<?php
// =============================================================================
// SonarQube report — printable/exportable FULL project report.
//   /sonar-report.php                       project picker
//   /sonar-report.php?key=<key>             report view (print-friendly)
//   /sonar-report.php?key=<key>&download=1  same report, served as a .html file
//
// The browser only talks to this page (same-origin); this PHP reads the
// SonarQube Web API over lds-network by service name. Browsing needs no login
// by default (SONARQUBE_FORCE_AUTH=false → anonymous read-only), so no token
// is needed. Community Build has no built-in report export — this page is it:
// every measure, every issue, every hotspot, per-file metrics, duplications,
// rules and the analysis history. Print/Save as PDF, or Download HTML.
// =============================================================================

const SONAR_API = 'http://sonarqube:9000';   // in-network service name + port
const PAGE_SIZE = 500;                       // API max page size
const MAX_PAGES = 40;                        // safety cap (20k rows per collection)

// Fallback labels for keys that are missing from a rolling server's metric
// registry (the registry name is preferred at render time).
const METRIC_LABELS = [
    'bugs' => 'Bugs', 'vulnerabilities' => 'Vulnerabilities', 'code_smells' => 'Code smells',
    'security_hotspots' => 'Security hotspots', 'security_hotspots_reviewed' => 'Hotspots reviewed',
    'sqale_index' => 'Technical debt', 'sqale_debt_ratio' => 'Debt ratio',
    'coverage' => 'Coverage', 'line_coverage' => 'Line coverage', 'branch_coverage' => 'Branch coverage',
    'duplicated_lines_density' => 'Duplicated lines', 'duplicated_lines' => 'Duplicated lines (count)',
    'duplicated_blocks' => 'Duplicated blocks', 'duplicated_files' => 'Duplicated files',
    'ncloc' => 'Lines of code', 'files' => 'Files', 'directories' => 'Directories',
    'complexity' => 'Cyclomatic complexity', 'cognitive_complexity' => 'Cognitive complexity',
    'reliability_rating' => 'Reliability', 'security_rating' => 'Security', 'sqale_rating' => 'Maintainability',
    'alert_status' => 'Quality gate', 'security_review_rating' => 'Security review',
    'new_lines' => 'New lines', 'new_bugs' => 'New bugs', 'new_vulnerabilities' => 'New vulnerabilities',
    'new_code_smells' => 'New code smells', 'new_coverage' => 'Coverage on new code',
    'new_duplicated_lines_density' => 'Duplicated lines on new code',
    'new_reliability_rating' => 'Reliability on new code', 'new_security_rating' => 'Security on new code',
];

const RATING_METRICS = ['reliability_rating', 'security_rating', 'sqale_rating'];

const TYPE_LABELS = ['BUG' => 'Bug', 'VULNERABILITY' => 'Vulnerability', 'CODE_SMELL' => 'Code smell'];

const SEVERITY_ORDER = ['BLOCKER' => 0, 'CRITICAL' => 1, 'MAJOR' => 2, 'MINOR' => 3, 'INFO' => 4];
const TYPE_ORDER     = ['BUG' => 0, 'VULNERABILITY' => 1, 'CODE_SMELL' => 2];

// Preferred ordering inside the metric tables (everything else follows by name).
const METRIC_PRIORITY = [
    'bugs' => 0, 'vulnerabilities' => 1, 'code_smells' => 2, 'security_hotspots' => 3,
    'security_hotspots_reviewed' => 4, 'sqale_index' => 5, 'sqale_debt_ratio' => 6,
    'reliability_rating' => 7, 'security_rating' => 8, 'sqale_rating' => 9, 'security_review_rating' => 10,
    'coverage' => 11, 'line_coverage' => 12, 'branch_coverage' => 13,
    'duplicated_lines_density' => 14, 'duplicated_lines' => 15, 'duplicated_blocks' => 16, 'duplicated_files' => 17,
    'ncloc' => 18, 'files' => 19, 'directories' => 20, 'complexity' => 21, 'cognitive_complexity' => 22,
];

const DOMAIN_ORDER = [
    'Issues', 'Reliability', 'Security', 'SecurityReview', 'Maintainability', 'Coverage',
    'Duplications', 'Size', 'Complexity', 'Documentation', 'Releasability', 'SCM', 'General',
];

const FACET_LABELS = [
    'severities' => 'Severity', 'types' => 'Type', 'statuses' => 'Status',
    'impactSeverities' => 'Impact severity', 'impactSoftwareQualities' => 'Software quality',
    'cleanCodeAttributeCategories' => 'Clean code attribute category',
    'languages' => 'Language', 'tags' => 'Tag', 'rules' => 'Rule', 'directories' => 'Directory',
    'files' => 'File', 'scopes' => 'Scope', 'resolutions' => 'Resolution',
];

const LANGUAGE_LABELS = [
    'ts' => 'TypeScript', 'js' => 'JavaScript', 'web' => 'Web', 'css' => 'CSS', 'scss' => 'SCSS',
    'java' => 'Java', 'php' => 'PHP', 'py' => 'Python', 'go' => 'Go', 'rs' => 'Rust',
    'docker' => 'Docker', 'kubernetes' => 'Kubernetes', 'yaml' => 'YAML', 'json' => 'JSON',
    'xml' => 'XML', 'html' => 'HTML', 'sql' => 'SQL', 'sh' => 'Shell',
];

/** GET a SonarQube Web API path. Returns [ok, status, data, error]. */
function sonar_get(string $path, array $params = []): array {
    $url = SONAR_API . $path . ($params ? '?' . http_build_query($params) : '');
    return sonar_request($url);
}

function sonar_request(string $url): array {
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 3,
        CURLOPT_TIMEOUT        => 20,
        CURLOPT_HTTPHEADER     => ['Accept: application/json'],
    ]);
    $resp = curl_exec($ch);
    $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err  = curl_error($ch);
    curl_close($ch);
    return [
        'ok'     => $code >= 200 && $code < 300,
        'status' => $code,
        'data'   => is_string($resp) ? json_decode($resp, true) : null,
        'error'  => $err ?: null,
    ];
}

