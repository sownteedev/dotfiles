use anyhow::{Context, Result, bail};
use regex::{Captures, Regex};
use serde_json::Value;

pub fn regex(pattern: &str) -> Regex {
    Regex::new(pattern).expect("settings regex must compile")
}

pub fn capture(source: &str, pattern: &str, group: usize) -> Option<String> {
    regex(pattern)
        .captures(source)
        .and_then(|captures| captures.get(group))
        .map(|value| value.as_str().to_string())
}

pub fn json_quote(value: &str) -> String {
    serde_json::to_string(value).expect("strings are JSON serializable")
}

pub fn value_bool(payload: &Value, name: &str, fallback: bool) -> bool {
    match payload.get(name) {
        Some(Value::Bool(value)) => *value,
        Some(Value::Number(value)) => value.as_i64().unwrap_or_default() != 0,
        Some(Value::String(value)) => !value.is_empty(),
        Some(Value::Array(value)) => !value.is_empty(),
        Some(Value::Object(value)) => !value.is_empty(),
        Some(Value::Null) | None => fallback,
    }
}

pub fn value_string(payload: &Value, name: &str, fallback: &str) -> String {
    match payload.get(name) {
        Some(Value::String(value)) => value.clone(),
        Some(Value::Bool(value)) => {
            if *value {
                "True".into()
            } else {
                "False".into()
            }
        }
        Some(Value::Number(value)) => value.to_string(),
        Some(Value::Null) | None => fallback.into(),
        Some(value) => value.to_string(),
    }
}

pub fn value_f64(payload: &Value, name: &str, fallback: f64) -> f64 {
    payload
        .get(name)
        .and_then(|value| match value {
            Value::Number(value) => value.as_f64(),
            Value::String(value) => value.parse().ok(),
            _ => None,
        })
        .filter(|value| value.is_finite())
        .unwrap_or(fallback)
}

pub fn value_i64(payload: &Value, name: &str, fallback: i64) -> i64 {
    payload
        .get(name)
        .and_then(|value| match value {
            Value::Number(value) => value.as_i64().or_else(|| value.as_f64().map(|v| v as i64)),
            Value::String(value) => value.parse().ok(),
            _ => None,
        })
        .unwrap_or(fallback)
}

pub fn kdl_float(value: f64) -> String {
    let mut text = format!("{value:.6}");
    while text.ends_with('0') {
        text.pop();
    }
    if text.ends_with('.') {
        text.pop();
    }
    if !text.contains('.') {
        text.push_str(".0");
    }
    text
}

pub fn block_number(block: &str, name: &str, fallback: f64) -> f64 {
    capture(
        block,
        &format!(r"(?m)^\s*{}\s+([\d.]+)", regex::escape(name)),
        1,
    )
    .and_then(|value| value.parse().ok())
    .unwrap_or(fallback)
}

pub fn block_number_any(block: &str, name: &str, fallback: f64) -> f64 {
    capture(
        block,
        &format!(r"(?m)^\s*(?://\s*)?{}\s+([-\d.]+)", regex::escape(name)),
        1,
    )
    .and_then(|value| value.parse().ok())
    .unwrap_or(fallback)
}

