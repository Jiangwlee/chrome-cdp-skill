# Navigation Refactor - 统一导航方式

## 背景

在 chrome-cdp skill 中，不同 site 之前使用不同的导航方式，导致代码重复和维护困难：

- **google, reddit, taoguba**: 使用 `cdp evalraw Page.navigate`（不等待加载）
- **xueqiu**: 使用 JavaScript `location.href`（特殊处理）
- **kdocs, x**: 使用 `cdp nav`（等待加载完成）
- **baidu, weixin-sogou**: 直接在脚本中使用 `cdp evalraw`
- **duckduckgo**: 不使用浏览器，用 Python 包

## 问题

1. **代码重复**: 每个 site 都实现了自己的导航函数
2. **维护困难**: 导航逻辑分散在多个文件中
3. **行为不一致**: 不同 site 的导航等待策略不同

## 解决方案

### 1. 在 core/common.sh 中添加统一的 `cdp_nav` 函数

```bash
# Navigate to URL using cdp.mjs nav command (waits for load completion)
# Usage: cdp_nav <target> <url> [fast]
#   If fast=true, uses evalraw Page.navigate without waiting for load
cdp_nav() {
  local target="$1"
  local url="$2"
  local fast="${3:-false}"
  
  if [[ "$fast" == "true" ]]; then
    # Fast navigation: use Page.navigate without waiting for loadEventFired
    local params
    params="$(jq -nc --arg url "$url" '{url: $url}')"
    cdp evalraw "$target" "Page.navigate" "$params" >/dev/null 2>&1 || true
  else
    # Normal navigation: wait for load completion
    cdp nav "$target" "$url" >/dev/null
  fi
}
```

### 2. 所有 site 的 common.sh 都使用统一的 `cdp_nav`

每个 site 保留自己的命名空间函数（如 `google_nav_fast`, `reddit_nav_fast`），但内部调用统一的 `cdp_nav`：

```bash
# Use the unified cdp_nav from core/common.sh
# google_nav_fast is kept for backward compatibility but now delegates to cdp_nav
google_nav_fast() {
  cdp_nav "$@"
}
```

### 3. 对于需要快速导航的 site，使用 fast 模式

```bash
# Use the unified cdp_nav from core/common.sh with fast mode (Baidu can timeout)
baidu_nav_fast() {
  cdp_nav "$1" "$2" "true"
}
```

## 修改的站点

| Site | 修改内容 | 导航模式 |
|------|---------|---------|
| **core/common.sh** | 添加 `cdp_nav()` 函数 | - |
| **google/common.sh** | `google_nav_fast` 委托给 `cdp_nav` | 默认（等待） |
| **reddit/common.sh** | `reddit_nav_fast` 委托给 `cdp_nav` | 默认（等待） |
| **taoguba/common.sh** | `taoguba_nav_fast` 委托给 `cdp_nav` | 默认（等待） |
| **xueqiu/common.sh** | `xueqiu_nav_fast` 委托给 `cdp_nav` | 默认（等待） |
| **weixin-sogou/common.sh** | 添加 `sogou_nav_fast`，更新 search.sh | 默认（等待） |
| **baidu/common.sh** | 添加 `baidu_nav_fast`，使用 fast 模式 | 快速（不等待） |
| **baidu/search.sh** | 使用 `baidu_nav_fast` | 快速（不等待） |
| **weixin-sogou/search.sh** | 使用 `sogou_nav_fast` | 默认（等待） |
| **x/common.sh** | 已正确定义 `cdp_nav` | 默认（等待） |

## 为什么需要两种模式？

### 默认模式（等待加载完成）
- **优点**: 确保页面完全加载后再执行后续操作
- **缺点**: 较慢，某些网站可能超时
- **适用**: 大多数网站（Google, Reddit, X, Xueqiu, Sogou）

### 快速模式（不等待加载）
- **优点**: 快速启动，不会因页面加载慢而超时
- **缺点**: 需要在导航后立即等待特定元素或 URL 变化
- **适用**: 加载慢的网站（Baidu）

## 向后兼容性

- 所有现有的 site-specific 导航函数名称保持不变
- 外部调用者不需要修改任何代码
- 只是内部实现改为使用统一的 `cdp_nav`

## 测试验证

所有 sites 经过测试：

```bash
# Google ✓
bash scripts/sites/google/search.sh "AI Agent" 3

# Reddit ✓ (注意：Reddit 有独立的 NEEDLE bug，与导航无关)
bash scripts/sites/reddit/search.sh "AI Agent" 3

# Taoguba ✓ (注意：Taoguba 有独立的 NEEDLE bug，与导航无关)
bash scripts/sites/taoguba/jinghua.sh 3

# Xueqiu ✓
bash scripts/sites/xueqiu/search.sh "AI Agent" 3

# X ✓
bash scripts/sites/x/search.sh "AI Agent" 3

# Baidu ✓
bash scripts/sites/baidu/search.sh "AI Agent" 3

# Weixin-Sogou ✓
bash scripts/sites/weixin-sogou/search.sh "AI Agent" 3
```

## 未来改进方向

1. **统一错误处理**: 为所有导航函数提供一致的错误消息
2. **超时配置**: 允许通过环境变量配置导航超时时间
3. **重试机制**: 为失败的导航自动重试
4. **性能监控**: 记录每次导航的耗时，帮助识别慢网站

## 相关文件

- `/scripts/core/common.sh` - 统一的 `cdp_nav` 函数
- `/scripts/sites/*/common.sh` - 各 site 的包装函数
- `/scripts/cdp.mjs` - CDP 命令实现
