# 决策: #826 xeCJKfntef 右侧 CJKglue 恢复

## 问题

`\CJKsout{文字}`、`\CJKunderdot{文字}` 等 xeCJKfntef 命令右侧的 CJKglue 未被正确恢复。

## 根因

xeCJKfntef 的内容在 ulem 的 hbox 中排版，不在主 hlist 上。当 hbox 关闭后（`}` 后），XeTeX 的 interchar class 不再是 CJK，源码空格产生 finite inter-word glue。该 glue 叠在 xeCJK 先前写下的 CJK kern pair 标记（`CJK` / `CJK-space` / `CJK-widow`）上方。

`\xeCJK_check_for_glue:` 的 glue 分支原来没有"揭开 glue 查看下方标记"的探测逻辑。

## 方案

新增 `\@@_check_for_glue_skip:` 函数处理 `\@@_if_last_glue:TF` 为真的分支。

### 处理流程

1. 保存 `\lastskip`
2. 判断 glue 是否 finite：
   - 非 finite（fil 级）：跳过，回退到 `\xeCJK_check_for_xglue:`
   - finite：`\unskip` 移除 glue，探测下方 kern pair
3. 若下方是 CJK kern pair 标记：移除并放置 CJKglue
4. 若不是 kern pair：恢复 glue，调用 `\@@_check_for_glue_auxii:`

### 关键设计决策

- **只处理 finite glue**：排除 listings 等插入的 fil 级 glue，避免破坏其列对齐
- **非 kern pair 回退到 `\@@_check_for_glue_auxii:`**：该路径包含 punct 检测链，保证标点识别正常；不能回退到 `\xeCJK_check_for_xglue:`
- **不处理 whatsit 层级**：`\textcolor{red}{文字}` 右侧的 `\special{color pop}` whatsit 隔断了 kern pair 探测，但无法安全区分 xcolor `\special` 和 XeTeX native word 节点

## 已知未修复

- `\textcolor{red}{文字}` 右侧仍有 3.33pt 多余空间（`\special{color pop}` whatsit 阻断 kern pair 探测）
- 这是已有问题（not regression），属于 xeCJK whatsit 定点恢复策略的已知边界

## 归属

这是边界恢复状态机的第四个核心修复场景，与 #315（whatsit 打断）、#252/#476（ecglue 字体度量）、#324（宏路径提前输出 glue 遮蔽标记）并列。
