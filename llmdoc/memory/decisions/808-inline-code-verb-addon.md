---
name: "808-inline-code-verb-addon"
description: "决策: #808 的真实需求是行内代码网格而非字体族级 CJKecglue；使用语义化局部命令组合 tt 字体与 xeCJKVerbAddon，不修改全部 texttt 的断行行为"
metadata:
  type: decision
---

# 决策：#808 使用语义化行内代码命令，不增加字体族级 glue

## 结论

#808 要求代码片段内部的 CJK/Latin 字符保持等宽网格、片段外部仍有正常正文间距。`\texttt` 只切换字体，并不代表代码；把 `CJKecglue` 绑定到字体族会错误影响允许断行的等宽普通文字。

现有公开 `\xeCJKVerbAddon` 已按当前等宽字体度量调整 CJK–CJK/CJK–Latin 间距与全角/半角网格，并禁止作用域内断行。对宏参数形式的短代码，使用局部语义命令先切换 `\ttfamily`、再调用 addon；特殊字符需要 verbatim 扫描时使用 `\verb`、`\lstinline` 等既有入口。

## 验证边界

使用报告字体 Maple Mono NF CN 的节点测试确认：默认 `\texttt` 含两处内部 `CJKecglue`，语义命令移除这两处 glue，同时保留片段外侧正常正文边界。窄行测试也确认 addon 会禁止内部断行；这对短代码是预期语义，对长篇等宽正文则会造成 overfull，因此不得全局挂到所有 `\ttfamily`/`\texttt`。

若未来出现“混排等宽普通文字必须允许断行且取消可见间距”的独立需求，应重新设计断行模型，不能从 #808 推导出字体族级 glue 接口。
