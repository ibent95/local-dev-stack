# 003 · LDS Desktop (Tauri v2 · JavaFX · NativePHP) — Planning

**Date:** 2026-08-11
**Status:** Planning (finalized; development follows)
**Type:** Planning

---

## Overview

Add a **desktop companion** for the local-dev-stack: a system-tray app plus a
control panel that starts/stops profiles, shows container status, opens the
admin tool UIs, tails logs, and runs `hosts-sync` behind a native elevation
prompt. It is a **thin shell over the existing `lds` CLI** — the bash/bat
scripts remain the single source of truth for Docker orchestration, DB init,
proxies, and DNS. The desktop app only *invokes* them.

Motivation: the dashboard at `http://localhost` already covers *browsing* the
tools; the real daily gaps are one-click start/stop, live status, logs, and
running `hosts-sync` / certs without opening an admin terminal.

**Process:** per the development workflow, this planning document is finalized
first. Development happens after it is agreed, and
`docs/developments/003/implementation.md` is written only once development is
complete and verified.

---

## 1 · Tech decision — three implementations

The same app is built in **three stacks**, sharing one design. This is
deliberate: the Tauri variant is the **primary, production choice**; the
JavaFX and NativePHP variants are learning exercises that prove the
architecture is toolkit-agnostic.

| Variant | Location | Stack | Build |
|:--------|:---------|:------|:------|
| **A** ⭐ | `desktop/tauri/` | Rust + **Tauri v2** (system WebView + Rust backend) | `desktop/build.sh tauri` via `lds/tauri-dev` |
| **B** 🎓 | `desktop/javafx/` | Java 21 + **JavaFX** (native controls) | `desktop/build.sh javafx` via `lds/javafx-dev` |
| **C** 🎓 | `desktop/nativephp/` | PHP 8.3+ + **NativePHP v2** (Laravel + Electron shell) | `php artisan native:run` | `desktop/build.sh nativephp` via `lds/nativephp-dev` |

⭐ = production · 🎓 = learning purposes only.

The A and B variants live under one `desktop/` folder, versioned by subfolder.
They are built with **containerized base images** (no Rust/Maven on the host):
`lds/tauri-dev` (rust-dev + webkit2gtk-4.1/GTK3 + tauri-cli) and
`lds/javafx-dev` (java-dev + GTK3/fontconfig/X11), both registered in
docker-bake.hcl and built with `lds build-bases`. Variant C is scaffolded
(Laravel 13 + nativephp 2.2.1); it builds on the host (PHP/Composer/Node are
already present) and also has a `lds/nativephp-dev` compile-check image in
docker-bake.hcl.

### Why Tauri over Electron

| Criteria | Tauri (Rust) | Electron (Node) |
|:---------|:-------------|:----------------|
| Bundle size | ~10 MB (system WebView) | ~150 MB (bundled Chromium) |
| Memory | Low | High |
| Rust safety & speed | ✅ | — |
| UI flexibility | Any web frontend | Any web frontend |
| Elevation (Windows) | UAC via `Start-Process -Verb RunAs` | Same, via child process |
| Team familiarity | New (Rust) | Node already used in LDS apps |

### Why JavaFX as the second variant

| Criteria | JavaFX (Java) | Notes |
|:---------|:--------------|:------|
| Toolkit | Native JavaFX controls (Button, TableView, Tabs) | Different UI stack from Tauri's WebView |
| Tray | AWT `SystemTray` (hack, no first-class support) | Weakest part vs Tauri's `tray-icon` |
| Bundle | ~80–150 MB (JRE via jpackage) | Heavier than Tauri |
| Stack fit | LDS already ships `java-dev` base + JDBC drivers | Java isn't foreign to the stack |
| Learning value | Idiomatic Java: ProcessBuilder, CompletableFuture, Platform.runLater | Same problems, different solutions |

### Why NativePHP as the third variant (learning only)

