<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="csrf-token" content="{{ csrf_token() }}">
<title>LDS Desktop — NativePHP</title>
<style>
  :root { color-scheme: light; }
  * { box-sizing: border-box; }
  body {
    margin: 0; font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    background: #f1f5f9; color: #0f172a; height: 100vh; display: flex; flex-direction: column;
  }
  header {
    display: flex; align-items: center; gap: 8px; flex-wrap: wrap;
    padding: 10px 14px; background: #fff; border-bottom: 1px solid #cbd5e1;
  }
  header h1 { font-size: 15px; margin: 0 8px 0 0; }
  .spacer { flex: 1; }
  .muted { color: #94a3b8; font-size: 11px; }
  button, .chip {
    font: inherit; font-size: 12px; padding: 5px 10px; border-radius: 6px;
    border: 1px solid #cbd5e1; background: #f8fafc; cursor: pointer; color: #0f172a;
  }
  button:hover:not(:disabled) { background: #e2e8f0; }
  button:disabled { opacity: .55; cursor: not-allowed; }
  button.primary { background: #0c4a6e; border-color: #0c4a6e; color: #fff; }
  button.primary:hover:not(:disabled) { background: #155e75; }
  button.on { background: #0c4a6e; border-color: #0c4a6e; color: #fff; }
  nav { display: flex; gap: 4px; padding: 8px 14px 0; background: #fff; border-bottom: 1px solid #cbd5e1; }
  nav button {
    border-radius: 6px 6px 0 0; border: 1px solid transparent; background: #e2e8f0; color: #475569;
  }
  nav button.active { background: #fff; border-color: #cbd5e1; border-bottom-color: #fff; font-weight: 600; color: #0f172a; }
  main { flex: 1; overflow: auto; padding: 12px 14px; }
  section { display: none; }
  section.active { display: block; }
  .row { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; margin-bottom: 10px; }
  .chips { display: flex; gap: 6px; flex-wrap: wrap; }
  .chips .chip { border-radius: 999px; }
  .chips .chip.on { background: #0c4a6e; border-color: #0c4a6e; color: #fff; }
  input[type=text], input[type=number] {
    font: inherit; font-size: 12px; padding: 5px 8px; border: 1px solid #cbd5e1; border-radius: 6px;
  }
  .cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 8px; }
  .card { text-align: left; padding: 8px 10px; }
  .card b { display: block; font-size: 12.5px; }
  .card span { font-size: 11px; color: #64748b; }
  table { width: 100%; border-collapse: collapse; font-size: 12.5px; background: #fff; border-radius: 6px; overflow: hidden; }
  th { text-align: left; padding: 6px 8px; border-bottom: 2px solid #e2e8f0; background: #f8fafc; }
  td { padding: 5px 8px; border-bottom: 1px solid #f1f5f9; }
  pre.log {
    background: #0f172a; color: #e2e8f0; padding: 10px; border-radius: 6px; font-size: 12px;
    margin: 0; min-height: 120px; max-height: 100%; overflow: auto; white-space: pre-wrap;
  }
  #tab-output pre.log { height: calc(100vh - 190px); }
  #tab-logs pre.log { height: calc(100vh - 230px); }
  .err { color: #b00020; font-size: 12px; }
  footer { padding: 6px 14px; border-top: 1px solid #cbd5e1; background: #fff; }
</style>
</head>
<body>

<header>
  <h1>LDS Desktop — NativePHP</h1>
  <button id="hide-panel" title="Hide the panel to the tray (tray Quit exits)">Hide to tray</button>
  <button id="hosts-sync" title="lds hosts-sync — write *.test hosts (elevated)">hosts-sync</button>
  <button id="start-all" class="primary" title="lds up all">Start all</button>
  <button id="stop-all" title="lds down">Stop all</button>
  <button id="refresh" title="Refresh container status now">⟳ Refresh</button>
  <button id="auto-refresh" class="on" title="Toggle auto-refresh (every 5s)">Auto-refresh: ON</button>
  <span class="spacer"></span>
  <span id="updated" class="muted"></span>
</header>

<nav>
  <button data-tab="lifecycle" class="active">Lifecycle</button>
  <button data-tab="profiles">Profiles</button>
  <button data-tab="tools">Tools</button>
  <button data-tab="containers">Containers</button>
  <button data-tab="logs">Logs</button>
  <button data-tab="output">Output</button>
</nav>

<main>
  <div id="error-line" class="err"></div>

  <section id="tab-lifecycle" class="active">
    <div class="row" id="lifecycle-buttons"></div>
  </section>

  <section id="tab-profiles">
    <div class="chips" id="profile-chips"></div>
    <div class="row" style="margin-top: 12px;">
      <input id="custom-profile" type="text" placeholder="custom profile" style="min-width: 220px;">
      <button id="custom-up">Up</button>
      <button id="custom-down">Down</button>
    </div>
  </section>

  <section id="tab-tools">
    <div class="row">
      <span class="muted">lds tools:</span>
      <input id="tool-path" type="text" placeholder="path to scan (project dir)" style="flex: 1; min-width: 240px;">
      <button id="tool-semgrep" class="primary">semgrep</button>
      <button id="tool-trivy" class="primary">trivy</button>
      <button id="tool-crg" class="primary">crg</button>
    </div>
    <div class="cards" id="tool-cards"></div>
  </section>

  <section id="tab-containers">
    <table>
      <thead>
        <tr><th>Service</th><th>Container</th><th>State</th><th>Health</th><th>Status</th></tr>
      </thead>
      <tbody id="container-rows">
        <tr><td colspan="5" class="muted">Loading…</td></tr>
      </tbody>
    </table>
  </section>

  <section id="tab-logs">
    <div class="row">
      <input id="log-service" type="text" value="redis" style="width: 160px;" placeholder="service">
      <input id="log-lines" type="number" value="200" min="10" max="5000" step="10" style="width: 80px;">
      <button id="log-stream" class="primary">Stream</button>
      <button id="log-stop" disabled>Stop</button>
      <button id="log-tail">Tail</button>
      <button id="log-clear">Clear</button>
      <span id="stream-state" class="muted"></span>
    </div>
    <pre id="log-output" class="log"></pre>
  </section>

  <section id="tab-output">
    <pre id="run-output" class="log"></pre>
    <div class="row" style="margin-top: 8px; justify-content: flex-end;">
      <button id="output-clear">Clear</button>
    </div>
  </section>
</main>

<footer class="muted">
  Close is disabled — hide the panel to the tray; Quit from the tray exits · auto-refresh every 5s · the lds CLI is the single source of truth
</footer>

<script>
(function () {
  "use strict";

  // ---------------------------------------------------------------- helpers
  const $ = (sel) => document.querySelector(sel);
  const csrf = document.querySelector('meta[name="csrf-token"]').content;
  let busy = false;
  let autoRefresh = true;
  let streamTimer = null;
  const profilesOn = new Set();

  async function api(path, body) {
    const opts = {
      method: body === undefined ? "GET" : "POST",
      headers: {
        "Accept": "application/json",
        "X-CSRF-TOKEN": csrf,
        "X-Requested-With": "XMLHttpRequest",
      },
    };
    if (body !== undefined) {
      opts.headers["Content-Type"] = "application/json";
      opts.body = JSON.stringify(body);
    }
    const res = await fetch(path, opts);
    const text = await res.text();
    let data = {};
    try { data = text ? JSON.parse(text) : {}; } catch (e) { data = { ok: res.ok, output: text }; }
    return data;
  }

  function setBusy(on, label) {
    busy = on;
    document.querySelectorAll("button").forEach((b) => {
      if (b.dataset.always !== "1") b.disabled = on || b.dataset.wasDisabled === "1";
    });
    // Buttons that are disabled by design when not streaming stay disabled.
    $("#log-stop").disabled = on || !streamTimer;
    if (on && label) {
      $("#updated").textContent = label;
    }
  }

  function showError(msg) {
    $("#error-line").textContent = msg || "";
  }

  function appendOutput(text) {
    const out = $("#run-output");
    out.textContent += text;
    out.scrollTop = out.scrollHeight;
  }

  // ------------------------------------------------------------ lds runner
  async function runLds(args) {
    if (busy) return;
    const cmd = "lds " + args.join(" ");
    appendOutput("$ " + cmd + "\n");
    setBusy(true, "running " + cmd + " …");
    showError("");
    try {
      const data = await api("/api/lds", { args });
      appendOutput((data.output || "") + "\n");
      if (!data.ok) showError(cmd + " exited with code " + data.code);
    } catch (e) {
      appendOutput("ERROR: " + e + "\n");
      showError(String(e));
    } finally {
      setBusy(false);
      refreshStatus();
    }
  }

  // ---------------------------------------------------------- status polling
  async function refreshStatus() {
    if (busy) return;
    try {
      const data = await api("/api/status");
      renderContainers(data.rows || []);
      $("#updated").textContent = "updated " + (data.updated || "");
      showError(data.ok ? "" : (data.error || ""));
    } catch (e) {
      showError(String(e));
    }
  }

  function renderContainers(rows) {
    const body = $("#container-rows");
    if (!rows.length) {
      body.innerHTML = '<tr><td colspan="5" class="muted">No containers — start a profile.</td></tr>';
      return;
    }
    body.innerHTML = rows.map((r) => "<tr><td>" + esc(r.Service) + "</td><td>" + esc(r.Name) +
      "</td><td>" + esc(r.State) + "</td><td>" + esc(r.Health) + "</td><td>" + esc(r.Status) +
      "</td></tr>").join("");
  }

  function esc(v) {
    return String(v == null ? "" : v).replace(/[&<>"']/g, (c) => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
    }[c]));
  }

  // ---------------------------------------------------------------- tabs
  document.querySelectorAll("nav button").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.querySelectorAll("nav button").forEach((b) => b.classList.toggle("active", b === btn));
      document.querySelectorAll("main section").forEach((s) => {
        s.classList.toggle("active", s.id === "tab-" + btn.dataset.tab);
      });
    });
  });

  // ------------------------------------------------------------ lifecycle
  const LIFECYCLE = [
    ["lds start", ["start"]],
    ["lds stop", ["stop"]],
    ["lds down", ["down"]],
    ["lds ps", ["ps"]],
    ["lds logs", ["logs"]],
    ["certs", ["certs"]],
    ["db init all", ["db", "init", "all"]],
    ["sonar", ["sonar"]],
    ["openvas start", ["openvas", "start"]],
    ["openvas stop", ["openvas", "stop"]],
    ["backup", ["backup"]],
  ];
  $("#lifecycle-buttons").innerHTML = LIFECYCLE.map(([label], i) =>
    '<button data-lifecycle="' + i + '"' + (i === 0 ? ' class="primary"' : "") + ">" + esc(label) + "</button>"
  ).join("");
  document.querySelectorAll("[data-lifecycle]").forEach((btn) => {
    btn.addEventListener("click", () => runLds(LIFECYCLE[Number(btn.dataset.lifecycle)][1]));
  });

  // ------------------------------------------------------------- profiles
  const PROFILES = [
    "analytics", "centrifugo", "crg", "dbx", "drawdb", "drawio", "duckdb",
    "erpnext", "headlessx", "hop", "hoppscotch", "imgcompress", "instatic",
    "kafka", "keycloak", "lldap", "mail", "mariadb", "memcached", "metabase",
    "mongo", "monitoring", "mqtt", "mssql", "mysql", "openldap", "openwa",
    "oracle", "penpot", "php", "phpcacheadmin", "plane", "playwright",
    "postgres", "proxy", "rabbitmq", "redis", "rustfs", "search", "semgrep",
    "snapotter", "soketi", "sonarqube", "superset", "tasks", "trino", "trivy",
    "valkey", "vaultwarden", "wiki", "zap",
  ];
  $("#profile-chips").innerHTML = PROFILES.map((p) =>
    '<button class="chip" data-profile="' + p + '">' + esc(p) + "</button>"
  ).join("");
  document.querySelectorAll("[data-profile]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const name = btn.dataset.profile;
      const op = profilesOn.has(name) ? "down" : "up";
      if (op === "up") profilesOn.add(name); else profilesOn.delete(name);
      btn.classList.toggle("on", op === "up");
      runLds([op, name]);
    });
  });
  $("#custom-up").addEventListener("click", () => {
    const p = $("#custom-profile").value.trim();
    if (p) runLds(["up", p]);
  });
  $("#custom-down").addEventListener("click", () => {
    const p = $("#custom-profile").value.trim();
    if (p) runLds(["down", p]);
  });

  // --------------------------------------------------------- admin tools
  const TOOLS = [
    ["phpCacheAdmin", "http://localhost:4500"],
    ["DBX", "http://localhost:4501"],
    ["DrawDB", "http://localhost:4502"],
    ["Apache Hop", "http://localhost:4503"],
    ["Superset", "http://localhost:4504"],
    ["Metabase", "http://localhost:4541"],
    ["Hoppscotch", "http://localhost:4542"],
    ["Plane", "http://localhost:4543"],
    ["Semgrep", "http://localhost:4505"],
    ["Vaultwarden", "http://localhost:4506"],
    ["OpenWA", "http://localhost:4507"],
    ["RustFS", "http://localhost:4509"],
    ["ZAP", "http://localhost:4510"],
    ["Trivy", "http://localhost:4511"],
    ["Mailpit", "http://localhost:4513"],
    ["Penpot", "http://localhost:4518"],
    ["Analytics", "http://localhost:4521"],
    ["Tasks", "http://localhost:4523"],
    ["Wiki", "http://localhost:4525"],
    ["Playwright", "http://localhost:4526"],
    ["Instatic", "http://localhost:4528"],
    ["ERPNext", "http://localhost:4529"],
    ["code-review-graph", "http://localhost:4530"],
    ["Trino", "http://localhost:4451"],
    ["RabbitMQ", "http://localhost:4411"],
    ["Kafka UI", "http://localhost:4424"],
    ["Centrifugo", "http://localhost:4441"],
    ["MQTTX", "http://localhost:4444"],
    ["HeadlessX", "http://localhost:4515"],
    ["Grafana", "http://localhost:4532"],
    ["Prometheus", "http://localhost:4533"],
    ["draw.io", "http://localhost:4535"],
    ["SnapOtter", "http://localhost:4538"],
    ["ImgCompress", "http://localhost:4539"],
    ["SonarQube", "http://localhost:4544"],
    ["Meilisearch", "http://localhost:4545"],
    ["Keycloak", "http://localhost:4546"],
    ["Loki", "http://localhost:4547"],
    ["Tempo", "http://localhost:4548"],
    ["OpenVAS", "http://localhost:9392"],
    ["Dashboard", "http://localhost"],
  ];
  $("#tool-cards").innerHTML = TOOLS.map(([name, url]) =>
    '<button class="card" data-url="' + esc(url) + '"><b>' + esc(name) + "</b><span>" + esc(url) + "</span></button>"
  ).join("");
  document.querySelectorAll("[data-url]").forEach((btn) => {
    btn.addEventListener("click", () => api("/api/open", { url: btn.dataset.url }));
  });

  function runTool(tool) {
    const p = $("#tool-path").value.trim();
    if (!p) {
      appendOutput("$ lds tools " + tool + " <path>\nERROR: enter a path to scan.\n");
      showError("enter a path to scan");
      return;
    }
    runLds(["tools", tool, p]);
  }
  $("#tool-semgrep").addEventListener("click", () => runTool("semgrep"));
  $("#tool-trivy").addEventListener("click", () => runTool("trivy"));
  $("#tool-crg").addEventListener("click", () => runTool("crg"));

  // ----------------------------------------------------------------- logs
  const logService = () => $("#log-service").value.trim();
  const logLines = () => Math.max(10, Math.min(5000, Number($("#log-lines").value) || 200));

  async function tailLogs() {
    const out = $("#log-output");
    if (busy) return;
    if (!logService()) { showError("enter a service name"); return; }
    appendOutput("$ docker compose logs --tail " + logLines() + " " + logService() + "\n");
    setBusy(true, "tailing logs …");
    try {
      const data = await api("/api/logs/tail", { service: logService(), lines: logLines() });
      out.textContent = data.output || "";
      out.scrollTop = out.scrollHeight;
      showError(data.ok ? "" : (data.error || ""))
    } catch (e) {
      showError(String(e));
    } finally {
      setBusy(false);
    }
  }

  async function startStream() {
    if (!logService()) { showError("enter a service name"); return; }
    $("#log-output").textContent = "[streaming docker compose logs --follow " + logService() + "]\n";
    const data = await api("/api/logs/stream/start", { service: logService(), lines: logLines() });
    if (!data.ok) { showError(data.error || "failed to start stream"); return; }
    $("#stream-state").textContent = "streaming " + logService();
    $("#log-stop").disabled = false;
    if (streamTimer) clearInterval(streamTimer);
    streamTimer = setInterval(async () => {
      try {
        const read = await api("/api/logs/stream/read");
        if (read.ok && read.output) {
          const out = $("#log-output");
          out.textContent = read.output;
          out.scrollTop = out.scrollHeight;
        }
      } catch (e) { /* transient while the server is busy */ }
    }, 1200);
  }

  async function stopStream() {
    if (streamTimer) { clearInterval(streamTimer); streamTimer = null; }
    $("#stream-state").textContent = "";
    $("#log-stop").disabled = true;
    await api("/api/logs/stream/stop", {});
  }

  $("#log-stream").addEventListener("click", startStream);
  $("#log-stop").addEventListener("click", stopStream);
  $("#log-tail").addEventListener("click", tailLogs);
  $("#log-clear").addEventListener("click", () => { $("#log-output").textContent = ""; });
  $("#output-clear").addEventListener("click", () => { $("#run-output").textContent = ""; });

  // ------------------------------------------------------- header actions
  $("#hosts-sync").addEventListener("click", async () => {
    if (busy) return;
    appendOutput("$ lds hosts-sync\n");
    setBusy(true, "hosts-sync (UAC) …");
    try {
      const data = await api("/api/hosts-sync", {});
      appendOutput((data.output || "") + "\n");
      if (!data.ok) showError("hosts-sync failed");
    } catch (e) {
      appendOutput("ERROR: " + e + "\n");
    } finally {
      setBusy(false);
    }
  });

  $("#start-all").addEventListener("click", () => runLds(["up", "all"]));
  $("#stop-all").addEventListener("click", () => runLds(["down"]));
  $("#refresh").addEventListener("click", refreshStatus);
  $("#auto-refresh").addEventListener("click", (e) => {
    autoRefresh = !autoRefresh;
    e.currentTarget.textContent = "Auto-refresh: " + (autoRefresh ? "ON" : "OFF");
    e.currentTarget.classList.toggle("on", autoRefresh);
  });
  $("#hide-panel").addEventListener("click", () => api("/api/window/hide", {}));

  // Tray "Refresh status" dispatches App\Events\TrayRefreshRequested, which
  // NativePHP forwards to this window (Native\Desktop\Events\* are not
  // forwarded — Electron broadcasts those itself).
  if (window.Native && typeof window.Native.on === "function") {
    window.Native.on("App\\Events\\TrayRefreshRequested", () => refreshStatus());
  }

  // ------------------------------------------------------------- polling
  setInterval(() => { if (autoRefresh) refreshStatus(); }, 5000);
  refreshStatus();
})();
</script>
</body>
</html>
