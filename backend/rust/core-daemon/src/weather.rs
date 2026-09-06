use crate::job::JobRegistry;
use crate::network::NetworkClient;
use anyhow::{Context, Result};
use reqwest::{StatusCode, Url};
use serde::Deserialize;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::Mutex;
use tokio_util::sync::CancellationToken;

const CACHE_ENTRY_LIMIT: usize = 16;
const FORECAST_TTL: Duration = Duration::from_secs(20 * 60);
const FORECAST_URL: &str = "https://api.openweathermap.org/data/3.0/onecall";
const LOCATION_TTL: Duration = Duration::from_secs(24 * 60 * 60);
const LOCATION_URL: &str = "https://api.openweathermap.org/geo/1.0/reverse";
const MAX_RESPONSE_BYTES: usize = 8 * 1024 * 1024;
const USER_AGENT: &str = "SownteeShell/1.0 weather";

#[derive(Clone)]
pub struct WeatherBackend {
    forecast_cache: Arc<Mutex<HashMap<String, CacheEntry>>>,
    forecast_gate: Arc<Mutex<()>>,
    jobs: JobRegistry,
    location_cache: Arc<Mutex<HashMap<String, CacheEntry>>>,
    location_gate: Arc<Mutex<()>>,
    network: NetworkClient,
}

#[derive(Clone)]
struct CacheEntry {
    expires_at: Instant,
    stored_at: Instant,
    value: Value,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct WeatherParams {
    #[serde(default)]
    api_key: String,
    #[serde(default)]
    latitude: Value,
    #[serde(default)]
    longitude: Value,
}

struct Coordinates {
    latitude: f64,
    longitude: f64,
}

impl WeatherBackend {
    pub fn new(network: NetworkClient, jobs: JobRegistry) -> Self {
        Self {
            forecast_cache: Arc::new(Mutex::new(HashMap::new())),
            forecast_gate: Arc::new(Mutex::new(())),
            jobs,
            location_cache: Arc::new(Mutex::new(HashMap::new())),
            location_gate: Arc::new(Mutex::new(())),
            network,
        }
    }

    pub async fn request(&self, method: &str, mut params: Value) -> Result<Option<Value>> {
        if !method.starts_with("weather.") {
            return Ok(None);
        }
        let job_id = JobRegistry::take_job_id(&mut params);
        let job = self.jobs.begin(job_id.as_deref());
        let cancellation = job.cancellation();
        let params: WeatherParams =
            serde_json::from_value(params).context("decode weather request")?;
        let result = match method {
            "weather.forecast" => self.forecast(params, cancellation).await?,
            "weather.location" => self.location(params, cancellation).await?,
            _ => return Ok(None),
        };
        Ok(Some(result))
    }

    async fn forecast(
        &self,
        params: WeatherParams,
        cancellation: CancellationToken,
    ) -> Result<Value> {
        let (coordinates, api_key) = match validate_params(params) {
            Ok(value) => value,
            Err(message) => return Ok(failure("invalid_params", message)),
        };
        let key = cache_key(&coordinates, &api_key);
        if let Some(value) = cached(&self.forecast_cache, &key).await {
            return Ok(value);
        }
        let _gate = self.forecast_gate.lock().await;
        if let Some(value) = cached(&self.forecast_cache, &key).await {
            return Ok(value);
        }

        let mut url = Url::parse(FORECAST_URL)?;
        {
            let mut query = url.query_pairs_mut();
            query
                .append_pair("lat", &coordinates.latitude.to_string())
                .append_pair("lon", &coordinates.longitude.to_string())
                .append_pair("appid", &api_key)
                .append_pair("units", "metric")
                .append_pair("exclude", "minutely,alerts");
        }
        let result = self
            .request_json(url, Duration::from_secs(25), cancellation)
            .await?;
        if result.get("ok").and_then(Value::as_bool) == Some(false) {
            return Ok(result);
        }
        if !result.is_object() || result.get("current").is_none() {
            return Ok(failure(
                "invalid_response",
                "OpenWeather returned invalid forecast data",
            ));
        }
        store(&self.forecast_cache, key, result.clone(), FORECAST_TTL).await;
        Ok(result)
    }

    async fn location(
        &self,
        params: WeatherParams,
        cancellation: CancellationToken,
    ) -> Result<Value> {
        let (coordinates, api_key) = match validate_params(params) {
            Ok(value) => value,
            Err(message) => return Ok(failure("invalid_params", message)),
        };
        let key = cache_key(&coordinates, &api_key);
        if let Some(value) = cached(&self.location_cache, &key).await {
            return Ok(value);
        }
        let _gate = self.location_gate.lock().await;
        if let Some(value) = cached(&self.location_cache, &key).await {
            return Ok(value);
        }

        let mut url = Url::parse(LOCATION_URL)?;
        {
            let mut query = url.query_pairs_mut();
            query
                .append_pair("lat", &coordinates.latitude.to_string())
                .append_pair("lon", &coordinates.longitude.to_string())
                .append_pair("limit", "1")
                .append_pair("appid", &api_key);
        }
        let result = self
            .request_json(url, Duration::from_secs(15), cancellation)
            .await?;
        if result.get("ok").and_then(Value::as_bool) == Some(false) {
            return Ok(result);
        }
        if !result.is_array() {
            return Ok(failure(
                "invalid_response",
                "OpenWeather returned invalid location data",
            ));
        }
        store(&self.location_cache, key, result.clone(), LOCATION_TTL).await;
        Ok(result)
    }

