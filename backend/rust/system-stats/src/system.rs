//! Linux process, CPU, memory, network, and thermal readers.

use crate::model::{ProcessMemoryDetails, ProcessSample, ProcessSnapshot, RankedProcess};
use std::collections::{HashMap, HashSet};
use std::ffi::OsStr;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::thread;
use std::time::{Duration, Instant};

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
            let name = process_name(pid, &reported_name);

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

    pub fn process_memory_details(&self, root_pid: u32) -> io::Result<ProcessMemoryDetails> {
        if root_pid <= 1 {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "process id must be greater than one",
            ));
        }

        let snapshot = self.process_snapshot(false, true);
        let Some(target) = snapshot.get(&root_pid) else {
            return Err(io::Error::new(
                io::ErrorKind::NotFound,
                "process no longer exists",
            ));
        };
        let target_name = target.name.clone();
        let mut process_count = 0_u32;
        let mut measured_process_count = 0_u32;
        let mut rss_mib = 0.0;
        let mut pss_kib = 0_u64;
        let mut pss_dirty_kib = 0_u64;
        let mut private_kib = 0_u64;

        for (pid, sample) in &snapshot {
            if sample.name != target_name || process_group_pid(&snapshot, *pid) != root_pid {
                continue;
            }
            process_count += 1;
            rss_mib += sample.rss_mib;
            let Some(memory) = read_smaps_rollup(*pid) else {
                continue;
            };
            measured_process_count += 1;
            pss_kib = pss_kib.saturating_add(memory.pss_kib);
            pss_dirty_kib = pss_dirty_kib.saturating_add(memory.pss_dirty_kib);
            private_kib = private_kib.saturating_add(memory.private_kib);
        }

        let has_detailed_sample = measured_process_count > 0;
        Ok(ProcessMemoryDetails {
            pid: root_pid,
            process_count,
            measured_process_count,
            rss_mib,
            pss_mib: has_detailed_sample.then_some(pss_kib as f64 / 1024.0),
            pss_dirty_mib: has_detailed_sample.then_some(pss_dirty_kib as f64 / 1024.0),
            private_mib: has_detailed_sample.then_some(private_kib as f64 / 1024.0),
        })
    }
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
struct SmapsMemory {
    pss_kib: u64,
    pss_dirty_kib: u64,
    private_kib: u64,
}

fn read_smaps_rollup(pid: u32) -> Option<SmapsMemory> {
    let content = fs::read_to_string(format!("/proc/{pid}/smaps_rollup")).ok()?;
    parse_smaps_rollup(&content)
}

fn parse_smaps_rollup(content: &str) -> Option<SmapsMemory> {
    let mut pss_kib = None;
    let mut pss_dirty_kib = None;
    let mut private_clean_kib = None;
    let mut private_dirty_kib = None;

    for line in content.lines() {
        let Some((name, value)) = line.split_once(':') else {
            continue;
        };
        let value = value
            .split_whitespace()
            .next()
            .and_then(|value| value.parse::<u64>().ok());
        match name {
            "Pss" => pss_kib = value,
            "Pss_Dirty" => pss_dirty_kib = value,
            "Private_Clean" => private_clean_kib = value,
            "Private_Dirty" => private_dirty_kib = value,
            _ => {}
        }
    }

    Some(SmapsMemory {
        pss_kib: pss_kib?,
        pss_dirty_kib: pss_dirty_kib?,
        private_kib: private_clean_kib?.saturating_add(private_dirty_kib?),
    })
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
    let electron_process = reported_name.to_ascii_lowercase().starts_with("electron");
    if electron_process {
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
    }

    if electron_process {
        if let Ok(command_line) = fs::read(format!("/proc/{pid}/cmdline")) {
            if let Some(app_name) = electron_app_name(&command_line) {
                return app_name;
            }
        }
    }

    if let Ok(executable) = fs::read_link(format!("/proc/{pid}/exe")) {
        let executable = executable.to_string_lossy().into_owned();
        if !executable.is_empty() {
            return executable;
        }
    }

    if let Ok(command_line) = fs::read(format!("/proc/{pid}/cmdline")) {
        let executable = command_line
            .split(|byte| *byte == 0)
            .next()
            .unwrap_or_default();
        let executable = String::from_utf8_lossy(executable).into_owned();
        let executable = executable.split_whitespace().next().unwrap_or_default();
        if !executable.is_empty() && executable != "exe" {
            return executable.to_string();
        }
    }

    if !reported_name.is_empty() {
        return reported_name.to_string();
    }

    let comm = read_text(format!("/proc/{pid}/comm"));
    if comm.is_empty() {
        pid.to_string()
    } else {
        comm
    }
}

