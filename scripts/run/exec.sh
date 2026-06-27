#!/usr/bin/env bash
# Run a command in a service's container — or open a shell if no command given.
#   lds exec <service> [command...]
#   lds exec mongo                          # interactive shell (bash, else sh)
#   lds exec mongo mongosh -u root -p root --authenticationDatabase admin
#   lds exec mysql mysql -uroot -proot app
#   lds exec redis redis-cli
# Uses `docker compose exec`, so pass the SERVICE name (mongo, kafka-broker,
# connect-debezium, …) — not the container name.
set -euo pipefail
export MSYS_NO_PATHCONV=1          # don't let Git Bash rewrite args like /opt/...
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

svc="${1:-}"; shift || true
if [ -z "$svc" ]; then
  cat <<'EOF'
Usage: lds exec <service> [command...]
  lds exec mongo                  # open a shell
  lds exec mongo mongosh -u root -p root --authenticationDatabase admin
  lds exec mysql mysql -uroot -proot app
  lds exec postgres psql -U app app
  lds exec redis redis-cli
Tip: `lds ps` lists running services.
EOF
  exit 1
fi

# compose exec allocates a TTY by default; disable it when not interactive
# (e.g. piped) so it doesn't fail with "the input device is not a TTY".
TT=(); { [ -t 0 ] && [ -t 1 ]; } || TT=(-T)

if [ "$#" -eq 0 ]; then
  exec docker compose --profile '*' exec "$svc" sh -c 'command -v bash >/dev/null 2>&1 && exec bash || exec sh'
else
  exec docker compose --profile '*' exec "${TT[@]}" "$svc" "$@"
fi
