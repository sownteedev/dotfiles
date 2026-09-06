use crate::job::JobRegistry;
use crate::network::NetworkClient;
use anyhow::{Context, Result, anyhow, bail};
use reqwest::{RequestBuilder, Response, Url};
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value, json};
use std::env;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::Mutex;
use tokio::task;
use tokio::time::timeout;
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

const AUTHORIZATION_ENDPOINT: &str = "https://accounts.google.com/o/oauth2/v2/auth";
const AUTH_TIMEOUT: Duration = Duration::from_secs(5 * 60);
const MAX_CALLBACK_BYTES: usize = 16 * 1024;
const MAX_RESPONSE_BYTES: usize = 8 * 1024 * 1024;
const MAX_TASKS: usize = 1000;
const TASKS_API_ROOT: &str = "https://tasks.googleapis.com/tasks/v1/";
const TASKS_SCOPE: &str = "https://www.googleapis.com/auth/tasks";
const TOKEN_ENDPOINT: &str = "https://oauth2.googleapis.com/token";

#[derive(Clone)]
pub struct GoogleTasksBackend {
    jobs: JobRegistry,
    network: NetworkClient,
    token_gate: Arc<Mutex<()>>,
    token_path: PathBuf,
}

#[derive(Debug, Default, Deserialize, Serialize)]
struct StoredToken {
    #[serde(default)]
    access_token: String,
    #[serde(default)]
    client_id: String,
    #[serde(default)]
    client_secret: String,
    #[serde(default)]
    expires_at: i64,
    #[serde(default)]
    refresh_token: String,
}

