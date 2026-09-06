use crate::command::{BoundedOutput, command_path, run_bounded};
use anyhow::{Result, anyhow};
use serde::Deserialize;
use serde_json::{Value, json};
use std::collections::HashSet;
use std::path::Path;
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tokio::sync::Mutex;
use tokio::time::timeout;
use tokio_util::sync::CancellationToken;

const CACHE_TTL: Duration = Duration::from_secs(15 * 60);
const CHECK_TIMEOUT: Duration = Duration::from_secs(45);
const MAX_COMMAND_OUTPUT: usize = 2 * 1024 * 1024;

#[derive(Clone, Default)]
pub struct UpdatesBackend {
    cache: Arc<Mutex<Option<CachedResult>>>,
    check_gate: Arc<Mutex<()>>,
}

#[derive(Clone)]
struct CachedResult {
    expires_at: Instant,
    value: Value,
}

#[derive(Default, Deserialize)]
struct CheckParams {
    #[serde(default)]
    force: bool,
}

impl UpdatesBackend {
    pub async fn check(&self, params: Value, cancellation: CancellationToken) -> Value {
        let params: CheckParams = match serde_json::from_value(params) {
            Ok(params) => params,
            Err(_) => return result(true, Vec::new(), "Invalid update-check parameters"),
        };
        if !params.force
            && let Some(value) = self.cached().await
        {
            return value;
        }

        let _gate = self.check_gate.lock().await;
        if !params.force
            && let Some(value) = self.cached().await
        {
            return value;
        }

        let checked = match timeout(CHECK_TIMEOUT, check_updates(cancellation)).await {
            Ok(Ok(value)) => value,
            Ok(Err(error)) => result(true, Vec::new(), error.to_string()),
            Err(_) => result(true, Vec::new(), "Update check timed out"),
        };
        self.store(checked.clone()).await;
        checked
    }

    async fn cached(&self) -> Option<Value> {
        let mut cache = self.cache.lock().await;
        if cache
            .as_ref()
            .is_some_and(|cached| cached.expires_at <= Instant::now())
        {
            *cache = None;
        }
        cache.as_ref().map(|cached| cached.value.clone())
    }

    async fn store(&self, value: Value) {
        *self.cache.lock().await = Some(CachedResult {
            expires_at: Instant::now() + CACHE_TTL,
            value,
        });
    }
}

async fn check_updates(cancellation: CancellationToken) -> Result<Value> {
    let Some(yay) = command_path("yay") else {
        return Ok(result(false, Vec::new(), "yay is not installed"));
    };
    let checkupdates = command_path("checkupdates");
    let flatpak = command_path("flatpak");

    let repo_task = repo_updates(checkupdates.as_deref(), &yay, cancellation.clone());
    let aur_task = aur_updates(&yay, cancellation.clone());
    let flatpak_task = flatpak_updates(flatpak.as_deref(), cancellation);
    let (repo, aur, flatpak) = tokio::join!(repo_task, aur_task, flatpak_task);

    let packages = deduplicate(repo?.into_iter().chain(aur?).chain(flatpak?).collect());
    Ok(result(true, packages, ""))
}

async fn repo_updates(
    checkupdates: Option<&Path>,
    yay: &Path,
    cancellation: CancellationToken,
) -> Result<Vec<String>> {
    if let Some(checkupdates) = checkupdates {
        let output = run_update_command(checkupdates, &[], cancellation).await?;
        if output.status.success() || output.status.code() == Some(2) {
            return lines(if output.status.code() == Some(2) {
                &[]
            } else {
                &output.stdout
            });
        }
        return Err(anyhow!("Could not check repository updates"));
    }

    let output =
        run_update_command(yay, &["-Qu", "--repo", "--color", "never"], cancellation).await?;
    if output.status.success()
        || output.status.code() == Some(1) && output.stdout.is_empty() && output.stderr.is_empty()
    {
        return lines(&output.stdout);
    }
    Err(anyhow!("Could not check repository updates"))
}

async fn aur_updates(yay: &Path, cancellation: CancellationToken) -> Result<Vec<String>> {
    let output = run_update_command(yay, &["-Qua", "--color", "never"], cancellation).await?;
    if output.status.success()
        || output.status.code() == Some(1) && output.stdout.is_empty() && output.stderr.is_empty()
    {
        return lines(&output.stdout);
    }
    Err(anyhow!("Could not check AUR updates"))
}

async fn flatpak_updates(
    flatpak: Option<&Path>,
    cancellation: CancellationToken,
) -> Result<Vec<String>> {
    let Some(flatpak) = flatpak else {
        return Ok(Vec::new());
    };
    let system = run_update_command(
        flatpak,
        &["remote-ls", "--system", "--updates", "--columns=ref"],
        cancellation.clone(),
    )
    .await?;
    if !system.status.success() {
        return Err(anyhow!("Could not check system Flatpak updates"));
    }
    let user = run_update_command(
        flatpak,
        &["remote-ls", "--user", "--updates", "--columns=ref"],
        cancellation,
    )
    .await?;
    if !user.status.success() {
        return Err(anyhow!("Could not check user Flatpak updates"));
    }

    let mut packages = lines(&system.stdout)?
        .into_iter()
        .map(|line| format!("flatpak-system:{line}"))
        .collect::<Vec<_>>();
    packages.extend(
        lines(&user.stdout)?
            .into_iter()
            .map(|line| format!("flatpak-user:{line}")),
    );
    Ok(packages)
}

async fn run_update_command(
    program: &Path,
    arguments: &[&str],
    cancellation: CancellationToken,
) -> Result<BoundedOutput> {
    let output = run_bounded(
        program,
        arguments,
        CHECK_TIMEOUT,
        cancellation,
        MAX_COMMAND_OUTPUT,
    )
    .await?;
    if output.stdout_truncated || output.stderr_truncated {
        return Err(anyhow!("Update command output exceeded the safety limit"));
    }
    Ok(output)
}

fn lines(bytes: &[u8]) -> Result<Vec<String>> {
    let text =
        std::str::from_utf8(bytes).map_err(|_| anyhow!("Update command returned invalid text"))?;
    Ok(text
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .map(str::to_string)
        .collect())
}

fn deduplicate(packages: Vec<String>) -> Vec<String> {
    let mut seen = HashSet::new();
    packages
        .into_iter()
        .filter(|line| {
            line.split_whitespace()
                .next()
                .is_some_and(|name| seen.insert(name.to_string()))
        })
        .collect()
}

fn result(available: bool, packages: Vec<String>, error: impl Into<String>) -> Value {
    json!({
        "available": available,
        "packages": packages,
        "error": error.into(),
        "checkedAt": now_millis(),
    })
}

fn now_millis() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
        .try_into()
        .unwrap_or(u64::MAX)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deduplicates_by_package_identifier_without_reordering() {
        let packages = deduplicate(vec![
            "linux 1 -> 2".into(),
            "brave 1 -> 2".into(),
            "linux 1 -> 3".into(),
            "flatpak-user:org.example.App".into(),
        ]);
        assert_eq!(
            packages,
            vec![
                "linux 1 -> 2",
                "brave 1 -> 2",
                "flatpak-user:org.example.App"
            ]
        );
    }

    #[test]
    fn result_uses_millisecond_timestamp() {
        let checked = result(true, Vec::new(), "");
        assert!(checked["checkedAt"].as_u64().unwrap_or_default() > 1_000_000_000_000);
    }
}
