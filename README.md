# chrome-cdp-skill

`chrome-cdp-skill` is a fork-based SOP skill platform built on top of Chrome CDP.

Instead of only exposing a low-level browser control tool, this repository packages a reusable `chrome-cdp` skill plus a growing set of site-specific SOP workflows. The current first-party workflows target:

- `reddit.com`
- `tgb.cn` / Taoguba
- `x.com`

The long-term direction is to keep the browser integration layer stable and expand support to more websites by adding new workflow modules, references, and tests.

## Project Model

This repository is organized around a `core + sites` model:

- `core`
  Shared Chrome CDP primitives, browser connection behavior, and general SOP development guidance.
- `sites`
  Website-specific workflow scripts and references built on top of the core browser layer.
- `tests`
  A test harness for smoke and workflow validation so agents can periodically run checks and repair broken skills.

The current codebase still contains some legacy flat layout from the original upstream project. The target layout is:

```text
skills/chrome-cdp/
  SKILL.md
  scripts/
    cdp.mjs
    sites/
    test.mjs
  references/
    core/
    sites/
  tests/
    core/
    sites/
```

## What This Repository Includes

- A Chrome CDP CLI for deterministic access to a live Chrome-family browser session.
- Site-specific SOP scripts for repeatable extraction and navigation workflows.
- Workflow references that document how each supported site should be handled.
- Repository rules for maintaining a personal fork while staying close to upstream.

## Current Supported Workflows

Core browser access currently routes through `skills/chrome-cdp/scripts/cdp.mjs`.

Bundled workflow scripts currently include:

- `skills/chrome-cdp/scripts/sites/reddit/search.sh`
- `skills/chrome-cdp/scripts/sites/reddit/open-post.sh`
- `skills/chrome-cdp/scripts/sites/taoguba/jinghua.sh`
- `skills/chrome-cdp/scripts/sites/taoguba/following.sh`
- `skills/chrome-cdp/scripts/sites/taoguba/open-post.sh`
- `skills/chrome-cdp/scripts/sites/x/search.sh`
- `skills/chrome-cdp/scripts/sites/x/open-post.sh`

These now live in per-site subdirectories under `skills/chrome-cdp/scripts/sites/`.

## Installation

### As a pi skill

```bash
pi install git:github.com/Jiangwlee/chrome-cdp-skill
```

### For other agents

Clone or copy the `skills/chrome-cdp/` directory wherever your agent loads skills or context from. The only runtime dependency is Node.js 22+.

### Enable remote debugging in Chrome

Navigate to `chrome://inspect/#remote-debugging` and enable remote debugging.

The CLI auto-detects Chrome, Chromium, Brave, Edge, and Vivaldi on macOS, Linux, and Windows. If your browser stores `DevToolsActivePort` in a non-standard location, set `CDP_PORT_FILE` to the full path.

## Direction For New Site Support

Each new supported website should add all of the following:

- site scripts
- site references
- site tests
- `scripts/test.mjs` integration

New site support is not considered complete unless it can be exercised by the unified test runner.

## Test Runner

Use the unified runner under `skills/chrome-cdp/scripts/test.mjs`.

```bash
node skills/chrome-cdp/scripts/test.mjs list
node skills/chrome-cdp/scripts/test.mjs core
node skills/chrome-cdp/scripts/test.mjs site reddit
node skills/chrome-cdp/scripts/test.mjs site taoguba
node skills/chrome-cdp/scripts/test.mjs site x
node skills/chrome-cdp/scripts/test.mjs all
```

Optional flags:

- `--json`
- `--fail-fast`

Optional environment overrides:

- `CDP_TEST_REDDIT_QUERY`
- `CDP_TEST_X_QUERY`
- `CDP_TEST_TAOGUBA_HOURS`
- `CDP_TEST_TAOGUBA_LIMIT`

## Why This Fork Exists

The upstream project is a strong base for live Chrome CDP access. This fork extends it into a maintained SOP skill workspace with:

- opinionated website workflows
- structured references for agents
- a testable maintenance loop for detecting broken site automations

## Near-Term Roadmap

- Keep `scripts/cdp.mjs` stable and refactor site scripts and references into per-site subdirectories.
- Add smoke tests for `core`, `reddit`, `taoguba`, and `x`.
