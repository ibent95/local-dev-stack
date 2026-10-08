// LDS Desktop — frontend logic. Talks to the Rust backend through the Tauri
// global (`withGlobalTauri: true`), so there is no bundler/npm step.

const { invoke } = window.__TAURI__.core;
const { listen } = window.__TAURI__.event;

// --- profile chips ---------------------------------------------------------
const PROFILES = [
  "proxy", "mysql", "postgres", "mongo", "redis",
  "duckdb", "trino", "analytics", "tasks", "wiki",
  "semgrep", "zap", "trivy", "crg", "vaultwarden", "mail",
  "instatic", "erpnext", "playwright", "headlessx", "kafka",
];

// --- admin tool cards (label -> url) ---------------------------------------
const TOOLS = [
  ["phpCacheAdmin", "http://localhost:4500"],
  ["DBGate", "http://localhost:4501"],
  ["DrawDB", "http://localhost:4502"],
  ["Apache Hop", "http://localhost:4503"],
  ["Superset", "http://localhost:4504"],
  ["Metabase", "http://localhost:4541"],
  ["Hoppscotch", "http://localhost:4542"],
  ["Plane", "http://localhost:4543"],
  ["Semgrep", "http://localhost:4505"],
  ["Vaultwarden", "http://localhost:4506"],
  ["OpenWA", "http://localhost:4507"],
  ["RustFS", "http://localhost:4508"],
  ["ZAP", "http://localhost:4510"],
  ["Trivy", "http://localhost:4511"],
  ["Mailpit", "http://localhost:4513"],
  ["Penpot", "http://localhost:4515"],
  ["Analytics", "http://localhost:4520"],
  ["Tasks", "http://localhost:4522"],
  ["Wiki", "http://localhost:4524"],
  ["Playwright", "http://localhost:4526"],
  ["Instatic", "http://localhost:4528"],
  ["ERPNext", "http://localhost:4529"],
  ["code-review-graph", "http://localhost:4530"],
  ["Trino", "http://localhost:4451"],
  ["Dashboard", "http://localhost"],
];

// --- small helpers ---------------------------------------------------------

const $ = (sel) => document.querySelector(sel);

function setDot(state) {
  const dot = $("#status-dot");
  dot.className = "dot";
  if (state === "ok") dot.classList.add("ok");
  else if (state === "bad") dot.classList.add("bad");
}

// --- auto-refresh -----------------------------------------------------------

const AUTO_REFRESH_MS = 5000;
let refreshTimer = null;

function startAutoRefresh() {
  if (refreshTimer) return;
  refreshTimer = setInterval(refreshStatus, AUTO_REFRESH_MS);
}

function stopAutoRefresh() {
  if (refreshTimer) {
    clearInterval(refreshTimer);
    refreshTimer = null;
  }
}

function setAutoRefresh(on) {
  const btn = $("#auto-refresh");
  btn.classList.toggle("on", on);
  btn.textContent = on ? "⟳ Auto" : "⟳ Auto";
  if (on) startAutoRefresh();
  else stopAutoRefresh();
}

async function runLds(args) {
  const out = $("#run-output");
  out.textContent = `$ lds ${args.join(" ")}\n`;
  try {
    const result = await invoke("lds_run", { args });
    out.textContent += result;
  } catch (e) {
    out.textContent += `ERROR: ${e}\n`;
  }
  return out.textContent;
}

// --- profile chips ---------------------------------------------------------

function renderProfiles() {
  const wrap = $("#profile-buttons");
  wrap.innerHTML = "";
  for (const p of PROFILES) {
    const b = document.createElement("button");
    b.className = "off";
    b.textContent = p;
    b.addEventListener("click", async () => {
      const isOn = b.classList.toggle("on");
      await runLds([isOn ? "up" : "down", p]);
    });
    wrap.appendChild(b);
  }
}

// --- tool cards ------------------------------------------------------------

