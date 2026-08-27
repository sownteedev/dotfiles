import json
import os
import select
import signal
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


def get_process_name(pid, reported_name):
    electron_process = reported_name.lower().startswith("electron")

    if electron_process:
        try:
            with open(f"/proc/{pid}/environ", "rb") as env_file:
                for entry in env_file.read().split(b"\0"):
                    if not entry.startswith(b"CHROME_DESKTOP="):
                        continue
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

    if electron_process:
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as cmdline_file:
                arguments = cmdline_file.read().split(b"\0")
            for argument in arguments[1:]:
                path = argument.decode("utf-8", errors="replace")
                if os.path.basename(path) == "app.asar":
                    app_name = os.path.basename(os.path.dirname(path))
                    if app_name:
                        return app_name
        except OSError:
            pass

    try:
        executable = os.readlink(f"/proc/{pid}/exe")
        if executable:
            return executable
    except OSError:
        pass

    try:
        with open(f"/proc/{pid}/cmdline", "rb") as cmdline_file:
            arguments = cmdline_file.read().split(b"\0")
        executable = arguments[0].decode(
            "utf-8", errors="replace"
        ).split(maxsplit=1)[0] if arguments and arguments[0] else ""
        if executable and executable != "exe":
            return executable
    except OSError:
        pass

    return reported_name


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
        if pid <= 1 or pid == SELF_PID:
            continue
        try:
            stat = read_text(f"/proc/{pid}/stat")
            close_paren = stat.rfind(")")
            open_paren = stat.find("(")
            if open_paren < 0 or close_paren < 0:
                continue
            name = stat[open_paren + 1:close_paren]
            fields = stat[close_paren + 2:].split()
            if len(fields) <= 12:
                continue
            parent_pid = int(fields[1])
            if include_cpu:
                cpu_ticks = int(fields[11]) + int(fields[12])
            else:
                cpu_ticks = 0

            if include_ram:
                statm = read_text(f"/proc/{pid}/statm").split()
                rss_mib = ((int(statm[1]) * PAGE_SIZE_KIB / 1024)
                           if len(statm) > 1 else 0)
            else:
                rss_mib = 0
            snapshot[pid] = (
                get_process_name(pid, name), parent_pid, cpu_ticks, rss_mib
            )
        except (IndexError, OSError, ValueError):
            continue
    return snapshot


def get_top_processes(previous, current, elapsed):
    denominator = max(elapsed * CLOCK_TICKS * CPU_COUNT, 1)
    cpu_processes = {}
    ram_processes = {}

    for pid, (name, _parent_pid, ticks, rss_mib) in current.items():
        group_pid = get_process_group_pid(current, pid)
        group = (group_pid, name)
        ram_processes[group] = ram_processes.get(group, 0) + rss_mib
        old = previous.get(pid)
        if old is None:
            continue
        delta = max(0, ticks - old[2])
        value = delta * 100 / denominator
        cpu_processes[group] = cpu_processes.get(group, 0) + value

    top_cpu = sorted(
        [
            {"pid": pid, "name": name, "val": value}
            for (pid, name), value in cpu_processes.items()
        ],
        key=lambda item: item["val"], reverse=True
    )
    top_ram = sorted(
        [
            {"pid": pid, "name": name, "val": value}
            for (pid, name), value in ram_processes.items()
        ],
        key=lambda item: item["val"], reverse=True
    )
    return top_cpu, top_ram


def read_process_memory_rollup(pid):
    values = {}
    try:
        with open(f"/proc/{pid}/smaps_rollup", "r", encoding="utf-8") as handle:
            for line in handle:
                name, separator, value = line.partition(":")
                if not separator or name not in {
                        "Pss", "Pss_Dirty", "Private_Clean", "Private_Dirty"}:
                    continue
                values[name] = int(value.split()[0])
    except (IndexError, OSError, ValueError):
        return None

    required = {"Pss", "Pss_Dirty", "Private_Clean", "Private_Dirty"}
    if not required.issubset(values):
        return None
    return {
        "pss_kib": values["Pss"],
        "pss_dirty_kib": values["Pss_Dirty"],
        "private_kib": values["Private_Clean"] + values["Private_Dirty"],
    }


def get_process_memory_details(root_pid):
    if root_pid <= 1:
        raise ValueError("process id must be greater than one")

    snapshot = get_process_snapshot(include_cpu=False, include_ram=True)
    target = snapshot.get(root_pid)
    if target is None:
        raise ProcessLookupError("process no longer exists")
    target_name = target[0]
    process_count = 0
    measured_process_count = 0
    rss_mib = 0
    pss_kib = 0
    pss_dirty_kib = 0
    private_kib = 0

    for pid, (name, _parent_pid, _ticks, process_rss_mib) in snapshot.items():
        if name != target_name or get_process_group_pid(snapshot, pid) != root_pid:
            continue
        process_count += 1
        rss_mib += process_rss_mib
        memory = read_process_memory_rollup(pid)
        if memory is None:
            continue
        measured_process_count += 1
        pss_kib += memory["pss_kib"]
        pss_dirty_kib += memory["pss_dirty_kib"]
        private_kib += memory["private_kib"]

    has_detailed_sample = measured_process_count > 0
    return {
        "pid": root_pid,
        "process_count": process_count,
        "measured_process_count": measured_process_count,
        "rss_mib": rss_mib,
        "pss_mib": pss_kib / 1024 if has_detailed_sample else None,
        "pss_dirty_mib": pss_dirty_kib / 1024 if has_detailed_sample else None,
        "private_mib": private_kib / 1024 if has_detailed_sample else None,
    }


