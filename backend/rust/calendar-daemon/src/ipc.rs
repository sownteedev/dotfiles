use crate::config::Config;
use crate::database::Database;
use crate::keyring::Keyring;
use crate::model::{Account, Calendar, DaemonEvent, EventDraft, ProviderKind, SyncReport};
use crate::oauth::{google as google_oauth, microsoft as microsoft_oauth};
use crate::providers::{
    CALDAV_PASSWORD_KEY, OAUTH_CLIENT_SECRET_KEY, OAUTH_TOKEN_KEY, ProviderError, ProviderRegistry,
};
use crate::sync::SyncService;
use anyhow::{Context, Result, bail};
use chrono::{DateTime, Duration, Utc};
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::fs;
use std::io::ErrorKind;
use std::os::unix::fs::{FileTypeExt, MetadataExt, PermissionsExt};
use std::path::{Path, PathBuf};
use tokio::io::{AsyncBufReadExt, AsyncWrite, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::{broadcast, watch};
use tokio::task::JoinSet;
use uuid::Uuid;

const MAX_REQUEST_BYTES: usize = 1024 * 1024;

#[derive(Clone)]
pub struct IpcServer {
    config: Config,
    database: Database,
    keyring: Keyring,
    providers: ProviderRegistry,
    sync: SyncService,
    events: broadcast::Sender<DaemonEvent>,
}

impl IpcServer {
    pub fn new(
        config: Config,
        database: Database,
        keyring: Keyring,
        providers: ProviderRegistry,
        sync: SyncService,
        events: broadcast::Sender<DaemonEvent>,
    ) -> Self {
        Self {
            config,
            database,
            keyring,
            providers,
            sync,
            events,
        }
    }

    pub async fn serve(
        self,
        listener: UnixListener,
        mut shutdown: watch::Receiver<bool>,
    ) -> Result<()> {
        let mut clients = JoinSet::new();
        loop {
            tokio::select! {
                changed = shutdown.changed() => {
                    if changed.is_err() || *shutdown.borrow() {
                        break;
                    }
                }
                accepted = listener.accept() => {
                    let (stream, _) = accepted.context("accept calendar IPC client")?;
                    let server = self.clone();
                    let client_shutdown = shutdown.clone();
                    clients.spawn(async move {
                        if let Err(error) = server.handle_client(stream, client_shutdown).await {
                            eprintln!("calendar IPC client failed: {error:#}");
                        }
                    });
                }
                Some(result) = clients.join_next(), if !clients.is_empty() => {
                    if let Err(error) = result {
                        eprintln!("calendar IPC client task failed: {error}");
                    }
                }
            }
        }

        clients.abort_all();
        while clients.join_next().await.is_some() {}
        Ok(())
    }

    async fn handle_client(
        &self,
        stream: UnixStream,
        shutdown: watch::Receiver<bool>,
    ) -> Result<()> {
        let (read_half, mut write_half) = stream.into_split();
        let mut reader = BufReader::new(read_half);
        let mut line = String::new();

        loop {
            line.clear();
            let read = reader.read_line(&mut line).await?;
            if read == 0 {
                return Ok(());
            }
            if line.len() > MAX_REQUEST_BYTES {
                write_json(
                    &mut write_half,
                    &RpcResponse::error(Value::Null, "request_too_large", "request exceeds 1 MiB"),
                )
                .await?;
                return Ok(());
            }

            let request = match serde_json::from_str::<RpcRequest>(line.trim_end()) {
                Ok(request) if !request.method.trim().is_empty() => request,
                Ok(request) => {
                    write_json(
                        &mut write_half,
                        &RpcResponse::error(request.id, "invalid_request", "method is required"),
                    )
                    .await?;
                    continue;
                }
                Err(error) => {
                    write_json(
                        &mut write_half,
                        &RpcResponse::error(
                            Value::Null,
                            "invalid_json",
                            format!("invalid JSON request: {error}"),
                        ),
                    )
                    .await?;
                    continue;
                }
            };

            if request.method == "subscribe" {
                return self
                    .serve_subscription(request, reader, write_half, shutdown)
                    .await;
            }

            let id = request.id.clone();
            let response = match self.dispatch(request).await {
                Ok(result) => RpcResponse::success(id, result),
                Err(error) => RpcResponse::error(id, error.code, error.message),
            };
            write_json(&mut write_half, &response).await?;
        }
    }

    async fn serve_subscription<R: tokio::io::AsyncBufRead + Unpin, W: AsyncWrite + Unpin>(
        &self,
        request: RpcRequest,
        mut reader: R,
        mut writer: W,
        mut shutdown: watch::Receiver<bool>,
    ) -> Result<()> {
        let parameters: SubscribeParams = match parse_params(request.params) {
            Ok(parameters) => parameters,
            Err(error) => {
                write_json(
                    &mut writer,
                    &RpcResponse::error(request.id, error.code, error.message),
                )
                .await?;
                return Ok(());
            }
        };
        let mut events = self.events.subscribe();
        write_json(
            &mut writer,
            &RpcResponse::success(request.id, json!({"subscribed": true})),
        )
        .await?;

        let mut client_input = String::new();
        loop {
            tokio::select! {
                changed = shutdown.changed() => {
                    if changed.is_err() || *shutdown.borrow() {
                        return Ok(());
                    }
                }
                event = events.recv() => {
                    match event {
                        Ok(event) if parameters.accepts(&event.topic) => {
                            write_json(&mut writer, &EventEnvelope { event }).await?;
                        }
                        Ok(_) => {}
                        Err(broadcast::error::RecvError::Lagged(skipped)) => {
                            write_json(
                                &mut writer,
                                &EventEnvelope {
                                    event: DaemonEvent {
                                        topic: "system".to_string(),
                                        kind: "lagged".to_string(),
                                        account_id: None,
                                        calendar_id: None,
                                        message: Some(format!("missed {skipped} daemon event(s)")),
                                    },
                                },
                            ).await?;
                        }
                        Err(broadcast::error::RecvError::Closed) => return Ok(()),
                    }
                }
                read = reader.read_line(&mut client_input) => {
                    match read {
                        Ok(0) => return Ok(()),
                        Ok(_) => {
                            write_json(
                                &mut writer,
                                &RpcResponse::error(
                                    Value::Null,
                                    "subscription_is_read_only",
                                    "open another connection for requests",
                                ),
                            ).await?;
                            return Ok(());
                        }
                        Err(error) => return Err(error.into()),
                    }
                }
            }
        }
    }

    async fn dispatch(&self, request: RpcRequest) -> RpcResult<Value> {
        match request.method.as_str() {
            "ping" => Ok(json!({
                "version": env!("CARGO_PKG_VERSION"),
                "pid": std::process::id(),
            })),
            "system.info" => self.system_info().await,
            "accounts.list" => Ok(json!(
                self.database
                    .list_accounts(false)
                    .map_err(RpcError::backend)?
            )),
            "accounts.google.add" => self.add_google(parse_params(request.params)?).await,
            "accounts.microsoft.add" => self.add_microsoft(parse_params(request.params)?).await,
            "accounts.icloud.add" => self.add_icloud(parse_params(request.params)?).await,
            "accounts.remove" => self.remove_account(parse_params(request.params)?).await,
            "accounts.setEnabled" => {
                let parameters: SetAccountEnabledParams = parse_params(request.params)?;
                let changed = self
                    .database
                    .set_account_enabled(&parameters.account_id, parameters.enabled)
                    .map_err(RpcError::backend)?;
                if !changed {
                    return Err(RpcError::not_found("calendar account was not found"));
                }
                self.publish(DaemonEvent::changed(
                    "accounts",
                    Some(&parameters.account_id),
                    None,
                ));
                Ok(json!({"changed": true}))
            }
            "calendars.list" => {
                let parameters: ListCalendarsParams = parse_params(request.params)?;
                Ok(json!(
                    self.database
                        .list_calendars(parameters.account_id.as_deref())
                        .map_err(RpcError::backend)?
                ))
            }
            "calendars.setVisible" => {
                let parameters: SetCalendarVisibleParams = parse_params(request.params)?;
                let calendar = self
                    .database
                    .get_calendar(&parameters.calendar_id)
                    .map_err(RpcError::backend)?
                    .ok_or_else(|| RpcError::not_found("calendar was not found"))?;
                let changed = self
                    .database
                    .set_calendar_visible(&parameters.calendar_id, parameters.visible)
                    .map_err(RpcError::backend)?;
                if !changed {
                    return Err(RpcError::not_found("calendar was not found"));
                }
                self.publish(DaemonEvent::changed(
                    "calendars",
                    Some(&calendar.account_id),
                    Some(&parameters.calendar_id),
                ));
                Ok(json!({"changed": true}))
            }
            "events.list" => self.list_events(parse_params(request.params)?),
            "events.create" => self.create_event(parse_params(request.params)?).await,
            "events.update" => self.update_event(parse_params(request.params)?).await,
            "events.delete" => self.delete_event(parse_params(request.params)?).await,
            "sync.now" => self.sync_now(parse_params(request.params)?).await,
            method => Err(RpcError::method_not_found(method)),
        }
    }

    async fn system_info(&self) -> RpcResult<Value> {
        let (accounts, calendars, events) = self.database.counts().map_err(RpcError::backend)?;
        Ok(json!({
            "name": "SownteeShell Calendar Daemon",
            "version": env!("CARGO_PKG_VERSION"),
            "pid": std::process::id(),
            "databasePath": self.config.database_path,
            "socketPath": self.config.socket_path,
            "keyringAvailable": self.keyring.available().await,
            "providers": ["google", "microsoft", "caldav"],
            "counts": {
                "accounts": accounts,
                "calendars": calendars,
                "events": events,
            }
        }))
    }

    async fn add_google(&self, parameters: AddGoogleParams) -> RpcResult<Value> {
        let client_id = required_setting(
            parameters.client_id,
            self.config.google_client_id.clone(),
            "Google OAuth client ID",
        )?;
        let client_secret = parameters
            .client_secret
            .or_else(|| self.config.google_client_secret.clone())
            .filter(|value| !value.trim().is_empty());
        let authorized =
            google_oauth::authorize(&self.providers.http(), &client_id, client_secret.as_deref())
                .await
                .map_err(RpcError::backend)?;
        let account_id = format!("google:{}", authorized.remote_id);
        let account = self.account_for_upsert(
            &account_id,
            ProviderKind::Google,
            authorized.display_name,
            authorized.email,
            json!({"clientId": client_id, "remoteId": authorized.remote_id}),
        )?;

        self.store_oauth_account(&account, &authorized.token, client_secret.as_deref())
            .await?;
        self.finish_account_add(account).await
    }

    async fn add_microsoft(&self, parameters: AddMicrosoftParams) -> RpcResult<Value> {
        let client_id = required_setting(
            parameters.client_id,
            self.config.microsoft_client_id.clone(),
            "Microsoft OAuth client ID",
        )?;
        let tenant = parameters
            .tenant
            .filter(|value| !value.trim().is_empty())
            .unwrap_or_else(|| self.config.microsoft_tenant.clone());
        let authorized = microsoft_oauth::authorize(&self.providers.http(), &client_id, &tenant)
            .await
            .map_err(RpcError::backend)?;
        let account_id = format!("microsoft:{}", authorized.remote_id);
        let account = self.account_for_upsert(
            &account_id,
            ProviderKind::Microsoft,
            authorized.display_name,
            authorized.email,
            json!({
                "clientId": client_id,
                "tenant": tenant,
                "remoteId": authorized.remote_id,
            }),
        )?;

        self.store_oauth_account(&account, &authorized.token, None)
            .await?;
        self.finish_account_add(account).await
    }

    async fn add_icloud(&self, parameters: AddIcloudParams) -> RpcResult<Value> {
        let email = required_text(parameters.email, "Apple account email")?;
        let password = required_text(parameters.app_password, "app-specific password")?;
        let username = parameters
            .username
            .filter(|value| !value.trim().is_empty())
            .unwrap_or_else(|| email.clone());
        let server = parameters
            .server
            .filter(|value| !value.trim().is_empty())
            .unwrap_or_else(|| crate::providers::caldav::default_icloud_endpoint().to_string());
        url::Url::parse(&server)
            .map_err(|error| RpcError::invalid_params(format!("invalid CalDAV server: {error}")))?;

        let existing = self
            .database
            .list_accounts(false)
            .map_err(RpcError::backend)?
            .into_iter()
            .find(|account| {
                account.provider == ProviderKind::CalDav
                    && account.email.eq_ignore_ascii_case(&email)
                    && account.config.get("server").and_then(Value::as_str) == Some(server.as_str())
            });
        let account_id = existing
            .as_ref()
            .map(|account| account.id.clone())
            .unwrap_or_else(|| format!("caldav:{}", Uuid::new_v4()));
        let display_name = parameters
            .display_name
            .filter(|value| !value.trim().is_empty())
            .unwrap_or_else(|| "iCloud".to_string());
        let account = self.account_for_upsert(
            &account_id,
            ProviderKind::CalDav,
            display_name,
            email,
            json!({"username": username, "server": server, "service": "icloud"}),
        )?;

        let previous_password = self
            .keyring
            .get(&account.id, CALDAV_PASSWORD_KEY)
            .await
            .map_err(RpcError::backend)?;
        self.keyring
            .set_text(&account.id, CALDAV_PASSWORD_KEY, &password)
            .await
            .map_err(RpcError::backend)?;

        let provider = self.providers.get(ProviderKind::CalDav);
        let calendars = match provider.list_calendars(&account).await {
            Ok(calendars) => calendars,
            Err(error) => {
                restore_secret(
                    &self.keyring,
                    &account.id,
                    CALDAV_PASSWORD_KEY,
                    previous_password,
                )
                .await;
                return Err(RpcError::backend(error));
            }
        };

        if let Err(error) = self.database.upsert_account(&account) {
            restore_secret(
                &self.keyring,
                &account.id,
                CALDAV_PASSWORD_KEY,
                previous_password,
            )
            .await;
            return Err(RpcError::backend(error));
        }
        if let Err(error) = self.database.reconcile_calendars(&account.id, &calendars) {
            restore_secret(
                &self.keyring,
                &account.id,
                CALDAV_PASSWORD_KEY,
                previous_password,
            )
            .await;
            match existing {
                Some(previous_account) => {
                    if let Err(rollback_error) = self.database.upsert_account(&previous_account) {
                        eprintln!(
                            "failed to restore CalDAV account {}: {rollback_error:#}",
                            account.id
                        );
                    }
                }
                None => {
                    if let Err(rollback_error) = self.database.delete_account(&account.id) {
                        eprintln!(
                            "failed to remove incomplete CalDAV account {}: {rollback_error:#}",
                            account.id
                        );
                    }
                }
            }
            return Err(RpcError::backend(error));
        }
        self.finish_account_add(account).await
    }

    async fn store_oauth_account(
        &self,
        account: &Account,
        token: &crate::oauth::OAuthToken,
        client_secret: Option<&str>,
    ) -> RpcResult<()> {
        let previous_token = self
            .keyring
            .get(&account.id, OAUTH_TOKEN_KEY)
            .await
            .map_err(RpcError::backend)?;
        let previous_client_secret = self
            .keyring
            .get(&account.id, OAUTH_CLIENT_SECRET_KEY)
            .await
            .map_err(RpcError::backend)?;

        self.keyring
            .set_json(&account.id, OAUTH_TOKEN_KEY, token)
            .await
            .map_err(RpcError::backend)?;
        let client_secret_result = match client_secret {
            Some(client_secret) => {
                self.keyring
                    .set_text(&account.id, OAUTH_CLIENT_SECRET_KEY, client_secret)
                    .await
            }
            None => Ok(()),
        };
        if let Err(error) = client_secret_result {
            restore_secret(&self.keyring, &account.id, OAUTH_TOKEN_KEY, previous_token).await;
            return Err(RpcError::backend(error));
        }

        if let Err(error) = self.database.upsert_account(account) {
            restore_secret(&self.keyring, &account.id, OAUTH_TOKEN_KEY, previous_token).await;
            restore_secret(
                &self.keyring,
                &account.id,
                OAUTH_CLIENT_SECRET_KEY,
                previous_client_secret,
            )
            .await;
            return Err(RpcError::backend(error));
        }
        Ok(())
    }

    async fn finish_account_add(&self, account: Account) -> RpcResult<Value> {
        self.publish(DaemonEvent::changed("accounts", Some(&account.id), None));
        let sync = self
            .sync
            .sync_account(&account.id)
            .await
            .map_err(RpcError::backend)?;
        let calendars = self
            .database
            .list_calendars(Some(&account.id))
            .map_err(RpcError::backend)?;
        let account = self
            .database
            .get_account(&account.id)
            .map_err(RpcError::backend)?
            .ok_or_else(|| RpcError::not_found("new calendar account disappeared"))?;
        Ok(json!({
            "account": account,
            "calendars": calendars,
            "sync": sync,
        }))
    }

    async fn remove_account(&self, parameters: AccountIdParams) -> RpcResult<Value> {
        if self
            .database
            .get_account(&parameters.account_id)
            .map_err(RpcError::backend)?
            .is_none()
        {
            return Err(RpcError::not_found("calendar account was not found"));
        }
        self.keyring
            .delete_account(&parameters.account_id)
            .await
            .map_err(RpcError::backend)?;
        let removed = self
            .database
            .delete_account(&parameters.account_id)
            .map_err(RpcError::backend)?;
        self.publish(DaemonEvent::changed("accounts", None, None));
        Ok(json!({"removed": removed}))
    }

    fn list_events(&self, parameters: ListEventsParams) -> RpcResult<Value> {
        let now = Utc::now();
        let from = parse_optional_time(parameters.from, now - Duration::days(30), "from")?;
        let to = parse_optional_time(parameters.to, now + Duration::days(365), "to")?;
        if from > to {
            return Err(RpcError::invalid_params("events.list requires from <= to"));
        }
        Ok(json!(
            self.database
                .list_events(
                    from,
                    to,
                    parameters.calendar_id.as_deref(),
                    parameters.visible_only,
                )
                .map_err(RpcError::backend)?
        ))
    }

    async fn create_event(&self, parameters: CreateEventParams) -> RpcResult<Value> {
        let draft = validate_event_draft(parameters.event)?;
        let (account, calendar) = self.writable_calendar(&parameters.calendar_id)?;
        let provider = self.providers.get(account.provider);
        let event = provider
            .create_event(&account, &calendar, &draft)
            .await
            .map_err(|error| self.provider_error(&account, error))?;
        let stored = self
            .database
            .upsert_event(&event)
            .map_err(RpcError::backend)?;
        self.publish(DaemonEvent::changed(
            "events",
            Some(&account.id),
            Some(&calendar.id),
        ));
        Ok(json!(stored))
    }

    async fn update_event(&self, parameters: UpdateEventParams) -> RpcResult<Value> {
        let draft = validate_event_draft(parameters.event)?;
        let existing = self
            .database
            .get_event(&parameters.event_id)
            .map_err(RpcError::backend)?
            .ok_or_else(|| RpcError::not_found("calendar event was not found"))?;
        let (account, calendar) = self.writable_calendar(&existing.calendar_id)?;
        let provider = self.providers.get(account.provider);
        let event = provider
            .update_event(&account, &calendar, &existing, &draft)
            .await
            .map_err(|error| self.provider_error(&account, error))?;
        let stored = self
            .database
            .upsert_event(&event)
            .map_err(RpcError::backend)?;
        self.publish(DaemonEvent::changed(
            "events",
            Some(&account.id),
            Some(&calendar.id),
        ));
        Ok(json!(stored))
    }

    async fn delete_event(&self, parameters: DeleteEventParams) -> RpcResult<Value> {
        let event = self
            .database
            .get_event(&parameters.event_id)
            .map_err(RpcError::backend)?
            .ok_or_else(|| RpcError::not_found("calendar event was not found"))?;
        let (account, calendar) = self.writable_calendar(&event.calendar_id)?;
        let provider = self.providers.get(account.provider);
        provider
            .delete_event(&account, &calendar, &event)
            .await
            .map_err(|error| self.provider_error(&account, error))?;
        self.database
            .delete_event(&event.id)
            .map_err(RpcError::backend)?;
        self.publish(DaemonEvent::changed(
            "events",
            Some(&account.id),
            Some(&calendar.id),
        ));
        Ok(json!({"deleted": true}))
    }

    fn writable_calendar(&self, calendar_id: &str) -> RpcResult<(Account, Calendar)> {
        let calendar = self
            .database
            .get_calendar(calendar_id)
            .map_err(RpcError::backend)?
            .ok_or_else(|| RpcError::not_found("calendar was not found"))?;
        if calendar.read_only {
            return Err(RpcError::invalid_params("calendar is read-only"));
        }
        let account = self
            .database
            .get_account(&calendar.account_id)
            .map_err(RpcError::backend)?
            .ok_or_else(|| RpcError::not_found("calendar account was not found"))?;
        if !account.enabled {
            return Err(RpcError::invalid_params("calendar account is disabled"));
        }
        Ok((account, calendar))
    }

    fn provider_error(&self, account: &Account, error: ProviderError) -> RpcError {
        let needs_reauth = matches!(error, ProviderError::Reauth(_));
        if needs_reauth {
            let _ = self
                .database
                .set_account_sync_error(&account.id, &error.to_string(), true);
            self.publish(DaemonEvent::changed("accounts", Some(&account.id), None));
        }
        RpcError::backend(error)
    }

    async fn sync_now(&self, parameters: SyncNowParams) -> RpcResult<Value> {
        let report = if let Some(account_id) = parameters
            .account_id
            .filter(|account_id| !account_id.trim().is_empty())
        {
            SyncReport {
                accounts: vec![
                    self.sync
                        .sync_account(&account_id)
                        .await
                        .map_err(RpcError::backend)?,
                ],
            }
        } else {
            self.sync.sync_all().await.map_err(RpcError::backend)?
        };
        Ok(json!({
            "succeeded": report.succeeded(),
            "failed": report.failed(),
            "accounts": report.accounts,
        }))
    }

    fn account_for_upsert(
        &self,
        id: &str,
        provider: ProviderKind,
        display_name: String,
        email: String,
        config: Value,
    ) -> RpcResult<Account> {
        let existing = self.database.get_account(id).map_err(RpcError::backend)?;
        let now = Utc::now();
        Ok(Account {
            id: id.to_string(),
            provider,
            display_name,
            email,
            config,
            enabled: true,
            needs_reauth: false,
            last_error: String::new(),
            last_sync_at: existing.as_ref().and_then(|account| account.last_sync_at),
            created_at: existing
                .as_ref()
                .map(|account| account.created_at)
                .unwrap_or(now),
            updated_at: now,
        })
    }

    fn publish(&self, event: DaemonEvent) {
        let _ = self.events.send(event);
    }
}

pub async fn bind_socket(path: &Path) -> Result<(UnixListener, SocketGuard)> {
    if fs::symlink_metadata(path).is_ok() {
        match UnixStream::connect(path).await {
            Ok(_) => bail!("calendar daemon is already listening at {}", path.display()),
            Err(error)
                if matches!(
                    error.kind(),
                    ErrorKind::ConnectionRefused | ErrorKind::NotFound
                ) =>
            {
                let metadata = fs::symlink_metadata(path)
                    .with_context(|| format!("inspect stale socket {}", path.display()))?;
                if !metadata.file_type().is_socket() {
                    bail!("refusing to replace non-socket path {}", path.display());
                }
                fs::remove_file(path)
                    .with_context(|| format!("remove stale socket {}", path.display()))?;
            }
            Err(error) => {
                return Err(error)
                    .with_context(|| format!("check existing calendar socket {}", path.display()));
            }
        }
    }

    let listener = UnixListener::bind(path)
        .with_context(|| format!("bind calendar socket {}", path.display()))?;
    fs::set_permissions(path, fs::Permissions::from_mode(0o600))
        .with_context(|| format!("set calendar socket permissions {}", path.display()))?;
    let metadata = fs::symlink_metadata(path)?;
    let guard = SocketGuard {
        path: path.to_path_buf(),
        device: metadata.dev(),
        inode: metadata.ino(),
    };
    Ok((listener, guard))
}

pub async fn send_request(socket_path: &Path, method: String, params: Value) -> Result<Value> {
    let mut stream = UnixStream::connect(socket_path)
        .await
        .with_context(|| format!("connect to calendar daemon at {}", socket_path.display()))?;
    let id = Value::String(Uuid::new_v4().to_string());
    write_json(
        &mut stream,
        &RpcRequest {
            id: id.clone(),
            method,
            params,
        },
    )
    .await?;

    let mut reader = BufReader::new(stream);
    let mut line = String::new();
    reader.read_line(&mut line).await?;
    if line.is_empty() {
        bail!("calendar daemon closed the connection without a response");
    }
    let response: RpcResponse = serde_json::from_str(line.trim_end())?;
    if response.id != id {
        bail!("calendar daemon returned a response with the wrong id");
    }
    if response.ok {
        Ok(response.result.unwrap_or(Value::Null))
    } else {
        let error = response
            .error
            .unwrap_or_else(|| RpcErrorBody::new("unknown", "unknown daemon error"));
        bail!("{}: {}", error.code, error.message)
    }
}

pub struct SocketGuard {
    path: PathBuf,
    device: u64,
    inode: u64,
}

impl Drop for SocketGuard {
    fn drop(&mut self) {
        let Ok(metadata) = fs::symlink_metadata(&self.path) else {
            return;
        };
        if metadata.file_type().is_socket()
            && metadata.dev() == self.device
            && metadata.ino() == self.inode
        {
            let _ = fs::remove_file(&self.path);
        }
    }
}

#[derive(Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct RpcRequest {
    #[serde(default)]
    id: Value,
    method: String,
    #[serde(default)]
    params: Value,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct RpcResponse {
    id: Value,
    ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    result: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<RpcErrorBody>,
}

impl RpcResponse {
    fn success(id: Value, result: Value) -> Self {
        Self {
            id,
            ok: true,
            result: Some(result),
            error: None,
        }
    }

    fn error(id: Value, code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            id,
            ok: false,
            result: None,
            error: Some(RpcErrorBody::new(code, message)),
        }
    }
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct RpcErrorBody {
    code: String,
    message: String,
}

impl RpcErrorBody {
    fn new(code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            code: code.into(),
            message: message.into(),
        }
    }
}

