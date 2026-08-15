# LDS Desktop — Dioxus spike (variant D)

A minimal spike proving a **Dioxus 0.7** desktop app can fill the same role as
the Tauri variant: a system-tray icon (via `muda`, Dioxus's tray re-export)
plus a panel window that live-polls `docker compose ps` and shows container
status every 3 seconds.

**Scope of the spike:** tray + panel + status poll. No log streaming, no
`lds` command bridge, no installers — those are the next steps if the spike
passes.

## Why Dioxus?

- Pure-Rust UI (`rsx!` — React-like, no HTML/JS frontend at all), signals
  reactivity, `<3 MB` portable binaries.
- Desktop runs on `wry`/`tao` — the *same* WebView layer Tauri uses, so the
  containerized-build machinery transfers almost 1:1 (`lds/tauri-dev` for the
  Linux compile-check, `lds/tauri-win-dev` for the Windows `.exe`).
- Tray: `dioxus_desktop::trayicon` re-exports `muda`/`tray-icon` — the same
  crates Tauri v2 uses, wired manually (no `TrayIconBuilder`-style abstraction).
- Path to a **native renderer** later: Dioxus Native (Blitz, WGPU) — no
  webview at all. Still experimental.

## Layout

```
Cargo.toml      dioxus 0.7 (desktop feature) + dioxus-desktop + serde + tokio
Dioxus.toml     dx config (serve / bundle); cargo build doesn't need it
src/main.rs     tray (muda) + panel with docker compose ps table
```

## Build (containerized compile-check)

```bash
desktop/build.sh dioxus          # Linux binary via lds/tauri-dev (reused from Tauri)
desktop/build.sh dioxus --os win --container   # Windows .exe via lds/tauri-win-dev
desktop/build.bat dioxus         # Windows counterpart of the first command
```

Artifacts: `desktop/dioxus/target/…/lds-desktop-dioxus`.

## Run on a host

```bash
cd desktop/dioxus && cargo run     # needs a webview (WebView2 / WebKitGTK)
# or with hot-patching: dx serve --platform desktop
```

The panel closes to the tray (the process stays alive); left-click the tray
icon to bring it back, use the tray menu to refresh or quit.

## Gotchas (learned while building the spike)

- `shift`-free note: none here — but the Dioxus 0.7 API churn is real:
  `launch` now takes `(root, contexts, platform_config)`; use
  `dioxus::LaunchBuilder::new().with_cfg(config).launch(App)` instead.
- `TrayIconBuilder` is `!Send` — the built `TrayIcon` is leaked via
  `Box::leak` so it outlives the `use_effect` that created it (dropping it
  removes the icon).
- `use_effect` re-runs on every render — guard one-time setup (tray) with a
  signal flag.
- Close-to-tray = `Config::with_exits_when_last_window_closes(false)`;
  tray-left-click-to-show is the default
  (`with_tray_icon_show_window_on_click(true)`).
