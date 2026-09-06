use super::decode;
use crate::command::{command_path, run_bounded};
use anyhow::{Context, Result, bail};
use regex::Regex;
use serde::Deserialize;
use serde_json::{Value, json};
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use std::time::Duration;
use tokio::task;
use tokio_util::sync::CancellationToken;

const COMMAND_OUTPUT_LIMIT: usize = 256 * 1024;
const COMMAND_TIMEOUT: Duration = Duration::from_secs(6);

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct GetParams {
    output: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SetParams {
    #[serde(default)]
    bus: Option<u32>,
    #[serde(default)]
    maximum: Option<u32>,
    output: String,
    value: f64,
}

struct Brightness {
    bus: u32,
    current: u32,
    maximum: u32,
}

pub async fn get(params: Value, cancellation: CancellationToken) -> Result<Value> {
    let params: GetParams = decode(params, "DDC brightness")?;
    Ok(match get_brightness(&params.output, cancellation).await {
        Ok(brightness) => response(&params.output, Some(brightness), None),
        Err(error) => response(&params.output, None, Some(error.to_string())),
    })
}

pub async fn set(params: Value, cancellation: CancellationToken) -> Result<Value> {
    let params: SetParams = decode(params, "DDC brightness")?;
    let result = set_brightness(params, cancellation).await;
    Ok(match result {
        Ok((output, brightness)) => response(&output, Some(brightness), None),
        Err((output, error)) => response(&output, None, Some(error)),
    })
}

async fn get_brightness(output: &str, cancellation: CancellationToken) -> Result<Brightness> {
    let ddcutil = command_path("ddcutil").context("Install ddcutil to control this display")?;
    let connector = output.to_string();
    let bus = task::spawn_blocking(move || connector_bus(&connector))
        .await
        .context("join DDC connector lookup")?
        .context("This display connection does not expose DDC/CI")?;
    let bus_text = bus.to_string();
    let result = run_bounded(
        &ddcutil,
        &["--bus", &bus_text, "getvcp", "10", "--brief"],
        COMMAND_TIMEOUT,
        cancellation,
        COMMAND_OUTPUT_LIMIT,
    )
    .await?;
    if !result.status.success() {
        bail!(
            "{}",
            command_error(&result.stdout, &result.stderr, "ddcutil failed")
        );
    }
    let (current, maximum) = parse_brightness(&String::from_utf8_lossy(&result.stdout))?;
    Ok(Brightness {
        bus,
        current,
        maximum,
    })
}

async fn set_brightness(
    params: SetParams,
    cancellation: CancellationToken,
) -> std::result::Result<(String, Brightness), (String, String)> {
    let output = params.output;
    let result = async {
        let ddcutil = command_path("ddcutil").context("Install ddcutil to control this display")?;
        let (bus, maximum) = match (params.bus, params.maximum) {
            (Some(bus), Some(maximum)) if maximum > 0 => (bus, maximum),
            _ => {
                let current = get_brightness(&output, cancellation.clone()).await?;
                (current.bus, current.maximum)
            }
        };
        let target = (params.value.clamp(0.0, 1.0) * f64::from(maximum)).round() as u32;
        let bus_text = bus.to_string();
        let target_text = target.to_string();
        let result = run_bounded(
            &ddcutil,
            &["--bus", &bus_text, "setvcp", "10", &target_text],
            COMMAND_TIMEOUT,
            cancellation,
            COMMAND_OUTPUT_LIMIT,
        )
        .await?;
        if !result.status.success() {
            bail!(
                "{}",
                command_error(&result.stdout, &result.stderr, "ddcutil failed")
            );
        }
        Ok::<_, anyhow::Error>(Brightness {
            bus,
            current: target,
            maximum,
        })
    }
    .await;
    result
        .map(|brightness| (output.clone(), brightness))
        .map_err(|error| (output, error.to_string()))
}

fn response(output: &str, brightness: Option<Brightness>, error: Option<String>) -> Value {
    if let Some(brightness) = brightness {
        return json!({
            "ok": true,
            "output": output,
            "available": true,
            "backend": "ddcutil",
            "bus": brightness.bus,
            "current": brightness.current,
            "maximum": brightness.maximum,
            "value": f64::from(brightness.current) / f64::from(brightness.maximum.max(1)),
        });
    }
    json!({
        "ok": false,
        "output": output,
        "available": false,
        "error": error.clone().unwrap_or_else(|| "Brightness unavailable".into()),
        "message": error.unwrap_or_else(|| "Brightness unavailable".into()),
    })
}

fn connector_bus(connector: &str) -> Option<u32> {
    let connector_path = connector_path(connector)?;
    for directory in [connector_path.join("ddc/i2c-dev"), connector_path.clone()] {
        let Ok(entries) = fs::read_dir(directory) else {
            continue;
        };
        let mut paths = entries
            .flatten()
            .map(|entry| entry.path())
            .collect::<Vec<_>>();
        paths.sort();
        for path in paths {
            if let Some(bus) = i2c_bus_from_path(&path) {
                return Some(bus);
            }
        }
    }
    fs::canonicalize(connector_path.join("ddc"))
        .ok()
        .and_then(|path| i2c_bus_from_path(&path))
}

fn connector_path(connector: &str) -> Option<PathBuf> {
    let entries = fs::read_dir("/sys/class/drm").ok()?;
    let suffix = format!("-{connector}");
    let mut matches = entries
        .flatten()
        .filter_map(|entry| {
            let name = entry.file_name().to_string_lossy().into_owned();
            (name.starts_with("card") && name.ends_with(&suffix)).then(|| entry.path())
        })
        .collect::<Vec<_>>();
    matches.sort();
    matches.into_iter().next()
}

fn i2c_bus_from_path(path: &Path) -> Option<u32> {
    static PATTERN: OnceLock<Regex> = OnceLock::new();
    let pattern = PATTERN.get_or_init(|| Regex::new(r"(?:^|/)i2c-(\d+)(?:/|$)").unwrap());
    pattern
        .captures(&path.to_string_lossy())
        .and_then(|captures| captures.get(1))
        .and_then(|value| value.as_str().parse().ok())
}

fn parse_brightness(output: &str) -> Result<(u32, u32)> {
    static PATTERNS: OnceLock<Vec<Regex>> = OnceLock::new();
    for pattern in PATTERNS.get_or_init(|| {
        vec![
            Regex::new(r"(?i)current value\s*=\s*(\d+)\s*,\s*max value\s*=\s*(\d+)").unwrap(),
            Regex::new(r"(?i)VCP\s+(?:code\s+)?(?:0x)?10\s+C\s+(\d+)\s+(\d+)").unwrap(),
        ]
    }) {
        if let Some(captures) = pattern.captures(output) {
            let current = captures[1].parse()?;
            let maximum = captures[2].parse::<u32>()?.max(1);
            return Ok((current, maximum));
        }
    }
    bail!("Could not parse DDC brightness response")
}

fn command_error(stdout: &[u8], stderr: &[u8], fallback: &str) -> String {
    let selected = if stderr.is_empty() { stdout } else { stderr };
    String::from_utf8_lossy(selected)
        .lines()
        .map(str::trim)
        .rfind(|line| !line.is_empty())
        .unwrap_or(fallback)
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_verbose_and_brief_ddc_responses() {
        assert_eq!(
            parse_brightness("current value = 52, max value = 100").unwrap(),
            (52, 100)
        );
        assert_eq!(parse_brightness("VCP 10 C 75 100").unwrap(), (75, 100));
    }
}
