<?php
// =============================================================================
// Kafka Connect connector builder.
// A guided form for creating connectors on EITHER worker, driven by that
// worker's own config schema (/connector-plugins/{class}/config/validate).
//
// The browser only ever talks to this page (same-origin → no CORS); this PHP
// proxies the REST calls to the workers over lds-network by service name.
// =============================================================================

const WORKERS = [
    'debezium' => ['label' => 'Debezium (CDC)',    'base' => 'http://connect-debezium:8083'],
    'generic'  => ['label' => 'Generic (apache)',  'base' => 'http://connect-generic:8083'],
];

function worker_base(string $w): ?string {
    return WORKERS[$w]['base'] ?? null;
}

/** Talk to a Connect worker's REST API. Returns [ok, status, data, error]. */
function connect_request(string $base, string $method, string $path, ?array $body = null): array {
    $ch = curl_init($base . $path);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CUSTOMREQUEST  => $method,
        CURLOPT_CONNECTTIMEOUT => 3,
        CURLOPT_TIMEOUT        => 12,
        CURLOPT_HTTPHEADER     => ['Accept: application/json', 'Content-Type: application/json'],
    ]);
    if ($body !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
    }
    $resp = curl_exec($ch);
    $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err  = curl_error($ch);
    curl_close($ch);
    if ($resp === false) {
        return ['ok' => false, 'status' => 0, 'data' => null, 'error' => $err ?: 'request failed'];
    }
    return [
        'ok'     => $code >= 200 && $code < 300,
        'status' => $code,
        'data'   => json_decode($resp, true),
        'raw'    => $resp,
        'error'  => null,
    ];
}

