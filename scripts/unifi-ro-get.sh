#!/usr/bin/env bash
# Read-only UniFi Network fetcher for local LLM use.
# Only sends GET requests to known read endpoints. Never POST/PUT/DELETE.
# The LLM never holds credentials. The user logs in once, and the script
# reuses that session cookie jar. Credentials below are only needed when
# the script itself must (re)login.
#
#   User login (password stays in the user's shell only):
#   curl -sk -c /tmp/unifi.jar -X POST "https://192.168.0.1/api/auth/login" \
#     -H "Content-Type: application/json" \
#     -d '{"username":"llm-viewer","password":"..."}'
#   chmod 600 /tmp/unifi.jar
#
#   LLM usage (no credentials needed):
#   ./scripts/unifi-ro-get.sh "stat/device"
#
#   Overrides: UNIFI_HOST, UNIFI_SITE, UNIFI_JAR.
#   UNIFI_USER / UNIFI_PASS (or `op read`) only if the script must log in.
set -euo pipefail

UNIFI_HOST="${UNIFI_HOST:-https://192.168.0.1}"
UNIFI_SITE="${UNIFI_SITE:-default}"

JAR="${UNIFI_JAR:-/tmp/unifi.jar}"
PATH_ARG="${1:-stat/device}"
# Strip a leading slash so both "stat/device" and "/stat/device" work.
PATH_ARG="${PATH_ARG#/}"

# Allowlist: read-only Network API surfaces only.
if [[ ! "$PATH_ARG" =~ ^(stat|list|get)/[A-Za-z0-9_./-]+$ ]]; then
  echo "refusing: path must start with stat/, list/ or get/" >&2
  exit 2
fi
if [[ "$PATH_ARG" =~ (^|/)\.\.(/|$) ]]; then
  echo "refusing: no path traversal" >&2
  exit 2
fi

login() {
  if [[ -z "${UNIFI_USER:-}" || -z "${UNIFI_PASS:-}" ]]; then
    echo "no usable session in $JAR and no UNIFI_USER/UNIFI_PASS to log in." >&2
    echo "ask the user to refresh the login, e.g.:" >&2
    echo "  curl -sk -c $JAR -X POST \"$UNIFI_HOST/api/auth/login\" \\" >&2
    echo '    -H "Content-Type: application/json" \' >&2
    echo '    -d '"'"'{"username":"llm-viewer","password":"..."}'"'"'' >&2
    exit 3
  fi
  rm -f "$JAR"
  (
    umask 077
    curl -sk --max-time 15 -c "$JAR" -X POST "$UNIFI_HOST/api/auth/login" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg u "$UNIFI_USER" --arg p "$UNIFI_PASS" \
        '{username: $u, password: $p}')" > /dev/null
  )
  chmod 600 "$JAR" 2> /dev/null || true
}

# Fresh login if we have no session cookie yet.
if [[ ! -s "$JAR" ]]; then
  login
fi

URL="$UNIFI_HOST/proxy/network/api/s/$UNIFI_SITE/$PATH_ARG"
CODE="$(curl -sk --max-time 20 -b "$JAR" -o /tmp/unifi-ro-body.json -w "%{http_code}" "$URL")"

# One retry with a fresh login on auth expiry.
if [[ "$CODE" == "401" ]]; then
  login
  CODE="$(curl -sk --max-time 20 -b "$JAR" -o /tmp/unifi-ro-body.json -w "%{http_code}" "$URL")"
fi

if [[ "$CODE" != "200" ]]; then
  echo "request failed: HTTP $CODE" >&2
  head -c 300 /tmp/unifi-ro-body.json >&2 || true
  echo >&2
  exit 1
fi
cat /tmp/unifi-ro-body.json
