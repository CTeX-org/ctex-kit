---
name: 336-347-510-808-553-feature-request-triage
description: "反思: 连续调查旧 issue 时先还原真实需求、核实现有行为和现代替代，再用成功/失败 MWE、节点与截图分离已解决故障、剩余边界和不值得产品化的泛化接口"
type: reflection
---

# #336/#347/#510/#808/#553：从 feature 表述回到真实需求

## 任务

连续复核五个长期 issue：URL 外部字符类 API（#336）、逐字符装盒变换（#347）、传统 `ruby.sty` 冲突（#510）、`\texttt` 内混排间距（#808），以及 CJK 字体配合西文间距（#553）。共同目标不是尽量接受 feature request，而是确认原始故障是否仍存在、真实用户任务能否由现有机制完成，以及剩余缺口是否值得进入 xeCJK 的稳定架构。

## 先核实现有能力和现代生态

旧 issue 的表面 feature 往往是在当年约束下提出的实现方案，不等于今天仍需实现的产品需求。

- #336 真正需要可读 Unicode URL 和可选的 CJK 断行。`urlraw`/编码后 `url` 已解决显示与 target 分离，xeCJK 的 `Others` 层又能从导言区中的 external→Default action 派生 CJK transitions，无需公开通用继承 API。
- #510 的致命加载冲突已由禁载 `CJK.sty` 解决；一般 ruby 又有 PXrubrica。剩余的传统 kern-marker 语义不应被误包装成“既然能编译就完全兼容”。
- #808 不是字体族级 glue 配置，而是行内代码布局。现有 `\xeCJKVerbAddon` 已表达代码网格和断行语义，`\texttt` 本身只表达字体。
- #553 是 range-to-font/composite-font 路由，不是数字类本身。可显式标记时局部字体命令已经满足核心排版结果。

因此调查顺序应先查当前源码、历史版本、上游包和现代替代，再决定是否仍有 feature gap；不能从十年前的 workaround 直接推导新 API。

## 不可能性与可行性都要用最小反例验证

#553 先前依据“每个字符只能属于一个 `\XeTeXcharclass`”断言字体与间距不能分离，混淆了 class 编号唯一与 transition 能执行的动作。复制 `Default` transitions、只增加 CJK 字体分组的最小原型立即构成反例。反过来，#347 的 plain XeTeX 原型只证明单个边界可装盒，迁移到完整 class 矩阵后，同类相邻会合盒，后接 `FullRight` 会留下未闭合分组。

成功 MWE 与失败 MWE同样重要：成功例证明最小机制存在，失败例负责暴露状态机未闭合的维度。#336 还说明加载顺序属于行为的一部分——同一条 external→Default action 在导言区可传播，到正文期才赋值则为时已晚。

## 验证必须覆盖用户目标和隐藏副作用

截图适合说明肉眼结果，节点和日志负责证明路径：#553 用字体节点、glue 与盒宽确认真实字体切换；#808 用节点确认内部 glue 消失、外部 glue 保留，再用窄行测试暴露 addon 禁止断行；#510 在“原 MWE 能编译”之外用放大的 `CJKglue` 检查 ruby hbox 外边界，证明传统协议并未兼容；#347 则保留预期失败日志说明哪个 transition 没有闭盒。

这形成可复用的多维验证：目标视觉、节点结构、加载时序、断行/边界和失败路径缺一不可。只给一张“看起来正确”的截图，容易把兼容层、替代路径或偶然同名宏误认为稳定语义。

## “能做”与“应做”是两次独立评审

#347 与 #553 的原型都证明局部技术可行，却同时跨越 xeCJK 的基本假设。逐 code point 装盒会切断 shaping cluster 并遮蔽 marker kern；混合字体/间距类在字体维度属于 CJK、在 spacing 维度属于 Default。产品化评估必须反向审计 class 枚举、标点、Boundary、math、listings、fntef、fallback、字体形状、颜色、链接和外部 class，而不能按原型代码行数估计影响面。

`not planned` 也应写清类型：#347 保留为未来整体流水线重构的原型；#553 等待明确的全局作用域和更多需求证据。#336/#808 则是现有公开能力已经覆盖真实任务；#510 是原始 crash completed，但拒绝模拟过时私有协议。精确说明“已解决什么、没有承诺什么”比笼统关闭更能防止未来误读。

## 可复用流程

处理旧 feature request 时依次完成：把表面方案翻译成用户任务；检查当前行为、历史时序和现代替代；分别构造成功与边界/失败 MWE；用节点、日志、截图和断行实验验证；最后独立审计架构假设、兼容面和作用域。若现有能力或语义化 wrapper 已覆盖任务，不新增更宽的底层配置；若原型只适合未来重构，明确保留设计价值但拒绝当前局部接入。

## 归属

对应决策见 [[../../decisions/336-external-interchar-class-others]]、[[../../decisions/347-boxed-glyph-transform-prototype]]、[[../../decisions/510-ruby-compatibility-boundary]]、[[../../decisions/808-inline-code-verb-addon]] 与 [[../../decisions/553-mixed-font-spacing-class-not-planned]]。稳定机制见 `llmdoc/architecture/xecjk-architecture.md` 的字符类、间距和兼容性章节。
