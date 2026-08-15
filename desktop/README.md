# LDS Desktop

The desktop companion for the local-dev-stack, built in four stacks for
learning/comparison — all thin shells over the `lds` CLI (the repo scripts
stay the single source of truth):

| Variant | Location | Stack | Run (host) | Build (container) |
|:--------|:---------|:------|:-----------|:------------------|
| **A — Tauri** | `tauri/` | Rust + Tauri v2 (system WebView) | `cargo tauri dev` | `desktop/build.sh tauri` via `lds/tauri-dev` |
| **B — JavaFX** | `javafx/` | Java 21 + JavaFX (native controls) | `mvn javafx:run` | `desktop/build.sh javafx` via `lds/javafx-dev` |
| **C — NativePHP** 🎓 | `nativephp/` | PHP 8.3+ + NativePHP v2 (Laravel + Electron) | `php artisan native:run` | `composer install` + `php artisan native:build` |
| **D — Dioxus** 🧪 | `dioxus/` | Rust + Dioxus 0.7 (`rsx!` UI, wry webview) | `cargo run` / `dx serve` | `desktop/build.sh dioxus` via `lds/tauri-dev` |

🎓 = learning purposes only. Variant C is **scaffolded but not implemented**
(no LDS logic yet) — see `nativephp/README.md` for the Laravel-13 composer
patch and the verified v2 build flow.

🧪 = **spike**. Variant D proves the tray + status panel pattern in pure-Rust
UI (tray via `muda`, the same crate Tauri v2 uses) — no log streaming or lds
command bridge yet. See `dioxus/README.md`.

🎓 = learning purposes only. Variant C is **scaffolded but not implemented**
(no LDS logic yet) — see `nativephp/README.md` for the Laravel-13 composer
patch and the verified v2 build flow.

## Features (identical in both)

- System tray — Open panel · Start all profiles · Stop all · Quit
- Lifecycle buttons — `lds start` / `stop` / `down` / `ps` / `logs` /
  `certs` / `db init all`
- Profile chips — `lds up <profile>` / `lds down <profile>` + custom box
- Admin tool cards — one-click open of every tool UI (localhost ports,
  mirrors `docs/en/12-ports.md`)
- Container status — live table from `docker compose --profile '*' ps`, **auto-refreshed every 5 s** (toggleable, with a last-updated stamp)
- Logs — one-shot tail `docker compose logs --tail N <service>` **plus a live follow stream** (`--follow`, streamed line-by-line; Stop kills it)
- lds tools — path input + `semgrep` / `trivy` / `crg`
- hosts-sync — Windows: elevated cmd (native UAC prompt); Unix: direct CLI

## Containerized builds (no Rust/Maven/PHP toolchain on the host)

Base images (built with `lds build-bases` or
`docker buildx bake tauri-dev javafx-dev nativephp-dev`):

- `lds/tauri-dev` — `rust-dev` + webkit2gtk-4.1/GTK3/appindicator deps + tauri-cli (**also builds the Dioxus variant** — wry needs the same webview deps)
- `lds/tauri-win-dev` — `tauri-dev` + mingw-w64 + rustup windows target (cross-compiles a Windows `.exe`; on-demand, NOT in `lds build-bases` — it's ~2.5 GB)
- `lds/javafx-dev` — `java-dev` + GTK3/fontconfig/X11 runtime deps
- `lds/nativephp-dev` — `lds/php` + sqlite + patch (PHP 8.4 CLI + composer + node 20)

```bash
desktop/build.sh                     # all four variants, containerized (Linux)
desktop/build.sh tauri               # cargo check + build in lds/tauri-dev
desktop/build.sh javafx              # mvn package + jpackage app-image in lds/javafx-dev
desktop/build.sh nativephp           # composer install + vite build + artisan check in lds/nativephp-dev
desktop/build.sh dioxus              # cargo build in lds/tauri-dev (Dioxus spike)
desktop/build.sh javafx --os linux   # explicit OS (same as default)
desktop/build.sh tauri --os win --container   # Windows .exe cross-compiled in lds/tauri-win-dev
                                               #   (auto-builds the image on first run)
desktop/build.sh dioxus --os win --container   # Dioxus .exe, same lds/tauri-win-dev image
desktop/build.sh all --os win        # HOST Windows build (needs Rust/Maven/PHP on the host)
desktop/build.sh all --os mac        # HOST macOS build (needs toolchain on a Mac)
```

> What a Linux container can and cannot produce:
>
> | Target | Tauri | JavaFX | NativePHP | Dioxus |
> |:-------|:------|:-------|:----------|:-------|
> | **Linux** | ✅ binary | ✅ jar + app-image | ✅ compile-check | ✅ binary (spike) |
> | **Windows** | ✅ raw `.exe` via `--os win --container` (mingw cross-compile) | ⚠️ the **jar** runs on Windows; `exe`/`msi` need jpackage on Windows | ❌ needs a Windows host | ✅ raw `.exe` via `--os win --container` |
> | **macOS** | ❌ | ❌ | ❌ | ❌ |
>
> macOS is impossible in a container — Apple's toolchain (Xcode SDK, hdiutil,
> codesign) is required and macOS cannot run inside Linux Docker. The Tauri
> Windows `.exe` is the raw binary (ship `WebView2Loader.dll` beside it at
> runtime); NSIS/MSI **installers** still need a Windows host. JavaFX jar is
> cross-platform and already built by the container. Real installers for all
> three OSes come from the CI matrix below — `--os win` / `--os mac` run the
> host toolchain and refuse with a CI pointer on the wrong OS.

## Windows + Linux + macOS in one command (CI)

`.github/workflows/desktop-build.yml` is a 3 runner × 3 variant matrix that
builds real installers for all three OSes and uploads them as workflow
artifacts:

| Variant | Windows | Linux | macOS |
|:--------|:--------|:------|:------|
| Tauri | `nsis` + `msi` (tauri-action) | `deb` + `appimage` | `app` + `dmg` |
| JavaFX | `target/dist/` (jpackage app-image; `JPACKAGE_TYPE=exe|msi`) | `deb`/app-image | `dmg` |
| NativePHP | `native:build win` | `native:build linux` | `native:build mac` |

Trigger: manual (`workflow_dispatch`) or on any push touching `desktop/`.

## Host builds (manual, optional)

See `tauri/README.md` (Rust + cargo) and `javafx/README.md` (Maven) for
local toolchain instructions, and `javafx/package.sh` for the jpackage step.

## Notes

- Tool card URLs are a static list mirroring `docs/en/12-ports.md`; a future
  version can source them from the dashboard/`.env` instead.
- Tray behavior: the app keeps running when the window is closed.
- The JavaFX AWT tray on Linux needs a desktop environment with a system tray.
- Auto-refresh and log streaming: the Tauri backend holds the `docker compose
  logs -f` child in Rust state (killed on Stop / app exit); JavaFX keeps the
  `Process` on the app object (killed via Stop / JVM shutdown hook).
