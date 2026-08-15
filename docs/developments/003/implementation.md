# 003 · LDS Desktop — Auto-Refresh Status & Live Log Streaming — Implementation

**Date:** 2026-08-11
**Status:** ✅ Iteration 1 — A/B auto-refresh + live logs (Tauri + JavaFX compile-verified); ✅ Iteration 2 — variant C scaffolded + Laravel-13 fix + containerized build; ✅ Iteration 3 — cross-platform builds (`--os` / CI matrix / Tauri Windows `.exe` from a container); 🧪 Iteration 4 — Dioxus spike scaffolded + build-wired (compile-check pending a Docker Desktop restart)
**Type:** Implementation
**Planning:** [`planning.md`](./planning.md)

---

## Overview

The LDS Desktop panel (Tauri + JavaFX variants) previously showed the
container status table only on demand (once at startup + a manual Refresh
button) and offered one-shot log tails. Per the confirmed scope, this
iteration makes both **live**:

- the **status table auto-refreshes every 5 seconds** (toggleable, with a
  last-updated timestamp), so profile up/down and lifecycle actions show up
  without clicking Refresh;
- the **logs tab can live-follow a service** — `docker compose logs --tail N
  --follow <service>` — pushing each line to the panel as it arrives, with a
  Stop control.

Both variants keep the "thin shell over the `lds` CLI" design: no orchestration
logic moved into the app, only the status poll and the log stream.

---

## Implementation

### Shared behavior (both variants)

- **Auto-refresh:** poll `docker compose --profile '*' ps` every 5 s. A
  toggle (header checkbox/button, on by default) switches the timer; a
  "last updated" stamp is shown next to the status dot. Overlapping runs are
  dropped so a slow docker response never queues a backlog of refreshes.
- **Live logs:** start `docker compose logs --tail N --follow <service>`
  (N = the existing lines input, default 200), clear the pane, then append
  lines as they arrive with auto-scroll to the bottom. Starting a new stream
  (or switching service) stops the previous one; Stop kills the child. The
  tail (one-shot) and clear buttons stay available. A `[log stream ended]`
  marker is appended when the stream closes (service stops, unknown service,
  or Stop).
- **Cleanup:** the running stream child is killed on Stop **and** on app exit
  (Tauri: `RunEvent::ExitRequested`; JavaFX: JVM shutdown hook) so no
  `docker compose logs -f` process is orphaned.

### Variant A — Tauri (`desktop/tauri/`)

**Backend (`src-tauri/src/lib.rs`):**

- New managed state `AppState { log_stream: Mutex<Option<Child>> }`
  (`.manage(AppState::default())`).
- New commands:
  - `stream_logs(service, lines)` — kills any previous stream, spawns
    `docker compose logs --tail N --follow <service>` with piped stdout +
    stderr, and spawns two blocking readers that emit each line to the UI as
    a `log-chunk` event (`AppHandle::emit`, via the `Emitter` trait). When
    the process exits and the pipes close, a `log-stream-end` event fires.
  - `stop_log_stream()` — kills the child held in state.
- `run()` now builds the app, then runs with a `RunEvent::ExitRequested`
  handler that kills the live stream child on exit.

**Frontend (`ui/`):**

- `index.html` — header gains an `⟳ Auto` toggle button and a
  `#last-updated` span; the logs row gains **Stream** / **Stop** buttons
  beside the existing Tail/Clear.
- `main.js` — `setInterval(refreshStatus, 5000)` with start/stop helpers and
  a header toggle (on by default); `refreshStatus` stamps
  `#last-updated` with the local time. Log streaming uses
  `window.__TAURI__.event.listen` for `log-chunk` (append + autoscroll) and
  `log-stream-end` (reset buttons, append marker); Stream/Stop button states
  track the active stream; listeners are unregistered on stop/end.
- `styles.css` — `button.on` (green active toggle) and `.last-updated`.

### Variant B — JavaFX (`desktop/javafx/`)

**`LdsCli.java`:** new `streamLogs(service, lines)` returns the live
`Process` for `docker compose logs --tail N --follow <service>` (stderr
merged into stdout).

**`LdsDesktopApp.java`:**

- Header gains an **Auto-refresh** `CheckBox` (selected by default) and a
  last-updated `Label`.
