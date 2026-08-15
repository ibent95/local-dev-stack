#!/usr/bin/env bash
# =============================================================================
# Build the LDS Desktop apps. Two modes:
#
#   --os linux (default) — inside the stack's own base images (no Rust, Maven
#       or PHP toolchain needed on the host). The repo is bind-mounted into the
#       container, so artifacts land in the tree. This is the compile-check:
#       Tauri → Linux binary, JavaFX → jar + Linux app-image, NativePHP →
#       composer + vite + artisan check.
#
#   --os win / --os mac — on the matching HOST OS, producing real installers
#       for that OS. jpackage (JavaFX) and electron-builder (NativePHP) cannot
#       cross-package, and macOS artifacts can ONLY be built on macOS — so
#       these require the toolchain on a machine of that OS. If you run them on
#       the wrong OS, the script prints the pointer to the CI matrix that
#       builds all three OSes for you.
#
#   --os win --container — exception: the Tauri Rust backend CAN be
#       cross-compiled to a Windows .exe inside a Linux container (mingw-w64 +
#       rustup in lds/tauri-win-dev). This is a raw .exe — NSIS/MSI installers
#       still need a Windows host. JavaFX/NativePHP have no containerized win
#       path (their jars are cross-platform; installers need the native OS).
#
# Usage:
#   desktop/build.sh                       # all variants, containerized (Linux)
#   desktop/build.sh tauri                 # one variant
#   desktop/build.sh javafx --os linux     # explicit OS (same as default)
#   desktop/build.sh all --os win          # host Windows build (needs toolchain)
#   desktop/build.sh tauri --os win --container   # Windows .exe from the container
#   desktop/build.sh all --os mac          # host macOS build (needs toolchain)
#   desktop/build.sh dioxus                # Dioxus spike: cargo build in lds/tauri-dev
#   desktop/build.sh dioxus --os win --container   # Dioxus Windows .exe (tauri-win-dev)
#
# Base images (see docker-bake.hcl):
#   lds/tauri-dev     — rust-dev + webkit2gtk-4.1/GTK3 deps + tauri-cli
#   lds/javafx-dev    — java-dev + GTK3/fontconfig/X11 deps + binutils (jpackage)
#   lds/nativephp-dev — lds/php + sqlite + patch (PHP 8.4 CLI + composer + node)
#   dioxus reuses lds/tauri-dev (wry needs the same webkit2gtk deps as Tauri).
# Build them with:  lds build-bases   (or docker buildx bake tauri-dev javafx-dev nativephp-dev)
#
# For one-command Windows + Linux + macOS builds of every variant, use the
# GitHub Actions matrix: .github/workflows/desktop-build.yml (3 runners × 3
# variants, artifacts uploaded).
# =============================================================================
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Load .env for the base-image tags (RUST_VERSION / JAVA_VERSION / PHP_VERSION).
RUST_VERSION="1.96"
JAVA_VERSION="25"
PHP_VERSION="8.4"
if [ -f .env ]; then
  while IFS='=' read -r k v; do
    case "$k" in
      RUST_VERSION) RUST_VERSION="${v%$'\r'}" ;;
      JAVA_VERSION) JAVA_VERSION="${v%$'\r'}" ;;
      PHP_VERSION)  PHP_VERSION="${v%$'\r'}" ;;
    esac
  done < .env
fi

# --- argument parsing: [all|tauri|javafx|nativephp] [--os linux|win|mac|auto] [--container] ---
variant="all"
os="linux"
container=0
prev=""
for a in "$@"; do
  if [ "$prev" = "--os" ]; then os="$a"; prev=""; continue; fi
  prev="$a"
  case "$a" in
    --os) ;;
    --container) container=1 ;;
    all|tauri|javafx|nativephp|dioxus) variant="$a" ;;
    linux|win|mac|auto) os="$a" ;;
    *) echo "usage: $0 [all|tauri|javafx|nativephp] [--os linux|win|mac|auto] [--container]"; exit 1 ;;
  esac
done
prev=""

case "$(uname -s)" in
  Linux*)              HOST_OS="linux" ;;
  Darwin*)             HOST_OS="mac" ;;
  MINGW*|MSYS*|CYGWIN*) HOST_OS="win" ;;
  *)                   HOST_OS="unknown" ;;
