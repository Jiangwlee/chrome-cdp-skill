#!/usr/bin/env bash
# This script searches google.com and returns the top organic search results.
# Input: a query string, optional result limit, and optional target prefix.
# Output: a JSON array of search results with title, snippet, and URL.
# Public interface: google-search.sh <query> [limit] [target_prefix].
#
# The script reuses or falls back to any available Chrome tab.
# It navigates directly to https://www.google.com/search?q=<query>&num=20.
# It uses cdp nav (waits for Page.loadEventFired) to avoid a race condition
# where wait conditions match the old DOM before navigation completes.
# It waits for the organic results section (#rso) to appear before extracting.
# Extraction collects all #rso .MjjYud containers in a single eval call.
# Only result cards with an h3 title and a valid http(s) destination URL are kept.
# Featured snippets, ads, and map packs without h3 are silently skipped.
# The default limit is 20 and the hard cap is also 20.
# Snippet text is truncated to 280 characters.
# The script depends on jq and the sibling common.sh helpers.
# Errors are printed to stderr and the script exits non-zero.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

require_cmd jq

usage() {
  printf 'usage: %s <query> [limit] [target_prefix]\n' "$(basename "$0")" >&2
  exit 1
}

QUERY="${1:-}"
LIMIT="${2:-20}"
TARGET="${3:-}"

[[ -n "$QUERY" ]] || usage
[[ "$LIMIT" =~ ^[0-9]+$ ]] || { printf 'limit must be an integer\n' >&2; exit 1; }
(( LIMIT > 0 )) || { printf 'limit must be greater than zero\n' >&2; exit 1; }
(( LIMIT <= 20 )) || LIMIT=20

TARGET="$(google_find_target "$TARGET")"
[[ -n "$TARGET" ]] || { printf 'no usable browser tab found\n' >&2; exit 1; }

SEARCH_URL="https://www.google.com/search?q=$(url_encode "$QUERY")&num=20"
cdp nav "$TARGET" "$SEARCH_URL"
wait_for_google_selector "$TARGET" '#rso'

read -r -d '' EXPR <<'EOF' || true
(() => {
  const limit = LIMIT_VALUE;
  const results = [];

  for (const container of document.querySelectorAll('#rso .MjjYud')) {
    if (results.length >= limit) break;

    // Title: must have an h3
    const h3 = container.querySelector('h3');
    if (!h3) continue;
    const title = (h3.innerText || '').replace(/\s+/g, ' ').trim();
    if (!title) continue;

    // URL: walk up from h3 to find the nearest <a href="http..."> ancestor,
    // then fall back to any http link in the container.
    let url = '';
    let el = h3.parentElement;
    while (el && el !== container) {
      if (
        el.tagName === 'A' &&
        el.href &&
        /^https?:\/\//.test(el.href) &&
        !el.href.includes('google.com/search') &&
        !el.href.includes('google.com/url')
      ) {
        url = el.href;
        break;
      }
      el = el.parentElement;
    }
    if (!url) {
      const a = container.querySelector(
        'a[href^="http"]:not([href*="google.com/search"]):not([href*="google.com/url"])'
      );
      if (a) url = a.href;
    }
    if (!url) continue;

    // Snippet: try known Google snippet selectors in priority order
    let snippet = '';
    const snippetEl =
      container.querySelector('.VwiC3b') ||
      container.querySelector('.IsZvec') ||
      container.querySelector('[data-sncf]') ||
      container.querySelector('.lEBKkf');
    if (snippetEl) {
      snippet = (snippetEl.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 280);
    }

    results.push({ title, snippet, url });
  }

  return results;
})()
EOF
EXPR="${EXPR/LIMIT_VALUE/${LIMIT}}"

cdp_eval "$TARGET" "$EXPR"