- `startAutoRefresh()` runs a daemon `ScheduledExecutorService` that calls
  `refreshStatus()` every 5 s when the checkbox is on; `refreshStatus()` is
  guarded by an `AtomicBoolean` (overlapping runs dropped) and stamps the
  last-updated label.
- Logs tab gains **Stream** / **Stop** buttons. `startLogStream()` starts the
  process, reads its input on a daemon thread, and appends each line via
  `Platform.runLater` with `positionCaret(getLength())` for auto-scroll;
  `stopLogStream()` / `killLogStream()` destroy the child. A JVM shutdown
  hook kills the stream on exit.

### Base images — `lds/tauri-dev` / `lds/javafx-dev`

Both variants compile in **containerized base images** so no Rust/Maven is
needed on the host:

- `lds/tauri-dev` — `FROM lds/rust-dev:${RUST_VERSION}` + `webkit2gtk-4.1-dev`,
  `gtk+3.0-dev`, `libayatana-appindicator-dev`, `librsvg`, `patchelf`,
  desktop-file-utils, xdg-utils + `cargo install tauri-cli --locked`.
- `lds/javafx-dev` — `FROM lds/java-dev:${JAVA_VERSION}` + `gtk+3.0`,
  `fontconfig`, `font-noto`, X11 libs (`libx11`/`libxcomposite`/`libxrender`/
  `libxtst`/`libxi`), `mesa-gl`, `unzip` (OpenJFX jars come from Maven
  Central via the app's `pom.xml`).

Both are registered in `docker-bake.hcl` (added to the `default` group, built
with `lds build-bases` or `docker buildx bake tauri-dev javafx-dev`) and
driven by `desktop/build.sh` / `desktop/build.bat` (`desktop/build.sh tauri` →
cargo check + build; `desktop/build.sh javafx` → `mvn package`). Container
builds target Linux (compile verification + jar output); Windows installers
are produced on a Windows host from the same source tree.

---

## Files changed

| File | Change |
|:-----|:-------|
| `desktop/tauri/src-tauri/src/lib.rs` | `AppState`, `stream_logs`, `stop_log_stream`, kill-on-exit; compile fixes (`Serialize`, `mut child`, `'static` closure) |
| `desktop/tauri/ui/index.html` | Auto-refresh toggle + last-updated; Stream/Stop buttons |
| `desktop/tauri/ui/main.js` | 5 s auto-refresh, `log-chunk`/`log-stream-end` listeners, stream UI state |
| `desktop/tauri/ui/styles.css` | `button.on`, `.last-updated` |
| `desktop/javafx/src/main/java/com/localdevstack/lds/LdsCli.java` | `streamLogs()` |
| `desktop/javafx/src/main/java/com/localdevstack/lds/LdsDesktopApp.java` | Auto-refresh timer + toggle, live log streaming, shutdown hook |
| `desktop/README.md` | Feature list: auto-refresh + live logs |
| `desktop/tauri/README.md` | Command list + notes |
| `desktop/javafx/README.md` | Layout + notes |
| `docker-bake.hcl` | `tauri-dev` + `javafx-dev` targets + `default` group |
| `base-images/tauri-dev/Dockerfile` | rust-dev + webkit2gtk-4.1/GTK3 deps + tauri-cli |
| `base-images/javafx-dev/Dockerfile` | java-dev + GTK3/fontconfig/X11 runtime deps |
| `desktop/build.sh` / `build.bat` | Containerized build entrypoints (`tauri` / `javafx`) |
| `docs/developments/003/planning.md` | Auto-refresh + log streaming moved from §10 future → §3.1 scope |

---

## Verification

| Check | Result |
|:------|:-------|
| `mvn -q -DskipTests package` inside `lds/java-dev:25` (existing image — the documented container build path; produces `desktop/javafx/target/lds-desktop-javafx-0.1.0.jar`) | ✅ compiles clean, jar built |
| `docker buildx bake --load javafx-dev` | ✅ image built (`lds/javafx-dev:25`) |
| `desktop/build.sh javafx` (mvn package inside `lds/javafx-dev`) | ✅ `target/lds-desktop-javafx-0.1.0.jar` produced |
| `docker buildx bake --load tauri-dev` | ✅ `lds/tauri-dev:1.96` built (2.7 GB) — Alpine lcms2 mirror skew (dhi.io vs dl-cdn at different sync points) worked around by pinning `lcms2-plugins=2.19-r0`; `dbus-dev` layer added for `libdbus-sys` |
| Tauri Rust backend (`desktop/build.sh tauri`: cargo check + build) | ✅ `cargo check` clean; `cargo build` 6m02s → 174 MB musl Linux binary at `target/debug/lds-desktop` (3 Rust errors fixed — see notes) |
| `node --check desktop/tauri/ui/main.js` | ✅ JS syntax valid |
| `docker compose config --quiet` | ✅ compose untouched, still valid |
| Live run (status auto-refresh + streaming against a running stack) | ⏳ pending — requires running the desktop apps on the host |

---

## Notes / gotchas

- `docker compose logs -f` on a service that isn't running exits immediately —
  the error lands on stderr and is streamed as a `log-chunk`, so the user sees
  it instead of a silent hang; the `log-stream-end` event then resets the UI.
- Only one stream at a time (per variant): starting a new one stops the
  previous, and switching the service dropdown does the same implicitly.
- Auto-refresh is a cheap `ps` poll, so it runs even while a lifecycle command
  is busy; the overlap guard prevents queueing, not concurrent CLI work.
- **First container build attempt (user-run `desktop/build.bat`) surfaced three
  issues, all fixed:** (1) `USER app` in `tauri-dev`/`javafx-dev` was invalid —
  the LDS language bases run as root (no `app` user in `/etc/passwd`) → both
  Dockerfiles now `USER root`; (2) `build.bat` passed a literal `^` into the
  container's `sh -c` strings (`2>&1 ^| tail` inside quotes — caret is not an
  escape inside cmd quotes), breaking composer/npm → plain `|` inside the
  quoted commands, plus `|| exit /b 1` after each base-image bake; (3) the
  `lds/tauri-dev` apk step hit the Alpine mirror transition above.
