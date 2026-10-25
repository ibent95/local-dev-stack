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

// Optional SonarQube user token (SONAR_TOKEN — passed into this container by
// compose, read from the git-ignored .env). The Web API omits rule
// descriptions for anonymous callers, and those descriptions are exactly the
// "why this issue was raised" / "how to fix" text this report renders, so we
// authenticate when we can. Validated once per request: a stale token is
// dropped instead of turning every API call into a 401.
$SONAR_TOKEN = trim((string) getenv('SONAR_TOKEN'));
if ($SONAR_TOKEN !== '') {
    $vr = sonar_request(SONAR_API . '/api/authentication/validate');
    if (!$vr['ok'] || ($vr['data']['valid'] ?? false) !== true) $SONAR_TOKEN = '';
}

/** Accept header + `Authorization: Bearer` when a token is in play. */
function sonar_headers(): array {
    global $SONAR_TOKEN;
    $h = ['Accept: application/json'];
    if ($SONAR_TOKEN !== '') $h[] = 'Authorization: Bearer ' . $SONAR_TOKEN;
    return $h;
}

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
        CURLOPT_HTTPHEADER     => sonar_headers(),
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
                CURLOPT_HTTPHEADER     => sonar_headers(),
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

/** Issue severity → badge/pill css class (the Semgrep palette). */
function sev_class(?string $s): string {
    return match (strtoupper((string) $s)) {
        'BLOCKER', 'CRITICAL' => 'error',
        'MAJOR'                => 'warning',
        'MINOR'                => 'note',
        default                => 'none',
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

// Aggregates for the stat tiles and the "by severity / rule / file" panels.
$sevCounts = [];
$typeCounts = [];
$ruleAgg = [];
$fileAgg = [];
foreach ($issuesAll as $it) {
    $sev  = strtoupper((string) ($it['severity'] ?? ''));
    $type = strtoupper((string) ($it['type'] ?? ''));
    $rul  = (string) ($it['rule'] ?? '');
    $path = comp_path($key, (string) ($it['component'] ?? ''));
    if ($sev !== '')  $sevCounts[$sev]   = ($sevCounts[$sev] ?? 0) + 1;
    if ($type !== '') $typeCounts[$type] = ($typeCounts[$type] ?? 0) + 1;
    $fileAgg[$path]['total'] = ($fileAgg[$path]['total'] ?? 0) + 1;
    if ($type !== '') $fileAgg[$path][$type] = ($fileAgg[$path][$type] ?? 0) + 1;
    if ($rul !== '') {
        if (!isset($ruleAgg[$rul])) $ruleAgg[$rul] = ['count' => 0, 'files' => [], 'sev' => ''];
        $ruleAgg[$rul]['count']++;
        $ruleAgg[$rul]['files'][$path] = true;
        if ($sev !== '' && ($ruleAgg[$rul]['sev'] === ''
            || (SEVERITY_ORDER[$sev] ?? 9) < (SEVERITY_ORDER[$ruleAgg[$rul]['sev']] ?? 9))) {
            $ruleAgg[$rul]['sev'] = $sev;
        }
    }
}
uasort($ruleAgg, fn($a, $b) => $b['count'] <=> $a['count']);
uasort($fileAgg, fn($a, $b) => ($b['total'] ?? 0) <=> ($a['total'] ?? 0));

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
  :root { color-scheme: light dark; --line:#8884; --line2:#8882; --muted:#7d8590; --card:rgba(127,127,127,.04); --accent:#6366f1; --err:#e5484d; --warn:#c47f00; --note:#3b82f5; --ok:#2f9e44; }
  @media (prefers-color-scheme: dark) { :root { --card:rgba(255,255,255,.035); --warn:#f5a623; --ok:#3fb950; } }
  * { box-sizing:border-box; }
  body { margin:0; font:14px/1.5 system-ui,'Segoe UI',Roboto,sans-serif; background:Canvas; color:CanvasText; }
  .top { display:flex; flex-wrap:wrap; gap:14px; align-items:flex-start; justify-content:space-between; padding:18px 22px 14px; border-bottom:1px solid var(--line); }
  .brand h1 { margin:0; font-size:20px; font-weight:650; letter-spacing:-.01em; }
  .brand h1 span { margin-left:8px; font-size:11px; font-weight:500; letter-spacing:.04em; text-transform:uppercase; color:var(--muted); }
  .meta { margin-top:4px; max-width:115ch; font-size:12px; color:var(--muted); }
  .actions { display:flex; flex-wrap:wrap; gap:8px; }
  button, a.btn { display:inline-flex; align-items:center; gap:6px; padding:6px 12px; border:1px solid var(--line); border-radius:6px; background:transparent; color:inherit; font:inherit; text-decoration:none; cursor:pointer; }
  button:hover, a.btn:hover { background:var(--card); border-color:var(--muted); }
  button:disabled { opacity:.45; cursor:not-allowed; }
  main { max-width:1500px; margin:0 auto; padding:18px 22px 60px; }
  .stats { display:grid; grid-template-columns:repeat(auto-fit,minmax(130px,1fr)); gap:10px; margin-bottom:16px; }
  .tile { display:flex; flex-direction:column; gap:2px; padding:12px 14px; border:1px solid var(--line); border-radius:10px; background:var(--card); }
  .tile .num { font-size:24px; font-weight:700; line-height:1.1; font-variant-numeric:tabular-nums; }
  .tile .lbl { font-size:11px; font-weight:600; letter-spacing:.06em; text-transform:uppercase; color:var(--muted); }
  .tile.sev-error .num { color:var(--err); } .tile.sev-warning .num { color:var(--warn); } .tile.sev-note .num { color:var(--note); }
  .tile.gate-ok .num { color:var(--ok); font-size:19px; }
  .tile.gate-fail .num { color:var(--err); font-size:19px; }
  .tile.gate-warn .num { color:var(--warn); font-size:19px; }
  .tile.gate-none .num { color:var(--muted); font-size:17px; }
  .panels { display:grid; grid-template-columns:minmax(0,1.25fr) minmax(0,1fr); gap:14px; }
  .panels.even { grid-template-columns:minmax(0,1fr) minmax(0,1fr); }
  @media (max-width:900px) { .panels, .panels.even { grid-template-columns:1fr; } }
  .panel { margin-bottom:14px; border:1px solid var(--line); border-radius:10px; background:var(--card); overflow:hidden; }
  .panel h2 { display:flex; align-items:baseline; justify-content:space-between; gap:10px; margin:0; padding:12px 16px; border-bottom:1px solid var(--line); font-size:12px; font-weight:600; letter-spacing:.06em; text-transform:uppercase; }
  .panel h2 .hint { font-size:11px; font-weight:400; letter-spacing:0; text-transform:none; color:var(--muted); }
  .scroll { max-height:340px; overflow:auto; }
  table { width:100%; border-collapse:collapse; }
  th, td { padding:8px 14px; border-bottom:1px solid var(--line2); text-align:left; vertical-align:top; }
  th { position:sticky; top:0; z-index:1; background:Canvas; font-size:11px; font-weight:600; letter-spacing:.05em; text-transform:uppercase; color:var(--muted); }
  .mini th, .mini td { padding:7px 14px; }
  tbody tr:last-child td { border-bottom:0; }
  tfoot th { position:static; border-top:1px solid var(--line); }
  tr[data-rule], tr[data-file] { cursor:pointer; }
  tr[data-rule]:hover, tr[data-file]:hover { background:var(--card); }
  tr.active { background:rgba(99,102,241,.1); }
  .n { text-align:right; white-space:nowrap; font-variant-numeric:tabular-nums; }
  .n.err { color:var(--err); } .n.warn { color:var(--warn); } .n.note { color:var(--note); }
  code { padding:1px 5px; border-radius:4px; background:#8881; font:12px/1.45 ui-monospace,Consolas,'Cascadia Code',monospace; word-break:break-word; }
  .sub { margin-top:2px; font-size:11px; color:var(--muted); }
  .muted { color:var(--muted); }
  .small { font-size:11px; }
  .path { min-width:180px; word-break:break-all; } .path code { padding:0; background:none; }
  .badge { display:inline-block; padding:2px 9px; border:1px solid transparent; border-radius:999px; font-size:10px; font-weight:700; letter-spacing:.03em; text-transform:uppercase; white-space:nowrap; }
  .badge.error, .badge.failed { background:rgba(229,72,77,.13); border-color:rgba(229,72,77,.27); color:var(--err); }
  .badge.warning, .badge.warn { background:rgba(245,166,35,.13); border-color:rgba(245,166,35,.33); color:var(--warn); }
  .badge.note { background:rgba(59,130,246,.13); border-color:rgba(59,130,246,.33); color:var(--note); }
  .badge.passed { background:rgba(47,158,68,.13); border-color:rgba(47,158,68,.3); color:var(--ok); }
  .badge.none { background:transparent; border-color:var(--line); color:var(--muted); }
  .rt { display:inline-flex; align-items:center; justify-content:center; min-width:26px; height:26px; padding:0 6px; border-radius:6px; font-size:13px; font-weight:700; color:#fff; }
  .rt.ra { background:#2f9e44; } .rt.rb { background:#82c91e; color:#14210a; } .rt.rc { background:#f0b400; color:#2a1f00; } .rt.rd { background:#f76707; } .rt.re { background:#e5484d; }
  .tags { display:flex; flex-direction:column; gap:12px; padding:14px 16px; }
  .tag-group { display:flex; flex-wrap:wrap; align-items:center; gap:6px; }
  .tag-group h3 { width:100%; margin:0 0 2px; font-size:11px; font-weight:600; letter-spacing:.05em; text-transform:uppercase; color:var(--muted); }
  .tag { display:inline-flex; align-items:center; gap:6px; padding:3px 10px; border:1px solid var(--line); border-radius:999px; background:transparent; color:inherit; font:inherit; font-size:12px; cursor:pointer; }
  .tag:hover { border-color:var(--muted); }
  .tag.active { border-color:var(--accent); background:var(--accent); color:#fff; }
  .tag .n { font-size:11px; opacity:.75; }
  .chip { display:inline-flex; align-items:center; gap:5px; padding:2px 9px; border:1px solid var(--line); border-radius:999px; font-size:11px; color:var(--muted); }
  .chip b { color:inherit; font-variant-numeric:tabular-nums; }
  .chips { display:flex; flex-wrap:wrap; gap:6px; }
  .toolbar { display:flex; flex-wrap:wrap; align-items:center; gap:8px; padding:12px 16px; border-bottom:1px solid var(--line); }
  .toolbar input, .toolbar select { padding:6px 10px; border:1px solid var(--line); border-radius:6px; background:transparent; color:inherit; font:inherit; }
  .toolbar input { flex:1; min-width:200px; }
  .toolbar select { max-width:320px; }
  .sev-filters { display:flex; flex-wrap:wrap; gap:6px; }
  .pill { padding:3px 10px; border:1px solid var(--line); border-radius:999px; background:transparent; color:inherit; font:inherit; font-size:12px; font-weight:600; cursor:pointer; }
  .pill:hover { background:var(--card); }
  .pill.all.active { border-color:var(--accent); background:var(--accent); color:#fff; }
  .pill.error { color:var(--err); } .pill.warning { color:var(--warn); } .pill.note { color:var(--note); }
  .pill.off { opacity:.35; text-decoration:line-through; }
  .filter-note { display:flex; flex-wrap:wrap; gap:6px; padding:10px 16px; border-bottom:1px solid var(--line); }
  .fchip { display:inline-flex; align-items:center; gap:5px; padding:3px 10px; border:1px solid var(--accent); border-radius:999px; background:rgba(99,102,241,.08); color:inherit; font:inherit; font-size:12px; cursor:pointer; }
  .fchip code { background:none; padding:0; }
  .finding { cursor:pointer; }
  .finding:hover { background:var(--card); }
  .finding:focus-visible { outline:2px solid var(--accent); outline-offset:-2px; }
  .finding .caret { width:26px; color:var(--muted); font-size:11px; transition:transform .12s ease; }
  .finding.open .caret { transform:rotate(90deg); }
  .finding .msg { max-width:78ch; }
  .finding .loc code { background:none; padding:0; }
  .finding .rule code { background:none; padding:0; }
  .sev { white-space:nowrap; }
  tr.detail > td { padding:16px 20px; background:var(--card); }
  .detail-grid { display:grid; grid-template-columns:minmax(0,1.2fr) minmax(0,1fr); gap:22px; }
  @media (max-width:900px) { .detail-grid { grid-template-columns:1fr; } }
  .detail h3 { margin:14px 0 4px; font-size:11px; font-weight:600; letter-spacing:.05em; text-transform:uppercase; color:var(--muted); }
  .detail h3:first-child { margin-top:0; }
  .detail p { margin:0 0 6px; }
  .detail .message { max-width:95ch; white-space:pre-wrap; }
  .detail .desc { max-width:95ch; color:var(--muted); }
  .detail .chips { margin-top:8px; }
  /* SonarQube rule-description HTML (why / how to fix, with code examples). */
  .detail .doc { max-width:95ch; }
  .detail .doc p { margin:0 0 6px; }
  .detail .doc h4 { margin:14px 0 4px; font-size:11px; font-weight:600; letter-spacing:.05em; text-transform:uppercase; color:var(--muted); }
  .detail .doc ul, .detail .doc ol { margin:0 0 6px; padding-left:20px; }
  .detail .doc li { margin-bottom:2px; }
  .detail .doc pre { max-height:300px; margin:6px 0 8px; padding:10px 12px; border:1px solid var(--line); border-radius:8px; background:Canvas; overflow:auto; font-size:12px; white-space:pre-wrap; }
  .detail .doc code { font-size:12px; }
  .detail .doc a { color:var(--accent); }
  .detail .doc img { max-width:100%; }
  .detail .doc h4:first-child, .detail .doc p:first-child { margin-top:0; }
  pre.snippet { max-height:220px; margin:6px 0 0; padding:10px 12px; border:1px solid var(--line); border-radius:8px; background:Canvas; overflow:auto; }
  pre.snippet code { padding:0; background:none; font-size:12px; white-space:pre; }
  .meta-list { display:grid; grid-template-columns:auto 1fr; gap:4px 12px; margin:0; font-size:12px; }
  .meta-list dt { color:var(--muted); } .meta-list dd { margin:0; }
  .pager { display:flex; align-items:center; justify-content:flex-end; gap:10px; padding:10px 16px; border-top:1px solid var(--line); font-size:12px; color:var(--muted); }
  .rating-row { display:grid; grid-template-columns:repeat(auto-fit,minmax(130px,1fr)); gap:10px; padding:14px 16px; }
  .rating { display:flex; align-items:center; gap:10px; padding:10px 12px; border:1px solid var(--line); border-radius:10px; background:Canvas; }
  .rating .rl { font-size:12px; color:var(--muted); }
  .grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(320px,1fr)); gap:12px; padding:14px 16px; }
  .mini-panel { border:1px solid var(--line); border-radius:10px; background:Canvas; overflow:hidden; }
  .mini-panel h3 { margin:0; padding:10px 14px; border-bottom:1px solid var(--line); font-size:11px; font-weight:600; letter-spacing:.05em; text-transform:uppercase; color:var(--muted); }
  .no-rows { padding:22px 16px; text-align:center; color:var(--muted); }
  .section-note { margin:0; padding:10px 16px; color:var(--muted); font-size:12px; border-top:1px solid var(--line2); }
  .print-head { display:none; }
  .foot { padding:16px 22px; border-top:1px solid var(--line); color:var(--muted); font-size:12px; }
  @media print {
    @page { margin:14mm; }
    body { background:#fff; color:#000; }
    .top { padding:0 0 10px; border-bottom:2px solid #000; }
    .top .meta, .actions, .toolbar, .pager, .filter-note, .hint, .foot { display:none !important; }
    main { max-width:none; padding:10px 0 0; }
    .stats { gap:6px; }
    .tile, .panel, .mini-panel, .rating { border-color:#bbb; background:#fff; }
    .scroll { max-height:none; overflow:visible; }
    a { color:#000; text-decoration:none; }
    .print-head { display:block; margin:10px 0 0; font-size:12px; }
    .print-head p { margin:0; }
    th { position:static; background:#fff; color:#444; }
    thead { display:table-header-group; }
    tr { break-inside:avoid; }
    .badge { border:1px solid #999 !important; background:#fff !important; color:#000 !important; }
    .rt { border:1px solid #999; background:#fff !important; color:#000 !important; }
    .tile.sev-error .num, .tile.sev-warning .num, .tile.sev-note .num, .n.err, .n.warn, .n.note,
    .tile.gate-ok .num, .tile.gate-fail .num, .tile.gate-warn .num, .tile.gate-none .num { color:#000; }
    .tag, .chip, .fchip { border-color:#bbb; }
    .tag.active { background:#eee; color:#000; }
    .detail { break-inside:avoid; }
  }
</style>
</head>
<body>
<?php
  $isReport = $key !== '' && $keyOk && $dataOk;
  $comp     = $isReport ? ($show['data']['component'] ?? []) : [];
  $projName = $comp['name'] ?? $key;
  $analysis = $comp['analysisDate'] ?? null;
  $ts       = $analysis ? strtotime((string) $analysis) : false;
  $revision = $isReport ? ($analyses[0]['revision'] ?? null) : null;
  $version  = (string) ($comp['version'] ?? '');
  if ($version === 'not provided') $version = '';
  [$gLabel, $gCls] = gate_badge($gateStatus);
  $gateCls = $gCls === 'passed' ? 'ok' : ($gCls === 'failed' ? 'fail' : ($gCls === 'warn' ? 'warn' : 'none'));

  // Findings payload for the Semgrep-style client-side report (rendering,
  // filtering, sorting, paging and expandable detail rows all happen in JS).
  $issueRows = [];
  if ($isReport) {
      foreach ($issuesAll as $it) {
          $sev  = (string) ($it['severity'] ?? '');
          $rul  = (string) ($it['rule'] ?? '');
          $line = $it['line'] ?? ($it['textRange']['startLine'] ?? 0);
          $path = comp_path($key, (string) ($it['component'] ?? ''));
          $impacts = [];
          foreach ($it['impacts'] ?? [] as $im) {
              $impacts[] = humanize($im['softwareQuality'] ?? '') . ': ' . humanize($im['severity'] ?? '');
          }
          $flows = [];
          foreach ($it['flows'] ?? [] as $flow) {
              if (empty($flow['locations'])) continue;
              $locParts = [];
              foreach ($flow['locations'] as $loc) {
                  $lp = comp_path($key, (string) ($loc['component'] ?? ''));
                  $ll = $loc['textRange']['startLine'] ?? null;
                  $lm = trim((string) ($loc['msg'] ?? ''));
                  $locParts[] = $lp . ($ll ? ':' . $ll : '') . ($lm !== '' ? ' (' . $lm . ')' : '');
              }
              $flows[] = implode(' → ', $locParts);
          }
          $issueUrl = '//sonarqube.test/project/issues?' . http_build_query([
              'id' => $key, 'open' => (string) ($it['key'] ?? ''), 'resolved' => 'false',
          ]);
          $issueRows[] = [
              'k'         => (string) ($it['key'] ?? ($rul . '|' . $path . '|' . $line)),
              'sev'       => $sev,
              'type'      => (string) ($it['type'] ?? ''),
              'typeLabel' => TYPE_LABELS[$it['type'] ?? ''] ?? humanize($it['type'] ?? ''),
              'rule'      => $rul,
              'file'      => $path,
              'line'      => (int) $line,
              'msg'       => (string) ($it['message'] ?? ''),
              'impacts'   => $impacts,
              'flows'     => $flows,
              'status'    => humanize($it['status'] ?? ($it['issueStatus'] ?? '')),
              'resolution'=> humanize($it['resolution'] ?? ''),
              'effort'    => (string) ($it['debt'] ?? $it['effort'] ?? ''),
              'created'   => fmt_date($it['creationDate'] ?? null),
              'tags'      => array_values($it['tags'] ?? []),
              'url'       => $issueUrl,
          ];
      }
  }

  // Rule metadata: name, a short plain-text summary, and — when the caller is
  // authenticated (SONAR_TOKEN) — the full rule description sections. Those
  // sections are SonarQube's "why this issue was raised" + "how to fix"
  // (including its noncompliant/compliant code examples): the Web API only
  // returns them to authenticated callers, never anonymously.
  $ruleMeta = [];
  if ($isReport) {
      foreach ($ruleInfo as $rk => $r) {
          $desc = (string) ($r['htmlDesc'] ?? $r['mdDesc'] ?? '');
          $secs = [];
          foreach ($r['descriptionSections'] ?? [] as $sec) {
              $k = (string) ($sec['key'] ?? '');
              $c = (string) ($sec['content'] ?? '');
              if ($k === '' || $c === '') continue;
              // Rule docs are SonarSource's own HTML; drop executable bits only.
              $c = preg_replace('#<\s*(script|iframe|object|embed)\b[^>]*>.*?<\s*/\s*\1\s*>#is', '', $c);
              $c = preg_replace('#<\s*(script|iframe|object|embed)\b[^>]*/?>#is', '', $c);
              $secs[$k] = $c;
          }
          if ($desc === '') {
              $plain = trim(preg_replace('/\s+/', ' ', strip_tags($secs['root_cause'] ?? ($secs['introduction'] ?? ''))));
              $desc  = $plain;
          }
          $desc = trim(preg_replace('/\s+/', ' ', strip_tags($desc)));
          if (strlen($desc) > 700) $desc = substr($desc, 0, 697) . '…';
          $entry = ['n' => (string) ($r['name'] ?? ''), 'd' => $desc];
          if ($secs) $entry['s'] = $secs;
          $ruleMeta[$rk] = $entry;
      }
  }
  // Is there anything to show under "How to fix"? (anonymous -> no sections)
  $ruleDocs = false;
  foreach ($ruleMeta as $entry) if (!empty($entry['s'])) { $ruleDocs = true; break; }
  $jsonFlags = JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT;
?>
<header class="top">
  <div class="brand">
    <h1>SonarQube <span>code quality</span></h1>
    <div class="meta">
      <?php if ($isReport): ?>
        <b><?= h($projName) ?></b> · key <code><?= h($key) ?></code>
        <?php if (!empty($comp['visibility'])): ?> · <?= h(strtolower((string) $comp['visibility'])) ?><?php endif; ?>
        <?php if ($version !== ''): ?> · v<?= h($version) ?><?php endif; ?>
        <?php if ($ts): ?> · analysed <?= h(date('Y-m-d H:i', $ts)) ?><?php endif; ?>
        <?php if ($revision): ?> · rev <?= h(substr((string) $revision, 0, 12)) ?><?php endif; ?>
      <?php elseif ($key === ''): ?>
        Printable full project report — quality gate, ratings, every measure, every issue,
        security hotspots, per-file metrics, duplications and the analysis history.
      <?php else: ?>
        Report request for <code><?= h($key) ?></code>.
      <?php endif; ?>
    </div>
  </div>
  <div class="actions">
    <?php if ($isReport): ?>
      <button type="button" id="printBtn">Print report</button>
      <a class="btn" href="?<?= h(http_build_query(['key' => $key, 'download' => 1])) ?>">Download HTML</a>
      <a class="btn" href="//sonarqube.test/dashboard?id=<?= h(rawurlencode($key)) ?>" target="_blank" rel="noopener">Open in SonarQube</a>
    <?php endif; ?>
    <a class="btn" href="/sonar-report.php">All projects</a>
    <a class="btn" href="/">Control panel</a>
    <a class="btn" href="//semgrep.test" target="_blank" rel="noopener">Semgrep report</a>
  </div>
</header>

<?php if ($key === ''): ?>
<main>
  <?php if ($projects !== null && $projects !== []): ?>
    <section class="panel">
      <h2>Projects <span class="hint"><?= h(number_format(count($projects))) ?> found — pick one to build the report</span></h2>
      <div class="scroll">
        <table class="mini">
          <thead><tr><th>Project</th><th>Key</th><th class="n"></th></tr></thead>
          <tbody>
          <?php foreach ($projects as $p): ?>
            <tr>
              <td><b><?= h((string) ($p['name'] ?? $p['key'])) ?></b></td>
              <td><code><?= h((string) ($p['key'] ?? '')) ?></code></td>
              <td class="n"><a class="btn" href="?key=<?= h(rawurlencode((string) ($p['key'] ?? ''))) ?>">Open report</a></td>
            </tr>
          <?php endforeach; ?>
          </tbody>
        </table>
      </div>
      <div class="toolbar">
        <form method="get" style="display:flex;flex-wrap:wrap;gap:8px;flex:1">
          <input name="key" placeholder="…or type a project key" aria-label="Project key">
          <button type="submit">Open report</button>
        </form>
      </div>
    </section>
  <?php elseif ($projects !== null): ?>
    <section class="panel">
      <h2>Projects <span class="hint">none yet</span></h2>
      <p class="no-rows">No projects on this server yet — run a scan first: <code>lds tools sonar &lt;path&gt;</code>.</p>
      <div class="toolbar">
        <form method="get" style="display:flex;flex-wrap:wrap;gap:8px;flex:1">
          <input name="key" placeholder="project key" aria-label="Project key">
          <button type="submit">Open report</button>
        </form>
      </div>
    </section>
  <?php else: ?>
    <section class="panel">
      <h2>Projects <span class="hint">listing failed</span></h2>
      <p class="no-rows">
        Could not list projects (HTTP <?= h((string) $listStatus) ?>).
        <?php if ($listStatus === 0): ?>SonarQube looks unreachable — start it with <code>lds up sonarqube</code>.
        <?php elseif ($listStatus === 401 || $listStatus === 403): ?>Anonymous browsing may be disabled (<code>SONARQUBE_FORCE_AUTH</code>).
        <?php endif; ?>
      </p>
      <div class="toolbar">
        <form method="get" style="display:flex;flex-wrap:wrap;gap:8px;flex:1">
          <input name="key" placeholder="project key" aria-label="Project key">
          <button type="submit">Open report</button>
        </form>
      </div>
    </section>
  <?php endif; ?>
</main>

<?php elseif (!$keyOk): ?>
<main>
  <section class="panel">
    <h2>Invalid project key</h2>
    <p class="no-rows"><span class="badge failed">Invalid</span> <code><?= h($key) ?></code> is not a valid SonarQube key.</p>
  </section>
</main>

<?php elseif (!$dataOk): ?>
<main>
  <section class="panel">
    <h2>Project unavailable</h2>
    <p class="no-rows">
      <?php $st = $show['status'] ?? 0; ?>
      <?php if ($st === 0): ?>
        <span class="badge failed">Unreachable</span> SonarQube is not answering at <code><?= h(SONAR_API) ?></code>.
        Start it with <code>lds up sonarqube</code>.
      <?php elseif ($st === 404): ?>
        <span class="badge none">Not found</span> no project with key <code><?= h($key) ?></code> on this server.
      <?php elseif ($st === 401 || $st === 403): ?>
        <span class="badge failed">HTTP <?= h((string) $st) ?></span> anonymous browsing is disabled
        (check <code>SONARQUBE_FORCE_AUTH</code>), or the project is not public.
      <?php else: ?>
        <span class="badge failed">HTTP <?= h((string) $st) ?></span> could not load the project.
      <?php endif; ?>
    </p>
  </section>
</main>

<?php else: ?>
<main id="app">
  <div class="print-head">
    <p id="printMeta"></p>
    <p id="printFilters"></p>
    <p id="printDate"></p>
  </div>

  <section class="stats">
    <div class="tile gate-<?= $gateCls ?>">
      <span class="num"><?= h($gLabel) ?></span><span class="lbl">Quality gate</span>
    </div>
    <?php foreach (['BLOCKER' => ['Blocker', 'sev-error'], 'CRITICAL' => ['Critical', 'sev-error'], 'MAJOR' => ['Major', 'sev-warning'], 'MINOR' => ['Minor', 'sev-note'], 'INFO' => ['Info', '']] as $sv => [$lbl, $cls]): ?>
      <?php if (!empty($sevCounts[$sv])): ?>
        <div class="tile <?= $cls ?>"><span class="num"><?= h(number_format($sevCounts[$sv])) ?></span><span class="lbl"><?= h($lbl) ?></span></div>
      <?php endif; ?>
    <?php endforeach; ?>
    <div class="tile"><span class="num"><?= h(number_format($issueTotal ?? count($issuesAll))) ?></span><span class="lbl">Issues</span></div>
    <div class="tile"><span class="num"><?= h(number_format(count($ruleAgg))) ?></span><span class="lbl">Rules hit</span></div>
    <div class="tile"><span class="num"><?= h(number_format(count($fileAgg))) ?></span><span class="lbl">Files affected</span></div>
    <?php if (isset($vals['coverage'])): ?>
      <div class="tile"><span class="num"><?= measure_display('PERCENT', $vals['coverage']) ?></span><span class="lbl">Coverage</span></div>
    <?php endif; ?>
    <?php if (isset($vals['duplicated_lines_density'])): ?>
      <div class="tile"><span class="num"><?= measure_display('PERCENT', $vals['duplicated_lines_density']) ?></span><span class="lbl">Duplicated lines</span></div>
    <?php endif; ?>
  </section>

  <div class="panels">
    <section class="panel">
      <h2>Quality gate <span class="hint"><?= h($gLabel) ?><?= $caycStatus !== null ? ' · Clean as You Code: ' . h(humanize($caycStatus)) : '' ?></span></h2>
      <?php if ($gateConds): ?>
        <div class="scroll">
          <table class="mini">
            <thead><tr><th>Condition</th><th class="n">Threshold</th><th class="n">Actual</th><th>Status</th></tr></thead>
            <tbody>
            <?php foreach ($gateConds as $c): ?>
              <?php
                $cst   = (string) ($c['status'] ?? 'OK');
                $cmk   = (string) ($c['metricKey'] ?? '');
                $ctype = $metricDefs[$cmk]['type'] ?? 'STRING';
              ?>
              <tr>
                <td>
                  <?= h(metric_name($cmk, $metricDefs)) ?>
                  <div class="sub"><?= ($c['comparator'] ?? '') === 'GT' ? 'greater than' : 'less than' ?> · <code><?= h($cmk) ?></code></div>
                </td>
                <td class="n"><?= measure_display($ctype, (string) ($c['errorThreshold'] ?? '')) ?></td>
                <td class="n"><?= isset($c['actualValue']) ? measure_display($ctype, (string) $c['actualValue']) : '—' ?></td>
                <td><span class="badge <?= $cst === 'ERROR' ? 'failed' : ($cst === 'WARN' ? 'warn' : 'passed') ?>"><?= h($cst) ?></span></td>
              </tr>
            <?php endforeach; ?>
            </tbody>
          </table>
        </div>
        <?php if (!empty($gate['data']['projectStatus']['ignoredConditions'])): ?>
          <p class="section-note">Some conditions are ignored for this project.</p>
        <?php endif; ?>
      <?php else: ?>
        <p class="no-rows">No conditions evaluated for this analysis.</p>
      <?php endif; ?>
    </section>

    <section class="panel">
      <h2>Ratings <span class="hint">A best → E worst</span></h2>
      <div class="rating-row">
        <?php foreach (RATING_METRICS as $mk): ?>
          <?php if (!isset($vals[$mk])) continue; ?>
          <div class="rating">
            <?= measure_display('RATING', $vals[$mk]) ?>
            <span class="rl"><?= h(metric_name($mk, $metricDefs)) ?></span>
          </div>
        <?php endforeach; ?>
        <?php if (isset($vals['security_review_rating'])): ?>
          <div class="rating">
            <?= measure_display('RATING', $vals['security_review_rating']) ?>
            <span class="rl">Security review</span>
          </div>
        <?php endif; ?>
      </div>
      <?php if (!empty($comp['tags'])): ?>
        <div class="chips" style="padding:0 16px 14px">
          <?php foreach ($comp['tags'] as $tg): ?><span class="chip"><?= h((string) $tg) ?></span><?php endforeach; ?>
        </div>
      <?php endif; ?>
    </section>
  </div>

  <div class="panels even">
    <section class="panel">
      <h2>Issues by rule <span class="hint">click a row to filter</span></h2>
      <div class="scroll">
        <table class="mini" id="ruleTbl">
          <thead><tr><th>Rule</th><th>Severity</th><th class="n">Issues</th><th class="n">Files</th></tr></thead>
          <tbody>
          <?php if (!$ruleAgg): ?>
            <tr><td colspan="4" class="no-rows">No issues.</td></tr>
          <?php endif; ?>
          <?php foreach (array_slice($ruleAgg, 0, 12, true) as $rk => $ra): ?>
            <?php $rn = $ruleInfo[$rk]['name'] ?? ''; ?>
            <tr data-rule="<?= h((string) $rk) ?>" tabindex="0">
              <td><code><?= h((string) $rk) ?></code><?php if ($rn !== ''): ?><div class="sub"><?= h($rn) ?></div><?php endif; ?></td>
              <td><?php if ($ra['sev'] !== ''): ?><span class="badge <?= sev_class($ra['sev']) ?>"><?= h(humanize($ra['sev'])) ?></span><?php endif; ?></td>
              <td class="n"><?= h(number_format($ra['count'])) ?></td>
              <td class="n"><?= h(number_format(count($ra['files']))) ?></td>
            </tr>
          <?php endforeach; ?>
          </tbody>
        </table>
      </div>
      <?php if (count($ruleAgg) > 12): ?>
        <p class="section-note">Top 12 of <?= h(number_format(count($ruleAgg))) ?> rules — pick any rule from the issues toolbar.</p>
      <?php endif; ?>
    </section>

    <section class="panel">
      <h2>Issues by file <span class="hint">click a row to filter</span></h2>
      <div class="scroll">
        <table class="mini" id="fileTbl">
          <thead><tr><th>File</th><th class="n">Bugs</th><th class="n">Vulns</th><th class="n">Smells</th><th class="n">Total</th></tr></thead>
          <tbody>
          <?php if (!$fileAgg): ?>
            <tr><td colspan="5" class="no-rows">No issues.</td></tr>
          <?php endif; ?>
          <?php foreach (array_slice($fileAgg, 0, 12, true) as $fp => $fa): ?>
            <tr data-file="<?= h((string) $fp) ?>" tabindex="0">
              <td class="path"><code><?= h((string) $fp) ?></code></td>
              <td class="n err"><?= !empty($fa['BUG']) ? h(number_format($fa['BUG'])) : '' ?></td>
              <td class="n err"><?= !empty($fa['VULNERABILITY']) ? h(number_format($fa['VULNERABILITY'])) : '' ?></td>
              <td class="n warn"><?= !empty($fa['CODE_SMELL']) ? h(number_format($fa['CODE_SMELL'])) : '' ?></td>
              <td class="n"><?= h(number_format($fa['total'] ?? 0)) ?></td>
            </tr>
          <?php endforeach; ?>
          </tbody>
        </table>
      </div>
      <?php if (count($fileAgg) > 12): ?>
        <p class="section-note">Top 12 of <?= h(number_format(count($fileAgg))) ?> files — the full list is in the files panel below.</p>
      <?php endif; ?>
    </section>
  </div>

  <section class="panel">
    <h2>Categories <span class="hint">click a tag or rule to filter</span></h2>
    <div id="tags" class="tags">
    <?php if ($facets): ?>
      <?php foreach ($facets as $f): ?>
        <?php
          $prop   = (string) ($f['property'] ?? '');
          $values = array_values(array_filter($f['values'] ?? [], fn($fv) => (int) ($fv['count'] ?? 0) > 0));
          if (!$values) continue;
          usort($values, fn($a, $b) => (int) ($b['count'] ?? 0) <=> (int) ($a['count'] ?? 0));
          $shownVals = array_slice($values, 0, 14);
          $moreVals  = count($values) - count($shownVals);
        ?>
        <div class="tag-group">
          <h3>By <?= h(FACET_LABELS[$prop] ?? humanize($prop)) ?></h3>
          <?php foreach ($shownVals as $fv): ?>
            <?php
              $val = (string) ($fv['val'] ?? '');
              $cnt = (int) ($fv['count'] ?? 0);
              if ($prop === 'types') $disp = TYPE_LABELS[$val] ?? humanize($val);
              elseif ($prop === 'rules') $disp = $ruleInfo[$val]['name'] ?? $val;
              elseif ($prop === 'languages') $disp = LANGUAGE_LABELS[$val] ?? $val;
              else $disp = humanize($val);
            ?>
            <?php if ($prop === 'tags'): ?>
              <button type="button" class="tag" data-tag="<?= h($val) ?>" title="Filter by tag: <?= h($val) ?>"><?= h($disp) ?> <span class="n"><?= h(number_format($cnt)) ?></span></button>
            <?php elseif ($prop === 'rules'): ?>
              <button type="button" class="tag" data-rule-filter="<?= h($val) ?>" title="Filter by rule: <?= h($val) ?>"><?= h($disp) ?> <span class="n"><?= h(number_format($cnt)) ?></span></button>
            <?php else: ?>
              <span class="chip" title="<?= h($val) ?>"><?= h($disp) ?> <b><?= h(number_format($cnt)) ?></b></span>
            <?php endif; ?>
          <?php endforeach; ?>
          <?php if ($moreVals > 0): ?><span class="chip">+<?= h(number_format($moreVals)) ?> more</span><?php endif; ?>
        </div>
      <?php endforeach; ?>
    <?php else: ?>
      <p class="no-rows">No issue facets returned.</p>
    <?php endif; ?>
    </div>
  </section>

  <section class="panel">
    <h2>Issues <span class="hint">click a row for the why + how to fix · <span id="shown"></span></span></h2>
    <div class="toolbar">
      <div id="sevFilters" class="sev-filters"></div>
      <select id="ruleSel" aria-label="Filter by rule">
        <option value="">All rules</option>
        <?php foreach ($ruleAgg as $rk => $ra): ?>
          <option value="<?= h((string) $rk) ?>"><?= h((string) $rk) ?> (<?= h(number_format($ra['count'])) ?>)</option>
        <?php endforeach; ?>
      </select>
      <select id="typeSel" aria-label="Filter by type">
        <option value="">All types</option>
        <?php foreach (['BUG', 'VULNERABILITY', 'CODE_SMELL'] as $ty): ?>
          <?php if (empty($typeCounts[$ty])) continue; ?>
          <option value="<?= h($ty) ?>"><?= h(TYPE_LABELS[$ty] ?? humanize($ty)) ?> (<?= h(number_format($typeCounts[$ty])) ?>)</option>
        <?php endforeach; ?>
      </select>
      <select id="sortSel" aria-label="Sort issues">
        <option value="severity">Sort: severity</option>
        <option value="file">Sort: file</option>
        <option value="rule">Sort: rule</option>
      </select>
      <input id="q" type="search" placeholder="Search rule, file, message, tag… (press /)" aria-label="Search issues">
      <button id="reset" type="button">Clear filters</button>
    </div>
    <div id="filterNote" class="filter-note" hidden></div>
    <div class="scroll" style="max-height:none">
      <table id="tbl">
        <thead><tr><th class="caret-col"></th><th>Severity</th><th>Rule</th><th>Location</th><th>Message</th></tr></thead>
        <tbody></tbody>
      </table>
    </div>
    <div id="pager" class="pager"></div>
  </section>

  <section class="panel">
    <h2>Security hotspots <span class="hint"><?= h(number_format(count($hotspots))) ?> total · <?= h(number_format($hotspotReview)) ?> to review</span></h2>
    <?php if ($hotspots): ?>
      <div class="scroll">
        <table class="mini">
          <thead><tr><th>Probability</th><th>Status</th><th>Category</th><th>Rule</th><th>Message</th><th>Location</th><th class="n">Comments</th><th>Created</th></tr></thead>
          <tbody>
          <?php foreach ($hotspots as $hs): ?>
            <?php
              $rk   = (string) ($hs['ruleKey'] ?? $hs['rule'] ?? '');
              $rn   = $ruleInfo[$rk]['name'] ?? '';
              $line = $hs['line'] ?? ($hs['textRange']['startLine'] ?? null);
              $path = comp_path($key, (string) ($hs['component'] ?? ''));
              $prob = strtoupper((string) ($hs['vulnerabilityProbability'] ?? ''));
              $pcls = $prob === 'HIGH' ? 'error' : ($prob === 'MEDIUM' ? 'warning' : ($prob === 'LOW' ? 'note' : 'none'));
            ?>
            <tr>
              <td><span class="badge <?= $pcls ?>"><?= h(humanize($prob)) ?></span></td>
              <td class="small"><?= h(humanize($hs['status'] ?? '')) ?></td>
              <td class="small"><?= h(humanize($hs['securityCategory'] ?? '')) ?></td>
              <td><?= $rn !== '' ? h($rn) : h($rk) ?><div class="sub"><code><?= h($rk) ?></code></div></td>
              <td class="msg"><?= h((string) ($hs['message'] ?? '')) ?></td>
              <td class="path"><code><?= h($path ?: '—') ?></code><?php if ($line): ?><div class="sub">line <?= h((string) $line) ?></div><?php endif; ?></td>
              <td class="n"><?= h((string) count($hs['comments'] ?? [])) ?></td>
              <td class="small muted"><?= h(fmt_date($hs['creationDate'] ?? null)) ?></td>
            </tr>
          <?php endforeach; ?>
          </tbody>
        </table>
      </div>
    <?php else: ?>
      <p class="no-rows">No security hotspots in this project.</p>
    <?php endif; ?>
  </section>

  <section class="panel">
    <h2>Files <span class="hint"><?= h(number_format(count($files))) ?> indexed · click a row to filter the issues</span></h2>
    <?php if ($langs): ?>
      <div class="chips" style="padding:12px 16px 0">
        <?php foreach ($langs as $l => $count): ?>
          <span class="chip"><?= h(LANGUAGE_LABELS[$l] ?? ucfirst((string) $l)) ?> <b><?= h(number_format($count)) ?></b></span>
        <?php endforeach; ?>
      </div>
    <?php endif; ?>
    <?php if ($files): ?>
      <?php $sum = ['ncloc' => 0, 'complexity' => 0, 'cognitive_complexity' => 0, 'bugs' => 0, 'vulnerabilities' => 0, 'code_smells' => 0, 'issues' => 0, 'debt' => 0]; ?>
      <div class="scroll" style="max-height:520px">
        <table id="filesTbl">
          <thead><tr>
            <th>File</th><th>Lang</th><th class="n">NCLOC</th><th class="n">Complexity</th><th class="n">Cognitive</th>
            <th class="n">Bugs</th><th class="n">Vulns</th><th class="n">Smells</th><th class="n">Issues</th><th class="n">Debt</th>
            <th class="n">Coverage</th><th class="n">Dup</th>
          </tr></thead>
          <tbody>
          <?php foreach ($files as $f): ?>
            <?php
              $mm  = $fileMeasures[$f['key']] ?? [];
              $cnt = $issueComponents[$f['key']] ?? 0;
              $dbt = $fileDebt[$f['key']] ?? 0;
              $sum['ncloc']                += (int) ($mm['ncloc'] ?? 0);
              $sum['complexity']           += (int) ($mm['complexity'] ?? 0);
              $sum['cognitive_complexity'] += (int) ($mm['cognitive_complexity'] ?? 0);
              $sum['bugs']                 += (int) ($mm['bugs'] ?? 0);
              $sum['vulnerabilities']      += (int) ($mm['vulnerabilities'] ?? 0);
              $sum['code_smells']          += (int) ($mm['code_smells'] ?? 0);
              $sum['issues']               += $cnt;
              $sum['debt']                 += $dbt;
            ?>
            <tr class="file-row" data-file="<?= h((string) $f['path']) ?>" tabindex="0">
              <td class="path"><code><?= h($f['path']) ?></code></td>
              <td class="small"><?= h($f['language'] !== '' ? (LANGUAGE_LABELS[$f['language']] ?? $f['language']) : '—') ?></td>
              <td class="n"><?= isset($mm['ncloc']) ? h(fmt_int($mm['ncloc'])) : '—' ?></td>
              <td class="n"><?= isset($mm['complexity']) ? h(fmt_int($mm['complexity'])) : '—' ?></td>
              <td class="n"><?= isset($mm['cognitive_complexity']) ? h(fmt_int($mm['cognitive_complexity'])) : '—' ?></td>
              <td class="n err"><?= isset($mm['bugs']) ? h(fmt_int($mm['bugs'])) : '—' ?></td>
              <td class="n err"><?= isset($mm['vulnerabilities']) ? h(fmt_int($mm['vulnerabilities'])) : '—' ?></td>
              <td class="n warn"><?= isset($mm['code_smells']) ? h(fmt_int($mm['code_smells'])) : '—' ?></td>
              <td class="n"><?= $cnt ? h(fmt_int((string) $cnt)) : '—' ?></td>
              <td class="n"><?= $dbt ? h(fmt_min((string) $dbt)) : '—' ?></td>
              <td class="n"><?= isset($mm['coverage']) ? h(fmt_pct($mm['coverage'])) : '—' ?></td>
              <td class="n"><?= isset($mm['duplicated_lines_density']) ? h(fmt_pct($mm['duplicated_lines_density'])) : '—' ?></td>
            </tr>
          <?php endforeach; ?>
          </tbody>
          <tfoot>
            <tr>
              <th>Total (<?= h(number_format(count($files))) ?> files)</th>
              <th></th>
              <th class="n"><?= h(fmt_int((string) $sum['ncloc'])) ?></th>
              <th class="n"><?= h(fmt_int((string) $sum['complexity'])) ?></th>
              <th class="n"><?= h(fmt_int((string) $sum['cognitive_complexity'])) ?></th>
              <th class="n"><?= h(fmt_int((string) $sum['bugs'])) ?></th>
              <th class="n"><?= h(fmt_int((string) $sum['vulnerabilities'])) ?></th>
              <th class="n"><?= h(fmt_int((string) $sum['code_smells'])) ?></th>
              <th class="n"><?= h(fmt_int((string) $sum['issues'])) ?></th>
              <th class="n"><?= h(fmt_min((string) $sum['debt'])) ?></th>
              <th class="n"></th><th class="n"></th>
            </tr>
          </tfoot>
        </table>
      </div>
    <?php else: ?>
      <p class="no-rows">No files indexed.</p>
    <?php endif; ?>
  </section>

  <section class="panel">
    <h2>Duplications <span class="hint"><?= h(number_format(count($dupGroups))) ?> groups</span></h2>
    <?php if ($dupGroups): ?>
      <div class="scroll">
        <table class="mini">
          <thead><tr><th>#</th><th class="n">Lines</th><th>Duplicated blocks</th></tr></thead>
          <tbody>
          <?php $dn = 0; foreach ($dupGroups as $blocks): $dn++; ?>
            <tr>
              <td class="muted"><?= $dn ?></td>
              <td class="n"><?= h(fmt_int((string) ($blocks[0]['size'] ?? 0))) ?></td>
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
      </div>
    <?php else: ?>
      <p class="no-rows">No duplicated blocks in this project.</p>
    <?php endif; ?>
  </section>

  <section class="panel">
    <h2>All measures <span class="hint"><?= h(number_format(count($vals))) ?> metrics · grouped by domain</span></h2>
    <?php if ($byDomain): ?>
      <div class="grid">
        <?php foreach ($byDomain as $domain => $items): ?>
          <div class="mini-panel">
            <h3><?= h($domain !== '' ? $domain : 'Other') ?></h3>
            <table class="mini">
              <thead><tr><th>Metric</th><th class="n">Value</th></tr></thead>
              <tbody>
              <?php foreach ($items as $mk => $mv): ?>
                <?php $mtype = $metricDefs[$mk]['type'] ?? 'STRING'; ?>
                <tr>
                  <td><?= h(metric_name($mk, $metricDefs)) ?><div class="sub"><code><?= h($mk) ?></code></div></td>
                  <td class="n"><?= measure_display($mtype, $mv) ?></td>
                </tr>
              <?php endforeach; ?>
              </tbody>
            </table>
          </div>
        <?php endforeach; ?>
      </div>
    <?php else: ?>
      <p class="no-rows">No measures returned.</p>
    <?php endif; ?>
  </section>

  <section class="panel">
    <h2>Analysis history <span class="hint"><?= h(number_format(count($analyses))) ?> analyses</span></h2>
    <?php if ($analyses): ?>
      <div class="scroll">
        <table class="mini">
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
      </div>
    <?php else: ?>
      <p class="no-rows">No analysis history available.</p>
    <?php endif; ?>
  </section>
</main>

<script id="issueData" type="application/json"><?= json_encode($issueRows, $jsonFlags) ?></script>
<script id="ruleData" type="application/json"><?= json_encode((object) $ruleMeta, $jsonFlags) ?></script>
<script>
(function () {
  'use strict';
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
  const DATA = JSON.parse($('#issueData').textContent || '[]');
  const RULES = JSON.parse($('#ruleData').textContent || '{}');
  const LEVELS = ['BLOCKER', 'CRITICAL', 'MAJOR', 'MINOR', 'INFO'];
  const LEVEL_LABEL = { BLOCKER: 'Blocker', CRITICAL: 'Critical', MAJOR: 'Major', MINOR: 'Minor', INFO: 'Info' };
  const LEVEL_ORDER = { BLOCKER: 0, CRITICAL: 1, MAJOR: 2, MINOR: 3, INFO: 4 };
  const TYPE_LABEL = { BUG: 'Bug', VULNERABILITY: 'Vulnerability', CODE_SMELL: 'Code smell' };
  const PAGE_SIZE = 200;

  const state = {
    levelsOff: new Set(),
    rule: '', file: '', tag: '', type: '', q: '',
    sort: 'severity', page: 1, printMode: false,
    expanded: new Set(),
  };

  const counts = { BLOCKER: 0, CRITICAL: 0, MAJOR: 0, MINOR: 0, INFO: 0 };
  for (const f of DATA) counts[f.sev] = (counts[f.sev] || 0) + 1;

  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const num = (n) => Number(n || 0).toLocaleString('en-US');
  const sevClass = (l) => ['BLOCKER', 'CRITICAL'].includes(l) ? 'error' : (l === 'MAJOR' ? 'warning' : (l === 'MINOR' ? 'note' : 'none'));
  const badge = (lvl) => `<span class="badge ${sevClass(lvl)}">${esc(LEVEL_LABEL[lvl] || lvl)}</span>`;

  function filtered() {
    const q = state.q.trim().toLowerCase();
    const list = DATA.filter((f) => {
      if (state.levelsOff.has(f.sev)) return false;
      if (state.rule && f.rule !== state.rule) return false;
      if (state.type && f.type !== state.type) return false;
      if (state.file && f.file !== state.file) return false;
      if (state.tag && !(f.tags || []).includes(state.tag)) return false;
      if (q) {
        const hay = (f.rule + ' ' + ((RULES[f.rule] || {}).n || '') + ' ' + f.file + ' ' + f.msg + ' ' + (f.tags || []).join(' ')).toLowerCase();
        if (!hay.includes(q)) return false;
      }
      return true;
    });
    const cmp = (a, b) => String(a).localeCompare(String(b));
    list.sort((a, b) => {
      if (state.sort === 'file') return cmp(a.file, b.file) || a.line - b.line || LEVEL_ORDER[a.sev] - LEVEL_ORDER[b.sev];
      if (state.sort === 'rule') return cmp(a.rule, b.rule) || cmp(a.file, b.file) || a.line - b.line;
      return (LEVEL_ORDER[a.sev] - LEVEL_ORDER[b.sev]) || cmp(a.file, b.file) || a.line - b.line;
    });
    return list;
  }

  function renderSevFilters() {
    const noneOff = state.levelsOff.size === 0;
    $('#sevFilters').innerHTML =
      `<button type="button" class="pill all${noneOff ? ' active' : ''}" data-level="" title="Show all severities">All <span class="n">${num(DATA.length)}</span></button>` +
      LEVELS.filter((l) => counts[l]).map((l) =>
        `<button type="button" class="pill ${sevClass(l)}${state.levelsOff.has(l) ? ' off' : ''}" data-level="${l}" title="Toggle ${LEVEL_LABEL[l]}">${LEVEL_LABEL[l]} <span class="n">${num(counts[l])}</span></button>`
      ).join('');
  }

  function detailRow(f) {
    const info = RULES[f.rule] || {};
    const loc = f.file + (f.line ? ':' + f.line : '');
    // Rule description sections (authenticated Web API only): the "why" is
    // introduction + root_cause, the "how to fix" is its own section and
    // carries SonarQube's noncompliant/compliant code examples as HTML.
    const secs = info.s || {};
    const why = [secs.introduction, secs.root_cause].filter(Boolean).join('\n');
    const fix = secs.how_to_fix || '';
    const res = secs.resources || '';
    const noDocs = `Rule descriptions come back only for authenticated callers — set <code>SONAR_TOKEN</code> in <code>.env</code>, recreate the <code>php</code> container, and the "why" + "how to fix" (with code examples) will show here.`;
    const whyHtml = why ? why
      : (info.d ? `<p class="desc">${esc(info.d)}</p>` : `<p class="desc">${noDocs}</p>`);
    const fixHtml = fix ? fix
      : (info.s ? `<p class="desc">SonarQube publishes no step-by-step fix for this rule — apply the description above.</p>` : `<p class="desc">${noDocs}</p>`);
    const resHtml = res ? `<h3>Resources</h3>${res}` : '';
    const tags = (f.tags || []).length
      ? `<div class="chips">${f.tags.map((t) => `<span class="chip">${esc(t)}</span>`).join('')}</div>` : '';
    const impacts = (f.impacts || []).length
      ? `<p class="desc">Impacts: ${esc(f.impacts.join(' · '))}</p>` : '';
    const flows = (f.flows || []).length
      ? `<h3>Flows</h3>${f.flows.map((x) => `<p class="desc"><code>${esc(x)}</code></p>`).join('')}` : '';
    const meta = [`<dt>Type</dt><dd>${esc(f.typeLabel || f.type || '—')}</dd>`];
    if (f.status) meta.push(`<dt>Status</dt><dd>${esc(f.status)}${f.resolution ? ' · ' + esc(f.resolution) : ''}</dd>`);
    if (f.effort) meta.push(`<dt>Effort</dt><dd>${esc(f.effort)}</dd>`);
    if (f.created) meta.push(`<dt>Created</dt><dd>${esc(f.created)}</dd>`);
    const docs = f.rule
      ? `<p><a href="//sonarqube.test/coding_rules?open=${encodeURIComponent(f.rule)}&rule_key=${encodeURIComponent(f.rule)}" target="_blank" rel="noopener">Rule documentation ↗</a></p>` : '';
    return `<tr class="detail"><td colspan="5"><div class="detail-grid">
      <div>
        <h3>Issue</h3>
        <p class="message">${esc(f.msg || '(no message)')}</p>
        ${impacts}
        <h3>Why this is an issue</h3>
        <div class="doc">${whyHtml}</div>
        <h3>How to fix</h3>
        <div class="doc">${fixHtml}</div>
        <div class="doc">${resHtml}</div>
        <h3>Rule</h3>
        <p><code>${esc(f.rule)}</code></p>
        ${info.n ? `<p class="desc">${esc(info.n)}</p>` : ''}
        ${docs}
        ${flows}
        ${tags}
      </div>
      <div>
        <h3>Location</h3>
        <p><code>${esc(loc)}</code></p>
        ${f.url ? `<p><a href="${esc(f.url)}" target="_blank" rel="noopener">Open issue in SonarQube ↗</a></p>` : ''}
        <h3>Metadata</h3>
        <dl class="meta-list">${meta.join('')}</dl>
      </div>
    </div></td></tr>`;
  }

  function renderFindings() {
    const list = filtered();
    const total = DATA.length;
    const pages = state.printMode ? 1 : Math.max(1, Math.ceil(list.length / PAGE_SIZE));
    if (state.page > pages) state.page = pages;
    const start = state.printMode ? 0 : (state.page - 1) * PAGE_SIZE;
    const end = state.printMode ? list.length : Math.min(list.length, start + PAGE_SIZE);
    const slice = list.slice(start, end);
    const tb = $('#tbl tbody');

    if (!total) {
      tb.innerHTML = '<tr><td colspan="5" class="no-rows">No issues — clean project.</td></tr>';
    } else if (!slice.length) {
      tb.innerHTML = '<tr><td colspan="5" class="no-rows">No issues match the current filters.</td></tr>';
    } else {
      tb.innerHTML = slice.map((f) => {
        const open = state.expanded.has(f.k);
        const locText = f.file + (f.line ? ':' + f.line : '');
        return `<tr class="finding${open ? ' open' : ''}" data-key="${esc(f.k)}" tabindex="0" aria-expanded="${open ? 'true' : 'false'}">
          <td class="caret">${open ? '▾' : '▸'}</td>
          <td class="sev">${badge(f.sev)}</td>
          <td class="rule"><code>${esc(f.rule)}</code>${(RULES[f.rule] || {}).n ? `<div class="sub">${esc(RULES[f.rule].n)}</div>` : ''}</td>
          <td class="loc" title="${esc(locText)}"><code>${esc(f.file)}</code>${f.line ? ':' + f.line : ''}</td>
          <td class="msg">${esc(f.msg)}</td>
        </tr>` + (open ? detailRow(f) : '');
      }).join('');
    }

    const shown = $('#shown');
    if (!list.length) shown.textContent = total ? 'no matches' : 'none';
    else if (state.printMode) shown.textContent = num(list.length) + ' issues';
    else shown.textContent = `${num(start + 1)}–${num(end)} of ${num(list.length)}` + (list.length !== total ? ' (filtered from ' + num(total) + ')' : '');

    renderPager(list.length, pages);
  }

  function renderPager(total, pages) {
    const p = $('#pager');
    if (state.printMode || pages <= 1) {
      p.innerHTML = total ? `<span>${num(total)} issue${total === 1 ? '' : 's'}</span>` : '';
      return;
    }
    p.innerHTML = `<button type="button" data-page="${state.page - 1}"${state.page <= 1 ? ' disabled' : ''}>← Prev</button>
      <span>Page ${num(state.page)} of ${num(pages)}</span>
      <button type="button" data-page="${state.page + 1}"${state.page >= pages ? ' disabled' : ''}>Next →</button>`;
  }

  function chip(kind, label, value) {
    return `<button type="button" class="fchip" data-clear="${kind}">${esc(label)}: <code>${esc(value)}</code> ×</button>`;
  }

  function renderFilterNote() {
    const chips = [];
    if (state.rule) chips.push(chip('rule', 'rule', state.rule));
    if (state.file) chips.push(chip('file', 'file', state.file));
    if (state.tag) chips.push(chip('tag', 'tag', state.tag));
    if (state.type) chips.push(chip('type', 'type', TYPE_LABEL[state.type] || state.type));
    if (state.q.trim()) chips.push(chip('q', 'search', '"' + state.q.trim() + '"'));
    const hidden = LEVELS.filter((l) => state.levelsOff.has(l));
    if (hidden.length) chips.push(chip('levels', 'hidden', hidden.map((l) => LEVEL_LABEL[l] || l).join(', ')));
    const el = $('#filterNote');
    el.innerHTML = chips.join('');
    el.hidden = chips.length === 0;
  }

  function applyFilters() {
    renderSevFilters();
    renderFilterNote();
    renderFindings();

    const ruleSel = $('#ruleSel');
    if (ruleSel && ruleSel.value !== state.rule) ruleSel.value = state.rule;
    const typeSel = $('#typeSel');
    if (typeSel && typeSel.value !== state.type) typeSel.value = state.type;

    $$('#ruleTbl tr[data-rule]').forEach((tr) => tr.classList.toggle('active', tr.getAttribute('data-rule') === state.rule));
    $$('#fileTbl tr[data-file], #filesTbl tr[data-file]').forEach((tr) => tr.classList.toggle('active', tr.getAttribute('data-file') === state.file));
    $$('#tags [data-tag]').forEach((b) => b.classList.toggle('active', b.getAttribute('data-tag') === state.tag));
    $$('#tags [data-rule-filter]').forEach((b) => b.classList.toggle('active', b.getAttribute('data-rule-filter') === state.rule));

    const pf = $('#printFilters');
    if (pf) {
      const desc = [];
      if (state.rule) desc.push('rule ' + state.rule);
      if (state.file) desc.push('file ' + state.file);
      if (state.tag) desc.push('tag ' + state.tag);
      if (state.type) desc.push('type ' + (TYPE_LABEL[state.type] || state.type));
      if (state.q.trim()) desc.push('search "' + state.q.trim() + '"');
      if (state.levelsOff.size) desc.push('hidden severities: ' + Array.from(state.levelsOff).map((l) => LEVEL_LABEL[l] || l).join(', '));
      pf.textContent = 'Filters: ' + (desc.length ? desc.join(' · ') : 'none (full report)');
    }
  }

  function toggleKey(key) {
    if (state.expanded.has(key)) state.expanded.delete(key);
    else state.expanded.add(key);
    renderFindings();
  }

  function bindTable(sel, attr, apply) {
    const table = $(sel);
    if (!table) return;
    const pick = (e) => e.target.closest('tr[' + attr + ']');
    table.addEventListener('click', (e) => { const tr = pick(e); if (tr) apply(tr.getAttribute(attr)); });
    table.addEventListener('keydown', (e) => {
      if (e.key !== 'Enter' && e.key !== ' ') return;
      const tr = pick(e);
      if (!tr) return;
      e.preventDefault();
      apply(tr.getAttribute(attr));
    });
  }

  bindTable('#ruleTbl', 'data-rule', (id) => { state.rule = state.rule === id ? '' : id; state.page = 1; applyFilters(); });
  bindTable('#fileTbl', 'data-file', (file) => { state.file = state.file === file ? '' : file; state.page = 1; applyFilters(); });
  bindTable('#filesTbl', 'data-file', (file) => { state.file = state.file === file ? '' : file; state.page = 1; applyFilters(); });

  $('#tags').addEventListener('click', (e) => {
    const tag = e.target.closest('[data-tag]');
    if (tag) { const v = tag.getAttribute('data-tag'); state.tag = state.tag === v ? '' : v; state.page = 1; applyFilters(); return; }
    const rule = e.target.closest('[data-rule-filter]');
    if (rule) { const v = rule.getAttribute('data-rule-filter'); state.rule = state.rule === v ? '' : v; state.page = 1; applyFilters(); }
  });

  $('#sevFilters').addEventListener('click', (e) => {
    const b = e.target.closest('[data-level]');
    if (!b) return;
    const lvl = b.getAttribute('data-level');
    if (!lvl) state.levelsOff.clear();
    else if (state.levelsOff.has(lvl)) state.levelsOff.delete(lvl);
    else state.levelsOff.add(lvl);
    state.page = 1;
    applyFilters();
  });

  $('#filterNote').addEventListener('click', (e) => {
    const b = e.target.closest('[data-clear]');
    if (!b) return;
    const k = b.getAttribute('data-clear');
    if (k === 'rule') state.rule = '';
    else if (k === 'file') state.file = '';
    else if (k === 'tag') state.tag = '';
    else if (k === 'type') state.type = '';
    else if (k === 'q') { state.q = ''; $('#q').value = ''; }
    else if (k === 'levels') state.levelsOff.clear();
    state.page = 1;
    applyFilters();
  });

  $('#tbl tbody').addEventListener('click', (e) => {
    if (e.target.closest('a')) return;
    const tr = e.target.closest('tr.finding');
    if (!tr) return;
    toggleKey(tr.getAttribute('data-key'));
  });

  $('#tbl tbody').addEventListener('keydown', (e) => {
    if (e.key !== 'Enter' && e.key !== ' ') return;
    const tr = e.target.closest('tr.finding');
    if (!tr) return;
    e.preventDefault();
    toggleKey(tr.getAttribute('data-key'));
  });

  $('#pager').addEventListener('click', (e) => {
    const b = e.target.closest('button[data-page]');
    if (!b || b.disabled) return;
    const p = Number(b.getAttribute('data-page'));
    if (!Number.isFinite(p)) return;
    state.page = Math.max(1, p);
    renderFindings();
  });

  $('#ruleSel').addEventListener('change', (e) => { state.rule = e.target.value; state.page = 1; applyFilters(); });
  $('#typeSel').addEventListener('change', (e) => { state.type = e.target.value; state.page = 1; applyFilters(); });
  $('#sortSel').addEventListener('change', (e) => { state.sort = e.target.value; state.page = 1; renderFindings(); });

  let qTimer;
  $('#q').addEventListener('input', (e) => {
    clearTimeout(qTimer);
    const v = e.target.value;
    qTimer = setTimeout(() => { state.q = v; state.page = 1; applyFilters(); }, 150);
  });

  $('#reset').addEventListener('click', () => {
    state.levelsOff.clear();
    state.rule = ''; state.file = ''; state.tag = ''; state.type = ''; state.q = '';
    state.page = 1;
    $('#ruleSel').value = ''; $('#typeSel').value = ''; $('#q').value = ''; $('#sortSel').value = 'severity';
    state.sort = 'severity';
    applyFilters();
  });

  document.addEventListener('keydown', (e) => {
    if (e.key !== '/' || e.ctrlKey || e.metaKey || e.altKey) return;
    const tag = document.activeElement && document.activeElement.tagName;
    if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA') return;
    e.preventDefault();
    $('#q').focus();
  });

  $('#printBtn').addEventListener('click', () => {
    $('#printMeta').textContent = document.querySelector('.meta').textContent.replace(/\s+/g, ' ').trim();
    $('#printDate').textContent = 'Printed: ' + new Date().toLocaleString();
    state.printMode = true;
    renderFindings();
    try { window.print(); } finally {
      state.printMode = false;
      renderFindings();
    }
  });

  applyFilters();
})();
</script>

<footer class="foot">
  generated <?= h(date('Y-m-d H:i')) ?> · data from the SonarQube Web API (anonymous read-only)
</footer>
<?php endif; ?>
</body>
</html>
