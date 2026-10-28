//! LDS Desktop — Dioxus variant (variant D).
//!
//! Full-parity desktop companion for the local-dev-stack: system tray
//! (open / start all / stop all / refresh / quit), lifecycle buttons,
//! profile chips, admin tool cards, container status with auto-refresh,
//! one-shot + live log streaming, path-scoped `lds tools` runners and an
//! elevated hosts-sync — the same feature set as the Tauri / JavaFX variants.
//!
//! The `lds` CLI stays the single source of truth — this app only invokes
//! it (same design as the Tauri / JavaFX variants).
//!
//! Build (containerized compile-check, reuses the Tauri Linux image):
//!     desktop/build.sh dioxus          # Linux binary in desktop/dioxus/target/
//!     desktop/build.sh dioxus --os win --container   # Windows .exe (tauri-win-dev)
//!     desktop/build.bat dioxus         # Windows counterpart
//!
//! Run on a host with a webview (WebView2 / WebKitGTK):
//!     cargo run --manifest-path desktop/dioxus/Cargo.toml

use dioxus::prelude::*;
use dioxus_desktop::trayicon::menu::{Menu, MenuItem, PredefinedMenuItem};
use dioxus_desktop::trayicon::{Icon, TrayIconBuilder};
use dioxus_desktop::{
    use_tray_menu_event_handler, use_window, Config, LogicalSize, WindowBuilder,
};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::io::{BufRead, BufReader};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

/// Set by the tray "Refresh status" item; the poll loop checks it between ticks.
static REFRESH: AtomicBool = AtomicBool::new(false);
/// Set by the tray "Open" item; a watcher future re-shows the panel window.
static OPEN_WINDOW: AtomicBool = AtomicBool::new(false);

/// Live `docker compose logs --follow` child (killed by Stop / tray Quit).
static LOG_STREAM: Mutex<Option<Child>> = Mutex::new(None);
/// Lines read by the streamer thread; drained into the UI by a watcher future.
static LOG_BUF: Mutex<Vec<String>> = Mutex::new(Vec::new());

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

/// Curated profile chips (mirrors docker-compose service profiles; the
/// one-shot `*-scan` profiles stay behind the `lds tools` buttons).
const PROFILES: &[&str] = &[
    "analytics", "centrifugo", "crg", "dbx", "drawdb", "drawio", "duckdb",
    "erpnext", "headlessx", "hop", "hoppscotch", "imgcompress", "instatic",
    "kafka", "keycloak", "lldap", "mail", "mariadb", "memcached", "metabase",
    "mongo", "monitoring", "mqtt", "mssql", "mysql", "openldap", "openwa",
    "oracle", "penpot", "php", "phpcacheadmin", "plane", "playwright",
    "postgres", "proxy", "rabbitmq", "redis", "rustfs", "search", "semgrep",
    "snapotter", "soketi", "sonarqube", "superset", "tasks", "trino", "trivy",
    "valkey", "vaultwarden", "wiki", "zap",
];