- **Never use `--force-broken-world` in the tauri-dev Dockerfile**: it exits 0
  while silently skipping unresolvable `-dev` packages (verified), leaving an
  image that fails to compile with missing `.pc` files.
- **The Alpine lcms2 blocker was resolved with a pin, not a wait:** `dhi.io`
  and `dl-cdn` were serving different sync states of `lcms2[-dev|-plugins]`,
  so apk's merged index was unresolvable. Pinning `lcms2-plugins=2.19-r0` in
  the tauri-dev Dockerfile forces the consistent set (verified: 331 packages
  install cleanly). The pin is marked TEMPORARY — remove once the mirrors
  settle (`docker run --rm lds/rust-dev:1.96 apk add --simulate lcms2-dev
  lcms2-plugins` should then pass unpinned).
- **Tauri first compile surfaced three Rust errors in `lib.rs`, all fixed:**
  `ContainerInfo` lacked `Serialize` (tauri commands must return `Serialize`
  types) → added to the derive; `lds_run` borrowed `&str`s from `args` across
  `spawn_blocking`'s `'static` closure (E0597) → build the `Vec<&str>` inside
  the moved closure; `stream_logs`'s `Command` child needed `mut` for
  `stdout`/`stderr.take()` (E0596). After the fixes, check + build pass →
  174 MB musl Linux binary.

---

---

## Variant C — NativePHP (`desktop/nativephp/`) — Iteration 2

Scaffold + dependency fix + containerized build. The LDS panel logic itself is
**not implemented yet** (see planning §6): this iteration made the project
bootable, buildable, and documented its (v2) toolchain.

### What was built

- **Scaffold** — stock `composer create-project laravel/laravel` (Laravel
  13.24) + `nativephp/desktop ^2.2` + `php artisan native:install` (publishes
  `config/nativephp.php` + `NativeAppServiceProvider`). Migrations ran against
  `database/database.sqlite` (10 stock tables); PHP lint clean.
- **Fix: Laravel-13 command-name conflict.** `php artisan list` crashed with
  `The "native:migrate:fresh" command cannot be found because it is registered
  under multiple names.` Root cause: nativephp/desktop 2.2.1's `FreshCommand`
  declares an `#[AsCommand(name: 'native:migrate:fresh')]` attribute but
  inherits Laravel's `migrate:fresh …` `$signature`. Laravel registers the
  command lazily under the attribute name, but the instantiated command's real
  name comes from the signature — so the loader key never matches and
  Symfony's console refuses to resolve it. `WipeDatabaseCommand` had the
  reverse bug: its `$name` was ignored and it silently shadowed Laravel's
  `db:wipe`. Fix (the pattern `MigrateCommand` already uses): add a constructor
  that prepends `native:` to the inherited signature,
  `$this->signature = 'native:'.$this->signature;`.