#[derive(Serialize)]
struct EventEnvelope {
    event: DaemonEvent,
}

#[derive(Debug)]
struct RpcError {
    code: &'static str,
    message: String,
}

impl RpcError {
    fn invalid_params(message: impl Into<String>) -> Self {
        Self {
            code: "invalid_params",
            message: message.into(),
        }
    }

    fn method_not_found(method: &str) -> Self {
        Self {
            code: "method_not_found",
            message: format!("unknown calendar method: {method}"),
        }
    }

    fn not_found(message: impl Into<String>) -> Self {
        Self {
            code: "not_found",
            message: message.into(),
        }
    }

    fn backend(error: impl std::fmt::Display) -> Self {
        Self {
            code: "backend_error",
            message: error.to_string(),
        }
    }
}

type RpcResult<T> = std::result::Result<T, RpcError>;

fn parse_params<T: DeserializeOwned>(params: Value) -> RpcResult<T> {
    let params = if params.is_null() { json!({}) } else { params };
    serde_json::from_value(params)
        .map_err(|error| RpcError::invalid_params(format!("invalid method parameters: {error}")))
}

fn required_setting(
    request_value: Option<String>,
    configured_value: Option<String>,
    label: &str,
) -> RpcResult<String> {
    request_value
        .or(configured_value)
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .ok_or_else(|| RpcError::invalid_params(format!("{label} is required")))
}

