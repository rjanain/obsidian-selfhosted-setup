#!/usr/bin/env bash
# =============================================================================
# provision.sh — create the vault database and its device user. Idempotent.
#
# Runs on the server (make provision), against CouchDB on 127.0.0.1. Safe to
# re-run: existing databases are kept, and the device user's password is reset
# to VAULT_PASSWORD from .env (that is how you rotate it).
#
#   bash scripts/provision.sh
#   VAULT_DB=work_vault VAULT_USER=work VAULT_PASSWORD=... bash scripts/provision.sh
#
# What it does
#   1. Waits for CouchDB, ensures the _users and _replicator system databases.
#   2. Creates VAULT_DB.
#   3. Creates or updates VAULT_USER (a plain user: no server roles).
#   4. Makes VAULT_USER admin + member of VAULT_DB only. LiveSync writes a
#      _design/chunks doc for garbage collection, which needs DB-admin.
#   5. Verifies: the user can open VAULT_DB, cannot read server config, and
#      anonymous requests are refused.
#
# Overridable via environment: COUCH_URL (default http://127.0.0.1:$COUCHDB_LOCAL_PORT)
# =============================================================================
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in -h|--help) awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;; esac

# Keep values given on the command line over the ones in .env.
_pre_db="${VAULT_DB:-}"; _pre_user="${VAULT_USER:-}"; _pre_pw="${VAULT_PASSWORD:-}"; _pre_url="${COUCH_URL:-}"
load_env
VAULT_DB="${_pre_db:-$VAULT_DB}"; VAULT_USER="${_pre_user:-$VAULT_USER}"; VAULT_PASSWORD="${_pre_pw:-$VAULT_PASSWORD}"
COUCH_URL="${_pre_url:-http://127.0.0.1:${COUCHDB_LOCAL_PORT:-5984}}"

[[ "$VAULT_DB" =~ ^[a-z][a-z0-9_$()+/-]*$ ]] || die "VAULT_DB '$VAULT_DB' is not a valid CouchDB name (lowercase, start with a letter)."
[ "$VAULT_USER" != "$COUCHDB_USER" ] || die "VAULT_USER must differ from the server admin COUCHDB_USER."
case "$VAULT_PASSWORD" in change-me*|"") die "Set a real VAULT_PASSWORD in .env first." ;; esac
case "$COUCHDB_PASSWORD" in change-me*|"") die "Set a real COUCHDB_PASSWORD in .env first." ;; esac

curl_auth_cfg ADMIN_CFG "$COUCHDB_USER" "$COUCHDB_PASSWORD"
curl_auth_cfg USER_CFG "$VAULT_USER" "$VAULT_PASSWORD"
USER_ID="org.couchdb.user:${VAULT_USER}"

echo "=== Provisioning ${VAULT_DB} for ${VAULT_USER} at ${COUCH_URL} ==="

# 1. Wait for CouchDB.
for i in $(seq 1 30); do
    [ "$(http_status "$COUCH_URL/_up")" = "200" ] && break
    [ "$i" -eq 30 ] && die "CouchDB did not answer on $COUCH_URL/_up — is the container up? (make ps)"
    sleep 2
done
ok "CouchDB is up"

[ "$(http_status -K "$ADMIN_CFG" "$COUCH_URL/_session")" = "200" ] \
    || die "Admin login failed — COUCHDB_USER/COUCHDB_PASSWORD in .env don't match the running server."

put_db() {
    local db="$1" code
    code="$(http_status -K "$ADMIN_CFG" -X PUT "$COUCH_URL/$db")"
    case "$code" in
        201|202) ok "created database $db" ;;
        412)     ok "database $db already exists" ;;
        *)       die "creating database $db returned HTTP $code" ;;
    esac
}

put_db _users
put_db _replicator
put_db "$VAULT_DB"

# 3. Device user: create, or update the password if it exists.
rev="$(curl -s --max-time 15 -K "$ADMIN_CFG" "$COUCH_URL/_users/$USER_ID" | json_field _rev)"
code="$(json_user_doc "$VAULT_USER" "$VAULT_PASSWORD" "$rev" \
    | http_status -K "$ADMIN_CFG" -X PUT -H 'Content-Type: application/json' \
        --data-binary @- "$COUCH_URL/_users/$USER_ID")"
case "$code" in
    201|202) ok "user $VAULT_USER $([ -n "$rev" ] && echo 'updated (password reset)' || echo 'created')" ;;
    *)       die "writing user $VAULT_USER returned HTTP $code" ;;
esac

# 4. Scope the user to this database only.
code="$(json_security_doc "$VAULT_USER" \
    | http_status -K "$ADMIN_CFG" -X PUT -H 'Content-Type: application/json' \
        --data-binary @- "$COUCH_URL/$VAULT_DB/_security")"
[ "$code" = "200" ] && ok "$VAULT_USER is admin + member of $VAULT_DB only" || die "_security returned HTTP $code"

# 5. Verify.
echo
echo "=== Checks ==="
[ "$(http_status -K "$USER_CFG" "$COUCH_URL/$VAULT_DB")" = "200" ] \
    && ok "$VAULT_USER can open $VAULT_DB" || bad "$VAULT_USER cannot open $VAULT_DB"
code="$(http_status -K "$USER_CFG" "$COUCH_URL/_node/_local/_config")"
[[ "$code" =~ ^40[13]$ ]] && ok "$VAULT_USER cannot read server config (HTTP $code)" \
    || bad "$VAULT_USER can read server config (HTTP $code) — it has too much access"
code="$(http_status "$COUCH_URL/$VAULT_DB")"
[ "$code" = "401" ] && ok "anonymous access refused (HTTP 401)" || bad "anonymous access returned HTTP $code"

[ "$FAILED" -eq 0 ] || die "Provisioning finished with failed checks."
echo
echo "Done. Devices connect with: URI https://${TS_HOSTNAME:-<ts-hostname>}:${TS_HTTPS_PORT:-6984}, user ${VAULT_USER}, database ${VAULT_DB}."
