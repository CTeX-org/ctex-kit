---
name: 1001-boundary-capture-gap-fixes
description: 记录 PR #1001 修复 #996、#998、#1000 时发现的问题，包括 pending 跨盒子泄漏、盒子可见内容判断、嵌套 marker 传递、管道掩盖退出码，以及测试驱动引用已删除变量
metadata:
  type: feedback
---

# [Task Reflection]

## Task

分支 `fix-996-998-1000-boundary-capture` 在 #999 的 capture/register 框架上处理 #992 中剩余的三个问题：#996 为 Boundary→CJK 补上与 Boundary→Default 相同的源码空格检查，并阻止 pending 越过盒子分组；#998 处理 `\mbox{$x$}`、`\mbox{\vrule}` 等不触发 interchar 转换的内容；#1000 恢复 siunitx 单位命令左侧丢失的源码空格。

实现与基线提交为 085f4f86、14336c4d、c8c803bf、a1df81ef。本地审查随后发现 `\mbox{中\mbox{$x$}}` 仍会保留错误的 CJK 末类别，19fedf48 补上了嵌套盒子之间的 marker 传递。

## Expected vs Actual

- 预期：三个问题都是给现有框架补充边界条件，完整测试一轮即可结束。
- 实际：每项修改都暴露了原框架没有覆盖的情况。pending 是全局变量，会越过 `\setbox` 分组；仅凭是否观察到字符类别，无法判断盒子是否直接排出了 math 或 rule；盒子尺寸也不足以区分可见内容、留白盒子和已经排好后放入的盒子。第一轮完整测试还因为命令接了管道而掩盖了六项失败。

## What Went Wrong

1. **管道掩盖了测试命令的退出码。** 第一轮执行 `l3build check -q 2>&1 | tail`。shell 返回的是 `tail` 的退出码，而不是 `l3build` 的退出码；输出又被截断，因此 boundary-space02、cjkmath01、cjkmath02、fntef-space02、ref-ecglue01、ref-ecglue02 的差异没有立刻被发现。凡是依靠退出码判断成败的命令，都不应直接接管道。

2. **判断盒子是否有可见内容不能只看一个条件。** 第一版只检查 capture 是否观察到字符类别，无法识别 math 和 rule。第二版增加尺寸检查，却把 `\makebox[.6\linewidth]{}` 这类留白盒子和 thuthesis `\thu@pad` 中已经排好的盒子误认为新的可见内容。最终条件同时检查尺寸和末节点类型：宽度必须非零，高度或深度必须非零，末节点还必须是 char(0)、rule(3)、math(10) 或 kern(12)。末节点是 hlist(1) 或 glue(11) 时不作推断，因为框架无法据此判断里面的字符类别。

3. **推断出的首类别与实际观察到的末类别必须分开更新。** 第一版复用 `\@@_boundary_capture_class:n`，把推断出的 default 写入所有外层 `last_tl`，导致 `\fcolorbox` 命令内部的辅助盒子覆盖已经观察到的 CJK 末类别。改用 `\@@_boundary_capture_report_first:n` 后，只补外层尚未取得的首类别，但 `\mbox{中\mbox{$x$}}` 的外层盒子仍没有读取嵌套盒子留下的 marker。最终由 `\@@_boundary_box_set_last_from_node:` 在每层盒子结束时读取自身节点列表末尾的 marker，只更新本层末类别。

4. **旧基线也可能记录了错误行为。** boundary-space02 和 fntef-space02 的名字与注释都要求保留显式 `\ `，旧值 20pt、40pt 却来自前一项测试遗留的 pending。修复后变为 23.33pt、43.33pt，才与测试说明一致。更新基线前应同时检查测试说明、宽度结果和节点日志，不能只把旧 `.tlg` 当作正确答案。

5. **长期复用的测试驱动不应假定内部变量永远存在。** gh-assets 的 `\MatrixReset` 直接写入 `\g__xeCJK_reset_color_pending_bool`，但该变量已在 #999 删除。驱动现在先用 `\bool_if_exist:NT` 检查变量是否存在。共享驱动若必须引用内部变量，应列出依赖，并在变量可能被删除时检查其是否存在。

6. **PR 预览与已合并状态分开维护。** #996、#998、#1000 的 before/after 图片固定在 gh-assets 提交 `fcff1eb3`。#992 的状态表只记录已经合并并从合并提交重新验证的结果，因此本轮只在 PR 正文和 gh-assets README 中提供预览，没有提前修改 issue 状态表。

## Root Cause

- 测试命令的真实退出码经过了无关的管道命令，判断依据与实际执行结果脱节。
- #998 同时涉及运行时观察和节点列表信息，不能由一个函数无条件更新所有嵌套层。
- 历史基线建立时没有核对测试说明与断言值是否一致。
- gh-assets 的共享测试代码直接依赖 xeCJK 内部变量，框架重构时没有兼容保证。

## Missing Docs or Signals

- `reference/build-and-test.md` 需要明确说明：依靠退出码判断结果的命令不得直接接管道。
- `xecjk-architecture.md` 已补充外层盒子必须读取嵌套盒子末尾 marker 的说明，以及 472 个矩阵比较的统计。
- gh-assets 的共享矩阵驱动仍缺少内部变量依赖清单。

## Promotion Candidates

- 将“测试命令不要接会改变退出码的管道”写入通用测试约定，而不只用于 `git push`。
- 将盒子可见内容的三个检查条件写入 xeCJK 架构文档。
- 明确 `report_first` 只补首类别；外层盒子的末类别由该层结束函数读取节点列表末尾的 marker 后更新。

## Follow-up

- 如果再次出现共享测试驱动因内部变量删除而失效，应在 gh-assets 增加统一的内部变量依赖清单和兼容检查。
- 运行依靠退出码判断结果的长命令时，保留完整输出并单独检查原命令的退出码。

## 相关引用

- 实现：`xeCJK/xeCJK.dtx` 中的 `\@@_glue_check_expire_stale:`、`\@@_boundary_if_capture_box_visible:`、`\@@_boundary_capture_report_first:n`、`\@@_boundary_box_set_last_from_node:` 和 siunitx package hook。
- 测试：`xeCJK/testfiles/boundary-crossbox01.lvt/.tlg`、`command-boundary01.lvt`、`siunitx-ecglue01.lvt/.tlg`、`boundary-space02.tlg`、`fntef-space02.tlg`，以及 `ctex/test/testfiles-ctxdoc/resize-function.tlg`。
- gh-assets：`fcff1eb3`、`issues/992/showcase-lib.tex`、`command-boundary-*-matrix.tex`。
- 架构与决策：[[../../architecture/xecjk-architecture.md]]、[[../decisions/992-command-boundary-capture-register.md]]。
