mod ddc;
mod niri;
mod sunshine;

use crate::job::JobRegistry;
use anyhow::{Context, Result};
use serde_json::Value;

#[derive(Clone)]
pub struct DisplayBackend {
    jobs: JobRegistry,
}

impl DisplayBackend {
    pub fn new(jobs: JobRegistry) -> Self {
        Self { jobs }
    }

    pub async fn request(&self, method: &str, mut params: Value) -> Result<Option<Value>> {
        if !method.starts_with("display.") {
            return Ok(None);
        }
        let job_id = JobRegistry::take_job_id(&mut params);
        let job = self.jobs.begin(job_id.as_deref());
        let cancellation = job.cancellation();
        let result = match method {
            "display.ddc.get" => ddc::get(params, cancellation).await?,
            "display.ddc.set" => ddc::set(params, cancellation).await?,
            "display.niri.mode" => niri::apply_mode(params, cancellation).await?,
            "display.niri.options" => niri::options(params).await?,
            "display.niri.persist" => niri::persist(params).await?,
            "display.niri.setVrr" => niri::set_vrr(params).await?,
            "display.sunshine.apply" => sunshine::apply(params, cancellation).await?,
            "display.sunshine.status" => sunshine::status(params, cancellation).await?,
            _ => return Ok(None),
        };
        Ok(Some(result))
    }
}

pub(super) fn decode<T: serde::de::DeserializeOwned>(params: Value, name: &str) -> Result<T> {
    serde_json::from_value(params).with_context(|| format!("decode {name} request"))
}