/// Admin tool cards (label -> url; mirrors docs/en/12-ports.md).
const TOOLS: &[(&str, &str)] = &[
    ("phpCacheAdmin", "http://localhost:4500"),
    ("DBX", "http://localhost:4501"),
    ("DrawDB", "http://localhost:4502"),
    ("Apache Hop", "http://localhost:4503"),
    ("Superset", "http://localhost:4504"),
    ("Metabase", "http://localhost:4541"),
    ("Hoppscotch", "http://localhost:4542"),
    ("Plane", "http://localhost:4543"),
    ("Semgrep", "http://localhost:4505"),
    ("Vaultwarden", "http://localhost:4506"),
    ("OpenWA", "http://localhost:4507"),
    ("RustFS", "http://localhost:4509"),
    ("ZAP", "http://localhost:4510"),
    ("Trivy", "http://localhost:4511"),
    ("Mailpit", "http://localhost:4513"),
    ("Penpot", "http://localhost:4518"),
    ("Analytics", "http://localhost:4521"),
    ("Tasks", "http://localhost:4523"),
    ("Wiki", "http://localhost:4525"),
    ("Playwright", "http://localhost:4526"),
    ("Instatic", "http://localhost:4528"),
    ("ERPNext", "http://localhost:4529"),
    ("code-review-graph", "http://localhost:4530"),
    ("Trino", "http://localhost:4451"),
    ("RabbitMQ", "http://localhost:4411"),
    ("Kafka UI", "http://localhost:4424"),
    ("Centrifugo", "http://localhost:4441"),
    ("MQTTX", "http://localhost:4444"),
    ("HeadlessX", "http://localhost:4515"),
    ("Grafana", "http://localhost:4532"),
    ("Prometheus", "http://localhost:4533"),
    ("draw.io", "http://localhost:4535"),
    ("SnapOtter", "http://localhost:4538"),
    ("ImgCompress", "http://localhost:4539"),
    ("SonarQube", "http://localhost:4544"),
    ("Meilisearch", "http://localhost:4545"),
    ("Keycloak", "http://localhost:4546"),
    ("Loki", "http://localhost:4547"),
    ("Tempo", "http://localhost:4548"),
    ("OpenVAS", "http://localhost:9392"),
    ("Dashboard", "http://localhost"),
];

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
/// Handles both output shapes docker has used: NDJSON (one object per line)
/// and a single JSON array.
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
    let text = String::from_utf8_lossy(&out.stdout);
    let mut list: Vec<ContainerInfo> = text
        .lines()
        .filter(|l| !l.trim().is_empty())
        .filter_map(|l| serde_json::from_str::<ContainerInfo>(l).ok())
        .collect();
    if list.is_empty() {
        if let Ok(v) = serde_json::from_str::<Vec<ContainerInfo>>(&text) {
            list = v;
        }
    }
    Ok(list)
}

/// Run the `lds` CLI with the given arguments, capturing combined output.
/// Windows → `cmd /C lds.bat …`, Unix → `bash lds.sh …`. Errors on non-zero exit.
fn run_lds(args: &[&str]) -> Result<String, String> {
    let root = repo_root();
    let output = if cfg!(windows) {
        Command::new("cmd")
            .arg("/C")
            .arg("lds.bat")
            .args(args)
            .current_dir(&root)
            .output()
    } else {
        Command::new("bash")
            .arg(root.join("lds.sh"))
            .args(args)
            .current_dir(&root)
            .output()
    }
    .map_err(|e| format!("failed to run lds: {e}"))?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    let combined = format!("{stdout}{stderr}");
    if output.status.success() {
        Ok(combined)
    } else {
        Err(format!(
            "lds exited with {:?}:\n{combined}",
            output.status.code()
        ))
    }
}

/// Run a blocking closure off the UI thread, awaiting its result.
/// (dioxus 0.7 dropped `spawn_blocking` from the prelude — std thread + oneshot.)
async fn run_blocking<T: Send + 'static>(
    f: impl FnOnce() -> T + Send + 'static,
) -> Result<T, String> {
    let (tx, rx) = tokio::sync::oneshot::channel();
    std::thread::spawn(move || {
        let _ = tx.send(f());
    });
    rx.await.map_err(|_| "blocking worker exited".to_string())
}

/// Run `lds …` off the UI thread and append the result to the Output tab.
fn run_lds_logged(args: Vec<String>, mut output: Signal<String>) {
    output.write().push_str(&format!("$ lds {}\n", args.join(" ")));
    spawn(async move {
        let res = run_blocking(move || {
            let refs: Vec<&str> = args.iter().map(String::as_str).collect();
            run_lds(&refs)
        })
        .await;
        match res {
            Ok(Ok(s)) => output.write().push_str(&s),
            Ok(Err(e)) | Err(e) => output.write().push_str(&format!("ERROR: {e}\n")),
        }
    });
}

