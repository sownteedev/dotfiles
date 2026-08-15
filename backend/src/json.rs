use crate::model::{RankedProcess, StatsPayload};
use std::fmt::Write;

pub fn encode(payload: &StatsPayload) -> String {
    let mut output = String::with_capacity(768);
    output.push('{');
    if let Some(value) = payload.cpu_model.as_deref() {
        output.push_str("\"cpu_model\":\"");
        escape_into(value, &mut output);
        output.push_str("\",");
    }
    write!(output, "\"cpu_total\":{},", payload.cpu_total).unwrap();
    write!(output, "\"cpu_idle\":{},", payload.cpu_idle).unwrap();
    match payload.cpu_temperature {
        Some(value) => write!(output, "\"cpu_temp\":{value},").unwrap(),
        None => output.push_str("\"cpu_temp\":\"N/A\","),
    }
    write!(output, "\"ram_usage\":{},", finite(payload.ram_usage)).unwrap();
    write!(output, "\"ram_used_gb\":{},", finite(payload.ram_used_gib)).unwrap();
    write!(
        output,
        "\"ram_total_gb\":{},",
        finite(payload.ram_total_gib)
    )
    .unwrap();
    write!(output, "\"gpu_usage\":{},", finite(payload.gpu.usage)).unwrap();
    write!(output, "\"gpu_temp\":{},", payload.gpu.temperature).unwrap();
    write!(
        output,
        "\"gpu_mem_used\":{},",
        finite(payload.gpu.memory_used)
    )
    .unwrap();
    write!(
        output,
        "\"gpu_mem_total\":{},",
        finite(payload.gpu.memory_total)
    )
    .unwrap();
    if let Some(value) = payload.gpu_model.as_deref() {
        output.push_str("\"gpu_model\":\"");
        escape_into(value, &mut output);
        output.push_str("\",");
    }
    output.push_str("\"network_interface\":\"");
    escape_into(&payload.network_interface, &mut output);
    output.push_str("\",");
    write!(output, "\"rx_rate\":{},", finite(payload.rx_rate)).unwrap();
    write!(output, "\"tx_rate\":{}", finite(payload.tx_rate)).unwrap();
    append_ranked("top_cpu", payload.top_cpu.as_deref(), &mut output);
    append_ranked("top_ram", payload.top_ram.as_deref(), &mut output);
    append_ranked("top_gpu", payload.top_gpu.as_deref(), &mut output);
    if let Some(value) = payload.uptime_seconds {
        write!(output, ",\"uptime_seconds\":{value}").unwrap();
    }
    output.push('}');
    output
}

fn append_ranked(name: &str, values: Option<&[RankedProcess]>, output: &mut String) {
    let Some(values) = values else {
        return;
    };
    write!(output, ",\"{name}\":[").unwrap();
    for (index, item) in values.iter().enumerate() {
        if index > 0 {
            output.push(',');
        }
        write!(output, "{{\"pid\":{},\"name\":\"", item.pid).unwrap();
        escape_into(&item.name, output);
        write!(output, "\",\"val\":{}}}", finite(item.value)).unwrap();
    }
    output.push(']');
}

pub(crate) fn escape_into(value: &str, output: &mut String) {
    for character in value.chars() {
        match character {
            '"' => output.push_str("\\\""),
            '\\' => output.push_str("\\\\"),
            '\n' => output.push_str("\\n"),
            '\r' => output.push_str("\\r"),
            '\t' => output.push_str("\\t"),
            value if value <= '\u{1f}' => write!(output, "\\u{:04x}", value as u32).unwrap(),
            value => output.push(value),
        }
    }
}

fn finite(value: f64) -> f64 {
    if value.is_finite() { value } else { 0.0 }
}

#[cfg(test)]
mod tests {
    use super::escape_into;

    #[test]
    fn escapes_process_names_as_valid_json_strings() {
        let mut output = String::new();
        escape_into("app\\name\"\n", &mut output);
        assert_eq!(output, "app\\\\name\\\"\\n");
    }
}
