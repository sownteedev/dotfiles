use super::decode;
use crate::command::{command_path, run_bounded};
use anyhow::{Context, Result, bail};
use regex::Regex;
use serde::Deserialize;
use serde_json::{Value, json};
use std::collections::HashMap;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tokio::task;
use tokio::time::sleep;
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

const AMD_VENDOR: &str = "0x1002";
const COMMAND_OUTPUT_LIMIT: usize = 2 * 1024 * 1024;
const COMMAND_TIMEOUT: Duration = Duration::from_secs(15);
const INTEL_VENDOR: &str = "0x8086";
const NVIDIA_VENDOR: &str = "0x10de";
const SUNSHINE_UNITS: &[&str] = &[
    "app-dev.lizardbyte.app.Sunshine.service",
    "sunshine.service",
];

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct ApplyParams {
    config_path: PathBuf,
    display_id: i64,
    output: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct StatusParams {
    config_path: PathBuf,
}

struct Profile {
    adapter_name: String,
    card: String,
    encoder: String,
    label: String,
    vendor: String,
}

pub async fn status(params: Value, cancellation: CancellationToken) -> Result<Value> {
    let params: StatusParams = decode(params, "Sunshine status")?;
    Ok(
        match current_status(&params.config_path, cancellation).await {
            Ok(mut value) => {
                if let Some(object) = value.as_object_mut() {
                    object.insert("ok".into(), Value::Bool(true));
                }
                value
            }
            Err(error) => {
                json!({"ok": false, "error": error.to_string(), "message": error.to_string()})
            }
        },
    )
}

pub async fn apply(params: Value, cancellation: CancellationToken) -> Result<Value> {
    let params: ApplyParams = decode(params, "Sunshine profile")?;
    let output_name = params.output.clone();
    Ok(match apply_inner(params, cancellation).await {
        Ok(mut value) => {
            if let Some(object) = value.as_object_mut() {
                object.insert("ok".into(), Value::Bool(true));
            }
            value
        }
        Err(error) => {
            json!({"ok": false, "error": error.to_string(), "message": error.to_string(), "output": output_name})
        }
    })
}

async fn apply_inner(params: ApplyParams, cancellation: CancellationToken) -> Result<Value> {
    let mut display_id = params.display_id.max(0);
    let output_for_profile = params.output.clone();
    let config_for_profile = params.config_path.clone();
    let (profile, mut changed) = task::spawn_blocking(move || {
        let profile = profile_for_output(&output_for_profile)?;
        let display_id_text = display_id.to_string();
        let values = HashMap::from([
            ("adapter_name", profile.adapter_name.as_str()),
            ("encoder", profile.encoder.as_str()),
            ("output_name", display_id_text.as_str()),
        ]);
        let changed = update_config(&config_for_profile, &values)?;
        Ok::<_, anyhow::Error>((profile, changed))
    })
    .await
    .context("join Sunshine profile preparation")??;

    let restart_started = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
        .saturating_sub(1);
    let mut unit = restart_sunshine(cancellation.clone()).await?;
    let detected_id =
        monitor_id_from_journal(&unit, &params.output, restart_started, cancellation.clone()).await;
    if let Some(detected_id) = detected_id
        && detected_id != display_id
    {
        display_id = detected_id;
        let display_id_text = display_id.to_string();
        let config_path = params.config_path.clone();
        changed |= task::spawn_blocking(move || {
            update_config(
                &config_path,
                &HashMap::from([("output_name", display_id_text.as_str())]),
            )
        })
        .await
        .context("join Sunshine display ID update")??;
        unit = restart_sunshine(cancellation).await?;
    }

    Ok(json!({
        "adapter_name": profile.adapter_name,
        "card": profile.card,
        "encoder": profile.encoder,
        "label": profile.label,
        "vendor": profile.vendor,
        "changed": changed,
        "display_id": display_id,
        "display_verified": detected_id.is_some(),
        "output": params.output,
        "service": unit,
    }))
}

async fn current_status(path: &Path, cancellation: CancellationToken) -> Result<Value> {
    let config_path = path.to_path_buf();
    let config = task::spawn_blocking(move || read_config(&config_path))
        .await
        .context("join Sunshine config read")?;
    let encoder = config.get("encoder").cloned().unwrap_or_default();
    let adapter_name = config.get("adapter_name").cloned().unwrap_or_default();
    let raw_display_id = config.get("output_name").cloned().unwrap_or_default();
    if encoder.is_empty() || raw_display_id.is_empty() {
        return Ok(json!({"configured": false}));
    }
    let display_id = raw_display_id
        .parse::<i64>()
        .with_context(|| format!("Invalid Sunshine output_name: {raw_display_id}"))?;

    let mut output = String::new();
    let mut service = String::new();
    for unit in active_sunshine_units(cancellation.clone()).await {
        if let Some(detected_output) =
            output_from_journal(&unit, display_id, cancellation.clone()).await
        {
            output = detected_output;
            service = unit;
            break;
        }
    }
    Ok(json!({
        "adapter_name": adapter_name,
        "configured": true,
        "display_id": display_id,
        "encoder": encoder,
        "label": encoder_label(&encoder, &adapter_name),
        "output": output,
        "service": service,
    }))
}

fn profile_for_output(connector: &str) -> Result<Profile> {
    let card = connector_card(connector)?;
    let vendor = read_text(
        &Path::new("/sys/class/drm")
            .join(&card)
            .join("device/vendor"),
    )?
    .to_ascii_lowercase();
    let (encoder, label) = match vendor.as_str() {
        INTEL_VENDOR => ("vaapi", "Intel VA-API"),
        NVIDIA_VENDOR => ("nvenc", "NVIDIA NVENC"),
        _ => bail!("Unsupported GPU vendor for {connector}: {vendor}"),
    };
    Ok(Profile {
        adapter_name: render_node(&card)?,
        card,
        encoder: encoder.into(),
        label: label.into(),
        vendor,
    })
}

fn connector_card(connector: &str) -> Result<String> {
    let suffix = format!("-{connector}");
    let mut matches = fs::read_dir("/sys/class/drm")?
        .flatten()
        .filter_map(|entry| {
            let name = entry.file_name().to_string_lossy().into_owned();
            (name.starts_with("card") && name.ends_with(&suffix)).then_some(name)
        })
        .collect::<Vec<_>>();
    matches.sort();
    let name = matches
        .first()
        .with_context(|| format!("DRM connector not found: {connector}"))?;
    let card = name
        .split_once('-')
        .map(|(card, _)| card)
        .unwrap_or_default();
    if !card.starts_with("card")
        || !card[4..]
            .chars()
            .all(|character| character.is_ascii_digit())
    {
        bail!("Could not resolve the DRM card for {connector}");
    }
    Ok(card.to_string())
}

fn render_node(card: &str) -> Result<String> {
    let directory = Path::new("/sys/class/drm").join(card).join("device/drm");
    let mut candidates = fs::read_dir(&directory)?
        .flatten()
        .filter_map(|entry| {
            let name = entry.file_name().to_string_lossy().into_owned();
            name.starts_with("renderD").then_some(name)
        })
        .collect::<Vec<_>>();
    candidates.sort();
    let node = candidates
        .first()
        .with_context(|| format!("No render node is available for {card}"))?;
    Ok(format!("/dev/dri/{node}"))
}

fn encoder_label(encoder: &str, adapter_name: &str) -> String {
    match encoder.to_ascii_lowercase().as_str() {
        "nvenc" => "NVIDIA NVENC".into(),
        "vaapi" => {
            let render_node = Path::new(adapter_name)
                .file_name()
                .and_then(|name| name.to_str())
                .unwrap_or_default();
            let vendor = read_text(
                &Path::new("/sys/class/drm")
                    .join(render_node)
                    .join("device/vendor"),
            )
            .unwrap_or_default()
            .to_ascii_lowercase();
            match vendor.as_str() {
                INTEL_VENDOR => "Intel VA-API".into(),
                AMD_VENDOR => "AMD VA-API".into(),
                _ => "VA-API".into(),
            }
        }
        "" => "Sunshine".into(),
        value => value.to_ascii_uppercase(),
    }
}

fn read_config(path: &Path) -> HashMap<String, String> {
    let Ok(content) = fs::read_to_string(path) else {
        return HashMap::new();
    };
    config_pattern()
        .captures_iter(&content)
        .filter_map(|captures| {
            Some((
                captures.get(1)?.as_str().to_string(),
                captures
                    .get(2)?
                    .as_str()
                    .trim()
                    .trim_matches('"')
                    .to_string(),
            ))
        })
        .collect()
}

fn update_config(path: &Path, values: &HashMap<&str, &str>) -> Result<bool> {
    let content = fs::read_to_string(path).unwrap_or_default();
    let mut remaining = values.clone();
    let mut updated = Vec::new();
    for line in content.lines() {
        let key = config_key_pattern()
            .captures(line)
            .and_then(|captures| captures.get(1))
            .map(|value| value.as_str());
        if let Some(value) = key.and_then(|key| remaining.remove(key).map(|value| (key, value))) {
            updated.push(format!("{} = {}", value.0, value.1));
        } else {
            updated.push(line.to_string());
        }
    }
    for (key, value) in remaining {
        updated.push(format!("{key} = {value}"));
    }
    let next_content = format!("{}\n", updated.join("\n").trim());
    let normalized_current = if content.trim().is_empty() {
        String::new()
    } else {
        format!("{}\n", content.trim())
    };
    if next_content == normalized_current {
        return Ok(false);
    }
    write_atomic(path, &next_content)?;
    Ok(true)
}

async fn restart_sunshine(cancellation: CancellationToken) -> Result<String> {
    let systemctl = command_path("systemctl").context("systemctl is unavailable")?;
    let mut errors = Vec::new();
    for unit in SUNSHINE_UNITS {
        let output = run_bounded(
            &systemctl,
            &["--user", "restart", unit],
            COMMAND_TIMEOUT,
            cancellation.clone(),
            COMMAND_OUTPUT_LIMIT,
        )
        .await?;
        if output.status.success() {
            return Ok((*unit).to_string());
        }
        errors.push(command_error(&output.stdout, &output.stderr, ""));
    }
    bail!(
        "{}",
        errors
            .into_iter()
            .find(|error| !error.is_empty())
            .unwrap_or_else(|| "Could not restart Sunshine".into())
    )
}

async fn active_sunshine_units(cancellation: CancellationToken) -> Vec<String> {
    let Some(systemctl) = command_path("systemctl") else {
        return SUNSHINE_UNITS.iter().map(|unit| (*unit).into()).collect();
    };
    let mut active = Vec::new();
    for unit in SUNSHINE_UNITS {
        if let Ok(output) = run_bounded(
            &systemctl,
            &["--user", "is-active", "--quiet", unit],
            Duration::from_secs(4),
            cancellation.clone(),
            COMMAND_OUTPUT_LIMIT,
        )
        .await
            && output.status.success()
        {
            active.push((*unit).to_string());
        }
    }
    if active.is_empty() {
        SUNSHINE_UNITS.iter().map(|unit| (*unit).into()).collect()
    } else {
        active
    }
}

async fn output_from_journal(
    unit: &str,
    display_id: i64,
    cancellation: CancellationToken,
) -> Option<String> {
    let journalctl = command_path("journalctl")?;
    let output = run_bounded(
        &journalctl,
        &[
            "--user",
            "-u",
            unit,
            "--grep",
            "Monitor [0-9]+ is ",
            "-n",
            "100",
            "--no-pager",
            "-o",
            "cat",
        ],
        COMMAND_TIMEOUT,
        cancellation,
        COMMAND_OUTPUT_LIMIT,
    )
    .await
    .ok()?;
    if !output.status.success() {
        return None;
    }
    monitor_matches(&String::from_utf8_lossy(&output.stdout))
        .into_iter()
        .rev()
        .find_map(|(id, output)| (id == display_id).then_some(output))
}

async fn monitor_id_from_journal(
    unit: &str,
    connector: &str,
    since_epoch: u64,
    cancellation: CancellationToken,
) -> Option<i64> {
    let journalctl = command_path("journalctl")?;
    let since = format!("--since=@{since_epoch}");
    let deadline = Instant::now() + Duration::from_secs(4);
    while Instant::now() < deadline {
        let output = run_bounded(
            &journalctl,
            &["--user", "-u", unit, &since, "--no-pager", "-o", "cat"],
            Duration::from_secs(3),
            cancellation.clone(),
            COMMAND_OUTPUT_LIMIT,
        )
        .await
        .ok()?;
        if output.status.success()
            && let Some(id) = monitor_matches(&String::from_utf8_lossy(&output.stdout))
                .into_iter()
                .rev()
                .find_map(|(id, output)| (output == connector).then_some(id))
        {
            return Some(id);
        }
        sleep(Duration::from_millis(150)).await;
    }
    None
}

fn monitor_matches(value: &str) -> Vec<(i64, String)> {
    monitor_pattern()
        .captures_iter(value)
        .filter_map(|captures| {
            Some((
                captures.get(1)?.as_str().parse().ok()?,
                captures.get(2)?.as_str().trim().to_string(),
            ))
        })
        .collect()
}

fn write_atomic(path: &Path, content: &str) -> Result<()> {
    let directory = path.parent().unwrap_or_else(|| Path::new("."));
    fs::create_dir_all(directory)
        .with_context(|| format!("create directory {}", directory.display()))?;
    let temporary = directory.join(format!(".sunshine-config-{}.tmp", Uuid::new_v4()));
    let result = (|| -> Result<()> {
        let mut file = fs::OpenOptions::new()
            .create_new(true)
            .write(true)
            .open(&temporary)?;
        file.write_all(content.as_bytes())?;
        file.flush()?;
        fs::rename(&temporary, path)
            .with_context(|| format!("replace Sunshine config {}", path.display()))?;
        Ok(())
    })();
    if result.is_err() {
        let _ = fs::remove_file(&temporary);
    }
    result
}

fn read_text(path: &Path) -> Result<String> {
    Ok(fs::read_to_string(path)
        .with_context(|| format!("read {}", path.display()))?
        .trim()
        .to_string())
}

fn command_error(stdout: &[u8], stderr: &[u8], fallback: &str) -> String {
    let selected = if stderr.is_empty() { stdout } else { stderr };
    String::from_utf8_lossy(selected)
        .trim()
        .lines()
        .next_back()
        .unwrap_or(fallback)
        .to_string()
}

fn config_pattern() -> &'static Regex {
    static PATTERN: OnceLock<Regex> = OnceLock::new();
    PATTERN.get_or_init(|| Regex::new(r"(?m)^\s*([A-Za-z0-9_]+)\s*=\s*(.*?)\s*$").unwrap())
}

