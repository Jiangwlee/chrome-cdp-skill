#!/usr/bin/env bash
# This file provides shared helpers for the chrome-cdp google.com workflows.
# Input: shell arguments, environment variables, and cdp.mjs JSON/text output.
# Output: resolved target prefixes, encoded URLs, and wrapper calls to cdp.mjs.
# Public interface: require_cmd, url_encode, cdp_list_raw, cdp_eval,
# google_find_target, google_nav_fast, wait_for_url_contains,
# and wait_for_google_selector.
#
# google_find_target prefers an existing google.com/search tab, then any
# google.com tab, then falls back to the first available page tab.
# This lets the search script run without requiring a pre-opened Google tab.
# Failures are printed to stderr and exit non-zero.
# Source this file from sibling scripts; it is not intended to run directly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CDP_SCRIPT="${SCRIPT_DIR}/../../cdp.mjs"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'missing required command: %s\n' "$cmd" >&2
    exit 1
  fi
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

cdp_eval() {
  local target="$1"
  local expr="$2"
  cdp eval "$target" "$expr"
}

google_find_target() {
  local preferred="${1:-}"
  if [[ -n "$preferred" ]]; then
    printf '%s\n' "$preferred"
    return 0
  fi

  local pages
  pages="$(cdp_list_raw)"
  jq -r '
    map(select(.type == "page"))
    | (map(select(.url | test("^https://www\\.google\\.com/search"))) +
       map(select(.url | test("^https://www\\.google\\.com/"))) +
       .)
    | unique_by(.targetId)
    | .[0].targetId // empty
  ' <<<"$pages"
}

google_nav_fast() {
  local target="$1"
  local url="$2"
  local params
  params="$(jq -nc --arg url "$url" '{url: $url}')"
  cdp evalraw "$target" "Page.navigate" "$params" >/dev/null 2>&1 || true
}

wait_for_url_contains() {
  local target="$1"
  local needle="$2"
  local limit="${3:-10000}"
  local expr
  read -r -d '' expr <<'EOF' || true
(async () => {
  const deadline = Date.now() + LIMIT_MS;
  while (Date.now() < deadline) {
    if (location.href.includes(NEEDLE)) return location.href;
    await new Promise(resolve => setTimeout(resolve, 250));
  }
  throw new Error('Timed out waiting for URL match');
})()
EOF
  expr="${expr/LIMIT_MS/${limit}}"
  expr="${expr/NEEDLE/$(jq -Rn --arg v "$needle" '$v')}"
  cdp_eval "$target" "$expr" >/dev/null
}

wait_for_google_selector() {
  local target="$1"
  local selector="$2"
  local limit="${3:-15000}"
  local expr
  read -r -d '' expr <<'EOF' || true
(async () => {
  const deadline = Date.now() + LIMIT_MS;
  while (Date.now() < deadline) {
    if (document.querySelector(SELECTOR)) return 'READY';
    await new Promise(resolve => setTimeout(resolve, 300));
  }
  throw new Error('Timed out waiting for Google selector');
})()
EOF
  expr="${expr/LIMIT_MS/${limit}}"
  expr="${expr/SELECTOR/$(jq -Rn --arg v "$selector" '$v')}"
  cdp_eval "$target" "$expr" >/dev/null
}
