---
name: "931-biblatex-let-shadow"
description: "决策: #931 biblatex 补丁点选 `\\let` 目标 `\\blx@pagetracker` 且 hook 时机改用 `\\@@_at_end_preamble:n`——补丁点必须挂到宏包内部 `\\let` 拷贝的目标而非源，且必须在 `\\let` 执行后装 patch，`\\@@_package_hook:nn` 对 nested style-load 场景不够晚"
metadata:
  type: decision
---

# 决策：#931 biblatex 补丁点选 `\let` 目标 + hook 时机延到 preamble 末

## 背景

xeCJK issue #931：中文参考文献条目首字符前多出一段空白。根因是 biblatex `\blx@pagetracker` 内的 `\protected@write` 产生的 whatsit 遮蔽了 `\g_@@_last_node_tl` 判定路径，`\@@_recover_glue_whatsit:` default 分支误吐 `\CJKecglue`。与 #920 l3doc `\codeline@wrindex` write 同源，属于 [[../reflections/910-verb-null-hbox-drain]] 中提到的"第三方 `\write` whatsit 误触发 default 分支"系列问题。

按 xeCJK 已有补丁模式，直觉是 patch `\blx@pagetracker@context`（write whatsit 的宿主函数）。但实测该 patch 完全不生效，`\iow_term:x` 打点无输出。

## 候选方案

**方案 A（采纳）**：补丁点选 `\let` 目标 `\blx@pagetracker`，hook 时机改用 `\@@_at_end_preamble:n`。

**方案 B（初次尝试，被否）**：补丁点选 `\blx@pagetracker@context`（write whatsit 的定义处），hook 时机用 `\@@_package_hook:nn { biblatex }`。

**方案 C（未采纳）**：走 [[873-880-fixed-point-vs-default-narrowing]] 预留的"未来 default 分支收窄独立 PR"方向——在 `\@@_recover_glue_whatsit:` default 分支加 pending boolean gate，只允许已知调用方（`\set@color` 等）显式置位时才吐 ecglue。

## 决策

采纳方案 A。

## 理由

- **方案 B 的时序失败**（关键证据）：biblatex 的 `authoryear.bbx` 通过 `\ExecuteBibliographyOptions{...pagetracker,...}` 在**加载时**展开 `\blx@opt@pagetracker@page`，其内部执行 `\let\blx@pagetracker\blx@pagetracker@context`——`\let` 是**值传递**，`\blx@pagetracker` 冻结到执行 `\let` 那一刻的 `\blx@pagetracker@context` meaning。`\@@_package_hook:nn` 展开为 `package/biblatex/after` hook，fire 时机是 biblatex 主 `.sty` 全部执行完；但 biblatex 主 sty L16439 `\RequireBibliographyStyle{\blx@bbxfile}` **在 sty 内部**加载 `authoryear.bbx`，也就是 hook fire 之前 `.bbx` 已经加载并完成 `\let`。方案 B 只改到 `\blx@pagetracker@context`（`\let` 源），但 `\blx@bibitem` 实际调用的 `\blx@pagetracker`（`\let` 目标）指向**旧拷贝**，永不进 patch 路径。
- **方案 A 的正确性**：把补丁点改到 `\let` 目标（`\blx@pagetracker`）本身，hook 时机改到 `\@@_at_end_preamble:n`（`begindocument/before`）——此时 `.bbx` 早已加载完，`\blx@pagetracker` 已经 `\let` 到最终目标（可能是 `\blx@pagetracker@context` / `\blx@pagetracker@spread` / `\relax`，取决于 `pagetracker` 选项值）。patch 直接 wrap `\blx@pagetracker` 本身，`\let` 目标不管指向何处都能捕获。
- **方案 C 的推迟理由**：default 分支收窄涉及全 xeCJK 状态机的一致性验证（`\set@color` / hypdoc / hyperref 等既有 patch 都依赖 default 分支才能正确恢复颜色 whatsit 后的边界）。参见 [[../reflections/809-810-hyperref-annot-ecglue]] "关键约束 1：不删除 `\__xeCJK_recover_glue_whatsit:` 的 `default` 分支"。当前"第三方 `\write` whatsit 误触发"仅积累到 3 例（#910 verb 后 setlanguage / #920 l3doc `\codeline@wrindex` / #931 biblatex `\abx@aux@page`），未到推动独立收窄 PR 的阈值。

## 关键约束

### 1. 补丁点必须挂在 `\let` 目标而非 `\let` 源

宏包如果通过"选项驱动 → `\let\A\B`"这种间接绑定把可选行为绑定成硬拷贝，patch `\B` 只能改到源函数，`\let` 目标 `\A`（真正的被调用者）已经**在 `\let` 那一刻冻结**，之后再改 `\B` 不影响 `\A`。判定方法：先从**实际调用者**（本例是 `\blx@bibitem`）逆向 grep，找到"最终被调用的控制序列名"，再判断该名字是否是 `\let` 目标。

### 2. Hook 时机必须晚于 `\let` 执行

`\@@_package_hook:nn { pkg }` 对"包主 sty 内部 nested `\Require*Style`（会立即 exec 选项 + `\let`）"这类场景不够晚。判定方法：先在 `pkg.sty` 里 grep `\RequireBibliographyStyle` / `\RequireCitationStyle` / `\LoadClass` / `\@ifpackageloaded{child} then LoadIt` 等 nested load 语句；若存在，且该 nested style 里有 `\ExecuteBibliographyOptions` / `\let` 等运行时绑定，`\@@_package_hook:nn` 就不够晚，必须选 `\@@_at_end_preamble:n` 或 `\@@_after_preamble:n`。

### 3. 保留 `\@@_recover_glue_whatsit:` 的 default 分支

引用 [[../reflections/809-810-hyperref-annot-ecglue]] 与 [[../reflections/910-verb-null-hbox-drain]]：`color` / `xcolor` 的合法恢复仍依赖 default 分支跨颜色 whatsit 续接边界语义。删掉 default 分支会把 #807 等既有修复破坏。本次修复通过在 biblatex 一侧下 patch 清空 `\g_@@_last_node_tl`，让下游探到 whatsit 时 default 分支条件不成立，不影响 default 分支本身的合法能力。

## 后续

若未来第 4 例、第 5 例…… 第三方 `\write` whatsit 误触发 default 分支的场景继续积累，达到"补丁点分散不可维护"的阈值时，再评估 [[873-880-fixed-point-vs-default-narrowing]] 预留的 default 分支收窄独立 PR 方向。

## 落地引用

- 实现：`xeCJK/xeCJK.dtx` `\@@_patch_biblatex_pagetracker:` 段（挂在 `\@@_at_end_preamble:n`）。
- 回归测试：`xeCJK/testfiles/biblatex-ecglue01.lvt` / `.tlg`。
- 反思：[[../reflections/931-biblatex-pagetracker-let-shadow]]。
- 上游证据链：`biblatex.sty` L10195（`\blx@pagetracker@context`）、L15618（`\let\blx@pagetracker\blx@pagetracker@context`）、L16439（`\RequireBibliographyStyle`）、`authoryear.bbx` L147（`\ExecuteBibliographyOptions{...pagetracker,...}`）。
