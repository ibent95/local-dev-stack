# 04 · Commands (the `lds` wrapper)

`lds` is a single entrypoint that dispatches to the scripts in `scripts/`. Use
`./lds.sh <cmd>` (bash) or `lds.bat <cmd>` (Windows cmd).

| Command | What it does |
|---------|--------------|
| `init` | create the shared `lds-network` network (once) |
| `network [status\|create\|rm\|reset]` | manage the shared `lds-network` (status = show + attached containers) |
| `build-bases [--force\|--push]` | build the `lds/*` base images |
| `up [profiles...]` | start profiles (no args → profiles whose `LDS_ENABLE_*` toggle is `true`, else `all`); auto-builds `lds/php` if needed |
| `stop` | stop running containers but **keep** them (fast resume with `up`; data untouched) |
| `down [-v]` | remove containers (`-v` also wipes data volumes) |
| `logs [service]` | tail logs (all, or one service) |
| `ps` | status of all services |
| `kafka <sub>` | `topics` · `connect-plugin [--generic] <name>` · `register-connectors` · `init` (topics + connectors) |
| `db <sub>` | `init [mysql\|mongo\|all]` (create the `app` db/users) · `seed` (DBGate connections) |
| `tools <sub>` | `semgrep [path]` — run a Semgrep scan; view it at `semgrep.test` (`up semgrep`) |
| `certs [--force]` | mint the wildcard `*.test` dev TLS cert (for the `LDS_ENABLE_HTTPS` overlay) |
| `hosts-sync` | write projects + tool hosts into the hosts file (DNS fallback), grouped by category |
| `build-php [--push]` | (re)build just the PHP service image |
| `help` | list commands |

> The grouped subcommands replace the old flat names, which **still work as
> aliases**: `kafka-topics`, `register-connectors`, `connect-plugin`,
> `mysql-init`, `mongo-init`, `dbgate-seed`.

Each script also exists standalone in `scripts/run/` and `scripts/build/` in
both `.sh` and `.bat` form.

## Daily workflow

- Start what you need: `./lds.sh up mysql redis`
- Logs: `./lds.sh logs kafka-broker` · Status: `./lds.sh ps`
- Stop: `./lds.sh down` (keep data) or `./lds.sh down -v` (wipe data)
- After a version/dep bump: `./lds.sh build-bases --force`
