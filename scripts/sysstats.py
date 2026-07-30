import json
import os
import select
import subprocess
import sys
import time


SAMPLE_INTERVAL = 1.0
GPU_SAMPLE_EVERY = 3
PROCESS_SAMPLE_INTERVAL = 2.0
CLOCK_TICKS = os.sysconf("SC_CLK_TCK")
PAGE_SIZE_KIB = os.sysconf("SC_PAGE_SIZE") / 1024
CPU_COUNT = os.cpu_count() or 1
SELF_PID = os.getpid()


def read_text(path):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return handle.read().strip()
    except (OSError, ValueError):
        return ""


def find_cpu_temp_path():
    preferred_types = {"x86_pkg_temp", "TCPU", "cpu-thermal"}
    fallback = None
    try:
        for entry in os.scandir("/sys/class/thermal"):
            if not entry.name.startswith("thermal_zone"):
                continue
            temp_path = os.path.join(entry.path, "temp")
            if not os.path.isfile(temp_path):
                continue
            if fallback is None:
                fallback = temp_path
            if read_text(os.path.join(entry.path, "type")) in preferred_types:
                return temp_path
    except OSError:
        pass
    return fallback


CPU_TEMP_PATH = find_cpu_temp_path()


def get_cpu_temp():
    try:
        return round(int(read_text(CPU_TEMP_PATH)) / 1000) if CPU_TEMP_PATH else "N/A"
    except ValueError:
        return "N/A"


def get_cpu_model():
    for line in read_text("/proc/cpuinfo").splitlines():
        name, separator, value = line.partition(":")
        if separator and name.strip() == "model name":
            return " ".join(value.replace("(R)", "").replace("(TM)", "").split())
    return ""


def get_cpu_stat():
    try:
        parts = read_text("/proc/stat").splitlines()[0].split()[1:9]
        values = list(map(int, parts))
        return sum(values), values[3] + values[4]
    except (IndexError, TypeError, ValueError):
        return 0, 0


def get_mem():
    values = {}
    try:
        with open("/proc/meminfo", "r", encoding="utf-8") as handle:
            for line in handle:
                name, value = line.split(":", 1)
                if name in ("MemTotal", "MemAvailable"):
                    values[name] = int(value.split()[0])
    except (OSError, ValueError):
        return 0, 0, 0

    total = values.get("MemTotal", 0)
    used = max(0, total - values.get("MemAvailable", 0))
    return ((used * 100 / total) if total else 0,
            used / 1024 / 1024,
            total / 1024 / 1024)


def get_default_interface():
    try:
        with open("/proc/net/route", "r", encoding="utf-8") as handle:
            next(handle, None)
            for line in handle:
                parts = line.split()
                if len(parts) > 3 and parts[1] == "00000000" and int(parts[3], 16) & 2:
                    return parts[0]
    except (OSError, ValueError):
        pass

    try:
        for name in sorted(os.listdir("/sys/class/net")):
            if name != "lo" and read_text(f"/sys/class/net/{name}/operstate") == "up":
                return name
    except OSError:
        pass
    return ""


def get_net(interface):
    if not interface:
        return 0, 0
    try:
        base = f"/sys/class/net/{interface}/statistics"
        return (int(read_text(f"{base}/rx_bytes")),
                int(read_text(f"{base}/tx_bytes")))
    except ValueError:
        return 0, 0


def get_process_snapshot(include_cpu=True, include_ram=True):
    snapshot = {}
    try:
        process_ids = os.listdir("/proc")
    except OSError:
        return snapshot

    for entry in process_ids:
        if not entry.isdigit():
            continue
        pid = int(entry)
        if pid == SELF_PID:
            continue
        try:
            if include_cpu:
                stat = read_text(f"/proc/{pid}/stat")
                close_paren = stat.rfind(")")
                open_paren = stat.find("(")
                if open_paren < 0 or close_paren < 0:
                    continue
                name = stat[open_paren + 1:close_paren]
                fields = stat[close_paren + 2:].split()
                cpu_ticks = int(fields[11]) + int(fields[12])
            else:
                name = read_text(f"/proc/{pid}/comm")
                cpu_ticks = 0
                if not name:
                    continue

            if include_ram:
                statm = read_text(f"/proc/{pid}/statm").split()
                rss_mib = ((int(statm[1]) * PAGE_SIZE_KIB / 1024)
                           if len(statm) > 1 else 0)
            else:
                rss_mib = 0
            snapshot[pid] = (name, cpu_ticks, rss_mib)
        except (IndexError, OSError, ValueError):
            continue
    return snapshot


