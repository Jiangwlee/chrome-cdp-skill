# Agents

本目录包含 pi agent 定义，将 `chrome-cdp` skill 组合成面向用户的工作流。

> [English README](README.md) | 中文文档

---

## 什么是 Agent

一个 agent 由三个部分组成：

- **系统提示词** — 本目录中的 `.md` 文件，定义 agent 的角色、工作流、工具使用方式和输出格式。
- **工具集** — 在 frontmatter 中声明。大多数 agent 只需要 `bash`（执行 skill 脚本）和 `read`（查阅 skill 参考文档）。
- **Skill** — `chrome-cdp` skill 提供所有浏览器访问能力。Agents 不包含浏览器脚本，通过 `bash` 调用 skill 的 shell 脚本。

Agents 无需 pi subagent 扩展，直接通过 pi CLI 调用。

## 目录结构

```text
agents/
  link-reader.md        ← 解读单条 X 或 Reddit URL
  web-researcher.md     ← 多轮主题研究
  stock-analyst.md      ← 淘股吧行情分析
  wps-assistant.md      ← WPS 365 文档问答
  bin/
    pi-read-link        ← link-reader 的 CLI 包装脚本
    pi-research         ← web-researcher 的 CLI 包装脚本
    pi-stock-report     ← stock-analyst 的 CLI 包装脚本
    pi-wps              ← wps-assistant 的 CLI 包装脚本
```

## Agent 文件格式

Agent 文件遵循 pi subagent frontmatter 约定，以保持与直接 CLI 调用和 pi subagent 扩展的双重兼容性。

```markdown
---
name: my-agent
description: 一句话描述此 agent 的功能。
tools: bash, read
model: claude-sonnet-4-6
---

系统提示词内容写在这里。
```

| Frontmatter 字段 | 必填 | 说明 |
|---|---|---|
| `name` | 是 | 与文件名（不含 `.md`）一致 |
| `description` | 是 | 供 subagent 扩展选择 agent 时使用 |
| `tools` | 是 | 声明最小工具集，大多数 agent：`bash, read` |
| `model` | 是 | 研究类任务推荐 `claude-sonnet-4-6` |

## CLI 包装脚本

每个 agent 在 `agents/bin/` 中有对应的包装脚本，是调用 pi 并传入正确参数的薄壳脚本：

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

包装脚本由 `bin/pi-cdp install` 安装到 `~/.local/bin/`。

## Skill 脚本参考

Agents 通过 `bash` 调用 skill 脚本，所有脚本位于 `skills/chrome-cdp/scripts/sites/` 下。

| 脚本 | 输入 | 输出 |
|---|---|---|
| `x/search.sh <query>` | 搜索词 | JSON 数组：`author`、`handle`、`time_hint`、`summary`、`url` |
| `x/open-post.sh <url>` | 帖子 URL | JSON 对象：`author`、`handle`、`time`、`text`、`url` |
| `reddit/search.sh <query>` | 搜索词 | JSON 数组：`title`、`subreddit`、`time_hint`、`summary`、`url` |
| `reddit/open-post.sh <url>` | 帖子 URL | JSON 对象：`title`、`subreddit`、`author`、`time`、`text`、`url`、`comments` |
| `taoguba/jinghua.sh` | 可选 hours、limit | 近期精华帖 JSON 数组 |
| `taoguba/following.sh` | 可选 hours、limit | 关注账号更新 JSON 数组 |
| `taoguba/open-post.sh <url>` | 帖子 URL | JSON 对象：`title`、`author`、`time`、`stats`、`text`、`url` |

Agent 需在运行时定位 skill 目录。包装脚本通过环境变量传递 `SKILL_DIR`，或 agent 提示词中包含已安装路径 `~/.agents/skills/chrome-cdp/`。

## 开发工作流

### 1. 编写系统提示词

创建 `agents/<name>.md`，包含 frontmatter 和专注的系统提示词，内容包括：
- 明确说明 agent 的单一职责。
- 使用哪些 skill 脚本及使用方式。
- agent 在结束前必须填写的结构化输出模板，这是强制行为约束（如最少迭代次数）的主要机制。

### 2. 本地测试

```bash
pi --no-session --print \
   --skill skills/chrome-cdp \
   --tools bash,read \
   --system-prompt "$(tail -n +6 agents/<name>.md)" \
   "你的测试输入"
```

Chrome 必须在启用远程调试的情况下运行。执行 `node skills/chrome-cdp/scripts/cdp.mjs list` 确认可用 tab 存在。

### 3. 迭代提示词

常见失效模式：
- Agent 使用了错误的脚本路径 → 在提示词中加入绝对路径指导。
- Agent 过早退出 → 收紧输出模板结构。
- Agent 忽略某个平台 → 让模板要求每个平台都有对应条目。

### 4. 创建 CLI 包装脚本

按上述包装模式添加 `agents/bin/pi-<name>`，并赋予执行权限：

```bash
chmod +x agents/bin/pi-<name>
```

### 5. 在 pi-cdp 中注册

将 agent 和包装脚本添加到 `bin/pi-cdp` 的安装/卸载表中。

### 6. 一次提交所有内容

一个完整的 agent 新增包括：
- `agents/<name>.md`
- `agents/bin/pi-<name>`
- 更新 `bin/pi-cdp` 安装/卸载表

## 第一方 Agents

| Agent | 文件 | 包装脚本 | 任务 |
|---|---|---|---|
| link-reader | `link-reader.md` | `pi-read-link` | 读取一条 X 或 Reddit URL，返回结构化摘要 |
| web-researcher | `web-researcher.md` | `pi-research` | 在 X 和 Reddit 上多轮研究某个主题，最少 10 轮 ReAct |
| stock-analyst | `stock-analyst.md` | `pi-stock-report` | 拉取淘股吧精华帖和关注账号更新，返回行情分析报告 |
| wps-assistant | `wps-assistant.md` | `pi-wps` | 基于 WPS 365 文档回答用户问题 |
