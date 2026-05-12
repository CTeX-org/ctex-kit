# 决策: #826 xeCJKfntef 右侧 CJKglue 恢复

## 问题

`\CJKsout{文字}`、`\CJKunderdot{文字}` 等 xeCJKfntef 命令右侧的 CJKglue 未被正确恢复。

## 根因

xeCJKfntef 的内容在 ulem 的 hbox 中排版，不在主 hlist 上。当 hbox 关闭后（`}` 后），XeTeX 的 interchar class 不再是 CJK，源码空格产生 finite inter-word glue。该 glue 叠在 xeCJK 先前写下的 CJK kern pair 标记（`CJK` / `CJK-space` / `CJK-widow`）上方。

`\xeCJK_check_for_glue:` 的 glue 分支原来没有"揭开 glue 查看下方标记"的探测逻辑。

## 方案

新增 `\@@_check_for_glue_skip:` 函数处理 `\@@_if_last_glue:TF` 为真的分支。

### 处理流程（三层过滤）

1. `\g_@@_ulem_pending_bool` 门控（最外层）：
   - 该 boolean 由 fntef 模块的 `\@@_ulem_group_end:n` 在 ulem hbox 关闭时全局置真
   - 若为假：直接跳过整个 glue 分支，进入 `\@@_check_for_glue_auxii:`
   - 若为真：进入 skip 检查，同时在此分支内保存 `\lastskip` 到 `\l_@@_last_skip`
2. `\skip_if_finite:nTF` 检查：
   - 非 finite（fil 级 glue，如 listings 列对齐）：回退到 `\@@_check_for_glue_auxii:`
   - finite：继续下一层
3. `\tex_glueshrink:D > 0` 检查：
   - glueshrink > 0（inter-word space）：`\unskip` 移除 glue，探测下方 kern pair
   - glueshrink = 0（`\quad` 等无 shrink 的显式空距）：回退到 `\@@_check_for_glue_auxii:`
4. 若下方是 CJK kern pair 标记：移除标记 kern，放置正确的 CJKglue
5. 若不是 kern pair：恢复 glue，调用 `\@@_check_for_glue_auxii:`

### 关键设计决策

- **boolean flag 门控 `\l_@@_last_skip` 赋值**：`\g_@@_ulem_pending_bool` 确保只有 ulem hbox 刚关闭时才保存 `\lastskip`，防止对 `\l_@@_last_skip` 的状态污染影响后续正常 glue 路径
- **`\g_@@_ulem_pending_bool` 由 `\@@_ulem_group_end:n` 置真**：fntef 模块在 ulem hbox 关闭时全局设置此标记，将 fntef 专属状态传递到边界恢复逻辑
- **只处理 finite glue**：排除 listings 等插入的 fil 级 glue，避免破坏其列对齐
- **glueshrink 检查排除 `\quad`**：`\quad` 等无 shrink component 的显式空距不应被移除并替换为 CJKglue；只有带 shrink 的 inter-word space 才是 fntef 右侧的意外 glue
- **所有 fallback 统一到 `\@@_check_for_glue_auxii:`**：该路径包含 punct 检测链，保证标点识别正常；不回退到 `\xeCJK_check_for_xglue:`
- **不处理 whatsit 层级**：`\textcolor{red}{文字}` 右侧的 `\special{color pop}` whatsit 隔断了 kern pair 探测，但无法安全区分 xcolor `\special` 和 XeTeX native word 节点

### 测试覆盖

- `fntef-space02`：覆盖 `\quad`（不应被吃掉）、显式空格（应被替换为 CJKglue）、标点（fallback 到 punct 检测链）三种场景

## 已知未修复

- `\textcolor{red}{文字}` 右侧仍有 3.33pt 多余空间（`\special{color pop}` whatsit 阻断 kern pair 探测）
- 这是已有问题（not regression），属于 xeCJK whatsit 定点恢复策略的已知边界

## 归属

这是边界恢复状态机的第四个核心修复场景，与 #315（whatsit 打断）、#252/#476（ecglue 字体度量）、#324（宏路径提前输出 glue 遮蔽标记）并列。