def get_process_group_pid(snapshot, pid):
    process = snapshot.get(pid)
    if process is None:
        return pid
    name = process[0]
    leader = pid

    for _ in range(64):
        current = snapshot.get(leader)
        if current is None:
            break
        parent_pid = current[1]
        if parent_pid <= 1 or parent_pid == leader:
            break
        parent = snapshot.get(parent_pid)
        if parent is None or parent[0] != name:
            break
        leader = parent_pid

    return leader

def terminate_process_tree(root_pid):
    if root_pid <= 1:
        raise ValueError("process id must be greater than one")
    root_identity = process_state_and_start_time(root_pid)
    if root_identity is None:
        return
    root_start_time = root_identity[1]

    initial_tree = collect_process_tree(root_pid)
    initial_helpers = linked_crashpad_handlers(initial_tree)
    initial_order = initial_tree + initial_helpers
    tracked = {}
    track_processes(initial_order, tracked)
    tracked.setdefault(root_pid, root_start_time)

    # Stop the application parent first, then its current helpers. This avoids
    # Electron/Chromium replacing helpers while shutdown is already underway.
    terminate_order = list(reversed(initial_tree)) + initial_helpers
    signal_tracked_processes(signal.SIGTERM, terminate_order, tracked)

    deadline = time.monotonic() + 0.9
    while time.monotonic() < deadline:
        if not has_live_tracked_processes(tracked):
            return
        if process_matches(root_pid, root_start_time):
            current_tree = collect_process_tree(root_pid)
            current_order = current_tree + linked_crashpad_handlers(current_tree)
            new_processes = [pid for pid in current_order if pid not in tracked]
            track_processes(new_processes, tracked)
            signal_tracked_processes(
                signal.SIGTERM, reversed(new_processes), tracked)
        time.sleep(0.05)

    if process_matches(root_pid, root_start_time):
        current_tree = collect_process_tree(root_pid)
        track_processes(current_tree, tracked)
        track_processes(linked_crashpad_handlers(current_tree), tracked)
    force_order = sorted(tracked, key=lambda pid: pid == root_pid)
    permission_error = signal_tracked_processes(
        signal.SIGKILL, force_order, tracked)

    force_deadline = time.monotonic() + 0.35
    while time.monotonic() < force_deadline:
        if not has_live_tracked_processes(tracked):
            return
        time.sleep(0.025)

    remaining = sum(
        1 for pid, start_time in tracked.items()
        if process_matches(pid, start_time)
    )
    if permission_error is not None:
        raise permission_error
    if remaining:
        raise RuntimeError(f"failed to terminate {remaining} process(es)")


def collect_process_tree(root_pid):
    if not os.path.exists(f"/proc/{root_pid}"):
        return []

    children_by_parent = {}
    try:
        process_ids = os.listdir("/proc")
    except OSError:
        process_ids = []
    for entry in process_ids:
        if not entry.isdigit():
            continue
        stat = read_text(f"/proc/{entry}/stat")
        close_paren = stat.rfind(")")
        if close_paren < 0:
            continue
        fields = stat[close_paren + 2:].split()
        if len(fields) < 2:
            continue
        try:
            parent_pid = int(fields[1])
            children_by_parent.setdefault(parent_pid, []).append(int(entry))
        except ValueError:
            continue

    order = []
    seen = set()
    stack = [(root_pid, False)]
    while stack:
        pid, visited = stack.pop()
        if visited:
            order.append(pid)
            continue
        if pid in seen:
            continue
        seen.add(pid)
        stack.append((pid, True))
        for child in children_by_parent.get(pid, []):
            stack.append((child, False))

    return order


def linked_crashpad_handlers(process_ids):
    result = []
    seen = set()
    for pid in process_ids:
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as command_file:
                arguments = command_file.read().split(b"\0")
        except OSError:
            continue
        for argument in arguments:
            prefix = b"--crashpad-handler-pid="
            if not argument.startswith(prefix):
                continue
            try:
                helper_pid = int(argument[len(prefix):])
            except ValueError:
                continue
            if (helper_pid > 1 and helper_pid not in seen
                    and is_crashpad_handler(helper_pid)):
                seen.add(helper_pid)
                result.append(helper_pid)
    return result


def is_crashpad_handler(pid):
    try:
        if "crashpad_handler" in os.path.basename(os.readlink(f"/proc/{pid}/exe")):
            return True
    except OSError:
        pass
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as command_file:
            executable = command_file.read().split(b"\0", 1)[0]
        return b"crashpad_handler" in executable
    except OSError:
        return False


