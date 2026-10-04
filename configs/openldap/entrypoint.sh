#!/bin/sh
# LDS OpenLDAP bootstrap — runs as root on every start, then execs slapd as
# the unprivileged `ldap` user (mirrors the image's own entrypoint, but adds
# the first-boot setup the stock image lacks: templated slapd.conf + LDIF).
#
# Env (all optional, set in docker-compose.yml):
#   OPENLDAP_BASE_DN         e.g. dc=lds,dc=test   (must start with dc=)
#   OPENLDAP_ADMIN_DN        defaults to cn=admin,<base>
#   OPENLDAP_ADMIN_PASSWORD  root password (hashed with slappasswd)
set -eu

BASE="${OPENLDAP_BASE_DN:-dc=lds,dc=test}"
ADMIN_DN="${OPENLDAP_ADMIN_DN:-cn=admin,$BASE}"
ADMIN_PW="${OPENLDAP_ADMIN_PASSWORD:-adminadmin}"
DATA="/var/lib/openldap/openldap-data"
CONF="/var/lib/openldap/slapd.conf"
MARK="/var/lib/openldap/.lds-bootstrapped"

case "$BASE" in
  dc=*) ;;
  *) echo "FATAL: OPENLDAP_BASE_DN must start with 'dc=' (got: $BASE)" >&2; exit 1 ;;
esac

if [ ! -f "$MARK" ]; then
  echo "lds-openldap: first boot — generating config + loading base entries"

  # The ./data/openldap bind mount hides the image's pre-built data dir —
  # recreate it or slapd.conf's `directory` line points nowhere.
  mkdir -p "$DATA"

  # Suffix hash: base64 SSHA output stays inside sed's replacement charset.
  HASH="$(/usr/sbin/slappasswd -s "$ADMIN_PW")"
  DC="$(printf '%s' "$BASE" | sed -n 's/^dc=\([^,]*\).*/\1/p')"

  sed -e "s|@SUFFIX@|$BASE|g" \
      -e "s|@ROOTDN@|$ADMIN_DN|g" \
      -e "s|@ROOTPW@|$HASH|g" \
      /lds/slapd.conf.tmpl > "$CONF"
  chown root:ldap "$CONF"
  chmod 0640 "$CONF"

  sed -e "s|@SUFFIX@|$BASE|g" -e "s|@DC@|$DC|g" \
      /lds/bootstrap.ldif.tmpl > /tmp/lds-bootstrap.ldif
  /usr/sbin/slapadd -f "$CONF" -l /tmp/lds-bootstrap.ldif
  rm -f /tmp/lds-bootstrap.ldif

  chown -R ldap:ldap /var/lib/openldap
  touch "$MARK"
  echo "lds-openldap: ready — suffix $BASE, admin $ADMIN_DN"
fi

exec /usr/sbin/slapd -u ldap -g ldap -h "ldap://" -f "$CONF" -d 0
