# Quickshell native backends

`qs-stats` is the on-demand system statistics sampler used by
`service/system/SysStats.qml`. It emits one JSON object per line and accepts one of
`none`, `cpu`, `ram`, or `gpu` on stdin to enable the corresponding process
list.

The same binary also supplies battery telemetry:

- `--battery` prints one JSON sample.
- `--battery-stream` prints a sample every five seconds and is kept alive only
  while the Battery page is open.

Build the optimized binary with:

```sh
cargo build --release
```

Manual builds are optional. `run-qs-stats` automatically rebuilds when the
binary is missing or older than its Rust sources. When Cargo is unavailable or
the build fails, it falls back to `scripts/sysstats.py`. The sampler only runs
while the Stats or Battery UI needs live data.
