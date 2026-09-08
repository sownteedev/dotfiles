use crate::config::Config;
use anyhow::{Context, Result, bail};
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sownteeshell_core::application::ApplicationBackend;
use sownteeshell_core::clipboard::ClipboardBackend;
use sownteeshell_core::diagnostics::DiagnosticsBackend;
use sownteeshell_core::display::DisplayBackend;
use sownteeshell_core::greeter::GreeterBackend;
use sownteeshell_core::job::JobRegistry;
use sownteeshell_core::launcher::LauncherBackend;
use sownteeshell_core::network::NetworkClient;
use sownteeshell_core::settings::SettingsBackend;
use sownteeshell_core::system::{self, BatteryReader, ProcessMode, Sampler};
use sownteeshell_core::updates::UpdatesBackend;
use sownteeshell_core::wallpaper::WallpaperBackend;
use sownteeshell_core::weather::WeatherBackend;
use sownteeshell_core::wifi::WifiBackend;
use std::fs;
use std::io::ErrorKind;
use std::os::unix::fs::{FileTypeExt, MetadataExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};
use tokio::io::{AsyncBufRead, AsyncBufReadExt, AsyncWrite, AsyncWriteExt, BufReader, BufWriter};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::watch;
use tokio::task;
use tokio::time::{Interval, MissedTickBehavior, interval};
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

const MAX_REQUEST_BYTES: usize = 1024 * 1024;
const MAX_RESPONSE_BYTES: usize = 16 * 1024 * 1024;
const STATS_INTERVAL: Duration = Duration::from_secs(1);
const BATTERY_INTERVAL: Duration = Duration::from_secs(5);
const UPDATES_INTERVAL: Duration = Duration::from_secs(2 * 60 * 60);

#[derive(Clone)]
pub struct IpcServer {
    applications: ApplicationBackend,
    clipboard: ClipboardBackend,
    config: Config,
    diagnostics: DiagnosticsBackend,
    display: DisplayBackend,
    greeter: GreeterBackend,
    jobs: JobRegistry,
    launcher: LauncherBackend,
    settings: SettingsBackend,
    started_at: Instant,
    updates: UpdatesBackend,
    wallpaper: WallpaperBackend,
    weather: WeatherBackend,
    wifi: WifiBackend,
}

impl IpcServer {
    pub fn new(config: Config) -> Result<Self> {
        let jobs = JobRegistry::default();
        let network = NetworkClient::default();
        Ok(Self {
            applications: ApplicationBackend::new(jobs.clone()),
            clipboard: ClipboardBackend::new(jobs.clone()),
            diagnostics: DiagnosticsBackend::new(jobs.clone()),
            display: DisplayBackend::new(jobs.clone()),
            greeter: GreeterBackend::new(jobs.clone()),
            launcher: LauncherBackend::new(
                network.clone(),
                jobs.clone(),
                config.runtime_dir.clone(),
            ),
            settings: SettingsBackend::new(jobs.clone()),
            wallpaper: WallpaperBackend::new(network.clone(), jobs.clone()),
            weather: WeatherBackend::new(network, jobs.clone()),
            wifi: WifiBackend::new(jobs.clone()),
            config,
            jobs,
            started_at: Instant::now(),
            updates: UpdatesBackend::default(),
        })
    }

    pub async fn serve(
        self,
        listener: UnixListener,
        mut shutdown: watch::Receiver<bool>,
    ) -> Result<()> {
        loop {
            if *shutdown.borrow() {
                return Ok(());
            }

            tokio::select! {
                changed = shutdown.changed() => {
                    if changed.is_err() || *shutdown.borrow() {
                        return Ok(());
                    }
                }
                accepted = listener.accept() => {
                    let (stream, _) = accepted.context("accept core IPC client")?;
                    let server = self.clone();
                    tokio::spawn(async move {
                        if let Err(error) = server.handle_client(stream).await {
                            eprintln!("core IPC client failed: {error:#}");
                        }
                    });
                }
            }
        }
    }