fn required_text(value: String, label: &str) -> RpcResult<String> {
    let value = value.trim().to_string();
    if value.is_empty() {
        Err(RpcError::invalid_params(format!("{label} is required")))
    } else {
        Ok(value)
    }
}

fn parse_optional_time(
    value: Option<String>,
    default: DateTime<Utc>,
    field: &str,
) -> RpcResult<DateTime<Utc>> {
    value
        .map(|value| {
            DateTime::parse_from_rfc3339(&value)
                .map(|date_time| date_time.with_timezone(&Utc))
                .map_err(|error| {
                    RpcError::invalid_params(format!("invalid {field} timestamp: {error}"))
                })
        })
        .transpose()
        .map(|value| value.unwrap_or(default))
}

async fn restore_secret(keyring: &Keyring, account_id: &str, key: &str, previous: Option<Vec<u8>>) {
    let result = match previous {
        Some(previous) => keyring.set(account_id, key, &previous).await,
        None => keyring.delete(account_id, key).await,
    };
    if let Err(error) = result {
        eprintln!("failed to restore keyring item for {account_id}/{key}: {error:#}");
    }
}

async fn write_json<W: AsyncWrite + Unpin, T: Serialize>(writer: &mut W, value: &T) -> Result<()> {
    let mut bytes = serde_json::to_vec(value)?;
    bytes.push(b'\n');
    writer.write_all(&bytes).await?;
    writer.flush().await?;
    Ok(())
}

