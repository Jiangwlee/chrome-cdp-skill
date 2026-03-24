# AGENTS.md

This repository is maintained as a personal fork-based workspace and developed as a SOP skill platform built on top of Chrome CDP.

## Repository Setup

- Local path: `/home/bruce/Projects/chrome-cdp-skill`
- Fork remote: `origin = git@github.com:Jiangwlee/chrome-cdp-skill.git`
- Upstream remote: `upstream = https://github.com/pasky/chrome-cdp-skill.git`

## Project Positioning

This repository is a three-layer platform: skill, agents, and a project CLI.

- `skill` — the `chrome-cdp` skill: CDP primitives, site SOP scripts, workflow references, and tests. The browser layer. All agents depend on it.
- `agents` — pi agent definitions. Each agent is a system prompt that drives `pi` to execute one focused user-facing task using the skill's scripts.
- `bin` — the `pi-cdp` project CLI: the single entry point for installing and removing the skill and agents on a local machine.

## Branch Strategy

- `main` tracks the fork's `origin/main` and should stay close to upstream.
- `bruce/custom` is the long-lived branch for personalized development.
- Feature work should normally branch from `bruce/custom`, unless there is a clear reason to work directly on it.

## Sync Workflow

Update local `main` from upstream:

```bash
git checkout main
git fetch upstream
git rebase upstream/main
git push origin main
```

Rebase personalized work onto the updated `main`:

```bash
git checkout bruce/custom
git rebase main
git push --force-with-lease origin bruce/custom
```

## Repository Rules

- Do not repoint `origin` away from the personal fork.
- Do not remove `upstream`.
- Do not force-push `main` unless explicitly requested.
- Before any risky history rewrite, create a backup branch.

## SOPs

Process documents for recurring workflows:

- [docs/sop/brainstorming.md](docs/sop/brainstorming.md)
  需求头脑风暴：先主动调查（读代码、查页面），再提聚焦业务的问题，最后写设计摘要确认后实现。
- [docs/sop/chrome-cdp-skill-dev.md](docs/sop/chrome-cdp-skill-dev.md)
  Chrome CDP Skill 开发：文件创建顺序、DOM 优先原则、canvas 页面处理、就绪等待模式、输出 schema 要求。
- [docs/sop/pi-agent-dev.md](docs/sop/pi-agent-dev.md)
  Pi Agent 开发：agent 定义文件格式、system prompt 结构、输出模板约束机制、CLI wrapper 标准模板、安装注册流程、完成标准清单。

## Engineering Rules

### Skill layer

- Prefer keeping general CDP behavior in the core layer instead of site-specific scripts.
- When adding a new site, add all of the following in the same change:
  - site scripts
  - site references
  - site tests
  - unified test-runner registration
- New site support is incomplete if it cannot be exercised by `skills/chrome-cdp/scripts/test.mjs`.
- Keep naming consistent with the site key used in scripts, references, tests, and test-runner registration.
- Keep `skills/chrome-cdp/scripts/cdp.mjs` in place as the stable forked core entrypoint.
- During the directory refactor, preserve working links and script entrypoints where possible until all references are updated.
- Prefer adding smoke tests that execute real workflow scripts and validate output structure, while marking missing browser prerequisites as setup issues rather than parser regressions.

### Agent layer

- An agent is a system prompt. Keep it focused on one user-facing task.
- All browser operations must go through the chrome-cdp skill's shell scripts invoked via `bash`. Do not write new browser scripts inside the agent layer.
- If a workflow requires a new browser capability, add the script to the skill layer first, then reference it from the agent.
- Agent `.md` files follow the pi subagent frontmatter convention: `name`, `description`, `tools`, `model`. This keeps them compatible with both direct CLI invocation and the pi subagent extension.
- Declare the minimal tool set. Most agents only need `bash` and `read`.
- Enforce behavioral constraints through output template structure, not instructions alone. An agent that must complete ten research rounds should require the agent to fill a numbered template before writing a conclusion.
- When adding a new agent, add all of the following in the same change:
  - agent definition (`agents/<name>.md`)
  - CLI wrapper (`agents/bin/pi-<name>`)
  - entry in `bin/pi-cdp` install/remove tables

### Project CLI

- `bin/pi-cdp` is the single entry point for local setup. Keep install and remove symmetric.
- Install targets:
  - skill → `~/.agents/skills/chrome-cdp/` (symlink)
  - agent definitions → `~/.pi/agent/agents/<name>.md` (symlink)
  - CLI wrappers → `~/.local/bin/pi-<name>` (symlink)
- Prefer symlinks over copies so edits in the repo take effect immediately without re-running install.

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
    wps-assistant.md      ← answer questions from WPS 365 documents
    bin/
      pi-read-link        ← CLI wrapper for link-reader
      pi-research         ← CLI wrapper for web-researcher
      pi-stock-report     ← CLI wrapper for stock-analyst
      pi-wps              ← CLI wrapper for wps-assistant
```
