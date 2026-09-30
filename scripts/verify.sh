#!/usr/bin/env bash
# =============================================================================
# verify.sh — end-to-end check of the sync endpoint, as a device sees it.
#
# Run from any computer on the tailnet (e.g. your laptop) after `make serve-on`.
#
#   bash scripts/verify.sh                  # https://$TS_HOSTNAME:$TS_HTTPS_PORT
#   bash scripts/verify.sh --url URL        # another endpoint
#   bash scripts/verify.sh --local --url http://127.0.0.1:5984
#                                           # skip TLS + exposure checks (smoke test)
#
# Checks
#   1. /_up answers over HTTPS with a certificate the OS trusts (no -k).
#   2. Anonymous requests to the vault database are refused (401).
#   3. The device user (VAULT_USER) can open the vault database.
#   4. CORS answers for Obsidian desktop (app://obsidian.md) and mobile
#      (capacitor://localhost), with credentials allowed.
#   5. There is no plain-HTTP path: TS_HOSTNAME:COUCHDB_LOCAL_PORT is closed.
# =============================================================================
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LOCAL=0
URL=""
while [ $# -gt 0 ]; do
    case "$1" in
        --local) LOCAL=1 ;;
        --url)   URL="${2:?--url needs a value}"; shift ;;
        -h|--help) awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;;
        *) die "Unknown option: $1 (see --help)" ;;
    esac
    shift
done

load_env
URL="${URL:-https://${TS_HOSTNAME}:${TS_HTTPS_PORT}}"
URL="${URL%/}"
curl_auth_cfg USER_CFG "$VAULT_USER" "$VAULT_PASSWORD"

echo "=== Verifying ${URL} (database ${VAULT_DB}, user ${VAULT_USER}) ==="

# 1. Reachable, with a trusted certificate.
body="$(curl -s --max-time 15 "$URL/_up" || true)"
if [[ "$body" == *'"status":"ok"'* ]]; then
    ok "/_up answers$([ "$LOCAL" -eq 0 ] && echo ' over HTTPS with a trusted certificate')"
else
    bad "/_up did not answer (TLS error, serve off, or container down). Got: ${body:-no response}"
fi
if [ "$LOCAL" -eq 0 ] && command -v openssl >/dev/null; then
    host_port="${URL#https://}"
    info="$(echo | openssl s_client -connect "$host_port" -servername "${host_port%:*}" 2>/dev/null \
        | openssl x509 -noout -issuer -enddate 2>/dev/null | tr '\n' ' ' || true)"
    [ -n "$info" ] && echo "        cert: $info"
fi

# 2. Anonymous refused.
code="$(http_status "$URL/$VAULT_DB")"
[ "$code" = "401" ] && ok "anonymous access refused (401)" || bad "anonymous access returned HTTP $code (want 401)"

# 3. Device user can open the vault.
info="$(curl -s --max-time 15 -K "$USER_CFG" "$URL/$VAULT_DB" || true)"
count="$(json_field doc_count <<<"$info" 2>/dev/null || true)"
if [[ "$count" =~ ^[0-9]+$ ]]; then
    ok "$VAULT_USER can open $VAULT_DB ($count documents)"
else
    bad "$VAULT_USER could not open $VAULT_DB: ${info:-no response}"
fi

# 4. CORS for desktop and mobile Obsidian.
for origin in "app://obsidian.md" "capacitor://localhost"; do
    headers="$(curl -s -o /dev/null -D - --max-time 15 -X OPTIONS \
        -H "Origin: $origin" \
        -H 'Access-Control-Request-Method: PUT' \
        -H 'Access-Control-Request-Headers: authorization,content-type' \
        "$URL/$VAULT_DB" | tr -d '\r' || true)"
    allow="$(grep -i '^access-control-allow-origin:' <<<"$headers" | cut -d' ' -f2- || true)"
    creds="$(grep -i '^access-control-allow-credentials:' <<<"$headers" | cut -d' ' -f2- || true)"
    if [ "$allow" = "$origin" ] && [ "$creds" = "true" ]; then
        ok "CORS preflight allows $origin with credentials"
    else
        bad "CORS preflight for $origin: allow-origin='${allow}', allow-credentials='${creds}'"
    fi
done

# 5. No plain-HTTP path to CouchDB from the tailnet.
if [ "$LOCAL" -eq 0 ] && [ -n "${TS_HOSTNAME:-}" ]; then
    port="${COUCHDB_LOCAL_PORT:-5984}"
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://${TS_HOSTNAME}:${port}/" || true)"
    [ "$code" = "000" ] && ok "no plain-HTTP path: ${TS_HOSTNAME}:${port} is closed" \
        || bad "${TS_HOSTNAME}:${port} answered HTTP $code — CouchDB is exposed beyond loopback"
fi

echo
[ "$FAILED" -eq 0 ] && echo "All checks passed." || die "Some checks failed."
