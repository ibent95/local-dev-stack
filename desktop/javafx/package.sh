#!/usr/bin/env bash
# =============================================================================
# Package the JavaFX app into a self-contained app / installer for the OS you
# are building ON. jpackage cannot cross-package, so run this once per target
# OS — locally or via the desktop-build GitHub Actions matrix
# (.github/workflows/desktop-build.yml).
#
#   bash desktop/javafx/package.sh                         # → target/dist/LdsDesktop (app-image)
#   JPACKAGE_TYPE=exe  bash desktop/javafx/package.sh      # Windows .exe (no WiX needed)
#   JPACKAGE_TYPE=msi  bash desktop/javafx/package.sh      # Windows .msi (needs WiX)
#   JPACKAGE_TYPE=dmg  bash desktop/javafx/package.sh      # macOS .dmg
#   JPACKAGE_TYPE=deb  bash desktop/javafx/package.sh      # Linux .deb (needs dpkg-deb)
#
# app-image is the default: a self-contained folder with its own JRE that
# needs no extra system tools on any OS.
#
# Output lands in desktop/javafx/target/dist/.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

echo "==> [javafx] mvn package (jar)"
mvn -q -DskipTests package

echo "==> [javafx] collecting runtime deps into target/jfxlib"
rm -rf target/jfxlib
mvn -q dependency:copy-dependencies \
    -DoutputDirectory=target/jfxlib \
    -DincludeScope=runtime
cp target/lds-desktop-javafx-*.jar target/jfxlib/

echo "==> [javafx] jpackage --type ${JPACKAGE_TYPE:-app-image}"
rm -rf target/dist
if command -v jpackage >/dev/null 2>&1; then
  JPACKAGE_BIN="jpackage"
else
  # Fallback for images where the JDK bin dir isn't on PATH (e.g. lds/javafx-dev).
  JPACKAGE_BIN="$(ls -d /usr/lib/jvm/*/bin/jpackage 2>/dev/null | head -1)"
fi
"$JPACKAGE_BIN" \
    --type "${JPACKAGE_TYPE:-app-image}" \
    --name LdsDesktop \
    --input target/jfxlib \
    --main-jar lds-desktop-javafx-0.1.0.jar \
    --main-class com.localdevstack.lds.LdsDesktopApp \
    --dest target/dist

echo "==> [javafx] done: $(pwd)/target/dist"
ls -la target/dist
