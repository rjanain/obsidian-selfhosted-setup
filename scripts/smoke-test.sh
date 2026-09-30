#!/usr/bin/env bash
# =============================================================================
# smoke-test.sh — boot a throwaway copy of the stack and run every script on it.
#
#   bash scripts/smoke-test.sh          # local Mac or CI; needs Docker
#
# Uses its own Compose project (obsidian-livesync-smoke), container name,
# random credentials and ports 25984/25985, so it cannot collide with a real
# deployment. Steps: up → provision (twice, idempotency) → verify --local →
# write a note doc and LiveSync's _design/chunks as the device user → backup
# (and its keep-newest-4 pruning) → restore-test → down -v.
# =============================================================================
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO_ROOT"

PROJECT="obsidian-livesync-smoke"
work="$(mktemp -d)"
export ENV_FILE="$work/smoke.env"

cat > "$ENV_FILE" <<EOF
COUCHDB_USER=smoke_admin
COUCHDB_PASSWORD=$(openssl rand -hex 16)
VAULT_DB=smoke_vault
VAULT_USER=smoke_user
VAULT_PASSWORD=$(openssl rand -hex 16)
COUCHDB_LOCAL_PORT=25984
COUCHDB_CONTAINER=obsidian_couchdb_smoke
BACKUP_DIR=$work/backups
BACKUP_KEEP=4
RESTORE_TEST_PORT=25985
TS_HOSTNAME=smoke.invalid
TS_HTTPS_PORT=6984
EOF

compose() { docker compose -p "$PROJECT" --env-file "$ENV_FILE" "$@"; }
teardown() {
    compose down -v --remove-orphans >/dev/null 2>&1 || true
    rm -rf "$work"
}
trap teardown EXIT

load_env
URL="http://127.0.0.1:${COUCHDB_LOCAL_PORT}"

echo "### up"
compose up -d --wait

echo; echo "### provision (first run)"
bash scripts/provision.sh
echo; echo "### provision (second run — must be idempotent)"
bash scripts/provision.sh

echo; echo "### verify --local"
bash scripts/verify.sh --local --url "$URL"

echo; echo "### device-user writes (a note doc + LiveSync's design doc)"
curl_auth_cfg USER_CFG "$VAULT_USER" "$VAULT_PASSWORD"
code="$(http_status -K "$USER_CFG" -X PUT -H 'Content-Type: application/json' \
    --data-binary '{"type":"plain","data":"hello"}' "$URL/$VAULT_DB/smoke-note")"
[ "$code" = "201" ] && ok "device user can write documents" || bad "writing a document returned HTTP $code"
code="$(http_status -K "$USER_CFG" -X PUT -H 'Content-Type: application/json' \
    --data-binary '{"views":{"collectDangling":{"map":"function(doc){emit(doc._id,1)}","reduce":"_sum"}}}' \
    "$URL/$VAULT_DB/_design/chunks")"
[ "$code" = "201" ] && ok "device user can write _design/chunks" || bad "writing _design/chunks returned HTTP $code"
code="$(http_status -K "$USER_CFG" -X PUT "$URL/other_db")"
[[ "$code" =~ ^40[13]$ ]] && ok "device user cannot create other databases (HTTP $code)" \
    || bad "device user created another database (HTTP $code)"
[ "$FAILED" -eq 0 ] || die "device-user checks failed"

echo; echo "### backup (with 4 older snapshots already present: the oldest must be pruned)"
mkdir -p "$BACKUP_DIR"
for d in 20200105 20200112 20200119 20200126; do
    echo old | gzip > "$BACKUP_DIR/couchdb-${d}-033000.tar.gz"
done
bash scripts/backup.sh
kept="$(find "$BACKUP_DIR" -maxdepth 1 -name 'couchdb-*.tar.gz' | wc -l | tr -d ' ')"
[ "$kept" = "4" ] && [ ! -e "$BACKUP_DIR/couchdb-20200105-033000.tar.gz" ] \
    && ok "pruning kept the newest 4 snapshots" \
    || bad "pruning left $kept snapshots (want 4, without the oldest)"
[ "$FAILED" -eq 0 ] || die "backup pruning check failed"

echo; echo "### restore-test"
bash scripts/restore-test.sh

echo
echo "Smoke test passed."