    async fn handle_client(&self, stream: UnixStream) -> Result<()> {
        let (reader, writer) = stream.into_split();
        let mut reader = BufReader::new(reader);
        let mut writer = BufWriter::new(writer);
        let mut subscription = None;

        loop {
            let event = match subscription.as_mut() {
                None => ConnectionEvent::Input(read_bounded_line(&mut reader).await?),
                Some(Subscription::Stats { interval, .. }) => {
                    tokio::select! {
                        line = read_bounded_line(&mut reader) => ConnectionEvent::Input(line?),
                        _ = interval.tick() => ConnectionEvent::StatsTick,
                    }
                }
                Some(Subscription::Battery { interval, .. }) => {
                    tokio::select! {
                        line = read_bounded_line(&mut reader) => ConnectionEvent::Input(line?),
                        _ = interval.tick() => ConnectionEvent::BatteryTick,
                    }
                }
                Some(Subscription::Updates { interval }) => {
                    tokio::select! {
                        line = read_bounded_line(&mut reader) => ConnectionEvent::Input(line?),
                        _ = interval.tick() => ConnectionEvent::UpdatesTick,
                    }
                }
            };

            match event {
                ConnectionEvent::Input(BoundedLine::Line(line)) => {
                    if matches!(
                        self.handle_line(&line, &mut reader, &mut subscription, &mut writer)
                            .await?,
                        LineOutcome::Closed
                    ) {
                        return Ok(());
                    }
                }
                ConnectionEvent::Input(BoundedLine::TooLarge) => {
                    write_rpc_response(
                        &mut writer,
                        &RpcResponse::error(
                            Value::Null,
                            "request_too_large",
                            "request exceeds 1 MiB",
                        ),
                    )
                    .await?;
                }
                ConnectionEvent::Input(BoundedLine::InvalidUtf8) => {
                    write_rpc_response(
                        &mut writer,
                        &RpcResponse::error(
                            Value::Null,
                            "invalid_request",
                            "request must be valid UTF-8",
                        ),
                    )
                    .await?;
                }
                ConnectionEvent::Input(BoundedLine::Eof) => return Ok(()),
                ConnectionEvent::StatsTick => {
                    let Some(Subscription::Stats { sampler, .. }) = subscription.as_mut() else {
                        continue;
                    };
                    let data =
                        task::block_in_place(|| stats_value(sampler.sample(Instant::now())))?;
                    write_json(
                        &mut writer,
                        &EventEnvelope {
                            event: "stats.updated",
                            data,
                        },
                    )
                    .await?;
                }
                ConnectionEvent::BatteryTick => {
                    let Some(Subscription::Battery { reader, .. }) = subscription.as_ref() else {
                        continue;
                    };
                    let data = task::block_in_place(|| battery_value(reader))?;
                    write_json(
                        &mut writer,
                        &EventEnvelope {
                            event: "battery.updated",
                            data,
                        },
                    )
                    .await?;
                }
                ConnectionEvent::UpdatesTick => {
                    let data = self
                        .updates
                        .check(json!({}), CancellationToken::new())
                        .await;
                    write_json(
                        &mut writer,
                        &EventEnvelope {
                            event: "updates.updated",
                            data,
                        },
                    )
                    .await?;
                }
            }
        }
    }

    async fn handle_line(
        &self,
        line: &str,
        reader: &mut BufReader<tokio::net::unix::OwnedReadHalf>,
        subscription: &mut Option<Subscription>,
        writer: &mut BufWriter<tokio::net::unix::OwnedWriteHalf>,
    ) -> Result<LineOutcome> {
        let request = match serde_json::from_str::<RpcRequest>(line) {
            Ok(request) if !request.method.trim().is_empty() => request,
            Ok(request) => {
                write_rpc_response(
                    writer,
                    &RpcResponse::error(request.id, "invalid_request", "method is required"),
                )
                .await?;
                return Ok(LineOutcome::Continue);
            }
            Err(error) => {
                write_rpc_response(
                    writer,
                    &RpcResponse::error(
                        Value::Null,
                        "invalid_request",
                        format!("invalid JSON request: {error}"),
                    ),
                )
                .await?;
                return Ok(LineOutcome::Continue);
            }
        };

        let response = if request.cancel_on_disconnect {
            let job_id = request
                .params
                .get("_job_id")
                .and_then(Value::as_str)
                .map(str::to_string);
            let dispatch = self.dispatch(request, subscription);
            tokio::pin!(dispatch);
            tokio::select! {
                response = &mut dispatch => response,
                input = read_bounded_line(reader) => {
                    let _ = input?;
                    if let Some(job_id) = job_id {
                        self.jobs.cancel(&job_id);
                    }
                    return Ok(LineOutcome::Closed);
                }
            }
        } else {
            self.dispatch(request, subscription).await
        };
        write_rpc_response(writer, &response).await?;
        Ok(LineOutcome::Continue)
    }

