//! LDS Desktop — a thin Rust/Tauri shell over the local-dev-stack `lds` CLI.
//!
//! Design principles:
//! * The `lds` CLI (lds.sh / lds.bat) stays the single source of truth — this
//!   app only *invokes* it. All Docker orchestration, DB init, and proxies
//!   remain in the repo's scripts.
//! * Long-running commands run on a blocking thread so the UI never freezes.
//! * The frontend is a static `ui/` folder (no bundler) talking to these
//!   commands via `invoke`.

use serde::{Deserialize, Serialize};
use std::io::{BufRead, BufReader};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::Mutex;
use tauri::menu::{Menu, MenuItem};
use tauri::tray::TrayIconBuilder;
use tauri::{AppHandle, Emitter, Manager, State};

/// Repo root: walk up from this crate (`<root>/desktop/tauri/src-tauri`) until
/// we find `lds.bat` / `lds.sh` — robust to the folder being moved deeper.
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

// ---------------------------------------------------------------------------
// Commands (invoked from the UI via window.__TAURI__.core.invoke)
// ---------------------------------------------------------------------------

/// Generic lds CLI bridge: `lds_run { args: ["up", "duckdb"] }`.
#[tauri::command(rename_all = "snake_case")]
async fn lds_run(args: Vec<String>) -> Result<String, String> {
    tauri::async_runtime::spawn_blocking(move || {
        let strs: Vec<&str> = args.iter().map(String::as_str).collect();
        run_lds(&strs)
    })
    .await
    .map_err(|e| e.to_string())?
}

/// One row of `docker compose ps --format json`.
#[derive(Deserialize, Serialize, Debug)]
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

/// Live status of every LDS container (`docker compose --profile '*' ps`).
#[tauri::command(rename_all = "snake_case")]
async fn stack_status() -> Result<Vec<ContainerInfo>, String> {
    let root = repo_root();
    let output = Command::new("docker")
        .args(["compose", "--profile", "*", "ps", "--format", "json"])
        .current_dir(&root)
        .output()
        .map_err(|e| format!("failed to run docker: {e}"))?;
    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).to_string());
    }
    serde_json::from_slice(&output.stdout).map_err(|e| format!("failed to parse docker output: {e}"))
}

