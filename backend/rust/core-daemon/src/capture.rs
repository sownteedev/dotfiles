use crate::command::{command_path, run_bounded_env};
use crate::job::JobRegistry;
use anyhow::{Context, Result, ensure};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::path::Path;
use std::time::Duration;
use tokio::io::AsyncReadExt;
use tokio_util::sync::CancellationToken;

const OUTPUT_LIMIT: usize = 256 * 1024;
const TEXT_LIMIT: usize = 8192;
const RESULT_LIMIT: usize = 16;

#[derive(Clone)]
pub struct CaptureBackend {
    jobs: JobRegistry,
}

#[derive(Deserialize)]
struct ScanParams {
    path: String,
}

#[derive(Debug, Serialize, PartialEq)]
struct QrResult {
    text: String,
    url: String,
    host: String,
}

impl CaptureBackend {
    pub fn new(jobs: JobRegistry) -> Self {
        Self { jobs }
    }

    pub async fn request(&self, method: &str, mut params: Value) -> Result<Option<Value>> {
        if method != "capture.qr.scan" {
            return Ok(None);
        }
        let job_id = JobRegistry::take_job_id(&mut params);
        let job = self.jobs.begin(job_id.as_deref());
        let params: ScanParams = serde_json::from_value(params)?;
        Ok(Some(match scan(&params.path, job.cancellation()).await {
            Ok(codes) => json!({"ok": true, "codes": codes}),
            Err(error) => json!({"ok": false, "codes": [], "message": error.to_string()}),
        }))
    }
}

async fn scan(path: &str, cancellation: CancellationToken) -> Result<Vec<QrResult>> {
    ensure!(
        Path::new(path).is_absolute(),
        "An absolute screenshot path is required"
    );
    let path = tokio::fs::canonicalize(path)
        .await
        .context("Screenshot is unavailable")?;
    let metadata = tokio::fs::metadata(&path).await?;
    ensure!(
        metadata.is_file() && metadata.len() <= 64 * 1024 * 1024,
        "Screenshot must be a regular file no larger than 64 MiB"
    );
    let mut header = [0; 12];
    tokio::fs::File::open(&path)
        .await?
        .read_exact(&mut header)
        .await?;
    ensure!(
        header.starts_with(b"\x89PNG\r\n\x1a\n")
            || header.starts_with(b"\xff\xd8\xff")
            || (&header[..4] == b"RIFF" && &header[8..] == b"WEBP"),
        "QR scanning supports PNG, JPEG and WebP screenshots"
    );
    let decoder = command_path("zbarimg").context("Install zbar to read screenshot QR codes")?;
    let path = path.to_str().context("Screenshot path is not UTF-8")?;
    let output = run_bounded_env(
        &decoder,
        &[
            "--quiet",
            "--nodbus",
            "--nodisplay",
            "--xml",
            "-Sdisable",
            "-Sqrcode.enable",
            "-Sqrcode.binary",
            path,
        ],
        &[
            ("MAGICK_MEMORY_LIMIT", "128MiB"),
            ("MAGICK_MAP_LIMIT", "128MiB"),
            ("MAGICK_DISK_LIMIT", "0"),
        ],
        Duration::from_secs(5),
        cancellation.clone(),
        OUTPUT_LIMIT,
    )
    .await?;
    // zbarimg returns 4 when the image contains no readable symbols.
    if output.status.code() == Some(4) {
        return Ok(Vec::new());
    }
    ensure!(
        output.status.success(),
        "Could not read QR codes from this screenshot"
    );
    ensure!(
        !output.stdout_truncated,
        "QR decoder output exceeded the limit"
    );
    let xml = std::str::from_utf8(&output.stdout).context("Invalid QR decoder output")?;
    // zbar's XML base64 output can corrupt high-bit bytes on signed-char builds.
    // Read raw binary output only when needed, framing by XML byte lengths rather
    // than newlines (a QR payload may itself contain newlines).
    let raw = if xml.contains("format='base64'") || xml.contains("format=\"base64\"") {
        let output = run_bounded_env(
            &decoder,
            &[
                "--quiet",
                "--nodbus",
                "--nodisplay",
                "--raw",
                "-Sdisable",
                "-Sqrcode.enable",
                "-Sqrcode.binary",
                path,
            ],
            &[
                ("MAGICK_MEMORY_LIMIT", "128MiB"),
                ("MAGICK_MAP_LIMIT", "128MiB"),
                ("MAGICK_DISK_LIMIT", "0"),
            ],
            Duration::from_secs(3),
            cancellation,
            OUTPUT_LIMIT,
        )
        .await?;
        ensure!(
            output.status.success() && !output.stdout_truncated,
            "Could not read QR text"
        );
        Some(output.stdout)
    } else {
        None
    };
    let after = tokio::fs::metadata(path).await?;
    ensure!(
        metadata.len() == after.len() && metadata.modified()? == after.modified()?,
        "Screenshot changed while scanning"
    );
    parse_codes_with_raw(xml, raw.as_deref())
}

#[cfg(test)]
fn parse_codes(xml: &str) -> Result<Vec<QrResult>> {
    parse_codes_with_raw(xml, None)
}