pub fn block_string(block: &str, name: &str, fallback: &str) -> String {
    capture(
        block,
        &format!(r#"(?m)^\s*(?://\s*)?{}\s+"([^"]*)""#, regex::escape(name)),
        1,
    )
    .unwrap_or_else(|| fallback.into())
}

pub fn block_bool(block: &str, name: &str, fallback: bool) -> bool {
    capture(
        block,
        &format!(r"(?m)^\s*(?://\s*)?{}\s+(true|false)", regex::escape(name)),
        1,
    )
    .map(|value| value == "true")
    .unwrap_or(fallback)
}

pub fn block_attribute_number(block: &str, name: &str, attribute: &str, fallback: f64) -> f64 {
    capture(
        block,
        &format!(
            r"(?m)^\s*(?://\s*)?{}\s+{}=([-\d.]+)",
            regex::escape(name),
            regex::escape(attribute)
        ),
        1,
    )
    .and_then(|value| value.parse().ok())
    .unwrap_or(fallback)
}

pub fn block_raw_setting(block: &str, name: &str, fallback: &str) -> (bool, String) {
    let pattern = regex(&format!(
        r"(?m)^\s*(?P<comment>//\s*)?{}\s+(?P<value>[^\n]+?)\s*$",
        regex::escape(name)
    ));
    let Some(captures) = pattern.captures(block) else {
        return (false, fallback.into());
    };
    (
        captures.name("comment").is_none(),
        captures
            .name("value")
            .map(|value| value.as_str().trim().to_string())
            .unwrap_or_else(|| fallback.into()),
    )
}

pub fn dimension_entries(block: &str) -> String {
    let pattern = regex(r"^\s*(proportion|fixed)\s+([-\d.]+)\s*;?\s*$");
    block
        .lines()
        .filter_map(|line| {
            let captures = pattern.captures(line)?;
            Some(format!("{} {}", &captures[1], &captures[2]))
        })
        .collect::<Vec<_>>()
        .join(", ")
}

pub fn block_offset(block: &str) -> (f64, f64) {
    let pattern = regex(r"(?m)^\s*offset\s+x=([-\d.]+)\s+y=([-\d.]+)");
    let Some(captures) = pattern.captures(block) else {
        return (0.0, 0.0);
    };
    (
        captures[1].parse().unwrap_or_default(),
        captures[2].parse().unwrap_or_default(),
    )
}

pub fn parse_input_line(raw: &str) -> Option<(String, bool)> {
    let stripped = raw.trim();
    if stripped.is_empty() || matches!(stripped, "{" | "}") || stripped.ends_with('{') {
        return None;
    }
    let enabled = !stripped.starts_with("//");
    let text = if enabled {
        stripped
    } else {
        stripped.strip_prefix("//")?.trim()
    }
    .trim_end_matches(';');
    if text.is_empty() || matches!(text, "off" | "on") || text.ends_with('{') {
        return None;
    }
    Some((text.into(), enabled))
}

pub fn input_lines(block: &str) -> Vec<Value> {
    let mut lines = Vec::new();
    for raw in block.lines() {
        let Some((text, enabled)) = parse_input_line(raw) else {
            continue;
        };
        lines.push(serde_json::json!({
            "index": lines.len(),
            "text": text,
            "enabled": enabled,
        }));
    }
    lines
}

pub fn find_block(source: &str, name: &str) -> String {
    find_block_range(source, name, false)
        .map(|(start, end)| source[start..end].to_string())
        .unwrap_or_default()
}

pub fn find_any_block(source: &str, name: &str) -> String {
    find_block_range(source, name, true)
        .map(|(start, end)| source[start..end].to_string())
        .unwrap_or_default()
}

fn find_block_range(source: &str, name: &str, slashdash: bool) -> Option<(usize, usize)> {
    let prefix = if slashdash { r"(?:/-)?" } else { "" };
    let suffix = if slashdash { r"(?:\s+[^\{\n]+)?" } else { "" };
    let pattern = regex(&format!(
        r"(?m)^\s*{prefix}{}{suffix}\s*\{{",
        regex::escape(name)
    ));
    let matched = pattern.find(source)?;
    let start = matched.end();
    matching_brace(source, start).map(|end| (start, end))
}

fn matching_brace(source: &str, start: usize) -> Option<usize> {
    let mut depth = 1_i32;
    for (offset, character) in source[start..].char_indices() {
        match character {
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if depth == 0 {
                    return Some(start + offset);
                }
            }
            _ => {}
        }
    }
    None
}

pub fn block_enabled(source: &str, name: &str) -> bool {
    regex(&format!(
        r"(?m)^\s*{}(?:\s+[^\{{\n]+)?\s*\{{",
        regex::escape(name)
    ))
    .is_match(source)
}

pub fn flag_enabled(source: &str, name: &str) -> bool {
    regex(&format!(r"(?m)^\s*{}\s*$", regex::escape(name))).is_match(source)
}

pub fn explicit_state_enabled(source: &str, fallback: bool) -> bool {
    if flag_enabled(source, "on") {
        true
    } else if flag_enabled(source, "off") {
        false
    } else {
        fallback
    }
}

