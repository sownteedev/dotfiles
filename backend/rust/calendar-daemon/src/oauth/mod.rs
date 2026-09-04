pub mod google;
pub mod microsoft;

use anyhow::{Context, Result, anyhow, bail};
use base64::Engine;
use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::process::Stdio;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::TcpListener;
use tokio::process::Command;
use tokio::time::{Duration as TokioDuration, timeout};
use url::Url;
use uuid::Uuid;

#[derive(Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OAuthToken {
    pub access_token: String,
    #[serde(default)]
    pub refresh_token: String,
    pub expires_at: DateTime<Utc>,
    #[serde(default)]
    pub token_type: String,
    #[serde(default)]
    pub scope: String,
}

impl OAuthToken {
    pub fn needs_refresh(&self) -> bool {
        self.expires_at <= Utc::now() + Duration::minutes(2)
    }
}

#[derive(Clone)]
pub struct AuthorizedAccount {
    pub remote_id: String,
    pub display_name: String,
    pub email: String,
    pub token: OAuthToken,
}

#[derive(Deserialize)]
pub(crate) struct TokenResponse {
    pub access_token: String,
    #[serde(default)]
    pub refresh_token: String,
    #[serde(default = "default_expires_in")]
    pub expires_in: i64,
    #[serde(default)]
    pub token_type: String,
    #[serde(default)]
    pub scope: String,
}

impl TokenResponse {
    pub fn into_token(self, previous: Option<&OAuthToken>) -> OAuthToken {
        OAuthToken {
            access_token: self.access_token,
            refresh_token: if self.refresh_token.is_empty() {
                previous
                    .map(|token| token.refresh_token.clone())
                    .unwrap_or_default()
            } else {
                self.refresh_token
            },
            expires_at: Utc::now() + Duration::seconds(self.expires_in.max(60)),
            token_type: if self.token_type.is_empty() {
                previous
                    .map(|token| token.token_type.clone())
                    .unwrap_or_default()
            } else {
                self.token_type
            },
            scope: if self.scope.is_empty() {
                previous
                    .map(|token| token.scope.clone())
                    .unwrap_or_default()
            } else {
                self.scope
            },
        }
    }
}

fn default_expires_in() -> i64 {
    3600
}

pub(crate) struct LoopbackFlow {
    listener: TcpListener,
    pub redirect_uri: String,
    pub state: String,
    pub verifier: String,
    pub challenge: String,
}

#[derive(Clone, Copy)]
pub(crate) enum RedirectHost {
    LoopbackIp,
    Localhost,
}

impl RedirectHost {
    const fn as_str(self) -> &'static str {
        match self {
            Self::LoopbackIp => "127.0.0.1",
            Self::Localhost => "localhost",
        }
    }
}

impl LoopbackFlow {
    pub async fn bind(redirect_host: RedirectHost) -> Result<Self> {
        let listener = TcpListener::bind(("127.0.0.1", 0))
            .await
            .context("bind OAuth loopback listener")?;
        let address = listener.local_addr()?;
        let verifier = format!("{}{}", Uuid::new_v4().simple(), Uuid::new_v4().simple());
        let digest = Sha256::digest(verifier.as_bytes());
        let challenge = base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(digest);
        Ok(Self {
            listener,
            redirect_uri: format!("http://{}:{}", redirect_host.as_str(), address.port()),
            state: Uuid::new_v4().to_string(),
            verifier,
            challenge,
        })
    }

    pub async fn open_and_wait(self, authorization_url: Url) -> Result<String> {
        open_browser(authorization_url.as_str()).await?;
        timeout(TokioDuration::from_secs(300), self.wait_for_code())
            .await
            .map_err(|_| anyhow!("OAuth authorization timed out after 5 minutes"))?
    }

