#!/usr/bin/env bash
# =============================================================================
# restore-test.sh — prove a snapshot restores, without touching the live DB.
#
#   bash scripts/restore-test.sh                    # newest snapshot in BACKUP_DIR
#   bash scripts/restore-test.sh path/to/couchdb-YYYYmmdd-HHMMSS.tar.gz
#
# Unpacks the snapshot into a temp dir, boots a throwaway CouchDB on
# 127.0.0.1:${RESTORE_TEST_PORT:-15984}, and checks that the vault database
# opens with the device user and holds documents. The live container, its
# volumes and the tailnet endpoint are never touched. Cleans up afterwards.
# =============================================================================
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in -h|--help) awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;; esac

load_env
BACKUP_DIR="${BACKUP_DIR:-$REPO_ROOT/backups}"
PORT="${RESTORE_TEST_PORT:-15984}"
NAME="obsidian_restore_test"
IMAGE="$(awk '/image: couchdb:/{print $2; exit}' "$REPO_ROOT/docker-compose.yml")"

# Snapshot names are timestamps, so the last one by name is the newest.
snap="${1:-$(find "$BACKUP_DIR" -maxdepth 1 -name 'couchdb-*.tar.gz' 2>/dev/null | sort | tail -1 || true)}"
[ -n "$snap" ] && [ -f "$snap" ] || die "No snapshot found (looked in $BACKUP_DIR). Run make backup first."

work="$(mktemp -d)"
cleanup() {
    docker rm -f "$NAME" >/dev/null 2>&1 || true
    # Files are owned by CouchDB's uid after boot; remove them from inside a container.
    docker run --rm -v "$work:/w" --entrypoint sh "$IMAGE" -c 'rm -rf /w/* /w/.[!.]*' >/dev/null 2>&1 || true
    rmdir "$work" 2>/dev/null || true
    _cleanup_curl_cfgs
}
trap cleanup EXIT

echo "=== Restore test: $(basename "$snap") → throwaway CouchDB on 127.0.0.1:$PORT ==="
tar xzf "$snap" -C "$work"
[ -d "$work/data" ] && [ -d "$work/etc/local.d" ] || die "Snapshot does not contain data/ and etc/local.d/."

docker run -d --name "$NAME" -p "127.0.0.1:$PORT:5984" \
    -e COUCHDB_USER -e COUCHDB_PASSWORD \
    -v "$work/data:/opt/couchdb/data" \
    -v "$work/etc/local.d:/opt/couchdb/etc/local.d" \
    -v "$REPO_ROOT/couchdb/livesync.ini:/livesync/livesync.ini:ro" \
    --entrypoint tini "$IMAGE" -- sh -c \
    'cp /livesync/livesync.ini /opt/couchdb/etc/default.d/90-livesync.ini && exec /docker-entrypoint.sh /opt/couchdb/bin/couchdb' \
    >/dev/null

URL="http://127.0.0.1:$PORT"
for i in $(seq 1 30); do
    [ "$(http_status "$URL/_up")" = "200" ] && break
    [ "$i" -eq 30 ] && die "Restored CouchDB did not come up. Logs: docker logs $NAME"
    sleep 2
done
ok "restored CouchDB is up"

curl_auth_cfg USER_CFG "$VAULT_USER" "$VAULT_PASSWORD"
info="$(curl -s --max-time 15 -K "$USER_CFG" "$URL/$VAULT_DB")"
count="$(json_field doc_count <<<"$info")"
if [[ "$count" =~ ^[0-9]+$ ]]; then
    ok "$VAULT_USER opens $VAULT_DB in the restore: $count documents"
    [ "$count" -gt 0 ] || bad "$VAULT_DB is empty in this snapshot"
else
    bad "$VAULT_USER could not open $VAULT_DB in the restore: $info"
fi

echo
[ "$FAILED" -eq 0 ] && echo "Restore test passed." || die "Restore test failed."
