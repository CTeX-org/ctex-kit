---
name: "510-ruby-compatibility-boundary"
description: "决策: #510 的旧 ruby.sty 致命冲突已由禁载 CJK.sty 解决，但这不构成传统 CJK 私有协议兼容；推荐 PXrubrica，不在 xeCJK 中模拟旧 kern-marker 状态机"
metadata:
  type: decision
---

# 决策：只阻止旧 `ruby.sty` 加载冲突，不模拟传统 CJK 协议

## 结论

xeCJK 3.8.7 起通过 LaTeX 包禁载机制阻止传统 `CJK.sty`。当前 `ruby.sty` 的 `\RequirePackage{CJK}` 会被跳过并给出预期 warning，#510 报告的 `\CJKglue already defined` 和无法生成中文 PDF 已经解决，Issue 以 completed 关闭。

成功编译不等于完整兼容。旧 `ruby.sty` 直接依赖传统 CJK 的 `\CJKglue` 以及 `\lastkern=1/2` 私有标记；xeCJK 的 interchar/marker 状态机语义不同。定量测试显示 ruby hbox 不保留正常 CJK→CJK 外边界 glue，因此不在 xeCJK 中增加一套模拟旧协议的兼容层。

## 用户路径

XeLaTeX 的一般 ruby 使用 PXrubrica，并在 ctex/xeCJK 后加载。PXrubrica 的日文 ruby 分组和分配语义不保证与旧 `ruby.sty` 逐像素一致，用户应显式选择所需模式；汉语拼音用 xpinyin，但它不是任意 ruby 的通用替代品。以后只对具体可复现的边界、断行、标点或字体问题做定点调查。
