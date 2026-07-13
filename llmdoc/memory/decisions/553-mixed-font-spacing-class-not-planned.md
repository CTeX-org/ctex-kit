---
name: "553-mixed-font-spacing-class-not-planned"
description: "决策: #553 的 CJK 字体 + Default 间距在 XeTeX 上技术可行，但混合类会破坏 xeCJK 的 CJK/非 CJK 二分；当前推荐显式局部字体命令，不提供数字特例并以 not planned 关闭"
metadata:
  type: decision
---

# 决策：不把 #553 的混合字体/间距字符类产品化

## 背景

#553 希望 ASCII 数字使用 CJK 字体，但保留西文间距语义：`abc123def` 的字母与数字之间不增加 `CJKecglue`，`中文012中文` 的 CJK 与数字之间仍有正常中西文间距。直接把数字声明为 `CJK` 类会同时改变字体和间距，无法满足要求。

早期回复据“每个字符只有一个 `\XeTeXcharclass`”推断字体选择与间距无法解耦。后续原型证明该推断过强：新类可复制 `Default` 的转换，只在进入和离开数字 run 时打开、关闭 CJK 字体分组。节点列表同时确认数字字体、CJK–数字 glue 和字母–数字无 glue 三项行为，说明引擎层允许这种组合。

## 决策

不新增数字专用或通用 `CJKFontOnly` 字符类，#553 以 `not planned` 关闭；结论是“技术可行但当前不应产品化”，而非“XeTeX 无法实现”。

对源文件中可识别的数字，推荐用 `\newfontfamily` 定义局部字体命令并显式包裹。数字继续属于 `Default`，现有 interchar 转换自然给出目标间距。

若未来出现无法显式标记的实际文档，应把需求重新表述为按 Unicode 范围选择组合字体并保留字符原有排版语义。讨论接口前必须明确正文与数学、页码和计数器、交叉引用、URL、代码，以及当前 CJK family、字重和字形的跟随规则；接口不应只为 ASCII 数字增加特例。

## 理由

xeCJK 当前用 `\g_@@_non_CJK_class_seq` 与 `\g_@@_CJK_class_seq` 表达基本二分。混合类在字体维度属于 CJK、在间距维度属于 `Default`，会影响标点转换、Boundary 恢复、math/`CJKmath`、listings/verbatim、xeCJKfntef/ulem、fallback、字体族切换、颜色、链接及外部字符类。普通文本原型只证明局部可行性，不能覆盖这些架构责任。

历史 #44 也显示，扩张 spacing 状态空间曾产生大量边界 bug。现有需求证据只有原报告和一条附议，不足以承担新的稳定接口及跨子系统测试矩阵。

## 验证与关联

调查使用两类证据：可见对比图用于说明直接 `CJK` 类的两侧间距错误，`\showbox` 节点列表用于确认真实字体节点与 glue。混合类和显式字体命令得到相同目标宽度与边界结构，排除了只凭截图判断的歧义。

架构说明见 `llmdoc/architecture/xecjk-architecture.md`“字体选择与间距语义并非引擎级绑定”一节。新增字符类的反向审计教训见 [[./382-dash-width-and-ligature-opt-in]] 与 `llmdoc/memory/archive/2026-07-13/382-dash-width-punct-if-right-and-cmap-metrics.md`。
