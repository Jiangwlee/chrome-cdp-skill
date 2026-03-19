# chrome-cdp-skill

`chrome-cdp-skill` 是一个基于 Chrome CDP 构建的、以个人 fork 为基础的 SOP 技能平台。

本仓库不仅暴露底层浏览器控制工具，还封装了一个可复用的 `chrome-cdp` skill、一套不断扩展的站点专属 SOP 工作流，以及可直接使用的 pi agents，将这些工作流组合成面向用户的任务。目前内置的第一方工作流覆盖：

- `reddit.com`
- `tgb.cn` / 淘股吧
- `x.com`

长期目标是保持浏览器集成层稳定，持续扩展更多站点支持，并推出让用户用一条命令即可触发复杂多步工作流的 agents。

> [English README](README.md) | 中文文档

---

## 项目结构

本仓库围绕三层架构组织：

- `skill`
  `chrome-cdp` skill：共享 CDP 原语、站点专属 SOP 脚本、工作流参考文档和测试框架。这是所有 agents 依赖的浏览器层。
- `agents`
  Pi agent 定义，将 skill 组合成面向用户的工作流。每个 agent 是一个系统提示词，驱动 `pi` 执行一个专注任务。
- `bin`
  `pi-cdp` 项目 CLI，是在本地安装和卸载 skill 与 agents 的唯一入口。

## 目录结构

```text
chrome-cdp-skill/
  bin/
    pi-cdp                ← 项目 CLI（install / remove / help）
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
    link-reader.md        ← 解读单条 X 或 Reddit URL
    web-researcher.md     ← 多轮主题研究
    stock-analyst.md      ← 淘股吧行情分析
    wps-assistant.md      ← WPS 365 文档问答
    bin/
      pi-read-link        ← CLI 包装脚本
      pi-research         ← CLI 包装脚本
      pi-stock-report     ← CLI 包装脚本
      pi-wps              ← CLI 包装脚本
```

## 功能概览

- Chrome CDP CLI，提供对本地 Chrome 系浏览器会话的确定性访问。
- 站点专属 SOP 脚本，支持可重复的内容提取与页面导航工作流。
- 工作流参考文档，描述每个支持站点的处理规范。
- Pi agent 定义，在 skill 之上驱动面向用户的工作流。
- 项目 CLI（`bin/pi-cdp`），用于安装和卸载 skill 与 agents。

## 当前支持的工作流

核心浏览器访问通过 `skills/chrome-cdp/scripts/cdp.mjs` 路由。

内置工作流脚本包括：

- `skills/chrome-cdp/scripts/sites/reddit/search.sh`
- `skills/chrome-cdp/scripts/sites/reddit/open-post.sh`
- `skills/chrome-cdp/scripts/sites/taoguba/jinghua.sh`
- `skills/chrome-cdp/scripts/sites/taoguba/following.sh`
- `skills/chrome-cdp/scripts/sites/taoguba/open-post.sh`
- `skills/chrome-cdp/scripts/sites/x/search.sh`
- `skills/chrome-cdp/scripts/sites/x/open-post.sh`

## 安装

### 完整安装（skill + agents + 包装脚本）

```bash
git clone git@github.com:Jiangwlee/chrome-cdp-skill.git
cd chrome-cdp-skill
./bin/pi-cdp install
```

安装内容：
- `chrome-cdp` skill → `~/.agents/skills/chrome-cdp/`
- agent 定义 → `~/.pi/agent/agents/`
- CLI 包装脚本 → `~/.local/bin/`

### 仅安装 Skill（通过 pi 包管理器）

```bash
pi install git:github.com/Jiangwlee/chrome-cdp-skill
```

### 供其他 agents 使用

将 `skills/chrome-cdp/` 目录克隆或复制到你的 agent 加载 skill 的位置。运行时唯一依赖为 Node.js 22+。

### 启用 Chrome 远程调试

进入 `chrome://inspect/#remote-debugging` 并启用远程调试。

CLI 会自动检测 macOS、Linux 和 Windows 上的 Chrome、Chromium、Brave、Edge 和 Vivaldi。若浏览器将 `DevToolsActivePort` 存放在非标准路径，请将 `CDP_PORT_FILE` 设置为完整路径。

## 添加新站点

每个新支持的站点必须同时添加：

- 站点脚本
- 站点参考文档
- 站点测试
- `scripts/test.mjs` 集成

只有能被统一测试运行器执行的站点，才视为支持完成。

## 测试运行器

使用 `skills/chrome-cdp/scripts/test.mjs` 统一运行：

```bash
node skills/chrome-cdp/scripts/test.mjs list
node skills/chrome-cdp/scripts/test.mjs core
node skills/chrome-cdp/scripts/test.mjs site reddit
node skills/chrome-cdp/scripts/test.mjs site taoguba
node skills/chrome-cdp/scripts/test.mjs site x
node skills/chrome-cdp/scripts/test.mjs all
```

可选参数：

- `--json`
- `--fail-fast`

可选环境变量：

- `CDP_TEST_REDDIT_QUERY`
- `CDP_TEST_X_QUERY`
- `CDP_TEST_TAOGUBA_HOURS`
- `CDP_TEST_TAOGUBA_LIMIT`

## 为什么存在这个 Fork

上游项目为 Chrome CDP 实时访问提供了良好基础。本 fork 在此之上扩展为一个有维护的 SOP skill 工作区，包含：

- 针对具体网站的规范化工作流
- 面向 agents 的结构化参考文档
- 可测试的维护循环，用于检测失效的站点自动化

## 近期路线图

- 保持 `scripts/cdp.mjs` 稳定，将站点脚本和参考文档重构为按站点划分的子目录。
- 为 `core`、`reddit`、`taoguba` 和 `x` 添加冒烟测试。
- 发布三个第一方 agents：`link-reader`、`web-researcher`、`stock-analyst`。
- 完成 `bin/pi-cdp` 的 `install`、`remove` 和 `help` 子命令。

## Agents 文档

详见 [agents/README.zh.md](agents/README.zh.md)。
