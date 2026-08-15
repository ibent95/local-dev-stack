# =============================================================================
# Base image: lds/tauri-dev — Rust toolchain + Tauri v2 Linux build deps.
# FROM lds/rust-dev (DHI rust dev flavor on Alpine), adds the system libraries
# Tauri v2 needs to compile the webkit2gtk-4.1/gtk3 backend and run the app:
#   webkit2gtk-4.1-dev   WebView engine
#   gtk+3.0-dev          GTK3 (window/tray backend)
#   libayatana-appindicator-dev  system tray
#   librsvg, patchelf, desktop-file-utils, xdg-utils   bundler helpers
# Also installs the `tauri` CLI (cargo) so `cargo tauri build` works directly.
# NOTE: builds target Linux; Windows installers are produced on a Windows
# host (the same source tree) where WebView2 + MSVC toolchain are present.
# =============================================================================
ARG RUST_VERSION=1.96
FROM lds/rust-dev:${RUST_VERSION}

USER root

# NOTE (Aug 2026): the Alpine v3.24 repos were mid-transition during this
# development — dhi.io and dl-cdn are at different sync points, so apk's merged
# index offers lcms2-dev-2.19-r0 (needs lcms2-plugins EXACTLY 2.19-r0) alongside
# lcms2-plugins-2.19.1-r0, and resolution fails with "unable to select
# packages". The `lcms2-plugins=2.19-r0` pin forces the consistent set.
# TEMPORARY: remove the pin once the mirrors settle (preflight:
#   docker run --rm lds/rust-dev:1.96 apk add --simulate lcms2-dev lcms2-plugins
# Do NOT use --force-broken-world here: it exits 0 while silently SKIPPING the
# unresolvable -dev packages, leaving an image that fails to compile.
RUN apk add --no-cache \
        'lcms2-plugins=2.19-r0' \
        webkit2gtk-4.1-dev \
        gtk+3.0-dev \
        libayatana-appindicator-dev \
        librsvg-dev \
        openssl-dev \
        patchelf \
        desktop-file-utils \
        xdg-utils \
    && rm -rf /var/cache/apk/*

# Tauri CLI (cargo install compiles from source — cached in the image).
RUN cargo install tauri-cli --locked

# dbus-dev: libdbus-sys (a transitive tauri dep) probes `dbus-1` via pkg-config
# when the app compiles; the main apk block's appindicator pulls don't include it
# on Alpine. Kept as its own layer so the cargo-install layer above stays cached.
RUN apk add --no-cache dbus-dev \
    && rm -rf /var/cache/apk/*

# The LDS language bases (rust-dev/java-dev) run as root — they override DHI's
# non-root default and install the toolchain under /root (cargo + tauri-cli live
# in /root/.cargo/bin), so builds here run as root too.
USER root

WORKDIR /app