- **Patch survives reinstalls** — cweagans/composer-patches (dev dep) +
  `extra.patches` in `composer.json` + `patches/nativephp-desktop-laravel13-commands.patch`
  + `patches.lock.json`; `composer reinstall nativephp/desktop` re-applies it.
- **Containerized build** — `lds/nativephp-dev` (FROM `lds/php:8.4` +
  `php8.4-sqlite3` + `patch`), registered in docker-bake.hcl (default group),
  and `desktop/build.sh|build.bat nativephp` → composer install + vite build +
  artisan check (a compile-check; per-OS installers build on the host).

### Files changed (iteration 2)

| File | Change |
|:-----|:-------|
| `desktop/nativephp/composer.json` | `nativephp/desktop ^2.2`; `extra.patches`; `cweagans/composer-patches` (dev) |
| `desktop/nativephp/composer.lock` | deps + content hash |
| `desktop/nativephp/patches/nativephp-desktop-laravel13-commands.patch` | FreshCommand + WipeDatabaseCommand signature fix |
| `desktop/nativephp/patches.lock.json` | applied-patch record |
| `desktop/nativephp/README.md` | stock Laravel boilerplate → variant C README (status, patch, v2 flow) |
| `base-images/nativephp-dev/Dockerfile` | `lds/php` + `php8.4-sqlite3` + `patch` |
| `docker-bake.hcl` | `nativephp-dev` target + default group |
| `desktop/build.sh` / `desktop/build.bat` | `nativephp` target |
| `desktop/README.md` | variant C row + containerized-build section |
| `docs/developments/003/planning.md` | §1/§6/§8/§9 — v2 flow, patch, status |

### Verification (iteration 2)

| Check | Result |
|:------|:-------|
| `php artisan list` | ✅ exit 0; 16 `native:*` / `bifrost:*` commands; `migrate:fresh`/`db:wipe` remain Laravel's own |
| `composer reinstall nativephp/desktop` (pristine vendor → patched) | ✅ patch re-applies; `composer validate` valid |
| `npm install` + `npm run build` | ✅ Vite build clean |
| `docker buildx bake --load nativephp-dev` | ✅ `lds/nativephp-dev:8.4` built |
| `desktop/build.sh nativephp` | ✅ composer install + vite build + `artisan list OK` inside the image |
| Live run (`native:run` / Electron) | ⏳ needs nativephp account (`bifrost:login`) + GUI — documented, not executed |

### Notes / gotchas (iteration 2)

- `native:dev` / `native:build` in the original planning are NativePHP **v1**.
  v2 CLI: `bifrost:init|login|download-bundle` + `native:run` (`native:serve`
  is its deprecated alias). Full flow in `desktop/nativephp/README.md`.
- The patch targets nativephp/desktop 2.2.1's file layout; if upstream ships a
  real fix, drop the `extra.patches` entry.
- Container root runs against the Windows bind mount are harmless (Docker
  Desktop maps ownership permissively).

---

## Iteration 3 — cross-platform (Windows / Linux / macOS) builds

Up to now the container builds were Linux compile-checks only. This iteration
made `desktop/build.sh` OS-aware and added the CI matrix that actually emits
Windows + Linux + macOS artifacts for every variant.

### The hard constraints (why a container can't do it all)

- **macOS artifacts can only be built on macOS** — Apple's toolchain (Xcode
  SDK, `hdiutil`, codesign) is required by jpackage (`dmg`), electron-builder
  (`mac` refuses non-mac hosts) and the Tauri bundler alike. No Linux/Windows
  container can emit a macOS build.
- **jpackage / electron-builder do not cross-package** — each produces
  installers for the OS it runs on. The containerized builds are therefore
  compile-checks (Tauri → musl Linux binary; JavaFX → jar + Linux app-image;
  NativePHP → composer/vite/artisan), and per-OS installers must come from a
  machine of that OS.
