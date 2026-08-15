use crate::model::{ProcessSample, ProcessSnapshot, RankedProcess};
use std::collections::HashMap;
use std::ffi::OsStr;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

pub struct SystemReader {
    clock_ticks: f64,
    cpu_count: f64,
    cpu_model: String,
    page_size_kib: f64,
    self_pid: u32,
    thermal_path: Option<PathBuf>,
}

impl SystemReader {
    pub fn new() -> Self {
        Self {
            clock_ticks: getconf("CLK_TCK").unwrap_or(100) as f64,
            cpu_count: std::thread::available_parallelism()
                .map(|count| count.get())
                .unwrap_or(1) as f64,
            cpu_model: cpu_model(),
            page_size_kib: getconf("PAGESIZE").unwrap_or(4096) as f64 / 1024.0,
            self_pid: std::process::id(),
            thermal_path: find_thermal_path(),
        }
    }

    pub fn cpu_model(&self) -> &str {
        &self.cpu_model
    }

    pub fn cpu_stat(&self) -> (u64, u64) {
        let content = read_text("/proc/stat");
        let values: Vec<u64> = content
            .lines()
            .next()
            .unwrap_or_default()
            .split_whitespace()
            .skip(1)
            .take(8)
            .filter_map(|value| value.parse().ok())
            .collect();
        if values.len() < 5 {
            return (0, 0);
        }

        let total = values.iter().sum();
        let idle = values[3].saturating_add(values[4]);
        (total, idle)
    }

    pub fn cpu_temperature(&self) -> Option<i64> {
        read_text(self.thermal_path.as_ref()?)
            .parse::<f64>()
            .ok()
            .map(|value| (value / 1000.0).round() as i64)
    }

    pub fn memory(&self) -> (f64, f64, f64) {
        let mut total_kib = 0_u64;
        let mut available_kib = 0_u64;
        for line in read_text("/proc/meminfo").lines() {
            let Some((name, value)) = line.split_once(':') else {
                continue;
            };
            let parsed = value
                .split_whitespace()
                .next()
                .and_then(|value| value.parse::<u64>().ok())
                .unwrap_or(0);
            match name {
                "MemTotal" => total_kib = parsed,
                "MemAvailable" => available_kib = parsed,
                _ => {}
            }
        }

        let used_kib = total_kib.saturating_sub(available_kib);
        let usage = if total_kib > 0 {
            used_kib as f64 * 100.0 / total_kib as f64
        } else {
            0.0
        };
        (
            usage,
            used_kib as f64 / 1024.0 / 1024.0,
            total_kib as f64 / 1024.0 / 1024.0,
        )
    }

    pub fn uptime_seconds(&self) -> u64 {
        read_text("/proc/uptime")
            .split_whitespace()
            .next()
            .and_then(|value| value.split('.').next())
            .and_then(|value| value.parse().ok())
            .unwrap_or(0)
    }

    pub fn default_interface(&self) -> String {
        for line in read_text("/proc/net/route").lines().skip(1) {
            let fields: Vec<&str> = line.split_whitespace().collect();
            if fields.len() <= 3 || fields[1] != "00000000" {
                continue;
            }
            let flags = u32::from_str_radix(fields[3], 16).unwrap_or(0);
            if flags & 2 != 0 {
                return fields[0].to_string();
            }
        }

        let mut candidates: Vec<_> = fs::read_dir("/sys/class/net")
            .into_iter()
            .flatten()
            .flatten()
            .collect();
        candidates.sort_by_key(|entry| entry.file_name());
        for entry in candidates {
            let name = entry.file_name().to_string_lossy().into_owned();
            if name != "lo" && read_text(entry.path().join("operstate")) == "up" {
                return name;
            }
        }
        String::new()
    }

    pub fn network_counters(&self, interface: &str) -> (u64, u64) {
        if interface.is_empty() {
            return (0, 0);
        }
        let base = Path::new("/sys/class/net")
            .join(interface)
            .join("statistics");
        (
            read_text(base.join("rx_bytes")).parse().unwrap_or(0),
            read_text(base.join("tx_bytes")).parse().unwrap_or(0),
        )
    }

