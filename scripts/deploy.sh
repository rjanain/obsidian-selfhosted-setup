#!/usr/bin/env bash
# =============================================================================
# deploy.sh — push this repo to your server over SSH (files only, never restarts).
#
# Optional: you can also `git clone` the repo on the server instead.
#
#   ./scripts/deploy.sh --init --env    # first deploy: create REMOTE_DIR, send files + .env
#   ./scripts/deploy.sh                 # routine deploy (files only)
#   ./scripts/deploy.sh --env           # also copy .env (only when secrets changed)
#   ./scripts/deploy.sh --dry-run       # preview the rsync, change nothing
#
# Then apply on the server:  ssh <user>@<host> 'cd /opt/obsidian-livesync && make up'
#
# Isolation from anything else on the server
#   - Writes only inside REMOTE_DIR (default /opt/obsidian-livesync).
#   - Refuses any REMOTE_DIR that is not an absolute path ending in
#     /obsidian-livesync.
#   - Before the --delete rsync, checks that REMOTE_DIR already holds THIS
#     project (docker-compose.yml with `name: obsidian-livesync`), so a wrong
#     path can never be wiped.
#   - Never touches Docker, Tailscale, or other directories.
#
# Always excluded: .git, .env (sent only with --env via scp, mode 600), backups/.
#
# Overridable via environment (defaults from .env):
#   DEPLOY_USER (deploy)   DEPLOY_HOST (required)   REMOTE_DIR (/opt/obsidian-livesync)
# =============================================================================
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO_ROOT"

SEND_ENV=0; FIRST_TIME=0; DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --env|-e)     SEND_ENV=1 ;;
        --init|-i)    FIRST_TIME=1 ;;
        --dry-run|-n) DRY_RUN=1 ;;
        -h|--help)    awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;;
        *)            die "Unknown option: $arg (see --help)" ;;
    esac
done

_pre_user="${DEPLOY_USER:-}"; _pre_host="${DEPLOY_HOST:-}"; _pre_dir="${REMOTE_DIR:-}"
load_env
DEPLOY_USER="${_pre_user:-${DEPLOY_USER:-deploy}}"
DEPLOY_HOST="${_pre_host:-${DEPLOY_HOST:-}}"
REMOTE_DIR="${_pre_dir:-${REMOTE_DIR:-/opt/obsidian-livesync}}"
REMOTE_DIR="${REMOTE_DIR%/}"
[ -n "$DEPLOY_HOST" ] || die "DEPLOY_HOST is empty (set it in .env)."

case "$REMOTE_DIR" in
    /*/obsidian-livesync) ;;
    *) die "Refusing REMOTE_DIR=$REMOTE_DIR — it must be an absolute path ending in /obsidian-livesync." ;;
esac
case "$REMOTE_DIR" in
    *"'"*|*..*) die "Refusing REMOTE_DIR=$REMOTE_DIR — no quotes or '..' allowed." ;;
esac

TARGET="${DEPLOY_USER}@${DEPLOY_HOST}"
MARKER='^name: obsidian-livesync$'

echo "=== Deploy to ${TARGET}:${REMOTE_DIR} ==="
echo "  .env:  $([ "$SEND_ENV" -eq 1 ] && echo 'yes (scp, mode 600)' || echo 'no')"
echo "  init:  $([ "$FIRST_TIME" -eq 1 ] && echo 'yes (create REMOTE_DIR)' || echo 'no')"
echo "  mode:  $([ "$DRY_RUN" -eq 1 ] && echo 'DRY RUN — nothing changes' || echo 'live')"
echo

# 1. Make sure REMOTE_DIR is ours (or create it on --init).
remote_state="$(ssh -o BatchMode=yes "$TARGET" "
    if [ ! -e '$REMOTE_DIR' ]; then echo missing
    elif [ -z \"\$(ls -A '$REMOTE_DIR' 2>/dev/null)\" ]; then echo empty
    elif grep -qE '$MARKER' '$REMOTE_DIR/docker-compose.yml' 2>/dev/null; then echo ours
    else echo foreign; fi")"

case "$remote_state" in
    ours)    ;;
    foreign) die "$REMOTE_DIR exists on the server but is not this project. Nothing was changed." ;;
    missing|empty)
        [ "$FIRST_TIME" -eq 1 ] || die "$REMOTE_DIR is $remote_state on the server — run with --init for the first deploy."
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "(dry run) would create $REMOTE_DIR owned by $DEPLOY_USER"
            echo "Dry run complete — the rsync preview needs REMOTE_DIR to exist, so it was skipped."
            exit 0
        fi
        echo "=== Creating $REMOTE_DIR (owner $DEPLOY_USER) ==="
        ssh "$TARGET" "sudo install -d -o '$DEPLOY_USER' -g \"\$(id -gn)\" -m 755 '$REMOTE_DIR'"
        ;;
    *) die "Could not inspect $REMOTE_DIR on the server (got '$remote_state')." ;;
esac

# 2. Sync files. --chmod makes the read-only CouchDB ini world-readable (644)
#    whatever the local filesystem reports; scripts are run via `bash`.
# shellcheck disable=SC2054  # the comma is rsync's own --chmod syntax
RSYNC_OPTS=(-avz --delete --chmod=D755,F644)
[ "$DRY_RUN" -eq 1 ] && RSYNC_OPTS+=(--dry-run)
rsync "${RSYNC_OPTS[@]}" \
    --exclude='.git' --exclude='.github' --exclude='.env' --exclude='backups' \
    --exclude='.DS_Store' --exclude='._*' \
    ./ "${TARGET}:${REMOTE_DIR}/"

if [ "$DRY_RUN" -eq 1 ]; then
    echo
    echo "Dry run complete — no files changed, .env not sent."
    exit 0
fi

# 3. .env only when asked, outside the --delete rsync, private to deploy.
if [ "$SEND_ENV" -eq 1 ]; then
    echo
    echo "=== Copying .env (mode 600) ==="
    scp -q .env "${TARGET}:${REMOTE_DIR}/.env"
    ssh "$TARGET" "chmod 600 '$REMOTE_DIR/.env'"
fi

echo
echo "Done. Files are on ${TARGET}:${REMOTE_DIR}."
echo "Next: ssh ${TARGET} 'cd ${REMOTE_DIR} && make up && make provision'"
