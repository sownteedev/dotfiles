use crate::nvidia::NvidiaReader;
use crate::system::read_text;
use std::fmt::Write;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};

pub struct BatteryReader {
    battery: Option<PathBuf>,
    nvidia: NvidiaReader,
}

impl BatteryReader {
    pub fn new() -> Self {
        Self {
            battery: find_battery(),
            nvidia: NvidiaReader::new(),
        }
    }

    pub fn encode(&self) -> String {
        let value = |name: &str| {
            self.battery
                .as_ref()
                .map(|path| read_number(path.join(name)))
                .unwrap_or(0.0)
        };

        let charge_full = value("charge_full");
        let charge_design = value("charge_full_design");
        let energy_design = value("energy_full_design");
        let voltage_now = value("voltage_now");
        let voltage_design = value("voltage_min_design");
        let current_now = value("current_now");
        let power_now = value("power_now");
        let raw_temperature = value("temp");
        let health = ratio(
            if value("energy_full") > 0.0 {
                value("energy_full")
            } else {
                charge_full
            },
            if energy_design > 0.0 {
                energy_design
            } else {
                charge_design
            },
        );
        let design_energy = if energy_design > 0.0 {
            Some(energy_design / 1_000_000.0)
        } else {
            positive(voltage_design * charge_design / 1_000_000_000_000.0)
        };
        let power_draw = if power_now > 0.0 {
            Some(power_now / 1_000_000.0)
        } else {
            positive(voltage_now * current_now / 1_000_000_000_000.0)
        };
        let device_name = self
            .battery
            .as_ref()
            .map(|path| {
                format!(
                    "{} {}",
                    read_text(path.join("manufacturer")),
                    read_text(path.join("model_name"))
                )
                .split_whitespace()
                .collect::<Vec<_>>()
                .join(" ")
            })
            .filter(|name| !name.is_empty())
            .unwrap_or_else(|| "Battery".to_string());

        let mut output = String::with_capacity(256);
        output.push('{');
        append_number(&mut output, "gpu_power", self.nvidia.power_draw(), false);
        append_number(&mut output, "health", health, true);
        append_number(
            &mut output,
            "cycle_count",
            positive(value("cycle_count")),
            true,
        );
        append_number(
            &mut output,
            "temperature",
            positive(raw_temperature / 10.0),
            true,
        );
        append_number(
            &mut output,
            "voltage",
            positive(voltage_now / 1_000_000.0),
            true,
        );
        append_number(&mut output, "power_draw", power_draw, true);
        append_number(&mut output, "design_energy", design_energy, true);
        output.push_str(",\"device_name\":\"");
        crate::json::escape_into(&device_name, &mut output);
        output.push_str("\"}");
        output
    }
}

pub fn encode_control() -> String {
    let battery = find_battery();
    let threshold = battery
        .as_ref()
        .map(|path| read_text(path.join("charge_control_end_threshold")))
        .unwrap_or_default();
    let charge_mode = if threshold.trim() == "80" {
        "preserve"
    } else {
        "maximize"
    };
    let governor = read_text("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor");
    let governor_override = read_pickle_choice(
        "/opt/auto-cpufreq/override.pickle",
        &["default", "powersave", "performance"],
        "default",
    );
    let turbo_override = read_pickle_choice(
        "/opt/auto-cpufreq/turbo-override.pickle",
        &["auto", "never", "always"],
        "auto",
    );

    let mut output = String::with_capacity(160);
    output.push('{');
    append_string(&mut output, "charge_mode", charge_mode, false);
    append_string(
        &mut output,
        "current_governor",
        if governor.is_empty() {
            "N/A"
        } else {
            &governor
        },
        true,
    );
    append_string(&mut output, "governor_override", &governor_override, true);
    append_string(&mut output, "turbo_override", &turbo_override, true);
    output.push('}');
    output
}

pub fn set_charge_mode(mode: &str) -> io::Result<()> {
    let battery = find_battery()
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "battery not found"))?;
    let (start, end) = match mode {
        "preserve" => ("75", "80"),
        "maximize" => ("50", "100"),
        _ => {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "charge mode must be preserve or maximize",
            ));
        }
    };

    fs::write(battery.join("charge_control_end_threshold"), end)?;
    let start_path = battery.join("charge_control_start_threshold");
    if start_path.exists() {
        fs::write(start_path, start)?;
    }
    Ok(())
}

fn append_number(output: &mut String, name: &str, value: Option<f64>, comma: bool) {
    if comma {
        output.push(',');
    }
    match value {
        Some(value) => write!(output, "\"{name}\":{value:.2}").unwrap(),
        None => write!(output, "\"{name}\":null").unwrap(),
    }
}

fn append_string(output: &mut String, name: &str, value: &str, comma: bool) {
    if comma {
        output.push(',');
    }
    write!(output, "\"{name}\":\"").unwrap();
    crate::json::escape_into(value, output);
    output.push('"');
}

fn find_battery() -> Option<PathBuf> {
    fs::read_dir("/sys/class/power_supply")
        .ok()?
        .flatten()
        .find(|entry| read_text(entry.path().join("type")) == "Battery")
        .map(|entry| entry.path())
}

fn read_pickle_choice(path: impl AsRef<Path>, choices: &[&str], fallback: &str) -> String {
    fs::read(path)
        .ok()
        .and_then(|bytes| find_choice(&bytes, choices))
        .unwrap_or(fallback)
        .to_string()
}

fn find_choice<'a>(bytes: &[u8], choices: &'a [&str]) -> Option<&'a str> {
    choices.iter().copied().find(|choice| {
        bytes
            .windows(choice.len())
            .any(|window| window == choice.as_bytes())
    })
}

fn positive(value: f64) -> Option<f64> {
    (value > 0.0 && value.is_finite()).then_some(value)
}

fn ratio(value: f64, total: f64) -> Option<f64> {
    (value > 0.0 && total > 0.0).then_some(value * 100.0 / total)
}

fn read_number(path: impl AsRef<Path>) -> f64 {
    read_text(path).parse().unwrap_or(0.0)
}

#[cfg(test)]
mod tests {
    use super::{find_choice, positive, ratio};

    #[test]
    fn rejects_missing_or_invalid_telemetry() {
        assert_eq!(positive(0.0), None);
        assert_eq!(positive(f64::NAN), None);
        assert_eq!(ratio(10.0, 0.0), None);
    }

    #[test]
    fn calculates_battery_health_percentage() {
        assert_eq!(ratio(60.0, 80.0), Some(75.0));
    }

    #[test]
    fn reads_known_auto_cpufreq_pickle_values_without_python() {
        let pickle = b"\x80\x04\x95\x0bperformance\x94.";
        assert_eq!(
            find_choice(pickle, &["default", "powersave", "performance"]),
            Some("performance")
        );
        assert_eq!(find_choice(pickle, &["auto", "never", "always"]), None);
    }
}