    pub fn process_snapshot(&self, include_cpu: bool, include_ram: bool) -> ProcessSnapshot {
        let mut snapshot = HashMap::new();
        let Ok(entries) = fs::read_dir("/proc") else {
            return snapshot;
        };

        for entry in entries.flatten() {
            let Ok(pid) = entry.file_name().to_string_lossy().parse::<u32>() else {
                continue;
            };
            if pid <= 1 || pid == self.self_pid {
                continue;
            }

            let stat = read_text(entry.path().join("stat"));
            let Some(open_paren) = stat.find('(') else {
                continue;
            };
            let Some(close_paren) = stat.rfind(')') else {
                continue;
            };
            let fields: Vec<&str> = stat[close_paren + 1..].split_whitespace().collect();
            if fields.len() <= 12 {
                continue;
            }
            let reported_name = stat[open_paren + 1..close_paren].to_string();
            let parent_pid = fields[1].parse::<u32>().unwrap_or(0);
            let cpu_ticks = if include_cpu {
                let user_ticks = fields[11].parse::<u64>().unwrap_or(0);
                let system_ticks = fields[12].parse::<u64>().unwrap_or(0);
                user_ticks.saturating_add(system_ticks)
            } else {
                0
            };
            let name = if reported_name.to_ascii_lowercase().starts_with("electron") {
                process_name(pid, &reported_name)
            } else {
                reported_name
            };

            let rss_mib = if include_ram {
                read_text(entry.path().join("statm"))
                    .split_whitespace()
                    .nth(1)
                    .and_then(|value| value.parse::<u64>().ok())
                    .map(|pages| pages as f64 * self.page_size_kib / 1024.0)
                    .unwrap_or(0.0)
            } else {
                0.0
            };

            snapshot.insert(
                pid,
                ProcessSample {
                    name,
                    parent_pid,
                    cpu_ticks,
                    rss_mib,
                },
            );
        }
        snapshot
    }

    pub fn top_processes(
        &self,
        previous: &ProcessSnapshot,
        current: &ProcessSnapshot,
        elapsed_seconds: f64,
    ) -> (Vec<RankedProcess>, Vec<RankedProcess>) {
        let mut cpu_processes: HashMap<(u32, String), f64> = HashMap::new();
        let mut ram_processes: HashMap<(u32, String), f64> = HashMap::new();
        let denominator = (elapsed_seconds * self.clock_ticks * self.cpu_count).max(1.0);

        for (pid, sample) in current {
            let group_pid = process_group_pid(current, *pid);
            let group = (group_pid, sample.name.clone());
            *ram_processes.entry(group.clone()).or_default() += sample.rss_mib;
            let Some(old) = previous.get(pid) else {
                continue;
            };
            let delta = sample.cpu_ticks.saturating_sub(old.cpu_ticks);
            *cpu_processes.entry(group).or_default() += delta as f64 * 100.0 / denominator;
        }

        (ranked_groups(cpu_processes), ranked_groups(ram_processes))
    }
}

fn cpu_model() -> String {
    for line in read_text("/proc/cpuinfo").lines() {
        let Some((name, value)) = line.split_once(':') else {
            continue;
        };
        if name.trim() == "model name" {
            return value
                .trim()
                .replace("(R)", "")
                .replace("(TM)", "")
                .split_whitespace()
                .collect::<Vec<_>>()
                .join(" ");
        }
    }
    String::new()
}

fn find_thermal_path() -> Option<PathBuf> {
    const PREFERRED: [&str; 3] = ["x86_pkg_temp", "TCPU", "cpu-thermal"];
    let mut fallback = None;
    for entry in fs::read_dir("/sys/class/thermal").ok()?.flatten() {
        if !entry
            .file_name()
            .to_string_lossy()
            .starts_with("thermal_zone")
        {
            continue;
        }
        let temperature_path = entry.path().join("temp");
        if !temperature_path.is_file() {
            continue;
        }
        fallback.get_or_insert_with(|| temperature_path.clone());
        if PREFERRED.contains(&read_text(entry.path().join("type")).as_str()) {
            return Some(temperature_path);
        }
    }
    fallback
}

