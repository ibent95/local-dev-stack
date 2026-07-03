#!/usr/bin/env bash
# Scaffold a new project — the cross-language equivalent of "drop a PHP folder".
#   lds new php   myblog            -> $PHP_PROJECTS_PATH/myblog (served instantly)
#   lds new go    myapi             -> web template by default
#   lds new svc-python rates        -> templates/svc-template-python
#   lds new web-laravel shop shop.test   (optional custom host)
#
# PHP (plain) projects go under the shared mass-vhost mount; everything else is
# copied from templates/<role>-template-<tech> into that tech's *_PROJECTS_PATH,
# with the template's name/container_name/host rewritten to the project name.
set -euo pipefail
export MSYS_NO_PATHCONV=1                 # Git Bash: don't rewrite our paths
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Load .env so the *_PROJECTS_PATH vars are available (shell env still wins).
if [ -f .env ]; then
  while IFS='=' read -r k v; do
    k="${k%$'\r'}"; v="${v%$'\r'}"   # strip \r from Windows line endings
    case "$k" in ''|'#'*) continue ;; esac
    [ -z "${!k:-}" ] && export "$k=$v"
  done < .env
fi

usage() {
  cat <<'EOF'
Usage: lds new <type> <name> [host]
  <type>  php | <tech> | <role>-<tech>     (role = svc|web|cron; bare tech -> web)
          tech: go rust node python java express flask fastapi django
                laravel symfony slim webman codeigniter cakephp
                springboot micronaut quarkus vaadin angular react
          cron (scheduled job; lands in the tech's path — cron-shell -> JOBS_PROJECTS_PATH):
                cron-shell cron-python cron-node cron-go cron-php  (bare 'cron' = shell)
                cron-hop cron-pdi           (ETL jobs → HOP_PROJECTS_PATH)
                web-superset web-powerbi web-metabase web-grafana (BI dashboards)
  <name>  project folder name (also the *.test hostname for web/svc)
  [host]  optional VIRTUAL_HOST (default <name>.test)

Examples:
  lds new php myblog
  lds new svc-python rates
  lds new web-laravel shop shop.test
  lds new cron-python nightly-report
  lds new cron-hop my-etl-project
  lds new cron-pdi my-pdi-project
  lds new web-superset my-bi-dashboard
  lds new web-grafana my-metrics
EOF
}

# tech keyword -> the env var holding its projects path
path_var_for() {
  case "$1" in
    go)                                   echo GO_PROJECTS_PATH ;;
    rust)                                 echo RUST_PROJECTS_PATH ;;
    node|express|angular|react)           echo NODE_PROJECTS_PATH ;;
    python|flask|fastapi|django)          echo PYTHON_PROJECTS_PATH ;;
    java|springboot|micronaut|quarkus|vaadin) echo JAVA_PROJECTS_PATH ;;
    php|laravel|symfony|slim|webman|codeigniter|cakephp) echo PHP_PROJECTS_PATH ;;
    shell)                                echo JOBS_PROJECTS_PATH ;;   # cron-shell: no language home
    hop|pdi)                              echo HOP_PROJECTS_PATH ;;
    superset|powerbi|metabase|grafana)    echo SUPERSET_PROJECTS_PATH ;;
    *)                                    echo "" ;;
  esac
}

type="${1:-}"; name="${2:-}"; host="${3:-}"
if [ -z "$type" ] || [ -z "$name" ]; then usage; exit 1; fi
host="${host:-$name.test}"

# ---- plain PHP (shared mass-vhost; no compose) ------------------------------
if [ "$type" = "php" ]; then
  base="${PHP_PROJECTS_PATH:-./www}"
  dest="$base/$name"
  [ -e "$dest" ] && { echo "Already exists: $dest"; exit 1; }
  mkdir -p "$dest/public"
  cat > "$dest/public/index.php" <<PHP
<?php
echo "<h1>$name</h1>";
echo "<p>Served by local-dev-stack at <code>$host</code> — PHP " . PHP_VERSION . "</p>";
PHP
  echo "Created plain PHP project: $dest"
  echo "  -> http://$host    (start the php profile if needed: lds up php)"
  exit 0
fi

# ---- template-based projects ------------------------------------------------
case "$type" in
  svc-*)  role=svc;  tech="${type#svc-}" ;;
  web-*)  role=web;  tech="${type#web-}" ;;
  cron-*) role=cron; tech="${type#cron-}" ;;
  cron)   role=cron; tech=shell ;;            # bare 'cron' = shell cron job
  hop)    role=cron; tech=hop ;;              # bare 'hop' → cron-template-hop
  pdi)    role=cron; tech=pdi ;;              # bare 'pdi' → cron-template-pdi
  superset)  role=web; tech=superset ;;       # bare 'superset' → web-template-superset
  powerbi)   role=web; tech=powerbi ;;        # bare 'powerbi' → web-template-powerbi
  metabase)  role=web; tech=metabase ;;       # bare 'metabase' → web-template-metabase
  grafana)   role=web; tech=grafana ;;        # bare 'grafana' → web-template-grafana
  *)      tech="$type"; role=web
          [ -d "templates/web-template-$tech" ] || role=svc ;;
esac

tpl="$role-template-$tech"
src="templates/$tpl"
if [ ! -d "$src" ]; then
  echo "No template '$src'."; echo "Available templates:"; ls templates | sed 's/^/  /'
  exit 1
fi

# Path follows the tech, same as svc/web (so cron-python -> PYTHON_PROJECTS_PATH,
# cron-go -> GO_PROJECTS_PATH, …). Only language-agnostic cron-shell uses JOBS.
var="$(path_var_for "$tech")"
[ -z "$var" ] && { echo "Don't know where to put '$tech' projects."; exit 1; }
base="${!var:-./projects/$tech}"
dest="$base/$name"
[ -e "$dest" ] && { echo "Already exists: $dest"; exit 1; }

mkdir -p "$(dirname "$dest")"
cp -r "$src" "$dest"

# Rewrite the template identifier (name/container_name/APP_HOST default) -> project.
grep -rl "$tpl" "$dest" 2>/dev/null | while IFS= read -r f; do
  sed -i "s/$tpl/$name/g" "$f"
done

# Cron projects vendor the supercronic binary (no network at build/deploy).
# Copied AFTER the rename above so it's never touched by sed.
# Exclude ETL data projects (hop, pdi) — they're just config files, not cron jobs.
if [ "$role" = "cron" ] && [ "$tech" != "hop" ] && [ "$tech" != "pdi" ]; then
  mkdir -p "$dest/bin"
  cp "$ROOT/assets/supersonic/v0.2.46/supercronic-linux-amd64" "$dest/bin/supercronic"
fi

# Custom host? compose auto-loads .env in the project dir.
if [ "$host" != "$name.test" ]; then
  printf 'APP_HOST=%s\nTZ=%s\n' "$host" "${TZ:-Asia/Jakarta}" > "$dest/.env"
fi

echo "Scaffolded $tpl -> $dest"
echo "Next:"
echo "  cd \"$dest\" && lds app start"
if grep -q "VIRTUAL_HOST" "$dest/docker-compose.yml" 2>/dev/null; then
  echo "  -> http://$host"
else
  echo "  (no web URL — scheduled/worker service; watch it with: lds app logs)"
fi
