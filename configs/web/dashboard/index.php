<?php
// Cheap liveness endpoint for the php healthcheck — returns immediately WITHOUT
// running the service probes below. (Probing the full dashboard can take seconds
// when services are down, which would otherwise fail the healthcheck's timeout.)
if (isset($_GET['health'])) { header('Content-Type: text/plain'); echo 'ok'; exit; }

// Control panel — lists every project folder under /var/www and links to its
// auto-generated <folder>.test virtual host. (Devilbox-style intranet.)

$root = '/var/www';
$tld  = 'test';

$projects = [];
foreach (glob($root . '/*', GLOB_ONLYDIR) as $dir) {
    $name = basename($dir);
    // Detect docroot for display.
    $docroot = 'root';
    if (is_dir("$dir/htdocs")) { $docroot = 'htdocs/'; }
    if (is_dir("$dir/public")) { $docroot = 'public/'; }
    $projects[] = ['name' => $name, 'docroot' => $docroot];
}

// Tiny TCP reachability probe on the lds-network network.
function lds_probe(string $host, int $port): bool {
    $c = @fsockopen($host, $port, $e, $s, 0.5);
    if ($c) { fclose($c); return true; }
    return false;
}

// Backing services, grouped by category for a tidier panel. Each entry is
// label => [in-network host, port]. Reachability is probed per service.
$serviceGroups = [
    // NOTE: definitions only — probing happens later, cached + time-budgeted.
    'Databases' => [
        'MySQL'      => ['mysql', 3306],
        'PostgreSQL' => ['postgres', 5432],
        'MongoDB'    => ['mongo', 27017],
    ],
    'Cache' => [
        'Redis'     => ['redis', 6379],
        'Memcached' => ['memcached', 11211],
    ],
    'Kafka' => [
        'Broker'             => ['kafka-broker', 9092],
        'Schema Registry'    => ['schema-registry', 8080],
        'Connect (Debezium)' => ['connect-debezium', 8083],
        'Connect (generic)'  => ['connect-generic', 8083],
    ],
    'Realtime / pub-sub' => [
        'Soketi (Pusher)'    => ['soketi', 6001],
        'Centrifugo'         => ['centrifugo', 8000],
        'Mosquitto (MQTT)'   => ['mosquitto', 1883],
    ],
];
// Web admin UIs (the `tools`-class profiles + Kafka UI + broker dashboards),
// grouped too. 'url' = browser link, 'alt' = direct host:port, 'health' =
// in-network host:port to ping (null = part of this dashboard, always up).
// Proxy-routed .test links are scheme-relative (`//host`) so they follow the
// page's scheme — http normally, https when the HTTPS overlay is on (no extra
// http->https redirect hop). Direct host:port links stay http (not proxied).
$uiGroups = [
    'Data tools' => [
        ['label' => 'phpCacheAdmin', 'desc' => 'Redis · Memcached',  'url' => '//cache.test', 'alt' => 'localhost:4421', 'health' => ['phpcacheadmin', 80]],
        ['label' => 'DBGate',        'desc' => 'MySQL · PostgreSQL',  'url' => '//db.test',    'alt' => 'localhost:4422', 'health' => ['dbgate', 3000]],
        ['label' => 'Vaultwarden',   'desc' => 'password manager',     'url' => '//vaultwarden.test', 'alt' => 'localhost:4429', 'health' => ['vaultwarden', 80]],
    ],
    'Database design' => [
        // DrawDB uses crypto.randomUUID(), which only exists in a secure context,
        // so it MUST be opened on localhost (or HTTPS) — NOT drawdb.test over http.
        ['label' => 'DrawDB', 'desc' => 'ER diagrams · open on localhost', 'url' => 'http://localhost:4423', 'alt' => null, 'health' => ['drawdb', 80]],
    ],
    'Data warehouse & BI' => [
        ['label' => 'Apache Superset', 'desc' => 'BI dashboards · admin/admin', 'url' => '//superset.test', 'alt' => 'localhost:4425', 'health' => ['superset', 8088]],
        ['label' => 'Apache Hop',      'desc' => 'ETL pipeline designer',       'url' => '//hop.test',      'alt' => 'localhost:4424', 'health' => ['hop', 8080]],
    ],
    'Code quality' => [
        ['label' => 'Semgrep', 'desc' => 'SAST · SARIF viewer', 'url' => '//semgrep.test', 'alt' => 'localhost:4426', 'health' => ['semgrep', 80]],
    ],
    'Web analytics' => [
        ['label' => 'InsightTrack',  'desc' => 'privacy-first analytics', 'url' => '//insighttrack.test',  'alt' => 'localhost:4427', 'health' => ['insighttrack', 4173]],
    ],
    'Project management' => [
        ['label' => 'Werkyn', 'desc' => 'team project management', 'url' => '//werkyn.test', 'alt' => 'localhost:4435', 'health' => ['werkyn', 3000]],
    ],
    'Kafka' => [
        ['label' => 'Kafka UI',          'desc' => 'topics · connectors',      'url' => 'http://localhost:4420', 'alt' => null, 'health' => ['kafka-ui', 8080]],
        ['label' => 'Connector builder', 'desc' => 'build Connect connectors', 'url' => '/connectors.php',       'alt' => null, 'health' => null],
    ],
    'Realtime dashboards' => [
        ['label' => 'Centrifugo',      'desc' => 'WebSocket · admin UI', 'url' => '//centrifugo.test', 'alt' => 'localhost:4431', 'health' => ['centrifugo', 8000]],
        ['label' => 'MQTTX',           'desc' => 'MQTT web client · no login', 'url' => '//mqtt.test',  'alt' => 'localhost:4434', 'health' => ['mqttx', 80]],
    ],
];
// --- Cached + time-budgeted probing -----------------------------------------
// A down service costs ~the musl/Docker-DNS timeout (~1-4s) per probe — NOT the
// fsockopen connect timeout, which only bounds connect, not name resolution. A
// full sweep of ~20 services can therefore exceed nginx-proxy's 60s read-timeout
// and 504 the page. So: cache results briefly, and cap total probe wall-clock per
// request. Render time is then always bounded (page can never 504); services not
// reached within the budget keep their last-known value or show "unknown".
$LDS_CACHE  = sys_get_temp_dir() . '/lds-dashboard-status.json';
$LDS_TTL    = 10;     // seconds a cached result stays fresh (no probing)
$LDS_BUDGET = 20.0;   // max wall-clock seconds spent probing per cold/stale render