/// Tail logs for a compose service, e.g. `service_logs { service: "redis" }`.
#[tauri::command(rename_all = "snake_case")]
async fn service_logs(service: String, lines: Option<u32>) -> Result<String, String> {
    let n = lines.unwrap_or(200).to_string();
    let root = repo_root();
    let output = Command::new("docker")
        .arg("compose")
        .arg("logs")
        .arg("--tail")
        .arg(&n)
        .arg(&service)
        .current_dir(&root)
        .output()
        .map_err(|e| format!("failed to run docker: {e}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    Ok(format!("{stdout}{stderr}"))
}

/// Managed state: the live `docker compose logs -f` child process, if any.
/// Kept so the UI can stop the stream and so the app can kill it on exit.
#[derive(Default)]
struct AppState {
    log_stream: Mutex<Option<Child>>,
}

fn stop_current_stream(state: &State<'_, AppState>) {
    if let Ok(mut guard) = state.log_stream.lock() {
        if let Some(mut child) = guard.take() {
            let _ = child.kill();
            let _ = child.wait();
        }
    }
}

/// Start a **live** log stream: `docker compose logs --tail N --follow <service>`.
///
/// Output is pushed to the UI as `log-chunk` events (one per line, both stdout
/// and stderr); a `log-stream-end` event fires when the stream closes. Only one
/// stream can run at a time — starting a new one stops the previous. The child
/// process is kept in [`AppState`] so `stop_log_stream` / app exit can kill it.
#[tauri::command(rename_all = "snake_case")]
async fn stream_logs(
    app: AppHandle,
    state: State<'_, AppState>,
    service: String,
    lines: Option<u32>,
) -> Result<(), String> {
    stop_current_stream(&state);

    let n = lines.unwrap_or(200).to_string();
    let root = repo_root();
    let mut child = Command::new("docker")
        .args(["compose", "logs", "--tail"])
        .arg(&n)
        .arg("--follow")
        .arg(&service)
        .current_dir(&root)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("failed to start docker logs: {e}"))?;

    let stdout = child.stdout.take().expect("stdout is piped");
    let stderr = child.stderr.take().expect("stderr is piped");

    // stdout reader — streams container log lines to the UI.
    let out_handle = app.clone();
    tauri::async_runtime::spawn_blocking(move || {
        let mut reader = BufReader::new(stdout);
        let mut line = String::new();
        loop {
            line.clear();
            match reader.read_line(&mut line) {
                Ok(0) => break,
                Ok(_) => {
                    let _ = out_handle.emit("log-chunk", line.clone());
                }
                Err(_) => break,
            }
        }
    });

    // stderr reader — captures errors (e.g. unknown service) and signals end
    // once the process exits and both pipes close.
    let err_handle = app.clone();
    let svc = service.clone();
    tauri::async_runtime::spawn_blocking(move || {
        let mut reader = BufReader::new(stderr);
        let mut line = String::new();
        loop {
            line.clear();
            match reader.read_line(&mut line) {
                Ok(0) => break,
                Ok(_) => {
                    let _ = err_handle.emit("log-chunk", line.clone());
                }
                Err(_) => break,
            }
        }
        let _ = err_handle.emit("log-stream-end", svc);
    });

    *state
        .log_stream
        .lock()
        .map_err(|e| format!("state poisoned: {e}"))? = Some(child);
    Ok(())
}

/// Stop the live log stream (kills the `docker compose logs -f` child).
#[tauri::command(rename_all = "snake_case")]
async fn stop_log_stream(state: State<'_, AppState>) -> Result<(), String> {
    stop_current_stream(&state);
    Ok(())
}

/// Open a URL in the system browser (used by the tool cards).
#[tauri::command(rename_all = "snake_case")]
fn open_url(url: String) -> Result<(), String> {        let mut cmd = if cfg!(windows) {
        let mut c = Command::new("cmd");
        c.arg("/C").arg("start").arg("").arg(&url);
        c
    } else if cfg!(target_os = "macos") {
        let mut c = Command::new("open");
        c.arg(&url);
        c
    } else {
        let mut c = Command::new("xdg-open");
        c.arg(&url);
        c
    };
    cmd.spawn()
        .map(|_| ())
        .map_err(|e| format!("failed to open {url}: {e}"))
}

/// Rewrite the hosts file via `lds hosts-sync`.
/// On Windows this relaunches the bat through an elevated cmd (UAC prompt);
/// on Unix it runs the CLI directly (needs passwordless sudo or a root shell).
#[tauri::command(rename_all = "snake_case")]
async fn hosts_sync() -> Result<String, String> {
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

// ---------------------------------------------------------------------------
// Tray icon
// ---------------------------------------------------------------------------

fn setup_tray(app: &tauri::App) -> tauri::Result<()> {
    let open = MenuItem::with_id(app, "open", "Open LDS Desktop", true, None::<&str>)?;
    let start_all = MenuItem::with_id(app, "start_all", "Start all profiles", true, None::<&str>)?;
    let stop_all = MenuItem::with_id(app, "stop_all", "Stop all", true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;
    let menu = Menu::with_items(app, &[&open, &start_all, &stop_all, &quit])?;

    let mut builder = TrayIconBuilder::new()
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id.as_ref() {
            "open" => {
                if let Some(win) = app.get_webview_window("main") {
                    let _ = win.show();
                    let _ = win.set_focus();
                }
            }
            "start_all" => {
                let _ = tauri::async_runtime::spawn_blocking(|| run_lds(&["up", "all"]));
            }
            "stop_all" => {
                let _ = tauri::async_runtime::spawn_blocking(|| run_lds(&["down"]));
            }
            "quit" => app.exit(0),
            _ => {}
        });

    if let Some(icon) = app.default_window_icon() {
        builder = builder.icon(icon.clone());
    }

    builder.build(app)?;
    Ok(())
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let app = tauri::Builder::default()
        .manage(AppState::default())
        .setup(|app| {
            setup_tray(app)?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            lds_run,
            stack_status,
            service_logs,
            stream_logs,
            stop_log_stream,
            open_url,
            hosts_sync
        ])
        .build(tauri::generate_context!())
        .expect("error while building LDS Desktop");

    app.run(|app_handle, event| {
        // Kill any live log stream on exit so no `docker compose logs -f`
        // process is orphaned after the app closes.
        if let tauri::RunEvent::ExitRequested { .. } = event {
            if let Some(state) = app_handle.try_state::<AppState>() {
                stop_current_stream(&state);
            }
        }
    });
}