    async fn wait_for_code(self) -> Result<String> {
        loop {
            let (mut stream, _) = self.listener.accept().await?;
            let mut first_line = String::new();
            {
                let mut reader = BufReader::new(&mut stream);
                reader.read_line(&mut first_line).await?;
            }
            let target = first_line.split_whitespace().nth(1).unwrap_or_default();
            let callback = match Url::parse(&format!("http://127.0.0.1{target}")) {
                Ok(url) => url,
                Err(_) => {
                    respond(&mut stream, 400, "Invalid OAuth callback").await?;
                    continue;
                }
            };

            if callback.path() != "/" {
                respond(&mut stream, 404, "Not found").await?;
                continue;
            }

            let mut code = None;
            let mut state = None;
            let mut oauth_error = None;
            for (key, value) in callback.query_pairs() {
                match key.as_ref() {
                    "code" => code = Some(value.into_owned()),
                    "state" => state = Some(value.into_owned()),
                    "error" => oauth_error = Some(value.into_owned()),
                    _ => {}
                }
            }

            if state.as_deref() != Some(self.state.as_str()) {
                respond(&mut stream, 400, "OAuth state did not match").await?;
                bail!("OAuth state did not match");
            }
            if let Some(error) = oauth_error {
                respond(&mut stream, 400, "Authorization was cancelled").await?;
                bail!("OAuth provider returned: {error}");
            }
            let code = code.context("OAuth callback did not include an authorization code")?;
            respond(
                &mut stream,
                200,
                "SownteeShell Calendar is connected. You can close this tab.",
            )
            .await?;
            return Ok(code);
        }
    }
}

async fn open_browser(url: &str) -> Result<()> {
    let status = Command::new("xdg-open")
        .arg(url)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .await
        .context("open OAuth URL with xdg-open")?;
    if !status.success() {
        bail!("xdg-open could not open the OAuth URL");
    }
    Ok(())
}

async fn respond(stream: &mut tokio::net::TcpStream, status: u16, message: &str) -> Result<()> {
    let status_text = if status == 200 { "OK" } else { "Error" };
    let body = format!(
        "<!doctype html><meta charset=\"utf-8\"><title>SownteeShell Calendar</title>\
         <style>body{{font-family:sans-serif;display:grid;place-items:center;height:100vh;\
         margin:0;background:#101412;color:#e7eee9}}main{{max-width:560px;padding:32px;\
         border-radius:24px;background:#1b211e}}</style><main>{message}</main>"
    );
    let response = format!(
        "HTTP/1.1 {status} {status_text}\r\nContent-Type: text/html; charset=utf-8\r\n\
         Content-Length: {}\r\nConnection: close\r\n\r\n{body}",
        body.len()
    );
    stream.write_all(response.as_bytes()).await?;
    stream.shutdown().await?;
    Ok(())
}

pub(crate) async fn decode_error_response(response: reqwest::Response) -> anyhow::Error {
    let status = response.status();
    let body = response.text().await.unwrap_or_default();
    if let Ok(value) = serde_json::from_str::<serde_json::Value>(&body) {
        let message = value
            .pointer("/error/message")
            .or_else(|| value.get("error_description"))
            .or_else(|| value.get("error"))
            .and_then(|value| value.as_str())
            .unwrap_or(&body);
        return anyhow!("OAuth request failed ({status}): {message}");
    }
    anyhow!("OAuth request failed ({status}): {body}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn refresh_response_preserves_omitted_token_fields() {
        let previous = OAuthToken {
            access_token: "old-access".to_string(),
            refresh_token: "refresh".to_string(),
            expires_at: Utc::now(),
            token_type: "Bearer".to_string(),
            scope: "calendar.readonly".to_string(),
        };
        let refreshed = TokenResponse {
            access_token: "new-access".to_string(),
            refresh_token: String::new(),
            expires_in: 3600,
            token_type: String::new(),
            scope: String::new(),
        }
        .into_token(Some(&previous));

        assert_eq!(refreshed.access_token, "new-access");
        assert_eq!(refreshed.refresh_token, "refresh");
        assert_eq!(refreshed.token_type, "Bearer");
        assert_eq!(refreshed.scope, "calendar.readonly");
    }
}