    async fn dispatch(
        &self,
        request: RpcRequest,
        subscription: &mut Option<Subscription>,
    ) -> RpcResponse {
        let RpcRequest {
            id, method, params, ..
        } = request;
        let result = match method.as_str() {
            "ping" => Ok(json!({
                "pong": true,
                "version": env!("CARGO_PKG_VERSION"),
            })),
            "system.info" => Ok(json!({
                "pid": std::process::id(),
                "version": env!("CARGO_PKG_VERSION"),
                "socketPath": self.config.socket_path,
                "uptimeSeconds": self.started_at.elapsed().as_secs(),
                "capabilities": [
                    "stats",
                    "application-packages",
                    "battery",
                    "clipboard",
                    "diagnostics",
                    "display",
                    "greeter",
                    "launcher",
                    "process-memory",
                    "process-terminate",
                    "settings",
                    "updates",
                    "wallpaper",
                    "weather",
                    "wifi-qr",
                ],
            })),
            "job.cancel" | "wallpaper.cancel" => cancel_job(params, &self.jobs),
            "stats.snapshot" => stats_snapshot(params),
            "battery.snapshot" => task::block_in_place(|| battery_value(&BatteryReader::new())),
            "battery.control" => task::block_in_place(battery_control_value),
            "process.memory" => process_memory(params),
            "process.terminate" => process_terminate(params),
            "stats.subscribe" => subscribe_stats(params, subscription),
            "stats.setMode" => set_stats_mode(params, subscription),
            "stats.unsubscribe" => unsubscribe_stats(subscription),
            "battery.subscribe" => subscribe_battery(subscription),
            "battery.unsubscribe" => unsubscribe_battery(subscription),
            "updates.check" => {
                let mut params = params;
                let job_id = JobRegistry::take_job_id(&mut params);
                let job = self.jobs.begin(job_id.as_deref());
                Ok(self.updates.check(params, job.cancellation()).await)
            }
            "updates.subscribe" => subscribe_updates(subscription),
            "updates.unsubscribe" => unsubscribe_updates(subscription),
            _ if method.starts_with("application.") => {
                match self.applications.request(&method, params).await {
                    Ok(Some(result)) => Ok(result),
                    Ok(None) => Err(RpcError::method_not_found(format!(
                        "unknown method '{method}'"
                    ))),
                    Err(error) => Err(RpcError::backend(error)),
                }
            }
            _ if method.starts_with("clipboard.") => {
                match self.clipboard.request(&method, params).await {
                    Ok(Some(result)) => Ok(result),
                    Ok(None) => Err(RpcError::method_not_found(format!(
                        "unknown method '{method}'"
                    ))),
                    Err(error) => Err(RpcError::backend(error)),
                }
            }
            _ if method.starts_with("diagnostics.") => {
                match self.diagnostics.request(&method, params).await {
                    Ok(Some(result)) => Ok(result),
                    Ok(None) => Err(RpcError::method_not_found(format!(
                        "unknown method '{method}'"
                    ))),
                    Err(error) => Err(RpcError::backend(error)),
                }
            }
            _ if method.starts_with("display.") => {
                match self.display.request(&method, params).await {
                    Ok(Some(result)) => Ok(result),
                    Ok(None) => Err(RpcError::method_not_found(format!(
                        "unknown method '{method}'"
                    ))),
                    Err(error) => Err(RpcError::backend(error)),
                }
            }
            _ if method.starts_with("greeter.") => {
                match self.greeter.request(&method, params).await {
                    Ok(Some(result)) => Ok(result),
                    Ok(None) => Err(RpcError::method_not_found(format!(
                        "unknown method '{method}'"
                    ))),
                    Err(error) => Err(RpcError::backend(error)),
                }
            }
            _ if method.starts_with("launcher.") => {
                match self.launcher.request(&method, params).await {
                    Ok(Some(result)) => Ok(result),
                    Ok(None) => Err(RpcError::method_not_found(format!(
                        "unknown method '{method}'"
                    ))),
                    Err(error) => Err(RpcError::backend(error)),
                }
            }
            _ if method.starts_with("settings.") => {
                match self.settings.request(&method, params).await {
                    Ok(Some(result)) => Ok(result),
                    Ok(None) => Err(RpcError::method_not_found(format!(
                        "unknown method '{method}'"
                    ))),
                    Err(error) => Err(RpcError::backend(error)),
                }
            }
            _ if method.starts_with("weather.") => {
                match self.weather.request(&method, params).await {
                    Ok(Some(result)) => Ok(result),
                    Ok(None) => Err(RpcError::method_not_found(format!(
                        "unknown method '{method}'"
                    ))),
                    Err(error) => Err(RpcError::backend(error)),
                }
            }
            _ if method.starts_with("wifi.") => match self.wifi.request(&method, params).await {
                Ok(Some(result)) => Ok(result),
                Ok(None) => Err(RpcError::method_not_found(format!(
                    "unknown method '{method}'"
                ))),
                Err(error) => Err(RpcError::backend(error)),
            },
            _ => match self.wallpaper.request(&method, params).await {
                Ok(Some(result)) => Ok(result),
                Ok(None) => Err(RpcError::method_not_found(format!(
                    "unknown method '{method}'"
                ))),
                Err(error) => Err(RpcError::backend(error)),
            },
        };

        match result {
            Ok(result) => RpcResponse::success(id, result),
            Err(error) => RpcResponse::error(id, error.code, error.message),
        }
    }
}

