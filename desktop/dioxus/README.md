# LDS Desktop — Dioxus (variant D)

The **pure-Rust** implementation of the LDS desktop companion: the full feature
set of the Tauri / JavaFX / NativePHP variants, with a `rsx!` UI instead of
HTML/JS. A system-tray icon (via `muda`, Dioxus's tray re-export) plus a 6-tab
panel that drives the `lds` CLI.

**Scope:** full parity — tray (open / start all / stop all / refresh / quit),
11 lifecycle commands, 51 profile chips, 41 tool cards, container status poll,
one-shot + streaming logs, `lds tools` runners and elevated `hosts-sync`.

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
src/main.rs     tray (muda) + 6 tabs + lds bridge + status poll + log stream
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

## Gotchas (learned while building it)

- The Dioxus 0.7 API churn is real: `launch` now takes
  `(root, contexts, platform_config)`; use
  `dioxus::LaunchBuilder::new().with_cfg(config).launch(App)` instead.
- `TrayIconBuilder` is `!Send` — the built `TrayIcon` is leaked via
  `Box::leak` so it outlives the `use_effect` that created it (dropping it
  removes the icon).
- `use_effect` re-runs on every render — guard one-time setup (tray) with a
  signal flag.
- Close-to-tray = `Config::with_exits_when_last_window_closes(false)`;
  tray-left-click-to-show is the default
  (`with_tray_icon_show_window_on_click(true)`).
- 0.7 dropped `spawn_blocking` from the prelude: blocking `lds`/`docker`
  calls go through a small `run_blocking` helper (std thread + `tokio`
  oneshot) so the UI thread never stalls.
- The live log stream keeps the `Child` in a static `Mutex` and pushes lines
  into a static buffer; a `use_future` drains it into the UI signal every
  100 ms (the tray Quit / Stop button kill the child).
