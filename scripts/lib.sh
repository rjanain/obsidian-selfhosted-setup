#!/usr/bin/env bash
# =============================================================================
# lib.sh — shared helpers, sourced by the other scripts (not run directly).
# =============================================================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die()  { echo "!! $*" >&2; exit 1; }
ok()   { echo "  ok    $*"; }
bad()  { echo "  FAIL  $*" >&2; FAILED=1; }
# shellcheck disable=SC2034  # read by the scripts that source this file
FAILED=0

# Load .env from the repo root, or ENV_FILE if set (the smoke test uses a
# throwaway one).
load_env() {
    local f="${ENV_FILE:-$REPO_ROOT/.env}"
    [ -f "$f" ] || die "No env file at $f — cp .env.example .env and fill it in."
    set -a
    # shellcheck disable=SC1090
    . "$f"
    set +a
}

# Credentials go to curl through a private config file, never on the command
# line, so they don't show up in `ps`.
_CURL_CFG_FILES=()
_cleanup_curl_cfgs() { [ ${#_CURL_CFG_FILES[@]} -eq 0 ] || rm -f "${_CURL_CFG_FILES[@]}"; }
trap _cleanup_curl_cfgs EXIT

# curl_auth_cfg VAR USER PASSWORD — writes a 0600 curl config file and stores
# its path in VAR. (Not called as $(...): the cleanup list must live in this shell.)
curl_auth_cfg() {
    local __var="$1" u="$2" p="$3" f
    f="$(mktemp)"
    chmod 600 "$f"
    u="${u//\\/\\\\}"; u="${u//\"/\\\"}"
    p="${p//\\/\\\\}"; p="${p//\"/\\\"}"
    printf 'user = "%s:%s"\n' "$u" "$p" > "$f"
    _CURL_CFG_FILES+=("$f")
    printf -v "$__var" '%s' "$f"
}

# http_status [curl args...] → prints only the HTTP status code (000 = no connection).
http_status() {
    curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$@" || true
}

# json_body VALUE... — build small JSON documents without shell-quoting bugs.
json_user_doc() {  # name password [rev]
    python3 - "$@" <<'PY'
import json, sys
name, password = sys.argv[1], sys.argv[2]
doc = {"_id": f"org.couchdb.user:{name}", "name": name, "password": password,
       "roles": [], "type": "user"}
if len(sys.argv) > 3 and sys.argv[3]:
    doc["_rev"] = sys.argv[3]
print(json.dumps(doc))
PY
}

json_security_doc() {  # name
    python3 - "$1" <<'PY'
import json, sys
n = sys.argv[1]
print(json.dumps({"admins": {"names": [n], "roles": []},
                  "members": {"names": [n], "roles": []}}))
PY
}

json_field() {  # field  (reads JSON on stdin)
    python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1], ""))' "$1"
}