pub fn terminate_process_tree(root_pid: u32) -> io::Result<()> {
    if root_pid <= 1 {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "process id must be greater than one",
        ));
    }
    let Some((_, root_start_time)) = process_state_and_start_time(root_pid) else {
        return Ok(());
    };

    let initial_tree = collect_process_tree(root_pid);
    let initial_helpers = linked_crashpad_handlers(&initial_tree);
    let mut initial_order = initial_tree.clone();
    initial_order.extend(initial_helpers.iter().copied());
    let mut tracked = HashMap::new();
    track_processes(&initial_order, &mut tracked);
    tracked.entry(root_pid).or_insert(root_start_time);

    // Signal the parent first so Electron/Chromium applications cannot replace
    // terminated helpers while their main process is still fully running.
    let mut terminate_order = initial_tree;
    terminate_order.reverse();
    terminate_order.extend(initial_helpers);
    signal_tracked_processes("TERM", &terminate_order, &tracked)?;

    let deadline = Instant::now() + Duration::from_millis(900);
    while Instant::now() < deadline {
        if !has_live_tracked_processes(&tracked) {
            return Ok(());
        }

        if process_matches(root_pid, root_start_time) {
            let current_tree = collect_process_tree(root_pid);
            let current_helpers = linked_crashpad_handlers(&current_tree);
            let mut current_order = current_tree;
            current_order.extend(current_helpers);
            let new_processes = current_order
                .iter()
                .filter(|pid| !tracked.contains_key(pid))
                .copied()
                .collect::<Vec<_>>();
            track_processes(&new_processes, &mut tracked);
            let mut new_terminate_order = new_processes;
            new_terminate_order.reverse();
            signal_tracked_processes("TERM", &new_terminate_order, &tracked)?;
        }
        thread::sleep(Duration::from_millis(50));
    }

    if process_matches(root_pid, root_start_time) {
        let current_tree = collect_process_tree(root_pid);
        track_processes(&current_tree, &mut tracked);
        track_processes(&linked_crashpad_handlers(&current_tree), &mut tracked);
    }
    let mut force_order = tracked.keys().copied().collect::<Vec<_>>();
    force_order.sort_unstable_by_key(|pid| *pid == root_pid);
    signal_tracked_processes("KILL", &force_order, &tracked)?;

    let force_deadline = Instant::now() + Duration::from_millis(350);
    while Instant::now() < force_deadline {
        if !has_live_tracked_processes(&tracked) {
            return Ok(());
        }
        thread::sleep(Duration::from_millis(25));
    }

    let remaining = tracked
        .iter()
        .filter(|(pid, start_time)| process_matches(**pid, **start_time))
        .count();
    if remaining == 0 {
        Ok(())
    } else {
        Err(io::Error::other(format!(
            "failed to terminate {remaining} process(es)"
        )))
    }
}

fn collect_process_tree(root_pid: u32) -> Vec<u32> {
    if !Path::new(&format!("/proc/{root_pid}")).exists() {
        return Vec::new();
    }

    let mut children_by_parent: HashMap<u32, Vec<u32>> = HashMap::new();
    if let Ok(entries) = fs::read_dir("/proc") {
        for entry in entries.flatten() {
            let Ok(pid) = entry.file_name().to_string_lossy().parse::<u32>() else {
                continue;
            };
            let stat = read_text(entry.path().join("stat"));
            let Some(close_paren) = stat.rfind(')') else {
                continue;
            };
            let parent_pid = stat[close_paren + 1..]
                .split_whitespace()
                .nth(1)
                .and_then(|value| value.parse::<u32>().ok())
                .unwrap_or(0);
            children_by_parent.entry(parent_pid).or_default().push(pid);
        }
    }

    process_tree_order(root_pid, &children_by_parent)
}

fn linked_crashpad_handlers(process_ids: &[u32]) -> Vec<u32> {
    let mut result = Vec::new();
    let mut seen = HashSet::new();
    for pid in process_ids {
        let Ok(command_line) = fs::read(format!("/proc/{pid}/cmdline")) else {
            continue;
        };
        for helper_pid in crashpad_handler_pids(&command_line) {
            if seen.insert(helper_pid) && is_crashpad_handler(helper_pid) {
                result.push(helper_pid);
            }
        }
    }
    result
}

fn crashpad_handler_pids(command_line: &[u8]) -> Vec<u32> {
    const PREFIX: &[u8] = b"--crashpad-handler-pid=";
    command_line
        .split(|byte| *byte == 0)
        .filter_map(|argument| argument.strip_prefix(PREFIX))
        .filter_map(|value| std::str::from_utf8(value).ok()?.parse::<u32>().ok())
        .filter(|pid| *pid > 1)
        .collect()
}

fn is_crashpad_handler(pid: u32) -> bool {
    if let Ok(executable) = fs::read_link(format!("/proc/{pid}/exe"))
        && executable
            .file_name()
            .and_then(OsStr::to_str)
            .is_some_and(|name| name.contains("crashpad_handler"))
    {
        return true;
    }
    fs::read(format!("/proc/{pid}/cmdline"))
        .ok()
        .is_some_and(|command_line| {
            command_line
                .split(|byte| *byte == 0)
                .next()
                .is_some_and(|argument| {
                    String::from_utf8_lossy(argument).contains("crashpad_handler")
                })
        })
}

