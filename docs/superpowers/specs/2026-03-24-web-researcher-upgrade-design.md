# Design: web-researcher 多平台升级

**日期**：2026-03-24
**状态**：已确认，待实现

---

## 目标

将 `web-researcher` 从"固定使用 X + Reddit"升级为"多平台自主路由的研究 agent"，新增 Google（含 DuckDuckGo fallback）和 GitHub，赋予 agent 更高的平台选择自由度，并支持三档研究深度。

---

## 改动范围

```
Skill 层
  skills/chrome-cdp/scripts/sites/google/search.sh      ← 修改：内部 fallback 到 DDG Lite
  skills/chrome-cdp/scripts/sites/duckduckgo/search.sh  ← 新建：curl-based DDG Lite 脚本

Agent 层
  agents/web-researcher.md     ← 重写：多平台 + 场景标签 + 开放式轮次模板 + 新 Report 结构

CLI 层
  agents/bin/pi-research       ← 修改：新增 --quick / --deep 参数
```

---

## Section 1：平台表与场景标签

| 平台 | 脚本/命令 | 适用场景 |
|------|-----------|----------|
| Google | `google/search.sh` | 通用查询、官方文档、技术博客、新闻报道、学术资料。优先选择，是大多数轮次的起点 |
| X | `x/search.sh` / `x/open-post.sh` | 实时动态、社区热议、意见领袖观点、新产品发布反应 |
| Reddit | `reddit/search.sh` / `reddit/open-post.sh` | 技术社区深度讨论、真实使用经验、踩坑记录、长帖分析 |
| GitHub | `gh search repos` / `gh search issues` / `gh repo view` / `gh release list` | 开源项目现状、代码实现参考、issue 跟踪、版本变更、活跃度评估 |

**Agent 决策原则**：
- 每轮自主选择 1–2 个平台，不要求全覆盖
- Google 是默认起点，话题明确指向社区/代码/实时信息时优先切换对应平台
- 同一平台连续 3 轮无新收获时，主动切换

---

## Section 2：DuckDuckGo Fallback（Skill 层）

- 新建 `skills/chrome-cdp/scripts/sites/duckduckgo/search.sh`
  - 实现：`curl` + User-Agent 请求 `https://lite.duckduckgo.com/lite/?q=<query>`
  - 解析 HTML 提取 title、snippet、真实 URL（decode `uddg` 参数）
  - 输出格式与其他 search 脚本一致：JSON array `[{title, snippet, url}]`
- 修改 `skills/chrome-cdp/scripts/sites/google/search.sh`
  - Google 搜索失败（non-zero exit）或返回空结果时，自动调用 `duckduckgo/search.sh`
  - Fallback 对调用方（agent）完全透明

---

## Section 3：深度档位与 CLI

**参数**：

```bash
pi-research "topic"          # 默认：中等深度，≥5 轮
pi-research --quick "topic"  # 简单：≥3 轮
pi-research --deep "topic"   # 深度：≥10 轮
```

**实现**：通过 `pi --append-system-prompt` 注入档位指令：

| 参数 | 注入内容 |
|------|----------|
| `--quick` | `这是一个简单问题，完成至少3轮搜索后即可写结论。` |
| (默认) | `完成至少5轮搜索后再写结论。` |
| `--deep` | `用户要求深度研究，必须完成至少10轮搜索，充分覆盖多个平台和角度后再写结论。` |

**`web-researcher.md` 轮次模板**：移除固定的 Round 1–10 填写块，改为开放式 Round Log，agent 按实际轮数填写，直到满足注入的轮次要求为止。

---

## Section 4：Final Report 结构

```markdown
# Research Report: <topic>

## Overview
<3–5 句高层摘要>

## Google / DuckDuckGo
<发现内容，含来源 URL>

## X
<发现内容，含来源 URL>
（若本次研究未使用该平台，注明"未使用"）

## Reddit
<发现内容，含来源 URL>
（若本次研究未使用该平台，注明"未使用"）

## GitHub
<发现内容，含来源 URL>
（若本次研究未使用该平台，注明"未使用"）

## 综合结论
<跨平台信息整合，主要观点、共识与分歧>

## Gaps and Limitations
<未能覆盖或无法确认的内容>
```

**说明**：
- 未使用的平台保留占位并注明"未使用"，明确覆盖范围
- Google 和 DuckDuckGo 合并为一节（fallback 对 agent 透明）
- "综合结论"替代原有的 Key Themes + Contrasting Views，位于各平台分区之后

---

## 不在本次范围内

- 新增其他平台（Hacker News、YouTube 等）
- 改变 agent 的模型选择
- 修改 `taoguba-researcher` 或其他 agent
