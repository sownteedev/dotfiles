use serde_json::Value;
use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use tokio_util::sync::CancellationToken;

#[derive(Clone, Default)]
pub struct JobRegistry {
    inner: Arc<JobRegistryInner>,
}

#[derive(Default)]
struct JobRegistryInner {
    generation: AtomicU64,
    jobs: Mutex<HashMap<String, JobEntry>>,
}

struct JobEntry {
    generation: u64,
    cancellation: CancellationToken,
}

pub struct JobHandle {
    cancellation: CancellationToken,
    guard: Option<JobGuard>,
}

impl JobHandle {
    pub fn cancellation(&self) -> CancellationToken {
        self.cancellation.clone()
    }

    pub fn is_registered(&self) -> bool {
        self.guard.is_some()
    }
}

struct JobGuard {
    generation: u64,
    job_id: String,
    registry: JobRegistry,
}

impl Drop for JobGuard {
    fn drop(&mut self) {
        let Ok(mut jobs) = self.registry.inner.jobs.lock() else {
            return;
        };
        if jobs
            .get(&self.job_id)
            .is_some_and(|entry| entry.generation == self.generation)
        {
            jobs.remove(&self.job_id);
        }
    }
}

impl JobRegistry {
    pub fn begin(&self, job_id: Option<&str>) -> JobHandle {
        let cancellation = CancellationToken::new();
        let Some(job_id) = job_id.map(str::trim).filter(|value| !value.is_empty()) else {
            return JobHandle {
                cancellation,
                guard: None,
            };
        };

        let generation = self.inner.generation.fetch_add(1, Ordering::Relaxed) + 1;
        if let Ok(mut jobs) = self.inner.jobs.lock()
            && let Some(previous) = jobs.insert(
                job_id.to_string(),
                JobEntry {
                    generation,
                    cancellation: cancellation.clone(),
                },
            )
        {
            previous.cancellation.cancel();
        }

        JobHandle {
            cancellation,
            guard: Some(JobGuard {
                generation,
                job_id: job_id.to_string(),
                registry: self.clone(),
            }),
        }
    }

    pub fn cancel(&self, job_id: &str) -> bool {
        let job_id = job_id.trim();
        if job_id.is_empty() {
            return false;
        }
        let cancellation = self
            .inner
            .jobs
            .lock()
            .ok()
            .and_then(|mut jobs| jobs.remove(job_id))
            .map(|entry| entry.cancellation);
        if let Some(cancellation) = cancellation {
            cancellation.cancel();
            true
        } else {
            false
        }
    }

    pub fn take_job_id(params: &mut Value) -> Option<String> {
        params
            .as_object_mut()
            .and_then(|object| object.remove("_job_id"))
            .and_then(|value| value.as_str().map(str::to_string))
            .filter(|value| !value.trim().is_empty())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn replacing_a_job_cancels_only_the_previous_generation() {
        let registry = JobRegistry::default();
        let first = registry.begin(Some("same"));
        let first_token = first.cancellation();
        let second = registry.begin(Some("same"));
        let second_token = second.cancellation();
        assert!(first_token.is_cancelled());
        assert!(!second_token.is_cancelled());

        drop(first);
        assert!(registry.cancel("same"));
        assert!(second_token.is_cancelled());
    }

    #[test]
    fn takes_private_job_id_from_parameters() {
        let mut params = json!({"_job_id": "job-1", "value": 2});
        assert_eq!(
            JobRegistry::take_job_id(&mut params).as_deref(),
            Some("job-1")
        );
        assert!(params.get("_job_id").is_none());
    }
}
