# SOP: Chrome CDP Skill 开发

本文档描述为新网站添加 SOP 工作流的完整开发流程。
是对 `skills/chrome-cdp/references/core/sop-development.md` 的补充，
重点记录本项目实践中总结的关键规则和常见陷阱。

## 开发顺序

按以下顺序创建文件，不要跳步：

1. `references/sites/<site>/workflows.md` — 先写文档，锁定边界和输出 schema
2. `scripts/sites/<site>/common.sh` — 共用辅助函数
3. 工作流脚本（每次一个，验证后再写下一个）
4. `tests/sites/<site>/` — smoke test
5. 更新 `SKILL.md`、`references/core/index.md`、`scripts/test.mjs`

## 页面调查规范

### 用 DOM，不用截图坐标

**将自己视为盲人，只能看到 HTML。** 不要截图后猜坐标再点击。
一切交互必须通过 DOM 定位：

```bash
# 正确：通过 CSS selector 定位并点击
cdp.mjs eval <target> "document.querySelector('.some-class')?.click()"

# 正确：通过文本内容定位
cdp.mjs eval <target> "Array.from(document.querySelectorAll('button')).find(b => b.innerText.trim() === 'Find')?.click()"

# 错误：截图后用坐标点击
cdp.mjs clickxy <target> 1263 49  # ← 避免，除非别无选择
```

### 调查工具使用顺序

1. `snap` — 先了解页面无障碍结构和主要区域
2. 针对性 `eval` 小探针 — 确认 selector、数据结构、URL 规律
3. 交互验证 — 触发行为后再次 `snap`/`eval` 确认结果

### 常见调查探针

```bash
# 确认 URL 和页面标题
cdp.mjs eval <target> "window.location.href"
cdp.mjs eval <target> "document.title"

# 找 class 规律
cdp.mjs eval <target> "JSON.stringify([...new Set(Array.from(document.querySelectorAll('*')).flatMap(el => el.className?.toString().split(' ') || []).filter(c => c.includes('result') || c.includes('item')))])"

# 读可见文字（canvas 渲染页面用 snap）
cdp.mjs snap <target> 2>/dev/null | grep '\[StaticText\]' | head -30
```

## Canvas 渲染文档的特殊处理

WPS 等富文本编辑器用 canvas 渲染，`innerText` 读不到正文。
正文只能通过无障碍树读取：

```bash
# 读文档正文
cdp.mjs snap <target> 2>/dev/null | grep -oP '(?<=\[StaticText\] ).*'
```

键盘快捷键（如 Ctrl+F）对 canvas 页面无效，必须通过 DOM 点击触发：

```bash
# 正确：通过 DOM 打开 Find 对话框
cdp.mjs eval <target> "document.querySelector('.kd-icon-magnifier')?.closest('button')?.click()"

# 错误：发送键盘事件（对 canvas 区域无效）
cdp.mjs evalraw <target> Input.dispatchKeyEvent '{"type":"keyDown","key":"f","modifiers":2}'
```

## 脚本结构规范

### common.sh 职责

- tab 查找（按 URL 模式过滤）
- 页面就绪等待（async 轮询，带超时）
- `cdp.mjs` 的薄封装
- 文本清洗工具（snap 输出过滤）

### 工作流脚本职责

- CLI 参数解析和验证
- 调用 common.sh 函数
- 站点专属的 JS 提取逻辑（内联在 heredoc 中）
- 输出 JSON（用 jq 后处理）

### JS 提取代码规范

- 用单次 `eval` 收集所有需要的数据，避免多次 `eval` 之间 DOM 变化
- 用 IIFE 封装：`(() => { ... })()`
- 通过字符串替换注入 bash 变量：`EXPR="${EXPR/PLACEHOLDER/${VALUE}}"`
- 返回值直接是 JSON 对象或数组，不要返回 HTML

## 就绪检测规范

不要假设 `nav` 完成 = 页面就绪。根据场景选择等待策略：

| 场景 | 等待策略 |
|---|---|
| 搜索结果列表 | 轮询特定 selector 出现（`.item-container`） |
| 文档加载 | 轮询 `document.title` 变化 |
| 弹窗/对话框 | 轮询对话框 selector 出现 |
| 点击后新 tab | 轮询 `list_raw` 直到新 targetId 出现 |

等待函数模板（async/await + 超时）：

```bash
read -r -d '' expr <<'EOF' || true
(async () => {
  const deadline = Date.now() + LIMIT_MS;
  while (Date.now() < deadline) {
    if (document.querySelector('.target-selector')) return 'READY';
    await new Promise(r => setTimeout(r, 300));
  }
  throw new Error('Timed out waiting for ...');
})()
EOF
expr="${expr/LIMIT_MS/${limit}}"
cdp_eval "$target" "$expr" >/dev/null
```

## 输出 Schema 规范

每个工作流脚本必须返回稳定的 JSON，在 `workflows.md` 中记录字段说明。

- 搜索脚本 → JSON 数组，每项包含 ID/key、标题、元数据、摘要
- 打开脚本 → JSON 对象，包含 title、url、target（targetId 前缀）、内容
- 操作脚本（find、close 等）→ JSON 对象，包含操作结果和状态确认

## 完成标准

一个新站点支持完成的标志：

- [ ] `workflows.md` 记录了边界、脚本入口、输出 schema、SOP 步骤
- [ ] `common.sh` 实现了 tab 查找、就绪等待、文本提取
- [ ] 所有工作流脚本在真实 tab 上验证通过
- [ ] smoke test 注册到 `test.mjs` 且 `node test.mjs site <site>` 通过
- [ ] `SKILL.md` 和 `references/core/index.md` 已更新
