#!/usr/bin/env bash
# =============================================================================
# backup.sh — snapshot CouchDB's data + config volumes to BACKUP_DIR (server).
#
#   bash scripts/backup.sh              # one snapshot now, then prune old ones
#
# Runs weekly from the systemd timer in deploy/systemd/ (make install-backup-timer),
# and keeps the newest BACKUP_KEEP snapshots (4 = the last four weeks).
# CouchDB's files are append-only, so copying them while it runs is safe; a
# snapshot is a gzip tar of /opt/couchdb/data and /opt/couchdb/etc/local.d,
# streamed out of the running container (no extra image needed).
#
# The snapshot holds E2EE-encrypted chunks: restoring needs this server's
# CouchDB, and reading notes needs your LiveSync passphrase.
#
# Environment (from .env): BACKUP_DIR, BACKUP_KEEP (4), COUCHDB_CONTAINER
# =============================================================================
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in -h|--help) awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;; esac

load_env
BACKUP_DIR="${BACKUP_DIR:-$REPO_ROOT/backups}"
KEEP="${BACKUP_KEEP:-4}"
CONTAINER="${COUCHDB_CONTAINER:-obsidian_couchdb}"
[[ "$KEEP" =~ ^[1-9][0-9]*$ ]] || die "BACKUP_KEEP must be a whole number of snapshots, 1 or more (got '$KEEP')."

docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true \
    || die "Container $CONTAINER is not running."

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
ts="$(date +%Y%m%d-%H%M%S)"
out="$BACKUP_DIR/couchdb-${ts}.tar.gz"
tmp="$out.partial"

docker exec "$CONTAINER" tar czf - -C /opt/couchdb data etc/local.d > "$tmp"
gzip -t "$tmp" || { rm -f "$tmp"; die "Snapshot is corrupt; removed it."; }
mv "$tmp" "$out"
chmod 600 "$out"
echo "Saved: $out ($(du -h "$out" | cut -f1))"

# Keep the newest $KEEP. Names are timestamps, so name order is age order.
pruned=0
while IFS= read -r old; do
    rm -f -- "$old"
    pruned=$((pruned + 1))
done < <(find "$BACKUP_DIR" -maxdepth 1 -name 'couchdb-*.tar.gz' | sort -r | tail -n +"$((KEEP + 1))")
echo "Kept the newest $KEEP snapshot(s); pruned $pruned older one(s)."
