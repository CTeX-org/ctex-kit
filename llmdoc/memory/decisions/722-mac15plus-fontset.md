---
name: "722-mac15plus-fontset"
description: "决策: 新增 mac15plus 字体集适配 macOS 15+，统一用 Heiti SC，不定义 \\pingfang"
type: decision
---

## 问题

Issue #722: macOS 15 (Sequoia) 起 Apple 将大量 CJK 字体移至私有目录，`fontset=mac` 的检测逻辑失效，LuaLaTeX 无法发现多数 CJK 字体。

## 设计决策

### 1. 新增 `mac15plus` 而非修改 `macnew`

**Why:** macOS 15 之前仍有大量用户，直接修改 `macnew` 会破坏 El Capitan ~ macOS 14 的现有行为。保持 `macold`/`macnew` 不变，新增 `mac15plus` 承接 macOS 15+ 的差异。

**How to apply:** 涉及 macOS 字体变更时，检查是否需要新增字体集而非修改现有字体集。

### 2. 三级检测逻辑

`fontset=mac` 自动检测改为：
1. `Songti.ttc` 在 Supplemental 且 `PingFang.ttc` 不存在 → `mac15plus`
2. `PingFang.ttc` 存在 → `macnew`
3. 否则 → `macold`

**Why:** 用户倾向于 mac15plus 优先检测，且双条件可精确区分 macOS 15+（有 Songti 但无 PingFang）与更早系统。

### 3. 统一用 Heiti SC，放弃 PingFang

**Why:** PingFang SC 在 macOS 15+ 上已改为系统 UI 专用字体，Core Text 拒绝暴露名称，FreeType 无法解析其私有格式（`hvgl` table）。无论按名称还是路径，XeTeX 和 LuaTeX 均无法加载。

**How to apply:** 后续若 Apple 恢复 PingFang 的第三方访问，可考虑在 mac15plus 中重新启用。

### 4. LuaTeX 用 Lua lfs 扫描 AssetsV2

**Why:** Kaiti.ttc、STFANGSO.ttf、Baoli.ttc、Yuanti.ttc 被移至 `/System/Library/AssetsV2/` 下的哈希子目录，路径不可预测。通过 `lfs.dir()` 遍历并匹配文件名是唯一可靠的定位方式。

**How to apply:** 该 Lua 代码嵌入 `.dtx` 的 `\lua_now:e` 中，每行末尾必须加 `~` 防止 expl3 吃掉换行导致关键字粘连。

### 5. 不定义 `\pingfang`，`\yahei` 映射为 `\heiti`

**Why:** PingFang 不可访问，定义 `\pingfang` 会导致运行时错误。`\yahei` 保留向后兼容但改为指向黑体-简。

### 6. pdfTeX/upTeX 不支持 mac15plus

**Why:** 这些引擎无法有效发现 AssetsV2 目录下的字体，报错比静默失败更好。