    async fn request_json(
        &self,
        url: Url,
        deadline: Duration,
        cancellation: CancellationToken,
    ) -> Result<Value> {
        let client = self.network.client()?;
        let response = tokio::select! {
            _ = cancellation.cancelled() => return Ok(failure("cancelled", "Weather request was cancelled")),
            response = client.get(url).header(reqwest::header::USER_AGENT, USER_AGENT).timeout(deadline).send() => response,
        };
        let mut response = match response {
            Ok(response) => response,
            Err(error) if error.is_timeout() => {
                return Ok(failure("timeout", "Weather request timed out"));
            }
            Err(_) => return Ok(failure("offline", "Could not reach OpenWeather")),
        };
        if response.url().scheme() != "https"
            || response.url().host_str() != Some("api.openweathermap.org")
        {
            return Ok(failure(
                "invalid_response",
                "OpenWeather redirected to an unexpected host",
            ));
        }
        if !response.status().is_success() {
            let (code, message) = match response.status() {
                StatusCode::UNAUTHORIZED | StatusCode::FORBIDDEN => {
                    ("invalid_api_key", "OpenWeather rejected the API key")
                }
                StatusCode::TOO_MANY_REQUESTS => {
                    ("rate_limited", "OpenWeather request limit was reached")
                }
                _ => ("http_error", "OpenWeather request failed"),
            };
            return Ok(failure_with_status(
                code,
                message,
                response.status().as_u16(),
            ));
        }

        let mut bytes = Vec::new();
        loop {
            let chunk = tokio::select! {
                _ = cancellation.cancelled() => return Ok(failure("cancelled", "Weather request was cancelled")),
                chunk = response.chunk() => chunk,
            };
            let chunk = match chunk {
                Ok(Some(chunk)) => chunk,
                Ok(None) => break,
                Err(_) => return Ok(failure("offline", "Weather response was interrupted")),
            };
            if bytes.len().saturating_add(chunk.len()) > MAX_RESPONSE_BYTES {
                return Ok(failure(
                    "invalid_response",
                    "OpenWeather response was too large",
                ));
            }
            bytes.extend_from_slice(&chunk);
        }
        match serde_json::from_slice(&bytes) {
            Ok(value) => Ok(value),
            Err(_) => Ok(failure(
                "invalid_response",
                "OpenWeather returned invalid JSON",
            )),
        }
    }
}

fn validate_params(params: WeatherParams) -> std::result::Result<(Coordinates, String), String> {
    let latitude = number(&params.latitude).ok_or_else(|| "Latitude is invalid".to_string())?;
    let longitude = number(&params.longitude).ok_or_else(|| "Longitude is invalid".to_string())?;
    if !(-90.0..=90.0).contains(&latitude) {
        return Err("Latitude must be between -90 and 90".to_string());
    }
    if !(-180.0..=180.0).contains(&longitude) {
        return Err("Longitude must be between -180 and 180".to_string());
    }
    let api_key = params.api_key.trim().to_string();
    if api_key.is_empty() {
        return Err("OpenWeather API key is not configured".to_string());
    }
    Ok((
        Coordinates {
            latitude,
            longitude,
        },
        api_key,
    ))
}

fn number(value: &Value) -> Option<f64> {
    value
        .as_f64()
        .or_else(|| value.as_str().and_then(|value| value.trim().parse().ok()))
        .filter(|value| value.is_finite())
}

fn cache_key(coordinates: &Coordinates, api_key: &str) -> String {
    let key_hash = format!("{:x}", Sha256::digest(api_key.as_bytes()));
    format!(
        "{:.6},{:.6}:{}",
        coordinates.latitude,
        coordinates.longitude,
        &key_hash[..16]
    )
}

async fn cached(cache: &Mutex<HashMap<String, CacheEntry>>, key: &str) -> Option<Value> {
    let mut cache = cache.lock().await;
    let now = Instant::now();
    cache.retain(|_, entry| entry.expires_at > now);
    cache.get(key).map(|entry| entry.value.clone())
}

async fn store(
    cache: &Mutex<HashMap<String, CacheEntry>>,
    key: String,
    value: Value,
    ttl: Duration,
) {
    let mut cache = cache.lock().await;
    let now = Instant::now();
    cache.insert(
        key,
        CacheEntry {
            expires_at: now + ttl,
            stored_at: now,
            value,
        },
    );
    while cache.len() > CACHE_ENTRY_LIMIT {
        let Some(oldest) = cache
            .iter()
            .min_by_key(|(_, entry)| entry.stored_at)
            .map(|(key, _)| key.clone())
        else {
            break;
        };
        cache.remove(&oldest);
    }
}

fn failure(code: &str, message: impl Into<String>) -> Value {
    json!({"ok": false, "code": code, "message": message.into()})
}

fn failure_with_status(code: &str, message: &str, status: u16) -> Value {
    json!({"ok": false, "code": code, "message": message, "status": status})
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validates_coordinate_ranges_and_accepts_strings() {
        let params = WeatherParams {
            api_key: "secret".into(),
            latitude: json!("21.0285"),
            longitude: json!(105.8542),
        };
        let (coordinates, _) = validate_params(params).expect("valid coordinates");
        assert_eq!(coordinates.latitude, 21.0285);
        assert_eq!(coordinates.longitude, 105.8542);
    }

    #[test]
    fn cache_key_does_not_contain_the_api_key() {
        let key = cache_key(
            &Coordinates {
                latitude: 1.0,
                longitude: 2.0,
            },
            "private-api-key",
        );
        assert!(!key.contains("private-api-key"));
    }
}
