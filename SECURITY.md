# Security Policy

Security notes for **Local Dev Stack (LDS)** — the shared Docker Compose dev
environment in this repository. A condensed, bilingual version lives in the
handbook as [`docs/en/17-security.md`](docs/en/17-security.md) (served at
`http://localhost/docs.php?doc=17-security` while the stack runs).

## Supported versions

There are no release branches or tags — **`master` is the only supported
line**. If you are running an older checkout, update first (`git pull`) and
rebuild (`./lds.sh build-bases --force`) before reporting an issue.

## Reporting a vulnerability

Please use **GitHub's private vulnerability reporting** — do not open a public
issue or discussion for security reports:

1. Open **Report a vulnerability**:
   <https://github.com/ibent95/local-dev-stack/security/advisories/new>
2. Include: what was affected (`docker-compose.yml` service, script, the
   dashboard, …), reproduction steps, impact, and any suggested fix.
3. You should get an acknowledgement with an initial assessment. Please allow
   reasonable time for a fix before any public disclosure; coordinated
   disclosure dates are agreed per report.

Good-faith testing is welcome: local runs, scanners (Semgrep/Trivy/ZAP ship
with the stack), and source review. Please avoid data destruction, attacking
services you don't own, and publishing exploit details before a fix ships.

**Scope.** This policy covers what *this repo* authors: the compose files,
scripts, base-image Dockerfiles, configs, and the dashboard PHP. For
vulnerabilities in the upstream projects the stack runs (Kafka, PostgreSQL,
Superset, Penpot, …), report them upstream too — we track the fix here by
bumping the pinned version in `.env.example` / `docker-compose.yml`.

## This is a development stack — by default it is not hardened

Everything below is **intentional, localhost-only, dev-only** behavior. It is
documented so nobody mistakes it for production posture, and so you know what
to change first if you expose the stack beyond your machine:

| Default | Where | Change to harden |
|---|---|---|
| DB passwords `root` / `app` (MySQL, MariaDB, Mongo, Postgres) | `docker-compose.yml` + `.env.example` | set `MYSQL_ROOT_PASSWORD`, `POSTGRES_PASSWORD`, `MONGO_*`, … in `.env` and re-create the volumes (`./lds.sh down -v`) |
| SQL Server `Lds-dev-2024!`, Oracle `Oracle-dev-2024!` | same | `MSSQL_SA_PASSWORD`, `ORACLE_PASSWORD` |
| Superset `admin` / `admin`, secret key `…change-me` | same | `SUPERSET_ADMIN`, `SUPERSET_PASSWORD`, `SUPERSET_SECRET_KEY` |
| DBX UI has **no password** (`DBX_DISABLE_PASSWORD=1`) | same | `DBX_DISABLE_PASSWORD=0` + `DBX_PASSWORD` |
| Vaultwarden admin token, Penpot/Instatic/RustFS/OpenWA secrets all `…change-me` | same | set each `*_SECRET_KEY` / `*_TOKEN` / `*_KEY` in `.env` |
| Centrifugo + Soketi run in dev `*_insecure` modes | same | set real keys, drop `--client_insecure` / `--admin_insecure` |
| The dashboard (`http://localhost`), and the Semgrep/Trivy/CRG/ZAP report viewers, have **no login** | `configs/web/dashboard`, compose | keep them local, or front them with auth at the proxy |
| Host ports publish on all interfaces (Docker default) | compose `ports:` | bind to loopback, e.g. `"127.0.0.1:4405:6379"` |
| HTTP by default (no TLS) | proxy | `LDS_ENABLE_HTTPS=true` + `./lds.sh certs` (wildcard `*.test`, mkcert preferred) |
| `*.test` resolves to `127.0.0.1` via dnsmasq | `configs/dns` | keep it local; don't delegate the zone publicly |

## Built-in security tooling

Use these before you ship a change (they are also the recommended pre-PR
scans — see [CONTRIBUTING.md](CONTRIBUTING.md)):

- `./lds.sh tools semgrep [path]` — SAST (SARIF viewer at `semgrep.test`)
- `./lds.sh tools trivy [path]` / `trivy image <name>` — CVE/SCA of files,
  dependencies and images (viewer at `trivy.test`)
- `./lds.sh up zap` — DAST against *running* apps (WebSwing UI at `zap.test`)
- `./lds.sh tools crg <path>` — AI code-intelligence graph (`crg.test`)
- Docker Hardened Images (`dhi.io`) as the base for services and `lds/*` bases

## Supply-chain & secret hygiene

- `.env` is **git-ignored**; `.env.example` intentionally documents the dev
  defaults above and contains no real secrets. The TLS material in
  `configs/proxy/certs/` is ignored by its own `.gitignore`; `data/*/*` and
  `*.db` are ignored too.
- JDBC driver jars are **not committed** (redistribution-restricted) — each
  developer downloads them per `assets/jdbc/README.md`.
- Third-party code is minimal and credited with licenses in
  [`docs/en/18-credits.md`](docs/en/18-credits.md); the vendored Parsedown copy
  ships with its own license file.
- Versions are pinned in `.env.example` / `docker-compose.yml`; Dependabot
  ([`.github/dependabot.yml`](.github/dependabot.yml)) opens monthly PRs for
  the Compose images, GitHub Actions, and the desktop/template manifests.
- We grep the tree for private keys and API tokens before releases; if you
  find one committed, report it privately per the section above (treat it as
  compromised regardless).
