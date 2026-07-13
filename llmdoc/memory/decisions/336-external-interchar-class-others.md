---
name: "336-external-interchar-class-others"
description: "决策: #336 的 CJK URL 断行需求由既有 Others 兼容层覆盖；外部 class 在导言区结束前定义 Default transition 即可派生 CJK transitions，不新增通用字符类继承 API"
metadata:
  type: decision
---

# 决策：#336 复用 `Others` 兼容层，不新增字符类继承 API

## 结论

Unicode URL 的通用需求是分离显示文本与链接目标：biblatex/Biber 的 `urlraw` 用于可读标签，编码后的 `url` 用于 URI-safe target。CJK URL 若只需显示，可结合 `CJKmath` 与 `\nolinkurl`；若还需在 slash 和连续 CJK 中断行，可新建 slash interchar class，并在导言区结束前只定义它到 `Default` 的 action。

xeCJK 的 `\@@_set_others_toks:n` 会在导言区末尾发现外部 class，把 `external ↔ Default` tokens 传播到全部 CJK 类，并从 `NormalSpace`/`Default` 模板补齐其他转换。因此 #336 旧方案手写 xeCJK 内部转换并非必要，不新增“创建 class 并选择继承模板”的公开 API。

## 时序边界

传播只在导言区结束时发生。若 class 虽已分配，但 `external → Default` 到正文期才赋值，自动派生看不到该 action；旧 TeX.SE MWE 正有这一顺序问题。判断代码冗余时必须连同赋值时机一起验证，不能只比较最终 token 内容。

## 产品判断

具体 URL 需求已有简单方案和可断行方案，2018 年后没有出现超出 `Others` 机制的新消费场景。现有兼容层不等于稳定的通用继承接口；未来只有在 MWE 证明某类语义无法表达时，才另行设计公开 API。