#[derive(Debug, Deserialize)]
struct TokenResponse {
    access_token: String,
    #[serde(default = "default_expires_in")]
    expires_in: i64,
    #[serde(default)]
    refresh_token: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TaskListParams {
    #[serde(default = "default_task_list")]
    list_id: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TaskMutationParams {
    #[serde(default)]
    due: Option<String>,
    #[serde(default = "default_task_list")]
    list_id: String,
    #[serde(default)]
    notes: Option<String>,
    #[serde(default)]
    status: Option<String>,
    #[serde(default)]
    task_id: String,
    #[serde(default)]
    title: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct AuthCredentials {
    client_id: String,
    client_secret: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TaskPage {
    #[serde(default)]
    items: Vec<Value>,
    #[serde(default)]
    next_page_token: String,
}

impl GoogleTasksBackend {
    pub fn new(network: NetworkClient, jobs: JobRegistry) -> Result<Self> {
        Ok(Self {
            jobs,
            network,
            token_gate: Arc::new(Mutex::new(())),
            token_path: default_token_path()?,
        })
    }

    pub async fn request(&self, method: &str, mut params: Value) -> Result<Option<Value>> {
        if !method.starts_with("productivity.googleTasks.") {
            return Ok(None);
        }

        let job_id = JobRegistry::take_job_id(&mut params);
        let job = self.jobs.begin(job_id.as_deref());
        let cancellation = job.cancellation();
        let result = match method {
            "productivity.googleTasks.authStatus" => self.auth_status().await?,
            "productivity.googleTasks.logout" => self.logout().await?,
            "productivity.googleTasks.list" => {
                let params = serde_json::from_value::<TaskListParams>(params)
                    .context("decode Google Tasks list request")?;
                self.list_tasks(&params.list_id, cancellation).await?
            }
            "productivity.googleTasks.create" => {
                let params = serde_json::from_value::<TaskMutationParams>(params)
                    .context("decode Google Tasks create request")?;
                self.create_task(params, cancellation).await?
            }
            "productivity.googleTasks.update" => {
                let params = serde_json::from_value::<TaskMutationParams>(params)
                    .context("decode Google Tasks update request")?;
                self.update_task(params, cancellation).await?
            }
            "productivity.googleTasks.delete" => {
                let params = serde_json::from_value::<TaskMutationParams>(params)
                    .context("decode Google Tasks delete request")?;
                self.delete_task(params, cancellation).await?
            }
            _ => return Ok(None),
        };
        Ok(Some(result))
    }

    pub async fn authenticate_local<F>(
        &self,
        params: Value,
        mut emit: F,
        cancellation: CancellationToken,
    ) -> Result<()>
    where
        F: FnMut(Value) -> Result<()>,
    {
        let credentials = serde_json::from_value::<AuthCredentials>(params)
            .context("decode Google OAuth credentials")?;
        let client_id = credentials.client_id.trim();
        let client_secret = credentials.client_secret.trim();
        if client_id.is_empty() || client_secret.is_empty() {
            bail!("Client ID and Client Secret are required");
        }

        let listener = TcpListener::bind("127.0.0.1:0")
            .await
            .context("bind Google OAuth callback listener")?;
        let redirect_uri = format!(
            "http://127.0.0.1:{}/oauth2callback",
            listener.local_addr()?.port()
        );
        let state = format!("{}{}", Uuid::new_v4().simple(), Uuid::new_v4().simple());
        let mut authorization_url = Url::parse(AUTHORIZATION_ENDPOINT)?;
        authorization_url
            .query_pairs_mut()
            .append_pair("client_id", client_id)
            .append_pair("redirect_uri", &redirect_uri)
            .append_pair("response_type", "code")
            .append_pair("scope", TASKS_SCOPE)
            .append_pair("access_type", "offline")
            .append_pair("prompt", "consent")
            .append_pair("include_granted_scopes", "true")
            .append_pair("state", &state);
        emit(json!({
            "event": "authorization_url",
            "url": authorization_url.as_str(),
        }))?;

        let authorization_code = tokio::select! {
            _ = cancellation.cancelled() => bail!("Google authentication was cancelled"),
            result = timeout(AUTH_TIMEOUT, wait_for_callback(listener, &state)) => {
                result.context("Google authentication timed out")??
            }
        };
        let client = self.network.client()?;
        let response = send_with_cancellation(
            client.post(TOKEN_ENDPOINT).form(&[
                ("client_id", client_id),
                ("client_secret", client_secret),
                ("code", authorization_code.as_str()),
                ("grant_type", "authorization_code"),
                ("redirect_uri", redirect_uri.as_str()),
            ]),
            &cancellation,
        )
        .await
        .context("exchange Google authorization code")?;
        let token_response =
            decode_json_response::<TokenResponse>(response, "Google OAuth").await?;
        if token_response.access_token.trim().is_empty() {
            bail!("Google returned no access token");
        }

        let _guard = self.token_gate.lock().await;
        let previous = read_token_async(self.token_path.clone())
            .await?
            .unwrap_or_default();
        let refresh_token =
            if token_response.refresh_token.is_empty() && previous.client_id == client_id {
                previous.refresh_token
            } else {
                token_response.refresh_token
            };
        write_token_async(
            self.token_path.clone(),
            &StoredToken {
                access_token: token_response.access_token,
                client_id: client_id.to_string(),
                client_secret: client_secret.to_string(),
                expires_at: unix_timestamp().saturating_add(token_response.expires_in),
                refresh_token,
            },
        )
        .await
    }

    async fn auth_status(&self) -> Result<Value> {
        let _guard = self.token_gate.lock().await;
        let token = read_token_async(self.token_path.clone())
            .await?
            .unwrap_or_default();
        let authenticated = !token.client_id.is_empty()
            && ((!token.access_token.is_empty() && token.expires_at > unix_timestamp() + 60)
                || !token.refresh_token.is_empty());
        Ok(json!({
            "authenticated": authenticated,
            "clientId": token.client_id,
            "clientSecret": token.client_secret,
        }))
    }

    async fn logout(&self) -> Result<Value> {
        let _guard = self.token_gate.lock().await;
        remove_token_async(self.token_path.clone()).await?;
        Ok(json!({"success": true}))
    }

    async fn access_token(&self, cancellation: &CancellationToken) -> Result<String> {
        let _guard = self.token_gate.lock().await;
        let mut token = read_token_async(self.token_path.clone())
            .await?
            .context("Google Tasks account is not connected")?;
        if !token.access_token.is_empty() && token.expires_at > unix_timestamp() + 60 {
            return Ok(token.access_token);
        }
        if token.client_id.is_empty() || token.refresh_token.is_empty() {
            bail!("Google Tasks session expired; connect the account again");
        }

        let client = self.network.client()?;
        let response = send_with_cancellation(
            client.post(TOKEN_ENDPOINT).form(&[
                ("client_id", token.client_id.as_str()),
                ("client_secret", token.client_secret.as_str()),
                ("refresh_token", token.refresh_token.as_str()),
                ("grant_type", "refresh_token"),
            ]),
            cancellation,
        )
        .await
        .context("refresh Google Tasks access token")?;
        let refreshed = decode_json_response::<TokenResponse>(response, "Google OAuth").await?;
        if refreshed.access_token.trim().is_empty() {
            bail!("Google returned no access token");
        }
        token.access_token = refreshed.access_token;
        token.expires_at = unix_timestamp().saturating_add(refreshed.expires_in);
        if !refreshed.refresh_token.is_empty() {
            token.refresh_token = refreshed.refresh_token;
        }
        write_token_async(self.token_path.clone(), &token).await?;
        Ok(token.access_token)
    }

    async fn list_tasks(&self, list_id: &str, cancellation: CancellationToken) -> Result<Value> {
        let access_token = self.access_token(&cancellation).await?;
        let client = self.network.client()?;
        let url = tasks_url(list_id, None)?;
        let mut tasks = Vec::new();
        let mut page_token = String::new();

        while tasks.len() < MAX_TASKS {
            let mut request = client.get(url.clone()).bearer_auth(&access_token).query(&[
                ("maxResults", "100"),
                ("showCompleted", "true"),
                ("showHidden", "true"),
            ]);
            if !page_token.is_empty() {
                request = request.query(&[("pageToken", page_token.as_str())]);
            }
            let response = send_with_cancellation(request, &cancellation)
                .await
                .context("list Google Tasks")?;
            let page = decode_json_response::<TaskPage>(response, "Google Tasks").await?;
            tasks.extend(page.items.into_iter().take(MAX_TASKS - tasks.len()));
            page_token = page.next_page_token;
            if page_token.is_empty() {
                break;
            }
        }
        Ok(Value::Array(tasks))
    }

    async fn create_task(
        &self,
        params: TaskMutationParams,
        cancellation: CancellationToken,
    ) -> Result<Value> {
        let title = params.title.unwrap_or_default().trim().to_string();
        if title.is_empty() {
            bail!("Google Task title is required");
        }
        let mut payload = Map::from_iter([("title".to_string(), Value::String(title))]);
        if let Some(notes) = params.notes.filter(|value| !value.is_empty()) {
            payload.insert("notes".to_string(), Value::String(notes));
        }
        if let Some(due) = params.due.as_deref().and_then(normalize_due) {
            payload.insert("due".to_string(), Value::String(due));
        }

        let access_token = self.access_token(&cancellation).await?;
        let response = send_with_cancellation(
            self.network
                .client()?
                .post(tasks_url(&params.list_id, None)?)
                .bearer_auth(access_token)
                .json(&payload),
            &cancellation,
        )
        .await
        .context("create Google Task")?;
        mutation_result(response).await
    }

    async fn update_task(
        &self,
        params: TaskMutationParams,
        cancellation: CancellationToken,
    ) -> Result<Value> {
        if params.task_id.trim().is_empty() {
            bail!("Google Task ID is required");
        }
        let mut payload = Map::new();
        if let Some(title) = params.title {
            payload.insert("title".to_string(), Value::String(title));
        }
        if let Some(notes) = params.notes {
            payload.insert("notes".to_string(), Value::String(notes));
        }
        if let Some(due) = params.due {
            payload.insert(
                "due".to_string(),
                normalize_due(&due)
                    .map(Value::String)
                    .unwrap_or(Value::Null),
            );
        }
        if let Some(status) = params.status {
            if !matches!(status.as_str(), "needsAction" | "completed") {
                bail!("Unsupported Google Task status '{status}'");
            }
            payload.insert("status".to_string(), Value::String(status));
        }
        if payload.is_empty() {
            bail!("Google Task update has no fields");
        }

        let access_token = self.access_token(&cancellation).await?;
        let response = send_with_cancellation(
            self.network
                .client()?
                .patch(tasks_url(&params.list_id, Some(&params.task_id))?)
                .bearer_auth(access_token)
                .json(&payload),
            &cancellation,
        )
        .await
        .context("update Google Task")?;
        mutation_result(response).await
    }

    async fn delete_task(
        &self,
        params: TaskMutationParams,
        cancellation: CancellationToken,
    ) -> Result<Value> {
        if params.task_id.trim().is_empty() {
            bail!("Google Task ID is required");
        }
        let access_token = self.access_token(&cancellation).await?;
        let response = send_with_cancellation(
            self.network
                .client()?
                .delete(tasks_url(&params.list_id, Some(&params.task_id))?)
                .bearer_auth(access_token),
            &cancellation,
        )
        .await
        .context("delete Google Task")?;
        ensure_success(response, "Google Tasks").await?;
        Ok(json!({"success": true}))
    }
}

async fn mutation_result(response: Response) -> Result<Value> {
    let task = decode_json_response::<Value>(response, "Google Tasks").await?;
    Ok(json!({
        "success": true,
        "id": task.get("id").and_then(Value::as_str).unwrap_or_default(),
    }))
}

async fn send_with_cancellation(
    request: RequestBuilder,
    cancellation: &CancellationToken,
) -> Result<Response> {
    tokio::select! {
        _ = cancellation.cancelled() => bail!("Google Tasks request was cancelled"),
        response = request.send() => response.context("send Google request"),
    }
}

async fn decode_json_response<T>(response: Response, label: &str) -> Result<T>
where
    T: DeserializeOwned,
{
    let response = ensure_success(response, label).await?;
    let bytes = response.bytes().await.context("read Google response")?;
    if bytes.len() > MAX_RESPONSE_BYTES {
        bail!("{label} response exceeded 8 MiB");
    }
    serde_json::from_slice(&bytes).with_context(|| format!("decode {label} response"))
}

async fn ensure_success(response: Response, label: &str) -> Result<Response> {
    if response.status().is_success() {
        return Ok(response);
    }
    Err(anyhow!(response_error(response, label).await))
}

async fn response_error(response: Response, label: &str) -> String {
    let status = response.status();
    let bytes = response.bytes().await.unwrap_or_default();
    let retained = &bytes[..bytes.len().min(4096)];
    let parsed = serde_json::from_slice::<Value>(retained).ok();
    let detail = parsed
        .as_ref()
        .and_then(|value| value.pointer("/error/message").and_then(Value::as_str))
        .or_else(|| {
            parsed
                .as_ref()
                .and_then(|value| value.get("error_description").and_then(Value::as_str))
        })
        .or_else(|| {
            parsed
                .as_ref()
                .and_then(|value| value.get("error").and_then(Value::as_str))
        })
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .unwrap_or_else(|| String::from_utf8_lossy(retained).trim().to_string());
    if detail.is_empty() {
        format!("{label} request failed with HTTP {}", status.as_u16())
    } else {
        format!(
            "{label} request failed with HTTP {}: {detail}",
            status.as_u16()
        )
    }
}

fn tasks_url(list_id: &str, task_id: Option<&str>) -> Result<Url> {
    let list_id = normalized_id(list_id, "@default");
    let mut url = Url::parse(TASKS_API_ROOT)?;
    let mut segments = url
        .path_segments_mut()
        .map_err(|_| anyhow!("Google Tasks API URL cannot hold path segments"))?;
    segments.pop_if_empty().extend(["lists", &list_id, "tasks"]);
    if let Some(task_id) = task_id {
        let task_id = normalized_id(task_id, "");
        if task_id.is_empty() {
            bail!("Google Task ID is required");
        }
        segments.push(&task_id);
    }
    drop(segments);
    Ok(url)
}

fn normalized_id(value: &str, fallback: &str) -> String {
    let value = value.trim();
    if value.is_empty() {
        fallback.to_string()
    } else {
        value.to_string()
    }
}

fn normalize_due(value: &str) -> Option<String> {
    let value = value.trim();
    if value.is_empty() {
        return None;
    }
    let date = value.get(..10)?;
    let bytes = date.as_bytes();
    let valid = bytes.len() == 10
        && bytes[4] == b'-'
        && bytes[7] == b'-'
        && bytes
            .iter()
            .enumerate()
            .all(|(index, byte)| matches!(index, 4 | 7) || byte.is_ascii_digit());
    valid.then(|| format!("{date}T00:00:00.000Z"))
}

async fn wait_for_callback(listener: TcpListener, expected_state: &str) -> Result<String> {
    let (mut stream, _) = listener
        .accept()
        .await
        .context("accept Google OAuth callback")?;
    let target = read_request_target(&mut stream).await?;
    let callback_url =
        Url::parse(&format!("http://127.0.0.1{target}")).context("parse Google OAuth callback")?;
    let mut code = String::new();
    let mut error = String::new();
    let mut state = String::new();
    for (key, value) in callback_url.query_pairs() {
        match key.as_ref() {
            "code" => code = value.into_owned(),
            "error" => error = value.into_owned(),
            "state" => state = value.into_owned(),
            _ => {}
        }
    }

    if state != expected_state {
        write_callback_response(&mut stream, 400, "Authentication failed: invalid state.").await?;
        bail!("Google authentication returned an invalid state");
    }
    if !error.is_empty() {
        write_callback_response(&mut stream, 400, "Google authentication was cancelled.").await?;
        bail!("Google authentication was cancelled: {error}");
    }
    if code.is_empty() {
        write_callback_response(&mut stream, 400, "No authorization code was received.").await?;
        bail!("Google returned no authorization code");
    }
    write_callback_response(
        &mut stream,
        200,
        "Authentication complete. You can close this tab.",
    )
    .await?;
    Ok(code)
}

async fn read_request_target(stream: &mut TcpStream) -> Result<String> {
    let mut request = Vec::with_capacity(1024);
    let mut buffer = [0_u8; 1024];
    loop {
        let read = stream.read(&mut buffer).await?;
        if read == 0 {
            break;
        }
        request.extend_from_slice(&buffer[..read]);
        if request.windows(4).any(|window| window == b"\r\n\r\n") {
            break;
        }
        if request.len() > MAX_CALLBACK_BYTES {
            bail!("Google OAuth callback request was too large");
        }
    }
    let request = String::from_utf8(request).context("Google OAuth callback is not UTF-8")?;
    let mut parts = request
        .lines()
        .next()
        .unwrap_or_default()
        .split_whitespace();
    if parts.next() != Some("GET") {
        bail!("Google OAuth callback did not use GET");
    }
    parts
        .next()
        .map(str::to_string)
        .context("Google OAuth callback has no request target")
}

async fn write_callback_response(stream: &mut TcpStream, status: u16, message: &str) -> Result<()> {
    let reason = if status == 200 { "OK" } else { "Bad Request" };
    let body = format!(
        "<!doctype html><meta charset=\"utf-8\"><title>SownteeShell Google Tasks</title>\
         <style>body{{font-family:sans-serif;background:#101817;color:#e9f2f0;display:grid;\
         place-items:center;height:100vh;margin:0}}div{{padding:32px;border-radius:18px;\
         background:#182220}}</style><div>{message}</div>"
    );
    let response = format!(
        "HTTP/1.1 {status} {reason}\r\nContent-Type: text/html; charset=utf-8\r\n\
         Content-Length: {}\r\nConnection: close\r\n\r\n{body}",
        body.len()
    );
    stream.write_all(response.as_bytes()).await?;
    stream.shutdown().await?;
    Ok(())
}

fn default_token_path() -> Result<PathBuf> {
    let state_home = env::var_os("XDG_STATE_HOME")
        .filter(|value| !value.is_empty())
        .map(PathBuf::from)
        .or_else(|| {
            env::var_os("HOME")
                .filter(|value| !value.is_empty())
                .map(PathBuf::from)
                .map(|path| path.join(".local/state"))
        })
        .context("HOME or XDG_STATE_HOME is required for Google Tasks authentication")?;
    Ok(state_home
        .join("sownteeshell")
        .join("google-calendar-token.json"))
}

async fn read_token_async(path: PathBuf) -> Result<Option<StoredToken>> {
    task::spawn_blocking(move || read_token_optional(&path))
        .await
        .context("join Google Tasks token read")?
}

async fn write_token_async(path: PathBuf, token: &StoredToken) -> Result<()> {
    let token = StoredToken {
        access_token: token.access_token.clone(),
        client_id: token.client_id.clone(),
        client_secret: token.client_secret.clone(),
        expires_at: token.expires_at,
        refresh_token: token.refresh_token.clone(),
    };
    task::spawn_blocking(move || write_token(&path, &token))
        .await
        .context("join Google Tasks token write")?
}

async fn remove_token_async(path: PathBuf) -> Result<()> {
    task::spawn_blocking(move || remove_token(&path))
        .await
        .context("join Google Tasks token removal")?
}

fn read_token_optional(path: &Path) -> Result<Option<StoredToken>> {
    let bytes = match fs::read(path) {
        Ok(bytes) => bytes,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(error) => return Err(error).with_context(|| format!("read {}", path.display())),
    };
    let token =
        serde_json::from_slice(&bytes).with_context(|| format!("decode {}", path.display()))?;
    Ok(Some(token))
}

fn write_token(path: &Path, token: &StoredToken) -> Result<()> {
    let parent = path
        .parent()
        .context("Google Tasks token path has no parent")?;
    fs::create_dir_all(parent).with_context(|| format!("create {}", parent.display()))?;
    fs::set_permissions(parent, fs::Permissions::from_mode(0o700))
        .with_context(|| format!("restrict {}", parent.display()))?;

    let file_name = path
        .file_name()
        .and_then(|value| value.to_str())
        .context("Google Tasks token path has no file name")?;
    let temporary = parent.join(format!(".{file_name}.{}.tmp", Uuid::new_v4().simple()));
    let result = (|| -> Result<()> {
        let mut file = OpenOptions::new()
            .create_new(true)
            .write(true)
            .open(&temporary)
            .with_context(|| format!("create {}", temporary.display()))?;
        file.set_permissions(fs::Permissions::from_mode(0o600))?;
        file.write_all(&serde_json::to_vec_pretty(token)?)?;
        file.write_all(b"\n")?;
        file.sync_all()?;
        fs::rename(&temporary, path).with_context(|| format!("publish {}", path.display()))?;
        fs::set_permissions(path, fs::Permissions::from_mode(0o600))?;
        Ok(())
    })();
    if result.is_err() {
        let _ = fs::remove_file(&temporary);
    }
    result
}

fn remove_token(path: &Path) -> Result<()> {
    match fs::remove_file(path) {
        Ok(()) => {}
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
        Err(error) => return Err(error).with_context(|| format!("remove {}", path.display())),
    }
    let legacy_temporary = PathBuf::from(format!("{}.tmp", path.display()));
    if let Err(error) = fs::remove_file(&legacy_temporary)
        && error.kind() != std::io::ErrorKind::NotFound
    {
        return Err(error).with_context(|| format!("remove {}", legacy_temporary.display()));
    }
    Ok(())
}

fn unix_timestamp() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
        .try_into()
        .unwrap_or(i64::MAX)
}

fn default_task_list() -> String {
    "@default".to_string()
}

const fn default_expires_in() -> i64 {
    3600
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_google_due_dates() {
        assert_eq!(
            normalize_due("2026-09-06"),
            Some("2026-09-06T00:00:00.000Z".to_string())
        );
        assert_eq!(
            normalize_due("2026-09-06T08:30:00Z"),
            Some("2026-09-06T00:00:00.000Z".to_string())
        );
        assert_eq!(normalize_due(""), None);
        assert_eq!(normalize_due("06/09/2026"), None);
    }

    #[test]
    fn encodes_task_path_segments() {
        let url = tasks_url("list/one", Some("task/two")).expect("create task URL");
        assert_eq!(
            url.as_str(),
            "https://tasks.googleapis.com/tasks/v1/lists/list%2Fone/tasks/task%2Ftwo"
        );
    }

    #[test]
    fn token_round_trip_is_private_and_python_compatible() {
        let root = env::temp_dir().join(format!("google-tasks-test-{}", Uuid::new_v4()));
        let path = root.join("sownteeshell/google-calendar-token.json");
        let token = StoredToken {
            access_token: "access".to_string(),
            client_id: "client".to_string(),
            client_secret: "secret".to_string(),
            expires_at: 123,
            refresh_token: "refresh".to_string(),
        };
        write_token(&path, &token).expect("write token");
        let stored = read_token_optional(&path)
            .expect("read token")
            .expect("token exists");
        assert_eq!(stored.client_id, "client");
        assert_eq!(
            fs::metadata(&path)
                .expect("token metadata")
                .permissions()
                .mode()
                & 0o777,
            0o600
        );
        fs::remove_dir_all(root).ok();
    }
}
