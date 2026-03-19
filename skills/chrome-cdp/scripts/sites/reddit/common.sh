#!/usr/bin/env bash
# This file provides shared helpers for the chrome-cdp reddit.com workflows.
# Input: shell arguments, environment variables, and cdp.mjs JSON/text output.
# Output: resolved target prefixes, encoded URLs, and wrapper calls to cdp.mjs.
# Public interface: require_cmd, url_encode, cdp_list_raw, cdp_eval,
# cdp_evalraw, reddit_find_target, reddit_nav_fast, wait_for_url_contains,
# wait_for_reddit_selector, and wait_for_reddit_text.
#
# The helpers keep search.sh and open-post.sh deterministic.
# They reuse an existing Reddit tab instead of opening a new browser tab.
# They use Page.navigate via evalraw because Reddit often keeps background
# activity alive after navigation even when the visible page is already ready.
# They rely on jq for JSON handling and URL encoding.
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

cdp_evalraw() {
  local target="$1"
  shift
  cdp evalraw "$target" "$@" >/dev/null
}

reddit_find_target() {
  local preferred="${1:-}"
  if [[ -n "$preferred" ]]; then
    printf '%s\n' "$preferred"
    return 0
  fi

  local pages
  pages="$(cdp_list_raw)"
  jq -r '
    map(select(.type == "page"))
    | map(select(.url | test("^https://www\\.reddit\\.com/")))
    | (map(select(.url | test("^https://www\\.reddit\\.com/search"))) +
       map(select(.url | test("^https://www\\.reddit\\.com/r/[^/]+/comments/"))) +
       .)
    | unique_by(.targetId)
    | .[0].targetId // empty
  ' <<<"$pages"
}

reddit_nav_fast() {
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

wait_for_reddit_selector() {
  local target="$1"
  local selector="$2"
  local limit="${3:-12000}"
  local expr
  read -r -d '' expr <<'EOF' || true
(async () => {
  const deadline = Date.now() + LIMIT_MS;
  while (Date.now() < deadline) {
    if (document.querySelector(SELECTOR)) return 'READY';
    await new Promise(resolve => setTimeout(resolve, 250));
  }
  throw new Error('Timed out waiting for Reddit selector');
})()
EOF
  expr="${expr/LIMIT_MS/${limit}}"
  expr="${expr/SELECTOR/$(jq -Rn --arg v "$selector" '$v')}"
  cdp_eval "$target" "$expr" >/dev/null
}

wait_for_reddit_text() {
  local target="$1"
  local needle="$2"
  local limit="${3:-12000}"
  local expr
  read -r -d '' expr <<'EOF' || true
(async () => {
  const deadline = Date.now() + LIMIT_MS;
  while (Date.now() < deadline) {
    if ((document.body?.innerText || '').includes(NEEDLE)) return 'READY';
    await new Promise(resolve => setTimeout(resolve, 250));
  }
  throw new Error('Timed out waiting for Reddit text');
})()
EOF
  expr="${expr/LIMIT_MS/${limit}}"
  expr="${expr/NEEDLE/$(jq -Rn --arg v "$needle" '$v')}"
  cdp_eval "$target" "$expr" >/dev/null
}