| Criteria | NativePHP (PHP + Laravel) | Notes |
|:---------|:--------------------------|:------|
| Language | PHP 8.3+ with Laravel — **already the stack's language** | The dashboard, edge, and templates are all PHP |
| UI | Any web stack (Blade, Livewire, Inertia, plain HTML/CSS/JS) | Could reuse dashboard styling almost directly |
| Runtime | Bundles a static PHP runtime in an Electron shell | No server/network needed on the user machine |
| OS APIs | Window, menu, tray, notifications, SQLite via Laravel | Out of the box |
| Bundle | Large (Electron + PHP runtime, ~100–200 MB) | Heaviest of the three |
| License | Free core (Laravel-compatible); paid plugins/cloud | — |

NativePHP is the easiest codebase fit for LDS (a PHP shop), but its Electron
footprint makes it a **learning-purpose variant only** — Tauri stays the
production choice (lightweight, first-class tray, ~10 MB bundles).

The app is deliberately **not** a Docker Desktop clone — container management
stays in Docker Desktop; the panel is a convenience layer for *this stack*.

---

## 2 · Common architecture

All three variants share the same shape — a frontend (WebView, native
controls, or Blade/web), a thin backend (Rust commands, Java methods, or
Laravel commands), and the `lds` CLI at the bottom:

```
┌──────────────────────────────────────────────────────────────┐
│  LDS Desktop (A: Tauri · B: JavaFX · C: NativePHP)         │
│  ┌────────────────┐        ┌──────────────────────────────┐  │
│  │  frontend      │  call  │  backend (thin layer)        │  │
│  │  A: ui/ (JS)   │◀──────▶│  A: Rust commands            │  │
│  │  B: JavaFX     │        │  B: Java methods             │  │
│  │  C: Blade/JS   │        │  C: Laravel commands         │  │
│  │  panel + chips │        │  lds_run / stack_status /    │  │
│  │  tool cards    │        │  service_logs / open_url /   │  │
│  │  status table  │        │  hosts_sync  + tray          │  │
│  └────────────────┘        └──────────────┬───────────────┘  │
│                                           │ spawn (cmd/bash) │
└───────────────────────────────────────────┼──────────────────┘
                                            ▼
                            ┌─────────────────────────────┐
                            │  lds CLI (repo root)        │
                            │  lds.sh / lds.bat           │
                            │  → docker compose, db init, │
                            │    hosts-sync, seed, certs  │
                            └─────────────────────────────┘
```

### Repo root discovery

| Variant | How the repo root is found |
|:--------|:---------------------------|
| A (Tauri) | Walk up from `CARGO_MANIFEST_DIR` until `lds.bat` / `lds.sh` is found |
| B (JavaFX) | Walk up from the working directory until `lds.bat` / `lds.sh` is found |
| C (NativePHP) | Repo root passed to the Laravel app / resolved from `base_path()` |

### Platform invocation

| Platform | Command |
|:---------|:--------|
| Windows | `cmd /C lds.bat <args>` |
| Linux/macOS | `bash lds.sh <args>` |

---

## 3 · Scope (v0.1) — shared by all variants

### 3.1 Features

- **System tray** — Open panel · Start all profiles · Stop all · Quit
- **Lifecycle commands** — `lds start` (full lifecycle) · `stop` · `down` ·
  `ps` · `logs` · `certs` · `db init all`
- **Profile chips** — click a profile → `lds up <profile>` / `lds down <profile>`
- **Admin tool cards** — one-click open of every tool UI (localhost ports,
  mirroring `docs/en/12-ports.md`)
- **Container status** — live table from `docker compose --profile '*' ps`
  (service, container, state, health, status), **auto-refreshed every 5 s**
  with a header toggle + last-updated stamp
- **Logs** — one-shot tail `docker compose logs --tail N <service>` **and a
  live follow stream** (`--follow`, lines pushed to the UI as they arrive;
  Stop kills the stream child)
