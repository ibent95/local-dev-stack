# LDS Desktop — JavaFX variant

The **Java 21 + JavaFX** implementation of the LDS desktop companion — the
learning sibling of the [Tauri variant](../tauri/README.md). Same features,
same "thin shell over the `lds` CLI" design — different toolkit
(see [`../README.md`](../README.md) for the shared feature list).

## Layout

```
javafx/
├── pom.xml                  # JavaFX 21 + Jackson (Maven Central)
└── src/main/
    ├── java/com/localdevstack/lds/
    │   ├── LdsCli.java      # ProcessBuilder bridge to lds.bat/lds.sh
    │   │                    #   + docker status/logs/stream + elevation
    │   └── LdsDesktopApp.java  # window, tabs, status table, tray,
    │                           #   auto-refresh timer, live log streaming
    └── resources/lds-tray.png  # tray icon
```

Architecture (mirror of the Tauri backend):

- `LdsCli.findRepoRoot()` walks up from the working directory until it finds
  `lds.bat` / `lds.sh`
- Blocking CLI calls run in `CompletableFuture.runAsync`; UI updates land back
  on the JavaFX thread via `Platform.runLater` (Tauri's `spawn_blocking` +
  async commands)
- `docker compose ps --format json` is parsed with Jackson (`JsonNode`),
  mirroring the Rust `serde` structs

## Build (containerized — recommended)

```bash
# one-time: build the base image
lds build-bases            # or: docker buildx bake javafx-dev

# then package — jar + a self-contained Linux app-image (target/dist/)
desktop/build.sh javafx
```

Verified: `mvn package` inside `lds/javafx-dev` produces a working jar, and
jpackage builds a runnable `target/dist/LdsDesktop/` app-image (bundled JRE,
~145 MB).

## Build (host) / per-OS installers

Prereqs: JDK 21+, Maven 3.9+. jpackage must run on each target OS — it cannot
cross-package.

```bash
cd desktop/javafx
mvn javafx:run                 # dev run
mvn package                    # jar (platform-portable)
bash package.sh                # jpackage app-image → target/dist/LdsDesktop/
JPACKAGE_TYPE=exe bash package.sh   # Windows .exe (no WiX needed)
JPACKAGE_TYPE=msi bash package.sh   # Windows .msi (needs WiX toolset)
JPACKAGE_TYPE=dmg bash package.sh   # macOS .dmg
JPACKAGE_TYPE=deb bash package.sh   # Linux .deb (needs dpkg-deb)
```

The same matrix runs automatically on all three OSes via
`.github/workflows/desktop-build.yml` (artifacts uploaded).

## Notes

- AWT tray on macOS requires the screen-enabled environment; on Linux it
  needs a desktop environment with a system tray (e.g. GNOME extension).
- The jar is platform-portable; native installers need jpackage on the target
  OS (Windows: WiX toolset).
- Status auto-refreshes every 5 s via a daemon `ScheduledExecutorService`
  (header checkbox; an `AtomicBoolean` drops overlapping runs). Live logs use
  `LdsCli.streamLogs()` (`docker compose logs --follow`) read on a daemon
  thread with `Platform.runLater` appends; Stop and the JVM shutdown hook
  destroy the child.
