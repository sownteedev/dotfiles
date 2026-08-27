mod battery;
mod json;
mod model;
mod nvidia;
mod system;

use model::{GpuStats, ProcessMode, ProcessSnapshot, StatsPayload};
use nvidia::NvidiaReader;
use std::io::{self, BufRead, BufWriter, Write};
use std::sync::mpsc::{self, Receiver};
use std::thread;
use std::time::{Duration, Instant};
use system::SystemReader;

const SAMPLE_INTERVAL: Duration = Duration::from_secs(1);
const PROCESS_SAMPLE_INTERVAL: Duration = Duration::from_secs(2);
const GPU_SAMPLE_EVERY: u64 = 3;

struct Sampler {
    cpu_model: String,
    gpu_model: String,
    system: SystemReader,
    nvidia: NvidiaReader,
    mode: ProcessMode,
    previous_time: Option<Instant>,
    previous_interface: String,
    previous_rx: u64,
    previous_tx: u64,
    previous_processes: ProcessSnapshot,
    previous_process_time: Option<Instant>,
    next_process_sample: Instant,
    next_gpu_process_sample: Instant,
    gpu: GpuStats,
    tick: u64,
}

impl Sampler {
    fn new() -> Self {
        let now = Instant::now();
        let system = SystemReader::new();
        let nvidia = NvidiaReader::new();
        let cpu_model = system.cpu_model().to_string();
        let gpu_model = nvidia.model_name();
        Self {
            cpu_model,
            gpu_model,
            system,
            nvidia,
            mode: ProcessMode::None,
            previous_time: None,
            previous_interface: String::new(),
            previous_rx: 0,
            previous_tx: 0,
            previous_processes: ProcessSnapshot::new(),
            previous_process_time: None,
            next_process_sample: now,
            next_gpu_process_sample: now,
            gpu: GpuStats::default(),
            tick: 0,
        }
    }

    fn set_mode(&mut self, mode: ProcessMode) {
        if self.mode == mode {
            return;
        }
        self.mode = mode;
        self.previous_processes.clear();
        self.previous_process_time = None;
        self.next_process_sample = Instant::now();
        self.next_gpu_process_sample = Instant::now();
    }

    fn sample(&mut self, now: Instant) -> StatsPayload {
        let elapsed = self
            .previous_time
            .map(|previous| now.duration_since(previous).as_secs_f64())
            .unwrap_or(0.0);
        let (cpu_total, cpu_idle) = self.system.cpu_stat();
        let cpu_temperature = self.system.cpu_temperature();
        let (ram_usage, ram_used_gib, ram_total_gib) = self.system.memory();

        let network_interface = self.system.default_interface();
        let (rx, tx) = self.system.network_counters(&network_interface);
        let same_counter = self.previous_time.is_some()
            && network_interface == self.previous_interface
            && elapsed > 0.0;
        let rx_rate = if same_counter {
            rx.saturating_sub(self.previous_rx) as f64 / elapsed
        } else {
            0.0
        };
        let tx_rate = if same_counter {
            tx.saturating_sub(self.previous_tx) as f64 / elapsed
        } else {
            0.0
        };

        let mut top_cpu = None;
        let mut top_ram = None;
        if matches!(self.mode, ProcessMode::Cpu | ProcessMode::Ram)
            && now >= self.next_process_sample
        {
            let current = self
                .system
                .process_snapshot(self.mode == ProcessMode::Cpu, self.mode == ProcessMode::Ram);
            let process_elapsed = self
                .previous_process_time
                .map(|previous| now.duration_since(previous).as_secs_f64())
                .unwrap_or(0.0);
            let has_baseline = self.previous_process_time.is_some();
            let (cpu, ram) =
                self.system
                    .top_processes(&self.previous_processes, &current, process_elapsed);
            if self.mode == ProcessMode::Cpu && has_baseline {
                top_cpu = Some(cpu);
            } else if self.mode == ProcessMode::Ram {
                top_ram = Some(ram);
            }
            self.previous_processes = current;
            self.previous_process_time = Some(now);
            self.next_process_sample = now
                + if has_baseline {
                    PROCESS_SAMPLE_INTERVAL
                } else {
                    SAMPLE_INTERVAL
                };
        } else if !matches!(self.mode, ProcessMode::Cpu | ProcessMode::Ram) {
            self.previous_processes.clear();
            self.previous_process_time = None;
        }

        if self.tick.is_multiple_of(GPU_SAMPLE_EVERY) {
            self.gpu = self.nvidia.stats();
        }
        let top_gpu = if self.mode == ProcessMode::Gpu && now >= self.next_gpu_process_sample {
            self.next_gpu_process_sample = now + Duration::from_secs(GPU_SAMPLE_EVERY);
            Some(self.nvidia.top_processes())
        } else {
            None
        };

        self.previous_time = Some(now);
        self.previous_interface.clone_from(&network_interface);
        self.previous_rx = rx;
        self.previous_tx = tx;
        self.tick += 1;

        StatsPayload {
            cpu_model: Some(self.cpu_model.clone()),
            cpu_total,
            cpu_idle,
            cpu_temperature,
            ram_usage,
            ram_used_gib,
            ram_total_gib,
            gpu: self.gpu,
            gpu_model: Some(self.gpu_model.clone()),
            network_interface,
            rx_rate,
            tx_rate,
            top_cpu,
            top_ram,
            top_gpu,
            uptime_seconds: (self.tick == 1 || self.tick.is_multiple_of(60))
                .then(|| self.system.uptime_seconds()),
        }
    }
}