fn process_group_pid(snapshot: &ProcessSnapshot, pid: u32) -> u32 {
    let Some(sample) = snapshot.get(&pid) else {
        return pid;
    };
    let name = &sample.name;
    let mut leader = pid;

    for _ in 0..64 {
        let Some(current) = snapshot.get(&leader) else {
            break;
        };
        if current.parent_pid <= 1 || current.parent_pid == leader {
            break;
        }
        let Some(parent) = snapshot.get(&current.parent_pid) else {
            break;
        };
        if parent.name != *name {
            break;
        }
        leader = current.parent_pid;
    }

    leader
}

fn ranked_groups(values: HashMap<(u32, String), f64>) -> Vec<RankedProcess> {
    let mut result = values
        .into_iter()
        .map(|((pid, name), value)| RankedProcess { pid, name, value })
        .collect::<Vec<_>>();
    result.sort_by(|left, right| right.value.total_cmp(&left.value));
    result
}

pub fn read_text(path: impl AsRef<Path>) -> String {
    fs::read_to_string(path)
        .map(|content| content.trim().to_string())
        .unwrap_or_default()
}

pub fn process_name(pid: u32, reported_name: &str) -> String {
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
        if let Some(app_name) = electron_app_name(&command_line) {
            return app_name;
        }

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

fn electron_app_name(command_line: &[u8]) -> Option<String> {
    for argument in command_line.split(|byte| *byte == 0).skip(1) {
        let path = Path::new(OsStr::from_bytes(argument));
        if path.file_name().and_then(OsStr::to_str) != Some("app.asar") {
            continue;
        }
        let app_name = path.parent()?.file_name()?.to_str()?;
        if !app_name.is_empty() {
            return Some(app_name.to_string());
        }
    }
    None
}

fn getconf(name: &str) -> Option<u64> {
    let output = Command::new("getconf").arg(name).output().ok()?;
    if !output.status.success() {
        return None;
    }
    String::from_utf8_lossy(&output.stdout).trim().parse().ok()
}

#[cfg(test)]
mod process_name_tests {
    use super::{SystemReader, electron_app_name, process_group_pid};
    use crate::model::{ProcessSample, ProcessSnapshot};

    #[test]
    fn resolves_electron_app_asar_parent() {
        let command_line = b"/usr/lib/electron40/electron\0/usr/lib/vesktop/app.asar\0";
        assert_eq!(electron_app_name(command_line).as_deref(), Some("vesktop"));
    }

    #[test]
    fn groups_same_application_children_under_parent() {
        let mut snapshot = ProcessSnapshot::new();
        snapshot.insert(
            100,
            ProcessSample {
                name: "vesktop".to_string(),
                parent_pid: 10,
                cpu_ticks: 0,
                rss_mib: 200.0,
            },
        );
        snapshot.insert(
            110,
            ProcessSample {
                name: "vesktop".to_string(),
                parent_pid: 100,
                cpu_ticks: 0,
                rss_mib: 100.0,
            },
        );
        snapshot.insert(
            120,
            ProcessSample {
                name: "vesktop".to_string(),
                parent_pid: 110,
                cpu_ticks: 0,
                rss_mib: 50.0,
            },
        );

        assert_eq!(process_group_pid(&snapshot, 120), 100);

        let (_, ram) = SystemReader::new().top_processes(&ProcessSnapshot::new(), &snapshot, 1.0);
        assert_eq!(ram.len(), 1);
        assert_eq!(ram[0].pid, 100);
        assert_eq!(ram[0].value, 350.0);
    }
}

#[cfg(unix)]
use std::os::unix::ffi::OsStrExt;
