# SownteeShell backends

Non-visual work is grouped by implementation language and then by feature
domain:

```text
backend/
├── native/                 # Small C++ helpers using Qt/native APIs
├── python/                 # On-demand system, API, and file-processing jobs
└── rust/                   # Long-running or performance-sensitive workers
```

Python backends use `snake_case.py` names that describe the capability they
provide. They are invoked directly by the owning QML service and do not run as
background daemons.

## System statistics

`rust/system-stats` provides the on-demand sampler used by
`service/system/SysStats.qml` and `service/system/BatteryService.qml`. It emits
one JSON object per line and accepts `none`, `cpu`, `ram`, or `gpu` on stdin to
select the process list.

The same binary supports battery telemetry and process actions:

- `--battery` prints one battery sample.
- `--battery-stream` prints a sample every five seconds.
- `--battery-control` reports charging and CPU policy support.
- `--set-charge-mode MODE` and `--set-charge-thresholds START END` update
  supported charging limits.
- `--process-memory PID` reports RSS, PSS, PSS Dirty, and private memory.
- `--terminate-tree PID` terminates a verified process tree.

Build it manually with:

```sh
cargo build --release --manifest-path backend/rust/system-stats/Cargo.toml
```

Manual builds are optional. `rust/system-stats/run-system-stats` rebuilds an
outdated binary automatically and falls back to
`python/system/system_stats_fallback.py` when Cargo or the native binary is not
available. The worker only runs while a Stats or Battery consumer needs it.

The small shell integrations that manage external commands remain in
`../scripts/`, grouped by feature domain rather than implementation language.
