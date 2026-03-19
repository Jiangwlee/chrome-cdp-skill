#!/usr/bin/env bash
# This script searches x.com using the default search results page.
# Input: a query string, optional result limit, and optional target prefix.
# Output: a JSON array of search result summaries with post URLs.
# Public interface: x-search.sh <query> [limit] [target_prefix].
#
# The script reuses an existing x.com tab discovered through cdp.mjs.
# It navigates directly to the default search URL rather than clicking UI.
# It waits for result articles to load before extracting content.
# Extraction keeps only unique post URLs and ignores analytics links.
# The output fields are author, handle, time_hint, summary, and url.
# The default limit is 10 and the hard cap is also 10.
# Summary text is the visible page summary, not the full post text.
# The script depends on jq and the sibling x-cdp-common.sh helpers.
# Errors are printed to stderr and the script exits non-zero.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./x-cdp-common.sh
source "${SCRIPT_DIR}/x-cdp-common.sh"

require_cmd jq

usage() {
  printf 'usage: %s <query> [limit] [target_prefix]\n' "$(basename "$0")" >&2
  exit 1
}

QUERY="${1:-}"
LIMIT="${2:-10}"
TARGET="${3:-}"

[[ -n "$QUERY" ]] || usage
[[ "$LIMIT" =~ ^[0-9]+$ ]] || { printf 'limit must be an integer\n' >&2; exit 1; }
(( LIMIT > 0 )) || { printf 'limit must be greater than zero\n' >&2; exit 1; }
(( LIMIT <= 10 )) || LIMIT=10

TARGET="$(x_find_target "$TARGET")"
[[ -n "$TARGET" ]] || { printf 'no usable x.com tab found\n' >&2; exit 1; }

SEARCH_URL="https://x.com/search?q=$(url_encode "$QUERY")"
cdp_nav "$TARGET" "$SEARCH_URL"
wait_for_x_article "$TARGET"

read -r -d '' EXPR <<'EOF' || true
(() => {
  const limit = LIMIT_VALUE;
  const rawTextOf = (node) => (node?.innerText || '').replace(/\u00A0/g, ' ').trim();
  const flatTextOf = (node) => rawTextOf(node).replace(/\s+/g, ' ').trim();
  const result = [];
  const seen = new Set();
  for (const article of document.querySelectorAll('article')) {
    const links = [...article.querySelectorAll('a[href]')].map(a => a.getAttribute('href') || '');
    const statusHref = links.find(href => /^\/[^/]+\/status\/\d+$/.test(href));
    if (!statusHref) continue;
    const url = 'https://x.com' + statusHref;
    if (seen.has(url)) continue;
    seen.add(url);

    const handleHref = links.find(href => /^\/[A-Za-z0-9_]{1,15}$/.test(href));
    const timeNode = article.querySelector('time');
    const blocks = rawTextOf(article).split(/\n+/).map(s => s.trim()).filter(Boolean);
    const handle = handleHref ? handleHref.slice(1) : '';
    const summary = blocks
      .find(line =>
        line !== (blocks[0] || '') &&
        line !== handle &&
        line !== '@' + handle &&
        !/^(@[A-Za-z0-9_]{1,15}|Replying to|Show more|Show original|Show translation|Promoted|Ad)$/i.test(line) &&
        line.length >= 16 &&
        !/^\d+[smhdwy]$/.test(line)
      ) || flatTextOf(article);

    result.push({
      author: blocks.find(line => line !== handle && line !== '@' + handle) || '',
      handle: handle ? '@' + handle : '',
      time_hint: timeNode ? timeNode.getAttribute('datetime') || flatTextOf(timeNode) : '',
      summary: summary.replace(/\s+/g, ' ').slice(0, 280),
      url
    });
    if (result.length >= limit) break;
  }
  return result;
})()
EOF
EXPR="${EXPR/LIMIT_VALUE/${LIMIT}}"

cdp_eval "$TARGET" "$EXPR"
