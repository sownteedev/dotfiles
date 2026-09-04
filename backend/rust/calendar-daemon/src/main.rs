mod config;
mod database;
mod ipc;
mod keyring;
mod model;
mod oauth;
mod providers;
mod reminder;
mod scheduler;
mod sync;

use crate::config::Config;
use crate::database::Database;
use crate::ipc::IpcServer;
use crate::keyring::Keyring;
use crate::providers::ProviderRegistry;
use crate::reminder::ReminderScheduler;
use crate::scheduler::Scheduler;
use crate::sync::SyncService;
use anyhow::{Context, Result, bail};
use serde_json::{Value, json};
use std::env;
use std::process::ExitCode;
use tokio::sync::{broadcast, watch};

#[tokio::main]
async fn main() -> ExitCode {
    match run().await {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("SownteeShell Calendar: {error:#}");
            ExitCode::FAILURE
        }
    }
}

async fn run() -> Result<()> {
    let mut arguments = env::args().skip(1);
    match arguments.next().as_deref() {
        None | Some("serve") => {
            ensure_no_more_arguments(arguments)?;
            serve().await
        }
        Some("request") => {
            let method = arguments.next().context("request requires a method name")?;
            let params = arguments
                .next()
                .map(|value| serde_json::from_str(&value).context("parse request parameters"))
                .transpose()?
                .unwrap_or_else(|| json!({}));
            ensure_no_more_arguments(arguments)?;
            request(method, params).await
        }
        Some("check") => {
            ensure_no_more_arguments(arguments)?;
            check().await
        }
        Some("sync-once") => {
            let account_id = arguments.next();
            ensure_no_more_arguments(arguments)?;
            sync_once(account_id.as_deref()).await
        }
        Some("paths") => {
            ensure_no_more_arguments(arguments)?;
            paths()
        }
        Some("help" | "--help" | "-h") => {
            print_help();
            Ok(())
        }
        Some(command) => bail!("unknown command '{command}'; run with --help"),
    }
}

async fn serve() -> Result<()> {
    let runtime = Runtime::load()?;
    let (listener, _socket_guard) = ipc::bind_socket(&runtime.config.socket_path).await?;
    let (shutdown_tx, shutdown_rx) = watch::channel(false);

    let scheduler = Scheduler::new(runtime.sync.clone(), runtime.config.sync_interval);
    let scheduler_task = tokio::spawn(scheduler.run(shutdown_rx.clone()));
    let reminder = ReminderScheduler::new(runtime.database.clone());
    let reminder_task = tokio::spawn(reminder.run(shutdown_rx.clone()));
    let server = IpcServer::new(
        runtime.config.clone(),
        runtime.database,
        runtime.keyring,
        runtime.providers,
        runtime.sync,
        runtime.events,
    );
    let server_future = server.serve(listener, shutdown_rx);
    tokio::pin!(server_future);

    eprintln!(
        "SownteeShell Calendar daemon listening at {}",
        runtime.config.socket_path.display()
    );
    let result = tokio::select! {
        result = &mut server_future => result,
        result = shutdown_signal() => {
            result?;
            let _ = shutdown_tx.send(true);
            server_future.await
        }
    };
    let _ = shutdown_tx.send(true);
    scheduler_task
        .await
        .context("calendar scheduler task panicked")?;
    reminder_task
        .await
        .context("calendar reminder task panicked")?;
    result
}

async fn request(method: String, params: Value) -> Result<()> {
    let config = Config::load()?;
    let result = ipc::send_request(&config.socket_path, method, params).await?;
    print_json(&result)
}

async fn check() -> Result<()> {
    let runtime = Runtime::load()?;
    let (accounts, calendars, events) = runtime.database.counts()?;
    let value = json!({
        "ok": true,
        "version": env!("CARGO_PKG_VERSION"),
        "databasePath": runtime.config.database_path,
        "socketPath": runtime.config.socket_path,
        "keyringAvailable": runtime.keyring.available().await,
        "counts": {
            "accounts": accounts,
            "calendars": calendars,
            "events": events,
        }
    });
    print_json(&value)
}

async fn sync_once(account_id: Option<&str>) -> Result<()> {
    let runtime = Runtime::load()?;
    let value = if let Some(account_id) = account_id {
        let account = runtime.sync.sync_account(account_id).await?;
        json!({"accounts": [account]})
    } else {
        serde_json::to_value(runtime.sync.sync_all().await?)?
    };
    print_json(&value)
}

fn paths() -> Result<()> {
    let config = Config::load()?;
    print_json(&json!({
        "dataDir": config.data_dir,
        "runtimeDir": config.runtime_dir,
        "databasePath": config.database_path,
        "socketPath": config.socket_path,
    }))
}

fn print_json(value: &Value) -> Result<()> {
    println!("{}", serde_json::to_string_pretty(value)?);
    Ok(())
}

fn ensure_no_more_arguments(mut arguments: impl Iterator<Item = String>) -> Result<()> {
    if let Some(argument) = arguments.next() {
        bail!("unexpected argument: {argument}");
    }
    Ok(())
}

async fn shutdown_signal() -> Result<()> {
    let mut terminate = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
        .context("install SIGTERM handler")?;
    tokio::select! {
        result = tokio::signal::ctrl_c() => result.context("install Ctrl-C handler"),
        _ = terminate.recv() => Ok(()),
    }
}

fn print_help() {
    println!(
        "SownteeShell Calendar backend\n\n\
         Usage:\n  \
           sownteeshell-calendar-daemon serve\n  \
           sownteeshell-calendar-daemon request <method> [params-json]\n  \
           sownteeshell-calendar-daemon check\n  \
           sownteeshell-calendar-daemon sync-once [account-id]\n  \
           sownteeshell-calendar-daemon paths\n\n\
         The current Quickshell Calendar is not connected to this daemon."
    );
}

struct Runtime {
    config: Config,
    database: Database,
    keyring: Keyring,
    providers: ProviderRegistry,
    sync: SyncService,
    events: broadcast::Sender<model::DaemonEvent>,
}

impl Runtime {
    fn load() -> Result<Self> {
        let config = Config::load()?;
        let database = Database::open(&config.database_path)?;
        let keyring = Keyring;
        let providers = ProviderRegistry::new(keyring.clone())?;
        let (events, _) = broadcast::channel(256);
        let sync = SyncService::new(database.clone(), providers.clone(), &config, events.clone());
        Ok(Self {
            config,
            database,
            keyring,
            providers,
            sync,
            events,
        })
    }
}
