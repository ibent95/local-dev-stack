//! LDS Desktop — Dioxus spike (variant D).
//!
//! Minimal proof that a Dioxus desktop app can do what the Tauri variant does:
//! a system-tray icon (via `muda`, Dioxus's tray re-export) plus a panel
//! window that live-polls `docker compose ps` and shows container status.
//!
//! The `lds` CLI stays the single source of truth — this app only invokes
//! docker (same design as the Tauri / JavaFX variants).
//!
//! Build (containerized compile-check, reuses the Tauri Linux image):
//!     desktop/build.sh dioxus          # Linux binary in desktop/dioxus/target/
//!     desktop/build.sh dioxus --os win --container   # Windows .exe (tauri-win-dev)
//!     desktop/build.bat dioxus         # Windows counterpart
//!
//! Run on a host with a webview (WebView2 / WebKitGTK):
//!     cargo run --manifest-path desktop/dioxus/Cargo.toml

use dioxus::prelude::*;
use dioxus_desktop::trayicon::menu::{Menu, MenuItem};
use dioxus_desktop::trayicon::{Icon, TrayIconBuilder};
use dioxus_desktop::{Config, LogicalSize, WindowBuilder};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

/// Set by the tray "Refresh status" item; the poll loop checks it between ticks.
static REFRESH: AtomicBool = AtomicBool::new(false);

/// One row of `docker compose ps --format json`.
#[derive(Deserialize, Serialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "PascalCase")]
struct ContainerInfo {
    #[serde(default)]
    name: String,
    #[serde(default)]
    service: String,
    #[serde(default)]
    state: String,
    #[serde(default)]
    health: String,
    #[serde(default)]
    status: String,
}

/// Repo root: walk up from this crate (`<root>/desktop/dioxus`) until we find
/// `lds.bat` / `lds.sh` — robust to the folder being moved deeper.
fn repo_root() -> PathBuf {
    let mut dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    loop {
        if dir.join("lds.bat").exists() || dir.join("lds.sh").exists() {
            return dir;
        }
        if !dir.pop() {
            return PathBuf::from(".");
        }
    }
}

/// Live status of every LDS container (`docker compose --profile '*' ps`).
fn stack_status() -> Result<Vec<ContainerInfo>, String> {
    let root = repo_root();
    let out = Command::new("docker")
        .args(["compose", "--profile", "*", "ps", "--format", "json"])
        .current_dir(&root)
        .output()
        .map_err(|e| format!("failed to run docker: {e}"))?;
    if !out.status.success() {
        return Err(String::from_utf8_lossy(&out.stderr).to_string());
    }
    serde_json::from_slice(&out.stdout).map_err(|e| format!("failed to parse docker output: {e}"))
}

/// 32×32 RGBA placeholder tray icon (LDS-blue square, transparent corners).
fn tray_icon_rgba() -> Vec<u8> {
    const S: u32 = 32;
    let mut rgba = Vec::with_capacity((S * S * 4) as usize);
    for y in 0..S {
        for x in 0..S {
            let corner = (x < 4 || x >= S - 4) && (y < 4 || y >= S - 4);
            let (r, g, b, a) = if corner { (0, 0, 0, 0) } else { (38, 132, 255, 255) };
            rgba.extend_from_slice(&[r, g, b, a]);
        }
    }
    rgba
}

fn main() {
    let cfg = Config::new()
        .with_window(
            WindowBuilder::new()
                .with_title("LDS Desktop — Dioxus spike")
                .with_inner_size(LogicalSize::new(760.0, 520.0)),
        )
        // Closing the panel must NOT kill the app: the tray keeps it alive.
        .with_exits_when_last_window_closes(false)
        // Left-clicking the tray icon shows + focuses the panel again.
        .with_tray_icon_show_window_on_click(true);

    dioxus::LaunchBuilder::new().with_cfg(cfg).launch(App);
}