- **lds tools** — path input + `semgrep` / `trivy` / `crg` scanner buttons
- **hosts-sync** — Windows: relaunch through elevated cmd (native UAC prompt);
  Unix: direct CLI run (needs passwordless sudo / root shell)
- **Custom profile box** — arbitrary `lds up|down <anything>`

### 3.2 Explicitly out of scope

- Container management (start/stop/exec individual containers) — Docker Desktop
- Re-implementing LDS logic (init DBs, proxies, DNS, certs) — the CLI owns it
- Monitoring/alerting — the dashboard probes cover health

---

## 4 · Variant A — Tauri v2 (`desktop/`)

### 4.1 Backend commands

| Command (Rust) | UI invoke | What it runs |
|:---------------|:----------|:-------------|
| `lds_run(args)` | `{ args: ["up","duckdb"] }` | `lds <args>` (blocking thread) |
| `stack_status()` | — | `docker compose --profile '*' ps --format json` → parsed rows |
| `service_logs(service, lines)` | `{ service, lines }` | `docker compose logs --tail N <service>` |
| `open_url(url)` | `{ url }` | `cmd /C start` / `open` / `xdg-open` |
| `hosts_sync()` | — | Windows: elevated `lds.bat hosts-sync`; Unix: direct |

Long-running commands run via `tauri::async_runtime::spawn_blocking` so the UI
never freezes. The generic `lds_run` means **any** future lds command is just a
new UI button — no backend change.

### 4.2 Frontend (`ui/`)

Vanilla HTML/CSS/JS — **no bundler, no npm**. Tauri serves `ui/` directly
(`frontendDist: "../ui"`), and the JS talks to Rust through the injected global
(`withGlobalTauri: true` → `window.__TAURI__.core.invoke`). Sections:

1. Header — status dot, refresh, hosts-sync, Start all / Stop all
2. Lifecycle — `start` / `stop` / `down` / `ps` / `logs` / `certs` / `db init`
3. lds tools — path input + semgrep / trivy / crg buttons
4. Profiles — chip buttons + custom profile input
5. Admin tools — clickable cards (label + port)
6. Containers — status table
7. Logs — service select + line count + tail output
8. Output — raw `lds` output log

### 4.3 Files

```
desktop/tauri/
├── README.md                # build/run instructions
├── .gitignore
├── ui/                      # static frontend (no build step)
│   ├── index.html
│   ├── styles.css
│   └── main.js
└── src-tauri/
    ├── Cargo.toml           # tauri v2 + tray-icon feature
    ├── build.rs
    ├── tauri.conf.json      # frontendDist, NSIS+MSI, icons
    ├── capabilities/default.json
    ├── icons/               # generated 32/128 PNG + icon.ico
    └── src/
        ├── main.rs
        └── lib.rs           # commands + tray + lds bridge
```

### 4.4 Build

```bash
# Containerized (recommended): lds/tauri-dev base image
lds build-bases            # one-time: build lds/tauri-dev (+ javafx-dev)
desktop/build.sh tauri     # cargo check + build inside the image

# Host build (optional, needs Rust toolchain)
cd desktop/tauri/src-tauri
cargo tauri dev      # dev run against ../ui (UI files hot-reload)
cargo tauri build    # NSIS + MSI installers in target/release/bundle/
```

---

## 5 · Variant B — JavaFX (`desktop/javafx/`)

### 5.1 Backend classes

| Class | Responsibility | Mirrors |
|:------|:---------------|:--------|
| `LdsCli` | ProcessBuilder bridge: `lds()`, `stackStatusJson()`, `serviceLogs()`, `hostsSync()`, `openUrl()` + repo-root discovery | Rust `run_lds` + commands |
| `LdsDesktopApp` | Window, tabs, status table, tray | `lib.rs` + `ui/` |