enum BoundedLine {
    Eof,
    InvalidUtf8,
    Line(String),
    TooLarge,
}

enum ConnectionEvent {
    Input(BoundedLine),
    StatsTick,
    BatteryTick,
    UpdatesTick,
}

enum LineOutcome {
    Continue,
    Closed,
}

enum Subscription {
    Stats {
        sampler: Box<Sampler>,
        interval: Interval,
    },
    Battery {
        reader: Box<BatteryReader>,
        interval: Interval,
    },
    Updates {
        interval: Interval,
    },
}

fn cancel_job(params: Value, jobs: &JobRegistry) -> RpcResult<Value> {
    let params: CancelJobParams = decode_params(params)?;
    Ok(json!({
        "ok": true,
        "cancelled": jobs.cancel(&params.job_id),
        "jobId": params.job_id,
    }))
}

fn stats_snapshot(params: Value) -> RpcResult<Value> {
    let mode = stats_mode(params)?;
    task::block_in_place(|| {
        let mut sampler = Sampler::new();
        sampler.set_mode(mode);
        stats_value(sampler.sample(Instant::now()))
    })
}

fn subscribe_stats(params: Value, subscription: &mut Option<Subscription>) -> RpcResult<Value> {
    ensure_no_subscription(subscription)?;
    let mode = stats_mode(params)?;
    let mut sampler = task::block_in_place(Sampler::new);
    sampler.set_mode(mode);
    let mut sample_interval = interval(STATS_INTERVAL);
    sample_interval.set_missed_tick_behavior(MissedTickBehavior::Skip);
    *subscription = Some(Subscription::Stats {
        sampler: Box::new(sampler),
        interval: sample_interval,
    });
    Ok(json!({
        "subscription": "stats",
        "active": true,
        "mode": mode.as_str(),
        "intervalMs": STATS_INTERVAL.as_millis(),
    }))
}

fn set_stats_mode(params: Value, subscription: &mut Option<Subscription>) -> RpcResult<Value> {
    let mode = stats_mode(params)?;
    let Some(Subscription::Stats { sampler, .. }) = subscription.as_mut() else {
        return Err(RpcError::invalid_state(
            "stats.setMode requires an active stats subscription",
        ));
    };
    sampler.set_mode(mode);
    Ok(json!({"mode": mode.as_str()}))
}

fn unsubscribe_stats(subscription: &mut Option<Subscription>) -> RpcResult<Value> {
    if !matches!(subscription, Some(Subscription::Stats { .. })) {
        return Err(RpcError::invalid_state(
            "no active stats subscription on this connection",
        ));
    }
    *subscription = None;
    Ok(json!({"subscription": "stats", "active": false}))
}