fn config_key_pattern() -> &'static Regex {
    static PATTERN: OnceLock<Regex> = OnceLock::new();
    PATTERN.get_or_init(|| Regex::new(r"^\s*([A-Za-z0-9_]+)\s*=").unwrap())
}

fn monitor_pattern() -> &'static Regex {
    static PATTERN: OnceLock<Regex> = OnceLock::new();
    PATTERN.get_or_init(|| Regex::new(r"Monitor\s+(\d+)\s+is\s+([^:]+):").unwrap())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn labels_known_encoders() {
        assert_eq!(encoder_label("nvenc", ""), "NVIDIA NVENC");
        assert_eq!(encoder_label("software", ""), "SOFTWARE");
    }

    #[test]
    fn parses_monitor_lines() {
        assert_eq!(
            monitor_matches("Monitor 0 is eDP-1:\nMonitor 2 is DP-1:\n"),
            vec![(0, "eDP-1".into()), (2, "DP-1".into())]
        );
    }

    #[test]
    fn updates_sunshine_values_without_dropping_other_lines() {
        let root = std::env::temp_dir().join(format!("sunshine-test-{}", Uuid::new_v4()));
        fs::create_dir_all(&root).unwrap();
        let path = root.join("sunshine.conf");
        fs::write(&path, "encoder = vaapi\ncustom = keep\n").unwrap();
        assert!(
            update_config(
                &path,
                &HashMap::from([("encoder", "nvenc"), ("output_name", "1")])
            )
            .unwrap()
        );
        let content = fs::read_to_string(&path).unwrap();
        assert!(content.contains("encoder = nvenc"));
        assert!(content.contains("custom = keep"));
        assert!(content.contains("output_name = 1"));
        fs::remove_dir_all(root).unwrap();
    }
}