Blocking CLI calls run in `CompletableFuture.runAsync`; UI updates land back on
the JavaFX thread via `Platform.runLater` — the JavaFX equivalent of Tauri's
`spawn_blocking` + async commands. `docker compose ps --format json` is parsed
with Jackson (`JsonNode`), mirroring the Rust `serde` structs.

### 5.2 UI (tabs)

1. Lifecycle — `start` / `stop` / `down` / `ps` / `logs` / `certs` / `db init`
2. Profiles — toggle chips → `up` / `down`
3. Tools — clickable cards for every admin UI
4. Containers — `TableView` status table
5. Logs — service field + line count + tail
6. Output — raw `lds` output

### 5.3 Files

```
desktop/javafx/
├── README.md                # build/run, layout, notes
├── .gitignore
├── pom.xml                  # JavaFX 21 + Jackson (Maven Central)
└── src/main/
    ├── java/com/localdevstack/lds/
    │   ├── LdsCli.java      # ProcessBuilder bridge to lds.bat/lds.sh
    │   └── LdsDesktopApp.java  # window, tabs, status table, tray
    └── resources/lds-tray.png  # tray icon
```

### 5.4 Build

```bash
# Containerized (recommended): lds/javafx-dev base image
lds build-bases            # one-time: build lds/javafx-dev
# note: also builds fine on plain lds/java-dev (JavaFX jars come from Maven)
desktop/build.sh javafx    # mvn package inside the image → javafx/target/*.jar

# Host build (optional, needs JDK 21 + Maven)
cd desktop/javafx
mvn javafx:run      # dev run
mvn package         # jar (jpackage for native installers)
```

---

## 6 · Variant C — NativePHP (`desktop/nativephp/`, learning only)

### 6.1 Shape

A Laravel app wrapped by NativePHP (Electron shell + static PHP runtime). The
panel is Blade/Livewire (or plain HTML/JS) served locally; a Laravel command
or route shells out to the `lds` CLI. The scaffold exists (Laravel 13 +
`nativephp/desktop ^2.2`, boots cleanly) but **no LDS logic is implemented yet** —
planned for learning only.

### 6.2 Planned files

```
desktop/nativephp/
├── README.md                # build/run, notes (learning purpose)
├── composer.json            # laravel + nativephp/desktop (+ composer-patches)
├── artisan                  # Laravel CLI
├── config/nativephp.php     # window/menu/tray settings
└── app/
    ├── Http/Controllers/LdsController.php   # routes → lds CLI calls
    └── .../LdsCli.php                       # Process/exec bridge to lds.bat / lds.sh
```

### 6.3 Build & run (NativePHP v2 — verified)

```bash
# Prereqs: PHP 8.3+ (8.4 works), Composer, Node 20+
cd desktop/nativephp
composer install              # auto-applies the Laravel-13 command-name patch (below)
npm install
php artisan bifrost:login           # nativephp account (one-time)
php artisan bifrost:init            # select the desktop project
php artisan bifrost:download-bundle # Electron runtime bundle
php artisan native:run              # dev run (Electron shell)
php artisan native:build            # package per-OS installer
```

> `native:dev` / `native:build` in the original plan were **NativePHP v1**
> commands. The installed `nativephp/desktop ^2.2` CLI is `bifrost:*` +
> `native:run` (`native:serve` is its deprecated alias). Full detail in
> `desktop/nativephp/README.md`.

**Laravel 13 patch:** nativephp/desktop 2.2.1's `FreshCommand` mixes an
`#[AsCommand]` attribute with the inherited `migrate:fresh` signature, which
crashed `php artisan list` ("registered under multiple names");
`WipeDatabaseCommand` similarly ignored its `$name` and shadowed `db:wipe`.
Both are fixed by
`desktop/nativephp/patches/nativephp-desktop-laravel13-commands.patch`, applied
automatically via cweagans/composer-patches (`composer reinstall
nativephp/desktop` re-applies).