esac
if [ "$os" = "auto" ]; then os="$HOST_OS"; fi

# --- ensure base images exist before containerized builds ---
ensure_image() {
  local image="$1"
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "==> building base image $image (first run)…"
    case "$image" in
      *tauri-win*) docker buildx bake -f "$ROOT/docker-bake.hcl" --load tauri-win-dev ;;
      *dioxus*)    docker buildx bake -f "$ROOT/docker-bake.hcl" --load tauri-dev ;;
      *tauri*)     docker buildx bake -f "$ROOT/docker-bake.hcl" --load tauri-dev ;;
      *javafx*)    docker buildx bake -f "$ROOT/docker-bake.hcl" --load javafx-dev ;;
      *nativephp*) docker buildx bake -f "$ROOT/docker-bake.hcl" --load nativephp-dev ;;
    esac
  fi
}

# --- host build on win/mac: toolchain checks + per-variant commands ---
host_build() {
  local target="$1" want="$2"
  if [ "$HOST_OS" != "$target" ]; then
    echo ""
    echo "ERROR: --os $target artifacts can only be built on a $target machine"
    echo "       (current host: $HOST_OS). jpackage / electron-builder cannot"
    echo "       cross-package, and macOS requires Apple tooling."
    echo ""
    echo "To build Windows + Linux + macOS for every variant in one go, run the"
    echo "GitHub Actions matrix: .github/workflows/desktop-build.yml"
    echo "  (3 runners x 3 variants, installers uploaded as artifacts)."
    exit 1
  fi
  echo ""
  echo "==> [host:$target] building on the host ($HOST_OS)"
  if [ "$want" = "tauri" ] || [ "$want" = "all" ]; then
    command -v cargo >/dev/null 2>&1 || { echo "  missing: cargo (rustup). Install Rust, then: cargo install tauri-cli --locked"; exit 1; }
    echo "==> [tauri] cargo tauri build — installers in desktop/tauri/src-tauri/target/release/bundle/"
    ( cd desktop/tauri/src-tauri && cargo tauri build )
  fi
  if [ "$want" = "javafx" ] || [ "$want" = "all" ]; then
    command -v mvn >/dev/null 2>&1 || { echo "  missing: mvn (Maven 3.9+ with JDK 21+). See desktop/javafx/README.md"; exit 1; }
    echo "==> [javafx] jpackage via package.sh — app/installer in desktop/javafx/target/dist/"
    bash desktop/javafx/package.sh
  fi
  if [ "$want" = "nativephp" ] || [ "$want" = "all" ]; then
    command -v php >/dev/null 2>&1 || { echo "  missing: php (8.3+ with composer). See desktop/nativephp/README.md"; exit 1; }
    echo "==> [nativephp] php artisan native:build $target"
    ( cd desktop/nativephp && php artisan native:build "$target" )
  fi
  if [ "$want" = "dioxus" ] || [ "$want" = "all" ]; then
    command -v dx >/dev/null 2>&1 || { echo "  missing: dx (Dioxus CLI). Install: cargo install dioxus-cli --locked"; exit 1; }
    echo "==> [dioxus] dx bundle — installers in desktop/dioxus/dist/"
    ( cd desktop/dioxus && dx bundle )
  fi
}

