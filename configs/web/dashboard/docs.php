<?php
/**
 * LDS — Docs page
 *
 * Renders the bilingual markdown handbook (docs/{en,id}/*.md) inside the
 * control panel. The docs directory is bind-mounted read-only at
 * /var/lds-docs by the php service in docker-compose.yml; outside a
 * container we fall back to the repo path, so the page works either way.
 *
 * Markdown -> HTML via the vendored single-file Parsedown (MIT) in
 * lib/parsedown.php, see lib/PARSEDOWN-LICENSE.txt. Raw HTML in the docs
 * (the big ports/profiles tables) is passed through on purpose, so safe
 * mode stays OFF — the files are repo-owned, never user input.
 *
 * Safety: `lang` is clamped to en|id and `doc` must be one of the names
 * returned by scandir() on that directory — no path built from user input.
 */

require_once __DIR__ . '/lib/parsedown.php';

/* ---------------------------------------------------------------- helpers */

function lds_slug($text)
{
    $text = html_entity_decode(strip_tags($text), ENT_QUOTES, 'UTF-8');
    $text = mb_strtolower($text, 'UTF-8');
    $text = preg_replace('/[^\p{L}\p{N}]+/u', '-', $text);
    return trim($text, '-');
}

function lds_plain_title($markdownLine)
{
    $t = trim(preg_replace('/^#+\s*/', '', $markdownLine));
    $t = str_replace('`', '', $t);
    $t = preg_replace('/\*\*(.+?)\*\*/u', '$1', $t);
    $t = preg_replace('/^\d+\s*[·\-\–—]\s*/u', '', $t);
    return $t;
}

/** [ '01-overview' => ['file' => '/…/01-overview.md', 'title' => 'Overview'], … ] */
function lds_chapters($dir)
{
    $chapters = array();
    foreach (glob($dir . '/*.md') ?: array() as $file) {
        $base = basename($file, '.md');
        $title = $base;
        if (($fh = @fopen($file, 'r')) !== false) {
            while (($line = fgets($fh)) !== false) {
                if (preg_match('/^#\s+\S/', $line)) {
                    $title = lds_plain_title($line);
                    break;
                }
            }
            fclose($fh);
        }
        $chapters[$base] = array('file' => $file, 'title' => $title);
    }
    ksort($chapters, SORT_NATURAL);
    return $chapters;
}

/**
 * Inline markdown inside raw HTML table cells.
 *
 * The handbook mixes two table styles: cells written with <code>/<b> (fine
 * as-is) and cells written with markdown — <td>`init`</td>, <td>**keep**</td>.
 * Parsedown passes raw HTML through verbatim, so the second kind would show
 * literal backticks. This pass wraps that markdown in real tags. Cells that
 * already contain a '<' are left alone.
 */
function lds_fix_table_cells($html)
{
    return preg_replace_callback(
        '/<(td|th)(\s[^>]*)?>(.*?)<\/\1>/s',
        function ($m) {
            $inner = $m[3];
            if (strpos($inner, '<') !== false) {
                return $m[0];
            }
            if (!preg_match('/[`*\[]/', $inner)) {
                return $m[0];
            }
            $text = str_replace('\|', '|', $inner); // md-table pipe escapes
            $code = array();
            // pull out code spans first so emphasis is not applied inside them
            $text = preg_replace_callback('/`([^`]+)`/', function ($c) use (&$code) {
                $code[] = $c[1];
                return "\x1A" . (count($code) - 1) . "\x1A";
            }, $text);
            $text = preg_replace('/\*\*(.+?)\*\*/su', '<strong>$1</strong>', $text);
            $text = preg_replace_callback(
                '/\[([^\]]+)\]\(([^)\s]+)\)/',
                function ($l) {
                    return '<a href="' . htmlspecialchars($l[2], ENT_QUOTES, 'UTF-8') . '">' . $l[1] . '</a>';
                },
                $text
            );
            $text = preg_replace_callback('/\x1A(\d+)\x1A/', function ($c) use ($code) {
                return '<code>' . $code[(int)$c[1]] . '</code>';
            }, $text);
            return '<' . $m[1] . ($m[2] ?: '') . '>' . $text . '</' . $m[1] . '>';
        },
        $html
    );
}

