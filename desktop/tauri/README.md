# LDS Desktop — Tauri variant

The **Rust + Tauri v2** implementation of the LDS desktop companion. Thin
shell over the `lds` CLI — see [`../README.md`](../README.md) for the shared
feature list and the JavaFX sibling.

## Layout

```
tauri/
├── ui/                      # static frontend (vanilla JS — no bundler, no npm)
│   ├── index.html
│   ├── styles.css
│   └── main.js              # talks to Rust via window.__TAURI__.core.invoke
└── src-tauri/
    ├── src/
    │   ├── main.rs          # entry point
    │   └── lib.rs           # commands + tray: lds_run, stack_status,
    │                        #   service_logs, stream_logs, stop_log_stream,
    │                        #   open_url, hosts_sync
    ├── capabilities/        # Tauri v2 permissions (core:default)
    ├── icons/               # generated PNG + ICO
    ├── build.rs
    ├── Cargo.toml
    └── tauri.conf.json
```

The Rust backend walks up from `src-tauri/` until it finds `lds.bat` /
`lds.sh`, so the app resolves the repo root from anywhere.

## Build (containerized — recommended)

```bash
# one-time: build the base image
lds build-bases            # or: docker buildx bake tauri-dev

# then compile-check + build
desktop/build.sh tauri
```

## Build (containerized — Windows .exe cross-compile)

The same source tree emits a **real Windows binary from the Linux container**
via the mingw-w64 cross toolchain (`lds/tauri-win-dev` = `tauri-dev` +
mingw-w64 + rustup with the `x86_64-pc-windows-gnu` target; built on demand
by the command — NOT part of `lds build-bases`, it's ~2.5 GB):

```bash
desktop/build.sh tauri --os win --container
# → desktop/tauri/src-tauri/target/x86_64-pc-windows-gnu/debug/lds-desktop.exe
#   (PE32+ executable, x86-64)
```

Notes:

- This is the **raw .exe** (compile artifact) — NSIS/MSI **installers** still
  need `cargo tauri build` on Windows. At runtime the .exe needs
  `WebView2Loader.dll` beside it (tauri loads it dynamically on Windows).
- `Cargo.toml`'s `crate-type = ["rlib"]` is deliberate: the template's
  `staticlib`/`cdylib` pair exists for mobile embedding and `cdylib` breaks
  the windows-gnu link with `export ordinal too large` (mingw export-table
  overflow over the whole tauri surface).
- The toolchain version is pinned in `base-images/tauri-win-dev/Dockerfile`;
  bumping it recompiles the windows target dir once.

## Build (host) / per-OS installers

Prereqs: Rust (rustup) + `cargo install tauri-cli --locked`, WebView2
(Windows) / webkit2gtk-4.1 (Linux). Tauri's bundler only emits installers
for the OS it runs on — the container build is a Linux compile-check (musl
binary, not a distributable glibc build).

```bash
cd desktop/tauri/src-tauri
cargo tauri dev      # dev run against ../ui (UI files hot-reload)
cargo tauri build    # installers in target/release/bundle/
                     #   Windows: NSIS + MSI · Linux: deb/rpm/AppImage · macOS: app/dmg
```

`desktop/build.sh tauri --os win|mac` runs the same host build from the repo
root. The full Windows + Linux + macOS matrix runs automatically via
`.github/workflows/desktop-build.yml` (tauri-action, per-OS `--bundles`,
artifacts uploaded).

## Notes

- The generic `lds_run` command means any future `lds` command is just a new
  UI button — no backend change.
- Tray "Start all" / "Stop all" run in the background; use the panel's
  Output section for CLI output.
- The status table auto-refreshes every 5 s (header toggle). Log streaming
  (`stream_logs`) runs `docker compose logs --tail N --follow <service>` and
  pushes each line to the UI as a `log-chunk` event; `stop_log_stream` and app
  exit kill the child so nothing is orphaned.