function renderTools() {
  const wrap = $("#tool-cards");
  wrap.innerHTML = "";
  for (const [name, url] of TOOLS) {
    const c = document.createElement("div");
    c.className = "card";
    c.innerHTML = `<div class="name"></div><div class="url"></div>`;
    c.querySelector(".name").textContent = name;
    c.querySelector(".url").textContent = url.replace(/^https?:\/\//, "");
    c.addEventListener("click", () => invoke("open_url", { url }));
    wrap.appendChild(c);
  }
}

// --- container status ------------------------------------------------------

async function refreshStatus() {
  setDot("");
  try {
    const rows = await invoke("stack_status");
    $("#last-updated").textContent =
      `updated ${new Date().toLocaleTimeString()}`;
    const tbody = $("#status-body");
    tbody.innerHTML = "";
    if (!rows.length) {
      tbody.innerHTML = `<tr><td colspan="5" class="muted">No containers — stack not started yet.</td></tr>`;
      setDot("bad");
      return;
    }
    let running = 0;
    const services = new Set();
    for (const r of rows) {
      const tr = document.createElement("tr");
      const state = r.state || "";
      const health = (r.health || "").toLowerCase();
      tr.innerHTML = `
        <td>${esc(r.service)}</td>
        <td class="muted">${esc(r.name)}</td>
        <td class="state-${state.toLowerCase()}">${esc(state)}</td>
        <td class="health-${health}">${esc(health || "—")}</td>
        <td class="muted">${esc(r.status || "")}</td>`;
      tbody.appendChild(tr);
      if (state === "running") running++;
      services.add(r.service);
    }
    setDot(running === rows.length ? "ok" : running > 0 ? "bad" : "bad");
    fillServiceSelect(services);
  } catch (e) {
    $("#status-body").innerHTML = `<tr><td colspan="5" class="muted">Cannot reach docker: ${esc(String(e))}</td></tr>`;
    setDot("bad");
  }
}

const esc = (s) =>
  String(s).replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

// --- logs ------------------------------------------------------------------

function fillServiceSelect(services) {
  const sel = $("#log-service");
  const current = sel.value;
  sel.innerHTML = "";
  for (const s of [...services].sort()) {
    const o = document.createElement("option");
    o.value = s;
    o.textContent = s;
    sel.appendChild(o);
  }
  if (current) sel.value = current;
}

async function tailLogs() {
  const service = $("#log-service").value;
  const lines = Number($("#log-lines").value) || 200;
  if (!service) return;
  const out = $("#log-output");
  out.textContent = `$ docker compose logs --tail ${lines} ${service}\n`;
  try {
    out.textContent += await invoke("service_logs", { service, lines });
  } catch (e) {
    out.textContent += `ERROR: ${e}\n`;
  }
}

// --- live log streaming -----------------------------------------------------

let streamListeners = [];

function clearStreamListeners() {
  for (const un of streamListeners) {
    try { un(); } catch { /* already unregistered */ }
  }
  streamListeners = [];
}

function setStreaming(on) {
  $("#log-stream").disabled = on;
  $("#log-stop").disabled = !on;
  $("#log-stream").textContent = on ? "Streaming…" : "Stream";
}

async function stopLogStream() {
  clearStreamListeners();
  try { await invoke("stop_log_stream"); } catch { /* stream may already be gone */ }
  setStreaming(false);
}

/** Live-follow a service: `docker compose logs --tail N --follow <service>`. */
async function startLogStream() {
  const service = $("#log-service").value;
  const lines = Number($("#log-lines").value) || 200;
  if (!service) return;
  await stopLogStream(); // switching services stops the previous stream

  const out = $("#log-output");
  out.textContent = `$ docker compose logs --tail ${lines} --follow ${service}\n`;

  streamListeners.push(await listen("log-chunk", (e) => {
    out.textContent += e.payload;
    out.scrollTop = out.scrollHeight;
  }));
  streamListeners.push(await listen("log-stream-end", () => {
    clearStreamListeners();
    setStreaming(false);
    out.textContent += "\n[log stream ended]\n";
    out.scrollTop = out.scrollHeight;
  }));

  try {
    await invoke("stream_logs", { service, lines });
    setStreaming(true);
  } catch (e) {
    out.textContent += `ERROR: ${e}\n`;
    setStreaming(false);
  }
}

// --- wiring -----------------------------------------------------------------

function init() {
  renderProfiles();
  renderTools();
  refreshStatus();

  // header actions
  $("#auto-refresh").addEventListener("click", (e) => {
    setAutoRefresh(!e.currentTarget.classList.contains("on"));
  });
  $("#refresh-btn").addEventListener("click", refreshStatus);
  $("#up-all").addEventListener("click", () => runLds(["up", "all"]));
  $("#down-all").addEventListener("click", () => runLds(["down"]));
  $("#hosts-btn").addEventListener("click", async () => {
    const out = $("#run-output");
    out.textContent = "$ lds hosts-sync\n";
    try {
      out.textContent += await invoke("hosts_sync");
    } catch (e) {
      out.textContent += `ERROR: ${e}\n`;
    }
  });

  // lifecycle commands (thin shell over the lds CLI — any command can be a button)
  $("#lc-start").addEventListener("click", () => runLds(["start"]));
  $("#lc-stop").addEventListener("click", () => runLds(["stop"]));
  $("#lc-down").addEventListener("click", () => runLds(["down"]));
  $("#lc-ps").addEventListener("click", () => runLds(["ps"]));
  $("#lc-logs").addEventListener("click", () => runLds(["logs"]));
  $("#lc-certs").addEventListener("click", () => runLds(["certs"]));
  $("#lc-db-init").addEventListener("click", () => runLds(["db", "init", "all"]));
  $("#lc-hosts").addEventListener("click", async () => {
    const out = $("#run-output");
    out.textContent = "$ lds hosts-sync\n";
    try {
      out.textContent += await invoke("hosts_sync");
    } catch (e) {
      out.textContent += `ERROR: ${e}\n`;
    }
  });

  // lds tools (path-scoped scanners)
  const toolPath = () => $("#tool-path").value.trim();
  const runTool = (tool) => {
    const p = toolPath();
    if (!p) {
      $("#run-output").textContent = `$ lds tools ${tool} <path>\nERROR: enter a path to scan.`;
      return;
    }
    runLds(["tools", tool, p]);
  };
  $("#tl-semgrep").addEventListener("click", () => runTool("semgrep"));
  $("#tl-trivy").addEventListener("click", () => runTool("trivy"));
  $("#tl-crg").addEventListener("click", () => runTool("crg"));
  $("#custom-up").addEventListener("click", () => {
    const p = $("#custom-profile").value.trim();
    if (p) runLds(["up", p]);
  });
  $("#custom-down").addEventListener("click", () => {
    const p = $("#custom-profile").value.trim();
    if (p) runLds(["down", p]);
  });
  $("#log-btn").addEventListener("click", tailLogs);
  $("#log-stream").addEventListener("click", startLogStream);
  $("#log-stop").addEventListener("click", stopLogStream);
  $("#log-clear").addEventListener("click", () => ($("#log-output").textContent = ""));

  startAutoRefresh();
}

window.addEventListener("DOMContentLoaded", init);
