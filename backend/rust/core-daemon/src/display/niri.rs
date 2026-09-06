use super::decode;
use crate::command::{command_path, run_bounded};
use anyhow::{Context, Result, bail};
use regex::Regex;
use serde::Deserialize;
use serde_json::{Map, Value, json};
use std::collections::HashMap;
use std::fs;
use std::io::Write;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use std::time::Duration;
use tokio::task;
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

const COMMAND_OUTPUT_LIMIT: usize = 4 * 1024 * 1024;
const COMMAND_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct ModeParams {
    mode: String,
    #[serde(default)]
    preferred_external: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct OptionsParams {
    config_path: PathBuf,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct PersistParams {
    config_path: PathBuf,
    outputs: Vec<Value>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct VrrParams {
    config_path: PathBuf,
    mode: String,
    output: String,
}

#[derive(Clone)]
struct OutputBlock {
    end: usize,
    name: String,
    start: usize,
}

pub async fn apply_mode(params: Value, cancellation: CancellationToken) -> Result<Value> {
    let params: ModeParams = decode(params, "Niri display mode")?;
    Ok(match apply_mode_inner(&params, cancellation).await {
        Ok(target) => json!({"ok": true, "mode": params.mode, "target": target}),
        Err(error) => {
            json!({"ok": false, "error": error.to_string(), "message": error.to_string()})
        }
    })
}

pub async fn options(params: Value) -> Result<Value> {
    let params: OptionsParams = decode(params, "Niri output options")?;
    let value = task::spawn_blocking(move || parse_config(&read_config(&params.config_path)))
        .await
        .context("join Niri option parser")?;
    Ok(Value::Object(value))
}

pub async fn set_vrr(params: Value) -> Result<Value> {
    let params: VrrParams = decode(params, "Niri VRR")?;
    let result = task::spawn_blocking(move || {
        if !matches!(params.mode.as_str(), "off" | "on" | "on-demand") {
            bail!("VRR mode must be off, on, or on-demand");
        }
        if !set_vrr_mode(&params.config_path, &params.output, params.mode.as_str())? {
            bail!("output block not found");
        }
        Ok::<_, anyhow::Error>(())
    })
    .await
    .context("join Niri VRR update")?;
    Ok(match result {
        Ok(()) => json!({"ok": true}),
        Err(error) => json!({"ok": false, "message": error.to_string()}),
    })
}

pub async fn persist(params: Value) -> Result<Value> {
    let params: PersistParams = decode(params, "Niri output persistence")?;
    let result = task::spawn_blocking(move || sync_outputs(&params.config_path, &params.outputs))
        .await
        .context("join Niri output persistence")?;
    Ok(match result {
        Ok(mut value) => {
            if let Some(object) = value.as_object_mut() {
                object.insert("ok".into(), Value::Bool(true));
            }
            value
        }
        Err(error) => {
            json!({"ok": false, "changed": false, "error": error.to_string(), "message": error.to_string()})
        }
    })
}

async fn apply_mode_inner(params: &ModeParams, cancellation: CancellationToken) -> Result<String> {
    let outputs = run_niri(&["-j", "outputs"], cancellation.clone()).await?;
    let decoded: Value = serde_json::from_slice(&outputs).context("parse Niri outputs")?;
    let object = decoded
        .as_object()
        .context("Niri outputs must be an object")?;
    let names = object
        .iter()
        .map(|(key, output)| {
            output
                .get("name")
                .and_then(Value::as_str)
                .unwrap_or(key)
                .to_string()
        })
        .collect::<Vec<_>>();
    let internal = names
        .iter()
        .filter(|name| is_internal_output(name))
        .cloned()
        .collect::<Vec<_>>();
    let external = names
        .iter()
        .filter(|name| !is_internal_output(name))
        .cloned()
        .collect::<Vec<_>>();

    match params.mode.as_str() {
        "internal" => {
            let target = internal
                .first()
                .context("No internal display is connected")?;
            set_output(target, true, cancellation.clone()).await?;
            for name in &names {
                if name != target {
                    set_output(name, false, cancellation.clone()).await?;
                }
            }
            Ok(target.clone())
        }
        "extend" => {
            if internal.is_empty() || external.is_empty() {
                bail!("Extend requires an internal and an external display");
            }
            for name in &names {
                set_output(name, true, cancellation.clone()).await?;
            }
            Ok(preferred_external(&external, &params.preferred_external))
        }
        "external" => {
            if external.is_empty() {
                bail!("No external display is connected");
            }
            let target = preferred_external(&external, &params.preferred_external);
            set_output(&target, true, cancellation.clone()).await?;
            for name in &names {
                if name != &target {
                    set_output(name, false, cancellation.clone()).await?;
                }
            }
            Ok(target)
        }
        _ => bail!("Duplicate is not supported natively by Niri"),
    }
}

fn preferred_external(external: &[String], preferred: &str) -> String {
    external
        .iter()
        .find(|name| name.as_str() == preferred)
        .unwrap_or(&external[0])
        .clone()
}

async fn set_output(name: &str, enabled: bool, cancellation: CancellationToken) -> Result<()> {
    run_niri(
        &["output", name, if enabled { "on" } else { "off" }],
        cancellation,
    )
    .await?;
    Ok(())
}

async fn run_niri(arguments: &[&str], cancellation: CancellationToken) -> Result<Vec<u8>> {
    let niri = command_path("niri").context("niri is unavailable")?;
    let output = run_bounded(
        &niri,
        arguments,
        COMMAND_TIMEOUT,
        cancellation,
        COMMAND_OUTPUT_LIMIT,
    )
    .await?;
    if output.stdout_truncated || output.stderr_truncated {
        bail!("Niri IPC output exceeded the safety limit");
    }
    if !output.status.success() {
        bail!(
            "{}",
            command_error(&output.stdout, &output.stderr, "niri IPC failed")
        );
    }
    Ok(output.stdout)
}

fn is_internal_output(name: &str) -> bool {
    ["eDP-", "LVDS-", "DSI-"]
        .iter()
        .any(|prefix| name.starts_with(prefix))
}

fn parse_config(content: &str) -> Map<String, Value> {
    let lines = content_lines(content);
    let mut result = Map::new();
    for block in output_blocks(&lines) {
        let body = lines[block.start + 1..block.end].concat();
        let vrr_arguments = active_vrr_pattern()
            .captures(&body)
            .and_then(|captures| captures.name("arguments"))
            .map(|value| value.as_str());
        let vrr_mode = match vrr_arguments {
            Some(arguments) if on_demand_pattern().is_match(arguments) => "on-demand",
            Some(_) => "on",
            None => "off",
        };
        result.insert(
            block.name,
            json!({
                "vrr": vrr_mode != "off",
                "vrrMode": vrr_mode,
                "focus": focus_pattern().is_match(&body),
            }),
        );
    }
    result
}

fn set_vrr_mode(path: &Path, output_name: &str, mode: &str) -> Result<bool> {
    let content = read_config(path);
    let mut lines = content_lines(&content);
    let Some(block) = output_blocks(&lines)
        .into_iter()
        .find(|block| block.name == output_name)
    else {
        return Ok(false);
    };

    let mut body = lines[block.start + 1..block.end].to_vec();
    let matching = body
        .iter()
        .enumerate()
        .filter_map(|(index, line)| vrr_line_pattern().is_match(line).then_some(index))
        .collect::<Vec<_>>();
    let insert_at = matching
        .first()
        .map(|first| {
            (0..*first)
                .filter(|index| !matching.contains(index))
                .count()
        })
        .unwrap_or(body.len());
    body = body
        .into_iter()
        .enumerate()
        .filter_map(|(index, line)| (!matching.contains(&index)).then_some(line))
        .collect();

    let newline = if content.contains("\r\n") {
        "\r\n"
    } else {
        "\n"
    };
    let header_indent = lines[block.start]
        .chars()
        .take_while(|character| character.is_whitespace())
        .collect::<String>();
    let option = match mode {
        "off" => "// variable-refresh-rate",
        "on-demand" => "variable-refresh-rate on-demand=true",
        _ => "variable-refresh-rate",
    };
    body.insert(insert_at, format!("{header_indent}    {option}{newline}"));
    lines.splice(block.start + 1..block.end, body);
    write_atomic(path, &lines.concat())?;
    Ok(true)
}

fn sync_outputs(config_path: &Path, outputs: &[Value]) -> Result<Value> {
    let mut content = read_config(config_path);
    let identities = output_id_map(outputs);
    let mut changed = false;
    let mut created = Vec::new();
    let active_right = outputs
        .iter()
        .filter_map(|output| output.get("logical"))
        .map(|logical| integer(logical.get("x")) + integer(logical.get("width")))
        .max()
        .unwrap_or(0);

    for output in outputs {
        let connector = clean_part(output.get("name"));
        let identity = identities
            .get(&connector)
            .cloned()
            .unwrap_or_else(|| connector.clone());
        if connector.is_empty() || identity.is_empty() {
            continue;
        }
        if identity != connector {
            let (next_content, disabled) = disable_connector_block(&content, &connector);
            content = next_content;
            changed |= disabled;
        }
        if active_output_exists(&content, &identity) {
            continue;
        }
        content = format!(
            "{}\n\n{}",
            content.trim_end(),
            output_block(&identity, output, active_right)
        );
        created.push(identity);
        changed = true;
    }
    if changed {
        write_atomic(config_path, &format!("{}\n", content.trim_end()))?;
    }
    Ok(json!({
        "changed": changed,
        "created": created,
        "identities": identities,
    }))
}

fn output_id_map(outputs: &[Value]) -> HashMap<String, String> {
    let candidates = outputs.iter().map(hardware_id).collect::<Vec<_>>();
    let mut counts = HashMap::new();
    for candidate in &candidates {
        *counts.entry(candidate.clone()).or_insert(0_u32) += 1;
    }
    outputs
        .iter()
        .zip(candidates)
        .map(|(output, candidate)| {
            let connector = clean_part(output.get("name"));
            let identity =
                if candidate.is_empty() || counts.get(&candidate).copied().unwrap_or(0) > 1 {
                    connector.clone()
                } else {
                    candidate
                };
            (connector, identity)
        })
        .collect()
}

fn hardware_id(output: &Value) -> String {
    let make = clean_part(output.get("make"));
    let model = clean_part(output.get("model"));
    let connector = clean_part(output.get("name"));
    if make.is_empty() || model.is_empty() {
        return connector;
    }
    let serial = {
        let value = clean_part(output.get("serial"));
        if value.is_empty() {
            "Unknown".into()
        } else {
            value
        }
    };
    let identity = format!("{make} {model} {serial}")
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ");
    if identity.is_empty() {
        connector
    } else {
        identity
    }
}

fn output_block(identity: &str, output: &Value, fallback_x: i64) -> String {
    let logical = output.get("logical").unwrap_or(&Value::Null);
    let x = logical
        .get("x")
        .map(|value| integer(Some(value)))
        .unwrap_or(fallback_x);
    let y = integer(logical.get("y"));
    let scale = number(logical.get("scale")).unwrap_or(1.0);
    let transform = {
        let value = clean_part(logical.get("transform")).to_ascii_lowercase();
        if value.is_empty() {
            "normal".into()
        } else {
            value
        }
    };
    format!(
        "output \"{}\" {{\n    mode \"{}\"\n    scale {}\n    transform \"{}\"\n    position x={} y={}\n    // variable-refresh-rate on-demand=true\n    // focus-at-startup\n}}\n",
        escape_kdl(identity),
        current_mode(output),
        format_number(scale),
        escape_kdl(&transform),
        x,
        y,
    )
}

fn current_mode(output: &Value) -> String {
    let modes = output
        .get("modes")
        .and_then(Value::as_array)
        .map(Vec::as_slice)
        .unwrap_or(&[]);
    match output.get("current_mode") {
        Some(Value::Number(index)) => index
            .as_u64()
            .and_then(|index| modes.get(index as usize))
            .map(format_mode)
            .unwrap_or_else(|| best_mode(modes)),
        Some(Value::Object(_)) => format_mode(output.get("current_mode").unwrap()),
        _ => best_mode(modes),
    }
}

fn best_mode(modes: &[Value]) -> String {
    modes
        .iter()
        .max_by_key(|mode| {
            (
                integer(mode.get("width")) * integer(mode.get("height")),
                integer(mode.get("refresh_rate")),
                mode.get("is_preferred")
                    .and_then(Value::as_bool)
                    .unwrap_or(false),
            )
        })
        .map(format_mode)
        .unwrap_or_else(|| "1920x1080@60.000".into())
}

fn format_mode(mode: &Value) -> String {
    let width = integer(mode.get("width")).max(1);
    let height = integer(mode.get("height")).max(1);
    let refresh = integer(mode.get("refresh_rate"));
    let refresh = if refresh == 0 { 60_000 } else { refresh } as f64 / 1000.0;
    format!("{width}x{height}@{refresh:.3}")
}

fn active_output_exists(content: &str, name: &str) -> bool {
    let lines = content_lines(content);
    output_blocks(&lines).iter().any(|block| block.name == name)
}

fn disable_connector_block(content: &str, connector: &str) -> (String, bool) {
    let mut lines = content_lines(content);
    let Some(block) = output_blocks(&lines)
        .into_iter()
        .find(|block| block.name == connector)
    else {
        return (content.to_string(), false);
    };
    lines[block.start] = lines[block.start].replacen("output", "/-output", 1);
    (lines.concat(), true)
}

fn output_blocks(lines: &[String]) -> Vec<OutputBlock> {
    let mut blocks = Vec::new();
    let mut index = 0;
    while index < lines.len() {
        let Some(captures) = output_header_pattern().captures(&lines[index]) else {
            index += 1;
            continue;
        };
        let mut depth = brace_delta(&lines[index]);
        let mut end = index;
        while depth > 0 && end + 1 < lines.len() {
            end += 1;
            depth += brace_delta(&lines[end]);
        }
        if depth == 0 {
            blocks.push(OutputBlock {
                end,
                name: decode_kdl_string(captures.get(1).unwrap().as_str()),
                start: index,
            });
        }
        index = end + 1;
    }
    blocks
}

fn brace_delta(line: &str) -> i32 {
    let mut delta = 0;
    let mut escaped = false;
    let mut in_string = false;
    let mut characters = line.chars().peekable();
    while let Some(character) = characters.next() {
        if !in_string && character == '/' && characters.peek() == Some(&'/') {
            break;
        }
        if in_string {
            if escaped {
                escaped = false;
            } else if character == '\\' {
                escaped = true;
            } else if character == '"' {
                in_string = false;
            }
        } else if character == '"' {
            in_string = true;
        } else if character == '{' {
            delta += 1;
        } else if character == '}' {
            delta -= 1;
        }
    }
    delta
}

fn content_lines(content: &str) -> Vec<String> {
    let mut lines = content
        .split_inclusive('\n')
        .map(str::to_string)
        .collect::<Vec<_>>();
    if content.is_empty() {
        lines.clear();
    }
    lines
}

fn read_config(path: &Path) -> String {
    fs::read_to_string(path).unwrap_or_default()
}

fn write_atomic(path: &Path, content: &str) -> Result<()> {
    let directory = path.parent().unwrap_or_else(|| Path::new("."));
    fs::create_dir_all(directory)
        .with_context(|| format!("create directory {}", directory.display()))?;
    let mode = fs::metadata(path)
        .map(|metadata| metadata.permissions().mode() & 0o777)
        .unwrap_or(0o644);
    let temporary = directory.join(format!(".niri-output-{}.tmp", Uuid::new_v4()));
    let result = (|| -> Result<()> {
        let mut file = fs::OpenOptions::new()
            .create_new(true)
            .write(true)
            .open(&temporary)
            .with_context(|| format!("create temporary file {}", temporary.display()))?;
        file.write_all(content.as_bytes())?;
        file.flush()?;
        fs::set_permissions(&temporary, fs::Permissions::from_mode(mode))?;
        fs::rename(&temporary, path)
            .with_context(|| format!("replace Niri output config {}", path.display()))?;
        Ok(())
    })();
    if result.is_err() {
        let _ = fs::remove_file(&temporary);
    }
    result
}

fn clean_part(value: Option<&Value>) -> String {
    value
        .and_then(Value::as_str)
        .unwrap_or_default()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

fn integer(value: Option<&Value>) -> i64 {
    value.and_then(Value::as_i64).unwrap_or_default()
}

fn number(value: Option<&Value>) -> Option<f64> {
    value.and_then(Value::as_f64)
}

fn format_number(value: f64) -> String {
    if value.fract().abs() < f64::EPSILON {
        format!("{value:.0}")
    } else {
        value.to_string()
    }
}

fn escape_kdl(value: &str) -> String {
    value.replace('\\', "\\\\").replace('"', "\\\"")
}

fn decode_kdl_string(value: &str) -> String {
    let mut result = String::new();
    let mut escaped = false;
    for character in value.chars() {
        if escaped {
            if matches!(character, '\\' | '"') {
                result.push(character);
            } else {
                result.push('\\');
                result.push(character);
            }
            escaped = false;
        } else if character == '\\' {
            escaped = true;
        } else {
            result.push(character);
        }
    }
    if escaped {
        result.push('\\');
    }
    result
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

fn output_header_pattern() -> &'static Regex {
    static PATTERN: OnceLock<Regex> = OnceLock::new();
    PATTERN.get_or_init(|| Regex::new(r#"^\s*output\s+"((?:\\.|[^"])*)"\s*\{"#).unwrap())
}

fn active_vrr_pattern() -> &'static Regex {
    static PATTERN: OnceLock<Regex> = OnceLock::new();
    PATTERN
        .get_or_init(|| Regex::new(r"(?m)^\s*variable-refresh-rate(?P<arguments>[^\n/]*)").unwrap())
}

fn on_demand_pattern() -> &'static Regex {
    static PATTERN: OnceLock<Regex> = OnceLock::new();
    PATTERN.get_or_init(|| Regex::new(r"\bon-demand\s*=\s*true\b").unwrap())
}

fn focus_pattern() -> &'static Regex {
    static PATTERN: OnceLock<Regex> = OnceLock::new();
    PATTERN.get_or_init(|| Regex::new(r"(?m)^\s*focus-at-startup(?:\s|$)").unwrap())
}

fn vrr_line_pattern() -> &'static Regex {
    static PATTERN: OnceLock<Regex> = OnceLock::new();
    PATTERN.get_or_init(|| {
        Regex::new(r"^\s*(?://\s*)?variable-refresh-rate(?:\s+on-demand\s*=\s*(?:true|false))?\s*(?://.*)?(?:\r?\n)?$").unwrap()
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;

    #[test]
    fn parses_niri_options() {
        let parsed = parse_config(
            "output \"eDP-1\" {\n    variable-refresh-rate on-demand=true\n    focus-at-startup\n}\noutput \"DP-1\" {\n    // variable-refresh-rate\n}\n",
        );
        assert_eq!(parsed["eDP-1"]["vrrMode"], "on-demand");
        assert_eq!(parsed["eDP-1"]["focus"], true);
        assert_eq!(parsed["DP-1"]["vrrMode"], "off");
    }

    #[test]
    fn updates_vrr_atomically() {
        let root = env::temp_dir().join(format!("niri-vrr-test-{}", Uuid::new_v4()));
        fs::create_dir_all(&root).unwrap();
        let path = root.join("outputs.kdl");
        fs::write(
            &path,
            "output \"eDP-1\" {\n    // variable-refresh-rate\n    scale 1\n}\n",
        )
        .unwrap();
        assert!(set_vrr_mode(&path, "eDP-1", "on-demand").unwrap());
        let result = fs::read_to_string(&path).unwrap();
        assert!(result.contains("variable-refresh-rate on-demand=true"));
        assert!(!result.contains("// variable-refresh-rate"));
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn creates_stable_hardware_identity() {
        let output = json!({
            "name": "DP-1",
            "make": "Dell Inc.",
            "model": "U2723QE",
            "serial": "ABC123",
        });
        assert_eq!(hardware_id(&output), "Dell Inc. U2723QE ABC123");
    }
}
