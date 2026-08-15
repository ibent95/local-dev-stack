# =============================================================================
# Base image: lds/tauri-win-dev — Tauri v2 Windows cross-compile (.exe).
# FROM lds/tauri-dev (the Linux compile image), adds the mingw-w64 toolchain
# plus a rustup toolchain with the x86_64-pc-windows-gnu std target, so the
# SAME source tree emits a real Windows PE32+ binary from a Linux container:
#
#   cargo build --target x86_64-pc-windows-gnu
#     → desktop/tauri/src-tauri/target/x86_64-pc-windows-gnu/debug/lds-desktop.exe
#
# Notes:
# * mingw-w64 is NOT on the DHI apk mirror (it is curated) — it comes from the
#   upstream dl-cdn repos already configured in the base. `--no-cache` forces a
#   fresh index fetch so all three repos are consulted (the DHI-only cached
#   index does not list mingw-w64-*).
# * The apk-installed rustc (rust-dev base) has no foreign std, hence rustup.
#   The version is pinned to the stable that produced the current windows
#   target/ cache, so image rebuilds don't recompile the whole dep tree.
# * `cargo tauri build` bundling (NSIS/MSI installers) still requires Windows —
#   this image produces the raw .exe only. Ship WebView2Loader.dll alongside
#   the .exe at runtime (tauri needs it on Windows).
# =============================================================================
ARG RUST_VERSION=1.96
FROM lds/tauri-dev:${RUST_VERSION}

USER root

# mingw-w64 cross toolchain — compiler + `windres` (used by the Windows
# resource-embedding step in tauri-build / tauri-winres).
RUN apk add --no-cache \
        mingw-w64-gcc \
        mingw-w64-binutils \
        mingw-w64-crt \
    && rm -rf /var/cache/apk/*

# rustup + the windows-gnu std target (the apk rustc cannot cross-compile).
RUN wget -qO /tmp/rustup-init https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-musl/rustup-init \
    && chmod +x /tmp/rustup-init \
    && /tmp/rustup-init -y --profile minimal \
        --default-toolchain 1.97.1 \
        --target x86_64-pc-windows-gnu \
    && rm -f /tmp/rustup-init

# winres (tauri's Windows resource embedder) looks up plain `windres` on
# non-Windows hosts — provide the mingw one under that name.
RUN ln -s /usr/bin/x86_64-w64-mingw32-windres /usr/local/bin/windres

# Prefer the rustup toolchain (has the windows target) over the apk rustc.
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /app