fn subscribe_battery(subscription: &mut Option<Subscription>) -> RpcResult<Value> {
    ensure_no_subscription(subscription)?;
    let mut sample_interval = interval(BATTERY_INTERVAL);
    sample_interval.set_missed_tick_behavior(MissedTickBehavior::Skip);
    *subscription = Some(Subscription::Battery {
        reader: Box::new(task::block_in_place(BatteryReader::new)),
        interval: sample_interval,
    });
    Ok(json!({
        "subscription": "battery",
        "active": true,
        "intervalMs": BATTERY_INTERVAL.as_millis(),
    }))
}

fn unsubscribe_battery(subscription: &mut Option<Subscription>) -> RpcResult<Value> {
    if !matches!(subscription, Some(Subscription::Battery { .. })) {
        return Err(RpcError::invalid_state(
            "no active battery subscription on this connection",
        ));
    }
    *subscription = None;
    Ok(json!({"subscription": "battery", "active": false}))
}

fn subscribe_updates(subscription: &mut Option<Subscription>) -> RpcResult<Value> {
    ensure_no_subscription(subscription)?;
    let mut update_interval = interval(UPDATES_INTERVAL);
    update_interval.set_missed_tick_behavior(MissedTickBehavior::Skip);
    *subscription = Some(Subscription::Updates {
        interval: update_interval,
    });
    Ok(json!({
        "subscription": "updates",
        "active": true,
        "intervalMs": UPDATES_INTERVAL.as_millis(),
    }))
}

fn unsubscribe_updates(subscription: &mut Option<Subscription>) -> RpcResult<Value> {
    if !matches!(subscription, Some(Subscription::Updates { .. })) {
        return Err(RpcError::invalid_state(
            "no active updates subscription on this connection",
        ));
    }
    *subscription = None;
    Ok(json!({"subscription": "updates", "active": false}))
}

fn ensure_no_subscription(subscription: &Option<Subscription>) -> RpcResult<()> {
    if subscription.is_some() {
        return Err(RpcError::invalid_state(
            "this connection already has an active subscription",
        ));
    }
    Ok(())
}

fn stats_mode(params: Value) -> RpcResult<ProcessMode> {
    let params: StatsParams = decode_params(params)?;
    match params.mode {
        Some(mode) => ProcessMode::parse(&mode)
            .ok_or_else(|| RpcError::invalid_params("mode must be one of: none, cpu, ram, gpu")),
        None => Ok(ProcessMode::None),
    }
}

fn stats_value(payload: sownteeshell_core::system::StatsPayload) -> RpcResult<Value> {
    serde_json::from_str(&system::encode_stats(&payload)).map_err(RpcError::backend)
}

fn battery_value(reader: &BatteryReader) -> RpcResult<Value> {
    serde_json::from_str(&reader.encode()).map_err(RpcError::backend)
}

fn battery_control_value() -> RpcResult<Value> {
    serde_json::from_str(&system::battery_control_json()).map_err(RpcError::backend)
}

fn process_memory(params: Value) -> RpcResult<Value> {
    let params: ProcessParams = decode_params(params)?;
    task::block_in_place(|| {
        let details = system::process_memory_details(params.pid).map_err(RpcError::backend)?;
        serde_json::from_str(&system::process_memory_details_json(&details))
            .map_err(RpcError::backend)
    })
}

fn process_terminate(params: Value) -> RpcResult<Value> {
    let params: ProcessParams = decode_params(params)?;
    task::block_in_place(|| {
        system::terminate_process_tree(params.pid).map_err(RpcError::backend)?;
        Ok(json!({"pid": params.pid, "terminated": true}))
    })
}

fn decode_params<T: DeserializeOwned>(params: Value) -> RpcResult<T> {
    serde_json::from_value(params)
        .map_err(|error| RpcError::invalid_params(format!("invalid method parameters: {error}")))
}

pub async fn bind_socket(path: &Path) -> Result<(UnixListener, SocketGuard)> {
    if fs::symlink_metadata(path).is_ok() {
        match UnixStream::connect(path).await {
            Ok(_) => bail!("core daemon is already listening at {}", path.display()),
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
                    .with_context(|| format!("check existing core socket {}", path.display()));
            }
        }
    }

    let listener =
        UnixListener::bind(path).with_context(|| format!("bind core socket {}", path.display()))?;
    fs::set_permissions(path, fs::Permissions::from_mode(0o600))
        .with_context(|| format!("set core socket permissions {}", path.display()))?;
    let metadata = fs::symlink_metadata(path)?;
    let guard = SocketGuard {
        path: path.to_path_buf(),
        device: metadata.dev(),
        inode: metadata.ino(),
    };
    Ok((listener, guard))
}