// Unique host:port probe targets, gathered from both structures.
$targets = [];
foreach ($serviceGroups as $svcs) foreach ($svcs as [$h, $p]) $targets["$h:$p"] = [$h, $p];
foreach ($uiGroups as $apps) foreach ($apps as $a) if ($a['health']) { [$h, $p] = $a['health']; $targets["$h:$p"] = [$h, $p]; }

$cached = [];
if (is_file($LDS_CACHE)) { $j = json_decode(@file_get_contents($LDS_CACHE), true); if (is_array($j)) $cached = $j; }
$age = is_file($LDS_CACHE) ? (time() - filemtime($LDS_CACHE)) : PHP_INT_MAX;

$status = [];  // "host:port" => 'up' | 'down' | 'unknown'
if ($age <= $LDS_TTL && $cached) {
    foreach ($targets as $k => $_) $status[$k] = $cached[$k] ?? 'unknown';   // fresh → no probing
} else {
    $start = microtime(true);
    foreach ($targets as $k => [$h, $p]) {
        if (microtime(true) - $start > $LDS_BUDGET) { $status[$k] = $cached[$k] ?? 'unknown'; continue; }
        $status[$k] = lds_probe($h, $p) ? 'up' : 'down';
    }
    @file_put_contents($LDS_CACHE, json_encode($status));   // best-effort persist
}

// Map the unified status back onto the display structures.
$serviceStatus = [];
foreach ($serviceGroups as $group => $svcs)
    foreach ($svcs as $label => [$h, $p])
        $serviceStatus[$group][$label] = $status["$h:$p"] ?? 'unknown';

foreach ($uiGroups as &$apps) {
    foreach ($apps as &$app) {
        $app['state'] = null;                // null = no probe (always-available, e.g. this dashboard)
        if ($app['health']) { [$h, $p] = $app['health']; $app['state'] = $status["$h:$p"] ?? 'unknown'; }
    }
    unset($app);
}
unset($apps);
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<!-- Keep status dots live + let "unknown" services fill in over time. Cheap:
     most loads hit the fresh status cache; cold/stale loads are time-budgeted. -->
