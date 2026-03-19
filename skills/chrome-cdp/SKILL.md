---
name: chrome-cdp
description: Interact with local Chrome browser session (only on explicit user approval after being asked to inspect, debug, or interact with a page open in Chrome)
---

# Chrome CDP

Use this skill when you need deterministic access to a local Chrome-family browser tab through the DevTools Protocol without Puppeteer.

## Quick start

- Confirm Chrome remote debugging is enabled at `chrome://inspect/#remote-debugging`.
- Use `scripts/cdp.mjs list` to identify the target tab prefix.
- Use `nav` for stable page transitions and `eval` only for page-specific extraction or interaction.
- Read [references/index.md](references/index.md) before using advanced commands or debugging connection issues.

## When to load references

- For command selection and common workflows, read [references/index.md](references/index.md).
- For command semantics and examples, read [references/cli-reference.md](references/cli-reference.md).
- For connection failures, stale `DevToolsActivePort`, or approval prompts, read [references/troubleshooting.md](references/troubleshooting.md).
- For repeatable `x.com` search and post-extraction workflows, read [references/x-workflows.md](references/x-workflows.md).
- For repeatable `reddit.com` search and post-plus-comments extraction workflows, read [references/reddit-workflows.md](references/reddit-workflows.md).
- For repeatable `tgb.cn` / Taoguba workflows, read [references/taoguba-workflows.md](references/taoguba-workflows.md).
- For the workflow used to develop new SOPs for this skill, read [references/sop-development.md](references/sop-development.md).

## Core rules

- The `<target>` argument is a unique `targetId` prefix from `scripts/cdp.mjs list`.
- Prefer `nav` over click-driven navigation when a stable URL is known.
- Prefer one `eval` that collects all needed data over multiple DOM-indexed `eval` calls.
- Use `type` instead of `eval` for text entry in cross-origin iframes.
- Expect one Chrome "Allow debugging" prompt per tab daemon on first access.

## Main entrypoint

All browser actions route through [scripts/cdp.mjs](scripts/cdp.mjs).

## Bundled workflow scripts

- `scripts/x-search.sh`
  Search `x.com` with the default result page and extract up to 10 result summaries.
- `scripts/x-open-post.sh`
  Open one `x.com` post URL and extract the current visible post text.
- `scripts/reddit-search.sh`
  Search `reddit.com` and extract up to 10 result summaries.
- `scripts/reddit-open-post.sh`
  Open one Reddit post URL and extract the main post plus top visible comments.
- `scripts/taoguba-jinghua.sh`
  Extract Taoguba `jinghua` posts from the last 24 hours by default.
- `scripts/taoguba-following.sh`
  Extract followed-content updates from the last 12 hours by default.
- `scripts/taoguba-open-post.sh`
  Open one Taoguba post and extract the main post body.