/// Rewrite the hosts file via `lds hosts-sync`. On Windows this relaunches
/// the bat through an elevated cmd (UAC prompt); on Unix it runs directly.
fn hosts_sync() -> Result<String, String> {
    let root = repo_root();
    if cfg!(windows) {
        let ps = format!(
            "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c','lds.bat hosts-sync' \
             -WorkingDirectory '{}' -Verb RunAs -Wait",
            root.display()
        );
        let output = Command::new("powershell")
            .arg("-NoProfile")
            .arg("-ExecutionPolicy")
            .arg("Bypass")
            .arg("-Command")
            .arg(&ps)
            .output()
            .map_err(|e| format!("failed to launch elevated hosts-sync: {e}"))?;
        if output.status.success() {
            Ok("hosts-sync completed (elevated).".to_string())
        } else {
            Err(format!(
                "hosts-sync failed (was the UAC prompt declined?):\n{}",
                String::from_utf8_lossy(&output.stderr)
            ))
        }
    } else {
        run_lds(&["hosts-sync"])
    }
}

/// One-shot log tail (`docker compose logs --tail N <service>`).
fn tail_logs(service: &str, lines: usize) -> Result<String, String> {
    let root = repo_root();
    let out = Command::new("docker")
        .args([
            "compose",
            "logs",
            "--tail",
            &lines.to_string(),
            "--no-color",
            service,
        ])
        .current_dir(&root)
        .output()
        .map_err(|e| format!("failed to run docker: {e}"))?;
    let stdout = String::from_utf8_lossy(&out.stdout);
    let stderr = String::from_utf8_lossy(&out.stderr);
    let combined = format!("{stdout}{stderr}");
    if out.status.success() {
        Ok(combined)
    } else {
        Err(combined)
    }
}

/// Start the live log stream child; a reader thread pushes lines into LOG_BUF.
fn start_log_stream(service: &str, lines: usize) -> Result<(), String> {
    stop_log_stream();
    let root = repo_root();
    let mut child = Command::new("docker")
        .args([
            "compose",
            "logs",
            "--follow",
            "--no-color",
            "--tail",
            &lines.to_string(),
            service,
        ])
        .current_dir(&root)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("failed to start log stream: {e}"))?;
    let stdout = child.stdout.take().ok_or("no stdout pipe")?;
    let mut stderr = child.stderr.take().ok_or("no stderr pipe")?;
    *LOG_STREAM.lock().unwrap() = Some(child);
    std::thread::spawn(move || {
        for line in BufReader::new(stdout).lines().map_while(Result::ok) {
            LOG_BUF.lock().unwrap().push(line);
        }
        let _ = std::io::copy(&mut stderr, &mut std::io::sink());
        LOG_BUF.lock().unwrap().push("[log stream ended]".into());
    });
    Ok(())
}

/// Kill the live log stream child (Stop button / tray Quit).
fn stop_log_stream() {
    if let Some(mut child) = LOG_STREAM.lock().unwrap().take() {
        let _ = child.kill();
    }
}

/// Open a URL in the system browser (tool cards).
fn open_url(url: &str) -> Result<(), String> {
    let mut cmd = if cfg!(windows) {
        let mut c = Command::new("cmd");
        c.arg("/C").arg("start").arg("").arg(url);
        c
    } else if cfg!(target_os = "macos") {
        let mut c = Command::new("open");
        c.arg(url);
        c
    } else {
        let mut c = Command::new("xdg-open");
        c.arg(url);
        c
    };
    cmd.spawn()
        .map(|_| ())
        .map_err(|e| format!("failed to open {url}: {e}"))
}

