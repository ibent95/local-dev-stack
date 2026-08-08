#!/bin/sh
# Two DNS views, one container:
#
#   A — eth0 (host-facing, published :53): resolves *.test -> 127.0.0.1 for the
#       HOST (adapter DNS / hosts file). This is the stack's original behaviour,
#       unchanged.
#
#   B — 10.99.0.53 (lds-dnsnet): an IN-NETWORK view that resolves *.test -> the
#       PROXY container IP, so browser tools INSIDE the stack (e.g. OWASP ZAP
#       scanning http://myapp.test from zap.test) can reach local apps. All other
#       queries forward to Docker's embedded DNS (container names + internet).
#
# Why: *.test -> 127.0.0.1 is correct for the host but useless inside a
# container (127.0.0.1 there is the container itself, not the proxy). The proxy
# IP is dynamic, so instance B generates its config at startup.
set -e

# A — host-facing (config baked into the image).
dnsmasq --keep-in-foreground --conf-file=/etc/dnsmasq.conf &
PID_A=$!

# B — in-network view. Resolve the proxy container's IP via Docker's embedded
# DNS, retrying while the proxy comes up (it may still be starting).
PROXY_IP=""
for i in $(seq 1 30); do
  PROXY_IP=$(nslookup proxy 127.0.0.11 2>/dev/null | awk '/^Address: / {print $2}' | tail -n1)
  [ -n "$PROXY_IP" ] && break
  sleep 2
done

if [ -z "$PROXY_IP" ]; then
  echo "[dns] proxy not resolvable — in-network *.test view disabled (ZAP will not reach *.test apps)."
  wait "$PID_A"
  exit 0
fi

echo "[dns] in-network *.test -> $PROXY_IP on 10.99.0.53"
cat > /etc/dnsmasq-internal.conf <<EOF
address=/test/$PROXY_IP
listen-address=10.99.0.53
bind-interfaces
no-resolv
server=127.0.0.11
cache-size=150
EOF
dnsmasq --keep-in-foreground --conf-file=/etc/dnsmasq-internal.conf &
PID_B=$!

trap 'kill $PID_A $PID_B 2>/dev/null' TERM INT
wait