/** Give every h2/h3 a stable id (and collect them for the in-page TOC). */
function lds_add_heading_ids($html, &$toc)
{
    $seen = array();
    return preg_replace_callback(
        '/<h([23])>(.*?)<\/h\1>/s',
        function ($m) use (&$toc, &$seen) {
            $slug = lds_slug($m[2]);
            if ($slug === '') {
                $slug = 'section';
            }
            if (isset($seen[$slug])) {
                $seen[$slug]++;
                $slug .= '-' . $seen[$slug];
            } else {
                $seen[$slug] = 1;
            }
            if ($m[1] === '2') {
                $toc[] = array('level' => 2, 'id' => $slug, 'title' => trim(strip_tags($m[2])));
            }
            return '<h' . $m[1] . ' id="' . $slug . '">' . $m[2] . '</h' . $m[1] . '>';
        },
        $html
    );
}

/** Keep readers inside the docs viewer; send external links to a new tab. */
function lds_rewrite_links($html, $lang)
{
    return preg_replace_callback('/<a\s+href="([^"]*)"/i', function ($m) use ($lang) {
        $href = $m[1];

        if ($href === '' || $href[0] === '#' || preg_match('/^[a-z][a-z0-9+.\-]*:/i', $href)) {
            // anchors and absolute/external URLs are untouched (external gets a new tab)
            if (preg_match('/^https?:\/\//i', $href)) {
                return '<a href="' . $href . '" target="_blank" rel="noopener"';
            }
            return '<a href="' . $href . '"';
        }

        // ../en/xx.md / ../id/xx.md — cross-language link
        if (preg_match('~^(?:\.\./)+(en|id)/([A-Za-z0-9][A-Za-z0-9._-]*)\.md(#.*)?$~', $href, $x)) {
            $url = 'docs.php?lang=' . $x[1] . '&doc=' . $x[2] . ($x[3] ?? '');
            return '<a href="' . $url . '"';
        }

        // xx.md (or ./xx.md) — sibling chapter in the same language
        if (preg_match('~^(?:\./)?([A-Za-z0-9][A-Za-z0-9._-]*)\.md(#.*)?$~', $href, $x)) {
            $url = 'docs.php?lang=' . $lang . '&doc=' . $x[1] . ($x[2] ?? '');
            return '<a href="' . $url . '"';
        }

        // anything else (repo history, assets, …) stays as-is
        return '<a href="' . $href . '"';
    }, $html);
}

/** Wide handbook tables scroll instead of blowing the layout out. */
function lds_wrap_tables($html)
{
    $html = preg_replace('/<table>/', '<div class="table-wrap"><table>', $html);
    return preg_replace('/<\/table>/', '</table></div>', $html);
}

/* ------------------------------------------------------------- request */

$available = array('en', 'id');
$lang = isset($_GET['lang']) && in_array($_GET['lang'], $available, true) ? $_GET['lang'] : 'en';

$docsRoot = null;
foreach (array('/var/lds-docs', dirname(__DIR__, 3) . '/docs') as $candidate) {
    if (is_dir($candidate)) {
        $docsRoot = $candidate;
        break;
    }
}

$docs = array();
$langDir  = $docsRoot !== null ? $docsRoot . '/' . $lang : '';
if ($langDir !== '' && is_dir($langDir)) {
    $docs = lds_chapters($langDir);
}

// README is the chapter index: renderable, but not a chapter of its own.
$chapters = array();
foreach ($docs as $key => $info) {
    if ($key !== 'README') {
        $chapters[$key] = $info;
    }
}

$requested = isset($_GET['doc']) ? (string)$_GET['doc'] : '';
$doc = $requested;
if ($doc === '' || !isset($docs[$doc])) {
    // unknown chapter → 404 when one was explicitly asked for, first chapter otherwise
    $missing = ($doc !== '' && $docs !== array());
    if ($missing) {
        http_response_code(404);
    }
    $doc = $chapters !== array() ? array_key_first($chapters) : '';
}

$titles  = array();
foreach ($docs as $key => $info) {
    $titles[$key] = $info['title'];
}

$keys  = array_keys($chapters);
$pos   = array_search($doc, $keys, true);
$prev  = ($pos !== false && $pos > 0) ? $keys[$pos - 1] : null;
$next  = ($pos !== false && $pos < count($keys) - 1) ? $keys[$pos + 1] : null;

$otherLang = $lang === 'en' ? 'id' : 'en';
$otherDir  = $docsRoot !== null ? $docsRoot . '/' . $otherLang : '';
$hasOther  = $otherDir !== '' && is_file($otherDir . '/' . $doc . '.md');

/* --------------------------------------------------------------- render */