def get_top_processes(previous, current, elapsed):
    cpu_by_name = {}
    ram_by_name = {}
    denominator = max(elapsed * CLOCK_TICKS * CPU_COUNT, 1)

    for pid, (name, ticks, rss_mib) in current.items():
        ram_by_name[name] = ram_by_name.get(name, 0) + rss_mib
        old = previous.get(pid)
        if old is None:
            continue
        delta = max(0, ticks - old[1])
        cpu_by_name[name] = cpu_by_name.get(name, 0) + delta * 100 / denominator

    top_cpu = [
        {"name": name, "val": value}
        for name, value in sorted(cpu_by_name.items(), key=lambda item: item[1], reverse=True)
        if value > 0
    ][:5]
    top_ram = [
        {"name": name, "val": value}
        for name, value in sorted(ram_by_name.items(), key=lambda item: item[1], reverse=True)
        if value > 0
    ][:5]
    return top_cpu, top_ram


def find_nvidia_device():
    base = "/sys/bus/pci/devices"
    try:
        for entry in os.scandir(base):
            if read_text(os.path.join(entry.path, "vendor")) == "0x10de":
                return entry.path
    except OSError:
        pass
    return ""


NVIDIA_DEVICE = find_nvidia_device()


def get_gpu_model():
    if not NVIDIA_DEVICE:
        return ""
    address = os.path.basename(NVIDIA_DEVICE)
    try:
        result = subprocess.run(
            ["lspci", "-s", address], capture_output=True, text=True,
            timeout=1.5, check=False
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    line = result.stdout.strip()
    open_bracket = line.find("[GeForce")
    close_bracket = line.find("]", open_bracket)
    if open_bracket >= 0 and close_bracket > open_bracket:
        return "NVIDIA " + line[open_bracket + 1:close_bracket]
    return line.split(": ", 1)[-1].strip() if ": " in line else ""


def run_nvidia_smi(arguments):
    try:
        result = subprocess.run(
            ["nvidia-smi", *arguments], capture_output=True, text=True,
            timeout=1.5, check=False
        )
        return result.stdout.strip() if result.returncode == 0 else ""
    except (OSError, subprocess.TimeoutExpired):
        return ""


def get_gpu_process_name(pid, reported_name):
    """Resolve Chromium/Electron GPU helpers to their owning desktop app."""
    try:
        with open(f"/proc/{pid}/environ", "rb") as env_file:
            for entry in env_file.read().split(b"\0"):
                if entry.startswith(b"CHROME_DESKTOP="):
                    desktop = entry.split(b"=", 1)[1].decode(
                        "utf-8", errors="replace"
                    )
                    if desktop.endswith(".desktop"):
                        desktop = desktop[:-8]
                    if desktop.endswith("-url-handler"):
                        desktop = desktop[:-12]
                    if desktop:
                        return desktop
    except OSError:
        pass

    try:
        with open(f"/proc/{pid}/cmdline", "rb") as cmdline_file:
            argv0 = cmdline_file.read().split(b"\0", 1)[0].decode(
                "utf-8", errors="replace"
            )
        argv0 = argv0.split(None, 1)[0] if argv0 else ""
        cmdline_base = os.path.basename(argv0)
        if cmdline_base and cmdline_base != "exe":
            return cmdline_base
    except OSError:
        pass

    # nvidia-smi may return a full command line. Only inspect its executable,
    # otherwise os.path.basename() leaves all Chromium flags in the UI.
    executable = reported_name.split(None, 1)[0] if reported_name else ""
    reported_base = os.path.basename(executable)
    if reported_base and reported_base != "exe":
        return reported_base

    comm = read_text(f"/proc/{pid}/comm")
    return comm or reported_base or str(pid)


def get_gpu():
    if not NVIDIA_DEVICE:
        return 0, 0, 0, 0
    if read_text(os.path.join(NVIDIA_DEVICE, "power/runtime_status")) == "suspended":
        return 0, 0, 0, 0
    output = run_nvidia_smi([
        "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total",
        "--format=csv,noheader,nounits"
    ])
    try:
        parts = [part.strip() for part in output.splitlines()[0].split(",")]
        return float(parts[0]), int(parts[1]), float(parts[2]), float(parts[3])
    except (IndexError, ValueError):
        return 0, 0, 0, 0


def get_top_gpu():
    # --query-compute-apps omits pure graphics contexts (Type G), including
    # compositors such as Niri and Quickshell. pmon reports G, C and C+G with
    # the current framebuffer allocation and still gives us a PID to resolve.
    output = run_nvidia_smi(["pmon", "-c", "1", "-s", "m"])
    totals = {}
    for line in output.splitlines():
        if not line or line.lstrip().startswith("#"):
            continue
        try:
            fields = line.split(None, 5)
            if len(fields) < 5:
                continue
            pid = int(fields[1])
            framebuffer_mib = float(fields[3])
            reported_name = fields[5] if len(fields) > 5 else ""
            name = get_gpu_process_name(pid, reported_name)
            totals[name] = totals.get(name, 0) + framebuffer_mib
        except (IndexError, OSError, ValueError):
            continue
    return [
        {"name": name, "val": value}
        for name, value in sorted(totals.items(), key=lambda item: item[1], reverse=True)
    ][:5]


def read_process_mode(current_mode):
    """Read the newest mode without blocking the one-second stats stream."""
    mode = current_mode
    changed = False
    while True:
        try:
            readable, _, _ = select.select([sys.stdin], [], [], 0)
        except (OSError, ValueError):
            break
        if not readable:
            break
        line = sys.stdin.readline()
        if not line:
            break
        requested = line.strip().lower()
        if requested in {"none", "cpu", "ram", "gpu"} and requested != mode:
            mode = requested
            changed = True
    return mode, changed


def find_battery():
    try:
        for entry in os.scandir("/sys/class/power_supply"):
            if read_text(os.path.join(entry.path, "type")) == "Battery":
                return entry.path
    except OSError:
        pass
    return ""


BATTERY_PATH = find_battery()


def read_pickle_choice(path, choices, fallback):
    try:
        import pickle
        with open(path, "rb") as handle:
            value = pickle.load(handle)
        return value if value in choices else fallback
    except (OSError, ValueError, TypeError, EOFError, pickle.UnpicklingError):
        return fallback


def battery_control_payload():
    threshold = read_text(os.path.join(
        BATTERY_PATH, "charge_control_end_threshold")) if BATTERY_PATH else ""
    governor = read_text(
        "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")
    return {
        "charge_mode": "preserve" if threshold == "80" else "maximize",
        "current_governor": governor or "N/A",
        "governor_override": read_pickle_choice(
            "/opt/auto-cpufreq/override.pickle",
            {"default", "powersave", "performance"}, "default"),
        "turbo_override": read_pickle_choice(
            "/opt/auto-cpufreq/turbo-override.pickle",
            {"auto", "never", "always"}, "auto"),
    }


def set_charge_mode(mode):
    if mode not in {"preserve", "maximize"}:
        raise ValueError("charge mode must be preserve or maximize")
    if not BATTERY_PATH:
        raise FileNotFoundError("battery not found")

    start, end = ("75", "80") if mode == "preserve" else ("50", "100")
    with open(os.path.join(BATTERY_PATH, "charge_control_end_threshold"),
              "w", encoding="utf-8") as handle:
        handle.write(end)
    start_path = os.path.join(BATTERY_PATH,
                              "charge_control_start_threshold")
    if os.path.exists(start_path):
        with open(start_path, "w", encoding="utf-8") as handle:
            handle.write(start)


def battery_payload():
    def number(name):
        try:
            return float(read_text(os.path.join(BATTERY_PATH, name))) if BATTERY_PATH else 0
        except ValueError:
            return 0

    charge_full = number("charge_full")
    charge_design = number("charge_full_design")
    energy_full = number("energy_full")
    energy_design = number("energy_full_design")
    voltage = number("voltage_now")
    voltage_design = number("voltage_min_design")
    current = number("current_now")
    power = number("power_now")
    health_value = energy_full if energy_full > 0 else charge_full
    health_total = energy_design if energy_design > 0 else charge_design
    device = " ".join(filter(None, [
        read_text(os.path.join(BATTERY_PATH, "manufacturer")) if BATTERY_PATH else "",
        read_text(os.path.join(BATTERY_PATH, "model_name")) if BATTERY_PATH else ""
    ])) or "Battery"

    gpu_power = None
    if NVIDIA_DEVICE and read_text(os.path.join(
            NVIDIA_DEVICE, "power/runtime_status")) != "suspended":
        try:
            gpu_power = float(run_nvidia_smi([
                "--query-gpu=power.draw", "--format=csv,noheader,nounits"
            ]).splitlines()[0])
        except (IndexError, ValueError):
            pass

    def positive(value):
        return value if value > 0 else None

    return {
        "gpu_power": gpu_power,
        "health": positive(health_value * 100 / health_total) if health_total > 0 else None,
        "cycle_count": positive(number("cycle_count")),
        "temperature": positive(number("temp") / 10),
        "voltage": positive(voltage / 1_000_000),
        "power_draw": positive(power / 1_000_000) if power > 0 else positive(
            voltage * current / 1_000_000_000_000),
        "design_energy": positive(energy_design / 1_000_000) if energy_design > 0
        else positive(voltage_design * charge_design / 1_000_000_000_000),
        "device_name": device
    }


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--battery-control":
        print(json.dumps(battery_control_payload()))
        return

    if len(sys.argv) > 2 and sys.argv[1] == "--set-charge-mode":
        set_charge_mode(sys.argv[2])
        return

    if len(sys.argv) > 1 and sys.argv[1] in {"--battery", "--battery-stream"}:
        stream = sys.argv[1] == "--battery-stream"
        while True:
            print(json.dumps(battery_payload()), flush=True)
            if not stream:
                return
            time.sleep(5)

    cpu_model = get_cpu_model()
    gpu_model = get_gpu_model()
    previous_time = None
    previous_interface = ""
    previous_rx = 0
    previous_tx = 0
    previous_processes = {}
    previous_process_time = None
    next_process_sample = 0
    process_mode = "none"
    gpu_usage = gpu_temp = gpu_mem_used = gpu_mem_total = 0
    next_gpu_process_sample = 0
    tick = 0
    next_tick = time.monotonic()

    while True:
        sample_time = time.monotonic()
        process_mode, process_mode_changed = read_process_mode(process_mode)
        if process_mode_changed:
            previous_processes = {}
            previous_process_time = None
            next_process_sample = 0
            next_gpu_process_sample = 0

        elapsed = sample_time - previous_time if previous_time is not None else 0
        cpu_total, cpu_idle = get_cpu_stat()
        cpu_temp = get_cpu_temp()
        ram_usage, ram_used_gb, ram_total_gb = get_mem()

        interface = get_default_interface()
        rx, tx = get_net(interface)
        same_counter = previous_time is not None and interface == previous_interface and elapsed > 0
        rx_rate = max(0, (rx - previous_rx) / elapsed) if same_counter else 0
        tx_rate = max(0, (tx - previous_tx) / elapsed) if same_counter else 0

        process_payload = {}
        if process_mode in {"cpu", "ram"} and sample_time >= next_process_sample:
            processes = get_process_snapshot(
                include_cpu=process_mode == "cpu",
                include_ram=process_mode == "ram"
            )
            has_process_baseline = previous_process_time is not None
            process_elapsed = (sample_time - previous_process_time
                               if has_process_baseline else 0)
            top_cpu, top_ram = get_top_processes(
                previous_processes, processes, process_elapsed
            )
            if process_mode == "cpu" and has_process_baseline:
                process_payload["top_cpu"] = top_cpu
            elif process_mode == "ram":
                process_payload["top_ram"] = top_ram
            previous_processes = processes
            previous_process_time = sample_time
            # The first snapshot provides RAM immediately and becomes the CPU
            # baseline. Take the second after one second, then settle at 2 s.
            next_process_sample = sample_time + (
                1.0 if process_elapsed <= 0 else PROCESS_SAMPLE_INTERVAL
            )
        elif process_mode not in {"cpu", "ram"}:
            previous_processes = {}
            previous_process_time = None

        if tick % GPU_SAMPLE_EVERY == 0:
            gpu_usage, gpu_temp, gpu_mem_used, gpu_mem_total = get_gpu()
        if process_mode == "gpu" and sample_time >= next_gpu_process_sample:
            process_payload["top_gpu"] = get_top_gpu()
            next_gpu_process_sample = sample_time + GPU_SAMPLE_EVERY

        payload = {
            "cpu_total": cpu_total,
            "cpu_idle": cpu_idle,
            "cpu_temp": cpu_temp,
            "ram_usage": ram_usage,
            "ram_used_gb": ram_used_gb,
            "ram_total_gb": ram_total_gb,
            "gpu_usage": gpu_usage,
            "gpu_temp": gpu_temp,
            "gpu_mem_used": gpu_mem_used,
            "gpu_mem_total": gpu_mem_total,
            "network_interface": interface,
            "rx_rate": rx_rate,
            "tx_rate": tx_rate
        }
        payload["cpu_model"] = cpu_model
        payload["gpu_model"] = gpu_model
        if tick == 0 or tick % 60 == 0:
            try:
                payload["uptime_seconds"] = int(
                    float(read_text("/proc/uptime").split()[0])
                )
            except (IndexError, ValueError):
                payload["uptime_seconds"] = 0
        payload.update(process_payload)
        print(json.dumps(payload), flush=True)

        previous_time = sample_time
        previous_interface = interface
        previous_rx = rx
        previous_tx = tx
        tick += 1

        next_tick += SAMPLE_INTERVAL
        delay = next_tick - time.monotonic()
        if delay <= -SAMPLE_INTERVAL:
            next_tick = time.monotonic()
        elif delay > 0:
            time.sleep(delay)


if __name__ == "__main__":
    main()