- The supported answer is a **build matrix**: 3 runners (ubuntu/windows/mac)
  × 3 variants, now in `.github/workflows/desktop-build.yml`.
- **One exception, proven here: the Tauri Rust backend cross-compiles to a
  real Windows `.exe` from a Linux container** (mingw-w64 + rustup windows
  target). JavaFX/NativePHP have no such path — their jars are
  cross-platform, but their installers need the native OS.

### Windows `.exe` from a Linux container (Tauri only)

Iteration 3 proved that `cargo build --target x86_64-pc-windows-gnu` inside a
Linux container emits a genuine PE32+ Windows binary — so the answer to
"can we build all 3 OSes in containers?" is **Linux ✅, Windows ✅ (Tauri),
macOS ❌ (impossible — Apple toolchain)**. That capability is now baked in:

- **`base-images/tauri-win-dev/Dockerfile`** (on-demand bake target
  `tauri-win-dev` — NOT in the `default` group; it's ~2.5 GB): layers
  mingw-w64 (`gcc`/`binutils`/`crt` — from upstream dl-cdn, the DHI apk
  mirror is curated and lacks mingw) + rustup with a pinned `1.97.1`
  toolchain carrying the `x86_64-pc-windows-gnu` std (the apk-installed
  rustc in rust-dev has no foreign std), plus a `windres` symlink for
  tauri-winres's non-Windows lookup.
- **`desktop/build.sh` / `build.bat`** — new `--container` flag:
  `desktop/build.sh tauri --os win --container` auto-builds the image on
  first run, then runs the cross-compile against the bind-mounted tree
  → `desktop/tauri/src-tauri/target/x86_64-pc-windows-gnu/debug/lds-desktop.exe`.
  Guardrails: `--os mac --container` refuses (mac needs native tooling);
  `javafx/nativephp --os win --container` refuses with the explanation that
  their jars are cross-platform but installers need the native OS.
- **`Cargo.toml` fix the cross-compile demanded** — dropped the `cdylib` from
  `crate-type`. The template's `staticlib/cdylib` pair exists for mobile
  embedding; on `x86_64-pc-windows-gnu`, mingw's `ld` dies on the export
  table for the whole tauri surface (`export ordinal too large: 92091`,
  ordinals cap at 65535). Desktop-only app → plain `rlib`.
- **Caveats:** raw `.exe` only — NSIS/MSI bundling (`cargo tauri build`) still
  needs Windows, and the `.exe` wants `WebView2Loader.dll` next to it at
  runtime (tauri's Windows requirement).

### What was built

- **`desktop/build.sh` / `build.bat` gained `--os linux|win|mac|auto`** —
  `--os linux` (default) keeps the containerized compile-checks; `--os win`
  / `--os mac` dispatch to the host toolchain and refuse with a CI pointer on
  the wrong OS; `auto` detects the host. Toolchain presence is checked
  (`cargo`/`mvn`/`php`) before running.
- **`desktop/javafx/package.sh`** — portable jpackage packager (mvn package →
  collect runtime deps into `target/jfxlib` → jpackage → `target/dist/`).
  Default `app-image` (self-contained folder, needs no system tools on any
  OS); `JPACKAGE_TYPE=exe|msi|dmg|deb` for real installers. Runs unchanged on
  all three CI runners (bash).
- **`lds/javafx-dev` gained `binutils` + `bash`** — jpackage's jlink step
  needs `objcopy` (binutils) to strip the runtime image, and `package.sh` is
  bash. Verified: `target/dist/LdsDesktop/` app-image (145 MB, own JRE) built
  in the container.
- **`.github/workflows/desktop-build.yml`** — 3×3 matrix:
  - **Tauri** — official `tauri-apps/tauri-action@v1` with per-OS `--bundles`
    (`nsis,msi` / `deb,appimage` / `app,dmg`), `uploadWorkflowArtifacts`.
  - **JavaFX** — `setup-java` 21 + `bash desktop/javafx/package.sh`, upload
    `target/dist/`.
  - **NativePHP** — `setup-php` (patch applies via composer-patches) + vite
    build + `php artisan native:build <os>` (unsecure path — no account
    needed; the bifrost bundle path needs nativephp credentials), upload
    `build/`.
  - Trigger: manual or on push touching `desktop/**`.

### Files changed (iteration 3)

| File | Change |
|:-----|:-------|
| `desktop/build.sh` / `desktop/build.bat` | `--os` flag; host win/mac dispatch + guardrails; `--container` flag + win cross-compile path; javafx now packages via `package.sh` |
| `desktop/javafx/package.sh` | new — portable jpackage packager (app-image / exe / msi / dmg / deb) |
| `base-images/javafx-dev/Dockerfile` | `binutils` (jpackage jlink) + `bash` |
| `base-images/tauri-win-dev/Dockerfile` | new — Tauri Windows cross-compile image (mingw-w64 + rustup `x86_64-pc-windows-gnu`), on-demand bake target |
| `docker-bake.hcl` | `tauri-win-dev` target (on-demand, not in the default group) |
| `desktop/tauri/src-tauri/Cargo.toml` | `crate-type` → `["rlib"]` (dropped `cdylib` — fixes `export ordinal too large` on windows-gnu) |
| `.github/workflows/desktop-build.yml` | new — 3 OS × 3 variant build matrix with artifact upload |
| `desktop/javafx/pom.xml` | comment noting packaging lives in `package.sh` (tried `org.panteleyev:jpackage-maven-plugin` 1.6.1 — fails on modern Maven: missing `maven-shared-utils` class) |
| `desktop/README.md` + `desktop/tauri/README.md` | `--os` / `--container` + CI matrix + cross-OS capability table docs |

### Verification (iteration 3)

| Check | Result |
|:------|:-------|
| `bash desktop/build.sh javafx --os linux` (container) | ✅ jar + `target/dist/LdsDesktop/` app-image (145 MB, launcher present) |
| `bash -n` on `build.sh` + `package.sh`; workflow YAML parsed | ✅ valid |
| `bash desktop/build.sh tauri --os mac` (on Windows host) | ✅ guardrail: refuses + points at the CI matrix |
| `bash desktop/build.sh tauri --os win --container` | ✅ full flow: image auto-built, cargo cross-compile → **`lds-desktop.exe` — PE32+ MS Windows x86-64, 22 sections (213 MB)** |
| `bash desktop/build.sh tauri --os mac --container` | ✅ guardrail: refuses (mac needs native toolchain) |
| `javafx --os win --container` | ✅ guardrail: refuses + explains jar-is-cross-platform / installer-needs-Windows |
| `bash desktop/build.bat tauri --os win --container` (real cmd) | ✅ bat parses + reaches the same cross-compile path |
| Tauri host build (`cargo tauri build` on Windows/macOS) | ⏳ requires a Rust toolchain on a machine of that OS (or the CI matrix) |
| NativePHP `native:build win/mac` | ⏳ requires host PHP + Electron download (or the CI matrix) |
| `.github/workflows/desktop-build.yml` run | ⏳ needs a GitHub repo — syntax-validated, not executed |

### Notes / gotchas (iteration 3)

- jpackage's `--type` values are lowercase (`app-image`, `exe`, …) — the
  pjavey/panteleyev Maven plugins fail on modern Maven (missing
  `maven-shared-utils`), hence the plain-script approach.
- The JavaFX container app-image keeps the exec bit inside Linux, but the
  Windows bind mount drops it — cosmetic, irrelevant on a real Linux host or
  on Windows (where jpackage emits `.exe`).
- `tauri.conf.json` stays `nsis/msi` (Windows-first); the CI matrix passes
  explicit `--bundles` per platform, so Linux/macOS bundles are chosen in the
  workflow, not the config.
- mingw-w64 only exists on the upstream dl-cdn repos (the DHI apk mirror is
  curated) — `tauri-win-dev` installs with a fresh `--no-cache` index fetch so
  all three configured repos are consulted.
- The rustup version is pinned to the stable that produced the current
  `target/` cache — bumping it recompiles the whole Windows dep tree.
- The `.exe` (213 MB debug build) is a cross-compile proof; `cargo build
  --release` for the real artifact, and NSIS/MSI still need a Windows host.

---

## Iteration 4 — Dioxus spike (variant D)

Research + spike: can a **Dioxus 0.7** desktop app (pure-Rust `rsx!` UI on the
same `wry` webview Tauri uses) fill the LDS panel role? Dioxus 0.7 (Sep 2025)
is the stable line (0.7.10 as of Aug 2026); desktop runs on `wry`/`tao`, and
tray support comes from `dioxus_desktop::trayicon`, a re-export of
`muda`/`tray-icon` — the same crates Tauri v2 uses.

### What was built

- **`desktop/dioxus/`** — a `cargo build` project (`dioxus` 0.7 with the
  `desktop` feature + `dioxus-desktop` + serde + tokio). `src/main.rs`:
  - **Tray icon + context menu via muda** — `TrayIconBuilder` with a
    `Menu`/`MenuItem` ("Refresh status" / "Quit"), wired through
    `use_tray_menu_event_handler`; a generated RGBA placeholder icon.
  - **Panel window** — live `docker compose --profile '*' ps` table polled
    every 3 s via `use_future` + `spawn_blocking`, plus a Refresh button and
    an error line.
  - Close-to-tray (`with_exits_when_last_window_closes(false)`); tray
    left-click shows the panel again
    (`with_tray_icon_show_window_on_click(true)`).
- **Build wiring** — `desktop/build.sh` / `build.bat` gained the `dioxus`
  variant:
  - `desktop/build.sh dioxus` → containerized compile-check **reusing
    `lds/tauri-dev`** (wry needs the same webkit2gtk deps as Tauri — no new
    base image).
  - `desktop/build.sh dioxus --os win --container` → Windows `.exe` via the
    existing `lds/tauri-win-dev` mingw cross-compile.
  - `--os win` / `--os mac` host paths → `dx bundle` (guarded on the `dx`
    CLI being installed).

### Files changed (iteration 4)

| File | Change |
|:-----|:-------|
| `desktop/dioxus/Cargo.toml` | new — dioxus 0.7 (desktop feature), dioxus-desktop, serde, tokio |
| `desktop/dioxus/src/main.rs` | new — muda tray + `docker compose ps` panel (spike) |
| `desktop/dioxus/Dioxus.toml` | new — minimal `dx` config (cargo build doesn't need it) |
| `desktop/dioxus/README.md` | new — why Dioxus, build/run, gotchas |
| `desktop/build.sh` / `build.bat` | `dioxus` variant: container build (tauri-dev), win-container (tauri-win-dev), host `dx bundle` |
| `desktop/README.md` | variant D row + base-image note + capability table column |

### Verification (iteration 4)

| Check | Result |
|:------|:-------|
| Dioxus 0.7.10 desktop API (launch / Config / trayicon) | ✅ confirmed from docs.rs + the v0.7 example tree |
| `build.sh` / `build.bat` wiring + guardrails | ✅ `bash -n` clean; real cmd parses the `dioxus` arg; the mac guardrail refuses with the CI pointer |
| `desktop/build.sh dioxus` container compile-check | ⏳ blocked mid-run — Docker Desktop's Linux engine returned **500 on `_ping`** (daemon wedged, needs a Docker Desktop restart) |

### Notes / gotchas (iteration 4)

- Dioxus 0.7 API churn is real: `launch` is now `(root, contexts,
  platform_config)` — use `dioxus::LaunchBuilder::new().with_cfg(config)
  .launch(App)` instead.
- `TrayIconBuilder` is `!Send`; the built `TrayIcon` is `Box::leak`ed so it
  outlives the creating `use_effect` (dropping it removes the icon).
- `use_effect` re-runs on every render — one-time setup (the tray) is guarded
  with a signal flag.
- Dioxus is NOT a competitor to Tauri at the same layer — Dioxus desktop IS
  built on wry. The differentiators: pure-Rust `rsx!` UI, signals reactivity,
  hot-patching (Subsecond), and the experimental Blitz native renderer (no
  webview at all).
- Spike scope: tray + status panel only. Log streaming / an `lds` command
  bridge / installers are the natural follow-ups if the spike passes.

---

## Future considerations

- **Dynamic tool URLs** — source cards from the dashboard/`.env` instead of
  the hardcoded list
- **Tray status** — per-profile tray submenu with live health dots (could
  reuse the auto-refresh poll)
- **Log streaming on the tail button** — merge Tail/Stream into one control
  with a follow checkbox
- **Stream history** — keep a ring buffer of recent lines so switching
  services doesn't lose the previous stream
