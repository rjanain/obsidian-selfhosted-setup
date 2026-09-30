#!/usr/bin/env bash
# =============================================================================
# tailscale-serve.sh — publish CouchDB on the tailnet over HTTPS (server only).
#
#   bash scripts/tailscale-serve.sh on       # https://$TS_HOSTNAME:$TS_HTTPS_PORT → 127.0.0.1:$COUCHDB_LOCAL_PORT
#   bash scripts/tailscale-serve.sh off      # remove only this project's handler
#   bash scripts/tailscale-serve.sh status
#
# Safety
#   - Only ever calls `tailscale serve`. It never runs `tailscale up`, which
#     can reset flags the host was brought up with (--ssh, --advertise-exit-node…).
#   - Refuses a port that is already taken, by another `tailscale serve`
#     handler or by any other listener (e.g. a web server on 443).
#   - Refuses to start until tailnet HTTPS certificates are enabled
#     (admin console → DNS → HTTPS Certificates), because mobile Obsidian
#     rejects anything but a trusted certificate.
#   - The serve config persists across reboots; `off` removes it.
# =============================================================================
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

load_env
PORT="${TS_HTTPS_PORT:-6984}"
TARGET="http://127.0.0.1:${COUCHDB_LOCAL_PORT:-5984}"
command -v tailscale >/dev/null || die "tailscale is not installed here — run this on the server."

SUDO=""
[ "$(id -u)" -eq 0 ] || SUDO="sudo"

cert_domains() {
    tailscale status --json | python3 -c 'import json,sys; print(" ".join(json.load(sys.stdin).get("CertDomains") or []))'
}

# serve_targets — what the existing serve config sends PORT to (space-separated),
# or nothing if PORT isn't served yet.
serve_targets() {
    $SUDO tailscale serve status --json 2>/dev/null | python3 -c '
import json, sys
port = sys.argv[1]
try:
    cfg = json.load(sys.stdin) or {}
except ValueError:
    cfg = {}
tcp = (cfg.get("TCP") or {}).get(port)
if tcp is None:
    sys.exit(0)
targets = set()
for hostport, web in (cfg.get("Web") or {}).items():
    if hostport.rsplit(":", 1)[-1] == port:
        for h in (web.get("Handlers") or {}).values():
            targets.add(h.get("Proxy") or h.get("Path") or "(static text)")
if tcp.get("TCPForward"):
    targets.add("tcp://" + tcp["TCPForward"])
print(" ".join(sorted(targets)) or "(unknown)")
' "$PORT"
}

case "${1:-status}" in
    on)
        domains="$(cert_domains)"
        [ -n "$domains" ] || die "Tailnet HTTPS certificates are not enabled.
   Enable them: https://login.tailscale.com/admin/dns → HTTPS Certificates → Enable.
   (The machine name then appears in public Certificate Transparency logs.)"
        [[ " $domains " == *" ${TS_HOSTNAME} "* ]] \
            || die "Certificates cover '$domains', not TS_HOSTNAME='${TS_HOSTNAME}'. Fix TS_HOSTNAME in .env."
        [ "$(http_status "$TARGET/_up")" = "200" ] || die "CouchDB is not answering on $TARGET — run 'make up' first."
        current="$(serve_targets || true)"
        if [ -n "$current" ] && [ "$current" != "$TARGET" ]; then
            die "Port $PORT already serves: $current. Pick another TS_HTTPS_PORT in .env."
        fi
        if [ -z "$current" ] && command -v ss >/dev/null && [ -n "$(ss -Hltn "sport = :$PORT")" ]; then
            die "Something on this machine already listens on :$PORT. Pick another TS_HTTPS_PORT in .env."
        fi
        echo "=== Serving ${TARGET} at https://${TS_HOSTNAME}:${PORT} (tailnet only) ==="
        $SUDO tailscale serve --bg --https="$PORT" "$TARGET"
        tailscale serve status
        ;;
    off)
        echo "=== Removing the :${PORT} handler (other serve config is left alone) ==="
        $SUDO tailscale serve --https="$PORT" off
        tailscale serve status || true
        ;;
    status)
        tailscale serve status
        echo
        echo "CertDomains: $(cert_domains || echo '(unknown)')"
        ;;
    -h|--help)
        awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0" ;;
    *)
        die "Usage: $0 on|off|status" ;;
esac
