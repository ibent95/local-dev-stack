# LDS Desktop — NativePHP variant (learning only)

The **PHP + NativePHP** implementation of the LDS desktop companion — the
learning sibling of the [Tauri](../tauri/README.md),
[JavaFX](../javafx/README.md) and [Dioxus](../dioxus/README.md) variants. Same
"thin shell over the `lds` CLI" design, expressed in the stack's own language
(PHP/Laravel) instead of Rust or Java.

> **Status: implemented — full parity with the other three variants.** The
> app boots a Laravel 13 + NativePHP v2.3 window rendering a 6-tab panel
> (Lifecycle / Profiles / Tools / Containers / Logs / Output), with a system
> tray and the same 11 lifecycle commands, 51 profile chips, 41 tool cards,
> live container status, one-shot + streaming logs and elevated `hosts-sync`.

## What's here

Standard Laravel app + NativePHP v2 (`config/nativephp.php`), plus the LDS
layer:

```
app/Services/LdsCli.php                     lds CLI wrapper (root discovery,
                                            run/detached/status/tail/stream,
                                            hosts-sync, open-url)
app/Providers/NativeAppServiceProvider.php  panel window + tray (MenuBar)
app/Providers/AppServiceProvider.php        tray menu event listeners
routes/web.php                              panel + 9 JSON API endpoints
resources/views/panel.blade.php             the 6-tab panel UI (inline CSS/JS)
public/images/tray.png                     tray icon (32×32 RGBA)
```

Requires PHP 8.3+ (8.4 works), Composer, and Node 20+.

## Features (same set as the Tauri / JavaFX / Dioxus variants)

- System tray — Open panel · Start all profiles · Stop all · Refresh status ·
  Hide panel · Quit
- Lifecycle buttons — `lds start` / `stop` / `down` / `ps` / `logs` /
  `certs` / `db init all` / `sonar` / `openvas start` / `openvas stop` /
  `backup`
- Profile chips — all 51 long-running compose profiles (`lds up <profile>` /
  `lds down <profile>`) + custom box; the one-shot `semgrep-scan` /
  `trivy-scan` / `sonar-scanner` profiles stay behind the `lds tools` buttons
- Admin tool cards — one-click open of all 41 tool UIs (mirrors
  `docs/en/12-ports.md`)
- Container status — live table from `docker compose --profile '*' ps`,
  auto-refreshed every 5 s (toggleable, last-updated stamp)
- Logs — one-shot `docker compose logs --tail N <service>` plus a live
  `--follow` stream (Stop kills the child)
- lds tools — path input + `semgrep` / `trivy` / `crg`
- hosts-sync — Windows: elevated cmd (native UAC prompt); Unix: direct CLI

### Close to tray — NativePHP caveat

NativePHP 2.3 has **no close interception** (no `Window::onClose`, no
`closing` event), so "X hides to tray" is not expressible. The equivalent
behaviour here:

- `Window::open('main')->closable(false)` removes the native close
  affordance, so the app cannot be closed by accident;
- a **Hide to tray** header button (`Window::hide('main')`) plus the tray's
  *Hide panel* item send it to the tray;
- the tray's *Open LDS Desktop* item and a left-click both re-show the panel;
- *Quit* (a native menu role) is the only way to exit.

The other three variants intercept the close event and hide instead.

### Implementation notes

- The PHP built-in server behind the window is single-threaded, so long
  commands are serialised: the panel keeps a `busy` flag and disables the
  buttons while an `lds` call is in flight.
- Log streaming runs a detached `docker compose logs --follow` writing to
  `storage/app/lds-stream.log`; the panel polls that file. Stop/Quit kill the
  child (Windows: `Get-CimInstance Win32_Process` filter; Unix: `pkill -f`).
- `NativeAppServiceProvider::boot()` can run more than once (macOS
  `activate`), so tray creation is guarded by a static flag (not the cache
  store — the default cache driver is the database and may not be migrated on
  first run).
- Tray menu clicks arrive as `Native\Desktop\Events\Menu\MenuItemClicked`
  (`$event->item['id']`); roles such as *Quit* are handled by Electron.

## Laravel-13 command-name bug — fixed upstream (2.3.1)

With nativephp/desktop 2.2.x, `php artisan list` crashed on Laravel 13:

```
The "native:migrate:fresh" command cannot be found because it is registered
under multiple names.
```

Root cause: `FreshCommand` declared an
`#[AsCommand(name: 'native:migrate:fresh')]` attribute but inherited the
`migrate:fresh …` `$signature` from Laravel's command, so the loader key never
matched the real name; `WipeDatabaseCommand` shadowed Laravel's own `db:wipe`
in reverse. This repo used to ship a local composer patch for both commands —
**obsolete since nativephp/desktop 2.3.1**, which fixed the signatures
upstream. The patch, `cweagans/composer-patches` and `patches/` were all
removed (commit `fed034e`); plain `composer install` is all you need.

## Build & run (NativePHP v2 — verified)

```bash
composer install
npm install                       # frontend deps (Vite)
php artisan bifrost:login         # nativephp account (one-time)
php artisan bifrost:init          # select/create the desktop project
php artisan bifrost:download-bundle   # fetch the Electron runtime bundle
php artisan native:run            # dev run (installs deps + launches Electron)
php artisan native:build          # package per-OS installer (defaults to current OS)
php artisan native:build win      # explicit OS: win | linux | mac | all (+ arch: x64 | arm64)
```

`native:build` accepts `{os}` and `{arch}` arguments (v2 — e.g. `native:build
mac arm64`); the per-OS matrix runs automatically via
`.github/workflows/desktop-build.yml`.

Notes:

- `php artisan native:serve` is a deprecated alias of `native:run`.
- The `native:dev` / `native:build` commands in the original planning doc are
  **NativePHP v1** — v2 uses `bifrost:*` + `native:run` / `native:build` above.
- `native:run` needs the Electron bundle from `bifrost:download-bundle`, which
  requires a logged-in nativephp account.
- Verified in this repo: `php artisan list` exits 0 with all `native:*` /
  `bifrost:*` commands present (nativephp/desktop 2.3.1); `migrate:fresh` and
  `db:wipe` remain Laravel's own; `npm install` + `npm run build` compile the
  frontend cleanly. CI runs `native:build` on PHP 8.4 / Node 22 for all three
  OSes.

## Containerized compile-check (optional)

Like the Tauri/JavaFX variants, a containerized build target exists —
`lds/nativephp-dev` (layered on `lds/php`: PHP 8.4 CLI + composer + node 20,
plus the SQLite driver):

```bash
docker buildx bake -f ../../docker-bake.hcl --load nativephp-dev   # one-time base image
../../desktop/build.sh nativephp    # composer install + vite build + artisan check
```

It proves the toolchain (composer, npm, artisan) works in a clean environment,
but like the Tauri container build it produces **no installer** — NativePHP
packages per-OS installers on the host via `native:build`.

## Learning notes

- Compare how the same thin-shell design is expressed in PHP (Laravel
  controllers/commands) vs Rust (Tauri commands) vs Java (JavaFX methods).
- NativePHP's Electron shell makes this the biggest bundle of the three —
  confirming the Tauri choice for production.
- Reuses the LDS PHP ecosystem (the dashboard's styling/tooling) with almost
  no translation.
