#!/usr/bin/env bash
# This file provides shared helpers for the chrome-cdp x.com workflow scripts.
# Input: shell arguments, environment variables, and cdp.mjs JSON/text output.
# Output: resolved target prefixes, encoded URLs, and wrapper calls to cdp.mjs.
# Public interface: require_cmd, x_find_target, cdp_list_raw, cdp_nav,
# cdp_eval, json_string, url_encode, and wait_for_x_article.
#
# The helpers keep x-search.sh and x-open-post.sh deterministic and small.
# They prefer the repository-local cdp.mjs entrypoint in the same skill.
# They select an existing usable X tab rather than opening a new one.
# They rely on jq for robust JSON parsing and URI encoding.
# They return plain strings or forward cdp.mjs output unchanged.
# Failures are reported to stderr and exit non-zero.
# Source this file from other scripts in this directory; it is not intended to
# be executed directly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CDP_SCRIPT="${SCRIPT_DIR}/cdp.mjs"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'missing required command: %s\n' "$cmd" >&2
    exit 1
  fi
}

json_string() {
  jq -Rn --arg v "$1" '$v'
}

url_encode() {
  jq -nr --arg v "$1" '$v|@uri'
}

cdp() {
  "$CDP_SCRIPT" "$@"
}

cdp_list_raw() {
  cdp list_raw
}

cdp_nav() {
  local target="$1"
  local url="$2"
  cdp nav "$target" "$url" >/dev/null
}

cdp_eval() {
  local target="$1"
  local expr="$2"
  cdp eval "$target" "$expr"
}

x_find_target() {
  local preferred="${1:-}"
  if [[ -n "$preferred" ]]; then
    printf '%s\n' "$preferred"
    return 0
  fi

  local pages
  pages="$(cdp_list_raw)"
  jq -r '
    map(select(.type == "page"))
    | map(select(.url | test("^https://x\\.com/")))
    | map(select(.url | test("^https://x\\.com/account/access") | not))
    | (map(select(.url | test("^https://x\\.com/home(\\?|$)"))) +
       map(select(.url | test("^https://x\\.com/search\\?"))) +
       map(select(.url | test("^https://x\\.com/.+/status/[0-9]+"))) +
       .)
    | unique_by(.targetId)
    | .[0].targetId // empty
  ' <<<"$pages"
}

wait_for_x_article() {
  local target="$1"
  local limit="${2:-10000}"
  local expr
  read -r -d '' expr <<'EOF' || true
(async () => {
  const deadline = Date.now() + LIMIT_MS;
  while (Date.now() < deadline) {
    if (document.querySelector('article')) return 'READY';
    await new Promise(resolve => setTimeout(resolve, 250));
  }
  throw new Error('Timed out waiting for x.com article content');
})()
EOF
  expr="${expr/LIMIT_MS/${limit}}"
  cdp_eval "$target" "$expr" >/dev/null
}
