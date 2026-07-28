use crate::model::{ProcessSample, ProcessSnapshot, RankedProcess};
use std::collections::HashMap;
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
            if pid == self.self_pid {
                continue;
            }

            let (name, cpu_ticks) = if include_cpu {
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
                let user_ticks = fields[11].parse::<u64>().unwrap_or(0);
                let system_ticks = fields[12].parse::<u64>().unwrap_or(0);
                (
                    stat[open_paren + 1..close_paren].to_string(),
                    user_ticks.saturating_add(system_ticks),
                )
            } else {
                let name = read_text(entry.path().join("comm"));
                if name.is_empty() {
                    continue;
                }
                (name, 0)
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
        let mut cpu_by_name: HashMap<&str, f64> = HashMap::new();
        let mut ram_by_name: HashMap<&str, f64> = HashMap::new();
        let denominator = (elapsed_seconds * self.clock_ticks * self.cpu_count).max(1.0);

        for (pid, sample) in current {
            *ram_by_name.entry(&sample.name).or_default() += sample.rss_mib;
            let Some(old) = previous.get(pid) else {
                continue;
            };
            let delta = sample.cpu_ticks.saturating_sub(old.cpu_ticks);
            *cpu_by_name.entry(&sample.name).or_default() += delta as f64 * 100.0 / denominator;
        }

        (ranked(cpu_by_name), ranked(ram_by_name))
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

fn ranked(values: HashMap<&str, f64>) -> Vec<RankedProcess> {
    let mut result: Vec<_> = values
        .into_iter()
        .filter(|(_, value)| *value > 0.0)
        .map(|(name, value)| RankedProcess {
            name: name.to_string(),
            value,
        })
        .collect();
    result.sort_by(|left, right| right.value.total_cmp(&left.value));
    result.truncate(5);
    result
}

pub fn read_text(path: impl AsRef<Path>) -> String {
    fs::read_to_string(path)
        .map(|content| content.trim().to_string())
        .unwrap_or_default()
}

fn getconf(name: &str) -> Option<u64> {
    let output = Command::new("getconf").arg(name).output().ok()?;
    if !output.status.success() {
        return None;
    }
    String::from_utf8_lossy(&output.stdout).trim().parse().ok()
}