$body     = '';
$toc      = array();
$rendered = false;

if ($doc !== '' && isset($docs[$doc])) {
    $file  = $docs[$doc]['file'];
    $mtime = @filemtime($file);
    // bump the renderer version whenever the HTML pipeline changes
    $renderer = 2;
    $cache = sys_get_temp_dir() . '/lds-doc-' . $lang . '-' . $doc . '-' . $mtime . '-v' . $renderer . '.html';

    if (is_file($cache) && filemtime($cache) >= (int)$mtime) {
        $payload = json_decode((string)file_get_contents($cache), true);
        if (is_array($payload) && isset($payload['html'], $payload['toc'])) {
            $body     = $payload['html'];
            $toc      = $payload['toc'];
            $rendered = true;
        }
    }

    if (!$rendered) {
        $md = (string)file_get_contents($file);

        $parser = new Parsedown();
        $parser->setSafeMode(false);
        $parser->setMarkupEscaped(false);
        $parser->setBreaksEnabled(false);

        $html = $parser->text($md);
        $html = lds_fix_table_cells($html);
        $html = lds_add_heading_ids($html, $toc);
        $html = lds_rewrite_links($html, $lang);
        $html = lds_wrap_tables($html);

        @file_put_contents(
            $cache,
            json_encode(array('html' => $html, 'toc' => $toc), JSON_UNESCAPED_UNICODE)
        );

        $body = $html;
    }
}

$pageTitle = ($doc !== '' && isset($titles[$doc])) ? $titles[$doc] : 'Documentation';
$self = function ($params) {
    return 'docs.php?' . http_build_query($params);
};