// --- JSON API (server-side proxy) -------------------------------------------
if (isset($_GET['api'])) {
    header('Content-Type: application/json');
    $api  = $_GET['api'];
    $wkey = $_GET['worker'] ?? '';
    $base = worker_base($wkey);

    if ($api === 'workers') {
        $out = [];
        foreach (WORKERS as $k => $w) {
            $r = connect_request($w['base'], 'GET', '/');
            $out[$k] = ['label' => $w['label'], 'up' => $r['ok'], 'version' => $r['data']['version'] ?? null];
        }
        echo json_encode($out);
        exit;
    }

    if ($base === null) {
        http_response_code(400);
        echo json_encode(['error' => "unknown worker '$wkey'"]);
        exit;
    }

    switch ($api) {
        case 'plugins':
            $r = connect_request($base, 'GET', '/connector-plugins');
            http_response_code($r['ok'] ? 200 : ($r['status'] ?: 502));
            echo json_encode($r['ok'] ? $r['data'] : ['error' => $r['error'] ?? 'worker unreachable']);
            break;

        case 'validate':
            $cfg   = json_decode(file_get_contents('php://input'), true) ?: [];
            $class = $cfg['connector.class'] ?? '';
            if ($class === '') {
                http_response_code(400);
                echo json_encode(['error' => 'connector.class is required']);
                break;
            }
            $r = connect_request($base, 'PUT',
                '/connector-plugins/' . rawurlencode($class) . '/config/validate', $cfg);
            http_response_code($r['ok'] ? 200 : ($r['status'] ?: 502));
            echo json_encode($r['ok'] ? $r['data']
                : ['error' => $r['error'] ?? 'validation request failed', 'detail' => $r['raw'] ?? null]);
            break;

        case 'connectors':
            $r = connect_request($base, 'GET', '/connectors?expand=status&expand=info');
            http_response_code($r['ok'] ? 200 : ($r['status'] ?: 502));
            echo json_encode($r['ok'] ? $r['data'] : ['error' => $r['error'] ?? 'worker unreachable']);
            break;

        case 'create':
            $body = json_decode(file_get_contents('php://input'), true) ?: [];
            $r = connect_request($base, 'POST', '/connectors', $body);
            http_response_code($r['status'] ?: 502);
            echo json_encode($r['data'] ?? ['error' => $r['error'] ?? 'create failed']);
            break;

        case 'delete':
            $name = $_GET['name'] ?? '';
            if ($name === '') {
                http_response_code(400);
                echo json_encode(['error' => 'name is required']);
                break;
            }
            $r = connect_request($base, 'DELETE', '/connectors/' . rawurlencode($name));
            http_response_code($r['status'] ?: 502);
            echo json_encode(['ok' => $r['ok'], 'status' => $r['status']]);
            break;

        default:
            http_response_code(404);
            echo json_encode(['error' => 'unknown api']);
    }
    exit;
}
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>connector builder · local-dev-stack</title>
<style>
  :root { color-scheme: light dark; }
  body { font: 15px/1.5 system-ui, sans-serif; max-width: 920px; margin: 2.5rem auto; padding: 0 1rem; }
  h1 { font-size: 1.4rem; } a { color: inherit; }
  h2 { font-size: 1rem; margin-top: 1.8rem; opacity: .7; text-transform: uppercase; letter-spacing: .05em; }
  .row { display: flex; flex-wrap: wrap; gap: .75rem; align-items: center; }
  select, input, textarea, button { font: inherit; padding: .4rem .55rem; border: 1px solid #8886; border-radius: 7px; }
  /* Field/FieldText are theme-aware system colors → dropdown options follow
     light/dark instead of rendering bright white. */
  select, input, textarea { background: Field; color: FieldText; }
  option { background: Field; color: FieldText; }
  button { cursor: pointer; border-color: #4a9; background: transparent; color: inherit; }
  button:hover { background: #4a91; }
  button.danger { border-color: #c55; } button.danger:hover { background: #c551; }
  button.primary { background: #2a8; color: #fff; border-color: #2a8; }
  label.fld { display: block; margin: .6rem 0; }
  label.fld .nm { font-weight: 600; font-size: .9rem; }
  label.fld .nm .req { color: #c55; } label.fld .nm code { opacity: .55; font-weight: 400; }
  label.fld .doc { font-size: .8rem; opacity: .6; margin: .1rem 0 .25rem; }
  label.fld input, label.fld select { width: 100%; box-sizing: border-box; }
  .err { color: #c55; font-size: .8rem; margin-top: .15rem; }
  .grp { border: 1px solid #8884; border-radius: 10px; padding: .4rem 1rem 1rem; margin: .8rem 0; }
  .grp > summary { font-weight: 600; cursor: pointer; padding: .5rem 0; }
  .badge { padding: .1rem .5rem; border-radius: 6px; font-size: .75rem; border: 1px solid #8886; }
  .up { color: #2a8; } .down { color: #c55; }
  .muted { opacity: .6; font-size: .85rem; }
  #result { white-space: pre-wrap; padding: .7rem; border-radius: 8px; border: 1px solid #8884; font-family: ui-monospace, monospace; font-size: .82rem; }
  pre.json { background: #8881; padding: .7rem; border-radius: 8px; overflow: auto; font-size: .8rem; }
  .conn { display: flex; justify-content: space-between; align-items: center; gap: .5rem; padding: .5rem .7rem; border: 1px solid #8884; border-radius: 8px; margin: .35rem 0; }
  .toolbar { gap: .5rem; margin: .5rem 0; }
</style>
</head>
<body>
  <h1>🔌 Connector builder <span class="muted">· <a href="/">control panel</a></span></h1>

  <div class="row" style="margin-top:1rem">
    <label>Worker
      <select id="worker"></select>
    </label>
    <label>Connector plugin
      <select id="plugin"><option value="">— pick a worker first —</option></select>
    </label>
    <button id="loadFields">Load fields</button>
  </div>

  <div id="builder" hidden>
    <h2>New connector</h2>
    <div class="row">
      <label style="flex:1">Connector name <span class="req" style="color:#c55">*</span>
        <input id="connName" placeholder="my-connector" style="width:100%">
      </label>
    </div>
    <div class="row toolbar">
      <label><input type="checkbox" id="showAdvanced"> show low-importance fields</label>
      <input id="filter" placeholder="filter fields…" style="flex:1">
    </div>
    <form id="fields"></form>
    <div class="row toolbar">
      <button id="validateBtn">Validate</button>
      <button id="previewBtn">Preview JSON</button>
      <button id="createBtn" class="primary">Create connector</button>
      <span id="validSummary" class="muted"></span>
    </div>
    <pre class="json" id="preview" hidden></pre>
    <div id="result" hidden></div>
  </div>

  <h2>Existing connectors</h2>
  <div id="existing" class="muted">—</div>

<script>
const $ = s => document.querySelector(s);
const api = (params) => location.pathname + '?' + new URLSearchParams(params);
let DEFS = [];          // current field definitions from validate
let CURRENT_CLASS = '';

async function jget(params)        { const r = await fetch(api(params)); return r.json(); }
async function jsend(params, body) { const r = await fetch(api(params), { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(body) }); return { status:r.status, data: await r.json() }; }

function worker() { return $('#worker').value; }

async function loadWorkers() {
  const w = await jget({ api:'workers' });
  $('#worker').innerHTML = Object.entries(w).map(([k,v]) =>
    `<option value="${k}">${v.label} ${v.up ? '●' : '○ (down)'}</option>`).join('');
  await loadPlugins();
}

async function loadPlugins() {
  $('#plugin').innerHTML = '<option value="">loading…</option>';
  const data = await jget({ api:'plugins', worker: worker() });
  if (!Array.isArray(data)) { $('#plugin').innerHTML = `<option value="">${data.error||'error'}</option>`; return; }
  data.sort((a,b)=> (a.class||'').localeCompare(b.class||''));
  $('#plugin').innerHTML = data.map(p => {
    const short = (p.class||'').split('.').pop();
    return `<option value="${p.class}">${short} — ${p.type||''}${p.version?(' · '+p.version):''}</option>`;
  }).join('');
  loadExisting();
}

function inputFor(def, val) {
  const name = def.name, type = def.type, rec = (val && val.recommended_values) || [];
  if (rec.length) {
    return `<select name="${name}"><option value=""></option>` +
      rec.map(r => `<option ${String(val.value)===String(r)?'selected':''}>${r}</option>`).join('') + `</select>`;
  }
  if (type === 'BOOLEAN') {
    const v = val ? String(val.value) : '';
    return `<select name="${name}"><option value=""></option>
      <option ${v==='true'?'selected':''}>true</option>
      <option ${v==='false'?'selected':''}>false</option></select>`;
  }
  const itype = type === 'PASSWORD' ? 'password'
    : (['INT','LONG','SHORT','DOUBLE','FLOAT'].includes(type) ? 'number' : 'text');
  const v = (val && val.value != null) ? String(val.value) : '';
  const ph = def.default_value != null ? ` placeholder="${String(def.default_value).replace(/"/g,'&quot;')}"` : '';
  return `<input type="${itype}" name="${name}" value="${v.replace(/"/g,'&quot;')}"${ph}>`;
}

function renderFields() {
  const showAdv = $('#showAdvanced').checked;
  const filter  = $('#filter').value.toLowerCase();
  // group -> [defs]
  const groups = {};
  for (const c of DEFS) {
    const d = c.definition, v = c.value;
    if (!d || d.name === 'name' || d.name === 'connector.class') continue;   // handled separately
    if (v && v.visible === false) continue;
    if (!showAdv && d.importance === 'LOW' && !d.required) continue;
    if (filter && !(d.name.toLowerCase().includes(filter) || (d.display_name||'').toLowerCase().includes(filter))) continue;
    const g = d.group || 'Other';
    (groups[g] ||= []).push(c);
  }
  const html = Object.entries(groups).map(([g, defs]) => {
    defs.sort((a,b)=> (a.definition.order ?? 999) - (b.definition.order ?? 999));
    const open = defs.some(c => c.definition.required || (c.value && c.value.errors && c.value.errors.length));
    const body = defs.map(c => {
      const d = c.definition, v = c.value;
      const req = d.required ? '<span class="req">*</span>' : '';
      const errs = (v && v.errors || []).map(e => `<div class="err">⚠ ${e}</div>`).join('');
      return `<label class="fld">
        <span class="nm">${d.display_name || d.name} ${req} <code>${d.name}</code></span>
        ${d.documentation ? `<div class="doc">${d.documentation}</div>` : ''}
        ${inputFor(d, v)}
        ${errs}
      </label>`;
    }).join('');
    return `<details class="grp" ${open?'open':''}><summary>${g} (${defs.length})</summary>${body}</details>`;
  }).join('');
  $('#fields').innerHTML = html || '<p class="muted">No matching fields.</p>';
}

function collectConfig() {
  const cfg = { 'connector.class': CURRENT_CLASS };
  const name = $('#connName').value.trim();
  if (name) cfg.name = name;
  for (const el of $('#fields').querySelectorAll('[name]')) {
    if (el.value !== '') cfg[el.name] = el.value;
  }
  return cfg;
}

async function loadFields() {
  CURRENT_CLASS = $('#plugin').value;
  if (!CURRENT_CLASS) return;
  $('#builder').hidden = false;
  const name = $('#connName').value.trim() || 'new-connector';
  const res = await jsend({ api:'validate', worker: worker() }, { 'connector.class': CURRENT_CLASS, name });
  if (!res.data || !res.data.configs) { showResult(res.data, false); return; }
  DEFS = res.data.configs;
  renderFields();
  $('#validSummary').textContent = '';
}

async function validate() {
  const res = await jsend({ api:'validate', worker: worker() }, collectConfig());
  if (res.data && res.data.configs) {
    DEFS = res.data.configs;
    renderFields();
    const n = res.data.error_count || 0;
    $('#validSummary').textContent = n ? `✗ ${n} error(s)` : '✓ valid';
    $('#validSummary').className = n ? 'down' : 'up';
  } else { showResult(res.data, false); }
}

async function create() {
  const name = $('#connName').value.trim();
  if (!name) { alert('Connector name is required.'); return; }
  const cfg = collectConfig(); cfg.name = name;
  const res = await jsend({ api:'create', worker: worker() }, { name, config: cfg });
  showResult(res.data, res.status >= 200 && res.status < 300);
  loadExisting();
}

function showResult(data, ok) {
  const el = $('#result');
  el.hidden = false;
  el.style.borderColor = ok ? '#2a8' : '#c55';
  el.textContent = (ok ? '✓ ' : '✗ ') + JSON.stringify(data, null, 2);
}

async function loadExisting() {
  const data = await jget({ api:'connectors', worker: worker() });
  const box = $('#existing');
  if (data.error) { box.innerHTML = `<span class="down">${data.error}</span>`; return; }
  const names = Object.keys(data);
  if (!names.length) { box.innerHTML = '<span class="muted">none on this worker</span>'; return; }
  box.innerHTML = names.map(n => {
    const st = data[n].status && data[n].status.connector && data[n].status.connector.state || '?';
    const cls = st === 'RUNNING' ? 'up' : (st === 'FAILED' ? 'down' : 'muted');
    return `<div class="conn"><span><b>${n}</b> <span class="badge ${cls}">${st}</span></span>
      <button class="danger" data-del="${n}">delete</button></div>`;
  }).join('');
  box.querySelectorAll('[data-del]').forEach(b => b.onclick = async () => {
    if (!confirm(`Delete connector "${b.dataset.del}" on the ${worker()} worker?`)) return;
    await fetch(api({ api:'delete', worker: worker(), name: b.dataset.del }), { method:'POST' });
    loadExisting();
  });
}

$('#worker').onchange   = loadPlugins;
$('#loadFields').onclick = loadFields;
$('#validateBtn').onclick = validate;
$('#createBtn').onclick   = create;
$('#showAdvanced').onchange = renderFields;
$('#filter').oninput      = renderFields;
$('#previewBtn').onclick  = () => { const p = $('#preview'); p.hidden = false; p.textContent = JSON.stringify({ name: $('#connName').value.trim(), config: collectConfig() }, null, 2); };

loadWorkers();
</script>
</body>
</html>