/** Parallel GETs (curl_multi), in chunks of 25. Keeps the request keys. */
function sonar_get_many(array $requests): array {
    $out = [];
    foreach (array_chunk($requests, 25, true) as $chunk) {
        $mh = curl_multi_init();
        $handles = [];
        foreach ($chunk as $i => $req) {
            $url = SONAR_API . $req['path'] . (!empty($req['params']) ? '?' . http_build_query($req['params']) : '');
            $ch = curl_init($url);
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_CONNECTTIMEOUT => 3,
                CURLOPT_TIMEOUT        => 20,
                CURLOPT_HTTPHEADER     => ['Accept: application/json'],
            ]);
            curl_multi_add_handle($mh, $ch);
            $handles[$i] = $ch;
        }
        $active = 0;
        do {
            $status = curl_multi_exec($mh, $active);
            if ($active) {
                if (curl_multi_select($mh, 1.0) === -1) usleep(20000);
            }
        } while ($active > 0 && $status === CURLM_OK);
        foreach ($handles as $i => $ch) {
            $resp = curl_multi_getcontent($ch);
            $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $err  = curl_error($ch);
            curl_multi_remove_handle($mh, $ch);
            curl_close($ch);
            $out[$i] = [
                'ok'     => $code >= 200 && $code < 300,
                'status' => $code,
                'data'   => is_string($resp) ? json_decode($resp, true) : null,
                'error'  => $err ?: null,
            ];
        }
        curl_multi_close($mh);
    }
    return $out;
}

/** Fetch every page of a paged endpoint, merging the $itemKey array. */
function sonar_paged(string $path, array $params, string $itemKey, int $maxPages = MAX_PAGES): array {
    $items  = [];
    $total  = null;
    $status = 0;
    $ok     = false;
    for ($p = 1; $p <= $maxPages; $p++) {
        $r = sonar_get($path, $params + ['ps' => PAGE_SIZE, 'p' => $p]);
        $status = $r['status'];
        if (!$r['ok']) break;
        $ok   = true;
        $page = $r['data'][$itemKey] ?? [];
        if (isset($r['data']['paging']['total'])) $total = (int) $r['data']['paging']['total'];
        $items = array_merge($items, is_array($page) ? $page : []);
        if (!$page || ($total !== null && count($items) >= $total)) break;
    }
    return ['ok' => $ok, 'status' => $status, 'items' => $items, 'total' => $total ?? count($items)];
}

function h(?string $s): string { return htmlspecialchars((string) $s, ENT_QUOTES, 'UTF-8'); }

function fmt_int(string $v): string { return number_format((float) $v); }

function fmt_pct(string $v): string {
    $s = rtrim(rtrim(number_format((float) $v, 1, '.', ''), '0'), '.');
    return $s . '%';
}

function fmt_min(string $v): string {
    $m = (int) round((float) $v);
    if ($m <= 0) return '0min';
    $h = intdiv($m, 60); $r = $m % 60;
    if ($h && $r) return "{$h}h {$r}min";
    return $h ? "{$h}h" : "{$r}min";
}

function fmt_bytes(string $v): string {
    $b = (float) $v;
    if ($b < 1024) return fmt_int((string) $b) . ' B';
    $units = ['KB', 'MB', 'GB', 'TB'];
    foreach ($units as $u) {
        $b /= 1024;
        if ($b < 1024) return rtrim(rtrim(number_format($b, 1, '.', ''), '0'), '.') . ' ' . $u;
    }
    return rtrim(rtrim(number_format($b, 1, '.', ''), '0'), '.') . ' PB';
}

/** "5min" / "1h 30min" / "2h" → minutes (best effort). */
function debt_minutes(string $s): int {
    if (preg_match('/(?:(\d+)\s*h)?\s*(?:(\d+)\s*min)?/i', $s, $m)) {
        return ((int) ($m[1] ?? 0)) * 60 + ((int) ($m[2] ?? 0));
    }
    return 0;
}

/** Rating measure (1.0..5.0) → [letter, css class] or null. */
function rating(?string $v): ?array {
    if ($v === null || $v === '') return null;
    $map = [1 => ['A', 'ra'], 2 => ['B', 'rb'], 3 => ['C', 'rc'], 4 => ['D', 'rd'], 5 => ['E', 're']];
    return $map[(int) round((float) $v)] ?? null;
}

/** Format a value by its metric type (registry-driven). */
function measure_display(string $type, string $value): string {
    switch ($type) {
        case 'RATING':
            $r = rating($value);
            return $r ? '<span class="rt ' . $r[1] . '">' . $r[0] . '</span>' : h($value);
        case 'PERCENT':
            return h(fmt_pct($value));
        case 'WORK_DUR':
            return h(fmt_min($value));
        case 'MILLISEC':
            return h(fmt_int($value)) . ' ms';
        case 'DATA_SIZE':
            return h(fmt_bytes($value));
        case 'BOOL':
            return h(in_array($value, ['true', '1', 'yes'], true) ? 'Yes' : 'No');
        case 'INT':
            return h(fmt_int($value));
        case 'FLOAT':
            return h(rtrim(rtrim(number_format((float) $value, 2, '.', ''), '0'), '.'));
        default:
            return h($value);
    }
}

/** Quality-gate status → [label, css class]. */
function gate_badge(?string $s): array {
    return match ($s) {
        'OK'    => ['Passed', 'passed'],
        'ERROR' => ['Failed', 'failed'],
        'WARN'  => ['Warning', 'warn'],
        default => ['Not computed', 'none'],
    };
}

/** Humanise an API enum (IMPACT_SEVERITY, software quality, …). */
function humanize(?string $s): string {
    $s = (string) $s;
    if ($s === '') return '';
    return ucfirst(strtolower(str_replace('_', ' ', $s)));
}

/** Path part of a "<project>:<path>" component key. */
function comp_path(string $projectKey, string $comp): string {
    $prefix = $projectKey . ':';
    return str_starts_with($comp, $prefix) ? substr($comp, strlen($prefix)) : $comp;
}

/** "yyyy-mm-ddThh:mm:ss+zzzz" → "yyyy-mm-dd hh:mm". */
function fmt_date(?string $s): string {
    if (!$s) return '';
    $ts = strtotime($s);
    return $ts ? date('Y-m-d H:i', $ts) : (string) $s;
}

@set_time_limit(120);

// --- request handling -------------------------------------------------------
$key      = trim((string) ($_GET['key'] ?? ''));
$download = isset($_GET['download']);
$keyOk    = $key === '' || (bool) preg_match('/^[A-Za-z0-9._:\-]+$/', $key);

if ($download) {
    header('Content-Type: text/html; charset=utf-8');
    header('Content-Disposition: attachment; filename="sonar-report-' . ($keyOk && $key !== '' ? $key : 'projects') . '.html"');
}

$projects   = null;   // picker entries (null = listing failed)
$listStatus = null;
$show = $gate = null;
$metricDefs = [];     // key => registry entry
$vals = [];           // key => measure value
$facets = [];
$issueTotal = $issueDebt = null;
$issuesAll = $hotspots = $filesTree = $fileMeasures = [];
$analyses = [];
$ruleInfo = [];
$dupGroups = [];
$dataOk = false;

