# 08 · Templates

Templates live in `templates/`, named by **role** and **technology**:

- `svc-template-<x>` — an API (returns JSON).
- `web-template-<x>` — a web app with a UI (server-rendered or SPA).

And split **native vs framework**:

- **Native** (language's own web tech): `go` (net/http), `node` (http module),
  `python` (http.server), `java` (Servlet); `rust` uses axum (no stdlib HTTP).
- **Frameworks** (separate templates): `springboot`, `express`, `flask`,
  `fastapi`, `django`, `laravel`, `angular`, `react` (+ more as added).

Most ship as a `svc-`+`web-` pair. **Code-included** templates run as-is;
**scaffolded** ones generate the real framework into `./src` via its own CLI on
first use (each template's README has the one-line command).

See `templates/README.md` for the full table and per-template READMEs for run
instructions.