/// Current wall-clock time as HH:MM:SS (UTC) — the "updated" stamp.
fn utc_hms() -> String {
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    format!("{:02}:{:02}:{:02}", (secs / 3600) % 24, (secs / 60) % 60, secs % 60)
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
                .with_title("LDS Desktop — Dioxus")
                .with_inner_size(LogicalSize::new(1080.0, 720.0)),
        )
        // Closing the panel must NOT kill the app: the tray keeps it alive.
        .with_exits_when_last_window_closes(false)
        // Left-clicking the tray icon shows + focuses the panel again.
        .with_tray_icon_show_window_on_click(true);

    dioxus::LaunchBuilder::new().with_cfg(cfg).launch(App);
}

#[allow(non_snake_case)] // dioxus components are PascalCase by convention
fn App() -> Element {
    let mut containers = use_signal(Vec::<ContainerInfo>::new);
    let mut error = use_signal(String::new);
    let mut updated = use_signal(String::new);
    let mut auto_refresh = use_signal(|| true);
    let mut tab = use_signal(|| "lifecycle");
    let mut output = use_signal(String::new);
    let mut logs = use_signal(String::new);
    let mut streaming = use_signal(|| false);
    let mut scan_path = use_signal(String::new);
    let mut service_input = use_signal(|| "redis".to_string());
    let mut lines_input = use_signal(|| "200".to_string());
    let mut custom_profile = use_signal(String::new);
    let mut profiles_on = use_signal(HashSet::<String>::new);

    // --- Tray icon + context menu (muda), built once ------------------------
    // use_effect re-runs on every render, so guard with a signal. The built
    // TrayIcon is leaked on purpose: if dropped, the icon vanishes (and a
    // TrayIcon is !Send, so it can't live in a Signal).
    let mut tray_ready = use_signal(|| false);
    use_effect(move || {
        if !*tray_ready.read() {
            let menu = Menu::new();
            let open = MenuItem::with_id("open", "Open LDS Desktop", true, None);
            let start_all = MenuItem::with_id("start_all", "Start all profiles", true, None);
            let stop_all = MenuItem::with_id("stop_all", "Stop all", true, None);
            let sep = PredefinedMenuItem::separator();
            let refresh = MenuItem::with_id("refresh", "Refresh status", true, None);
            let quit = MenuItem::with_id("quit", "Quit", true, None);
            menu.append(&open).expect("append");
            menu.append(&start_all).expect("append");
            menu.append(&stop_all).expect("append");
            menu.append(&sep).expect("append");
            menu.append(&refresh).expect("append");
            menu.append(&quit).expect("append");

            let icon = Icon::from_rgba(tray_icon_rgba(), 32, 32).expect("icon");

            let tray = TrayIconBuilder::new()
                .with_menu(Box::new(menu))
                .with_icon(icon)
                .with_tooltip("LDS Desktop (Dioxus)")
                .build()
                .expect("tray icon");
            Box::leak(Box::new(tray));
            tray_ready.set(true);
        }
    });

    // --- Tray menu events ---------------------------------------------------
    use_tray_menu_event_handler(move |event| match event.id.as_ref() {
        "open" => OPEN_WINDOW.store(true, Ordering::Relaxed),
        "start_all" => {
            std::thread::spawn(|| {
                let _ = run_lds(&["up", "all"]);
            });
        }
        "stop_all" => {
            std::thread::spawn(|| {
                let _ = run_lds(&["down"]);
            });
        }
        "refresh" => REFRESH.store(true, Ordering::Relaxed),
        "quit" => {
            stop_log_stream();
            std::process::exit(0);
        }
        _ => {}
    });

    // --- Tray "Open" watcher: re-show + focus the panel window --------------
    let ctx = use_window();
    use_future(move || {
        let ctx = ctx.clone();
        async move {
            loop {
                if OPEN_WINDOW.swap(false, Ordering::Relaxed) {
                    ctx.set_visible(true);
                    ctx.set_focus();
                }
                tokio::time::sleep(Duration::from_millis(100)).await;
            }
        }
    });

    // --- Live status poll: every 5s (or immediately when the tray says so) --
    use_future(move || async move {
        loop {
            if *auto_refresh.read() || REFRESH.swap(false, Ordering::Relaxed) {
                match run_blocking(stack_status).await {
                    Ok(Ok(list)) => {
                        containers.set(list);
                        error.set(String::new());
                        updated.set(utc_hms());
                    }
                    Ok(Err(e)) | Err(e) => error.set(e),
                }
            }
            tokio::time::sleep(Duration::from_secs(5)).await;
        }
    });

    // --- Log stream drain: move lines from LOG_BUF into the logs signal ----
    use_future(move || async move {
        loop {
            let batch: Vec<String> = {
                let mut buf = LOG_BUF.lock().unwrap();
                std::mem::take(&mut *buf)
            };
            if !batch.is_empty() {
                let mut text = logs.write();
                for line in batch {
                    text.push_str(&line);
                    text.push('\n');
                }
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
    });

    let lifecycle_btn = move |label: &'static str, args: &'static [&'static str]| {
        let owned: Vec<String> = args.iter().map(|s| s.to_string()).collect();
        rsx! {
            button {
                style: "padding: 6px 10px; border-radius: 6px; border: 1px solid #cbd5e1; background: #f8fafc; cursor: pointer;",
                onclick: move |_| run_lds_logged(owned.clone(), output),
                "{label}"
            }
        }
    };

    let tab_btn = move |id: &'static str, label: &'static str| {
        let active = *tab.read() == id;
        rsx! {
            button {
                style: if active {
                    "padding: 6px 12px; border-radius: 6px 6px 0 0; border: 1px solid #cbd5e1; border-bottom: none; background: #fff; font-weight: 600; cursor: pointer;"
                } else {
                    "padding: 6px 12px; border-radius: 6px 6px 0 0; border: 1px solid transparent; background: #e2e8f0; cursor: pointer; color: #475569;"
                },
                onclick: move |_| tab.set(id),
                "{label}"
            }
        }
    };

    // Precomputed outside the rsx! (nested braces break the text macro).
    let auto_label = if *auto_refresh.read() { "ON" } else { "OFF" };

    rsx! {
        div {
            style: "font-family: system-ui, sans-serif; padding: 12px; display: flex; flex-direction: column; gap: 10px; height: 100vh; box-sizing: border-box;",
            header {
                style: "display: flex; align-items: center; gap: 8px; flex-wrap: wrap;",
                h1 { style: "font-size: 16px; margin: 0 12px 0 0;", "LDS Desktop — Dioxus" }
                button {
                    style: "padding: 5px 10px; border-radius: 6px; border: 1px solid #cbd5e1; background: #f8fafc; cursor: pointer;",
                    onclick: move |_| {
                        output.write().push_str("$ lds hosts-sync\n");
                        spawn(async move {
                            match run_blocking(hosts_sync).await {
                                Ok(Ok(s)) => output.write().push_str(&format!("{s}\n")),
                                Ok(Err(e)) | Err(e) => output.write().push_str(&format!("ERROR: {e}\n")),
                            }
                        });
                    },
                    "hosts-sync"
                }
                button {
                    style: "padding: 5px 10px; border-radius: 6px; border: 1px solid #cbd5e1; background: #f8fafc; cursor: pointer;",
                    onclick: move |_| run_lds_logged(vec!["up".into(), "all".into()], output),
                    "Start all"
                }
                button {
                    style: "padding: 5px 10px; border-radius: 6px; border: 1px solid #cbd5e1; background: #f8fafc; cursor: pointer;",
                    onclick: move |_| run_lds_logged(vec!["down".into()], output),
                    "Stop all"
                }
                button {
                    style: "padding: 5px 10px; border-radius: 6px; border: 1px solid #cbd5e1; background: #f8fafc; cursor: pointer;",
                    onclick: move |_| {
                        let mut c = containers.clone();
                        let mut e = error.clone();
                        let mut u = updated.clone();
                        spawn(async move {
                            match run_blocking(stack_status).await {
                                Ok(Ok(list)) => { c.set(list); e.set(String::new()); u.set(utc_hms()); }
                                Ok(Err(err)) | Err(err) => e.set(err),
                            }
                        });
                    },
                    "⟳ Refresh"
                }
                button {
                    style: if *auto_refresh.read() {
                        "padding: 5px 10px; border-radius: 6px; border: 1px solid #0c4a6e; background: #0c4a6e; color: white; cursor: pointer;"
                    } else {
                        "padding: 5px 10px; border-radius: 6px; border: 1px solid #cbd5e1; background: #f8fafc; cursor: pointer;"
                    },
                    onclick: move |_| {
                        let cur = *auto_refresh.read();
                        auto_refresh.set(!cur);
                    },
                    "Auto-refresh: {auto_label}"
                }
                span {
                    style: "margin-left: auto; font-size: 11px; color: #94a3b8;",
                    "updated {updated}"
                }
            }
            if !error.read().is_empty() {
                div { style: "color: #b00020; font-size: 12px;", "{error}" }
            }
            div { style: "display: flex; gap: 4px;",
                {tab_btn("lifecycle", "Lifecycle")}
                {tab_btn("profiles", "Profiles")}
                {tab_btn("tools", "Tools")}
                {tab_btn("containers", "Containers")}
                {tab_btn("logs", "Logs")}
                {tab_btn("output", "Output")}
            }
            div {
                style: "flex: 1; overflow: auto; border: 1px solid #cbd5e1; border-radius: 0 6px 6px 6px; padding: 10px;",

                if *tab.read() == "lifecycle" {
                    div { style: "display: flex; gap: 8px; flex-wrap: wrap;",
                        {lifecycle_btn("lds start", &["start"])}
                        {lifecycle_btn("lds stop", &["stop"])}
                        {lifecycle_btn("lds down", &["down"])}
                        {lifecycle_btn("lds ps", &["ps"])}
                        {lifecycle_btn("lds logs", &["logs"])}
                        {lifecycle_btn("certs", &["certs"])}
                        {lifecycle_btn("db init all", &["db", "init", "all"])}
                        {lifecycle_btn("sonar", &["sonar"])}
                        {lifecycle_btn("openvas start", &["openvas", "start"])}
                        {lifecycle_btn("openvas stop", &["openvas", "stop"])}
                        {lifecycle_btn("backup", &["backup"])}
                    }
                } else if *tab.read() == "profiles" {
                    div { style: "display: flex; gap: 6px; flex-wrap: wrap;",
                        for p in PROFILES.iter() {
                            button {
                                key: "{p}",
                                style: if profiles_on.read().contains(*p) {
                                    "padding: 5px 10px; border-radius: 999px; border: 1px solid #0c4a6e; background: #0c4a6e; color: white; cursor: pointer;"
                                } else {
                                    "padding: 5px 10px; border-radius: 999px; border: 1px solid #cbd5e1; background: #f8fafc; cursor: pointer;"
                                },
                                onclick: move |_| {
                                    let name = p.to_string();
                                    let mut set = profiles_on.read().clone();
                                    let op = if set.contains(&name) {
                                        set.remove(&name);
                                        "down"
                                    } else {
                                        set.insert(name.clone());
                                        "up"
                                    };
                                    profiles_on.set(set);
                                    run_lds_logged(vec![op.into(), name], output);
                                },
                                "{p}"
                            }
                        }
                    }
                    div { style: "display: flex; gap: 8px; margin-top: 10px; align-items: center;",
                        input {
                            r#type: "text",
                            placeholder: "custom profile",
                            style: "padding: 5px 8px; border: 1px solid #cbd5e1; border-radius: 6px; min-width: 200px;",
                            oninput: move |evt| custom_profile.set(evt.value()),
                        }
                        button {
                            style: "padding: 5px 10px; border-radius: 6px; border: 1px solid #cbd5e1; background: #f8fafc; cursor: pointer;",
                            onclick: move |_| {
                                let p = custom_profile.read().trim().to_string();
                                if !p.is_empty() {
                                    run_lds_logged(vec!["up".into(), p], output);
                                }
                            },
                            "Up"
                        }
                        button {
                            style: "padding: 5px 10px; border-radius: 6px; border: 1px solid #cbd5e1; background: #f8fafc; cursor: pointer;",
                            onclick: move |_| {
                                let p = custom_profile.read().trim().to_string();
                                if !p.is_empty() {
                                    run_lds_logged(vec!["down".into(), p], output);
                                }
                            },
                            "Down"
                        }
                    }
                } else if *tab.read() == "tools" {
                    div { style: "display: flex; gap: 8px; align-items: center; margin-bottom: 12px;",
                        span { style: "font-size: 13px; color: #475569;", "lds tools:" }
                        input {
                            r#type: "text",
                            placeholder: "path to scan (project dir)",
                            style: "flex: 1; padding: 5px 8px; border: 1px solid #cbd5e1; border-radius: 6px;",
                            oninput: move |evt| scan_path.set(evt.value()),
                        }
                        for tool in ["semgrep", "trivy", "crg"] {
                            button {
                                key: "{tool}",
                                style: "padding: 5px 10px; border-radius: 6px; border: 1px solid #0c4a6e; background: #0c4a6e; color: white; cursor: pointer;",
                                onclick: move |_| {
                                    let p = scan_path.read().trim().to_string();
                                    if p.is_empty() {
                                        output.write().push_str(&format!(
                                            "$ lds tools {tool} <path>\nERROR: enter a path to scan.\n"
                                        ));
                                        return;
                                    }
                                    run_lds_logged(vec!["tools".into(), tool.into(), p], output);
                                },
                                "{tool}"
                            }
                        }
                    }
                    div { style: "display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 8px;",
                        for (name, url) in TOOLS {
                            button {
                                key: "{name}",
                                style: "text-align: left; padding: 8px 10px; border-radius: 6px; border: 1px solid #cbd5e1; background: #f8fafc; cursor: pointer;",
                                onclick: move |_| {
                                    let u = url.to_string();
                                    spawn(async move {
                                        let _ = run_blocking(move || open_url(&u)).await;
                                    });
                                },
                                div { style: "font-weight: 600; font-size: 13px;", "{name}" }
                                div { style: "font-size: 11px; color: #64748b;", "{url}" }
                            }
                        }
                    }
                } else if *tab.read() == "containers" {
                    table {
                        style: "width: 100%; border-collapse: collapse; font-size: 13px;",
                        thead {
                            tr {
                                th { style: "text-align: left; padding: 6px 8px; border-bottom: 2px solid #ddd;", "Service" }
                                th { style: "text-align: left; padding: 6px 8px; border-bottom: 2px solid #ddd;", "Container" }
                                th { style: "text-align: left; padding: 6px 8px; border-bottom: 2px solid #ddd;", "State" }
                                th { style: "text-align: left; padding: 6px 8px; border-bottom: 2px solid #ddd;", "Health" }
                                th { style: "text-align: left; padding: 6px 8px; border-bottom: 2px solid #ddd;", "Status" }
                            }
                        }
                        tbody {
                            for c in containers.read().iter() {
                                tr {
                                    key: "{c.name}",
                                    td { style: "padding: 4px 8px; border-bottom: 1px solid #eee;", "{c.service}" }
                                    td { style: "padding: 4px 8px; border-bottom: 1px solid #eee;", "{c.name}" }
                                    td { style: "padding: 4px 8px; border-bottom: 1px solid #eee;", "{c.state}" }
                                    td { style: "padding: 4px 8px; border-bottom: 1px solid #eee;", "{c.health}" }
                                    td { style: "padding: 4px 8px; border-bottom: 1px solid #eee;", "{c.status}" }
                                }
                            }
                        }
                    }
                } else if *tab.read() == "logs" {
                    div { style: "display: flex; gap: 8px; align-items: center; margin-bottom: 8px; flex-wrap: wrap;",
                        input {
                            r#type: "text",
                            style: "padding: 5px 8px; border: 1px solid #cbd5e1; border-radius: 6px; width: 140px;",
                            value: "{service_input}",
                            oninput: move |evt| service_input.set(evt.value()),
                        }
                        input {
                            r#type: "text",
                            style: "padding: 5px 8px; border: 1px solid #cbd5e1; border-radius: 6px; width: 70px;",
                            value: "{lines_input}",
                            oninput: move |evt| lines_input.set(evt.value()),
                        }
                        button {
                            style: if *streaming.read() {
                                "padding: 5px 10px; border-radius: 6px; border: 1px solid #64748b; background: #64748b; color: white; cursor: not-allowed;"
                            } else {
                                "padding: 5px 10px; border-radius: 6px; border: 1px solid #0c4a6e; background: #0c4a6e; color: white; cursor: pointer;"
                            },
                            disabled: *streaming.read(),
                            onclick: move |_| {
                                let svc = service_input.read().trim().to_string();
                                let n = lines_input.read().trim().parse::<usize>().unwrap_or(200);
                                match start_log_stream(&svc, n) {
                                    Ok(()) => {
                                        streaming.set(true);
                                        logs.write().push_str(&format!(
                                            "[streaming docker compose logs --follow {svc}]\n"
                                        ));
                                    }
                                    Err(e) => logs.write().push_str(&format!("ERROR: {e}\n")),
                                }
                            },
                            if *streaming.read() { "Streaming…" } else { "Stream" }
                        }
                        button {
                            style: "padding: 5px 10px; border-radius: 6px; border: 1px solid #cbd5e1; background: #f8fafc; cursor: pointer;",
                            disabled: !*streaming.read(),
                            onclick: move |_| {
                                stop_log_stream();
                                streaming.set(false);
                            },
                            "Stop"
                        }
                        button {
                            style: "padding: 5px 10px; border-radius: 6px; border: 1px solid #cbd5e1; background: #f8fafc; cursor: pointer;",
                            onclick: move |_| {
                                let svc = service_input.read().trim().to_string();
                                let n = lines_input.read().trim().parse::<usize>().unwrap_or(200);
                                let mut lg = logs;
                                spawn(async move {
                                    match run_blocking(move || tail_logs(&svc, n)).await {
                                        Ok(Ok(s)) => lg.write().push_str(&format!("{s}\n")),
                                        Ok(Err(e)) | Err(e) => lg.write().push_str(&format!("ERROR: {e}\n")),
                                    }
                                });
                            },
                            "Tail"
                        }
                        button {
                            style: "padding: 5px 10px; border-radius: 6px; border: 1px solid #cbd5e1; background: #f8fafc; cursor: pointer;",
                            onclick: move |_| logs.set(String::new()),
                            "Clear"
                        }
                    }
                    pre {
                        style: "flex: 1; overflow: auto; background: #0f172a; color: #e2e8f0; padding: 10px; border-radius: 6px; font-size: 12px; margin: 0; min-height: 0;",
                        "{logs}"
                    }
                } else {
                    div { style: "display: flex; flex-direction: column; height: 100%; gap: 8px;",
                        pre {
                            style: "flex: 1; overflow: auto; background: #0f172a; color: #e2e8f0; padding: 10px; border-radius: 6px; font-size: 12px; margin: 0; min-height: 0;",
                            "{output}"
                        }
                        button {
                            style: "align-self: flex-end; padding: 5px 10px; border-radius: 6px; border: 1px solid #cbd5e1; background: #f8fafc; cursor: pointer;",
                            onclick: move |_| output.set(String::new()),
                            "Clear"
                        }
                    }
                }
            }
            footer { style: "font-size: 11px; color: #888;",
                "Close hides to tray (Quit from the tray exits) · auto-refresh every 5s · the lds CLI is the single source of truth"
            }
        }
    }
}
