mod config;
mod ipc;

use anyhow::{Context, Result, bail};
use config::Config;
use ipc::IpcServer;
use serde_json::{Value, json};
use sownteeshell_core::system::{self, BatteryReader, Sampler};
use sownteeshell_core::wallpaper;
use sownteeshell_core::{greeter, theme};
use std::env;
use std::io::{self, BufRead};
use std::process::ExitCode;
use std::time::Instant;
use tokio::sync::watch;
use tokio::task;

#[tokio::main(flavor = "multi_thread", worker_threads = 4)]
async fn main() -> ExitCode {
    match run().await {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("SownteeShell Core: {error:#}");
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
        Some("request-stdin") => {
            let method = arguments
                .next()
                .context("request-stdin requires a method name")?;
            ensure_no_more_arguments(arguments)?;
            request_stdin(method).await
        }
        Some("greeter-sessions") => {
            ensure_no_more_arguments(arguments)?;
            print_json(&greeter::discover_sessions())
        }
        Some("greeter-keyboard-layout") => {
            ensure_no_more_arguments(arguments)?;
            print_json(&greeter::keyboard_layout().await)
        }
        Some("launcher-klipy-copy") => {
            let url = arguments
                .next()
                .context("launcher-klipy-copy requires a URL")?;
            let mime = arguments
                .next()
                .context("launcher-klipy-copy requires a MIME type")?;
            let paste = arguments
                .next()
                .map(|value| value.eq_ignore_ascii_case("true"))
                .unwrap_or(false);
            ensure_no_more_arguments(arguments)?;
            compatibility_request(
                "launcher.klipy.copy",
                json!({"url": url, "mime": mime, "paste": paste}),
                OutputMode::Silent,
            )
            .await
        }
        Some("clipboard-restore") => {
            let entry_id = arguments
                .next()
                .context("clipboard-restore requires an entry ID")?;
            let auto_paste = arguments
                .next()
                .map(|value| value.eq_ignore_ascii_case("true"))
                .unwrap_or(false);
            ensure_no_more_arguments(arguments)?;
            compatibility_request(
                "clipboard.restore",
                json!({"entryId": entry_id, "autoPaste": auto_paste}),
                OutputMode::Silent,
            )
            .await
        }
        Some("display-ddc-get") => {
            let output = arguments
                .next()
                .context("display-ddc-get requires an output name")?;
            ensure_no_more_arguments(arguments)?;
            compatibility_request(
                "display.ddc.get",
                json!({"output": output}),
                OutputMode::JsonStatus,
            )
            .await
        }
        Some("display-ddc-set") => {
            let output = arguments
                .next()
                .context("display-ddc-set requires an output name")?;
            let value = arguments
                .next()
                .context("display-ddc-set requires a value")?
                .parse::<f64>()
                .context("parse DDC value")?;
            let bus = arguments
                .next()
                .map(|value| value.parse::<u32>().context("parse DDC bus"))
                .transpose()?;
            let maximum = arguments
                .next()
                .map(|value| value.parse::<u32>().context("parse DDC maximum"))
                .transpose()?;
            ensure_no_more_arguments(arguments)?;
            compatibility_request(
                "display.ddc.set",
                json!({"output": output, "value": value, "bus": bus, "maximum": maximum}),
                OutputMode::JsonStatus,
            )
            .await
        }
        Some("display-niri-mode") => {
            let mode = arguments
                .next()
                .context("display-niri-mode requires a mode")?;
            let preferred_external = arguments.next().unwrap_or_default();
            ensure_no_more_arguments(arguments)?;
            compatibility_request(
                "display.niri.mode",
                json!({"mode": mode, "preferredExternal": preferred_external}),
                OutputMode::JsonStatus,
            )
            .await
        }
        Some("display-niri-options") => {
            let config_path = arguments
                .next()
                .context("display-niri-options requires a config path")?;
            ensure_no_more_arguments(arguments)?;
            compatibility_request(
                "display.niri.options",
                json!({"configPath": config_path}),
                OutputMode::Json,
            )
            .await
        }
        Some("display-niri-persist") => {
            let config_path = arguments
                .next()
                .context("display-niri-persist requires a config path")?;
            let outputs = arguments
                .next()
                .context("display-niri-persist requires output JSON")
                .and_then(|value| serde_json::from_str::<Value>(&value).context("parse outputs"))?;
            ensure_no_more_arguments(arguments)?;
            compatibility_request(
                "display.niri.persist",
                json!({"configPath": config_path, "outputs": outputs}),
                OutputMode::JsonStatus,
            )
            .await
        }
        Some("display-niri-set-vrr") => {
            let config_path = arguments
                .next()
                .context("display-niri-set-vrr requires a config path")?;
            let output = arguments
                .next()
                .context("display-niri-set-vrr requires an output name")?;
            let mode = arguments
                .next()
                .context("display-niri-set-vrr requires a mode")?;
            ensure_no_more_arguments(arguments)?;
            compatibility_request(
                "display.niri.setVrr",
                json!({"configPath": config_path, "output": output, "mode": mode}),
                OutputMode::Silent,
            )
            .await
        }
        Some("display-sunshine-status") => {
            let config_path = arguments
                .next()
                .context("display-sunshine-status requires a config path")?;
            ensure_no_more_arguments(arguments)?;
            compatibility_request(
                "display.sunshine.status",
                json!({"configPath": config_path}),
                OutputMode::JsonStatus,
            )
            .await
        }
        Some("display-sunshine-apply") => {
            let config_path = arguments
                .next()
                .context("display-sunshine-apply requires a config path")?;
            let output = arguments
                .next()
                .context("display-sunshine-apply requires an output name")?;
            let display_id = arguments
                .next()
                .context("display-sunshine-apply requires a display ID")?
                .parse::<i64>()
                .context("parse Sunshine display ID")?;
            ensure_no_more_arguments(arguments)?;
            compatibility_request(
                "display.sunshine.apply",
                json!({"configPath": config_path, "output": output, "displayId": display_id}),
                OutputMode::JsonStatus,
            )
            .await
        }
        Some("wallpaper-engine-scan") => {
            let roots = arguments.collect::<Vec<_>>();
            compatibility_request(
                "wallpaper.engine.scan",
                json!({"roots": roots}),
                OutputMode::Json,
            )
            .await
        }
        Some("wallpaper-engine-project") => {
            let path = arguments
                .next()
                .context("wallpaper-engine-project requires a path")?;
            ensure_no_more_arguments(arguments)?;
            compatibility_request(
                "wallpaper.engine.project",
                json!({"path": path}),
                OutputMode::Json,
            )
            .await
        }
        Some("wallpaper-frame-probe") => {
            let path = arguments
                .next()
                .context("wallpaper-frame-probe requires a path")?;
            let timeout = arguments
                .next()
                .map(|value| value.parse::<f64>().context("parse frame probe timeout"))
                .transpose()?
                .unwrap_or(4.0);
            ensure_no_more_arguments(arguments)?;
            compatibility_request(
                "wallpaper.engine.frameProbe",
                json!({"path": path, "timeout": timeout}),
                OutputMode::Ready,
            )
            .await
        }
        Some("wallpaper-engine-preview") => {
            let source = arguments
                .next()
                .context("wallpaper-engine-preview requires a source")?;
            let target = arguments
                .next()
                .context("wallpaper-engine-preview requires a target")?;
            let cache_dir = arguments
                .next()
                .context("wallpaper-engine-preview requires a cache directory")?;
            let width = arguments
                .next()
                .context("wallpaper-engine-preview requires a width")?
                .parse::<u32>()
                .context("parse preview width")?;
            ensure_no_more_arguments(arguments)?;
            compatibility_request(
                "wallpaper.engine.preview",
                json!({
                    "source": source,
                    "target": target,
                    "cache_dir": cache_dir,
                    "width": width,
                }),
                OutputMode::Silent,
            )
            .await
        }
        Some("wallpaper-engine-cache-preview") => {
            let source = arguments
                .next()
                .context("wallpaper-engine-cache-preview requires a source")?;
            let target = arguments
                .next()
                .context("wallpaper-engine-cache-preview requires a target")?;
            let cache_dir = arguments
                .next()
                .context("wallpaper-engine-cache-preview requires a cache directory")?;
            ensure_no_more_arguments(arguments)?;
            compatibility_request(
                "wallpaper.engine.cachePreview",
                json!({"source": source, "target": target, "cache_dir": cache_dir}),
                OutputMode::Silent,
            )
            .await
        }
        Some("wallpaper-backdrop") => {
            let source = arguments
                .next()
                .context("wallpaper-backdrop requires a source")?;
            let cache_dir = arguments
                .next()
                .context("wallpaper-backdrop requires a cache directory")?;
            let stable_identity = arguments.next().unwrap_or_default();
            let generate_if_missing = arguments
                .next()
                .map(|value| value.eq_ignore_ascii_case("true"))
                .unwrap_or(true);
            ensure_no_more_arguments(arguments)?;
            compatibility_request(
                "wallpaper.backdrop.ensure",
                json!({
                    "source": source,
                    "cache_dir": cache_dir,
                    "stable_identity": stable_identity,
                    "generate_if_missing": generate_if_missing,
                }),
                OutputMode::Path,
            )
            .await
        }
        Some("wallpaper-workshop-login") => {
            let username = arguments
                .next()
                .context("wallpaper-workshop-login requires a username")?;
            ensure_no_more_arguments(arguments)?;
            let exit_code = wallpaper::login_workshop(&username)?;
            if exit_code == 0 {
                Ok(())
            } else {
                bail!("SteamCMD login failed with exit code {exit_code}")
            }
        }
        Some("theme-xsettings-apply") => {
            let theme_name = arguments
                .next()
                .context("theme-xsettings-apply requires a GTK theme name")?;
            let icon_theme_name = arguments
                .next()
                .context("theme-xsettings-apply requires an icon theme name")?;
            let cursor_theme_name = arguments
                .next()
                .context("theme-xsettings-apply requires a cursor theme name")?;
            let cursor_theme_size = arguments
                .next()
                .context("theme-xsettings-apply requires a cursor theme size")?
                .parse::<i32>()
                .context("parse cursor theme size")?;
            ensure_no_more_arguments(arguments)?;
            let report = theme::xsettings::apply(
                &theme_name,
                &icon_theme_name,
                &cursor_theme_name,
                cursor_theme_size,
            )?;
            print_json(&json!({
                "ok": true,
                "owner": report.owner,
                "serial": report.serial,
                "settingCount": report.setting_count,
            }))
        }
        Some("check") => {
            ensure_no_more_arguments(arguments)?;
            check()
        }
        Some("paths") => {
            ensure_no_more_arguments(arguments)?;
            paths()
        }
        Some("help" | "--help" | "-h") => {
            print_help();
            Ok(())
        }
        Some(command) if command.starts_with("--") => {
            let command_arguments = std::iter::once(command.to_string()).chain(arguments);
            task::block_in_place(|| system::run_cli(command_arguments)).context("run core command")
        }
        Some(command) => bail!("unknown command '{command}'; run with --help"),
    }
}

