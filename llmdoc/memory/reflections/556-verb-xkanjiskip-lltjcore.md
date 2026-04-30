---
name: 556-verb-xkanjiskip-lltjcore
description: ctex #556 修复反思：LuaLaTeX 下 \verb 前 xkanjiskip 被吞掉，根因是禁用 ltj-latex 后漏掉 lltjcore 的 verb 补丁
type: reflection
---

## 任务

修复 Issue #556：LuaLaTeX 下 `\verb` 前原本应自动插入的 xkanjiskip 消失，导致 CJK 与 `\verb` 之间的间距异常。

## 初始误判

最初把问题归因为 `verbatim@font` hook 中设置了 `autoxspacing=false`，直觉上认为这是关闭 xkanjiskip 自动插入的直接原因。

但进一步对照纯 `luatexja` 行为后发现，这个判断不成立：即使同样禁用 `autoxspacing`，纯 `luatexja` 仍能在 `\verb` 前得到正确结果。说明真正的问题不在“误伤 autoxspacing”，而在 ctex 的 LuaTeX 适配层与原生 luatexja 路径之间还有别的差异。

## 关键发现

### `\showbox` dump 揭示空 `\hbox{}` 才是阻断点

通过对比 ctex 路径与纯 luatexja 路径下 `\verb` 附近盒子节点列表的 `\showbox` dump，关键差异不是字体 hook，而是 `\verb` 内部用于起始定位的那个空盒子。

纯 luatexja 路径会在 `lltjcore.sty` 中把 `\verb` 里的 `\null`（本质是空 `\hbox{}`）替换为 `\vadjust{}`。这样既保留原始宏流程所需的结构，又不会在水平列表里插入一个真正的空盒节点。

而空 `\hbox{}` 一旦进入水平列表，就会打断 luatexja 对前后字符边界的连续观察，导致本应自动插入的 xkanjiskip 不再生成。因此，真正阻断 xkanjiskip 的不是 autoxspacing 开关，而是这个空盒节点。

## 认知修正

问题定位应从：

- “`verbatim@font` hook 误伤 autoxspacing”

修正为：

- “ctex 通过 `\@namedef{ver@ltj-latex.sty}{}` 禁用了 `ltj-latex`，从而连带跳过了 `lltjcore.sty`；而 `lltjcore` 里包含了避免 `\verb` 前空 `\hbox{}` 阻断 xkanjiskip 的关键补丁”

因此，PR #792 的正确修复方式不是重新调整 `autoxspacing`，而是在 `ctex.dtx` 的 LuaTeX 引擎适配中移植 `lltjcore` 对 `\verb` 与 `\do@noligs` 的相关补丁，把缺失的行为补回来。

## 测试注意

### `\verb` 不能直接放进宏参数

为 `\verb` 写回归测试时，不能把它直接塞进测试辅助宏的参数里，否则会先撞上 `\verb` 的语法限制，而不是测到真正的间距行为。

更稳妥的做法是：

- 在 `\TEST` 一类辅助宏外部先用 `\setbox` 捕获包含 `\verb` 的水平列表；或
- 先用 `\edef` / 其他安全方式整理待比较的数据；
- 再把已经构造好的盒子尺寸、节点结果或标志值交给测试宏比较。

也就是说，测试应把“包含 `\verb` 的输入构造”与“断言逻辑”拆开，避免让 `\verb` 的参数禁忌污染测试框架本身。

## 可复用教训

- LuaTeX-ja 相关问题若只看选项开关，很容易把“表面配置差异”误判为根因；应尽快下沉到节点级别比对。
- `\showbox` 对 `\verb`、活跃字符和自动插胶问题尤其有价值，因为日志里能直接看到空盒、glue、penalty 等是否真的进入列表。
- 当 ctex 有意屏蔽某个上游 luatexja 包时，要同时审查该包是否还承担了“非表面依赖”的补丁职责；禁用入口包并不等于这些副作用可以安全丢弃。