### 6.4 Learning notes

- Compare how the same thin-shell design is expressed in PHP vs Rust vs Java
- NativePHP's Electron shell means the biggest bundle of the three — confirms
  the Tauri choice for production
- Reuses the LDS PHP ecosystem (the dashboard's styling/tooling) with almost
  no translation

---

## 7 · Tool cards (v0.1 static list)

Mirrors `docs/en/12-ports.md` (hardcoded for now; a follow-up may source them
from the dashboard config):

| Card | URL |
|:-----|:----|
| phpCacheAdmin / DBGate / DrawDB / Hop / Superset | `localhost:4500–4504` |
| Semgrep / Vaultwarden / OpenWA / RustFS | `4505–4508` |
| ZAP / Trivy / Mailpit / Penpot | `4510 / 4511 / 4513 / 4515` |
| Analytics / Tasks / Wiki / Playwright | `4520 / 4522 / 4524 / 4526` |
| Instatic / ERPNext / code-review-graph | `4528 / 4529 / 4530` |
| Trino / Dashboard | `4451 / localhost` |

---

## 8 · Development plan

Order of work after this plan is agreed:

1. **Variant B (JavaFX)** — scaffold `desktop/javafx/`, `LdsCli`, window,
   tabs, tray → compile-check with `javac` / `mvn package`
   *(done: verified `mvn package` inside `lds/java-dev` produces a working jar)*
2. **Variant A (Tauri)** — scaffold `desktop/tauri/`, backend commands, tray,
   UI panels → compile-check via `lds/tauri-dev` (`desktop/build.sh tauri`)
3. **Base images** — `lds/tauri-dev` + `lds/javafx-dev` + `lds/nativephp-dev`
   in docker-bake.hcl (built by `lds build-bases`; `nativephp-dev` added later
   for the variant C compile-check)
4. **Verification** — run the apps and confirm: status table populates,
   buttons invoke the CLI, hosts-sync elevation path works
5. **Variant C (NativePHP, learning only)** — optional, after A and B are
   stable: scaffold `desktop/nativephp/` and compare the thin-shell design in PHP
   *(done: scaffolded — Laravel 13 + nativephp 2.2.1, boots; Laravel-13 command
   conflict patched via composer-patches; v2 build flow verified & documented.
   LDS logic itself not implemented yet)*
6. **Docs** — fill in `docs/developments/003/implementation.md` with what was
   built, bugs found, and verification results (only after development is done)

---

## 9 · Documentation updates

| File | Update |
|:-----|:-------|
| `desktop/README.md` | All variants + containerized builds |
| `desktop/tauri/README.md` | Build/run, layout, requirements, notes (variant A) |
| `desktop/javafx/README.md` | Build/run, layout, requirements, notes (variant B) |
| `desktop/nativephp/README.md` | Build/run (v2 flow), composer patch, learning notes (variant C) — done |
| `docker-bake.hcl` | `tauri-dev` + `javafx-dev` + `nativephp-dev` targets, added to `default` group |
| `base-images/tauri-dev/Dockerfile` | rust-dev + webkit2gtk-4.1/GTK3 deps + tauri-cli |
| `base-images/javafx-dev/Dockerfile` | java-dev + GTK3/fontconfig/X11 runtime deps |
| `base-images/nativephp-dev/Dockerfile` | `lds/php` + sqlite + patch (variant C compile-check) |
| `desktop/build.sh` / `build.bat` | Containerized build entrypoints |
| `docs/developments/003/implementation.md` | This iteration's implementation record — written after development completes |

---

## 10 · Future considerations

- **Dynamic tool URLs** — source cards from the dashboard/`.env` instead of a
  hardcoded list
- **Tray status** — per-profile tray submenu with live health dots
- **Certs action** — run `lds certs` behind the same elevation path
- **Startup with OS** — auto-start the tray app on login
- **Notifications** — toast on container crash / unhealthy