if ($key === '') {
    $pr = sonar_get('/api/components/search', ['qualifiers' => 'TRK', 'ps' => 500]);
    if ($pr['ok']) {
        $projects = $pr['data']['components'] ?? [];
    } else {
        $listStatus = $pr['status'];
    }
} elseif ($keyOk) {
    $show = sonar_get('/api/components/show', ['component' => $key]);
    if ($show['ok']) {
        $dataOk = true;

        // Quality gate.
        $gate = sonar_get('/api/qualitygates/project_status', ['projectKey' => $key]);

        // Metric registry (drives labels, domains and value formatting).
        $p = 1; $fetched = 0; $metricTotal = 1;
        while ($p <= 5 && $fetched < $metricTotal) {
            $mr = sonar_get('/api/metrics/search', ['ps' => PAGE_SIZE, 'p' => $p]);
            if (!$mr['ok']) break;
            $metricTotal = (int) ($mr['data']['paging']['total'] ?? 0);
            $pageMetrics = $mr['data']['metrics'] ?? [];
            foreach ($pageMetrics as $m) if (isset($m['key'])) $metricDefs[$m['key']] = $m;
            $fetched += count($pageMetrics);
            if (!$pageMetrics) break;
            $p++;
        }

        // Every measure with a value (chunked to keep URLs sane).
        if ($metricDefs) {
            $reqs = [];
            foreach (array_chunk(array_keys($metricDefs), 60) as $i => $chunk) {
                $reqs[$i] = ['path' => '/api/measures/component', 'params' => [
                    'component' => $key, 'metricKeys' => implode(',', $chunk),
                ]];
            }
            foreach (sonar_get_many($reqs) as $r) {
                if (!$r['ok']) continue;
                foreach ($r['data']['component']['measures'] ?? [] as $m) {
                    if (isset($m['metric'])) $vals[$m['metric']] = (string) $m['value'];
                }
            }
        }

        // Issue facets (richer taxonomy; retried with the classic pair if a
        // future/older server rejects one of the facet names).
        $facetList = 'severities,types,statuses,impactSeverities,impactSoftwareQualities,'
                   . 'cleanCodeAttributeCategories,languages,tags,rules';
        $is = sonar_get('/api/issues/search', ['componentKeys' => $key, 'ps' => 1, 'facets' => $facetList]);
        if (!$is['ok']) {
            $is = sonar_get('/api/issues/search', [
                'componentKeys' => $key, 'ps' => 1, 'facets' => 'severities,types,impactSeverities',
            ]);
        }
        if ($is['ok']) {
            $facets     = $is['data']['facets'] ?? [];
            $issueTotal = (int) ($is['data']['total'] ?? 0);
            $issueDebt  = (int) ($is['data']['effortTotal'] ?? 0);
        }

        // Every issue (open + resolved; impacts are part of the payload).
        $ip = sonar_paged('/api/issues/search', [
            'componentKeys' => $key,
        ], 'issues');
        $issuesAll = $ip['items'];

        // Every security hotspot.
        $hp = sonar_paged('/api/hotspots/search', ['project' => $key], 'hotspots', 10);
        $hotspots = $hp['items'];

        // File tree + per-file measures.
        $ft = sonar_paged('/api/components/tree', [
            'component' => $key, 'qualifiers' => 'FIL',
        ], 'components', 20);
        $filesTree = $ft['items'];

        $fm = sonar_paged('/api/measures/component_tree', [
            'component' => $key, 'qualifiers' => 'FIL',
            'metricKeys' => 'ncloc,complexity,cognitive_complexity,coverage,line_coverage,'
                          . 'duplicated_lines,duplicated_lines_density,duplicated_blocks,'
                          . 'bugs,vulnerabilities,code_smells,sqale_index',
        ], 'components', 20);
        $fileMeasures = [];
        foreach ($fm['items'] as $c) {
            if (empty($c['key'])) continue;
            $mm = [];
            foreach ($c['measures'] ?? [] as $m) if (isset($m['metric'])) $mm[$m['metric']] = (string) $m['value'];
            if (!isset($fileMeasures[$c['key']])) $fileMeasures[$c['key']] = [];
            $fileMeasures[$c['key']] += $mm;
        }

        // Analysis history.
        $ap = sonar_paged('/api/project_analyses/search', ['project' => $key], 'analyses', 10);
        $analyses = $ap['items'];

        // Distinct rule metadata (names, languages, impacts) in one parallel batch.
        $ruleKeys = [];
        foreach ($issuesAll as $it) if (!empty($it['rule'])) $ruleKeys[$it['rule']] = true;
        foreach ($hotspots as $hs) {
            $rk = $hs['ruleKey'] ?? $hs['rule'] ?? null;
            if ($rk) $ruleKeys[$rk] = true;
        }
        if ($ruleKeys) {
            $keys = array_keys($ruleKeys);
            $reqs = [];
            foreach ($keys as $i => $rk) $reqs[$i] = ['path' => '/api/rules/show', 'params' => ['key' => $rk]];
            foreach (sonar_get_many($reqs) as $i => $r) {
                if ($r['ok'] && isset($r['data']['rule'])) $ruleInfo[$keys[$i]] = $r['data']['rule'];
            }
        }

        // Duplication groups: /api/duplications/show exposes the blocks of one
        // file; query every file that has duplicated lines, then dedupe the
        // groups (a pair shows up once per file it touches).
        $dupFileKeys = [];
        foreach ($fileMeasures as $fk => $mm) {
            if ((float) ($mm['duplicated_lines'] ?? 0) > 0) $dupFileKeys[] = $fk;
        }
        if ($dupFileKeys) {
            $reqs = [];
            foreach ($dupFileKeys as $i => $fk) $reqs[$i] = ['path' => '/api/duplications/show', 'params' => ['key' => $fk]];
            foreach (sonar_get_many($reqs) as $r) {
                if (!$r['ok']) continue;
                $dupFiles = $r['data']['files'] ?? [];
                foreach ($r['data']['duplications'] ?? [] as $dup) {
                    $blocks = [];
                    foreach ($dup['blocks'] ?? [] as $b) {
                        $ref = (string) ($b['_ref'] ?? '');
                        if (!isset($dupFiles[$ref])) continue;
                        $blocks[] = [
                            'path' => (string) ($dupFiles[$ref]['name'] ?? $dupFiles[$ref]['key'] ?? $ref),
                            'from' => (int) ($b['from'] ?? 0),
                            'size' => (int) ($b['size'] ?? 0),
                        ];
                    }
                    if (count($blocks) < 2) continue;
                    $sig = array_map(fn($b) => $b['path'] . ':' . $b['from'] . ':' . $b['size'], $blocks);
                    sort($sig);
                    $sig = implode('|', $sig);
                    if (!isset($dupGroups[$sig])) $dupGroups[$sig] = $blocks;
                }
            }
            uasort($dupGroups, fn($a, $b) => ($b[0]['size'] ?? 0) <=> ($a[0]['size'] ?? 0));
        }
    }
}

