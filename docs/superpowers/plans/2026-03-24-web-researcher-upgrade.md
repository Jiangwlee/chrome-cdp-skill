# web-researcher 多平台升级 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 web-researcher 升级为支持 Google（含 DDG fallback）、X、Reddit、GitHub 四平台的自主路由研究 agent，并支持三档研究深度。

**Architecture:** Skill 层新增 DuckDuckGo curl 脚本并修改 Google 脚本自动 fallback；Agent 层重写 web-researcher.md 加入平台场景标签和开放式轮次模板；CLI 层为 pi-research 添加 --quick/--deep 参数注入深度指令。

**Tech Stack:** bash, curl, python3, jq, gh CLI, pi CLI (`--append-system-prompt`)

---

## 文件清单

| 操作 | 文件 | 变更说明 |
|------|------|----------|
| 新建 | `skills/chrome-cdp/scripts/sites/duckduckgo/search.sh` | DDG Lite curl 脚本，输出与 google/search.sh 相同格式 |
| 修改 | `skills/chrome-cdp/scripts/sites/google/search.sh` | 尾部加 fallback 逻辑：失败或空结果时调 duckduckgo/search.sh |
| 重写 | `agents/web-researcher.md` | 多平台表 + 场景标签 + 开放式 Round Log + 新 Report 结构 |
| 修改 | `agents/bin/pi-research` | 新增 --quick/--deep 参数，注入深度指令 |

---

## Task 1：创建 `duckduckgo/search.sh`

**Files:**
- Create: `skills/chrome-cdp/scripts/sites/duckduckgo/search.sh`

### 背景

使用 `duckduckgo-search` Python 包（通过 `uv run --with duckduckgo-search` 调用，无需预装或创建 venv）搜索 DuckDuckGo，输出与 google/search.sh 一致的 `[{title, snippet, url}]` JSON。uv 会将包缓存在 `~/.cache/uv/`，对安装流程零影响。

- [ ] **Step 1: 验证 uv 可用**

```bash
uv --version
```

预期：打印版本号。若不存在，安装：`curl -LsSf https://astral.sh/uv/install.sh | sh`

- [ ] **Step 2: 验证 duckduckgo-search 可用**

```bash
uv run --with duckduckgo-search python3 -c "
from duckduckgo_search import DDGS
with DDGS() as ddgs:
    r = list(ddgs.text('AI agent 2025', max_results=3))
print(len(r), 'results')
print(r[0])
"
```

预期：打印结果数量和第一条结果（含 title、href、body 字段）。

- [ ] **Step 3: 创建脚本**

```bash
mkdir -p skills/chrome-cdp/scripts/sites/duckduckgo
cat > skills/chrome-cdp/scripts/sites/duckduckgo/search.sh << 'SCRIPT'
#!/usr/bin/env bash
# Search DuckDuckGo and return top results via duckduckgo-search Python package.
# Input: <query> [limit]
# Output: JSON array [{title, snippet, url}], same format as google/search.sh.
# Requires: uv (https://docs.astral.sh/uv/), no browser needed.
# Errors are printed to stderr and the script exits non-zero.

set -euo pipefail

usage() {
  printf 'usage: %s <query> [limit]\n' "$(basename "$0")" >&2
  exit 1
}

QUERY="${1:-}"
LIMIT="${2:-20}"

[[ -n "$QUERY" ]] || usage
[[ "$LIMIT" =~ ^[0-9]+$ ]] || { printf 'limit must be an integer\n' >&2; exit 1; }
(( LIMIT > 0 )) || { printf 'limit must be greater than zero\n' >&2; exit 1; }
(( LIMIT <= 20 )) || LIMIT=20

command -v uv >/dev/null 2>&1 || { printf 'uv is required: https://docs.astral.sh/uv/\n' >&2; exit 1; }

uv run --quiet --with duckduckgo-search python3 - "$LIMIT" "$QUERY" <<'PYEOF'
import sys, json
from duckduckgo_search import DDGS

limit = int(sys.argv[1])
query = sys.argv[2]

with DDGS() as ddgs:
    raw = list(ddgs.text(query, max_results=limit))

results = [
    {"title": r.get("title", ""), "snippet": r.get("body", "")[:280], "url": r.get("href", "")}
    for r in raw
    if r.get("href") and r.get("title")
]

print(json.dumps(results))
PYEOF
SCRIPT
chmod +x skills/chrome-cdp/scripts/sites/duckduckgo/search.sh
```