#[derive(Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SubscribeParams {
    #[serde(default)]
    topics: Vec<String>,
}

impl SubscribeParams {
    fn accepts(&self, topic: &str) -> bool {
        self.topics.is_empty() || self.topics.iter().any(|candidate| candidate == topic)
    }
}

#[derive(Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct AddGoogleParams {
    client_id: Option<String>,
    client_secret: Option<String>,
}

#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct AddMicrosoftParams {
    client_id: Option<String>,
    tenant: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct AddIcloudParams {
    email: String,
    #[serde(default)]
    username: Option<String>,
    app_password: String,
    #[serde(default)]
    server: Option<String>,
    #[serde(default)]
    display_name: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct AccountIdParams {
    account_id: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SetAccountEnabledParams {
    account_id: String,
    enabled: bool,
}

#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ListCalendarsParams {
    account_id: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SetCalendarVisibleParams {
    calendar_id: String,
    visible: bool,
}

#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ListEventsParams {
    from: Option<String>,
    to: Option<String>,
    calendar_id: Option<String>,
    #[serde(default = "default_true")]
    visible_only: bool,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct CreateEventParams {
    calendar_id: String,
    event: EventDraft,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct UpdateEventParams {
    event_id: String,
    event: EventDraft,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct DeleteEventParams {
    event_id: String,
}

#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SyncNowParams {
    account_id: Option<String>,
}

const fn default_true() -> bool {
    true
}

fn validate_event_draft(mut draft: EventDraft) -> RpcResult<EventDraft> {
    draft.title = required_text(draft.title, "event title")?;
    draft.description = draft.description.trim().to_string();
    draft.location = draft.location.trim().to_string();
    if draft.end <= draft.start {
        return Err(RpcError::invalid_params(
            "event end must be later than its start",
        ));
    }
    Ok(draft)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_topics_subscribe_to_everything() {
        assert!(SubscribeParams::default().accepts("events"));
    }

    #[test]
    fn parses_null_as_empty_parameters() {
        let parameters: ListEventsParams = parse_params(Value::Null).expect("parse parameters");
        assert!(parameters.visible_only);
        assert!(parameters.calendar_id.is_none());
    }

    #[test]
    fn rejects_backwards_event_window() {
        let error = parse_optional_time(Some("not-a-date".to_string()), Utc::now(), "from")
            .expect_err("reject invalid date");
        assert_eq!(error.code, "invalid_params");
    }

    #[test]
    fn trims_configured_client_ids() {
        assert_eq!(
            required_setting(Some("  client-id  ".to_string()), None, "client").expect("client id"),
            "client-id"
        );
    }
}