<meta http-equiv="refresh" content="60">
<title>Local Dev Stack · control panel</title>
<style>
  :root{
    --bg:#0f1419; --card:#1a212b; --card2:#222b38; --line:#2c3743;
    --fg:#e6edf3; --muted:#8b98a5; --accent:#4cc2ff; --good:#3fb950; --bad:#f85149;
  }
  *{box-sizing:border-box}
  body{margin:0;font:15px/1.5 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;
    background:var(--bg);color:var(--fg);padding:32px 20px 64px}
  .wrap{max-width:1100px;margin:0 auto}
  h1{font-size:24px;margin:0 0 4px;letter-spacing:.3px}
  h1 .dot{color:var(--good)}
  .sub{color:var(--muted);margin:0 0 12px}
  .sub code{background:var(--card);border:1px solid var(--line);border-radius:5px;padding:1px 5px;font-size:13px}
  h2{font-size:13px;text-transform:uppercase;letter-spacing:1px;color:var(--muted);
    margin:34px 0 6px;border-bottom:1px solid var(--line);padding-bottom:6px}
  h3{font-size:11px;text-transform:uppercase;letter-spacing:.6px;color:var(--muted);
    opacity:.85;margin:18px 0 10px;font-weight:600}
  .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:14px}
  a.card{display:block;text-decoration:none;color:inherit;background:var(--card);
    border:1px solid var(--line);border-radius:10px;padding:14px 16px;transition:.12s}
  a.card:hover{background:var(--card2);border-color:var(--accent);transform:translateY(-2px)}
  .name{font-weight:600;font-size:15px;display:flex;align-items:center;gap:7px}
  .stat{width:8px;height:8px;border-radius:50%;flex:none;display:inline-block}
  .stat.up{background:var(--good);box-shadow:0 0 6px var(--good)}
  .stat.down{background:var(--bad)}
  .stat.unknown{background:var(--muted);opacity:.5}
  .meta{color:var(--muted);font-size:13px;margin-top:4px}
  ul.svc{list-style:none;padding:0;display:flex;flex-wrap:wrap;gap:8px;margin:0}
  ul.svc li{display:flex;align-items:center;gap:7px;padding:5px 11px;border-radius:7px;
    font-size:13px;background:var(--card);border:1px solid var(--line)}
  .empty{color:var(--muted)}
  footer{margin-top:40px;color:var(--muted);font-size:12px;border-top:1px solid var(--line);padding-top:16px}
  footer code{color:var(--fg)}
</style>
</head>
<body>
<div class="wrap">
  <h1><span class="dot">●</span> Local Dev Stack</h1>
  <p class="sub">Drop a folder into your projects path and it's served instantly at
     <code>&lt;folder&gt;.<?= $tld ?></code>. Tool links use default hostnames — enable each
     profile (<code>LDS_ENABLE_*</code>) for it to respond.</p>

  <h2>Tools &amp; web UIs</h2>
  <?php foreach ($uiGroups as $group => $apps): ?>
    <h3><?= htmlspecialchars($group) ?></h3>
    <div class="grid">
      <?php foreach ($apps as $app): ?>
        <a class="card" href="<?= htmlspecialchars($app['url']) ?>"<?= (strpos($app['url'], 'http') === 0 || strpos($app['url'], '//') === 0) ? ' target="_blank" rel="noopener"' : '' ?>>
          <div class="name">
            <?php if ($app['state'] !== null): ?><span class="stat <?= $app['state'] ?>" title="<?= $app['state'] ?>"></span><?php endif; ?>
            <?= htmlspecialchars($app['label']) ?>
          </div>
          <div class="meta"><?= htmlspecialchars($app['desc']) ?><?= $app['alt'] ? ' · ' . htmlspecialchars($app['alt']) : '' ?></div>
        </a>
      <?php endforeach; ?>
    </div>
  <?php endforeach; ?>

  <h2>Projects (<?= count($projects) ?>)</h2>
  <?php if ($projects): ?>
    <div class="grid">
      <?php foreach ($projects as $p): ?>
        <a class="card" href="http://<?= htmlspecialchars($p['name']) ?>.<?= $tld ?>/">
          <div class="name"><?= htmlspecialchars($p['name']) ?>.<?= $tld ?></div>
          <div class="meta">docroot: <?= htmlspecialchars($p['docroot']) ?></div>
        </a>
      <?php endforeach; ?>
    </div>
  <?php else: ?>
    <p class="empty">No projects yet — drop <code>myapp/public/index.php</code> into your
       projects path, then visit <code>http://myapp.<?= $tld ?></code>.</p>
  <?php endif; ?>

  <h2>Backing services</h2>
  <?php foreach ($serviceStatus as $group => $svcs): ?>
    <h3><?= htmlspecialchars($group) ?></h3>
    <ul class="svc">
      <?php foreach ($svcs as $label => $st): ?>
        <li><span class="stat <?= $st ?>" title="<?= $st ?>"></span><?= htmlspecialchars($label) ?></li>
      <?php endforeach; ?>
    </ul>
  <?php endforeach; ?>

  <footer>
    PHP <?= PHP_VERSION ?> · extensions:
    <?= implode(', ', array_filter(['rdkafka','redis','memcached','pdo_mysql','pdo_pgsql'], 'extension_loaded')) ?>
    · status: <span class="stat up"></span> reachable
    · <span class="stat down"></span> down
    · <span class="stat unknown"></span> not yet checked
    · cached ~<?= $LDS_TTL ?>s, auto-refresh 60s
  </footer>
</div>
</body>
</html>
