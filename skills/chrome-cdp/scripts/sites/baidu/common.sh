#!/usr/bin/env bash
# This file provides shared helpers for the chrome-cdp baidu.com workflows.
# Input: shell arguments, environment variables, and cdp.mjs JSON/text output.
# Output: resolved target prefixes, encoded URLs, and wrapper calls to cdp.mjs.
# Public interface: require_cmd, url_encode, cdp_list_raw, cdp_eval,
# baidu_find_target, wait_for_url_contains, and wait_for_baidu_selector.
#
# baidu_find_target prefers an existing baidu.com/s tab, then any
# baidu.com tab, then falls back to the first available page tab.
# This lets the search script run without requiring a pre-opened Baidu tab.
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

baidu_find_target() {
  local preferred="${1:-}"
  if [[ -n "$preferred" ]]; then
    printf '%s\n' "$preferred"
    return 0
  fi

  local pages
  pages="$(cdp_list_raw)"
  jq -r '
    map(select(.type == "page"))
    | (map(select(.url | test("^https://www\\.baidu\\.com/s"))) +
       map(select(.url | test("^https://www\\.baidu\\.com/"))) +
       .)
    | unique_by(.targetId)
    | .[0].targetId // empty
  ' <<<"$pages"
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

wait_for_baidu_selector() {
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
  throw new Error('Timed out waiting for Baidu selector');
})()
EOF
  expr="${expr/LIMIT_MS/${limit}}"
  expr="${expr/SELECTOR/$(jq -Rn --arg v "$selector" '$v')}"
  cdp_eval "$target" "$expr" >/dev/null
}
