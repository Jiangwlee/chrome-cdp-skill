# chrome-cdp-skill

`chrome-cdp-skill` is a fork-based SOP skill platform built on top of Chrome CDP.

Instead of only exposing a low-level browser control tool, this repository packages a reusable `chrome-cdp` skill, a growing set of site-specific SOP workflows, and ready-to-use pi agents that compose those workflows into end-user tasks. The current first-party workflows target:

- `reddit.com`
- `tgb.cn` / Taoguba
- `x.com`

The long-term direction is to keep the browser integration layer stable, expand support to more websites, and ship agents that let users invoke complex multi-step workflows with a single command.

## Project Model

This repository is organized around three layers:

- `skill`
  The `chrome-cdp` skill: shared CDP primitives, site-specific SOP scripts, workflow references, and a test harness. This is the browser layer that all agents depend on.
- `agents`
  Pi agent definitions that compose the skill into end-user workflows. Each agent is a system prompt that drives `pi` to execute one focused task using the skill's scripts.
- `bin`
  The `pi-cdp` project CLI. The single entry point for installing and removing the skill and agents on a local machine.

## Target Layout

```text
chrome-cdp-skill/
  bin/
    pi-cdp                ← project CLI (install / remove / help)
  skills/
    chrome-cdp/
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
  agents/
    link-reader.md        ← summarize a single X or Reddit URL
    web-researcher.md     ← multi-round research on a topic
    stock-analyst.md      ← Taoguba market analysis
    bin/
      pi-read-link        ← CLI wrapper
      pi-research         ← CLI wrapper
      pi-stock-report     ← CLI wrapper
```

## What This Repository Includes

- A Chrome CDP CLI for deterministic access to a live Chrome-family browser session.
- Site-specific SOP scripts for repeatable extraction and navigation workflows.
- Workflow references that document how each supported site should be handled.
- Pi agent definitions that drive end-user workflows on top of the skill.
- A project CLI (`bin/pi-cdp`) for installing and removing the skill and agents.

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

### Full install (skill + agents + wrappers)

```bash
git clone git@github.com:Jiangwlee/chrome-cdp-skill.git
cd chrome-cdp-skill
./bin/pi-cdp install
```

This installs:
- the `chrome-cdp` skill to `~/.agents/skills/chrome-cdp/`
- agent definitions to `~/.pi/agent/agents/`
- CLI wrappers to `~/.local/bin/`

### Skill only (as a pi skill via pi package manager)

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
- Ship the three first-party agents: `link-reader`, `web-researcher`, `stock-analyst`.
- Ship `bin/pi-cdp` with `install`, `remove`, and `help` subcommands.
