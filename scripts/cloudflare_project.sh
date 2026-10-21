#!/usr/bin/env bash
# ------------------------------------------------------------------
# Makes sure the Cloudflare Pages project for this book exists (and,
# if DOMAIN is set, its custom domain + DNS record), and
# reports its address. Safe to run on every build.
#
# Needs: CLOUDFLARE_API_TOKEN, NAME
# Optional: DOMAIN (also publish at NAME.DOMAIN)
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

# Each project records which repo created it (variable BOOK_REPO), so a
# second book that happens to pick the same name can't publish over it.
REPO="${GITHUB_REPOSITORY:-}"
[ -n "$REPO" ] || fail "GITHUB_REPOSITORY not set."
owner_of() { echo "$1" | jq -r '.result.deployment_configs.production.env_vars.BOOK_REPO.value // empty'; }
proj=$(CF_ALLOW_404=1 cf GET "/accounts/$ACC/pages/projects/$NAME")
if ! echo "$proj" | jq -e '.success == true' >/dev/null 2>&1; then
  echo "Creating Pages project '$NAME'…" >&2
  cf POST "/accounts/$ACC/pages/projects" \
    "$(jq -n --arg n "$NAME" --arg r "$REPO" '{name: $n, production_branch: "main",
       deployment_configs: {production: {env_vars: {BOOK_REPO: {type: "plain_text", value: $r}}},
                            preview:    {env_vars: {BOOK_REPO: {type: "plain_text", value: $r}}}}}')" >/dev/null
  proj=$(cf GET "/accounts/$ACC/pages/projects/$NAME")
  [ "$(owner_of "$proj")" = "$REPO" ] || fail "Created project '$NAME' but couldn't record its owner (BOOK_REPO). Please report this; not publishing."
else
  owner=$(owner_of "$proj")
  if [ "$owner" != "$REPO" ]; then
    fail "A Cloudflare Pages project called '$NAME' already exists${owner:+ and belongs to $owner}. To avoid publishing over another book, pick a different short-name in publishing.yml. (If it really is this book, set the variable BOOK_REPO = $REPO under Workers & Pages → $NAME → Settings → Variables and secrets.)"
  fi
fi
SUB=$(echo "$proj" | jq -r '.result.subdomain // empty')
[ -n "$SUB" ] || SUB="$NAME.pages.dev"
output pages_host "$SUB"

# --- Optional custom domain ----------------------------------------
if [ -n "${DOMAIN:-}" ]; then
  HOST="$NAME.$DOMAIN"
  ZONE=$(cf GET "/zones?name=$DOMAIN" | jq -r '.result[0].id // empty')
  [ -n "$ZONE" ] || fail "Couldn't find $DOMAIN on this Cloudflare account. Check 'domain:' in publishing.yml."

  # Don't take over an address another book (or anything else) already uses.
  recs=$(cf GET "/zones/$ZONE/dns_records?name=$HOST")
  if [ "$(echo "$recs" | jq '.result | length')" != 0 ]; then
    target=$(echo "$recs" | jq -r '.result[0].content')
    [ "$target" = "$SUB" ] || fail "$HOST already points somewhere else ($target), maybe another book. Pick a different short-name in publishing.yml."
  fi

  doms=$(cf GET "/accounts/$ACC/pages/projects/$NAME/domains")
  if ! echo "$doms" | jq -e --arg h "$HOST" '.result[] | select(.name == $h)' >/dev/null; then
    echo "Adding custom domain $HOST…" >&2
    cf POST "/accounts/$ACC/pages/projects/$NAME/domains" "$(jq -n --arg h "$HOST" '{name: $h}')" >/dev/null
  fi
  if [ "$(echo "$recs" | jq '.result | length')" = 0 ]; then
    echo "Adding DNS record $HOST → $SUB…" >&2
    cf POST "/zones/$ZONE/dns_records" "$(jq -n --arg h "$HOST" --arg s "$SUB" \
      '{type: "CNAME", name: $h, content: $s, proxied: true, ttl: 1, comment: "Pages custom domain (added by book publish workflow)"}')" >/dev/null
  fi
  output custom_host "$HOST"
fi
