---
name: 671-cjkpunct-rglue-nobreak
description: CJKpunct #671 修复反思：段末右标点 rglue 断行问题的调试经验与节点级测试技术
type: reflection
---

## 任务

修复 CJKpunct issue #671：段末全角右标点（如"。"）后出现多余空行。

## 修复

在 `CJKpunct/CJKpunct.dtx` 第 420 行，右标点 class 2 的 `rglue`（`\hskip`）前加 `\nobreak`，阻止 TeX 在此处断行。

## 关键调试经验

### `\showbox` 是 CJKpunct 节点调试的首选工具

CJKpunct 的标点挤压通过 rule/glyph/rule/glue/kern 组合实现，只有 `\showbox` 能完整展示节点序列。文档或源码描述的"逻辑序列"可能过度简化。

### `\lastkern`/`\lastpenalty`/`\lastnodetype` 在 hbox 构建中不可靠

CJKpunct 的 `{{{...}}}` 三层分组 + CJK 追踪 kern 机制导致：在 `\hbox_set:Nn` 内部直接用 `\last...` 原语无法看到预期节点。原因是 CJK 追踪 kern 可能在分组关闭后通过 `\aftergroup` 添加。

**正确做法**：先完整构建 hbox，再用 `\unhbox` 展开到新 hlist，然后剥离节点：
```tex
\setbox0=\hbox{ 测。 }
\setbox2=\hbox{\unhbox0 \unkern\unkern\unskip \xdef\temp{\the\lastpenalty}}
```

### 捕获 `\last...` 值必须用 `\the` 扩展

`\count255=\lastnodetype\relax` 赋值方式不可靠（返回 8230 等垃圾值）。正确方式是 `\xdef\temp{\the\lastpenalty}` 在 hbox 内捕获，hbox 外读取。

### `\typeout` 在 hbox 内可能干扰节点列表

即使 `\immediate\write` 理论上不添加节点，在 CJK 活跃字符环境下仍可能导致 `\lastnodetype` 返回 -1。避免在探测节点时使用任何输出命令。

## 遗留项

- CJKpunct 的内部架构（标点挤压节点模型、class 1/2 分类、样式策略）尚未纳入 llmdoc stable docs
- CI 中未包含 CJKpunct 测试步骤（build-and-test.md 需更新）