def process_state_and_start_time(pid):
    stat = read_text(f"/proc/{pid}/stat")
    close_paren = stat.rfind(")")
    if close_paren < 0:
        return None
    fields = stat[close_paren + 2:].split()
    if len(fields) <= 19:
        return None
    try:
        return fields[0], int(fields[19])
    except ValueError:
        return None


def process_matches(pid, start_time):
    identity = process_state_and_start_time(pid)
    return (identity is not None and identity[0] not in {"Z", "X", "x"}
            and identity[1] == start_time)


def track_processes(process_ids, tracked):
    for pid in process_ids:
        if pid in tracked:
            continue
        identity = process_state_and_start_time(pid)
        if identity is not None and identity[0] not in {"Z", "X", "x"}:
            tracked[pid] = identity[1]


def signal_tracked_processes(signal_number, process_ids, tracked):
    permission_error = None
    for pid in process_ids:
        start_time = tracked.get(pid)
        if start_time is None or not process_matches(pid, start_time):
            continue
        try:
            os.kill(pid, signal_number)
        except ProcessLookupError:
            continue
        except PermissionError as error:
            permission_error = error
    return permission_error


def has_live_tracked_processes(tracked):
    return any(
        process_matches(pid, start_time)
        for pid, start_time in tracked.items()
    )


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
            previous = totals.get(pid, {"name": name, "val": 0})
            previous["val"] += framebuffer_mib
            totals[pid] = previous
        except (IndexError, OSError, ValueError):
            continue
    return [
        {"pid": pid, "name": item["name"], "val": item["val"]}
        for pid, item in sorted(
            totals.items(), key=lambda entry: entry[1]["val"], reverse=True
        )
    ]


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
    start_path = os.path.join(
        BATTERY_PATH, "charge_control_start_threshold") if BATTERY_PATH else ""
    end_path = os.path.join(
        BATTERY_PATH, "charge_control_end_threshold") if BATTERY_PATH else ""
    start_threshold = read_threshold(start_path)
    end_threshold = read_threshold(end_path)
    charge_mode = {
        (55, 60): "conservation",
        (75, 80): "preserve",
        (50, 100): "maximize",
    }.get((start_threshold, end_threshold), "custom")
    governor = read_text(
        "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")
    return {
        "charge_mode": charge_mode,
        "charge_start_threshold": start_threshold,
        "charge_end_threshold": end_threshold,
        "charge_threshold_supported": bool(end_path and os.path.exists(end_path)),
        "current_governor": governor or "N/A",
        "governor_override": read_pickle_choice(
            "/opt/auto-cpufreq/override.pickle",
            {"default", "powersave", "performance"}, "default"),
        "turbo_override": read_pickle_choice(
            "/opt/auto-cpufreq/turbo-override.pickle",
            {"auto", "never", "always"}, "auto"),
    }


def set_charge_mode(mode):
    thresholds = {
        "conservation": (55, 60),
        "preserve": (75, 80),
        "maximize": (50, 100),
    }
    if mode not in thresholds:
        raise ValueError(
            "charge mode must be conservation, preserve or maximize")
    set_charge_thresholds(*thresholds[mode])

def set_charge_thresholds(start, end):
    if not 0 <= start < end <= 100:
        raise ValueError(
            "charge thresholds must satisfy 0 <= start < end <= 100")
    if not BATTERY_PATH:
        raise FileNotFoundError("battery not found")

    start_path = os.path.join(BATTERY_PATH,
                              "charge_control_start_threshold")
    end_path = os.path.join(BATTERY_PATH, "charge_control_end_threshold")
    if not os.path.exists(end_path):
        raise OSError("charge thresholds are not supported by this battery")

    def write_threshold(path, value):
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(str(value))

    current_start = read_threshold(start_path)
    if (os.path.exists(start_path) and current_start is not None
            and end <= current_start):
        write_threshold(start_path, start)
        write_threshold(end_path, end)
    else:
        write_threshold(end_path, end)
        if os.path.exists(start_path):
            write_threshold(start_path, start)

def read_threshold(path):
    try:
        return int(read_text(path)) if path else None
    except ValueError:
        return None

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
        "full_energy": positive(energy_full / 1_000_000) if energy_full > 0
        else positive(voltage_design * charge_full / 1_000_000_000_000),
        "design_energy": positive(energy_design / 1_000_000) if energy_design > 0
        else positive(voltage_design * charge_design / 1_000_000_000_000),
        "device_name": device
    }


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--process-memory":
        print(json.dumps(get_process_memory_details(int(sys.argv[2]))))
        return

    if len(sys.argv) > 2 and sys.argv[1] == "--terminate-tree":
        terminate_process_tree(int(sys.argv[2]))
        return

    if len(sys.argv) > 1 and sys.argv[1] == "--battery-control":
        print(json.dumps(battery_control_payload()))
        return

    if len(sys.argv) > 2 and sys.argv[1] == "--set-charge-mode":
        set_charge_mode(sys.argv[2])
        return

    if len(sys.argv) > 3 and sys.argv[1] == "--set-charge-thresholds":
        set_charge_thresholds(int(sys.argv[2]), int(sys.argv[3]))
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
