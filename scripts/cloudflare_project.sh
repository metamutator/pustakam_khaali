#!/usr/bin/env bash
# ------------------------------------------------------------------
# Makes sure the Cloudflare Pages project for this book exists, and
# reports its address. Safe to run on every build.
#
# Needs: CLOUDFLARE_API_TOKEN, NAME
# Optional: CLOUDFLARE_ACCOUNT_ID (looked up from the token if blank)
# ------------------------------------------------------------------
set -euo pipefail

API="${CF_API:-https://api.cloudflare.com/client/v4}"

fail() { echo "::error::$*" >&2; exit 1; }
output() { if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "$1=$2" >> "$GITHUB_OUTPUT"; fi; echo "$1=$2" >&2; }

[ -n "${CLOUDFLARE_API_TOKEN:-}" ] || fail "The CLOUDFLARE_API_TOKEN secret is missing. Add it under Settings → Secrets and variables → Actions, then re-run."
: "${NAME:?NAME not set}"

cf() {
  local method="$1" path="$2" data="${3:-}" status body tmp
  tmp="$(mktemp)"
  if [ -n "$data" ]; then
    status=$(curl -sS -o "$tmp" -w '%{http_code}' -X "$method" "$API$path" \
      -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" --data "$data")
  else
    status=$(curl -sS -o "$tmp" -w '%{http_code}' -X "$method" "$API$path" \
      -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN")
  fi
  body="$(cat "$tmp")"; rm -f "$tmp"
  if [ "${CF_ALLOW_404:-0}" = 1 ] && [ "$status" = 404 ]; then echo "$body"; return 0; fi
  if ! echo "$body" | jq -e '.success == true' >/dev/null 2>&1; then
    local msg; msg=$(echo "$body" | jq -r '[.errors[]? | "\(.code): \(.message)"] | join("; ")' 2>/dev/null || true)
    [ "$status" = 403 ] && msg="$msg (the API token is probably missing a permission; see README)"
    fail "Cloudflare API $method $path failed (HTTP $status): ${msg:-$body}"
  fi
  echo "$body"
}

ACC="${CLOUDFLARE_ACCOUNT_ID:-}"
if [ -z "$ACC" ]; then
  ACC=$(cf GET "/accounts" | jq -r '.result | if length == 1 then .[0].id else "" end')
  [ -n "$ACC" ] || fail "Couldn't tell which Cloudflare account to use. Add a CLOUDFLARE_ACCOUNT_ID secret (shown on the Workers & Pages overview page)."
fi
output account_id "$ACC"

proj=$(CF_ALLOW_404=1 cf GET "/accounts/$ACC/pages/projects/$NAME")
if ! echo "$proj" | jq -e '.success == true' >/dev/null 2>&1; then
  echo "Creating Pages project '$NAME'…" >&2
  proj=$(cf POST "/accounts/$ACC/pages/projects" \
    "$(jq -n --arg n "$NAME" '{name: $n, production_branch: "main"}')")
fi
SUB=$(echo "$proj" | jq -r '.result.subdomain // empty')
[ -n "$SUB" ] || SUB="$NAME.pages.dev"
output pages_host "$SUB"