pub fn replace_once_with<F>(source: &str, pattern: &str, label: &str, replacer: F) -> Result<String>
where
    F: Fn(&Captures<'_>) -> String,
{
    let expression = Regex::new(pattern).with_context(|| format!("compile {label} pattern"))?;
    let Some(captures) = expression.captures(source) else {
        bail!("Could not find {label}");
    };
    let matched = captures.get(0).expect("a regex match has group zero");
    let replacement = replacer(&captures);
    Ok(format!(
        "{}{}{}",
        &source[..matched.start()],
        replacement,
        &source[matched.end()..]
    ))
}

pub fn update_block<F>(source: &str, name: &str, updater: F) -> Result<String>
where
    F: FnOnce(&str) -> Result<String>,
{
    let Some((start, end)) = find_block_range(source, name, true) else {
        bail!("Could not find {name} block");
    };
    let updated = updater(&source[start..end])?;
    Ok(format!("{}{}{}", &source[..start], updated, &source[end..]))
}

pub fn toggle_block(source: &str, name: &str, enabled: bool) -> Result<String> {
    replace_once_with(
        source,
        &format!(
            r"(?m)^([ \t]*)(?:/-)?({}(?:[ \t]+[^\{{\n]+)?[ \t]*\{{)",
            regex::escape(name)
        ),
        &format!("{name} block"),
        |captures| {
            format!(
                "{}{}{}",
                &captures[1],
                if enabled { "" } else { "/-" },
                &captures[2]
            )
        },
    )
}

pub fn set_flag(source: &str, name: &str, enabled: bool) -> Result<String> {
    replace_once_with(
        source,
        &format!(r"(?m)^([ \t]*)(?://[ \t]*)?{}[ \t]*$", regex::escape(name)),
        name,
        |captures| {
            format!(
                "{}{}{}",
                &captures[1],
                if enabled { "" } else { "// " },
                name
            )
        },
    )
}

pub fn set_block_flag(
    source: &str,
    block_name: &str,
    flag_name: &str,
    enabled: bool,
) -> Result<String> {
    update_block(source, block_name, |block| {
        set_flag(block, flag_name, enabled)
    })
}

pub fn set_explicit_block_state(source: &str, block_name: &str, enabled: bool) -> Result<String> {
    update_block(source, block_name, |block| {
        let state_pattern = regex(r"(?m)^([ \t]*)(?://[ \t]*)?(on|off)[ \t]*$");
        let matches = state_pattern.captures_iter(block).collect::<Vec<_>>();
        let desired = if enabled { "on" } else { "off" };
        if matches.is_empty() {
            let indent = capture(block, r"(?m)^([ \t]+)\S", 1).unwrap_or_else(|| "        ".into());
            return Ok(format!(
                "\n{indent}{desired}\n{}",
                block.trim_start_matches('\n')
            ));
        }
        let mut result = String::with_capacity(block.len());
        let mut cursor = 0;
        for (index, captures) in matches.iter().enumerate() {
            let matched = captures.get(0).expect("state match");
            result.push_str(&block[cursor..matched.start()]);
            result.push_str(&captures[1]);
            if index == 0 {
                result.push_str(desired);
            } else {
                result.push_str("// ");
                result.push_str(&captures[2]);
            }
            cursor = matched.end();
        }
        result.push_str(&block[cursor..]);
        Ok(result)
    })
}

pub fn set_unique_option_line(
    source: &str,
    name: &str,
    enabled: bool,
    suffix: &str,
) -> Result<String> {
    let pattern = regex(&format!(
        r"(?m)^([ \t]*)(?://[ \t]*)?{}(?:[ \t]+.*)?$",
        regex::escape(name)
    ));
    let matches = pattern.captures_iter(source).collect::<Vec<_>>();
    if matches.is_empty() {
        bail!("Could not find {name}");
    }
    let desired = if suffix.is_empty() {
        name.to_string()
    } else {
        format!("{name} {suffix}")
    };
    let mut result = String::with_capacity(source.len());
    let mut cursor = 0;
    for (index, captures) in matches.iter().enumerate() {
        let matched = captures.get(0).expect("option match");
        result.push_str(&source[cursor..matched.start()]);
        result.push_str(&captures[1]);
        if enabled && index == 0 {
            result.push_str(&desired);
        } else {
            result.push_str("// ");
            result.push_str(&desired);
        }
        cursor = matched.end();
    }
    result.push_str(&source[cursor..]);
    Ok(result)
}

pub fn set_optional_raw_line(
    block: &str,
    name: &str,
    value: &str,
    enabled: bool,
    label: &str,
) -> Result<String> {
    let clean = value.trim();
    if clean.is_empty()
        || clean
            .chars()
            .any(|value| matches!(value, '{' | '}' | ';' | '\n' | '\r'))
    {
        bail!("Invalid {label}");
    }
    let rendered = format!("{name} {clean}");
    let pattern = format!(
        r"(?m)^([ \t]*)(?://[ \t]*)?{}\s+[^\n]+$",
        regex::escape(name)
    );
    if regex(&pattern).is_match(block) {
        return replace_once_with(block, &pattern, label, |captures| {
            format!(
                "{}{}{}",
                &captures[1],
                if enabled { "" } else { "// " },
                rendered
            )
        });
    }
    let trailing = regex(r"(\n[ \t]*)$");
    if let Some(captures) = trailing.captures(block) {
        let matched = captures.get(0).expect("trailing indentation");
        let closing_indent = &captures[1][1..];
        return Ok(format!(
            "{}\n{}    {}{}{}",
            &block[..matched.start()],
            closing_indent,
            if enabled { "" } else { "// " },
            rendered,
            &captures[1]
        ));
    }
    Ok(format!(
        "{block}\n    {}{rendered}\n",
        if enabled { "" } else { "// " }
    ))
}

pub fn render_dimension_entries(raw_value: &str, label: &str) -> Result<String> {
    let parts = raw_value
        .split([',', ';'])
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    if parts.is_empty() {
        bail!("{label} needs at least one entry");
    }
    let pattern = regex(r"^(proportion|fixed)\s+([-+]?\d+(?:\.\d+)?)$");
    let mut rendered = Vec::new();
    for part in parts {
        let Some(captures) = pattern.captures(part) else {
            bail!("Invalid {label} entry: {part:?}");
        };
        let kind = &captures[1];
        let value = captures[2].parse::<f64>()?;
        if kind == "proportion" && !(0.0 < value && value <= 1.0) {
            bail!("{label} proportion must be between 0 and 1");
        }
        if kind == "fixed" && value <= 0.0 {
            bail!("{label} fixed size must be positive");
        }
        let encoded = if kind == "fixed" {
            format!("{:.0}", value)
        } else {
            kdl_float(value)
        };
        rendered.push(format!("        {kind} {encoded}"));
    }
    Ok(format!("\n{}\n    ", rendered.join("\n")))
}

pub fn set_number_line(block: &str, name: &str, value: f64, label: &str) -> Result<String> {
    replace_once_with(
        block,
        &format!(
            r"(?m)^([ \t]*)(?://[ \t]*)?{}\s+[-\d.]+",
            regex::escape(name)
        ),
        label,
        |captures| format!("{}{} {}", &captures[1], name, kdl_float(value)),
    )
}

pub fn set_integer_line(block: &str, name: &str, value: i64, label: &str) -> Result<String> {
    replace_once_with(
        block,
        &format!(
            r"(?m)^([ \t]*)(?://[ \t]*)?{}\s+[-\d.]+",
            regex::escape(name)
        ),
        label,
        |captures| format!("{}{} {value}", &captures[1], name),
    )
}

pub fn set_string_line(block: &str, name: &str, value: &str, label: &str) -> Result<String> {
    replace_once_with(
        block,
        &format!(
            r#"(?m)^([ \t]*)(?://[ \t]*)?{}\s+"[^"]*""#,
            regex::escape(name)
        ),
        label,
        |captures| format!("{}{} {}", &captures[1], name, json_quote(value)),
    )
}

pub fn set_bool_line(block: &str, name: &str, value: bool, label: &str) -> Result<String> {
    replace_once_with(
        block,
        &format!(
            r"(?m)^([ \t]*)(?://[ \t]*)?{}\s+(?:true|false)",
            regex::escape(name)
        ),
        label,
        |captures| {
            format!(
                "{}{} {}",
                &captures[1],
                name,
                if value { "true" } else { "false" }
            )
        },
    )
}

pub fn set_attribute_number_line(
    block: &str,
    name: &str,
    attribute: &str,
    value: f64,
    label: &str,
) -> Result<String> {
    replace_once_with(
        block,
        &format!(
            r"(?m)^([ \t]*)(?://[ \t]*)?{}\s+{}=[-\d.]+",
            regex::escape(name),
            regex::escape(attribute)
        ),
        label,
        |captures| {
            format!(
                "{}{} {}={}",
                &captures[1],
                name,
                attribute,
                kdl_float(value)
            )
        },
    )
}

pub fn qml_string(source: &str, name: &str, fallback: &str) -> String {
    let pattern = regex(&format!(
        r#"property\s+string\s+{}\s*:\s*"((?:\\.|[^"])*)""#,
        regex::escape(name)
    ));
    let Some(captures) = pattern.captures(source) else {
        return fallback.into();
    };
    serde_json::from_str::<String>(&format!("\"{}\"", &captures[1]))
        .unwrap_or_else(|_| captures[1].to_string())
}

pub fn qml_int(source: &str, name: &str, fallback: i64) -> i64 {
    capture(
        source,
        &format!(r"property\s+int\s+{}\s*:\s*(\d+)", regex::escape(name)),
        1,
    )
    .and_then(|value| value.parse().ok())
    .unwrap_or(fallback)
}

pub fn qml_bool(source: &str, name: &str, fallback: bool) -> bool {
    capture(
        source,
        &format!(
            r"property\s+bool\s+{}\s*:\s*(true|false)",
            regex::escape(name)
        ),
        1,
    )
    .map(|value| value == "true")
    .unwrap_or(fallback)
}

pub fn parse_recent_binds(block: &str) -> Vec<Value> {
    let pattern = regex(
        r#"^\s*([^\s/\{][^\{]*?)\s*\{\s*(next-window|previous-window)((?:\s+[a-z-]+="[^"]*")*)\s*;\s*\}\s*$"#,
    );
    let filter_pattern = regex(r#"\bfilter="([^"]*)""#);
    let scope_pattern = regex(r#"\bscope="([^"]*)""#);
    block
        .lines()
        .filter_map(|raw| {
            let captures = pattern.captures(raw)?;
            let attributes = &captures[3];
            Some(serde_json::json!({
                "key": captures[1].trim(),
                "direction": &captures[2],
                "filter": filter_pattern.captures(attributes).map(|value| value[1].to_string()).unwrap_or_default(),
                "scope": scope_pattern.captures(attributes).map(|value| value[1].to_string()).unwrap_or_default(),
            }))
        })
        .collect()
}

pub fn shell_split(value: &str) -> Option<Vec<String>> {
    #[derive(Clone, Copy, PartialEq, Eq)]
    enum Quote {
        None,
        Single,
        Double,
    }
    let mut words = Vec::new();
    let mut word = String::new();
    let mut quote = Quote::None;
    let mut started = false;
    let mut characters = value.chars();
    while let Some(character) = characters.next() {
        match quote {
            Quote::None => match character {
                '\'' => {
                    quote = Quote::Single;
                    started = true;
                }
                '"' => {
                    quote = Quote::Double;
                    started = true;
                }
                '\\' => {
                    word.push(characters.next()?);
                    started = true;
                }
                value if value.is_whitespace() => {
                    if started {
                        words.push(std::mem::take(&mut word));
                        started = false;
                    }
                }
                _ => {
                    word.push(character);
                    started = true;
                }
            },
            Quote::Single => {
                if character == '\'' {
                    quote = Quote::None;
                } else {
                    word.push(character);
                }
            }
            Quote::Double => match character {
                '"' => quote = Quote::None,
                '\\' => {
                    word.push(characters.next()?);
                    started = true;
                }
                _ => word.push(character),
            },
        }
    }
    if quote != Quote::None {
        return None;
    }
    if started {
        words.push(word);
    }
    Some(words)
}
