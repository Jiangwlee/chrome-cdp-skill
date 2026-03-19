# SOP: Pi Agent 开发

本文档描述为本项目开发新 pi agent 和 CLI wrapper 的完整流程。
涵盖 agent 定义文件、CLI wrapper 脚本、安装注册三个部分。

## 核心概念

**Agent = system prompt + tool set + skill**

- pi agent 不是一个框架特性，只是一次 `pi` 调用。
- Agent `.md` 文件的 body 就是 system prompt，frontmatter 声明元数据。
- 所有浏览器操作通过 chrome-cdp skill 的 shell 脚本完成，不在 agent 层写脚本。
- CLI wrapper 是对 `pi` 调用的 shell 封装，让用户可以用一行命令触发 agent。

## 开发顺序

1. `agents/<name>.md` — 先写 system prompt，定义行为和输出格式
2. 本地测试，迭代 prompt
3. `agents/bin/pi-<name>` — 写 CLI wrapper
4. 注册到 `bin/pi-cdp` 的 install/remove 表

---

## 第一步：写 Agent 定义文件

文件位置：`agents/<name>.md`

### Frontmatter 格式

```markdown
---
name: my-agent
description: 一句话描述这个 agent 做什么（供 pi subagent 插件选择时使用）。
tools: bash, read
model: qwen3.5-27b
---

[system prompt 正文]
```

| 字段 | 说明 |
|------|------|
| `name` | 与文件名一致（不含 `.md`） |
| `description` | 简短描述，面向 LLM 选择时的判断 |
| `tools` | 最小集。绝大多数 agent 只需 `bash, read` |
| `model` | 默认 `qwen3.5-27b`，可按需调整 |

### System Prompt 结构

每个 system prompt 应包含以下部分：

**1. 角色声明**

一句话说明 agent 的职责和范围。

**2. 脚本路径表**

明确列出可调用的 chrome-cdp 脚本及其签名。Agent 运行时依赖安装路径，须硬编码：

```markdown
## 脚本路径

| 脚本 | 签名 | 输出 |
|------|------|------|
| `~/.agents/skills/chrome-cdp/scripts/sites/x/search.sh` | `<query> [limit]` | JSON 数组 |
| `~/.agents/skills/chrome-cdp/scripts/sites/x/open-post.sh` | `<url>` | JSON 对象 |
```

**3. 工作流程**

逐步描述 agent 的执行逻辑，语气使用命令式。

**4. 输出模板（关键）**

将行为约束编码进输出结构，而不是依赖指令约束。

- 如果需要最少 N 轮迭代，要求 agent 填写 N 个带编号的轮次记录，再允许写结论。
- 如果需要覆盖多个平台，要求每个平台各有一行。
- 任何必须执行的步骤，都应在模板里占一个必填字段。

**错误示例（依赖指令）：**
```
你必须完成 10 轮搜索后才能写结论。
```

**正确示例（模板约束）：**
```
在写"综合结论"之前，必须填完以下所有轮次记录：

### Round 1 / 10
**X 搜索词**：___
**Reddit 搜索词**：___
...

### Round 10 / 10
...

## 综合结论
（仅在 Round 10 完成后填写）
```

---

## 第二步：本地测试

```bash
pi --no-session --print \
   --skill skills/chrome-cdp \
   --tools bash,read \
   --model qwen3.5-27b \
   --system-prompt "$(awk 'BEGIN{n=0} /^---/{n++; next} n>=2{print}' agents/<name>.md)" \
   "测试输入"
```

Chrome 必须处于运行状态且已开启远程调试。
用 `node skills/chrome-cdp/scripts/cdp.mjs list` 确认有可用 tab。

### 常见失败模式

| 现象 | 原因 | 修法 |
|------|------|------|
| Agent 调用了错误路径 | 脚本路径写错 | 在 prompt 里硬编码完整绝对路径 |
| Agent 过早结束，不足 N 轮 | 指令约束无效 | 用输出模板结构强制，不能只靠指令 |
| Agent 忽略某个平台 | 未分别要求 | 模板里对每个平台各设一个必填行 |
| 立即退出无输出 | 没有传初始消息 | wrapper 需提供默认触发语 |

---

## 第三步：写 CLI Wrapper

文件位置：`agents/bin/pi-<name>`，必须可执行（`chmod +x`）。

### 标准模板

```bash
#!/usr/bin/env bash
# pi-<name> [options] [args]
# 一行描述。
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: pi-<name> [options] [args]

详细描述。

Options:
  -v          Verbose: show tool calls and LLM output in real time
  --help      Show this help
EOF
}

VERBOSE=false
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --help) usage; exit 0 ;;
    -v)     VERBOSE=true ;;
    *)      ARGS+=("$arg") ;;
  esac
done

# 如果 agent 需要参数，在此校验
# if [[ ${#ARGS[@]} -eq 0 ]]; then usage; exit 1; fi

SKILL_DIR="$HOME/.agents/skills/chrome-cdp"
AGENT_FILE="$HOME/.pi/agent/agents/<name>.md"

MODEL="$(awk -F': ' '/^model:/{print $2; exit}' "$AGENT_FILE")"
PROMPT="$(awk 'BEGIN{n=0} /^---/{n++; next} n>=2{print}' "$AGENT_FILE")"

# 无参数 agent 需要默认触发语，有参数 agent 用 "${ARGS[@]}"
DEFAULT_MSG="请开始执行"

if [[ "$VERBOSE" == true ]]; then
  pi --no-session --mode json \
     --skill "$SKILL_DIR" \
     --tools bash,read \
     --model "$MODEL" \
     --system-prompt "$PROMPT" \
     "${ARGS[@]:-$DEFAULT_MSG}" | pi-watch
else
  pi --no-session --print \
     --skill "$SKILL_DIR" \
     --tools bash,read \
     --model "$MODEL" \
     --system-prompt "$PROMPT" \
     "${ARGS[@]:-$DEFAULT_MSG}"
fi
```

**关键说明：**

- `MODEL` 和 `PROMPT` 从已安装的 agent 文件动态读取，修改 `.md` 即生效，无需重新 install。
- `pi-watch` 必须在 PATH 中（由 `pi-cdp install` 安装），wrapper 直接调用名字即可。
- 有参数的 agent（如 URL、topic）：不提供默认消息，缺参数时打印 usage 并退出 1。
- 无参数的 agent（如 stock-report）：提供默认触发语，否则 `pi --print` 立即退出。

---

## 第四步：注册到 pi-cdp

编辑 `bin/pi-cdp`，在两个数组里各添一项：

```bash
AGENT_NAMES=(link-reader web-researcher stock-analyst <name>)
WRAPPER_NAMES=(pi-read-link pi-research pi-stock-report pi-<name>)
```

install 和 remove 逻辑会自动处理新增项，无需其他改动。

---

## 完成标准

- [ ] `agents/<name>.md` 存在，frontmatter 完整，system prompt 包含脚本路径表和输出模板
- [ ] `agents/bin/pi-<name>` 存在且可执行，支持 `--help` 和 `-v`
- [ ] `bin/pi-cdp` 的 `AGENT_NAMES` 和 `WRAPPER_NAMES` 已注册
- [ ] `pi-cdp install` 运行后，`~/.pi/agent/agents/<name>.md` 和 `~/.local/bin/pi-<name>` 均为正确 symlink
- [ ] `pi-<name> --help` 输出正确
- [ ] `pi-<name> -v [args]` 可见 tool call 并正常退出