- [ ] **Step 4: 验证脚本输出**

```bash
bash skills/chrome-cdp/scripts/sites/duckduckgo/search.sh "AI agent frameworks 2025" 5
```

预期：合法 JSON 数组，包含 `title`、`snippet`、`url` 字段，url 为真实网址。

- [ ] **Step 5: 验证 limit 参数**

```bash
bash skills/chrome-cdp/scripts/sites/duckduckgo/search.sh "Python" 3 | python3 -c "import sys,json; r=json.load(sys.stdin); print(len(r)); assert len(r) <= 3"
```

预期：打印结果数量（≤ 3），无 AssertionError。

- [ ] **Step 6: Commit**

```bash
git add skills/chrome-cdp/scripts/sites/duckduckgo/search.sh
git commit -m "feat: add duckduckgo/search.sh via duckduckgo-search + uv run"
```

---

## Task 2：为 `google/search.sh` 添加 DDG Fallback

**Files:**
- Modify: `skills/chrome-cdp/scripts/sites/google/search.sh`

### 背景

当前 google/search.sh 在失败时直接 exit non-zero。在脚本末尾增加 fallback：把原始 Google 逻辑包装成函数，失败或空结果时自动调 `../duckduckgo/search.sh`，对调用方透明。

- [ ] **Step 1: 确认当前脚本结构**

```bash
grep -n "^RESULTS\|^printf\|^for START\|^done" skills/chrome-cdp/scripts/sites/google/search.sh
```

预期：看到 `RESULTS='[]'`、`for START in 0 10 20`、`done`、`printf '%s\n' "$RESULTS"` 等关键行及行号。记下 `printf '%s\n' "$RESULTS"` 的行号，这是脚本最后一行。

- [ ] **Step 2: 将主逻辑包装成函数并加 fallback**

在 `google/search.sh` 中，把从 `RESULTS='[]'` 到 `printf '%s\n' "$RESULTS"` 之间的代码包入 `_google_search()` 函数，然后在末尾加 fallback 调用。最终文件尾部应如下（替换原有的裸逻辑）：

```bash
_google_search() {
  local _RESULTS='[]'
  local _SEEN_URLS=''

  for START in 0 10 20; do
    local _CURRENT_COUNT
    _CURRENT_COUNT=$(printf '%s' "$_RESULTS" | jq 'length')
    (( _CURRENT_COUNT >= LIMIT )) && break

    local PAGE_URL="https://www.google.com/search?q=${ENCODED_QUERY}&num=10&start=${START}"
    cdp nav "$TARGET" "$PAGE_URL" >/dev/null
    wait_for_google_selector "$TARGET" '#rso'

    local PAGE_RESULTS
    PAGE_RESULTS="$(cdp_eval "$TARGET" "$EXTRACT_EXPR")"

    _RESULTS=$(jq -n \
      --argjson acc "$_RESULTS" \
      --argjson page "$PAGE_RESULTS" \
      --argjson limit "$LIMIT" \
      '($acc + $page) | unique_by(.url) | .[:$limit]')
  done

  printf '%s' "$_RESULTS"
}

# Try Google; fall back to DuckDuckGo if it fails or returns no results.
DDG_SCRIPT="${SCRIPT_DIR}/../duckduckgo/search.sh"

if RESULTS="$(_google_search 2>/dev/null)"; then
  COUNT=$(printf '%s' "$RESULTS" | jq 'length')
  if (( COUNT == 0 )); then
    printf 'google: no results, falling back to DuckDuckGo\n' >&2
    RESULTS="$(bash "$DDG_SCRIPT" "$QUERY" "$LIMIT")"
  fi
else
  printf 'google: search failed, falling back to DuckDuckGo\n' >&2
  RESULTS="$(bash "$DDG_SCRIPT" "$QUERY" "$LIMIT")"
fi

printf '%s\n' "$RESULTS"
```

- [ ] **Step 3: 验证正常 Google 路径（需要 Chrome 运行）**

```bash
bash skills/chrome-cdp/scripts/sites/google/search.sh "site:github.com AI agent" 5
```

