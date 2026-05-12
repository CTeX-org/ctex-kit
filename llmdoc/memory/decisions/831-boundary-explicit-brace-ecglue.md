# 决策: #831 显式 } / \mbox / \textcolor 右侧多余 inter-word glue

## 问题

多种场景在 CJK 字符后产生多余的 inter-word glue：

1. `前{中} 后` — 显式 `}` 后的源码空格
2. `前\mbox{中} 后` — `\mbox` 创建的 hbox 隔离了 CJK kern pair 标记
3. `\textcolor{red}{中}后` — `\reset@color` 通过 `\aftergroup` 插入 color-pop whatsit，覆盖了 CJK kern pair

## 根因

三种场景的共同根因：XeTeX 在 `}` 或 hbox/whatsit 之后看到的 interchar class 不再是 CJK，后续源码空格被排版为 inter-word glue，叠在 CJK kern pair 标记上方（或标记被隔离在 hbox/whatsit 之后）。

### 场景 1：显式 `}` (catcode 2)

显式 `{}`（catcode 1/2）触发 XeTeX 的 Boundary class (255/4095)。`\xeCJK_CJK_and_Boundary:w` 在处理边界时执行 `\@@_boundary_group_end:n`，结束 TeX 分组。分组结束后，源码空格产生 inter-word glue 叠在 CJK kern pair 标记上方。

### 场景 2：`\mbox` (hlist)

`\mbox{中}` 产生 hbox（hlist 节点类型 1），CJK kern pair 标记被隔离在 hbox 内部。主 hlist 上 `\lastkern` 无法穿透 hbox 看到标记 kern。

### 场景 3：`\textcolor` (color-pop whatsit)

xeCJK 原来只补丁了 `\set@color`（颜色推入），未补丁 `\reset@color`（颜色弹出）。`\textcolor{red}{中}` 结束时 `\reset@color` 通过 `\aftergroup` 插入 color-pop whatsit，该 whatsit 覆盖了 CJK kern pair 标记，导致 `\lastkern` 检测失败。

## 方案

### 阶段 1：CJK->Boundary handler 中 catcode 2 的 boolean set 点

在 CJK->Boundary handler 中增加 `\token_if_group_end:NTF` 检查：当 peek token 是 catcode 2（`}`）时，在调用 `\@@_boundary_group_end:n` **之前**设置 `\g_@@_ulem_pending_bool`。

时序约束：必须在 `\@@_boundary_group_end:n` 之前设置 boolean，因为该函数内部调用 `\xeCJK_class_group_end:` 结束 TeX 组，虽然 `\g_@@_ulem_pending_bool` 是全局的不受分组恢复影响，但理解时序对正确性推理很重要。

`\ `（control space）也触发 CJK->Boundary，但其 peek token 是控制序列而非 catcode 2 字符，`\token_if_group_end:NTF` 能正确区分。

### 阶段 2：`\reset@color` 补丁

新增 `\reset@color` 定点补丁（`xeCJK/xeCJK.dtx` ~line 9588-9601）。在 color-pop whatsit 插入后，重新放置 kern pair 标记并设置 `\g_@@_ulem_pending_bool`，使后续 `\@@_check_for_glue_skip:` 能正确处理 glue-on-kern-pair。

这将定点颜色补丁从只覆盖 `\set@color`（颜色推入）扩展到同时覆盖 `\reset@color`（颜色弹出），与 hyperref `\Hy@BeginAnnot` 补丁的"进入端补丁"策略保持一致。

### 阶段 3：hlist 回退路径

在 `\@@_check_for_glue_skip:` 中新增 hlist 回退路径（`xeCJK/xeCJK.dtx` ~line 3563-3582）。当 `\lastkern` 不存在时，检查 `\lastnodetype` 是否为 hlist（类型 1），并通过 `\g_@@_last_node_tl` 判断 hbox 内的 CJK 内容类型。

关键设计：hlist 路径不依赖 `\g_@@_ulem_pending_bool` 门控——`\mbox` 不设置 boolean，但 hlist + `\g_@@_last_node_tl` 的组合本身足够安全。限定 hlist 类型避免了 whatsit（如 `\write`，lastnodetype = 4）的干扰。

### `\@@_check_for_glue_skip:` 重构

将 finite/shrink 检查提到 boolean 门控之前，形成两条分支路径：
- **kern 路径**：由 boolean 门控，保护 `space=true` 模式
- **hlist 路径**：不依赖 boolean，通过 `\g_@@_last_node_tl` 自主判断

## 复用 `\@@_check_for_glue_skip:` 消费端

所有三种场景最终都通过 `\@@_check_for_glue_skip:` 的统一消费端处理，无需为每种场景新增独立的恢复逻辑。

## 测试覆盖

- `xeCJK/testfiles/boundary-space02.lvt/.tlg`：覆盖显式分组、`\ ` 不误触发场景
- `xeCJK/testfiles/thuthesis.lvt/.tlg`：覆盖 `\mbox` 和 `\textcolor` 场景

## 归属

此修复将 `\g_@@_ulem_pending_bool` 的语义从"fntef 专属标记"扩展为"已知会产生 glue-on-kern-pair 的场景标记"，生产端来自三个来源：fntef 模块、CJK->Boundary handler（catcode 2）、`\reset@color` 补丁。消费端统一在 `\@@_check_for_glue_skip:` 的 kern 路径和 hlist 路径。
