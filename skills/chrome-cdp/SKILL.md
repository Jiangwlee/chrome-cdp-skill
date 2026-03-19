---
name: chrome-cdp
description: Use Chrome CDP as a reusable browser core for site-specific SOP workflows, with explicit approval before interacting with a live local browser session
---

# Chrome CDP

Use this skill when you need deterministic access to a local Chrome-family browser tab through the DevTools Protocol and when a site-specific SOP in this repository should run on top of that browser connection.

This skill is no longer just a thin browser utility. It is the core browser layer for a growing SOP skill platform.

## Skill Model

Treat this skill as two layers:

- `core`
  Chrome connection, tab targeting, navigation, extraction primitives, and SOP development guidance.
- `sites`
  Repeatable workflows for specific websites such as `reddit.com`, `tgb.cn`, and `x.com`.

The repository is being refactored toward a `core + sites + tests` layout. Until that migration is complete, some files still live in the legacy flat `scripts/` and `references/` directories.

## Quick Start

- Confirm Chrome remote debugging is enabled at `chrome://inspect/#remote-debugging`.
- Use `scripts/cdp.mjs list` to identify the target tab prefix.
- Prefer stable URL navigation when a workflow can avoid brittle click paths.
- Load the relevant core or site reference before running a non-trivial workflow.

## When To Load References

Load core references for shared browser behavior:

- [references/core/index.md](references/core/index.md)
  Command selection and common workflow guidance.
- [references/core/cli-reference.md](references/core/cli-reference.md)
  CLI semantics and examples.
- [references/core/troubleshooting.md](references/core/troubleshooting.md)
  Connection failures, stale `DevToolsActivePort`, and approval-prompt issues.
- [references/core/sop-development.md](references/core/sop-development.md)
  The SOP development process used in this repository.

Load site references for website-specific workflows:

- [references/sites/reddit/workflows.md](references/sites/reddit/workflows.md)
  `reddit.com` search and post-plus-comments workflows.
- [references/sites/taoguba/workflows.md](references/sites/taoguba/workflows.md)
  `tgb.cn` / Taoguba workflow guidance.
- [references/sites/x/workflows.md](references/sites/x/workflows.md)
  `x.com` search and post-extraction workflows.

## Core Rules

- The `<target>` argument is a unique `targetId` prefix from `scripts/cdp.mjs list`.
- Prefer `nav` over click-driven navigation when a stable URL is known.
- Prefer one `eval` that collects all needed data over multiple DOM-indexed `eval` calls.
- Use `type` instead of `eval` for text entry in cross-origin iframes.
- Expect one Chrome "Allow debugging" prompt per tab daemon on first access.
- Keep browser primitives in the core layer. Do not bury general CDP logic inside a site-specific workflow unless the behavior is truly site-bound.

## Main Entrypoint

All browser actions currently route through [scripts/cdp.mjs](scripts/cdp.mjs).

This file stays in place as the stable forked core entrypoint while site workflows move into per-site subdirectories.

## Current Site Workflow Scripts

### Reddit

- `scripts/sites/reddit/search.sh`
  Search `reddit.com` and extract up to 10 result summaries.
- `scripts/sites/reddit/open-post.sh`
  Open one Reddit post URL and extract the main post plus top visible comments.

### Taoguba

- `scripts/sites/taoguba/jinghua.sh`
  Extract Taoguba `jinghua` posts from the last 24 hours by default.
- `scripts/sites/taoguba/following.sh`
  Extract followed-content updates from the last 12 hours by default.
- `scripts/sites/taoguba/open-post.sh`
  Open one Taoguba post and extract the main post body.

### X

- `scripts/sites/x/search.sh`
  Search `x.com` and extract up to 10 result summaries.
- `scripts/sites/x/open-post.sh`
  Open one `x.com` post URL and extract the current visible post text.

## Expected Future Structure

Each supported site should eventually have:

- scripts under `scripts/sites/<site>/`
- references under `references/sites/<site>/`
- tests under `tests/sites/<site>/`

The unified validation entrypoint will be `scripts/test.mjs`.

Current test commands:

- `node scripts/test.mjs list`
- `node scripts/test.mjs core`
- `node scripts/test.mjs site reddit`
- `node scripts/test.mjs site taoguba`
- `node scripts/test.mjs site x`
- `node scripts/test.mjs all`

## Definition Of Done For New Site Support

New site support is not complete unless it includes:

- workflow scripts
- a site reference document
- at least one smoke test
- registration in the unified test runner
