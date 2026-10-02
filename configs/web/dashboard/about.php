<?php
// LDS — About page
// Placeholder for future development — flesh out as the project evolves.

$version = '0.1.0';  // bump when you ship features
$year    = date('Y');
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="icon" href="favicon.ico" type="image/x-icon">
<title>About · LDS — Local Dev Stack</title>
<style>
  :root {
    --bg: #0f1419;
    --card: #1a212b;
    --card2: #222b38;
    --line: #2c3743;
    --fg: #e6edf3;
    --muted: #8b98a5;
    --red: #EF4444;
    --red-dim: #991B1B;
    --red-glow: rgba(220, 38, 38, 0.45);
    --red-soft: #FCA5A5;
    --red-pale: #FEF2F2;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    font: 15px/1.6 system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;
    background: var(--bg);
    color: var(--fg);
    padding: 0;
  }

  /* ── Hero ── */
  .hero {
    text-align: center;
    padding: 72px 20px 56px;
    position: relative;
    overflow: hidden;
  }
  .hero::before {
    content: '';
    position: absolute;
    inset: 0;
    background: radial-gradient(ellipse 60% 50% at 50% 40%, var(--red-glow), transparent 70%);
    opacity: 0.25;
    pointer-events: none;
  }
  .hero svg { filter: drop-shadow(0 0 24px var(--red-glow)); margin-bottom: 20px; }
  .hero h1 {
    font-size: 28px;
    margin: 0 0 4px;
    letter-spacing: 1px;
  }
  .hero h1 .accent { color: var(--red); }
  .hero .tagline {
    color: var(--muted);
    font-size: 13px;
    letter-spacing: 4px;
    text-transform: uppercase;
    margin: 0;
  }
  .hero .version {
    display: inline-block;
    margin-top: 14px;
    padding: 3px 12px;
    border: 1px solid var(--line);
    border-radius: 20px;
    font-size: 12px;
    color: var(--muted);
    font-family: ui-monospace, 'Cascadia Code', 'Fira Code', monospace;
  }

  /* ── Content ── */
  .wrap { max-width: 860px; margin: 0 auto; padding: 0 20px 80px; }
  .section { margin-top: 48px; }
  .section h2 {
    font-size: 13px;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: var(--fg);
    margin: 0 0 16px;
    border-bottom: 1px solid var(--line);
    padding-bottom: 8px;
  }
  .section p { color: var(--muted); margin: 0 0 14px; }
  .section p strong { color: var(--fg); }

  /* ── Feature grid ── */
  .features {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
    gap: 14px;
    margin-top: 12px;
  }
  .feature {
    background: var(--card);
    border: 1px solid var(--line);
    border-radius: 10px;
    padding: 18px;
    transition: 0.15s;
  }
  .feature:hover {
    border-color: var(--red);
    transform: translateY(-2px);
  }
  .feature .icon { font-size: 22px; margin-bottom: 8px; }
  .feature h3 { font-size: 14px; margin: 0 0 4px; font-weight: 600; }
  .feature p  { font-size: 13px; margin: 0; color: var(--muted); }

  /* ── Stats ── */
  .stats {
    display: flex;
    gap: 32px;
    flex-wrap: wrap;
    margin-top: 12px;
  }
  .stat-box { text-align: center; }
  .stat-box .num {
    font-size: 32px;
    font-weight: 800;
    color: var(--red);
    line-height: 1;
  }
  .stat-box .label {
    font-size: 11px;
    color: var(--muted);
    text-transform: uppercase;
    letter-spacing: 1px;
    margin-top: 4px;
  }

  /* ── Palette ── */
  .palette {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
    margin-top: 12px;
  }
  .swatch-wrap { text-align: center; }
  .swatch {
    width: 52px;
    height: 52px;
    border-radius: 10px;
    transition: transform 0.15s;
  }
  .swatch:hover { transform: scale(1.12); }
  .swatch-label {
    font-size: 9px;
    color: #555;
    margin-top: 4px;
    font-family: ui-monospace, monospace;
  }

  /* ── Roadmap ── */
  .roadmap {
    margin-top: 12px;
  }
  .roadmap-item {
    display: flex;
    gap: 14px;
    padding: 12px 0;
    border-bottom: 1px solid var(--line);
  }
  .roadmap-item:last-child { border-bottom: none; }
  .roadmap-dot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    margin-top: 5px;
    flex-shrink: 0;
  }
  .roadmap-dot.done    { background: #3fb950; }
  .roadmap-dot.wip     { background: var(--red); box-shadow: 0 0 8px var(--red-glow); }
  .roadmap-dot.planned { background: var(--muted); opacity: 0.4; }
  .roadmap-text h4 { margin: 0; font-size: 14px; font-weight: 600; }
  .roadmap-text p  { margin: 2px 0 0; font-size: 13px; color: var(--muted); }

  /* ── Footer ── */
  footer {
    margin-top: 56px;
    padding: 20px 0;
    border-top: 1px solid var(--line);
    text-align: center;
    font-size: 12px;
    color: var(--muted);
  }
  footer a {
    color: var(--red);
    text-decoration: none;
  }
  footer a:hover { text-decoration: underline; }
</style>
</head>
<body>

<!-- ═══════ HERO ═══════ -->
<div class="hero">
  <svg width="80" height="80" viewBox="0 0 140 140" fill="none" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <linearGradient id="flame-grad" x1="70" y1="0" x2="70" y2="140" gradientUnits="userSpaceOnUse">
        <stop offset="0%" stop-color="#EF4444"/>
        <stop offset="50%" stop-color="#DC2626"/>
        <stop offset="100%" stop-color="#991B1B"/>
      </linearGradient>
      <linearGradient id="flame-inner" x1="70" y1="30" x2="70" y2="120" gradientUnits="userSpaceOnUse">
        <stop offset="0%" stop-color="#FCA5A5"/>
        <stop offset="100%" stop-color="#EF4444"/>
      </linearGradient>
    </defs>
    <path d="M70 8 C70 8, 120 45, 120 85 C120 115, 98 132, 70 132 C42 132, 20 115, 20 85 C20 45, 70 8, 70 8Z" fill="url(#flame-grad)"/>
    <path d="M70 38 C70 38, 98 60, 98 85 C98 103, 86 115, 70 115 C54 115, 42 103, 42 85 C42 60, 70 38, 70 38Z" fill="url(#flame-inner)" opacity="0.9"/>
    <ellipse cx="70" cy="88" rx="12" ry="18" fill="#FEF2F2" opacity="0.6"/>
  </svg>
  <h1><span class="accent">LDS</span> Local Dev Stack</h1>
  <p class="tagline">Build. Deploy. Repeat.</p>
  <span class="version">v<?= $version ?></span>
</div>

<!-- ═══════ CONTENT ═══════ -->
<div class="wrap">

  <!-- What is LDS -->
  <div class="section">
    <h2>What is LDS?</h2>
    <p>
      <strong>Local Dev Stack</strong> is a batteries-included Docker Compose infrastructure for local development.
      Spin up databases, caches, message brokers, monitoring tools, and more — all with a single command,
      all on your machine, all talking to each other over a shared network.
    </p>
    <p>
      Drop a project folder into your workspace and it's instantly served at <code style="background:var(--card);padding:2px 6px;border-radius:4px;font-size:13px">&lt;folder&gt;.test</code> —
      no config files, no manual nginx wiring. Every service is gated behind a profile toggle, so you only
      run what you need.
    </p>
  </div>

  <!-- Key features -->
  <div class="section">
    <h2>Key Features</h2>
    <div class="features">
      <div class="feature">
        <div class="icon">🔥</div>
        <h3>Zero-Config Vhosts</h3>
        <p>Drop a folder, get <code>*.test</code> — auto-detected docroot (public → htdocs → root).</p>
      </div>
      <div class="feature">
        <div class="icon">🐘</div>
        <h3>Multi-Database</h3>
        <p>MySQL, Postgres, MongoDB, MariaDB, MSSQL, Oracle — all CDC-ready with healthchecks.</p>
      </div>
      <div class="feature">
        <div class="icon">📡</div>
        <h3>Kafka KRaft</h3>
        <p>Broker + controller, Schema Registry, two Connect workers (Debezium + generic).</p>
      </div>
      <div class="feature">
        <div class="icon">🔒</div>
        <h3>Security Scanners</h3>
        <p>Semgrep SAST, Trivy CVE, OWASP ZAP DAST — integrated and ready to scan.</p>
      </div>
      <div class="feature">
        <div class="icon">🛠️</div>
        <h3>Profile Toggles</h3>
        <p>One <code>LDS_ENABLE_*</code> flag per service. Start only what you need.</p>
      </div>
      <div class="feature">
        <div class="icon">🐳</div>
        <h3>Docker Hardened Images</h3>
        <p>Base images and DB services run on DHI — minimal, secure, reproducible.</p>
      </div>
    </div>
  </div>

  <!-- Stats -->
  <div class="section">
    <h2>By the Numbers</h2>
    <div class="stats">
      <div class="stat-box">
        <div class="num">35+</div>
        <div class="label">Services</div>
      </div>
      <div class="stat-box">
        <div class="num">20+</div>
        <div class="label">Profiles</div>
      </div>
      <div class="stat-box">
        <div class="num">6</div>
        <div class="label">Databases</div>
      </div>
      <div class="stat-box">
        <div class="num">8+</div>
        <div class="label">Templates</div>
      </div>
      <div class="stat-box">
        <div class="num">1</div>
        <div class="label">Command</div>
      </div>
    </div>
  </div>

  <!-- Brand Palette -->
  <div class="section">
    <h2>Brand Palette</h2>
    <div class="palette">
      <div class="swatch-wrap"><div class="swatch" style="background:#EF4444"></div><div class="swatch-label">#EF4444</div></div>
      <div class="swatch-wrap"><div class="swatch" style="background:#DC2626"></div><div class="swatch-label">#DC2626</div></div>
      <div class="swatch-wrap"><div class="swatch" style="background:#B91C1C"></div><div class="swatch-label">#B91C1C</div></div>
      <div class="swatch-wrap"><div class="swatch" style="background:#991B1B"></div><div class="swatch-label">#991B1B</div></div>
      <div class="swatch-wrap"><div class="swatch" style="background:#FCA5A5"></div><div class="swatch-label">#FCA5A5</div></div>
      <div class="swatch-wrap"><div class="swatch" style="background:#FEF2F2"></div><div class="swatch-label">#FEF2F2</div></div>
    </div>
  </div>

  <!-- Roadmap (placeholder) -->
  <div class="section">
    <h2>Roadmap</h2>
    <div class="roadmap">
      <div class="roadmap-item">
        <div class="roadmap-dot done"></div>
        <div class="roadmap-text">
          <h4>Core stack</h4>
          <p>Docker Compose setup, mass-vhost nginx, dnsmasq DNS, profile toggles.</p>
        </div>
      </div>
      <div class="roadmap-item">
        <div class="roadmap-dot done"></div>
        <div class="roadmap-text">
          <h4>Database services</h4>
          <p>MySQL, Postgres, MongoDB, Redis, Memcached — all with healthchecks and init scripts.</p>
        </div>
      </div>
      <div class="roadmap-item">
        <div class="roadmap-dot wip"></div>
        <div class="roadmap-text">
          <h4>Kafka ecosystem</h4>
          <p>KRaft broker + controller, Connect workers, Schema Registry, topic provisioning.</p>
        </div>
      </div>
      <div class="roadmap-item">
        <div class="roadmap-dot planned"></div>
        <div class="roadmap-text">
          <h4>Observability</h4>
          <p>Centralized logging, metrics dashboard, distributed tracing.</p>
        </div>
      </div>
      <div class="roadmap-item">
        <div class="roadmap-dot planned"></div>
        <div class="roadmap-text">
          <h4>Template expansion</h4>
          <p>More framework starters: Laravel, Django, Spring Boot, FastAPI, Axum.</p>
        </div>
      </div>
    </div>
  </div>

  <!-- Links -->
  <div class="section">
    <h2>Links</h2>
    <div class="features" style="grid-template-columns: repeat(auto-fill, minmax(180px, 1fr))">
      <a class="feature" href="/" style="text-decoration:none;color:inherit">
        <div class="icon">🏠</div>
        <h3>Dashboard</h3>
        <p>Back to control panel</p>
      </a>
      <a class="feature" href="/connectors.php" style="text-decoration:none;color:inherit">
        <div class="icon">🔌</div>
        <h3>Connectors</h3>
        <p>Kafka connector builder</p>
      </a>
    </div>
  </div>

</div>

<footer>
  LDS — Local Dev Stack · v<?= $version ?> · <?= $year ?>
  · <a href="/">Dashboard</a>
</footer>

</body>
</html>
