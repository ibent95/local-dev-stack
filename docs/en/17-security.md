# 17 · Security

Security posture of Local Dev Stack: how to report issues, what the stack does
**not** protect by default (it is a localhost dev environment), and what to
run before you ship a change. The full policy lives at the repo root in
[`SECURITY.md`](https://github.com/ibent95/local-dev-stack/blob/master/SECURITY.md).

## Reporting a vulnerability

Use **GitHub private vulnerability reporting**, never a public issue:

**Report a vulnerability** →
<https://github.com/ibent95/local-dev-stack/security/advisories/new>

Include what was affected (compose service, script, dashboard, docs),
reproduction steps, impact, and any suggested fix. You will get an
acknowledgement and an initial assessment; disclosure dates are agreed per
report. Good-faith testing (local runs, the bundled scanners, source review)
is welcome — no data destruction, no attacking services you don't own.

**Scope**: this repo's compose files, scripts, Dockerfiles, configs and
dashboard PHP. Vulnerabilities in upstream projects (Kafka, Superset,
Penpot, …) should also go upstream — we track the fix by bumping the pin in
`.env.example` / `docker-compose.yml`.

**Supported versions**: only `master`. There are no release branches; update
your checkout before reporting.

## Dev-only defaults (not hardened on purpose)

Everything below is **intentional, localhost-only** behavior — documented so
nobody mistakes it for production posture, and so you know what to change
first if the stack ever leaves your machine:

<table>
<thead><tr><th>Default</th><th>Where</th><th>Harden by</th></tr></thead>
<tbody>
<tr><td>DB passwords <code>root</code> / <code>app</code> (MySQL, MariaDB, Mongo, Postgres)</td><td><code>docker-compose.yml</code> + <code>.env.example</code></td><td>set <code>MYSQL_ROOT_PASSWORD</code>, <code>POSTGRES_PASSWORD</code>, <code>MONGO_*</code> in <code>.env</code>, then <code>./lds.sh down -v</code> to re-create volumes</td></tr>
<tr><td>SQL Server <code>Lds-dev-2024!</code>, Oracle <code>Oracle-dev-2024!</code></td><td>same</td><td><code>MSSQL_SA_PASSWORD</code>, <code>ORACLE_PASSWORD</code></td></tr>
<tr><td>Superset <code>admin</code>/<code>admin</code> + <code>…change-me</code> secret key</td><td>same</td><td><code>SUPERSET_ADMIN</code>, <code>SUPERSET_PASSWORD</code>, <code>SUPERSET_SECRET_KEY</code></td></tr>
<tr><td>DBX UI with <b>no password</b> (<code>DBX_DISABLE_PASSWORD=1</code>)</td><td>same</td><td><code>DBX_DISABLE_PASSWORD=0</code> + <code>DBX_PASSWORD</code></td></tr>
<tr><td>Vaultwarden / Penpot / Instatic / RustFS / OpenWA secrets all <code>…change-me</code></td><td>same</td><td>set each <code>*_SECRET_KEY</code>, <code>*_TOKEN</code>, <code>*_KEY</code> in <code>.env</code></td></tr>
<tr><td>Centrifugo + Soketi run in dev <code>*_insecure</code> modes</td><td>same</td><td>real keys; drop <code>--client_insecure</code> / <code>--admin_insecure</code></td></tr>
<tr><td>Dashboard and the Semgrep/Trivy/CRG/ZAP viewers have <b>no login</b></td><td>dashboard + compose</td><td>keep them local, or put auth at the proxy</td></tr>
<tr><td>Host ports publish on all interfaces (Docker default)</td><td>compose <code>ports:</code></td><td>bind loopback: <code>"127.0.0.1:4405:6379"</code></td></tr>
<tr><td>HTTP only (no TLS)</td><td>proxy</td><td><code>LDS_ENABLE_HTTPS=true</code> + <code>./lds.sh certs</code></td></tr>
<tr><td><code>*.test</code> resolves to <code>127.0.0.1</code></td><td><code>configs/dns</code></td><td>keep it local; don't delegate the zone publicly</td></tr>
</tbody>
</table>

## Built-in tooling

```bash
./lds.sh tools semgrep [path]     # SAST - SARIF viewer at semgrep.test
./lds.sh tools trivy [path]       # CVE/SCA of files, deps and images
./lds.sh tools trivy image <name> # same, for one image
./lds.sh up zap                   # DAST against running apps (zap.test)
./lds.sh tools crg <path>         # AI code-intelligence graph (crg.test)
```

These double as the recommended pre-PR scans (see
[16 · Contributing](16-contributing.md)).

## Supply chain & secret hygiene

- `.env` is **git-ignored**; `.env.example` holds documented dev defaults and
  no real secrets. `configs/proxy/certs/` is ignored by its own
  `.gitignore`; `data/*/*` and `*.db` are ignored too.
- JDBC driver jars are **never committed** (redistribution-restricted) — each
  developer downloads them per `assets/jdbc/README.md`.
- Service and base images build on **Docker Hardened Images** (`dhi.io`);
  third-party components and licenses are listed in
  [18 · Credits](18-credits.md).
- Versions are pinned in `.env.example`; Dependabot
  ([`.github/dependabot.yml`](https://github.com/ibent95/local-dev-stack/blob/master/.github/dependabot.yml))
  opens monthly PRs for Compose images with literal tags, GitHub Actions, and
  the desktop/stack-app manifests.
- The tree is grepped for private keys and API tokens before releases; if you
  find one committed, report it privately (treat it as compromised anyway).
