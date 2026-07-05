#!/usr/bin/env bash
# =============================================================================
# local-dev-stack — single entrypoint that unites every script.
#   ./lds.sh <command> [args]
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cmd="${1:-help}"; shift || true

case "$cmd" in
  # --- grouped contexts: lds <context> <subcommand> ----------------------
  kafka)
    sub="${1:-}"; shift 2>/dev/null || true
    case "$sub" in
      topics)              exec "$ROOT/scripts/run/kafka-topics.sh" "$@" ;;
      connect-plugin)      exec "$ROOT/scripts/run/connect-plugin.sh" "$@" ;;
      register-connectors) exec "$ROOT/scripts/run/register-connectors.sh" "$@" ;;
      init)                "$ROOT/scripts/run/kafka-topics.sh"; exec "$ROOT/scripts/run/register-connectors.sh" "$@" ;;
      *) echo "usage: lds kafka <topics | connect-plugin [--generic|--debezium] <name> | register-connectors | init>"; exit 1 ;;
    esac ;;
  tools)
    sub="${1:-}"; shift 2>/dev/null || true
    case "$sub" in
      semgrep) exec "$ROOT/scripts/run/semgrep.sh" "$@" ;;
      *) echo "usage: lds tools <semgrep [path]>"; exit 1 ;;
    esac ;;
  db)
    sub="${1:-}"; shift 2>/dev/null || true
    case "$sub" in
      init)
        case "${1:-all}" in
          mysql)  exec "$ROOT/scripts/run/mysql-init.sh" ;;
          postgres)  exec "$ROOT/scripts/run/postgres-init.sh" ;;
          mongo)  exec "$ROOT/scripts/run/mongo-init.sh" ;;
          all|"") "$ROOT/scripts/run/mysql-init.sh" || true; "$ROOT/scripts/run/postgres-init.sh" || true; exec "$ROOT/scripts/run/mongo-init.sh" ;;
          *) echo "usage: lds db init [mysql|postgres|mongo|all]"; exit 1 ;;
        esac ;;
      seed)  exec "$ROOT/scripts/run/dbgate-seed.sh" "$@" ;;
      *) echo "usage: lds db <init [mysql|postgres|mongo|all] | seed>"; exit 1 ;;
    esac ;;
  # --- lifecycle / scaffolding (flat) ------------------------------------
  init)                exec "$ROOT/scripts/run/init.sh" "$@" ;;
  network)             exec "$ROOT/scripts/run/network.sh" "$@" ;;
  new)                 exec "$ROOT/scripts/run/new.sh" "$@" ;;
  app)                 exec "$ROOT/scripts/run/app.sh" "$@" ;;
  build-bases)         exec "$ROOT/scripts/build/build-bases.sh" "$@" ;;
  build-php)           exec "$ROOT/scripts/build/build-php.sh" "$@" ;;
  up)                  exec "$ROOT/scripts/run/up.sh" "$@" ;;
  down)                exec "$ROOT/scripts/run/down.sh" "$@" ;;
  stop)                exec "$ROOT/scripts/run/stop.sh" "$@" ;;
  rm)                  exec "$ROOT/scripts/run/rm.sh" "$@" ;;
  start)               exec "$ROOT/scripts/run/start.sh" "$@" ;;
  logs)                exec "$ROOT/scripts/run/logs.sh" "$@" ;;
  certs)               exec "$ROOT/scripts/run/certs.sh" "$@" ;;
  hosts-sync)          exec "$ROOT/scripts/run/hosts-sync.sh" "$@" ;;
  ps)                  cd "$ROOT" && exec docker compose --profile '*' ps ;;
  exec)                exec "$ROOT/scripts/run/exec.sh" "$@" ;;
  # --- back-compat aliases (old flat names; prefer the grouped forms) -----
  kafka-topics)        exec "$ROOT/scripts/run/kafka-topics.sh" "$@" ;;
  register-connectors) exec "$ROOT/scripts/run/register-connectors.sh" "$@" ;;
  connect-plugin)      exec "$ROOT/scripts/run/connect-plugin.sh" "$@" ;;
  mysql-init)          exec "$ROOT/scripts/run/mysql-init.sh" "$@" ;;
  postgres-init)       exec "$ROOT/scripts/run/postgres-init.sh" "$@" ;;
  mongo-init)          exec "$ROOT/scripts/run/mongo-init.sh" "$@" ;;
  dbgate-seed)         exec "$ROOT/scripts/run/dbgate-seed.sh" "$@" ;;
  help|-h|--help)
    cat <<'EOF'
local-dev-stack — usage: ./lds.sh <command> [args]

  init                          create the shared `lds-network` network (run once)
  new <type> <name> [host]      scaffold a project (php | <tech> | svc-/web-<tech>)
  app <start|stop|restart|logs|ps> [dir]   manage an svc/web project (dir=.)
                                  start ensures the proxy; stop accepts -v
  network [status|create|rm|reset]   manage the shared lds-network
  build-bases [--force|--push]  build the lds/* base images
  up [profiles...]              start profiles (default: LDS_ENABLE_* toggles, else all)
                                  e.g. up proxy | up mysql redis | up kafka | up mqtt
  stop                          stop running containers but KEEP them (fast resume via up)
  down [-v]                     remove containers (-v also wipes data volumes)
  rm [profiles...]              force-remove containers (default: all)
  start [profiles...]           full lifecycle: init, down, rm, build-bases
                                  (if missing), up (default: all)
  logs [service]                tail logs (all, or one service)
  ps                            status of all services
  exec <service> [cmd...]       run a command (or open a shell) in a service container

 kafka <sub>                    topics | connect-plugin [--generic|--debezium] <name>
                                  | register-connectors | init (topics + connectors)
 db <sub>                       init [mysql|postgres|mongo|all] | seed (DBGate connections)
 tools <sub>                    semgrep [path]  (scan; view at semgrep.test via `up semgrep`)

  certs [--force]               mint the wildcard *.test dev TLS cert (for LDS_ENABLE_HTTPS)
  hosts-sync                    write www/ projects into the hosts file (fallback)
  build-php [--push]            (re)build just the PHP service image
  help                          show this message

  (old flat names — kafka-topics, mongo-init, postgres-init, mysql-init, register-connectors,
   connect-plugin, dbgate-seed — still work as aliases.)
EOF
    ;;
  *) echo "Unknown command: $cmd"; "$0" help; exit 1 ;;
esac