async fn serve() -> Result<()> {
    let config = Config::load()?;
    let (listener, _socket_guard) = ipc::bind_socket(&config.socket_path).await?;
    let (shutdown_tx, shutdown_rx) = watch::channel(false);
    let server = IpcServer::new(config.clone())?;
    let server_future = server.serve(listener, shutdown_rx);
    tokio::pin!(server_future);

    eprintln!(
        "SownteeShell Core daemon listening at {}",
        config.socket_path.display()
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
    result
}

async fn request(method: String, params: Value) -> Result<()> {
    let config = Config::load()?;
    let result = ipc::send_request(&config.socket_path, method, params).await?;
    print_json(&result)
}

async fn request_stdin(method: String) -> Result<()> {
    let mut input = String::new();
    io::stdin()
        .lock()
        .read_line(&mut input)
        .context("read request parameters from stdin")?;
    let params = if input.trim().is_empty() {
        json!({})
    } else {
        serde_json::from_str(&input).context("parse stdin request parameters")?
    };
    let result = cancellable_request(&method, params).await?;
    println!("{}", serde_json::to_string(&result)?);
    ensure_business_success(&result)
}

async fn compatibility_request(method: &str, params: Value, output: OutputMode) -> Result<()> {
    let result = cancellable_request(method, params).await?;
    if matches!(output, OutputMode::JsonStatus) {
        println!("{}", serde_json::to_string(&result)?);
        return ensure_business_success(&result);
    }
    ensure_business_success(&result)?;
    match output {
        OutputMode::Json => println!("{}", serde_json::to_string(&result)?),
        OutputMode::Path => {
            let path = result
                .get("path")
                .and_then(Value::as_str)
                .unwrap_or_default();
            if path.is_empty() {
                bail!("requested wallpaper cache entry does not exist");
            }
            println!("{path}");
        }
        OutputMode::Ready => {
            if !result
                .get("ready")
                .and_then(Value::as_bool)
                .unwrap_or(false)
            {
                bail!("renderer frame did not become ready");
            }
        }
        OutputMode::JsonStatus | OutputMode::Silent => {}
    }
    Ok(())
}

async fn cancellable_request(method: &str, mut params: Value) -> Result<Value> {
    let config = Config::load()?;
    let job_id = uuid::Uuid::new_v4().to_string();
    let object = params
        .as_object_mut()
        .context("wallpaper request parameters must be a JSON object")?;
    object.insert("_job_id".into(), job_id.clone().into());
    let request = ipc::send_cancellable_request(&config.socket_path, method.to_string(), params);
    tokio::pin!(request);
    tokio::select! {
        result = &mut request => result,
        signal = shutdown_signal() => {
            signal?;
            let _ = ipc::send_request(
                &config.socket_path,
                "job.cancel".to_string(),
                json!({"jobId": job_id}),
            ).await;
            bail!("backend request cancelled")
        }
    }
}

fn ensure_business_success(result: &Value) -> Result<()> {
    if result.get("ok").and_then(Value::as_bool) == Some(false) {
        let message = result
            .get("message")
            .and_then(Value::as_str)
            .or_else(|| result.get("error").and_then(Value::as_str))
            .unwrap_or("backend request failed");
        bail!("{message}");
    }
    Ok(())
}

enum OutputMode {
    Json,
    JsonStatus,
    Path,
    Ready,
    Silent,
}

fn check() -> Result<()> {
    let config = Config::load()?;
    let (stats, battery, battery_control) = task::block_in_place(|| -> Result<_> {
        let mut sampler = Sampler::new();
        let stats: Value =
            serde_json::from_str(&system::encode_stats(&sampler.sample(Instant::now())))?;
        let battery: Value = serde_json::from_str(&BatteryReader::new().encode())?;
        let battery_control: Value = serde_json::from_str(&system::battery_control_json())?;
        Ok((stats, battery, battery_control))
    })?;
    print_json(&json!({
        "ok": true,
        "version": env!("CARGO_PKG_VERSION"),
        "socketPath": config.socket_path,
        "samples": {
            "stats": stats,
            "battery": battery,
            "batteryControl": battery_control,
        },
    }))
}

fn paths() -> Result<()> {
    let config = Config::load()?;
    print_json(&json!({
        "dataDir": config.data_dir,
        "runtimeDir": config.runtime_dir,
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
        "SownteeShell Core backend\n\n\
         Usage:\n  \
           sownteeshell-core serve\n  \
           sownteeshell-core request <method> [params-json]\n  \
           sownteeshell-core request-stdin <method>\n  \
           sownteeshell-core greeter-sessions\n  \
           sownteeshell-core greeter-keyboard-layout\n  \
           sownteeshell-core clipboard-restore <entry-id> [true|false]\n  \
           sownteeshell-core display-ddc-get <output>\n  \
           sownteeshell-core display-ddc-set <output> <value> [bus] [maximum]\n  \
           sownteeshell-core display-niri-mode <mode> [preferred-output]\n  \
           sownteeshell-core display-niri-options <config>\n  \
           sownteeshell-core display-niri-persist <config> <outputs-json>\n  \
           sownteeshell-core display-niri-set-vrr <config> <output> <mode>\n  \
           sownteeshell-core display-sunshine-status <config>\n  \
           sownteeshell-core display-sunshine-apply <config> <output> <display-id>\n  \
           sownteeshell-core launcher-klipy-copy <url> <mime> [true|false]\n  \
           sownteeshell-core theme-xsettings-apply <theme> <icons> <cursor> <cursor-size>\n  \
           sownteeshell-core check\n  \
           sownteeshell-core paths\n\n\
         JSONL IPC is available through the configured Unix socket. SownteeShell\n\
         connects through CoreService for requests and telemetry subscriptions."
    );
}
