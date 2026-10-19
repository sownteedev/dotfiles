use super::{util::failure, wallhaven};
use anyhow::Result;
use reqwest::Client;
use serde::Deserialize;
use serde_json::{Value, json};
use std::time::Duration;
use tokio::task::JoinSet;
use tokio_util::sync::CancellationToken;

#[derive(Default, Deserialize)]
struct Params {
    ids: Vec<String>,
    #[serde(default)]
    api_key: String,
}

pub async fn fetch(
    client: &Client,
    params: Value,
    workshop: bool,
    cancellation: CancellationToken,
) -> Result<Value> {
    let Ok(params) = serde_json::from_value::<Params>(params) else {
        return Ok(failure("invalid_request", "Expected wallpaper IDs"));
    };
    let limit = if workshop { 50 } else { 12 };
    if params.ids.is_empty()
        || params.ids.len() > limit
        || params.ids.iter().any(|id| !valid_id(id, workshop))
    {
        return Ok(failure(
            "invalid_request",
            "Invalid wallpaper statistics IDs",
        ));
    }
    let mut ids = params.ids;
    ids.sort();
    ids.dedup();
    if !workshop {
        let mut jobs = JoinSet::new();
        for id in ids {
            let client = client.clone();
            let api_key = params.api_key.clone();
            let cancellation = cancellation.clone();
            jobs.spawn(async move {
                let response =
                    wallhaven::api_get(&client, &format!("/w/{id}"), &[], &api_key, cancellation)
                        .await
                        .ok()?;
                if response.get("ok") == Some(&Value::Bool(false))
                    || response["data"]["id"].as_str() != Some(id.as_str())
                {
                    return None;
                }
                Some(json!({"id": id, "count": count(&response["data"]["favorites"])?}))
            });
        }
        let mut items = Vec::new();
        while let Some(result) = jobs.join_next().await {
            if let Ok(Some(item)) = result {
                items.push(item);
            }
        }
        return Ok(json!({"ok": true, "items": items}));
    }
    let mut form = vec![("itemcount".to_owned(), ids.len().to_string())];
    for (index, id) in ids.iter().enumerate() {
        form.push((format!("publishedfileids[{index}]"), id.clone()));
    }
    let request = client
        .post("https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/")
        .header(
            reqwest::header::USER_AGENT,
            "SownteeShell-Wallpaper-Workshop/1.0",
        )
        .timeout(Duration::from_secs(30))
        .form(&form);
    let response = tokio::select! {
        _ = cancellation.cancelled() => return Ok(failure("cancelled", "Statistics request was cancelled")),
        response = request.send() => response,
    };
    let Ok(mut response) = response else {
        return Ok(failure(
            "network_error",
            "Could not load wallpaper statistics",
        ));
    };
    if !response.status().is_success() {
        return Ok(failure("http_error", "Could not load wallpaper statistics"));
    }
    let mut bytes = Vec::new();
    loop {
        let chunk = tokio::select! {
            _ = cancellation.cancelled() => return Ok(failure("cancelled", "Statistics request was cancelled")),
            chunk = response.chunk() => chunk,
        };
        match chunk {
            Ok(Some(chunk)) => {
                if bytes.len().saturating_add(chunk.len()) > 8 * 1024 * 1024 {
                    return Ok(failure(
                        "response_too_large",
                        "Statistics response exceeded 8 MiB",
                    ));
                }
                bytes.extend_from_slice(&chunk);
            }
            Ok(None) => break,
            Err(_) => {
                return Ok(failure(
                    "invalid_response",
                    "Unreadable wallpaper statistics",
                ));
            }
        }
    }
    let Ok(payload) = serde_json::from_slice::<Value>(&bytes) else {
        return Ok(failure(
            "invalid_response",
            "Unreadable wallpaper statistics",
        ));
    };
    Ok(json!({"ok": true, "items": steam_counts(&payload, &ids)}))
}

fn valid_id(id: &str, workshop: bool) -> bool {
    if workshop {
        !id.is_empty()
            && id.bytes().all(|byte| byte.is_ascii_digit())
            && id.parse::<u64>().is_ok_and(|value| value > 0)
    } else {
        id.len() == 6
            && id
                .bytes()
                .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit())
    }
}

pub(super) fn count(value: &Value) -> Option<u64> {
    value.as_u64().or_else(|| value.as_str()?.parse().ok())
}

fn steam_counts(payload: &Value, ids: &[String]) -> Vec<Value> {
    payload["response"]["publishedfiledetails"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|item| {
            let id = item["publishedfileid"].as_str()?;
            if count(&item["result"]) != Some(1)
                || count(&item["consumer_app_id"]) != Some(431960)
                || !ids.iter().any(|requested| requested == id)
            {
                return None;
            }
            Some(json!({"id": id, "count": count(&item["subscriptions"])?}))
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validates_provider_ids() {
        assert!(valid_id("2696451767", true));
        assert!(valid_id("abc123", false));
        for id in ["", "../foo", "0", "18446744073709551616"] {
            assert!(!valid_id(id, true));
        }
        assert!(!valid_id("ABC123", false));
    }

    #[test]
    fn preserves_zero_without_inventing_missing_counts() {
        assert_eq!(count(&json!(0)), Some(0));
        assert_eq!(count(&json!("42")), Some(42));
        for value in [Value::Null, json!(-1), json!(1.5), json!("invalid")] {
            assert_eq!(count(&value), None);
        }
    }

    #[test]
    fn steam_counts_only_requested_successful_wallpapers() {
        let base = json!({"publishedfileid": "123", "consumer_app_id": 431960, "result": 1, "subscriptions": 0, "favorited": 99});
        let mut items = vec![base.clone()];
        for (field, value) in [
            ("result", json!(9)),
            ("consumer_app_id", json!(1)),
            ("publishedfileid", json!("456")),
            ("subscriptions", Value::Null),
        ] {
            let mut invalid = base.clone();
            invalid[field] = value;
            items.push(invalid);
        }
        let payload = json!({"response": {"publishedfiledetails": items}});
        assert_eq!(
            steam_counts(&payload, &["123".into()]),
            vec![json!({"id": "123", "count": 0})]
        );
    }
}
