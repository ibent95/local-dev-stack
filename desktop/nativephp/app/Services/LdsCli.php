<?php

namespace App\Services;

use Symfony\Component\Process\Process;

/**
 * Thin PHP wrapper over the `lds` CLI — the desktop panel only invokes the
 * same CLI the terminal uses (the Tauri / JavaFX / Dioxus variants share
 * this design; the CLI stays the single source of truth).
 */
class LdsCli
{
    /** Repo root: walk up from the app until `lds.bat` / `lds.sh` is found. */
    public static function root(): string
    {
        $dir = base_path();
        for ($i = 0; $i < 8; $i++) {
            if (is_file($dir . '/lds.bat') || is_file($dir . '/lds.sh')) {
                return $dir;
            }
            $dir = dirname($dir);
        }
        return base_path();
    }

    /** @return string[] argv for the lds CLI. */
    protected static function ldsCommand(array $args): array
    {
        if (PHP_OS_FAMILY === 'Windows') {
            return array_merge(['cmd', '/C', 'lds.bat'], $args);
        }
        return array_merge(['bash', self::root() . '/lds.sh'], $args);
    }

    /**
     * Run `lds …` synchronously.
     *
     * @return array{0:int,1:string} exit code + combined output
     */
    public static function run(array $args): array
    {
        $process = new Process(self::ldsCommand($args), self::root());
        $process->setTimeout(null);
        $process->run();

        return [$process->getExitCode() ?? 1, $process->getOutput() . $process->getErrorOutput()];
    }

    /** Write a temporary .bat/.sh launcher and start it detached. */
    protected static function runDetached(string $content): void
    {
        if (PHP_OS_FAMILY === 'Windows') {
            $bat = storage_path('app/lds-detached.bat');
            file_put_contents($bat, "@echo off\r\n" . $content . "\r\n");
            @pclose(@popen('cmd /C start "" /B "' . $bat . '" > NUL 2>&1', 'r'));
        } else {
            $sh = storage_path('app/lds-detached.sh');
            file_put_contents($sh, "#!/usr/bin/env bash\n" . $content . "\n");
            @chmod($sh, 0755);
            @pclose(@popen('nohup bash "' . $sh . '" > /dev/null 2>&1 &', 'r'));
        }
    }

    /** Launch `lds …` detached — tray actions must not block the event request. */
    public static function detached(array $args): void
    {
        $root = self::root();
        if (PHP_OS_FAMILY === 'Windows') {
            $cmd = 'cd /d "' . $root . '"\r\ncall lds.bat ' . implode(' ', array_map('escapeshellarg', $args));
        } else {
            $cmd = 'cd "' . $root . '" && bash lds.sh ' . implode(' ', array_map('escapeshellarg', $args));
        }
        self::runDetached($cmd);
    }

    /**
     * `docker compose --profile '*' ps --format json` → parsed rows
     * (handles both NDJSON and single-array output shapes).
     *
     * @return array<int,array<string,mixed>>
     */
    public static function status(): array
    {
        $process = new Process(
            ['docker', 'compose', '--profile', '*', 'ps', '--format', 'json'],
            self::root()
        );
        $process->setTimeout(60);
        $process->run();
        if (!$process->isSuccessful()) {
            throw new \RuntimeException(trim($process->getErrorOutput()) ?: 'docker compose ps failed');
        }

        $text = trim($process->getOutput());
        $rows = [];
        foreach (preg_split('/\R/', $text) as $line) {
            $line = trim($line);
            if ($line === '') {
                continue;
            }
            $row = json_decode($line, true);
            if (is_array($row)) {
                $rows[] = $row;
            }
        }
        if ($rows === [] && str_starts_with($text, '[')) {
            $decoded = json_decode($text, true);
            if (is_array($decoded)) {
                $rows = $decoded;
            }
        }

        return $rows;
    }

    /** @return array{0:int,1:string} one-shot `docker compose logs --tail N <service>`. */
    public static function tailLogs(string $service, int $lines): array
    {
        $lines = max(10, min(5000, $lines));
        $process = new Process(
            ['docker', 'compose', 'logs', '--tail', (string) $lines, '--no-color', $service],
            self::root()
        );
        $process->setTimeout(120);
        $process->run();

        return [$process->getExitCode() ?? 1, $process->getOutput() . $process->getErrorOutput()];
    }

    protected static function streamFile(): string
    {
        return storage_path('app/lds-stream.log');
    }

    /** Start `docker compose logs --follow` detached, appending to the stream file. */
    public static function startStream(string $service, int $lines): void
    {
        self::stopStream();
        $lines = max(10, min(5000, $lines));
        $log = self::streamFile();
        @unlink($log);
        @touch($log);

        $cmd = sprintf(
            'docker compose logs --follow --no-color --tail %d %s',
            $lines,
            escapeshellarg($service)
        );
        if (PHP_OS_FAMILY === 'Windows') {
            self::runDetached('cd /d "' . self::root() . '"' . "\r\n" . $cmd . ' > "' . $log . '" 2>&1');
        } else {
            self::runDetached('cd "' . self::root() . '" && ' . $cmd . ' > "' . $log . '" 2>&1');
        }
    }

    /** Kill running `docker compose logs --follow` children (Stop / tray Quit). */
    public static function stopStream(): void
    {
        if (PHP_OS_FAMILY === 'Windows') {
            $ps = 'Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*compose logs --follow*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }';
            @pclose(@popen('powershell -NoProfile -Command ' . escapeshellarg($ps), 'r'));
        } else {
            @pclose(@popen('pkill -f "compose logs --follow" > /dev/null 2>&1', 'r'));
        }
    }

    /** Last N lines of the live stream file. */
    public static function readStream(int $maxLines = 500): string
    {
        $log = self::streamFile();
        if (!is_file($log)) {
            return '';
        }
        $content = (string) @file_get_contents($log);
        if ($content === '') {
            return '';
        }
        $lines = preg_split('/\R/', rtrim($content)) ?: [];
        if (count($lines) > $maxLines) {
            $lines = array_slice($lines, -$maxLines);
        }

        return implode("\n", $lines);
    }

    /** Elevated `lds hosts-sync` (UAC prompt on Windows). */
    public static function hostsSync(): array
    {
        if (PHP_OS_FAMILY !== 'Windows') {
            return self::run(['hosts-sync']);
        }
        $script = sprintf(
            "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c','lds.bat hosts-sync' -WorkingDirectory '%s' -Verb RunAs -Wait",
            str_replace("'", "''", self::root())
        );
        $process = new Process(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $script]);
        $process->setTimeout(null);
        $process->run();
        if ($process->isSuccessful()) {
            return [0, 'hosts-sync completed (elevated).'];
        }

        return [1, 'hosts-sync failed (was the UAC prompt declined?): ' . trim($process->getErrorOutput())];
    }

    /** Open a URL in the system browser (tool cards). */
    public static function openUrl(string $url): void
    {
        if (!preg_match('#^https?://#i', $url)) {
            return;
        }
        if (PHP_OS_FAMILY === 'Windows') {
            @pclose(@popen('start "" ' . escapeshellarg($url), 'r'));
        } elseif (PHP_OS_FAMILY === 'Darwin') {
            @pclose(@popen('open ' . escapeshellarg($url), 'r'));
        } else {
            @pclose(@popen('xdg-open ' . escapeshellarg($url) . ' > /dev/null 2>&1 &', 'r'));
        }
    }
}
