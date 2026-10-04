# 16 · Contributing

LDS is shared infrastructure: one Compose stack, `lds` shell scripts, a PHP
dashboard, and a bilingual handbook. Changes here ripple into every project
that runs on the stack, so contributions follow a short, explicit checklist.
The full, machine-facing version of this guide lives at the repo root in
[`CONTRIBUTING.md`](https://github.com/ibent95/local-dev-stack/blob/master/CONTRIBUTING.md)
— this chapter is the handbook summary.

## Ways to contribute

- **Bugs** → the bug-report issue form.
- **Features / new services / templates** → open an issue first, agree the
  shape, then a PR.
- **Security** → never a public issue; see [17 · Security](17-security.md).
- **Docs** → every chapter exists in English **and** Indonesian; keep the pair
  in sync.
- **Code** → fork, branch from `master`, open a PR against `master`.

## Dev setup

Prerequisites: Docker (Desktop or Engine) with Compose v2, Git, and Bash (Git
Bash on Windows).

```bash
git clone https://github.com/<you>/local-dev-stack.git
cd local-dev-stack
cp .env.example .env        # git-ignored - never commit it
./lds.sh init               # network + first-run setup
./lds.sh build-bases        # build the lds/* base images (once)
./lds.sh up                 # default run-set from your .env toggles
```

On Windows use `lds.bat` (from `cmd`) or the `.sh` scripts via Git Bash.

## The sync rules

Most changes touch several files **by design**:

- **New profile/service** → `docker-compose.yml` **and** the profile list in
  `scripts/run/up.sh` + `scripts/run/up.bat` **and** an
  `LDS_ENABLE_<PROFILE>` toggle in `.env.example`.
- **New env var** → add it to `.env.example` (ordering/comments come from
  there); `lds env-sync --dry-run` must be clean. `up` runs `env-sync`
  quietly, so a missing var would be rewritten anyway.
- **Scripts come in pairs** — every `.sh` needs its `.bat` twin (only
  `env-sync` also ships a `.ps1`). Shell files must stay **LF**: `.gitattributes`
  enforces it because `sh`/`ash` fails on CRLF.
- **New service/tool** → credits row in [18 · Credits](18-credits.md), a
  mention in [15 · Data tools](15-data-tools.md) if it is a tool, and a card on
  the dashboard (`configs/web/dashboard/index.php`).
- **New docs chapter** → both `docs/en/` and `docs/id/`, the next free number,
  and a numbered entry in **both** `README.md` indexes.
- **Dashboard PHP** → `docker exec lds-php php -l <file>`, then
  `docker restart lds-php` (opcache `revalidate_freq=300`).
- **Changing the dev TLD** → update `configs/nginx/default.conf` **and**
  `configs/dns/dnsmasq.conf` together.

Conventions: containers are named `lds-*`; Compose values use
`${VAR:-default}`; services talk over `lds-network` by name (not host ports);
never rely on `COMPOSE_PROFILES` (toggles are read directly so
`lds up <profile>` stays scoped). `.github/copilot-instructions.md` and
`CLAUDE.md` hold the deeper architecture reference.

## Validation before a PR

There is **no unit-test runner** at the root — validation is Compose
correctness, container health, and the built-in scanners:

```bash
docker compose config --quiet       # compose syntax / interpolation
./lds.sh ps                         # healthy after up
./lds.sh env-sync --dry-run         # .env vs .env.example drift
./lds.sh tools semgrep ./scripts    # SAST (viewer at semgrep.test)
./lds.sh tools trivy .              # CVE/SCA (viewer at trivy.test)
```

For docs, open the touched chapters in **both** languages and check the
sidebar, TOC and prev/next links.

## PR checklist

- [ ] Compose validates (`docker compose config --quiet`)
- [ ] Profiles/toggles synced across `up.sh`, `up.bat`, `.env.example`
- [ ] Shell changes present in both `.sh` and `.bat`, LF preserved
- [ ] Docs in EN + ID, README indexes numbered, credits row added
- [ ] Dashboard PHP linted and `lds-php` restarted
- [ ] No secrets staged (`.env`, `configs/proxy/certs/*`, `data/*`, `*.db`
      are all git-ignored)
- [ ] PR explains what changed, why, and how it was tested

## Commit & PR style

Short, imperative messages; this repo historically prefixes them with
`Updated:` (e.g. `Updated: swap DBGate for DBX`). Keep PRs focused — one
service or tool per PR.

## License

Contributions are distributed under this repository's
[MIT license](https://github.com/ibent95/local-dev-stack/blob/master/LICENSE).