fn stdin_modes() -> Receiver<ProcessMode> {
    let (sender, receiver) = mpsc::channel();
    thread::spawn(move || {
        let stdin = io::stdin();
        for line in stdin.lock().lines().map_while(Result::ok) {
            if let Some(mode) = ProcessMode::parse(&line)
                && sender.send(mode).is_err()
            {
                break;
            }
        }
    });
    receiver
}

fn main() -> io::Result<()> {
    let mut arguments = std::env::args().skip(1);
    match arguments.next().as_deref() {
        Some("--battery") => {
            println!("{}", battery::BatteryReader::new().encode());
            return Ok(());
        }
        Some("--battery-control") => {
            println!("{}", battery::encode_control());
            return Ok(());
        }
        Some("--set-charge-mode") => {
            let mode = arguments.next().ok_or_else(|| {
                io::Error::new(io::ErrorKind::InvalidInput, "missing charge mode")
            })?;
            battery::set_charge_mode(&mode)?;
            return Ok(());
        }
        Some("--set-charge-thresholds") => {
            let start = arguments
                .next()
                .ok_or_else(|| {
                    io::Error::new(io::ErrorKind::InvalidInput, "missing start threshold")
                })?
                .parse::<u8>()
                .map_err(|_| {
                    io::Error::new(io::ErrorKind::InvalidInput, "invalid start threshold")
                })?;
            let end = arguments
                .next()
                .ok_or_else(|| {
                    io::Error::new(io::ErrorKind::InvalidInput, "missing end threshold")
                })?
                .parse::<u8>()
                .map_err(|_| {
                    io::Error::new(io::ErrorKind::InvalidInput, "invalid end threshold")
                })?;
            battery::set_charge_thresholds(start, end)?;
            return Ok(());
        }
        Some("--process-memory") => {
            let pid = arguments
                .next()
                .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "missing process id"))?
                .parse::<u32>()
                .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "invalid process id"))?;
            let details = SystemReader::new().process_memory_details(pid)?;
            println!("{}", json::encode_process_memory(&details));
            return Ok(());
        }
        Some("--terminate-tree") => {
            let pid = arguments
                .next()
                .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "missing process id"))?
                .parse::<u32>()
                .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "invalid process id"))?;
            system::terminate_process_tree(pid)?;
            return Ok(());
        }
        Some("--battery-stream") => {
            let reader = battery::BatteryReader::new();
            let stdout = io::stdout();
            let mut output = BufWriter::new(stdout.lock());
            loop {
                writeln!(output, "{}", reader.encode())?;
                output.flush()?;
                thread::sleep(Duration::from_secs(5));
            }
        }
        _ => {}
    }

    let modes = stdin_modes();
    let mut sampler = Sampler::new();
    let stdout = io::stdout();
    let mut output = BufWriter::new(stdout.lock());
    let mut next_tick = Instant::now();

    loop {
        for mode in modes.try_iter() {
            sampler.set_mode(mode);
        }

        let payload = sampler.sample(Instant::now());
        writeln!(output, "{}", json::encode(&payload))?;
        output.flush()?;

        next_tick += SAMPLE_INTERVAL;
        let now = Instant::now();
        if next_tick > now {
            thread::sleep(next_tick - now);
        } else if now.duration_since(next_tick) >= SAMPLE_INTERVAL {
            next_tick = now;
        }
    }
}
