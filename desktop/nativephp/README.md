# LDS Desktop — NativePHP variant (learning only)

The **PHP + NativePHP** implementation of the LDS desktop companion — the
learning sibling of the [Tauri](../tauri/README.md) and
[JavaFX](../javafx/README.md) variants. Same "thin shell over the `lds` CLI"
design, expressed in the stack's own language (PHP/Laravel) instead of Rust or
Java.

> **Status: scaffolded, not yet implemented.** This folder is a stock
> Laravel 13 + NativePHP v2 app (`composer create-project laravel/laravel` +
> `nativephp/desktop ^2.2`, `php artisan native:install`). It boots and every
> artisan command works, but there is **no LDS logic yet** — no `LdsCli`
> bridge, no panel UI, no tray. `routes/web.php` is still the stock welcome
> page. See `docs/developments/003/planning.md` §6 for the planned shape.

## What's here

Standard Laravel app + NativePHP v2 (`config/nativephp.php`,
`app/Providers/NativeAppServiceProvider.php`). Requires PHP 8.3+ (8.4 works),
Composer, and Node 20+.

## Composer patch — why it exists

`php artisan list` crashed on Laravel 13 with:

```
The "native:migrate:fresh" command cannot be found because it is registered
under multiple names.
```

Root cause: nativephp/desktop 2.2.1's `FreshCommand` declares an
`#[AsCommand(name: 'native:migrate:fresh')]` attribute but inherits the
`migrate:fresh …` `$signature` from Laravel's command. Laravel registers the
command lazily under the attribute name, but the instantiated command's actual
name comes from the signature — so the loader key never matches the real name
and Symfony's console refuses to resolve it. `WipeDatabaseCommand` has the same
class of bug in reverse: its `$name` is ignored and it silently shadowed
Laravel's own `db:wipe`.

Fix: `patches/nativephp-desktop-laravel13-commands.patch` gives both commands
the constructor pattern `MigrateCommand` already uses
(`$this->signature = 'native:'.$this->signature;`), so their real names match
their loader keys. The patch is applied automatically by
[cweagans/composer-patches](https://github.com/cweagans/composer-patches)
(see `extra.patches` in `composer.json`).

**The patch re-applies on every `composer install` / `composer update`.**
To force it on an existing checkout:

```bash
composer reinstall nativephp/desktop
```

`patches.lock.json` records the applied patch — commit it alongside
`composer.json` / `composer.lock`.

## Build & run (NativePHP v2 — verified)

```bash
composer install                  # applies the composer patch automatically
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
- Verified in this repo: `composer reinstall nativephp/desktop` re-applies the
  patch; `php artisan list` exits 0 with all `native:*` / `bifrost:*`
  commands present; `migrate:fresh` and `db:wipe` remain Laravel's own;
  `npm install` + `npm run build` compile the frontend cleanly.

## Containerized compile-check (optional)

Like the Tauri/JavaFX variants, a containerized build target exists —
`lds/nativephp-dev` (layered on `lds/php`: PHP 8.4 CLI + composer + node 20,
plus the SQLite driver and `patch`):

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