function lds_h($s)
{
    return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8');
}
?>
<!doctype html>
<html lang="<?= lds_h($lang) ?>">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="icon" href="favicon.ico" type="image/x-icon">
<title><?= lds_h($pageTitle) ?> · Docs — LDS</title>
<style>
  :root {
    --bg:#0f1419; --card:#1a212b; --card2:#222b38; --line:#2c3743;
    --fg:#e6edf3; --muted:#8b98a5; --accent:#EF4444; --good:#3fb950; --bad:#f85149;
  }
  * { box-sizing: border-box; }
  body {
    margin:0; background:var(--bg); color:var(--fg);
    font:15px/1.65 system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;
  }
  a { color:var(--accent); text-decoration:none; }
  a:hover { text-decoration:underline; }
  code { font-family:ui-monospace,'Cascadia Code','Fira Code',Consolas,monospace; font-size:.9em; }

  /* ── top bar ── */
  .topbar {
    display:flex; align-items:center; gap:14px; flex-wrap:wrap;
    padding:14px 20px; border-bottom:1px solid var(--line); background:var(--card);
    position:sticky; top:0; z-index:5;
  }
  .topbar .brand { display:flex; align-items:center; gap:10px; font-weight:700; letter-spacing:.4px; }
  .topbar .brand .flame {
    width:22px; height:22px; border-radius:50%;
    background:radial-gradient(circle at 35% 30%, #FCA5A5, var(--accent) 55%, #991B1B);
    box-shadow:0 0 10px rgba(220,38,38,.55);
  }
  .topbar .brand span.mut { color:var(--muted); font-weight:400; font-size:13px; }
  .topbar nav { margin-left:auto; display:flex; align-items:center; gap:6px; flex-wrap:wrap; }
  .topbar nav a {
    color:var(--muted); font-size:13px; padding:5px 11px; border:1px solid var(--line);
    border-radius:7px; transition:.15s;
  }
  .topbar nav a:hover { color:var(--fg); border-color:var(--accent); text-decoration:none; }
  .topbar nav a.on { color:var(--fg); border-color:var(--accent); background:rgba(239,68,68,.12); }
  .lang { display:flex; gap:4px; margin-left:8px; }
  .lang a {
    font-size:12px; padding:4px 9px; border:1px solid var(--line); border-radius:6px;
    color:var(--muted); text-transform:uppercase; letter-spacing:.5px;
  }
  .lang a.on { color:var(--fg); border-color:var(--accent); background:rgba(239,68,68,.12); }

  /* ── layout ── */
  .layout { display:grid; grid-template-columns:250px minmax(0,1fr) 210px; max-width:1500px; }
  .side, .toc { position:sticky; top:57px; align-self:start; max-height:calc(100vh - 57px); overflow-y:auto; }
  .side { border-right:1px solid var(--line); padding:20px 14px 40px; }
  .toc  { border-left:1px solid var(--line);  padding:24px 14px 40px; }
  .rail-title {
    font-size:11px; text-transform:uppercase; letter-spacing:1.2px; color:var(--muted);
    margin:0 0 10px; font-weight:600;
  }
  .side ol { list-style:none; margin:0; padding:0; counter-reset:ch; }
  .side li { counter-increment:ch; }
  .side li a {
    display:flex; gap:9px; align-items:baseline; padding:6px 9px; border-radius:7px;
    color:var(--muted); font-size:13.5px; line-height:1.35; margin-bottom:2px;
  }
  .side li a::before {
    content:counter(ch,decimal-leading-zero); font-size:10.5px; color:#5b6875;
    font-family:ui-monospace,monospace; flex:none; width:16px;
  }
  .side li a:hover { background:var(--card); color:var(--fg); text-decoration:none; }
  .side li a.on { background:rgba(239,68,68,.13); color:var(--fg); box-shadow:inset 2px 0 0 var(--accent); }
  .toc ol { list-style:none; margin:0; padding:0; }
  .toc li a { display:block; font-size:12.5px; color:var(--muted); padding:4px 8px; border-left:2px solid transparent; }
  .toc li.lv3 a { padding-left:20px; font-size:12px; }
  .toc li a:hover { color:var(--fg); text-decoration:none; border-left-color:var(--accent); }

  main { padding:28px 34px 70px; min-width:0; }
  .crumb { font-size:12.5px; color:var(--muted); margin-bottom:6px; }
  .crumb a { color:var(--muted); }
  .crumb a:hover { color:var(--fg); }

  /* ── markdown content ── */
  main h1 { font-size:27px; line-height:1.25; margin:6px 0 18px; letter-spacing:.2px; }
  main h2 { font-size:19px; margin:36px 0 12px; padding-bottom:7px; border-bottom:1px solid var(--line); scroll-margin-top:70px; }
  main h3 { font-size:16px; margin:26px 0 8px; scroll-margin-top:70px; }
  main h4 { font-size:14.5px; margin:20px 0 6px; color:var(--fg); }
  main p  { margin:0 0 14px; color:#c9d3dd; }
  main ul, main ol { margin:0 0 16px; padding-left:24px; color:#c9d3dd; }
  main li { margin:5px 0; }
  main li > ul, main li > ol { margin:5px 0 4px; }
  main a { color:#ff8b8b; }
  main strong { color:var(--fg); }
  main blockquote {
    margin:0 0 16px; padding:10px 16px; border-left:3px solid var(--accent);
    background:var(--card); border-radius:0 8px 8px 0; color:var(--muted);
  }
  main blockquote p:last-child { margin-bottom:0; }
  main hr { border:0; border-top:1px solid var(--line); margin:30px 0; }
  main :not(pre) > code {
    background:var(--card2); border:1px solid var(--line); border-radius:5px;
    padding:1.5px 6px; color:#ffd7d7; white-space:nowrap;
  }
  main pre {
    background:#0b0f14; border:1px solid var(--line); border-radius:9px;
    padding:14px 16px; overflow-x:auto; margin:0 0 18px; line-height:1.5;
  }
  main pre code { background:none; border:0; padding:0; color:#c9d1d9; white-space:pre; font-size:13px; }
  .table-wrap { overflow-x:auto; margin:0 0 18px; border:1px solid var(--line); border-radius:9px; }
  .table-wrap table { border-collapse:collapse; width:100%; font-size:13.5px; margin:0; }
  .table-wrap th, .table-wrap td { border:1px solid var(--line); padding:8px 12px; text-align:left; vertical-align:top; }
  .table-wrap th { background:var(--card2); color:var(--fg); font-weight:600; white-space:nowrap; }
  .table-wrap td { background:var(--card); color:#c9d3dd; }
  .table-wrap tr:nth-child(even) td { background:#171e27; }
  .table-wrap code { white-space:nowrap; }
  main img { max-width:100%; border-radius:8px; }

  /* ── pager ── */
  .pager { display:flex; justify-content:space-between; gap:12px; margin-top:44px; padding-top:18px; border-top:1px solid var(--line); }
  .pager a {
    display:block; max-width:48%; padding:11px 14px; border:1px solid var(--line);
    border-radius:9px; background:var(--card); color:var(--fg); font-size:13.5px; transition:.15s;
  }
  .pager a:hover { border-color:var(--accent); text-decoration:none; }
  .pager a span { display:block; font-size:11px; color:var(--muted); text-transform:uppercase; letter-spacing:1px; margin-bottom:3px; }
  .pager a.next { text-align:right; margin-left:auto; }
  .empty { color:var(--muted); }

  @media (max-width:1180px) {
    .layout { grid-template-columns:230px minmax(0,1fr); }
    .toc { display:none; }
  }
  @media (max-width:820px) {
    .layout { grid-template-columns:1fr; }
    .side { position:static; max-height:none; border-right:0; border-bottom:1px solid var(--line); }
    main { padding:22px 18px 60px; }
    .topbar nav a { padding:4px 8px; }
  }
</style>
</head>
<body>

<div class="topbar">
  <div class="brand"><span class="flame"></span> LDS <span class="mut">Docs</span></div>
  <nav>
    <a href="/">Dashboard</a>
    <a href="/about.php">About</a>
    <a href="/connectors.php">Connectors</a>
    <?php if ($hasOther): ?>
      <a class="on" href="<?= lds_h($self(array('lang' => $otherLang, 'doc' => $doc))) ?>">
        <?= $otherLang === 'id' ? 'Bahasa Indonesia' : 'English' ?> ↗
      </a>
    <?php endif; ?>
    <span class="lang">
      <?php foreach ($available as $l): ?>
        <a class="<?= $l === $lang ? 'on' : '' ?>"
           href="<?= lds_h($self(array('lang' => $l, 'doc' => $doc))) ?>"><?= $l ?></a>
      <?php endforeach; ?>
    </span>
  </nav>
</div>

<div class="layout">

  <aside class="side">
    <p class="rail-title">Chapters</p>
    <ol>
      <?php foreach ($chapters as $key => $info): ?>
        <li>
          <a class="<?= $key === $doc ? 'on' : '' ?>"
             href="<?= lds_h($self(array('lang' => $lang, 'doc' => $key))) ?>"><?= lds_h($info['title']) ?></a>
        </li>
      <?php endforeach; ?>
      <?php if ($chapters === array()): ?>
        <li class="empty">No chapters found<?= $docsRoot === null ? ' — docs are not mounted into this container' : '' ?>.</li>
      <?php endif; ?>
    </ol>
  </aside>

  <main>
    <?php if ($chapters !== array() && $doc !== ''): ?>
      <p class="crumb">
        <a href="/">LDS</a> · docs/<code><?= lds_h($lang) ?></code> /
        <code><?= lds_h($doc) ?>.md</code>
        <?php if (isset($docs[$doc]) && is_file($docs[$doc]['file'])): ?>
          · <span title="Edited"><?= lds_h(date('Y-m-d H:i', (int)@filemtime($docs[$doc]['file']))) ?></span>
        <?php endif; ?>
      </p>
    <?php endif; ?>

    <?php if (isset($_GET['doc']) && $_GET['doc'] !== '' && !isset($docs[(string)$_GET['doc']])): ?>
      <p class="empty">That chapter does not exist in <code><?= lds_h($lang) ?></code>.
         <a href="<?= lds_h($self(array('lang' => $lang))) ?>">Back to the first chapter</a>.</p>
    <?php endif; ?>

    <article>
      <?= $body ?>
    </article>

    <?php if ($body === ''): ?>
      <p class="empty">Nothing to show here.</p>
    <?php endif; ?>

    <?php if ($prev !== null || $next !== null): ?>
      <nav class="pager">
        <?php if ($prev !== null): ?>
          <a class="prev" href="<?= lds_h($self(array('lang' => $lang, 'doc' => $prev))) ?>">
            <span>← Previous</span><?= lds_h($titles[$prev]) ?>
          </a>
        <?php endif; ?>
        <?php if ($next !== null): ?>
          <a class="next" href="<?= lds_h($self(array('lang' => $lang, 'doc' => $next))) ?>">
            <span>Next →</span><?= lds_h($titles[$next]) ?>
          </a>
        <?php endif; ?>
      </nav>
    <?php endif; ?>
  </main>

  <aside class="toc">
    <?php if (count($toc) > 1): ?>
      <p class="rail-title">On this page</p>
      <ol>
        <?php foreach ($toc as $item): ?>
          <li class="lv<?= (int)$item['level'] ?>">
            <a href="#<?= lds_h($item['id']) ?>"><?= lds_h($item['title']) ?></a>
          </li>
        <?php endforeach; ?>
      </ol>
    <?php endif; ?>
  </aside>

</div>
</body>
</html>
