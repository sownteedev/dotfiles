use crate::model::{GpuStats, RankedProcess};
use crate::system::read_text;
use std::collections::HashMap;
use std::ffi::OsStr;
use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::thread;
use std::time::{Duration, Instant};

pub struct NvidiaReader {
    device: Option<PathBuf>,
}

impl NvidiaReader {
    pub fn new() -> Self {
        Self {
            device: find_device(),
        }
    }

    pub fn stats(&self) -> GpuStats {
        let Some(device) = self.device.as_ref() else {
            return GpuStats::default();
        };
        if read_text(device.join("power/runtime_status")) == "suspended" {
            return GpuStats::default();
        }

        let output = run_nvidia_smi([
            "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total",
            "--format=csv,noheader,nounits",
        ]);
        let Some(line) = output.lines().next() else {
            return GpuStats::default();
        };
        let fields: Vec<&str> = line.split(',').map(str::trim).collect();
        if fields.len() < 4 {
            return GpuStats::default();
        }
        GpuStats {
            usage: fields[0].parse().unwrap_or(0.0),
            temperature: fields[1].parse().unwrap_or(0),
            memory_used: fields[2].parse().unwrap_or(0.0),
            memory_total: fields[3].parse().unwrap_or(0.0),
        }
    }

    pub fn model_name(&self) -> String {
        let Some(device) = self.device.as_ref() else {
            return String::new();
        };
        let Some(address) = device.file_name().and_then(OsStr::to_str) else {
            return String::new();
        };
        let Ok(output) = Command::new("lspci").args(["-s", address]).output() else {
            return String::new();
        };
        let line = String::from_utf8_lossy(&output.stdout);
        if let (Some(open), Some(close)) = (line.find("[GeForce"), line.find(']'))
            && close > open
        {
            return format!("NVIDIA {}", &line[open + 1..close]);
        }
        line.split_once(": ")
            .map(|(_, value)| value.trim().to_string())
            .unwrap_or_default()
    }

    pub fn power_draw(&self) -> Option<f64> {
        let device = self.device.as_ref()?;
        if read_text(device.join("power/runtime_status")) == "suspended" {
            return None;
        }
        run_nvidia_smi(["--query-gpu=power.draw", "--format=csv,noheader,nounits"])
            .lines()
            .next()?
            .trim()
            .parse()
            .ok()
    }

    pub fn top_processes(&self) -> Vec<RankedProcess> {
        let output = run_nvidia_smi(["pmon", "-c", "1", "-s", "m"]);
        let mut totals: HashMap<String, f64> = HashMap::new();

        for line in output.lines() {
            if line.trim_start().starts_with('#') || line.trim().is_empty() {
                continue;
            }
            let fields: Vec<&str> = line.split_whitespace().collect();
            if fields.len() < 5 {
                continue;
            }
            let Ok(pid) = fields[1].parse::<u32>() else {
                continue;
            };
            let Ok(framebuffer_mib) = fields[3].parse::<f64>() else {
                continue;
            };
            let reported_name = fields
                .get(5..)
                .map(|parts| parts.join(" "))
                .unwrap_or_default();
            let name = process_name(pid, &reported_name);
            *totals.entry(name).or_default() += framebuffer_mib;
        }

        let mut result: Vec<_> = totals
            .into_iter()
            .map(|(name, value)| RankedProcess { name, value })
            .collect();
        result.sort_by(|left, right| right.value.total_cmp(&left.value));
        result.truncate(5);
        result
    }
}

fn find_device() -> Option<PathBuf> {
    for entry in fs::read_dir("/sys/bus/pci/devices").ok()?.flatten() {
        if read_text(entry.path().join("vendor")) == "0x10de" {
            return Some(entry.path());
        }
    }
    None
}

fn process_name(pid: u32, reported_name: &str) -> String {
    if let Ok(environment) = fs::read(format!("/proc/{pid}/environ")) {
        for entry in environment.split(|byte| *byte == 0) {
            let Some(desktop) = entry.strip_prefix(b"CHROME_DESKTOP=") else {
                continue;
            };
            let mut desktop = String::from_utf8_lossy(desktop).into_owned();
            if let Some(value) = desktop.strip_suffix(".desktop") {
                desktop = value.to_string();
            }
            if let Some(value) = desktop.strip_suffix("-url-handler") {
                desktop = value.to_string();
            }
            if !desktop.is_empty() {
                return desktop;
            }
        }
    }

    if let Ok(command_line) = fs::read(format!("/proc/{pid}/cmdline")) {
        let executable = command_line
            .split(|byte| *byte == 0)
            .next()
            .unwrap_or_default();
        let base = Path::new(OsStr::from_bytes(executable))
            .file_name()
            .and_then(OsStr::to_str)
            .unwrap_or_default();
        if !base.is_empty() && base != "exe" {
            return base.to_string();
        }
    }

    let reported_executable = reported_name.split_whitespace().next().unwrap_or_default();
    let reported_base = Path::new(reported_executable)
        .file_name()
        .and_then(OsStr::to_str)
        .unwrap_or_default();
    if !reported_base.is_empty() && reported_base != "exe" {
        return reported_base.to_string();
    }

    let comm = read_text(format!("/proc/{pid}/comm"));
    if comm.is_empty() {
        pid.to_string()
    } else {
        comm
    }
}

fn run_nvidia_smi<const N: usize>(arguments: [&str; N]) -> String {
    let Ok(mut child) = Command::new("nvidia-smi")
        .args(arguments)
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
    else {
        return String::new();
    };

    let deadline = Instant::now() + Duration::from_millis(1500);
    loop {
        match child.try_wait() {
            Ok(Some(status)) => {
                if !status.success() {
                    return String::new();
                }
                let mut output = String::new();
                if let Some(mut stdout) = child.stdout.take() {
                    let _ = stdout.read_to_string(&mut output);
                }
                return output.trim().to_string();
            }
            Ok(None) if Instant::now() < deadline => {
                thread::sleep(Duration::from_millis(10));
            }
            _ => {
                let _ = child.kill();
                let _ = child.wait();
                return String::new();
            }
        }
    }
}

#[cfg(unix)]
use std::os::unix::ffi::OsStrExt;
