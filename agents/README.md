# Agents

> English README | [中文文档](README.zh.md)

This directory contains pi agent definitions that compose the `chrome-cdp` skill into end-user workflows.

## What Is an Agent

An agent is a pi invocation with three components:

- **System prompt** — the `.md` file in this directory. Defines the agent's role, workflow, tool usage, and output format.
- **Tool set** — declared in the frontmatter. Most agents only need `bash` (to run skill scripts) and `read` (to consult skill references).
- **Skill** — the `chrome-cdp` skill provides all browser access. Agents do not contain browser scripts; they invoke the skill's shell scripts via `bash`.

Agents do not require the pi subagent extension. They are invoked directly via the pi CLI.

## Directory Layout

```text
agents/
  link-reader.md        ← summarize a single X or Reddit URL
  web-researcher.md     ← multi-round research on a topic
  stock-analyst.md      ← Taoguba market analysis
  bin/
    pi-read-link        ← CLI wrapper for link-reader
    pi-research         ← CLI wrapper for web-researcher
    pi-stock-report     ← CLI wrapper for stock-analyst
```

## Agent File Format

Agent files follow the pi subagent frontmatter convention so they remain compatible with both direct CLI invocation and the pi subagent extension.

```markdown
---
name: my-agent
description: One sentence describing what this agent does.
tools: bash, read
model: claude-sonnet-4-6
---

System prompt content goes here.
```

| Frontmatter field | Required | Notes |
|---|---|---|
| `name` | yes | Matches the filename without `.md` |
| `description` | yes | Used by the subagent extension to select agents |
| `tools` | yes | Declare the minimal set. Most agents: `bash, read` |
| `model` | yes | Prefer `claude-sonnet-4-6` for research tasks |

## CLI Wrappers

Each agent has a corresponding wrapper script in `agents/bin/`. A wrapper is a thin shell script that calls pi with the correct flags:

```bash
#!/usr/bin/env bash
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)/skills/chrome-cdp"
AGENT_FILE="$(cd "$(dirname "$0")/.." && pwd)/my-agent.md"

exec pi --no-session --print \
        --skill "$SKILL_DIR" \
        --tools bash,read \
        --system-prompt "$(tail -n +6 "$AGENT_FILE")" \
        "$@"
```

Wrappers are installed to `~/.local/bin/` by `bin/pi-cdp install`.

## Skill Script Reference

Agents invoke skill scripts via `bash`. All scripts are under `skills/chrome-cdp/scripts/sites/`.

| Script | Inputs | Output |
|---|---|---|
| `x/search.sh <query>` | search query | JSON array: `author`, `handle`, `time_hint`, `summary`, `url` |
| `x/open-post.sh <url>` | post URL | JSON object: `author`, `handle`, `time`, `text`, `url` |
| `reddit/search.sh <query>` | search query | JSON array: `title`, `subreddit`, `time_hint`, `summary`, `url` |
| `reddit/open-post.sh <url>` | post URL | JSON object: `title`, `subreddit`, `author`, `time`, `text`, `url`, `comments` |
| `taoguba/jinghua.sh` | optional hours, limit | JSON array of recent jinghua posts |
| `taoguba/following.sh` | optional hours, limit | JSON array of followed-content updates |
| `taoguba/open-post.sh <url>` | post URL | JSON object: `title`, `author`, `time`, `stats`, `text`, `url` |

The agent must locate the skill directory at runtime. Wrappers pass `SKILL_DIR` via environment or the agent prompt includes the installed path `~/.agents/skills/chrome-cdp/`.

## Development Workflow

### 1. Write the system prompt

Create `agents/<name>.md` with frontmatter and a focused system prompt. Include:
- A clear statement of the agent's single responsibility.
- Which skill scripts to use and how.
- A structured output template the agent must fill before concluding. This is the primary mechanism for enforcing behavioral constraints such as minimum iteration counts.

### 2. Test locally

```bash
pi --no-session --print \
   --skill skills/chrome-cdp \
   --tools bash,read \
   --system-prompt "$(tail -n +6 agents/<name>.md)" \
   "your test input"
```

Chrome must be running with remote debugging enabled. Run `node skills/chrome-cdp/scripts/cdp.mjs list` to confirm a usable tab is available.

### 3. Iterate on the prompt

Common failure modes:
- Agent uses wrong script path → add absolute path guidance to prompt.
- Agent exits too early → tighten the output template structure.
- Agent ignores one platform → make the template require entries per platform.

### 4. Create the CLI wrapper

Add `agents/bin/pi-<name>` following the wrapper pattern above. Make it executable:

```bash
chmod +x agents/bin/pi-<name>
```

### 5. Register in pi-cdp

Add the agent and wrapper to the install/remove tables in `bin/pi-cdp`.

### 6. Commit everything together

A complete agent addition includes:
- `agents/<name>.md`
- `agents/bin/pi-<name>`
- updated `bin/pi-cdp` install/remove tables

## First-Party Agents

| Agent | File | Wrapper | Task |
|---|---|---|---|
| link-reader | `link-reader.md` | `pi-read-link` | Read one X or Reddit URL and return a structured summary |
| web-researcher | `web-researcher.md` | `pi-research` | Research a topic across X and Reddit with a minimum of 10 ReAct rounds |
| stock-analyst | `stock-analyst.md` | `pi-stock-report` | Pull Taoguba jinghua posts and followed-account updates, return a market analysis report |