// Derived report data.
$gateStatus = $gate['data']['projectStatus']['status'] ?? null;
$gateConds  = $gate['data']['projectStatus']['conditions'] ?? [];
$caycStatus = $gate['data']['projectStatus']['caycStatus'] ?? null;

$issueComponents = [];
foreach ($issuesAll as $it) {
    $ck = (string) ($it['component'] ?? '');
    $issueComponents[$ck] = ($issueComponents[$ck] ?? 0) + 1;
}

// Sort issues: severity, then type, then file, then line.
usort($issuesAll, function ($a, $b) {
    $sa = SEVERITY_ORDER[$a['severity'] ?? ''] ?? 9;
    $sb = SEVERITY_ORDER[$b['severity'] ?? ''] ?? 9;
    if ($sa !== $sb) return $sa <=> $sb;
    $ta = TYPE_ORDER[$a['type'] ?? ''] ?? 9;
    $tb = TYPE_ORDER[$b['type'] ?? ''] ?? 9;
    if ($ta !== $tb) return $ta <=> $tb;
    $ca = (string) ($a['component'] ?? '');
    $cb = (string) ($b['component'] ?? '');
    if ($ca !== $cb) return strcmp($ca, $cb);
    return ((int) ($a['line'] ?? 0)) <=> ((int) ($b['line'] ?? 0));
});

// Files keyed by component key, with per-file issue counts/debt.
$files = [];
foreach ($filesTree as $c) {
    if (empty($c['key'])) continue;
    $files[$c['key']] = [
        'key'      => $c['key'],
        'path'     => $c['path'] ?? $c['name'] ?? $c['key'],
        'language' => $c['language'] ?? '',
    ];
}
foreach ($fileMeasures as $fk => $_) {
    if (!isset($files[$fk])) $files[$fk] = ['key' => $fk, 'path' => comp_path($key, $fk), 'language' => ''];
}
$fileDebt = [];
foreach ($issuesAll as $it) {
    $ck = (string) ($it['component'] ?? '');
    $fileDebt[$ck] = ($fileDebt[$ck] ?? 0) + debt_minutes((string) ($it['debt'] ?? $it['effort'] ?? ''));
}
uasort($files, function ($a, $b) use ($issueComponents) {
    $ia = $issueComponents[$a['key']] ?? 0;
    $ib = $issueComponents[$b['key']] ?? 0;
    if ($ia !== $ib) return $ib <=> $ia;
    return strcmp($a['path'], $b['path']);
});

// Languages by file count.
$langs = [];
foreach ($files as $f) {
    $l = $f['language'] !== '' ? $f['language'] : 'unknown';
    $langs[$l] = ($langs[$l] ?? 0) + 1;
}
arsort($langs);

// Hotspot counters.
$hotspotReview = 0;
foreach ($hotspots as $hs) if (($hs['status'] ?? '') === 'TO_REVIEW') $hotspotReview++;

// Measures grouped by registry domain.
$byDomain = [];
foreach ($vals as $mk => $mv) {
    $def = $metricDefs[$mk] ?? [];
    $domain = $def['domain'] ?? 'Other';
    $byDomain[$domain][$mk] = $mv;
}
uksort($byDomain, function ($a, $b) {
    $ia = array_search($a, DOMAIN_ORDER, true);
    $ib = array_search($b, DOMAIN_ORDER, true);
    if ($ia === false && $ib === false) return strcmp($a, $b);
    if ($ia === false) return 1;
    if ($ib === false) return -1;
    return $ia <=> $ib;
});
foreach ($byDomain as $domain => $items) {
    uksort($items, function ($a, $b) use ($metricDefs) {
        $pa = METRIC_PRIORITY[$a] ?? 100;
        $pb = METRIC_PRIORITY[$b] ?? 100;
        if ($pa !== $pb) return $pa <=> $pb;
        $na = $metricDefs[$a]['name'] ?? $a;
        $nb = $metricDefs[$b]['name'] ?? $b;
        return strcmp($na, $nb);
    });
    $byDomain[$domain] = $items;
}

