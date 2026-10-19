use anyhow::{Context, Result};
use nix::sys::signal::{Signal, killpg};
use nix::unistd::Pid;
use std::env;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{ExitStatus, Stdio};
use std::time::Duration;
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWriteExt};
use tokio::process::Command;
use tokio::time::timeout;
use tokio_util::sync::CancellationToken;

pub struct BoundedOutput {
    pub status: ExitStatus,
    pub stdout: Vec<u8>,
    pub stderr: Vec<u8>,
    pub stdout_truncated: bool,
    pub stderr_truncated: bool,
}

struct CommandGroup(Option<Pid>);

impl CommandGroup {
    fn terminate(&mut self) {
        if let Some(group) = self.0.take() {
            let _ = killpg(group, Signal::SIGKILL);
        }
    }
}

impl Drop for CommandGroup {
    fn drop(&mut self) {
        self.terminate();
    }
}

pub fn command_path(name: &str) -> Option<PathBuf> {
    if name.contains('/') {
        let path = PathBuf::from(name);
        return path.is_file().then_some(path);
    }
    env::var_os("PATH").and_then(|paths| {
        env::split_paths(&paths)
            .map(|directory| directory.join(name))
            .find(|candidate| candidate.is_file())
    })
}

pub async fn run_bounded(
    program: &Path,
    arguments: &[&str],
    deadline: Duration,
    cancellation: CancellationToken,
    output_limit: usize,
) -> Result<BoundedOutput> {
    run_bounded_inner(
        program,
        arguments,
        &[],
        None,
        deadline,
        cancellation,
        output_limit,
    )
    .await
}

pub async fn run_bounded_env(
    program: &Path,
    arguments: &[&str],
    environment: &[(&str, &str)],
    deadline: Duration,
    cancellation: CancellationToken,
    output_limit: usize,
) -> Result<BoundedOutput> {
    run_bounded_inner(
        program,
        arguments,
        environment,
        None,
        deadline,
        cancellation,
        output_limit,
    )
    .await
}

pub async fn run_bounded_input(
    program: &Path,
    arguments: &[&str],
    input: &[u8],
    deadline: Duration,
    cancellation: CancellationToken,
    output_limit: usize,
) -> Result<BoundedOutput> {
    run_bounded_inner(
        program,
        arguments,
        &[],
        Some(input),
        deadline,
        cancellation,
        output_limit,
    )
    .await
}

// Commands such as wl-copy fork an owner that keeps stderr open. When only the
// exit status matters, do not capture pipes whose EOF depends on that owner.
pub async fn run_bounded_input_status(
    program: &Path,
    arguments: &[&str],
    input: &[u8],
    deadline: Duration,
    cancellation: CancellationToken,
) -> Result<ExitStatus> {
    let mut child = Command::new(program)
        .args(arguments)
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .kill_on_drop(true)
        .spawn()
        .with_context(|| format!("start {}", program.display()))?;

    let result = tokio::select! {
        biased;
        _ = cancellation.cancelled() => Err(anyhow::anyhow!("command was cancelled")),
        result = timeout(deadline, async {
            let mut stdin = child.stdin.take().context("open command stdin")?;
            stdin.write_all(input).await.context("write command stdin")?;
            drop(stdin);
            child.wait().await.context("wait for command")
        }) => result.context("command timed out").and_then(|result| result),
    };
    if result.is_err() {
        stop_child(&mut child).await;
    }
    result
}

async fn run_bounded_inner(
    program: &Path,
    arguments: &[&str],
    environment: &[(&str, &str)],
    input: Option<&[u8]>,
    deadline: Duration,
    cancellation: CancellationToken,
    output_limit: usize,
) -> Result<BoundedOutput> {
    let mut command = Command::new(program);
    command
        .args(arguments)
        .envs(environment.iter().copied())
        .stdin(if input.is_some() {
            Stdio::piped()
        } else {
            Stdio::null()
        })
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true);
    command.as_std_mut().process_group(0);
    let mut child = command
        .spawn()
        .with_context(|| format!("start {}", program.display()))?;
    let mut group = CommandGroup(child.id().map(|pid| Pid::from_raw(pid as i32)));
    let stdin = child.stdin.take();
    let stdout = child.stdout.take().context("capture command stdout")?;
    let stderr = child.stderr.take().context("capture command stderr")?;
    let result = tokio::select! {
        biased;
        _ = cancellation.cancelled() => Err(anyhow::anyhow!("command was cancelled")),
        result = timeout(deadline, async {
            tokio::try_join!(
                async { child.wait().await.context("wait for command") },
                async {
                    if let (Some(mut stdin), Some(bytes)) = (stdin, input) {
                        stdin.write_all(bytes).await.context("write command stdin")?;
                        stdin.shutdown().await.context("close command stdin")?;
                    }
                    Ok::<(), anyhow::Error>(())
                },
                read_bounded(stdout, output_limit),
                read_bounded(stderr, output_limit),
            )
        }) => result.context("command timed out").and_then(|result| result),
    };
    if result.is_err() {
        group.terminate();
        stop_child(&mut child).await;
    } else {
        group.0 = None;
    }
    let (status, (), (stdout, stdout_truncated), (stderr, stderr_truncated)) = result?;
    Ok(BoundedOutput {
        status,
        stdout,
        stderr,
        stdout_truncated,
        stderr_truncated,
    })
}