# --- containerized Linux builds (the compile-checks) ---
container_build() {
  local want="$1"
  if [ "$want" = "tauri" ] || [ "$want" = "all" ]; then
    ensure_image "lds/tauri-dev:${RUST_VERSION}"
    echo ""
    echo "==> [tauri] cargo check + build (Linux) — desktop/tauri/src-tauri"
    docker run --rm \
      -v "$ROOT:/app" \
      -w /app/desktop/tauri/src-tauri \
      "lds/tauri-dev:${RUST_VERSION}" sh -c "
        cargo check 2>&1 | tail -5
        echo '---'
        cargo build 2>&1 | tail -5
      "
    echo "==> [tauri] done (target dir: desktop/tauri/src-tauri/target)"
  fi

  if [ "$want" = "dioxus" ] || [ "$want" = "all" ]; then
    ensure_image "lds/tauri-dev:${RUST_VERSION}"
    echo ""
    echo "==> [dioxus] cargo build (Linux compile-check) — desktop/dioxus (reuses lds/tauri-dev)"
    docker run --rm \
      -v "$ROOT:/app" \
      -w /app/desktop/dioxus \
      "lds/tauri-dev:${RUST_VERSION}" sh -c "
        cargo build 2>&1 | tail -10
        echo '---'
        file target/debug/lds-desktop-dioxus
      "
    echo "==> [dioxus] done (binary: desktop/dioxus/target/debug/lds-desktop-dioxus)"
  fi

  if [ "$want" = "javafx" ] || [ "$want" = "all" ]; then
    ensure_image "lds/javafx-dev:${JAVA_VERSION}"
    echo ""
    echo "==> [javafx] mvn package + jpackage app-image — desktop/javafx"
    docker run --rm \
      -v "$ROOT:/app" \
      -w /app/desktop/javafx \
      "lds/javafx-dev:${JAVA_VERSION}" sh -c "bash package.sh"
    echo "==> [javafx] done (jar: desktop/javafx/target/ · app-image: desktop/javafx/target/dist/)"
  fi

  if [ "$want" = "nativephp" ] || [ "$want" = "all" ]; then
    ensure_image "lds/nativephp-dev:${PHP_VERSION}"
    echo ""
    echo "==> [nativephp] composer install (patch applies) + vite build + artisan check (Linux)"
    docker run --rm \
      -v "$ROOT:/app" \
      -w /app/desktop/nativephp \
      "lds/nativephp-dev:${PHP_VERSION}" sh -c "
        composer install --no-interaction --no-progress 2>&1 | tail -5
        echo '---'
        npm install --no-audit --no-fund 2>&1 | tail -3
        npm run build 2>&1 | tail -5
        echo '---'
        php artisan list >/dev/null 2>&1 && echo 'artisan list OK' || echo 'artisan list FAILED'
      "
    echo "==> [nativephp] done (compile-check only — installers are built on the host / CI)"
  fi
}

# --- containerized Windows cross-compile (Tauri only) ---
container_win_build() {
  local want="$1"
  if [ "$want" = "tauri" ] || [ "$want" = "all" ]; then
    ensure_image "lds/tauri-win-dev:${RUST_VERSION}"
    echo ""
    echo "==> [tauri] cargo build --target x86_64-pc-windows-gnu (Windows .exe, in container)"
    docker run --rm \
      -v "$ROOT:/app" \
      -w /app/desktop/tauri/src-tauri \
      "lds/tauri-win-dev:${RUST_VERSION}" sh -c "
        cargo build --target x86_64-pc-windows-gnu 2>&1 | tail -10
        echo '---'
        file target/x86_64-pc-windows-gnu/debug/lds-desktop.exe
      "
    echo "==> [tauri] done (.exe: desktop/tauri/src-tauri/target/x86_64-pc-windows-gnu/debug/)"
  fi
  if [ "$want" = "dioxus" ] || [ "$want" = "all" ]; then
    ensure_image "lds/tauri-win-dev:${RUST_VERSION}"
    echo ""
    echo "==> [dioxus] cargo build --target x86_64-pc-windows-gnu (Windows .exe, in container)"
    docker run --rm \
      -v "$ROOT:/app" \
      -w /app/desktop/dioxus \
      "lds/tauri-win-dev:${RUST_VERSION}" sh -c "
        cargo build --target x86_64-pc-windows-gnu 2>&1 | tail -10
        echo '---'
        file target/x86_64-pc-windows-gnu/debug/lds-desktop-dioxus.exe
      "
    echo "==> [dioxus] done (.exe: desktop/dioxus/target/x86_64-pc-windows-gnu/debug/)"
  fi
  if [ "$want" != "tauri" ] && [ "$want" != "dioxus" ]; then
    echo ""
    echo "NOTE: JavaFX/NativePHP have no containerized Windows build:"
    echo "      - JavaFX jar (target/*.jar) is cross-platform — exe/msi need jpackage on Windows"
    echo "      - NativePHP exe needs a Windows host (or the CI matrix)"
  fi
}

if [ "$os" = "linux" ]; then
  container_build "$variant"
elif [ "$container" = "1" ] && [ "$os" = "win" ]; then
  container_win_build "$variant"
elif [ "$container" = "1" ]; then
  echo "ERROR: --os $os cannot be built in a Linux container ($os needs its native toolchain)."
  exit 1
else
  host_build "$os" "$variant"
fi

echo ""
echo "Desktop builds complete."
