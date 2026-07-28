use std::collections::HashMap;

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub enum ProcessMode {
    Cpu,
    Gpu,
    Ram,
    #[default]
    None,
}

impl ProcessMode {
    pub fn parse(value: &str) -> Option<Self> {
        match value.trim().to_ascii_lowercase().as_str() {
            "cpu" => Some(Self::Cpu),
            "gpu" => Some(Self::Gpu),
            "ram" => Some(Self::Ram),
            "none" => Some(Self::None),
            _ => None,
        }
    }
}

#[cfg(test)]
mod process_mode_tests {
    use super::ProcessMode;

    #[test]
    fn parses_supported_modes_case_insensitively() {
        assert_eq!(ProcessMode::parse(" CPU\n"), Some(ProcessMode::Cpu));
        assert_eq!(ProcessMode::parse("ram"), Some(ProcessMode::Ram));
        assert_eq!(ProcessMode::parse("Gpu"), Some(ProcessMode::Gpu));
        assert_eq!(ProcessMode::parse("none"), Some(ProcessMode::None));
    }

    #[test]
    fn rejects_unknown_modes() {
        assert_eq!(ProcessMode::parse("processes"), None);
    }
}

#[derive(Clone, Debug)]
pub struct ProcessSample {
    pub name: String,
    pub cpu_ticks: u64,
    pub rss_mib: f64,
}

pub type ProcessSnapshot = HashMap<u32, ProcessSample>;

#[derive(Clone, Debug)]
pub struct RankedProcess {
    pub name: String,
    pub value: f64,
}

#[derive(Clone, Copy, Debug, Default)]
pub struct GpuStats {
    pub usage: f64,
    pub temperature: i64,
    pub memory_used: f64,
    pub memory_total: f64,
}

#[derive(Debug)]
pub struct StatsPayload {
    pub cpu_model: Option<String>,
    pub cpu_total: u64,
    pub cpu_idle: u64,
    pub cpu_temperature: Option<i64>,
    pub ram_usage: f64,
    pub ram_used_gib: f64,
    pub ram_total_gib: f64,
    pub gpu: GpuStats,
    pub gpu_model: Option<String>,
    pub network_interface: String,
    pub rx_rate: f64,
    pub tx_rate: f64,
    pub top_cpu: Option<Vec<RankedProcess>>,
    pub top_ram: Option<Vec<RankedProcess>>,
    pub top_gpu: Option<Vec<RankedProcess>>,
    pub uptime_seconds: Option<u64>,
}
