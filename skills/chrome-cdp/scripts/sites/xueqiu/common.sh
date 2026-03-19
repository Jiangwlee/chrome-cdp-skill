#!/usr/bin/env bash
# Shared helpers for the chrome-cdp xueqiu.com workflow scripts.
# Input: shell arguments plus cdp.mjs JSON/text output from a local browser tab.
# Output: resolved target prefixes, encoded URLs, normalized URLs, and waits.
# Public interface: require_cmd, url_encode, json_string, normalize_xueqiu_url,
# cdp_list_raw, cdp_eval, cdp_eval_retry, cdp_evalraw, xueqiu_find_target,
# xueqiu_nav_fast, wait_for_url_contains, wait_for_xueqiu_selector, and
# wait_for_xueqiu_text.
#
# The helpers keep site scripts deterministic and aligned with the repository's
# common shell conventions. They reuse an existing Xueqiu tab rather than
# opening a new one, and they prefer Page.navigate for faster SPA transitions.

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

json_string() {
  jq -Rn --arg v "$1" '$v'
}

url_encode() {
  jq -nr --arg v "$1" '$v|@uri'
}

normalize_xueqiu_url() {
  jq -nr --arg href "$1" '
    ($href | if test("^https?://") then . else "https://xueqiu.com" + . end)
    | sub("\\?.*$"; "")
    | sub("#.*$"; "")
  '
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

cdp_eval_retry() {
  local target="$1"
  local expr="$2"
  local attempts="${3:-24}"
  local delay="${4:-0.25}"
  local output=''
  local i

  for ((i = 0; i < attempts; i += 1)); do
    if output="$(cdp eval "$target" "$expr" 2>&1)"; then
      printf '%s\n' "$output"
      return 0
    fi
    if grep -qiE 'Inspected target navigated or closed|Cannot find context|Execution context was destroyed' <<<"$output"; then
      sleep "$delay"
      continue
    fi
    printf '%s\n' "$output" >&2
    return 1
  done

  printf '%s\n' "$output" >&2
  return 1
}

cdp_evalraw() {
  local target="$1"
  shift
  cdp evalraw "$target" "$@" >/dev/null
}

xueqiu_find_target() {
  local preferred="${1:-}"
  if [[ -n "$preferred" ]]; then
    printf '%s\n' "$preferred"
    return 0
  fi

  local pages
  pages="$(cdp_list_raw)"
  jq -r '
    map(select(.type == "page"))
    | map(select(.url | test("^https://xueqiu\\.com/")))
    | map(select(.url | test("/snowman/logout") | not))
    | (map(select(.url | test("^https://xueqiu\\.com/(\\?|$|#)"))) +
       map(select(.url | test("^https://xueqiu\\.com/k\\?"))) +
       map(select(.url | test("^https://xueqiu\\.com/[A-Za-z0-9_]+/[0-9]+"))) +
       map(select(.url | test("^https://xueqiu\\.com/[0-9]+/[0-9]+"))) +
       .)
    | unique_by(.targetId)
    | .[0].targetId // empty
  ' <<<"$pages"
}

xueqiu_nav_fast() {
  local target="$1"
  local url="$2"
  local expr
  expr="$(printf 'location.href = %s; "NAVIGATING"' "$(json_string "$url")")"
  cdp_eval "$target" "$expr" >/dev/null || true
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
  throw new Error('Timed out waiting for Xueqiu URL match');
})()
EOF
  expr="${expr/LIMIT_MS/${limit}}"
  expr="${expr/NEEDLE/$(jq -Rn --arg v "$needle" '$v')}"
  cdp_eval_retry "$target" "$expr" >/dev/null
}

wait_for_xueqiu_selector() {
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
  throw new Error('Timed out waiting for Xueqiu selector');
})()
EOF
  expr="${expr/LIMIT_MS/${limit}}"
  expr="${expr/SELECTOR/$(jq -Rn --arg v "$selector" '$v')}"
  cdp_eval_retry "$target" "$expr" >/dev/null
}

wait_for_xueqiu_text() {
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
  throw new Error('Timed out waiting for Xueqiu text');
})()
EOF
  expr="${expr/LIMIT_MS/${limit}}"
  expr="${expr/NEEDLE/$(jq -Rn --arg v "$needle" '$v')}"
  cdp_eval_retry "$target" "$expr" >/dev/null
}
