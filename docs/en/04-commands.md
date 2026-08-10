# 04 · Commands (the `lds` wrapper)

`lds` is a single entrypoint that dispatches to the scripts in `scripts/`. Use
`./lds.sh <cmd>` (bash) or `lds.bat <cmd>` (Windows cmd).

<table>
<thead>
<tr>
<th>Command</th>
<th>What it does</th>
</tr>
</thead>
<tbody>
<tr>
<td>`init`</td>
<td>create the shared `lds-network` network (once)</td>
</tr>
<tr>
<td>`network [status\|create\|rm\|reset]`</td>
<td>manage the shared `lds-network` (status = show + attached containers)</td>
</tr>
<tr>
<td>`build-bases [--force\|--push]`</td>
<td>build the `lds/*` base images</td>
</tr>
<tr>
<td>`up [profiles...]`</td>
<td>start profiles (no args → profiles whose `LDS_ENABLE_*` toggle is `true`, else `all`); auto-builds `lds/php` if needed</td>
</tr>
<tr>
<td>`stop`</td>
<td>stop running containers but **keep** them (fast resume with `up`; data untouched)</td>
</tr>
<tr>
<td>`down [-v]`</td>
<td>remove containers (`-v` also wipes data volumes)</td>
</tr>
<tr>
<td>`logs [service]`</td>
<td>tail logs (all, or one service)</td>
</tr>
<tr>
<td>`ps`</td>
<td>status of all services</td>
</tr>
<tr>
<td>`kafka &lt;sub&gt;`</td>
<td>`topics` · `connect-plugin [--generic] &lt;name&gt;` · `register-connectors` · `init` (topics + connectors)</td>
</tr>
<tr>
<td>`db &lt;sub&gt;`</td>
<td>`init [mysql\|postgres\|mongo\|all]` (create default db/users + optional tool specs via `*_INIT_SPECS`) · `seed` (DBGate connections)</td>
</tr>
<tr>
<td>`tools &lt;sub&gt;`</td>
<td>`semgrep [path\|clear]` — run/clear Semgrep report · `trivy [path\|clear]` / `trivy image &lt;name&gt;` — run/clear Trivy report; view at `semgrep.test` / `trivy.test` · `playwright &lt;…&gt;` — alias for `lds playwright` (see below)</td>
</tr>
<tr>
<td>`playwright &lt;sub&gt;`</td>
<td>`init &lt;name&gt; [url]` — scaffold an E2E project · `run &lt;name&gt; [args…]` — run tests · `codegen [url]` — record tests · `ui &lt;name&gt;` — interactive UI Mode in the browser (:4487) · `shell` — runner shell · `report` — viewer URL (`playwright.test` / :4486); alias: `e2e`</td>
</tr>
<tr>
<td>`certs [--force]`</td>
<td>mint the wildcard `*.test` dev TLS cert (for the `LDS_ENABLE_HTTPS` overlay)</td>
</tr>
<tr>
<td>`hosts-sync`</td>
<td>write projects + tool hosts into the hosts file (DNS fallback), grouped by category</td>
</tr>
<tr>
<td>`env-sync [--dry-run]`</td>
<td>sync `.env` to `.env.example` — keeps your values, adds missing variables at the example's position, preserves `.env`-only vars (auto-run by `up`)</td>
</tr>
<tr>
<td>`build-php [--push]`</td>
<td>(re)build just the PHP service image</td>
</tr>
<tr>
<td>`help`</td>
<td>list commands</td>
</tr>
</tbody>
</table>

> The grouped subcommands replace the old flat names, which **still work as
> aliases**: `kafka-topics`, `register-connectors`, `connect-plugin`,
> `mysql-init`, `postgres-init`, `mongo-init`, `dbgate-seed`.

Each script also exists standalone in `scripts/run/` and `scripts/build/` in
both `.sh` and `.bat` form.

## Daily workflow

- Start what you need: `./lds.sh up mysql redis`
- Logs: `./lds.sh logs kafka-broker` · Status: `./lds.sh ps`
- Stop: `./lds.sh down` (keep data) or `./lds.sh down -v` (wipe data)
- After a version/dep bump: `./lds.sh build-bases --force`