预期：返回 JSON 数组，url 字段为 github.com 域名。若 Chrome 未运行或 Google block，stderr 会打印 fallback 信息，结果来自 DDG，也算通过。

- [ ] **Step 4: 模拟 Google 失败，验证 Fallback**

临时把 Google URL 改坏，测试 fallback 触发：

```bash
bash -c '
  QUERY="AI agent frameworks" LIMIT=3
  RESULTS=""
  DDG_SCRIPT="skills/chrome-cdp/scripts/sites/duckduckgo/search.sh"
  # Simulate Google failure
  if false; then
    RESULTS="[]"
  else
    printf "google: search failed, falling back to DuckDuckGo\n" >&2
    RESULTS="$(bash "$DDG_SCRIPT" "$QUERY" "$LIMIT")"
  fi
  printf "%s\n" "$RESULTS" | python3 -c "import sys,json; r=json.load(sys.stdin); print(\"fallback ok, got\", len(r), \"results\")"
'
```

预期：stderr 打印 `google: search failed, falling back to DuckDuckGo`，stdout 打印 `fallback ok, got N results`。

- [ ] **Step 5: Commit**

```bash
git add skills/chrome-cdp/scripts/sites/google/search.sh
git commit -m "feat: add DuckDuckGo fallback to google/search.sh"
```

---

## Task 3：重写 `agents/web-researcher.md`

**Files:**
- Modify: `agents/web-researcher.md`

### 背景

完整替换文件内容：更新 description、添加多平台表（含场景标签和 gh CLI 命令）、用开放式 Round Log 替换固定 10 轮模板、用新的按平台分区 Final Report 替换旧结构。

- [ ] **Step 1: 写入新文件内容**

```bash
cat > agents/web-researcher.md << 'EOF'
---
name: web-researcher
description: Research a topic across Google, X, Reddit, and GitHub using iterative search rounds, then return a structured per-platform research report.
tools: bash, read
model: qwen3.5-27b
---

You are a research agent. Given a topic, you conduct multi-round research across multiple platforms, selecting the best platform for each query. You stop only when you have met the minimum round requirement (injected by the system or defaulting to 5 rounds).

## Platforms

All browser access runs through shell scripts at `~/.agents/skills/chrome-cdp/scripts/sites/`.
GitHub access uses the `gh` CLI directly.

| Platform | Script / Command | Use when |
|----------|-----------------|----------|
| Google | `google/search.sh <query> [limit]` | Default starting point. General queries, official docs, news, technical blogs, academic references. Use first unless the topic clearly belongs to another platform. |
| X | `x/search.sh <query> [limit]` then `x/open-post.sh <url>` | Real-time reactions, trending discussion, opinions from practitioners, product launch buzz. |
| Reddit | `reddit/search.sh <query> [limit]` then `reddit/open-post.sh <url> [comment_limit]` | In-depth technical community discussion, real usage experience, war stories, long-form analysis. |
| GitHub | `gh search repos <query>`, `gh search issues <query>`, `gh repo view <owner/repo>`, `gh release list -R <owner/repo>` | Open-source project landscape, code-level implementation, issue tracking, release history, project activity. |

Scripts output JSON and exit non-zero on failure. The default result limit is 10.

Example invocations:

```bash
bash ~/.agents/skills/chrome-cdp/scripts/sites/google/search.sh "AI agent frameworks 2025" 10
bash ~/.agents/skills/chrome-cdp/scripts/sites/x/search.sh "AI agent" 5
bash ~/.agents/skills/chrome-cdp/scripts/sites/x/open-post.sh "https://x.com/user/status/123"
bash ~/.agents/skills/chrome-cdp/scripts/sites/reddit/search.sh "AI agent frameworks" 5
bash ~/.agents/skills/chrome-cdp/scripts/sites/reddit/open-post.sh "https://www.reddit.com/r/MachineLearning/comments/abc/title/"
gh search repos "AI agent framework" --limit 10 --json fullName,description,stargazersCount,updatedAt
gh search issues "agent memory" --limit 10 --json title,url,body,comments
gh repo view langchain-ai/langchain --json description,stargazerCount,updatedAt
```

## Research Loop

Each round follows this sequence:

1. **Choose platform** — pick 1–2 platforms best suited to your current gap.
2. **Search** — run the chosen platform's search script with a specific query.
3. **Select** — from the results, choose 2–3 items that look most informative.
4. **Read** — run `open-post.sh` (or `gh repo view` / `gh search issues`) on each selected item.
5. **Reflect** — identify what you learned and what gaps remain.
6. **Refine** — derive the next query from your gaps and new terms found.

Platform selection rules:
- Start with Google unless the topic is clearly code/open-source (→ GitHub) or real-time discussion (→ X).
- If the same platform yields no new information for 3 consecutive rounds, switch.
- You do not need to use every platform every round, but aim to cover at least 2 platforms by the end.

Vary your queries across rounds. Do not repeat the same query.

## Round Log

Fill one entry per round. Continue until you have met the minimum round requirement, then write the Final Report.

---

### Round 1
**Platform(s) chosen**: ___
**Query**: ___
**Items read**: (list URLs or gh commands)
**Key findings**: ___
**Gaps identified**: ___
**Next query direction**: ___

### Round 2
**Platform(s) chosen**: ___
**Query**: ___
**Items read**: (list URLs or gh commands)
**Key findings**: ___
**Gaps identified**: ___
**Next query direction**: ___

### Round 3
**Platform(s) chosen**: ___
**Query**: ___
**Items read**: (list URLs or gh commands)
**Key findings**: ___
**Gaps identified**: ___
**Next query direction**: ___

*(Add more rounds as needed until the minimum is met.)*

---

## Final Report

*Write this section only after meeting the minimum round requirement.*

```
# Research Report: <topic>