pub async fn send_request(socket_path: &Path, method: String, params: Value) -> Result<Value> {
    send_request_inner(socket_path, method, params, false).await
}

pub async fn send_cancellable_request(
    socket_path: &Path,
    method: String,
    params: Value,
) -> Result<Value> {
    send_request_inner(socket_path, method, params, true).await
}

async fn send_request_inner(
    socket_path: &Path,
    method: String,
    params: Value,
    cancel_on_disconnect: bool,
) -> Result<Value> {
    let mut stream = UnixStream::connect(socket_path)
        .await
        .with_context(|| format!("connect to core daemon at {}", socket_path.display()))?;
    let id = Value::String(Uuid::new_v4().to_string());
    write_json_with_limit(
        &mut stream,
        &RpcRequest {
            cancel_on_disconnect,
            id: id.clone(),
            method,
            params,
        },
        MAX_REQUEST_BYTES,
        "request",
    )
    .await?;

    let mut reader = BufReader::new(stream);
    let line = match read_bounded_line_with_limit(&mut reader, MAX_RESPONSE_BYTES).await? {
        BoundedLine::Line(line) => line,
        BoundedLine::Eof => bail!("core daemon closed the connection without a response"),
        BoundedLine::InvalidUtf8 => bail!("core daemon returned invalid UTF-8"),
        BoundedLine::TooLarge => bail!("core daemon response exceeds 16 MiB"),
    };
    let response: RpcResponse = serde_json::from_str(&line)?;
    if response.id != id {
        bail!("core daemon returned a response with the wrong id");
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
    cancel_on_disconnect: bool,
    #[serde(default)]
    id: Value,
    method: String,
    #[serde(default = "empty_params")]
    params: Value,
}

fn empty_params() -> Value {
    json!({})
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
#[serde(rename_all = "camelCase")]
struct EventEnvelope<'a> {
    event: &'a str,
    data: Value,
}

#[derive(Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct StatsParams {
    mode: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct ProcessParams {
    pid: u32,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct CancelJobParams {
    job_id: String,
}

type RpcResult<T> = std::result::Result<T, RpcError>;

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

    fn invalid_state(message: impl Into<String>) -> Self {
        Self {
            code: "invalid_state",
            message: message.into(),
        }
    }

    fn method_not_found(message: impl Into<String>) -> Self {
        Self {
            code: "method_not_found",
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

impl std::fmt::Display for RpcError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(formatter, "{}: {}", self.code, self.message)
    }
}

impl std::error::Error for RpcError {}

async fn read_bounded_line<R: AsyncBufRead + Unpin>(reader: &mut R) -> Result<BoundedLine> {
    read_bounded_line_with_limit(reader, MAX_REQUEST_BYTES).await
}

async fn read_bounded_line_with_limit<R: AsyncBufRead + Unpin>(
    reader: &mut R,
    limit: usize,
) -> Result<BoundedLine> {
    let mut bytes = Vec::with_capacity(limit.min(8192));
    let mut oversized = false;

    loop {
        let available = reader.fill_buf().await?;
        if available.is_empty() {
            if bytes.is_empty() && !oversized {
                return Ok(BoundedLine::Eof);
            }
            break;
        }

        let newline = available.iter().position(|byte| *byte == b'\n');
        let consumed = newline.map_or(available.len(), |index| index + 1);
        let payload = newline.map_or(available, |index| &available[..index]);
        if !oversized {
            if bytes.len().saturating_add(payload.len()) > limit {
                oversized = true;
                bytes.clear();
            } else {
                bytes.extend_from_slice(payload);
            }
        }
        reader.consume(consumed);
        if newline.is_some() {
            break;
        }
    }

    if oversized {
        return Ok(BoundedLine::TooLarge);
    }
    if bytes.last() == Some(&b'\r') {
        bytes.pop();
    }
    match String::from_utf8(bytes) {
        Ok(line) => Ok(BoundedLine::Line(line)),
        Err(_) => Ok(BoundedLine::InvalidUtf8),
    }
}

async fn write_json_with_limit<W: AsyncWrite + Unpin, T: Serialize>(
    writer: &mut W,
    value: &T,
    limit: usize,
    label: &str,
) -> Result<()> {
    let mut bytes = serde_json::to_vec(value)?;
    if bytes.len() > limit {
        bail!("{label} exceeds {limit} bytes");
    }
    bytes.push(b'\n');
    writer.write_all(&bytes).await?;
    writer.flush().await?;
    Ok(())
}

async fn write_json<W: AsyncWrite + Unpin, T: Serialize>(writer: &mut W, value: &T) -> Result<()> {
    write_json_with_limit(writer, value, MAX_RESPONSE_BYTES, "response").await
}

async fn write_rpc_response<W: AsyncWrite + Unpin>(
    writer: &mut W,
    response: &RpcResponse,
) -> Result<()> {
    let bytes = serde_json::to_vec(response)?;
    if bytes.len() <= MAX_RESPONSE_BYTES {
        return write_json_with_limit(writer, response, MAX_RESPONSE_BYTES, "response").await;
    }

    write_json(
        writer,
        &RpcResponse::error(
            response.id.clone(),
            "response_too_large",
            "response exceeds 16 MiB",
        ),
    )
    .await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_default_and_explicit_stats_modes() {
        assert_eq!(
            stats_mode(json!({})).expect("default mode"),
            ProcessMode::None
        );
        assert_eq!(
            stats_mode(json!({"mode": "ram"})).expect("RAM mode"),
            ProcessMode::Ram
        );
        assert!(stats_mode(json!({"mode": "disk"})).is_err());
    }

    #[tokio::test]
    async fn serves_ping_over_a_private_unix_socket() {
        let root = std::env::temp_dir().join(format!("core-ipc-test-{}", Uuid::new_v4()));
        fs::create_dir_all(&root).expect("create test directory");
        let socket_path = root.join("core.sock");
        let config = Config {
            data_dir: root.join("data"),
            runtime_dir: root.clone(),
            socket_path: socket_path.clone(),
        };
        let (listener, _guard) = bind_socket(&socket_path).await.expect("bind test socket");
        let (shutdown_tx, shutdown_rx) = watch::channel(false);
        let server = IpcServer::new(config).expect("create IPC server");
        let server_task = tokio::spawn(server.serve(listener, shutdown_rx));

        let response = send_request(&socket_path, "ping".to_string(), json!({}))
            .await
            .expect("ping daemon");
        assert_eq!(response["pong"], true);

        shutdown_tx.send(true).expect("request shutdown");
        server_task
            .await
            .expect("server task")
            .expect("clean server shutdown");
        fs::remove_dir_all(root).ok();
    }

    #[tokio::test]
    async fn cancels_wallpaper_job_when_client_disconnects() {
        let root = std::env::temp_dir().join(format!("core-cancel-test-{}", Uuid::new_v4()));
        fs::create_dir_all(&root).expect("create test directory");
        let socket_path = root.join("core.sock");
        let config = Config {
            data_dir: root.join("data"),
            runtime_dir: root.clone(),
            socket_path: socket_path.clone(),
        };
        let (listener, _guard) = bind_socket(&socket_path).await.expect("bind test socket");
        let (shutdown_tx, shutdown_rx) = watch::channel(false);
        let server = IpcServer::new(config).expect("create IPC server");
        let server_task = tokio::spawn(server.serve(listener, shutdown_rx));

        let job_id = Uuid::new_v4().to_string();
        let mut stream = UnixStream::connect(&socket_path)
            .await
            .expect("connect cancellable client");
        write_json(
            &mut stream,
            &RpcRequest {
                cancel_on_disconnect: true,
                id: json!("wallpaper-probe"),
                method: "wallpaper.engine.frameProbe".to_string(),
                params: json!({
                    "_job_id": job_id,
                    "path": root.join("missing-frame.png"),
                    "timeout": 5.0,
                }),
            },
        )
        .await
        .expect("send cancellable request");
        drop(stream);
        tokio::time::sleep(Duration::from_millis(100)).await;

        let response = send_request(
            &socket_path,
            "wallpaper.cancel".to_string(),
            json!({"jobId": job_id}),
        )
        .await
        .expect("query cancelled job");
        assert_eq!(response["cancelled"], false);

        shutdown_tx.send(true).expect("request shutdown");
        server_task
            .await
            .expect("server task")
            .expect("clean server shutdown");
        fs::remove_dir_all(root).ok();
    }
}
