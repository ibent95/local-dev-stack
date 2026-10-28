<?php

use App\Services\LdsCli;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Native\Desktop\Facades\Window;

// The desktop panel — a single window rendering the 6-tab companion UI.
Route::get('/', fn () => view('panel'));

// Live container status (docker compose ps), polled by the panel.
Route::get('/api/status', function () {
    try {
        return response()->json([
            'ok' => true,
            'rows' => LdsCli::status(),
            'updated' => now()->format('H:i:s'),
        ]);
    } catch (\Throwable $e) {
        return response()->json([
            'ok' => false,
            'rows' => [],
            'error' => $e->getMessage(),
            'updated' => now()->format('H:i:s'),
        ]);
    }
});

// Any `lds …` command (lifecycle buttons, profile up/down, lds tools).
Route::post('/api/lds', function (Request $request) {
    $args = $request->input('args');
    if (!is_array($args) || $args === []) {
        return response()->json(['ok' => false, 'error' => 'no command given'], 422);
    }
    $args = array_values(array_map(static fn ($a) => (string) $a, $args));

    [$code, $output] = LdsCli::run($args);

    return response()->json([
        'ok' => $code === 0,
        'code' => $code,
        'command' => 'lds ' . implode(' ', $args),
        'output' => $output,
    ]);
});

// One-shot log tail.
Route::post('/api/logs/tail', function (Request $request) {
    $service = (string) $request->input('service', '');
    if (!preg_match('/^[a-z0-9][a-z0-9_-]*$/i', $service)) {
        return response()->json(['ok' => false, 'error' => 'invalid service name'], 422);
    }
    [, $output] = LdsCli::tailLogs($service, (int) $request->input('lines', 200));

    return response()->json(['ok' => true, 'output' => $output]);
});

// Live log streaming (detached `docker compose logs --follow` + file).
Route::post('/api/logs/stream/start', function (Request $request) {
    $service = (string) $request->input('service', '');
    if (!preg_match('/^[a-z0-9][a-z0-9_-]*$/i', $service)) {
        return response()->json(['ok' => false, 'error' => 'invalid service name'], 422);
    }
    LdsCli::startStream($service, (int) $request->input('lines', 200));

    return response()->json(['ok' => true, 'message' => "streaming docker compose logs --follow {$service}"]);
});

Route::post('/api/logs/stream/stop', function () {
    LdsCli::stopStream();

    return response()->json(['ok' => true]);
});

Route::get('/api/logs/stream/read', fn () => response()->json(['ok' => true, 'output' => LdsCli::readStream()]));

// Elevated hosts-sync (UAC prompt on Windows).
Route::post('/api/hosts-sync', function () {
    [$code, $output] = LdsCli::hostsSync();

    return response()->json(['ok' => $code === 0, 'output' => $output]);
});

// Open a tool UI in the system browser.
Route::post('/api/open', function (Request $request) {
    LdsCli::openUrl((string) $request->input('url', ''));

    return response()->json(['ok' => true]);
});

// Hide the panel to the tray (Close is disabled; the tray brings it back).
Route::post('/api/window/hide', function () {
    Window::hide('main');

    return response()->noContent();
});
