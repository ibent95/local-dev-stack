package com.localdevstack.lds;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

/**
 * Thin bridge to the {@code lds} CLI — the JavaFX mirror of the Tauri variant's
 * Rust backend. Everything goes through {@code lds.bat} (Windows) or
 * {@code lds.sh} (Unix) so the repo scripts stay the single source of truth.
 *
 * <p>Each method blocks; call them from a background thread (see
 * {@link LdsDesktopApp#runAsync}) so the JavaFX UI thread never freezes.
 */
public final class LdsCli {

    /** Repo root: the folder that contains lds.bat / lds.sh. */
    private final Path root;

    public LdsCli() {
        this.root = findRepoRoot();
    }

    /**
     * Walk up from the working directory until we find {@code lds.bat} or
     * {@code lds.sh}. Falls back to the working directory.
     */
    static Path findRepoRoot() {
        Path dir = Paths.get("").toAbsolutePath().normalize();
        while (dir != null) {
            if (Files.exists(dir.resolve("lds.bat")) || Files.exists(dir.resolve("lds.sh"))) {
                return dir;
            }
            dir = dir.getParent();
        }
        return Paths.get("").toAbsolutePath();
    }

    /** Run any {@code lds} command, capturing combined stdout+stderr. Throws on non-zero exit. */
    public String lds(String... args) throws IOException, InterruptedException {
        List<String> cmd = new ArrayList<>();
        boolean isWindows = System.getProperty("os.name", "").toLowerCase().contains("win");
        if (isWindows) {
            cmd.add("cmd");
            cmd.add("/C");
            cmd.add("lds.bat");
        } else {
            cmd.add("bash");
            cmd.add(root.resolve("lds.sh").toString());
        }
        cmd.addAll(List.of(args));
        return exec(cmd);
    }

    /** {@code docker compose --profile '*' ps --format json} — raw JSON for parsing. */
    public String stackStatusJson() throws IOException, InterruptedException {
        return exec(List.of("docker", "compose", "--profile", "*", "ps", "--format", "json"));
    }

    /** {@code docker compose logs --tail <lines> <service>}. */
    public String serviceLogs(String service, int lines) throws IOException, InterruptedException {
        return exec(List.of("docker", "compose", "logs", "--tail", String.valueOf(lines), service));
    }

    /**
     * Start a **live** log stream: {@code docker compose logs --tail <lines>
     * --follow <service>}. The returned process keeps running — read its input
     * stream line by line on a background thread (stderr is merged into
     * stdout). Stop it with {@code Process.destroy()}.
     */
    public Process streamLogs(String service, int lines) throws IOException {
        List<String> cmd = List.of("docker", "compose", "logs",
                "--tail", String.valueOf(lines), "--follow", service);
        ProcessBuilder pb = new ProcessBuilder(cmd);
        pb.directory(root.toFile());
        pb.redirectErrorStream(true); // merge stderr into stdout
        return pb.start();
    }

    /**
     * hosts-sync. On Windows it relaunches {@code lds.bat hosts-sync} through an
     * elevated cmd via PowerShell {@code Start-Process -Verb RunAs}, which shows
     * the native UAC prompt. On Unix it runs the CLI directly (needs a root
     * shell / passwordless sudo).
     */
    public String hostsSync() throws IOException, InterruptedException {
        boolean isWindows = System.getProperty("os.name", "").toLowerCase().contains("win");
        if (isWindows) {
            String script = "Start-Process -FilePath 'cmd.exe'"
                    + " -ArgumentList '/c','lds.bat hosts-sync'"
                    + " -WorkingDirectory '" + root + "'"
                    + " -Verb RunAs -Wait";
            return exec(List.of("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
                    "-Command", script));
        }
        return lds("hosts-sync");
    }

    /** Open a URL in the system browser. */
    public void openUrl(String url) throws IOException {
        boolean isWindows = System.getProperty("os.name", "").toLowerCase().contains("win");
        boolean isMac = System.getProperty("os.name", "").toLowerCase().contains("mac");
        if (isWindows) {
            new ProcessBuilder("cmd", "/C", "start", "", url).start();
        } else if (isMac) {
            new ProcessBuilder("open", url).start();
        } else {
            new ProcessBuilder("xdg-open", url).start();
        }
    }

    /** Run a process, wait, and return combined output; throw on non-zero exit. */
    private String exec(List<String> cmd) throws IOException, InterruptedException {
        ProcessBuilder pb = new ProcessBuilder(cmd);
        pb.directory(root.toFile());
        pb.redirectErrorStream(true); // merge stderr into stdout
        Process p = pb.start();
        String out = new String(p.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
        int code = p.waitFor();
        if (code != 0) {
            throw new IOException("command exited with " + code + ":\n" + out);
        }
        return out;
    }

    public Path root() {
        return root;
    }
}
