#!/usr/bin/env bash
# This file provides shared helpers for the chrome-cdp Taoguba workflows.
# Input: shell arguments, environment variables, and cdp.mjs JSON/text output.
# Output: resolved target prefixes, encoded URLs, and wrapper calls to cdp.mjs.
# Public interface: require_cmd, cdp_list_raw, cdp_eval, taoguba_find_target,
# taoguba_nav_fast, wait_for_url_contains, wait_for_taoguba_text, and
# wait_for_taoguba_selector.
#
# The helpers keep Taoguba workflow scripts small and deterministic.
# They reuse an existing Taoguba tab instead of opening a new browser tab.
# They use Page.navigate but tolerate timeout noise from pages that continue
# background loading after the visible content is already ready.
# They rely on jq for JSON handling.
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

taoguba_find_target() {
  local preferred="${1:-}"
  local pattern="${2:-}"
  if [[ -n "$preferred" ]]; then
    printf '%s\n' "$preferred"
    return 0
  fi

  local pages
  pages="$(cdp_list_raw)"
  jq -r --arg pattern "$pattern" '
    map(select(.type == "page"))
    | map(select(.url | test("^https://www\\.tgb\\.cn/")))
    | if $pattern != "" then
        (map(select(.url | test($pattern))) + .)
      else .
      end
    | unique_by(.targetId)
    | .[0].targetId // empty
  ' <<<"$pages"
}

taoguba_nav_fast() {
  local target="$1"
  local url="$2"
  local params
  params="$(jq -nc --arg url "$url" '{url: $url}')"
  cdp evalraw "$target" "Page.navigate" "$params" >/dev/null 2>&1 || true
}

wait_for_url_contains() {
  local target="$1"
  local needle="$2"
  local limit="${3:-12000}"
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

wait_for_taoguba_text() {
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
  throw new Error('Timed out waiting for Taoguba text');
})()
EOF
  expr="${expr/LIMIT_MS/${limit}}"
  expr="${expr/NEEDLE/$(jq -Rn --arg v "$needle" '$v')}"
  cdp_eval "$target" "$expr" >/dev/null
}

wait_for_taoguba_selector() {
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
  throw new Error('Timed out waiting for Taoguba selector');
})()
EOF
  expr="${expr/LIMIT_MS/${limit}}"
  expr="${expr/SELECTOR/$(jq -Rn --arg v "$selector" '$v')}"
  cdp_eval "$target" "$expr" >/dev/null
}
