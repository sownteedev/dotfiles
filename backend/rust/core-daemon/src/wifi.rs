use crate::command::{command_path, run_bounded, run_bounded_input};
use crate::job::JobRegistry;
use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::env;
use std::fs::{self, DirBuilder};
use std::os::unix::fs::{DirBuilderExt, MetadataExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::task;

const COMMAND_OUTPUT_LIMIT: usize = 256 * 1024;
const COMMAND_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Clone)]
pub struct WifiBackend {
    jobs: JobRegistry,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct DeleteParams {
    path: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct GenerateParams {
    #[serde(default)]
    open_network: bool,
    #[serde(default)]
    profile: String,
    ssid: String,
}

#[derive(Debug)]
struct WifiQrError(String);

impl WifiQrError {
    fn new(message: impl Into<String>) -> Self {
        Self(message.into())
    }

    fn response(self) -> Value {
        json!({"ok": false, "error": self.0})
    }
}

impl WifiBackend {
    pub fn new(jobs: JobRegistry) -> Self {
        Self { jobs }
    }

    pub async fn request(&self, method: &str, mut params: Value) -> Result<Option<Value>> {
        if !method.starts_with("wifi.") {
            return Ok(None);
        }
        let job_id = JobRegistry::take_job_id(&mut params);
        let job = self.jobs.begin(job_id.as_deref());
        let result = match method {
            "wifi.qr.cleanup" => cleanup_response().await,
            "wifi.qr.delete" => {
                let params: DeleteParams =
                    serde_json::from_value(params).context("decode Wi-Fi QR delete request")?;
                delete_response(params).await
            }
            "wifi.qr.generate" => {
                let params: GenerateParams =
                    serde_json::from_value(params).context("decode Wi-Fi QR request")?;
                generate_response(params, job.cancellation()).await
            }
            _ => return Ok(None),
        };
        Ok(Some(result))
    }
}

async fn generate_response(
    params: GenerateParams,
    cancellation: tokio_util::sync::CancellationToken,
) -> Value {
    match generate_qr(&params, cancellation).await {
        Ok(path) => json!({"ok": true, "path": path, "ssid": params.ssid}),
        Err(error) => error.response(),
    }
}

async fn delete_response(params: DeleteParams) -> Value {
    match task::spawn_blocking(move || delete_qr(&params.path)).await {
        Ok(Ok(())) => json!({"ok": true}),
        Ok(Err(error)) => error.response(),
        Err(_) => WifiQrError::new("Could not remove the Wi-Fi QR code.").response(),
    }
}

async fn cleanup_response() -> Value {
    match task::spawn_blocking(|| {
        private_directory().and_then(|directory| remove_stale_files(&directory))
    })
    .await
    {
        Ok(Ok(())) => json!({"ok": true}),
        Ok(Err(error)) => error.response(),
        Err(_) => WifiQrError::new("Could not clean temporary Wi-Fi QR codes.").response(),
    }
}

async fn generate_qr(
    params: &GenerateParams,
    cancellation: tokio_util::sync::CancellationToken,
) -> std::result::Result<PathBuf, WifiQrError> {
    let ssid = params.ssid.as_str();
    if ssid.is_empty() {
        return Err(WifiQrError::new("The Wi-Fi name is empty."));
    }
    if !params.open_network && params.profile.is_empty() {
        return Err(WifiQrError::new(
            "The saved NetworkManager profile could not be found.",
        ));
    }

    let payload = if params.open_network {
        wifi_payload("nopass", ssid, "")
    } else {
        saved_wifi_payload(ssid, &params.profile, cancellation.clone()).await?
    };
    let ssid_for_path = ssid.to_string();
    let (output_path, temporary_path) =
        task::spawn_blocking(move || prepare_qr_paths(&ssid_for_path))
            .await
            .map_err(|_| WifiQrError::new("Could not prepare the Wi-Fi QR code."))??;
    let qrencode = command_path("qrencode")
        .ok_or_else(|| WifiQrError::new("The qrencode package is not installed."))?;
    let temporary = temporary_path.to_string_lossy().into_owned();
    let encoded = run_bounded_input(
        &qrencode,
        &[
            "-8", "-l", "M", "-m", "4", "-s", "8", "-t", "PNG", "-o", &temporary,
        ],
        payload.as_bytes(),
        COMMAND_TIMEOUT,
        cancellation,
        COMMAND_OUTPUT_LIMIT,
    )
    .await;
    let output = match encoded {
        Ok(output) => output,
        Err(error) => {
            let _ = tokio::fs::remove_file(&temporary_path).await;
            return Err(WifiQrError::new(
                if error.to_string().contains("timed out") {
                    "Creating the Wi-Fi QR code timed out."
                } else {
                    "Could not create the Wi-Fi QR code."
                },
            ));
        }
    };
    if !output.status.success() || output.stdout_truncated || output.stderr_truncated {
        let _ = tokio::fs::remove_file(&temporary_path).await;
        return Err(WifiQrError::new("Could not create the Wi-Fi QR code."));
    }
    let temporary_for_publish = temporary_path.clone();
    let output_for_publish = output_path.clone();
    task::spawn_blocking(move || finalize_qr(&temporary_for_publish, &output_for_publish))
        .await
        .map_err(|_| WifiQrError::new("Could not create the Wi-Fi QR code."))??;
    Ok(output_path)
}

async fn saved_wifi_payload(
    ssid: &str,
    profile: &str,
    cancellation: tokio_util::sync::CancellationToken,
) -> std::result::Result<String, WifiQrError> {
    let key_management = nmcli_value(
        "802-11-wireless-security.key-mgmt",
        profile,
        false,
        cancellation.clone(),
    )
    .await?
    .to_ascii_lowercase();
    if !matches!(key_management.as_str(), "wpa-psk" | "sae" | "wpa-psk-sae") {
        return Err(WifiQrError::new(
            "Only WPA/WPA2/WPA3 personal networks can be shared by QR code.",
        ));
    }
    let password = nmcli_value("802-11-wireless-security.psk", profile, true, cancellation).await?;
    if password.is_empty() {
        return Err(WifiQrError::new(
            "The saved password could not be retrieved.",
        ));
    }
    Ok(wifi_payload("WPA", ssid, &password))
}

async fn nmcli_value(
    field: &str,
    profile: &str,
    preserve_whitespace: bool,
    cancellation: tokio_util::sync::CancellationToken,
) -> std::result::Result<String, WifiQrError> {
    let nmcli = command_path("nmcli")
        .ok_or_else(|| WifiQrError::new("NetworkManager tools are not installed."))?;
    let output = run_bounded(
        &nmcli,
        &[
            "--show-secrets",
            "--escape",
            "no",
            "--get-values",
            field,
            "connection",
            "show",
            profile,
        ],
        COMMAND_TIMEOUT,
        cancellation,
        COMMAND_OUTPUT_LIMIT,
    )
    .await
    .map_err(|error| {
        if error.to_string().contains("timed out") {
            WifiQrError::new("Reading the saved Wi-Fi credentials timed out.")
        } else {
            WifiQrError::new("Could not read the saved Wi-Fi credentials.")
        }
    })?;
    if !output.status.success() || output.stdout_truncated {
        return Err(WifiQrError::new(
            "Could not read the saved Wi-Fi credentials.",
        ));
    }
    let mut value = String::from_utf8_lossy(&output.stdout).into_owned();
    if value.ends_with('\n') {
        value.pop();
        if value.ends_with('\r') {
            value.pop();
        }
    }
    Ok(if preserve_whitespace {
        value
    } else {
        value.trim().to_string()
    })
}

fn wifi_payload(security: &str, ssid: &str, password: &str) -> String {
    let mut payload = format!("WIFI:T:{security};S:{};", escape_wifi_value(ssid));
    if !security.eq_ignore_ascii_case("nopass") {
        payload.push_str(&format!("P:{};", escape_wifi_value(password)));
    }
    payload.push(';');
    payload
}

fn escape_wifi_value(value: &str) -> String {
    let mut escaped = String::with_capacity(value.len());
    for character in value.chars() {
        if matches!(character, '\\' | ';' | ',' | ':' | '"') {
            escaped.push('\\');
        }
        escaped.push(character);
    }
    escaped
}

fn prepare_qr_paths(ssid: &str) -> std::result::Result<(PathBuf, PathBuf), WifiQrError> {
    let directory = private_directory()?;
    remove_stale_files(&directory)?;
    let digest = format!("{:x}", Sha256::digest(ssid.as_bytes()));
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos();
    let output_path = directory.join(format!("wifi-{}-{timestamp}.png", &digest[..12]));
    let temporary_path = output_path.with_extension("tmp.png");
    Ok((output_path, temporary_path))
}

fn finalize_qr(temporary: &Path, output: &Path) -> std::result::Result<(), WifiQrError> {
    if !fs::metadata(temporary).is_ok_and(|metadata| metadata.is_file() && metadata.len() > 0) {
        let _ = fs::remove_file(temporary);
        return Err(WifiQrError::new("Could not create the Wi-Fi QR code."));
    }
    fs::set_permissions(temporary, fs::Permissions::from_mode(0o600))
        .map_err(|_| WifiQrError::new("Could not create the Wi-Fi QR code."))?;
    fs::rename(temporary, output)
        .map_err(|_| WifiQrError::new("Could not create the Wi-Fi QR code."))
}

fn private_directory() -> std::result::Result<PathBuf, WifiQrError> {
    let uid = current_uid()?;
    let directory = env::temp_dir().join(format!("sowntee-wifi-qr-{uid}"));
    match fs::symlink_metadata(&directory) {
        Ok(metadata)
            if metadata.file_type().is_symlink() || !metadata.is_dir() || metadata.uid() != uid =>
        {
            return Err(WifiQrError::new(
                "The private QR directory is not safe to use.",
            ));
        }
        Ok(_) => {}
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            let mut builder = DirBuilder::new();
            builder.mode(0o700);
            builder
                .create(&directory)
                .map_err(|_| WifiQrError::new("The private QR directory is not safe to use."))?;
        }
        Err(_) => {
            return Err(WifiQrError::new(
                "The private QR directory is not safe to use.",
            ));
        }
    }
    fs::set_permissions(&directory, fs::Permissions::from_mode(0o700))
        .map_err(|_| WifiQrError::new("The private QR directory is not safe to use."))?;
    Ok(directory)
}

fn current_uid() -> std::result::Result<u32, WifiQrError> {
    let status = fs::read_to_string("/proc/self/status")
        .map_err(|_| WifiQrError::new("Could not determine the current user."))?;
    status
        .lines()
        .find_map(|line| line.strip_prefix("Uid:"))
        .and_then(|value| value.split_whitespace().next())
        .and_then(|value| value.parse::<u32>().ok())
        .ok_or_else(|| WifiQrError::new("Could not determine the current user."))
}

fn remove_stale_files(directory: &Path) -> std::result::Result<(), WifiQrError> {
    for entry in fs::read_dir(directory)
        .map_err(|_| WifiQrError::new("Could not clean temporary Wi-Fi QR codes."))?
    {
        let entry =
            entry.map_err(|_| WifiQrError::new("Could not clean temporary Wi-Fi QR codes."))?;
        let name = entry.file_name().to_string_lossy().into_owned();
        if !name.starts_with("wifi-") || !name.contains(".png") {
            continue;
        }
        let metadata = fs::symlink_metadata(entry.path())
            .map_err(|_| WifiQrError::new("Could not clean temporary Wi-Fi QR codes."))?;
        if metadata.is_file() && !metadata.file_type().is_symlink() {
            fs::remove_file(entry.path())
                .map_err(|_| WifiQrError::new("Could not clean temporary Wi-Fi QR codes."))?;
        }
    }
    Ok(())
}

fn delete_qr(path_value: &str) -> std::result::Result<(), WifiQrError> {
    let directory = fs::canonicalize(private_directory()?)
        .map_err(|_| WifiQrError::new("The private QR directory is not safe to use."))?;
    let requested = PathBuf::from(path_value);
    let file_name = requested
        .file_name()
        .and_then(|value| value.to_str())
        .unwrap_or_default();
    if !file_name.starts_with("wifi-")
        || requested.extension().and_then(|value| value.to_str()) != Some("png")
    {
        return Err(WifiQrError::new(
            "Refusing to remove a file outside the private QR directory.",
        ));
    }
    let parent = requested
        .parent()
        .and_then(|path| fs::canonicalize(path).ok())
        .ok_or_else(|| {
            WifiQrError::new("Refusing to remove a file outside the private QR directory.")
        })?;
    if parent != directory {
        return Err(WifiQrError::new(
            "Refusing to remove a file outside the private QR directory.",
        ));
    }
    match fs::symlink_metadata(&requested) {
        Ok(metadata) if metadata.file_type().is_symlink() => Err(WifiQrError::new(
            "Refusing to remove a file outside the private QR directory.",
        )),
        Ok(metadata) if metadata.is_file() => fs::remove_file(requested)
            .map_err(|_| WifiQrError::new("Could not remove the Wi-Fi QR code.")),
        Ok(_) => Err(WifiQrError::new("Could not remove the Wi-Fi QR code.")),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(_) => Err(WifiQrError::new("Could not remove the Wi-Fi QR code.")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn escapes_wifi_payload_values() {
        assert_eq!(
            wifi_payload("WPA", "Office: 2,4G", "a;b\\c\""),
            "WIFI:T:WPA;S:Office\\: 2\\,4G;P:a\\;b\\\\c\\\";;"
        );
        assert_eq!(
            wifi_payload("nopass", "Guest", ""),
            "WIFI:T:nopass;S:Guest;;"
        );
    }

    #[test]
    fn rejects_delete_paths_outside_the_private_directory() {
        let result = delete_qr("/tmp/not-a-sowntee-qr.png");
        assert!(result.is_err());
    }
}
