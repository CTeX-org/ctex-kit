# 决策：隔离 xeCJKfntef 装饰内容的 PDF 文本语义

## 背景

xeCJKfntef 的波浪线、删除线、着重号和自定义装饰可以由真实字符或数学内容组成，再由 `ulem` 的 leaders 重复排出。这些内容在页面上只是装饰，却仍属于 PDF 内容流中的文字；复制、搜索或文本提取时会混入 `:`、`/`、`.`、`*` 等字符。Issue #1017 要求排除这类污染，同时保持现有页面效果。

## 决定

在所有线条和符号装饰共用的 `\xeCJK_fntef_sbox:n` 中，用空的 `ActualText` 包住装饰盒。若 LaTeX 提供 tagging 接口，则只在构造装饰盒期间调用 `\tag_suspend:n` 和 `\tag_resume:n`，避免盒内数学内容生成的内层标记穿过外层 `ActualText`。

这套处理与既有的 boundary capture 暂停／恢复同时保留。空 `ActualText` 和 tagging 暂停负责 PDF 文本语义；capture 暂停／恢复负责 xeCJK 命令边界状态。两套机制解决不同问题。

## 未采用的方案

- 不单独依赖 Artifact。不同阅读器和 Poppler 对 Artifact 的复制、搜索和文本提取处理不一致，不能为 #1017 建立稳定的可观察契约。
- 不为本问题把装饰改写为 `l3draw`。绘图方案会改变 leader、断行和线条连接的实现，范围远大于文本语义修复；空 `ActualText` 能在不改变版面的前提下直接解决提取污染。
- 不只使用外层空 `ActualText`。tagged PDF 中的内层数学标记可能重新暴露装饰字符，因此仍需在最小范围暂停 tagging。

## 验证与范围

`xeCJK/testfiles/fntef-actualtext01.lvt` 覆盖八类装饰入口，并固定空 `ActualText` 与 tagging 暂停／恢复的调用。普通 PDF 和 tagged PDF 都要实际检查文本提取；页面视觉另用同条件高分辨率栅格或坐标证据验证。#1017 的结果是两种 PDF 都只提取正文，修复前后 300 dpi 栅格差为 `AE=0`。

本决策只解决 #1017 的复制、搜索和文本提取问题。它不改变装饰盒尺寸、leader 类型或绘制位置，也不解决 #1012 所讨论的线条重叠、波浪相位和阅读器抗锯齿现象。

运行时依赖 `accsupp` 与 tagged PDF 测试依赖 `latex-lab`、`pdfmanagement`、`tagpdf` 必须同时进入包级依赖声明和 `.github/tl_packages`。本变更登记在尚未发布的 xeCJK `v3.10.5`。

## 相关资料

- Issue：#1017；相关但不在本次范围内：#1012。
- 实现：`xeCJK/xeCJK.dtx` 中的 `\xeCJK_fntef_sbox:n`。
- 测试：`xeCJK/testfiles/fntef-actualtext01.lvt/.tlg`。
- 反思：[[../reflections/1017-fntef-actualtext.md]]。
