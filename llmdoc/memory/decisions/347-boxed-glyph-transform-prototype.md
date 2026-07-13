---
name: "347-boxed-glyph-transform-prototype"
description: "决策: #347 的 interchar 装盒变换原型保留为未来整体重构的设计资料，但逐 code point 装盒无法局部接入当前 xeCJK 状态机，现阶段 not planned"
metadata:
  type: decision
---

# 决策：保留 #347 原型，不在当前状态机上局部接入

## 结论

在 interchar transition 中捕获内容、装盒后交给统一变换函数，在 plain XeTeX 层面可行，也可能成为未来重构 xeCJK 的方案原型；当前不提供公开逐字符旋转、抬升或通用装盒 hook，Issue 以 `not planned` 关闭。

## 当前架构障碍

特殊类必须为同类、所有 CJK/标点类和 Boundary 组合定义闭合状态。迁移测试中，同类相邻会进入同一个盒子整体旋转，后接 `FullRight` 会因没有关盒 transition 直接产生分组错误。加载顺序还会与导言区末尾的 `Others` 初始化发生覆盖关系。

逐 code point 装盒也不是正确的文本处理单位：IVS、分解 Hangul Jamo 和其他 shaping 序列必须连续进入字体 shaping；普遍加入 hbox 又会遮蔽 xeCJK 的 marker kern，影响标点度量、Boundary 恢复和第三方补丁。#908 的基线抬升实验从另一入口复现了标点错误与 `\lastkern` 遮蔽。

## 未来重构条件

若完整重构字符输入、分类、fallback、标点和节点生成，应捕获 shaping 后的 glyph cluster，把变换放在字体选择/fallback 与节点生成之间，并由统一状态机生成所有边界转换。这里拒绝的是现有实现上的局部增量，不是否定原型的长期价值。