fn App() -> Element {
    let mut containers = use_signal(Vec::<ContainerInfo>::new);
    let mut error = use_signal(String::new);

    // --- Tray icon + context menu (muda), built once ------------------------
    // use_effect re-runs on every render, so guard with a signal. The built
    // TrayIcon is leaked on purpose: if dropped, the icon vanishes (and a
    // TrayIcon is !Send, so it can't live in a Signal).
    let tray_ready = use_signal(|| false);
    use_effect(move || {
        if !*tray_ready.read() {
            let menu = Menu::new();
            let refresh =
                MenuItem::with_id(&menu, "refresh", "Refresh status", true, None::<&str>)
                    .expect("menu item");
            let quit = MenuItem::with_id(&menu, "quit", "Quit", true, None::<&str>)
                .expect("menu item");
            menu.append(&refresh).expect("append");
            menu.append(&quit).expect("append");

            let icon = Icon::from_rgba(tray_icon_rgba(), 32, 32).expect("icon");

            let tray = TrayIconBuilder::new()
                .with_menu(Box::new(menu))
                .with_icon(icon)
                .with_tooltip("LDS Desktop (Dioxus spike)")
                .build()
                .expect("tray icon");
            Box::leak(Box::new(tray));
            tray_ready.set(true);
        }
    });

    // --- Tray menu events ---------------------------------------------------
    use_tray_menu_event_handler(move |event| match event.id.as_ref() {
        "refresh" => REFRESH.store(true, Ordering::Relaxed),
        "quit" => std::process::exit(0),
        _ => {}
    });

    // --- Live poll: refresh immediately, then every 3s ----------------------
    use_future(move || async move {
        loop {
            match spawn_blocking(stack_status).await {
                Ok(list) => {
                    containers.set(list);
                    error.set(String::new());
                }
                Err(e) => error.set(e),
            }
            tokio::time::sleep(Duration::from_secs(3)).await;
            if REFRESH.swap(false, Ordering::Relaxed) {
                continue; // tray said refresh — poll again right away
            }
        }
    });

    rsx! {
        div {
            style: "font-family: system-ui, sans-serif; padding: 16px; display: flex; flex-direction: column; gap: 10px; height: 100vh; box-sizing: border-box;",
            header {
                style: "display: flex; align-items: center; justify-content: space-between;",
                h1 { style: "font-size: 16px; margin: 0;", "LDS Desktop — Dioxus spike" }
                button {
                    onclick: move |_| {
                        let c = containers.clone();
                        let e = error.clone();
                        spawn(async move {
                            match spawn_blocking(stack_status).await {
                                Ok(list) => { c.set(list); e.set(String::new()); }
                                Err(err) => e.set(err),
                            }
                        });
                    },
                    "Refresh"
                }
            }
            if !error.read().is_empty() {
                div { style: "color: #b00020; font-size: 12px;", "{error}" }
            }
            div {
                style: "flex: 1; overflow: auto; border: 1px solid #ddd; border-radius: 6px;",
                table {
                    style: "width: 100%; border-collapse: collapse; font-size: 13px;",
                    thead {
                        tr {
                            th { style: "text-align: left; padding: 6px 8px; border-bottom: 2px solid #ddd;", "Service" }
                            th { style: "text-align: left; padding: 6px 8px; border-bottom: 2px solid #ddd;", "State" }
                            th { style: "text-align: left; padding: 6px 8px; border-bottom: 2px solid #ddd;", "Health" }
                            th { style: "text-align: left; padding: 6px 8px; border-bottom: 2px solid #ddd;", "Status" }
                        }
                    }
                    tbody {
                        for c in containers.read().iter() {
                            tr {
                                key: "{c.service}",
                                td { style: "padding: 4px 8px; border-bottom: 1px solid #eee;", "{c.service}" }
                                td { style: "padding: 4px 8px; border-bottom: 1px solid #eee;", "{c.state}" }
                                td { style: "padding: 4px 8px; border-bottom: 1px solid #eee;", "{c.health}" }
                                td { style: "padding: 4px 8px; border-bottom: 1px solid #eee;", "{c.status}" }
                            }
                        }
                    }
                }
            }
            footer { style: "font-size: 11px; color: #888;", "Auto-refresh every 3s · data: docker compose ps" }
        }
    }
}
