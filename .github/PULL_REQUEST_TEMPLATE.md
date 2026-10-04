<!-- Thanks for the PR! Please fill in what/why + how you tested. -->

## What & why

<!-- Which service/tool/docs, and the reason for the change. -->

## How tested

<!-- e.g. `docker compose config --quiet`, `lds ps` output, docs checked at
     http://localhost/docs.php?doc=<name> in EN + ID, scanners run. -->

## Checklist

- [ ] `docker compose config --quiet` passes
- [ ] Profiles/toggles synced (`scripts/run/up.sh`, `scripts/run/up.bat`, `.env.example`)
- [ ] New env vars added to `.env.example`; `lds env-sync --dry-run` is clean
- [ ] Every changed `.sh` has its `.bat` twin; shell files kept **LF**
- [ ] Docs updated in **EN and ID**, both `README.md` indexes renumbered,
      credits row added for anything new the stack runs
- [ ] Dashboard PHP passes `php -l`; `lds-php` restarted after edits
- [ ] Nothing secret staged (`.env`, `configs/proxy/certs/*`, `data/*`, `*.db`)
- [ ] Follows the conventions in [CONTRIBUTING.md](https://github.com/ibent95/local-dev-stack/blob/master/CONTRIBUTING.md)