async fn read_bounded<R>(mut reader: R, limit: usize) -> Result<(Vec<u8>, bool)>
where
    R: AsyncRead + Unpin,
{
    let mut retained = Vec::with_capacity(limit.min(64 * 1024));
    let mut buffer = [0_u8; 16 * 1024];
    let mut truncated = false;
    loop {
        let read = reader.read(&mut buffer).await?;
        if read == 0 {
            break;
        }
        let remaining = limit.saturating_sub(retained.len());
        let keep = remaining.min(read);
        retained.extend_from_slice(&buffer[..keep]);
        truncated |= keep < read;
    }
    Ok((retained, truncated))
}

async fn stop_child(child: &mut tokio::process::Child) {
    let _ = child.start_kill();
    let _ = child.wait().await;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn retains_only_the_configured_output_limit() {
        let output = run_bounded(
            Path::new("/bin/sh"),
            &["-c", "printf '1234567890'"],
            Duration::from_secs(2),
            CancellationToken::new(),
            4,
        )
        .await
        .expect("run bounded command");
        assert!(output.status.success());
        assert_eq!(output.stdout, b"1234");
        assert!(output.stdout_truncated);
    }

    #[tokio::test]
    async fn timeout_covers_descendants_holding_output_pipes() {
        for script in ["sleep 5 & wait", "sleep 5 & exit 0"] {
            let result = timeout(
                Duration::from_secs(2),
                run_bounded(
                    Path::new("/bin/sh"),
                    &["-c", script],
                    Duration::from_millis(100),
                    CancellationToken::new(),
                    1024,
                ),
            )
            .await
            .expect("descendant pipes must not extend the deadline");
            let error = result.err().expect("command must time out");
            assert!(error.to_string().contains("timed out"));
        }
    }

    #[tokio::test]
    async fn cancellation_covers_descendants_holding_output_pipes() {
        let cancellation = CancellationToken::new();
        let cancel = async {
            tokio::time::sleep(Duration::from_millis(100)).await;
            cancellation.cancel();
        };
        let command = run_bounded(
            Path::new("/bin/sh"),
            &["-c", "sleep 5 & wait"],
            Duration::from_secs(5),
            cancellation.clone(),
            1024,
        );
        let (result, ()) = timeout(Duration::from_secs(2), async {
            tokio::join!(command, cancel)
        })
        .await
        .expect("cancellation must not wait for descendant pipes");
        let error = result.err().expect("command must be cancelled");
        assert!(error.to_string().contains("cancelled"));
    }

    #[tokio::test]
    async fn dropping_command_future_kills_descendants() {
        let pid_path =
            env::temp_dir().join(format!("sownteeshell-command-{}", uuid::Uuid::new_v4()));
        let command_path = pid_path.clone();
        let command = tokio::spawn(async move {
            run_bounded(
                Path::new("/bin/sh"),
                &[
                    "-c",
                    "sleep 5 & echo $! > \"$1\"; wait",
                    "test",
                    command_path.to_str().unwrap(),
                ],
                Duration::from_secs(5),
                CancellationToken::new(),
                1024,
            )
            .await
        });
        let descendant = timeout(Duration::from_secs(2), async {
            loop {
                if let Ok(text) = std::fs::read_to_string(&pid_path)
                    && let Ok(pid) = text.trim().parse::<u32>()
                {
                    break pid;
                }
                tokio::time::sleep(Duration::from_millis(10)).await;
            }
        })
        .await;
        command.abort();
        let _ = command.await;
        let _ = std::fs::remove_file(pid_path);
        let descendant = descendant.expect("test child must start");
        timeout(Duration::from_secs(2), async {
            loop {
                let status = std::fs::read_to_string(format!("/proc/{descendant}/stat"));
                let exited = match status {
                    Err(_) => true,
                    Ok(text) => text
                        .rsplit_once(") ")
                        .is_some_and(|(_, fields)| fields.starts_with('Z')),
                };
                if exited {
                    break;
                }
                tokio::time::sleep(Duration::from_millis(10)).await;
            }
        })
        .await
        .expect("dropping a command must not orphan a running descendant");
    }

    #[tokio::test]
    async fn status_command_times_out_while_input_is_blocked() {
        let error = run_bounded_input_status(
            Path::new("/bin/sleep"),
            &["5"],
            &vec![0; 1024 * 1024],
            Duration::from_millis(50),
            CancellationToken::new(),
        )
        .await
        .expect_err("timeout must also cover writing stdin");
        assert!(error.to_string().contains("timed out"));
    }

    #[tokio::test]
    async fn status_command_honors_cancellation() {
        let cancellation = CancellationToken::new();
        cancellation.cancel();
        let error = run_bounded_input_status(
            Path::new("/bin/sleep"),
            &["5"],
            &[],
            Duration::from_secs(2),
            cancellation,
        )
        .await
        .expect_err("cancelled commands must not wait for exit");
        assert!(error.to_string().contains("cancelled"));
    }
}
