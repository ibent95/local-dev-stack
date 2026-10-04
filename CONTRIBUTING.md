# Contributing to Local Dev Stack

Thanks for helping improve LDS! This repo is shared local dev infrastructure
(Docker Compose + scripts + a PHP dashboard) that every project in the stack
builds on, so changes here ripple outward — a short checklist below keeps that
safe. A condensed, bilingual version of this guide lives in the handbook as
[`docs/en/16-contributing.md`](docs/en/16-contributing.md) (served at
`http://localhost/docs.php?doc=16-contributing` while the stack runs).

## Ways to contribute

- **Bug reports** — use the [bug report form](.github/ISSUE_TEMPLATE/bug_report.yml).
- **Feature ideas / new services / new templates** — open an issue first so the
  shape can be discussed before code.
- **Security issues** — do **not** open a public issue; follow
  [SECURITY.md](SECURITY.md).
- **Docs** — every chapter exists in English **and** Indonesian; keep them in
  sync.
- **Code / config / scripts** — fork, branch, open a PR against `master`.

## Development setup

Prerequisites: Docker Desktop or Docker Engine with Compose v2, Git, and Bash
(Git Bash on Windows). Then:

```bash
git clone https://github.com/<you>/local-dev-stack.git
cd local-dev-stack
cp .env.example .env          # never commit .env — it is git-ignored
./lds.sh init                 # network + first-run setup
./lds.sh build-bases          # build the shared lds/* base images (once)
./lds.sh up                   # start the default run-set from your .env toggles
./lds.sh ps                   # everything healthy?
```

On Windows `cmd`, use `lds.bat` instead of `./lds.sh`; under PowerShell run
`& .\lds.bat …` or the `.sh` via Git Bash.

## Pull request workflow

1. Fork and branch from `master`: `feat/<short-name>` or `fix/<short-name>`.
2. Make the change (see the sync rules below — most changes touch **several**
   files by design).
3. Run the validation checklist.
4. Open a PR **against `master`** with: what changed, why, and how you tested
   it (paste `docker compose config --quiet` / `lds ps` output where useful).
5. Keep PRs focused; one service/tool per PR is much easier to review.

Commit messages: short and imperative. This repo historically uses an
`Updated: <what>` prefix (e.g. `Updated: swap DBGate for DBX`) — matching it is
welcome but not required.

## The sync rules (the important part)

LDS is one stack wired together in many small places. When you change X, also
change Y:

| You changed | You must also |
|---|---|
| A profile / service in `docker-compose.yml` | Keep the profile list in sync in `scripts/run/up.sh`, `scripts/run/up.bat` **and** `.env.example` (`LDS_ENABLE_<PROFILE>` toggle) |
| An environment variable | Add it to `.env.example` (same order/comments apply — `lds env-sync --dry-run` must be clean; `up` runs `env-sync` quietly and would rewrite `.env` anyway) |
| A script | Write it **twice**: `.sh` **and** `.bat` (only `env-sync` also has a `.ps1`); shell files must stay **LF** — `.gitattributes` enforces it because `sh`/`ash` chokes on CRLF |
| A service or tool | Add its row to the credits chapter (`docs/en/18-credits.md` + `docs/id/18-credits.md`), mention it in `docs/en+id/15-data-tools.md` if it's a tool, and register it on the dashboard (`configs/web/dashboard/index.php`) |
| Docs | Translate both languages (`docs/en/…` **and** `docs/id/…`), add the numbered entry to **both** `README.md` indexes, and use the next free chapter number |
| Dashboard PHP (`configs/web/dashboard/*.php`) | `php -l` it, then `docker restart lds-php` (opcache `revalidate_freq=300`) — the container is bind-mounted, so no rebuild is needed |
| Base images (`base-images/**`) | Rebuild with `./lds.sh build-bases`; bump the version var in `.env.example` if you changed a pinned version |
| The dev TLD (`.test`) | Update **both** `configs/nginx/default.conf` and `configs/dns/dnsmasq.conf` |

Conventions in short: container names are `lds-*`; Compose values use
`${VAR:-default}`; inter-container traffic uses service names on `lds-network`
(not host ports); never rely on `COMPOSE_PROFILES` for defaults (`up` reads the
`LDS_ENABLE_*` toggles directly so `lds up <profile>` stays scoped); prefer
targeted `lds up <profile>` over `lds up all`.

`.github/copilot-instructions.md` and `CLAUDE.md` carry the fuller architecture
and convention reference — read them before a large change.

## Validation checklist

There is **no unit-test runner** at the repo root; validation is Compose
correctness, container health, and the built-in scanners:

```bash
docker compose config --quiet        # compose syntax / interpolation
./lds.sh ps                          # services healthy after up
./lds.sh env-sync --dry-run          # .env vs .env.example drift
./lds.sh tools semgrep ./scripts     # SAST on shell/scripts (optional but nice)
./lds.sh tools trivy .               # CVE/SCA of the repo + images (optional)
docker exec lds-php php -l /var/lds-dashboard/<file>.php   # dashboard edits
```

For docs, load the touched chapters at `http://localhost/docs.php?doc=<name>`
in **both** languages and check the sidebar, TOC and prev/next links.

## PR checklist

- [ ] `docker compose config --quiet` passes
- [ ] Profiles/toggles synced (`up.sh`, `up.bat`, `.env.example`)
- [ ] New env vars live in `.env.example`; `lds env-sync --dry-run` is clean
- [ ] Every changed `.sh` has its `.bat` twin; shell files are LF
- [ ] Docs updated in EN **and** ID, both `README.md` indexes numbered, credits
      row added for anything new the stack runs
- [ ] Dashboard PHP passes `php -l`; `lds-php` restarted after edits
- [ ] Nothing secret committed (`.env`, `configs/proxy/certs/*`, `data/*`,
      `*.db` are all git-ignored — double-check `git status` before you commit)
- [ ] PR describes what/why and how it was tested

## License

By contributing you agree that your changes are distributed under this repository's
[MIT license](LICENSE).