/** Metric display name. */
function metric_name(string $mk, array $defs): string {
    return $defs[$mk]['name'] ?? METRIC_LABELS[$mk] ?? $mk;
}
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<link rel="icon" href="favicon.ico" type="image/x-icon">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SonarQube report · local-dev-stack</title>
<style>
  :root { color-scheme: light dark; }
  * { box-sizing: border-box; }
  body { font: 15px/1.5 system-ui, -apple-system, Segoe UI, Roboto, sans-serif; max-width: 1180px; margin: 2.5rem auto; padding: 0 1.25rem; }
  h1 { font-size: 1.4rem; margin: 0 0 .4rem; }
  h1 .muted { font-size: .85rem; font-weight: 400; }
  h2 { font-size: .95rem; margin: 1.8rem 0 .6rem; opacity: .75; text-transform: uppercase; letter-spacing: .05em; }
  h3 { font-size: .85rem; margin: .8rem 0 .3rem; font-weight: 600; }
  a { color: inherit; }
  .muted { opacity: .6; }
  .small { font-size: .8rem; }
  .row { display: flex; flex-wrap: wrap; gap: .75rem; align-items: center; }
  select, input, button { font: inherit; padding: .4rem .55rem; border: 1px solid #8886; border-radius: 7px; }
  select, input { background: Field; color: FieldText; }
  option { background: Field; color: FieldText; }
  button, .btn { cursor: pointer; background: transparent; color: inherit; border: 1px solid #4a9; }
  button { font: inherit; padding: .4rem .55rem; border-radius: 7px; }
  button:hover, .btn:hover { background: #4a91; }
  .btn { display: inline-block; padding: .4rem .55rem; border-radius: 7px; text-decoration: none; }
  button.primary { background: #2a8; color: #fff; border-color: #2a8; }
  .badge { padding: .15rem .6rem; border-radius: 7px; font-size: .8rem; font-weight: 600; border: 1px solid transparent; white-space: nowrap; }
  .badge.passed { color: #1a7f37; border-color: #1a7f3780; background: #1a7f3718; }
  .badge.failed { color: #c53030; border-color: #c5303080; background: #c5303018; }
  .badge.warn   { color: #b7791f; border-color: #b7791f80; background: #b7791f18; }
  .badge.none   { color: #718096; border-color: #71809680; background: #71809618; }
  .sev { padding: .05rem .45rem; border-radius: 6px; font-size: .72rem; font-weight: 700; border: 1px solid transparent; white-space: nowrap; text-transform: uppercase; }
  .sev-blocker  { color: #9b2c2c; border-color: #9b2c2c80; background: #9b2c2c18; }
  .sev-critical { color: #c53030; border-color: #c5303080; background: #c5303018; }
  .sev-major    { color: #c05621; border-color: #c0562180; background: #c0562118; }
  .sev-minor    { color: #b7791f; border-color: #b7791f80; background: #b7791f18; }
  .sev-info     { color: #4a5568; border-color: #4a556880; background: #4a556818; }
  .cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: .75rem; }
  .tile { border: 1px solid #8884; border-radius: 10px; padding: .6rem .8rem; }
  .tile .tv { font-size: 1.25rem; font-weight: 650; line-height: 1.3; }
  .tile .tl { font-size: .78rem; opacity: .65; margin-top: .15rem; }
  .rt { display: inline-block; min-width: 1.6em; text-align: center; padding: .05rem .35rem; border-radius: 6px; font-weight: 700; font-size: 1.05rem; }
  .ra { background: #1a7f3722; color: #1a7f37; } .rb { background: #5c940d22; color: #5c940d; }
  .rc { background: #b7791f22; color: #b7791f; } .rd { background: #c0562122; color: #c05621; }
  .re { background: #c5303022; color: #c53030; }
  table { border-collapse: collapse; width: 100%; font-size: .88rem; }
  th, td { text-align: left; padding: .35rem .5rem; border-bottom: 1px solid #8883; vertical-align: top; }
  th { font-size: .75rem; text-transform: uppercase; letter-spacing: .04em; opacity: .6; font-weight: 600; }
  thead { display: table-header-group; }
  tr { break-inside: avoid; }
  .path { word-break: break-word; }
  .mono, code { font-family: ui-monospace, SFMono-Regular, Consolas, monospace; font-size: .82em; }
  .chips { display: flex; flex-wrap: wrap; gap: .5rem; }
  .chip { border: 1px solid #8884; border-radius: 999px; padding: .2rem .7rem; font-size: .82rem; }
  .chip b { font-weight: 650; }
  .summary { display: flex; flex-wrap: wrap; gap: 1.4rem; align-items: center; margin: .8rem 0 0; }
  .summary .item { font-size: .9rem; }
  .summary .item b { font-size: 1.1rem; }
  .section-note { font-size: .85rem; opacity: .6; margin: .3rem 0 0; }
  .toolbar { margin: .9rem 0 1.2rem; }
  footer { margin-top: 2.5rem; font-size: .8rem; opacity: .6; border-top: 1px solid #8883; padding-top: .8rem; }
  .metricval { white-space: nowrap; }
  @media print {
    .no-print { display: none !important; }
    body { background: #fff; color: #000; max-width: none; margin: 0; padding: 0; }
    .tile { break-inside: avoid; border-color: #bbb; }
    .cards, .chips { break-inside: avoid; }
    th, td { border-color: #bbb; }
    h2, h3 { break-after: avoid; }
    h2 { opacity: 1; color: #444; }
    .muted, .tile .tl, .section-note, footer { opacity: 1; color: #444; }
    a { text-decoration: none; }
  }
</style>
</head>
<body>
<h1>SonarQube report
  <span class="muted">· <a href="/">control panel</a> · <a href="//sonarqube.test">sonarqube.test</a></span>
  <span class="muted" style="margin-left:12px">· <a class=\"btn\" href=\"//semgrep.test\" style=\"color:inherit;text-decoration:inherit">Semgrep report</a></span>
</h1>

<?php if ($key !== '' && $keyOk && $dataOk && !$download): ?>
<div class="row toolbar no-print">
  <button type="button" onclick="window.print()">Print / Save as PDF</button>
  <a class="btn" href="?<?= h(http_build_query(['key' => $key, 'download' => 1])) ?>">Download HTML</a>
  <a class="btn" href="//sonarqube.test/dashboard?id=<?= h(rawurlencode($key)) ?>">Open in SonarQube</a>
</div>
<?php endif; ?>

<?php if ($key === ''): ?>
  <p class="muted">Full printable project report: quality gate, every rating and measure,
     every issue, security hotspots, per-file metrics, duplications, rules and the analysis
     history. Community Build has no built-in export — print to PDF or download the HTML.</p>
  <?php if ($projects !== null && $projects !== []): ?>
    <form method="get" class="row">
      <select name="key" style="min-width:320px">
        <?php foreach ($projects as $p): ?>
          <option value="<?= h($p['key']) ?>"><?= h($p['name']) ?> (<?= h($p['key']) ?>)</option>
        <?php endforeach; ?>
      </select>
      <button class="primary">Open report</button>
    </form>
  <?php elseif ($projects !== null): ?>
    <p class="muted">No projects on this server yet — run a scan first: <code>lds tools sonar &lt;path&gt;</code>.</p>
    <form method="get" class="row">
      <input name="key" placeholder="project key">
      <button>Open report</button>
    </form>
  <?php else: ?>
    <p class="muted">
      Could not list projects (HTTP <?= h((string) $listStatus) ?>).
      <?php if ($listStatus === 0): ?>SonarQube looks unreachable — start it with <code>lds up sonarqube</code>.
      <?php elseif ($listStatus === 401 || $listStatus === 403): ?>Anonymous browsing may be disabled (<code>SONARQUBE_FORCE_AUTH</code>).
      <?php endif; ?>
      You can still open a report by key:
    </p>
    <form method="get" class="row">
      <input name="key" placeholder="project key">
      <button>Open report</button>
    </form>
  <?php endif; ?>

<?php elseif (!$keyOk): ?>
  <p><span class="badge failed">Invalid</span> project key <code><?= h($key) ?></code>.</p>
  <p><a class="btn" href="/sonar-report.php">Back to the picker</a></p>

<?php elseif (!$dataOk): ?>
  <?php $st = $show['status'] ?? 0; ?>
  <?php if ($st === 0): ?>
    <p><span class="badge failed">Unreachable</span> SonarQube is not answering at <code><?= h(SONAR_API) ?></code>.
       Start it with <code>lds up sonarqube</code>.</p>
  <?php elseif ($st === 404): ?>
    <p><span class="badge none">Not found</span> no project with key <code><?= h($key) ?></code> on this server.</p>
  <?php elseif ($st === 401 || $st === 403): ?>
    <p><span class="badge failed">HTTP <?= h((string) $st) ?></span> anonymous browsing is disabled
       (check <code>SONARQUBE_FORCE_AUTH</code>), or the project is not public.</p>
  <?php else: ?>
    <p><span class="badge failed">HTTP <?= h((string) $st) ?></span> could not load the project.</p>
  <?php endif; ?>
  <p><a class="btn" href="/sonar-report.php">Back to the picker</a></p>

<?php else: ?>
  <?php
    $comp     = $show['data']['component'] ?? [];
    $name     = $comp['name'] ?? $key;
    $analysis = $comp['analysisDate'] ?? null;
    $ts       = $analysis ? strtotime((string) $analysis) : false;
    [$gLabel, $gCls] = gate_badge($gateStatus);
    $revision = $analyses[0]['revision'] ?? null;
    $version  = $comp['version'] ?? '';
    if ($version === 'not provided') $version = '';
  ?>
  <p class="row" style="gap:.6rem">
    <b style="font-size:1.05rem"><?= h($name) ?></b>
  </p>
  <p class="muted small" style="margin-top:-.3rem">
    key <code><?= h($key) ?></code>
    <?php if (!empty($comp['qualifier'])): ?> · <?= h($comp['qualifier']) ?><?php endif; ?>
    <?php if (!empty($comp['visibility'])): ?> · <?= h($comp['visibility']) ?><?php endif; ?>
    <?php if ($version !== ''): ?> · version <?= h($version) ?><?php endif; ?>
    <?php if ($ts): ?> · analysed <?= h(date('Y-m-d H:i', $ts)) ?><?php endif; ?>
    <?php if ($revision): ?> · revision <code title="<?= h($revision) ?>"><?= h(substr($revision, 0, 12)) ?></code><?php endif; ?>
  </p>
  <?php if (!empty($comp['tags'])): ?>
    <div class="chips" style="margin:.4rem 0 0">
      <?php foreach ($comp['tags'] as $tg): ?><span class="chip"><?= h((string) $tg) ?></span><?php endforeach; ?>
    </div>
  <?php endif; ?>

  <div class="summary">
    <span class="item"><span class="badge <?= $gCls ?>">Quality gate: <?= h($gLabel) ?></span></span>
    <?php if ($caycStatus !== null): ?>
      <span class="item"><span class="badge none">Clean as You Code: <?= h(humanize($caycStatus)) ?></span></span>
    <?php endif; ?>
    <?php if ($issueTotal !== null): ?>
      <span class="item"><b><?= h(number_format($issueTotal)) ?></b> <span class="muted">issues</span></span>
      <span class="item"><b><?= h(fmt_min((string) $issueDebt)) ?></b> <span class="muted">debt</span></span>
    <?php endif; ?>
    <?php if ($hotspots): ?>
      <span class="item"><b><?= h(number_format($hotspotReview)) ?></b> <span class="muted">hotspots to review</span></span>
    <?php endif; ?>
    <?php foreach (['coverage' => 'coverage', 'duplicated_lines_density' => 'duplicated lines', 'ncloc' => 'lines of code', 'files' => 'files', 'complexity' => 'complexity'] as $mk => $label): ?>
      <?php if (isset($vals[$mk])): ?>
        <span class="item"><b><?= measure_display($metricDefs[$mk]['type'] ?? 'STRING', $vals[$mk]) ?></b> <span class="muted"><?= h($label) ?></span></span>
      <?php endif; ?>
    <?php endforeach; ?>
  </div>

  <h2>Quality gate conditions</h2>
  <?php if ($gateConds): ?>
    <table>
      <thead><tr><th>Metric</th><th>Condition</th><th>Threshold</th><th>Actual</th><th>Status</th></tr></thead>
      <tbody>
      <?php foreach ($gateConds as $c): ?>
        <?php
          $cst = $c['status'] ?? 'OK';
          $cmk = (string) ($c['metricKey'] ?? '');
          $ctype = $metricDefs[$cmk]['type'] ?? 'STRING';
        ?>
        <tr>
          <td><?= h(metric_name($cmk, $metricDefs)) ?><div class="muted small"><code><?= h($cmk) ?></code></div></td>
          <td><?= ($c['comparator'] ?? '') === 'GT' ? 'greater than' : 'less than' ?></td>
          <td class="metricval"><?= h(measure_display($ctype, (string) ($c['errorThreshold'] ?? ''))) ?></td>
          <td class="metricval"><?= isset($c['actualValue']) ? measure_display($ctype, (string) $c['actualValue']) : '—' ?></td>
          <td><span class="badge <?= $cst === 'ERROR' ? 'failed' : ($cst === 'WARN' ? 'warn' : 'passed') ?>"><?= h($cst) ?></span></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
    <?php if (!empty($gate['data']['projectStatus']['ignoredConditions'])): ?>
      <p class="section-note">Some conditions are ignored for this project.</p>
    <?php endif; ?>
  <?php else: ?>
    <p class="section-note">No conditions evaluated for this analysis.</p>
  <?php endif; ?>

  <?php $ratingTiles = array_values(array_filter(RATING_METRICS, fn($mk) => isset($vals[$mk]))); ?>
  <?php if ($ratingTiles): ?>
    <h2>Quality ratings</h2>
    <div class="cards">
      <?php foreach ($ratingTiles as $mk): ?>
        <div class="tile">
          <div class="tv"><?= measure_display('RATING', $vals[$mk]) ?></div>
          <div class="tl"><?= h(metric_name($mk, $metricDefs)) ?></div>
        </div>
      <?php endforeach; ?>
    </div>
  <?php endif; ?>

  <h2>Issues (<?= h(number_format(count($issuesAll))) ?>)</h2>
  <?php if ($issueTotal !== null && $issueTotal !== count($issuesAll)): ?>
    <p class="section-note">Issue API reported <?= h(number_format($issueTotal)) ?> total; <?= h(number_format(count($issuesAll))) ?> rows fetched (page cap).</p>
  <?php endif; ?>
  <?php if ($facets): ?>
    <?php foreach ($facets as $f): ?>
      <?php
        $prop   = (string) ($f['property'] ?? '');
        $values = array_values(array_filter($f['values'] ?? [], fn($fv) => (int) ($fv['count'] ?? 0) > 0));
        if (!$values) continue;
      ?>
      <h3 class="muted">By <?= h(FACET_LABELS[$prop] ?? humanize($prop)) ?></h3>
      <div class="chips">
        <?php foreach ($values as $fv): ?>
          <?php
            $val = (string) ($fv['val'] ?? '');
            if ($prop === 'types') $disp = TYPE_LABELS[$val] ?? humanize($val);
            elseif ($prop === 'rules') $disp = $ruleInfo[$val]['name'] ?? $val;
            elseif ($prop === 'languages') $disp = LANGUAGE_LABELS[$val] ?? $val;
            else $disp = humanize($val);
          ?>
          <span class="chip" title="<?= h($val) ?>"><?= h($disp) ?> <b><?= h(number_format((int) $fv['count'])) ?></b></span>
        <?php endforeach; ?>
      </div>
    <?php endforeach; ?>
  <?php else: ?>
    <p class="section-note">No issue facets returned.</p>
  <?php endif; ?>

  <?php if ($issuesAll): ?>
    <h3 class="muted" style="margin-top:1.2rem">All issues</h3>
    <table>
      <thead><tr>
        <th>#</th><th>Severity</th><th>Type</th><th>Rule</th><th>Message</th>
        <th>File / line</th><th>Effort</th><th>Status</th><th>Tags</th><th>Created</th>
      </tr></thead>
      <tbody>
      <?php foreach ($issuesAll as $i => $it): ?>
        <?php
          $sev = (string) ($it['severity'] ?? '');
          $rul = (string) ($it['rule'] ?? '');
          $rn  = $ruleInfo[$rul]['name'] ?? '';
          $line = $it['line'] ?? ($it['textRange']['startLine'] ?? null);
          $path = comp_path($key, (string) ($it['component'] ?? ''));
          $impacts = [];
          foreach ($it['impacts'] ?? [] as $im) {
              $impacts[] = humanize($im['softwareQuality'] ?? '') . ': ' . humanize($im['severity'] ?? '');
          }
          $status = (string) ($it['status'] ?? ($it['issueStatus'] ?? ''));
          $res    = (string) ($it['resolution'] ?? '');
        ?>
        <tr>
          <td class="muted"><?= $i + 1 ?></td>
          <td><span class="sev sev-<?= h(strtolower($sev)) ?>"><?= h($sev) ?></span></td>
          <td><?= h(TYPE_LABELS[$it['type'] ?? ''] ?? humanize($it['type'] ?? '')) ?></td>
          <td>
            <?= $rn !== '' ? h($rn) : h($rul) ?>
            <div class="muted small"><code><?= h($rul) ?></code></div>
          </td>
          <td>
            <?= h((string) ($it['message'] ?? '')) ?>
            <?php if ($impacts): ?><div class="muted small"><?= h(implode(' · ', $impacts)) ?></div><?php endif; ?>
            <?php foreach ($it['flows'] ?? [] as $fi => $flow): ?>
              <?php if (empty($flow['locations'])) continue; ?>
              <div class="small muted">flow <?= $fi + 1 ?>:
                <?php
                  $locParts = [];
                  foreach ($flow['locations'] as $loc) {
                      $lp  = comp_path($key, (string) ($loc['component'] ?? ''));
                      $ll  = $loc['textRange']['startLine'] ?? null;
                      $lm  = trim((string) ($loc['msg'] ?? ''));
                      $locParts[] = $lp . ($ll ? ':' . $ll : '') . ($lm !== '' ? ' (' . $lm . ')' : '');
                  }
                  echo h(implode(' → ', $locParts));
                ?>
              </div>
            <?php endforeach; ?>
          </td>
          <td class="path"><?= h($path ?: '—') ?><?= $line ? '<div class="muted small">line ' . h((string) $line) . '</div>' : '' ?></td>
          <td class="metricval"><?= h((string) ($it['debt'] ?? $it['effort'] ?? '—')) ?></td>
          <td class="small"><?= h($status) ?><?= $res !== '' ? '<div class="muted">' . h($res) . '</div>' : '' ?></td>
          <td class="small"><?= h(implode(', ', $it['tags'] ?? [])) ?></td>
          <td class="small muted"><?= h(fmt_date($it['creationDate'] ?? null)) ?></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  <?php endif; ?>

  <h2>Security hotspots (<?= h(number_format(count($hotspots))) ?>)</h2>
  <?php if ($hotspots): ?>
    <table>
      <thead><tr>
        <th>#</th><th>Probability</th><th>Status</th><th>Category</th><th>Rule</th>
        <th>Message</th><th>File / line</th><th>Comments</th><th>Created</th>
      </tr></thead>
      <tbody>
      <?php foreach ($hotspots as $i => $hs): ?>
        <?php
          $rk   = (string) ($hs['ruleKey'] ?? $hs['rule'] ?? '');
          $rn   = $ruleInfo[$rk]['name'] ?? '';
          $line = $hs['line'] ?? ($hs['textRange']['startLine'] ?? null);
          $path = comp_path($key, (string) ($hs['component'] ?? ''));
        ?>
        <tr>
          <td class="muted"><?= $i + 1 ?></td>
          <td><?= h(humanize($hs['vulnerabilityProbability'] ?? '')) ?></td>
          <td><?= h(humanize($hs['status'] ?? '')) ?></td>
          <td><?= h(humanize($hs['securityCategory'] ?? '')) ?></td>
          <td><?= $rn !== '' ? h($rn) : h($rk) ?><div class="muted small"><code><?= h($rk) ?></code></div></td>
          <td><?= h((string) ($hs['message'] ?? '')) ?></td>
          <td class="path"><?= h($path ?: '—') ?><?= $line ? '<div class="muted small">line ' . h((string) $line) . '</div>' : '' ?></td>
          <td class="small"><?= h((string) count($hs['comments'] ?? [])) ?></td>
          <td class="small muted"><?= h(fmt_date($hs['creationDate'] ?? null)) ?></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  <?php else: ?>
    <p class="section-note">No security hotspots in this project.</p>
  <?php endif; ?>

  <h2>Files (<?= h(number_format(count($files))) ?>)</h2>
  <?php if ($langs): ?>
    <div class="chips" style="margin-bottom:.6rem">
      <?php foreach ($langs as $l => $count): ?>
        <span class="chip"><?= h(LANGUAGE_LABELS[$l] ?? ucfirst($l)) ?> <b><?= h(number_format($count)) ?></b></span>
      <?php endforeach; ?>
    </div>
  <?php endif; ?>
  <?php if ($files): ?>
    <?php $sum = ['ncloc' => 0, 'complexity' => 0, 'cognitive_complexity' => 0, 'bugs' => 0, 'vulnerabilities' => 0, 'code_smells' => 0, 'issues' => 0, 'debt' => 0]; ?>
    <table>
      <thead><tr>
        <th>File</th><th>Lang</th><th>NCLOC</th><th>Complexity</th><th>Cognitive</th>
        <th>Bugs</th><th>Vulns</th><th>Smells</th><th>Issues</th><th>Debt</th>
        <th>Coverage</th><th>Dup</th>
      </tr></thead>
      <tbody>
      <?php foreach ($files as $f): ?>
        <?php
          $mm  = $fileMeasures[$f['key']] ?? [];
          $cnt = $issueComponents[$f['key']] ?? 0;
          $dbt = $fileDebt[$f['key']] ?? 0;
          $sum['ncloc']              += (int) ($mm['ncloc'] ?? 0);
          $sum['complexity']         += (int) ($mm['complexity'] ?? 0);
          $sum['cognitive_complexity'] += (int) ($mm['cognitive_complexity'] ?? 0);
          $sum['bugs']               += (int) ($mm['bugs'] ?? 0);
          $sum['vulnerabilities']    += (int) ($mm['vulnerabilities'] ?? 0);
          $sum['code_smells']        += (int) ($mm['code_smells'] ?? 0);
          $sum['issues']             += $cnt;
          $sum['debt']               += $dbt;
        ?>
        <tr>
          <td class="path"><?= h($f['path']) ?></td>
          <td><?= h($f['language'] !== '' ? (LANGUAGE_LABELS[$f['language']] ?? $f['language']) : '—') ?></td>
          <td class="metricval"><?= isset($mm['ncloc']) ? h(fmt_int($mm['ncloc'])) : '—' ?></td>
          <td class="metricval"><?= isset($mm['complexity']) ? h(fmt_int($mm['complexity'])) : '—' ?></td>
          <td class="metricval"><?= isset($mm['cognitive_complexity']) ? h(fmt_int($mm['cognitive_complexity'])) : '—' ?></td>
          <td class="metricval"><?= isset($mm['bugs']) ? h(fmt_int($mm['bugs'])) : '—' ?></td>
          <td class="metricval"><?= isset($mm['vulnerabilities']) ? h(fmt_int($mm['vulnerabilities'])) : '—' ?></td>
          <td class="metricval"><?= isset($mm['code_smells']) ? h(fmt_int($mm['code_smells'])) : '—' ?></td>
          <td class="metricval"><?= $cnt ? h(fmt_int((string) $cnt)) : '—' ?></td>
          <td class="metricval"><?= $dbt ? h(fmt_min((string) $dbt)) : '—' ?></td>
          <td class="metricval"><?= isset($mm['coverage']) ? h(fmt_pct($mm['coverage'])) : '—' ?></td>
          <td class="metricval"><?= isset($mm['duplicated_lines_density']) ? h(fmt_pct($mm['duplicated_lines_density'])) : '—' ?></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
      <tfoot>
        <tr>
          <th>Total (<?= h(number_format(count($files))) ?> files)</th>
          <th></th>
          <th><?= h(fmt_int((string) $sum['ncloc'])) ?></th>
          <th><?= h(fmt_int((string) $sum['complexity'])) ?></th>
          <th><?= h(fmt_int((string) $sum['cognitive_complexity'])) ?></th>
          <th><?= h(fmt_int((string) $sum['bugs'])) ?></th>
          <th><?= h(fmt_int((string) $sum['vulnerabilities'])) ?></th>
          <th><?= h(fmt_int((string) $sum['code_smells'])) ?></th>
          <th><?= h(fmt_int((string) $sum['issues'])) ?></th>
          <th><?= h(fmt_min((string) $sum['debt'])) ?></th>
          <th></th><th></th>
        </tr>
      </tfoot>
    </table>
  <?php else: ?>
    <p class="section-note">No files indexed.</p>
  <?php endif; ?>

  <h2>Duplications (<?= h(number_format(count($dupGroups))) ?> groups)</h2>
  <?php if ($dupGroups): ?>
    <table>
      <thead><tr><th>#</th><th>Lines</th><th>Duplicated blocks</th></tr></thead>
      <tbody>
      <?php $dn = 0; foreach ($dupGroups as $blocks): $dn++; ?>
        <tr>
          <td class="muted"><?= $dn ?></td>
          <td class="metricval"><?= h(fmt_int((string) ($blocks[0]['size'] ?? 0))) ?></td>
          <td class="path">
            <?php
              $parts = [];
              foreach ($blocks as $b) {
                  $end = $b['from'] + max(0, $b['size'] - 1);
                  $parts[] = h($b['path']) . ' <span class="muted small">:' . h((string) $b['from']) . '–' . h((string) $end) . '</span>';
              }
              echo implode('<br>↔ ', $parts);
            ?>
          </td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  <?php else: ?>
    <p class="section-note">No duplicated blocks in this project.</p>
  <?php endif; ?>

  <h2>All measures (<?= h(number_format(count($vals))) ?>)</h2>
  <?php if ($byDomain): ?>
    <?php foreach ($byDomain as $domain => $items): ?>
      <h3 class="muted"><?= h($domain !== '' ? $domain : 'Other') ?></h3>
      <table>
        <thead><tr><th>Metric</th><th>Key</th><th>Value</th></tr></thead>
        <tbody>
        <?php foreach ($items as $mk => $mv): ?>
          <?php $mtype = $metricDefs[$mk]['type'] ?? 'STRING'; ?>
          <tr>
            <td><?= h(metric_name($mk, $metricDefs)) ?></td>
            <td class="muted small"><code><?= h($mk) ?></code></td>
            <td class="metricval"><?= measure_display($mtype, $mv) ?></td>
          </tr>
        <?php endforeach; ?>
        </tbody>
      </table>
    <?php endforeach; ?>
  <?php else: ?>
    <p class="section-note">No measures returned.</p>
  <?php endif; ?>

  <h2>Analysis history (<?= h(number_format(count($analyses))) ?>)</h2>
  <?php if ($analyses): ?>
    <table>
      <thead><tr><th>Date</th><th>Version</th><th>Revision</th><th>Events</th></tr></thead>
      <tbody>
      <?php foreach ($analyses as $a): ?>
        <?php
          $events = [];
          foreach ($a['events'] ?? [] as $ev) {
              $events[] = humanize($ev['category'] ?? '') . ': ' . (string) ($ev['name'] ?? '');
          }
        ?>
        <tr>
          <td><?= h(fmt_date($a['date'] ?? null)) ?></td>
          <td><?= h((string) ($a['projectVersion'] ?? '')) ?></td>
          <td class="small"><code><?= h((string) ($a['revision'] ?? '—')) ?></code></td>
          <td class="small"><?= h(implode(' · ', $events)) ?></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  <?php else: ?>
    <p class="section-note">No analysis history available.</p>
  <?php endif; ?>
<?php endif; ?>

<footer>
  generated <?= h(date('Y-m-d H:i')) ?> · data from the SonarQube Web API (anonymous read-only)
</footer>
</body>
</html>