fn parse_codes_with_raw(xml: &str, mut raw: Option<&[u8]>) -> Result<Vec<QrResult>> {
    let document = roxmltree::Document::parse_with_options(
        xml,
        roxmltree::ParsingOptions {
            nodes_limit: 4096,
            ..Default::default()
        },
    )
    .context("Invalid QR decoder output")?;
    let mut codes: Vec<QrResult> = Vec::new();
    for symbol in document
        .descendants()
        .filter(|node| node.has_tag_name("symbol"))
    {
        if symbol.attribute("type") != Some("QR-Code") {
            continue;
        }
        let Some(data) = symbol.children().find(|node| node.has_tag_name("data")) else {
            continue;
        };
        let xml_text: String = data
            .children()
            .filter(|node| node.is_text())
            .filter_map(|node| node.text())
            .collect();
        let text = if let Some(bytes) = raw {
            let length = if data.attribute("format") == Some("base64") {
                data.attribute("length")
                    .context("Missing QR byte length")?
                    .parse::<usize>()?
            } else {
                xml_text.len()
            };
            ensure!(
                length < bytes.len() && bytes[length] == b'\n',
                "QR byte framing changed"
            );
            let payload = &bytes[..length];
            raw = Some(&bytes[length + 1..]);
            if data.attribute("format").is_none() {
                ensure!(
                    payload == xml_text.as_bytes(),
                    "QR content changed while scanning"
                );
            }
            let Ok(text) = std::str::from_utf8(payload) else {
                continue;
            };
            text.to_string()
        } else {
            if data.attribute("format").is_some() || data.attribute("encoding").is_some() {
                continue;
            }
            xml_text
        };
        if text.is_empty()
            || text.len() > TEXT_LIMIT
            || text.contains('\0')
            || codes.iter().any(|code| code.text == text)
        {
            continue;
        }
        let (url, host) = web_link(&text).unwrap_or_default();
        codes.push(QrResult { text, url, host });
        if codes.len() == RESULT_LIMIT {
            break;
        }
    }
    Ok(codes)
}

fn web_link(text: &str) -> Option<(String, String)> {
    let candidate = text.trim();
    if candidate.chars().any(|ch| ch.is_control() || ch == '\\') {
        return None;
    }
    let lower = candidate.to_ascii_lowercase();
    if !lower.starts_with("https://") && !lower.starts_with("http://") {
        return None;
    }
    let url = reqwest::Url::parse(candidate).ok()?;
    if !url.username().is_empty() || url.password().is_some() {
        return None;
    }
    let host = url.host_str()?.to_string();
    Some((url.to_string(), host))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_multiple_codes_and_preserves_text() {
        let xml = r#"<barcodes xmlns="http://zbar.sourceforge.net/2008/barcode"><source><index>
          <symbol type="QR-Code"><data><![CDATA[https://example.com/?a=1&b=2]]></data></symbol>
          <symbol type="QR-Code"><data><![CDATA[line one
line two <hello>]]></data></symbol>
          <symbol type="QR-Code"><data>https://example.com/?a=1&amp;b=2</data></symbol>
          <symbol type="EAN-13"><data>123456</data></symbol>
        </index></source></barcodes>"#;
        let codes = parse_codes(xml).unwrap();
        assert_eq!(codes.len(), 2);
        assert_eq!(codes[0].host, "example.com");
        assert_eq!(codes[0].url, "https://example.com/?a=1&b=2");
        assert_eq!(codes[1].text, "line one\nline two <hello>");
        assert!(codes[1].url.is_empty());
    }

    #[test]
    fn only_explicit_safe_web_links_have_open_actions() {
        for text in [
            "javascript:alert(1)",
            "file:///etc/passwd",
            "data:text/html,test",
            "WIFI:S:test;P:secret;;",
            "mailto:a@example.com",
            "https://user:pass@example.com",
            "https://example.com\n/evil",
            "https://example.com\\@other.test",
            "https:example.com",
            "$(touch /tmp/qr)",
        ] {
            assert_eq!(web_link(text), None, "{text}");
        }
        assert_eq!(
            web_link(" https://example.com/test ").unwrap().1,
            "example.com"
        );
        assert!(
            web_link("https://éxample.com")
                .unwrap()
                .1
                .starts_with("xn--")
        );
    }

    #[test]
    fn rejects_dtd_binary_and_oversized_payloads() {
        assert!(parse_codes("<!DOCTYPE x [<!ENTITY a 'test'>]><x>&a;</x>").is_err());
        let xml = format!(
            "<barcodes><symbol type='QR-Code'><data format='base64'>AA==</data></symbol><symbol type='QR-Code'><data>{}</data></symbol></barcodes>",
            "a".repeat(TEXT_LIMIT + 1)
        );
        assert!(parse_codes(&xml).unwrap().is_empty());
        assert!(parse_codes("<broken>").is_err());
    }

    #[test]
    fn raw_fallback_preserves_unicode_and_embedded_newlines() {
        let text = "Dòng một\nDòng hai";
        let xml = format!(
            "<barcodes><symbol type='QR-Code'><data format='base64' length='{}'>ignored</data></symbol><symbol type='QR-Code'><data>https://example.com</data></symbol></barcodes>",
            text.len()
        );
        let raw = format!("{text}\nhttps://example.com\n");
        let codes = parse_codes_with_raw(&xml, Some(raw.as_bytes())).unwrap();
        assert_eq!(codes[0].text, text);
        assert_eq!(codes[1].host, "example.com");
        assert!(parse_codes_with_raw(&xml, Some(b"truncated")).is_err());
    }
}
