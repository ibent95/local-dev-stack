#!/usr/bin/env bash
# Generate a wildcard dev TLS cert for the .test hosts into configs/proxy/certs/.
# Prefers mkcert (installs a trusted local CA -> no browser warnings); falls back
# to a self-signed openssl cert (works, but the browser warns until you trust it).
#   ./scripts/run/certs.sh            generate if missing
#   ./scripts/run/certs.sh --force    regenerate even if present
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CERT_DIR="$ROOT/configs/proxy/certs"
# Named after the TLD: nginx-proxy matches vhost <name>.test to test.crt by
# stripping the leftmost label (wildcard-parent lookup). The php container also
# sets CERT_NAME=test (in docker-compose.https.yml) so its localhost + regex
# *.test vhosts use it too.
CRT="$CERT_DIR/test.crt"
KEY="$CERT_DIR/test.key"
mkdir -p "$CERT_DIR"

# Hosts/IPs the dev cert is valid for. *.test covers <name>.test, cache.test,
# db.test, mqtt.test, ws.test, centrifugo.test, etc.
HOSTS=("*.test" "test" "localhost" "127.0.0.1" "::1")

[ "${1:-}" = "--force" ] && rm -f "$CRT" "$KEY"

if [ -s "$CRT" ] && [ -s "$KEY" ]; then
  echo "Cert already present: $CRT  (use --force to regenerate)"
  exit 0
fi

if command -v mkcert >/dev/null 2>&1; then
  echo "Generating cert with mkcert (trusted local CA)…"
  mkcert -install
  mkcert -cert-file "$CRT" -key-file "$KEY" "${HOSTS[@]}"
  echo "Done — browsers will trust https://*.test"
elif command -v openssl >/dev/null 2>&1; then
  echo "mkcert not found — falling back to a self-signed openssl cert."
  echo "  (the browser will warn until you trust it; install mkcert for a clean"
  echo "   cert: https://github.com/FiloSottile/mkcert )"
  openssl req -x509 -newkey rsa:2048 -nodes -days 825 \
    -keyout "$KEY" -out "$CRT" \
    -subj "/CN=*.test/O=local-dev-stack" \
    -addext "subjectAltName=DNS:*.test,DNS:test,DNS:localhost,IP:127.0.0.1,IP:0:0:0:0:0:0:0:1"
  echo "Done (self-signed): $CRT"
else
  echo "ERROR: neither mkcert nor openssl is installed." >&2
  echo "Install mkcert (recommended): https://github.com/FiloSottile/mkcert" >&2
  exit 1
fi

# Apply immediately: nginx re-reads cert files on reload, but a bind-mounted
# cert change does NOT restart the container — so a running proxy keeps serving
# the OLD cert until told to reload. (This is what causes a stale-cert
# ERR_CERT_AUTHORITY_INVALID after regenerating.)
if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx lds-proxy; then
  echo "Reloading lds-proxy to apply the new cert…"
  docker exec lds-proxy nginx -s reload >/dev/null 2>&1 || docker restart lds-proxy >/dev/null 2>&1 || true
fi