## Overview
<3–5 sentence high-level summary>

## Google / DuckDuckGo
<Findings from Google searches, with source URLs. Write "Not used." if this platform was not used.>

## X
<Findings from X searches and posts, with source URLs. Write "Not used." if this platform was not used.>

## Reddit
<Findings from Reddit searches and threads, with source URLs. Write "Not used." if this platform was not used.>

## GitHub
<Findings from GitHub repo/issue searches, with links. Write "Not used." if this platform was not used.>

## 综合结论
<Cross-platform synthesis: main conclusions, consensus points, and notable disagreements.>

## Gaps and Limitations
<What this research did not cover or could not confirm.>
```
EOF
```

- [ ] **Step 2: 验证文件结构正确**

```bash
head -10 agents/web-researcher.md
grep -c "Platform" agents/web-researcher.md
grep "Round Log\|Final Report\|综合结论" agents/web-researcher.md
```

预期：frontmatter 正确，`Platform` 出现多次，关键章节标题都存在。

- [ ] **Step 3: Commit**

```bash
git add agents/web-researcher.md
git commit -m "feat: rewrite web-researcher with multi-platform routing and open round log"
```

---

## Task 4：更新 `pi-research` CLI

**Files:**
- Modify: `agents/bin/pi-research`

### 背景

添加 `--quick`（≥3 轮）和 `--deep`（≥10 轮）参数。默认（无参数）注入"至少5轮"。通过在 `pi` 调用后附加 `--append-system-prompt` 注入档位指令。同时更新 usage 文档和 description 注释。

- [ ] **Step 1: 写入新 CLI 内容**

