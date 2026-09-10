use anyhow::{Context, Result, bail};
use std::env;
use std::path::{Path, PathBuf};
use std::process::{ExitStatus, Stdio};
use std::time::Duration;
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWriteExt};
use tokio::process::Command;
use tokio::task::JoinHandle;
use tokio::time::timeout;
use tokio_util::sync::CancellationToken;

pub struct BoundedOutput {
    pub status: ExitStatus,
    pub stdout: Vec<u8>,
    pub stderr: Vec<u8>,
    pub stdout_truncated: bool,
    pub stderr_truncated: bool,
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
    let mut child = command
        .spawn()
        .with_context(|| format!("start {}", program.display()))?;
    let input_writer = input.map(|bytes| {
        let mut stdin = child.stdin.take().expect("piped command stdin");
        let bytes = bytes.to_vec();
        tokio::spawn(async move {
            stdin.write_all(&bytes).await?;
            stdin.shutdown().await?;
            Ok::<(), std::io::Error>(())
        })
    });
    let stdout = child.stdout.take().context("capture command stdout")?;
    let stderr = child.stderr.take().context("capture command stderr")?;
    let stdout_reader = tokio::spawn(read_bounded(stdout, output_limit));
    let stderr_reader = tokio::spawn(read_bounded(stderr, output_limit));

    let status = tokio::select! {
        _ = cancellation.cancelled() => {
            stop_child(&mut child).await;
            drain_readers(stdout_reader, stderr_reader).await;
            drain_writer(input_writer).await;
            bail!("command was cancelled")
        }
        result = timeout(deadline, child.wait()) => match result {
            Ok(status) => status.with_context(|| format!("wait for {}", program.display()))?,
            Err(_) => {
                stop_child(&mut child).await;
                drain_readers(stdout_reader, stderr_reader).await;
                drain_writer(input_writer).await;
                bail!("command timed out")
            }
        },
    };
    if let Some(writer) = input_writer {
        writer.await.context("join stdin writer")??;
    }
    let (stdout, stdout_truncated) = stdout_reader.await.context("join stdout reader")??;
    let (stderr, stderr_truncated) = stderr_reader.await.context("join stderr reader")??;
    Ok(BoundedOutput {
        status,
        stdout,
        stderr,
        stdout_truncated,
        stderr_truncated,
    })
}

async fn drain_writer(writer: Option<JoinHandle<std::io::Result<()>>>) {
    if let Some(writer) = writer {
        let _ = writer.await;
    }
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

async fn drain_readers(
    stdout: JoinHandle<Result<(Vec<u8>, bool)>>,
    stderr: JoinHandle<Result<(Vec<u8>, bool)>>,
) {
    let _ = stdout.await;
    let _ = stderr.await;
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