fn process_state_and_start_time(pid: u32) -> Option<(char, u64)> {
    let stat = fs::read_to_string(format!("/proc/{pid}/stat")).ok()?;
    let close_paren = stat.rfind(')')?;
    let fields = stat[close_paren + 1..]
        .split_whitespace()
        .collect::<Vec<_>>();
    let state = fields.first()?.chars().next()?;
    let start_time = fields.get(19)?.parse::<u64>().ok()?;
    Some((state, start_time))
}

fn process_matches(pid: u32, start_time: u64) -> bool {
    matches!(
        process_state_and_start_time(pid),
        Some((state, current_start_time))
            if !matches!(state, 'Z' | 'X' | 'x') && current_start_time == start_time
    )
}

fn track_processes(process_ids: &[u32], tracked: &mut HashMap<u32, u64>) {
    for pid in process_ids {
        if tracked.contains_key(pid) {
            continue;
        }
        if let Some((state, start_time)) = process_state_and_start_time(*pid)
            && !matches!(state, 'Z' | 'X' | 'x')
        {
            tracked.insert(*pid, start_time);
        }
    }
}

fn signal_tracked_processes(
    signal: &str,
    process_ids: &[u32],
    tracked: &HashMap<u32, u64>,
) -> io::Result<()> {
    let process_ids = process_ids
        .iter()
        .filter(|pid| {
            tracked
                .get(pid)
                .is_some_and(|start_time| process_matches(**pid, *start_time))
        })
        .map(u32::to_string)
        .collect::<Vec<_>>();
    if process_ids.is_empty() {
        return Ok(());
    }

    // A process may exit between the identity check and kill(1). Ignore that
    // expected race; the final live-process verification reports real errors.
    let _ = Command::new("kill")
        .arg(format!("-{signal}"))
        .arg("--")
        .args(&process_ids)
        .output()?;
    Ok(())
}

fn has_live_tracked_processes(tracked: &HashMap<u32, u64>) -> bool {
    tracked
        .iter()
        .any(|(pid, start_time)| process_matches(*pid, *start_time))
}

fn process_tree_order(root_pid: u32, children_by_parent: &HashMap<u32, Vec<u32>>) -> Vec<u32> {
    let mut order = Vec::new();
    let mut seen = HashSet::new();
    let mut stack = vec![(root_pid, false)];

    while let Some((pid, visited)) = stack.pop() {
        if visited {
            order.push(pid);
            continue;
        }
        if !seen.insert(pid) {
            continue;
        }
        stack.push((pid, true));
        if let Some(children) = children_by_parent.get(&pid) {
            for child in children {
                stack.push((*child, false));
            }
        }
    }

    order
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
    use super::{
        SmapsMemory, SystemReader, crashpad_handler_pids, electron_app_name, parse_smaps_rollup,
        process_group_pid, process_tree_order,
    };
    use crate::model::{ProcessSample, ProcessSnapshot};
    use std::collections::HashMap;

    #[test]
    fn resolves_electron_app_asar_parent() {
        let command_line = b"/usr/lib/electron40/electron\0/usr/lib/vesktop/app.asar\0";
        assert_eq!(electron_app_name(command_line).as_deref(), Some("vesktop"));
    }

    #[test]
    fn resolves_linked_crashpad_handler_pid() {
        let command_line = b"/usr/share/code/code\0--type=renderer\0--crashpad-handler-pid=456\0";
        assert_eq!(crashpad_handler_pids(command_line), vec![456]);
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

    #[test]
    fn orders_descendants_before_the_parent_for_termination() {
        let children = HashMap::from([(100, vec![110, 120]), (110, vec![111])]);
        let order = process_tree_order(100, &children);

        assert!(
            order.iter().position(|pid| *pid == 111) < order.iter().position(|pid| *pid == 110)
        );
        assert!(
            order.iter().position(|pid| *pid == 110) < order.iter().position(|pid| *pid == 100)
        );
        assert!(
            order.iter().position(|pid| *pid == 120) < order.iter().position(|pid| *pid == 100)
        );
    }

    #[test]
    fn parses_process_memory_rollup() {
        let rollup = "Rss:                900 kB\nPss:                600 kB\nPss_Dirty:          450 kB\nPrivate_Clean:       25 kB\nPrivate_Dirty:      400 kB\n";

        assert_eq!(
            parse_smaps_rollup(rollup),
            Some(SmapsMemory {
                pss_kib: 600,
                pss_dirty_kib: 450,
                private_kib: 425,
            })
        );
    }
}

#[cfg(unix)]
use std::os::unix::ffi::OsStrExt;