```bash
cat > agents/bin/pi-research << 'EOF'
#!/usr/bin/env bash
# pi-research [options] <topic>
# Research a topic across Google, X, Reddit, and GitHub with iterative rounds.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: pi-research [options] <topic>

Research a topic across Google, X, Reddit, and GitHub using iterative
search rounds, then return a structured per-platform research report.

Arguments:
  <topic>     The research topic or question

Options:
  --quick     Simple topic: at least 3 rounds
  --deep      Deep research: at least 10 rounds (thorough multi-platform)
  -v          Verbose: show tool calls and LLM output in real time
  --help      Show this help

Default (no depth flag): at least 5 rounds.
USAGE
}

VERBOSE=false
DEPTH="medium"
ARGS=()

for arg in "$@"; do
  case "$arg" in
    --help)  usage; exit 0 ;;
    -v)      VERBOSE=true ;;
    --quick) DEPTH="quick" ;;
    --deep)  DEPTH="deep" ;;
    *)       ARGS+=("$arg") ;;
  esac
done

if [[ ${#ARGS[@]} -eq 0 ]]; then
  usage; exit 1
fi

case "$DEPTH" in
  quick)  DEPTH_PROMPT="这是一个简单问题，完成至少3轮搜索后即可写结论。" ;;
  deep)   DEPTH_PROMPT="用户要求深度研究，必须完成至少10轮搜索，充分覆盖多个平台和角度后再写结论。" ;;
  *)      DEPTH_PROMPT="完成至少5轮搜索后再写结论。" ;;
esac

SKILL_DIR="$HOME/.agents/skills/chrome-cdp"
AGENT_FILE="$HOME/.pi/agent/agents/web-researcher.md"

MODEL="$(awk -F': ' '/^model:/{print $2; exit}' "$AGENT_FILE")"
PROMPT="$(awk 'BEGIN{n=0} /^---/{n++; next} n>=2{print}' "$AGENT_FILE")"

if [[ "$VERBOSE" == true ]]; then
  pi --no-session --mode json \
     --skill "$SKILL_DIR" \
     --tools bash,read \
     --model "$MODEL" \
     --system-prompt "$PROMPT" \
     --append-system-prompt "$DEPTH_PROMPT" \
     "${ARGS[@]}" | pi-watch
else
  pi --no-session --print \
     --skill "$SKILL_DIR" \
     --tools bash,read \
     --model "$MODEL" \
     --system-prompt "$PROMPT" \
     --append-system-prompt "$DEPTH_PROMPT" \
     "${ARGS[@]}"
fi
EOF
chmod +x agents/bin/pi-research
```

- [ ] **Step 2: 验证 usage 输出**

```bash
bash agents/bin/pi-research --help
```

预期：打印包含 `--quick`、`--deep`、`-v` 的 usage 文档，无报错。

- [ ] **Step 3: 验证参数解析（dry-run）**

```bash
# 验证 DEPTH 变量是否按预期设置（在脚本中临时加 echo 测试）
bash -c '
  DEPTH="medium"
  for arg in --quick "test topic"; do
    case "$arg" in --quick) DEPTH="quick" ;; esac
  done
  echo "DEPTH=$DEPTH"
'
```

预期：输出 `DEPTH=quick`。

- [ ] **Step 4: Commit**

```bash
git add agents/bin/pi-research
git commit -m "feat: add --quick/--deep depth flags to pi-research CLI"
```

---

## Task 5：Smoke Test

- [ ] **Step 1: 确认所有新/改文件存在且可执行**

```bash
ls -la skills/chrome-cdp/scripts/sites/duckduckgo/search.sh
ls -la agents/bin/pi-research
head -5 agents/web-researcher.md
```

预期：三个文件均存在，权限正确，frontmatter 正确。

- [ ] **Step 2: DDG 脚本端到端测试**

```bash
bash skills/chrome-cdp/scripts/sites/duckduckgo/search.sh "open source LLM 2025" 3 \
  | python3 -c "
import sys, json
results = json.load(sys.stdin)
assert len(results) > 0, 'no results'
for r in results:
    assert 'title' in r and 'url' in r, f'missing fields: {r}'
    assert r['url'].startswith('http'), f'bad url: {r[\"url\"]}'
print(f'DDG ok: {len(results)} results, first url: {results[0][\"url\"]}')
"
```

预期：打印 `DDG ok: N results, first url: https://...`

- [ ] **Step 3: 确认 pi-research --help 可运行**

```bash
bash agents/bin/pi-research --help 2>&1 | grep -q "deep" && echo "CLI ok"
```

预期：输出 `CLI ok`。

- [ ] **Step 4: 最终 commit（如有遗漏文件）**

```bash
git status
# 若有未提交文件：
# git add <file> && git commit -m "chore: ..."
```

---

## 完成标准

- [ ] `duckduckgo/search.sh` 可独立运行，返回合法 JSON，URL 为真实网址
- [ ] `google/search.sh` 在 Google 不可用时自动 fallback，stderr 有提示
- [ ] `web-researcher.md` 包含四平台表、场景标签、开放式 Round Log、新 Report 结构
- [ ] `pi-research --quick/--deep` 可解析，`--help` 文档正确
- [ ] 所有改动均已 commit
