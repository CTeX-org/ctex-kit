---
title: "681: xeCJK 省略号断行分类修复"
type: reflection
---

# 681: xeCJK 省略号断行分类修复

## 问题

XeLaTeX 路线下，U+2025（․․）与 U+2026（…）默认属于 `LongPunct`。普通 `LongPunct` 在前方会走允许断行的路径，因此 TeX 可能在省略号前断行，表现为省略号可以出现在行首。

这与中文排版中省略号通常不应出现在行首的预期不符，也暴露出 xeCJK 标点系统里“字符集合名称”和“具体断行/胶水行为”之间并不是一一等价的直觉关系。

## 最终修复

最终没有把 U+2025 与 U+2026 从 `LongPunct` 直接移到 `MiddlePunct`，而是新增了一个正交属性 `NoBreakLongPunct`：

- 在 `\g_@@_special_punct_clist` 中加入 `nobreak_long`
- 通过现有 special punct 扩展机制自动生成 `\@@_punct_if_nobreak_long:NTF` 谓词
- 新增用户键 `NoBreakLongPunct` / `NoBreakLongPunct+` / `NoBreakLongPunct-`
- 默认值设为 `U+2025 U+2026`

这样 U+2025/U+2026 仍然保留在 `LongPunct` 中，因此“长标点”的对偶 kerning、相同长标点间 nobreak、boundary 处理等既有行为全部保留；与此同时，在需要决定“能否在其前断行”的路径上，再额外检查它是否属于 `NoBreakLongPunct`，从而禁止在省略号前断行。

对应实现上，xeCJK 修改了 3 处断行路径：

- `\@@_CJK_and_FullRight_glue:N`：`LongPunct + NoBreakLongPunct` 时改走 nobreak
- `\@@_Default_and_FullRight_glue:N`：同样改为 nobreak
- `\@@_punct_kern:NN`：当右侧相邻标点属于 `NoBreakLongPunct` 时禁止断行

同时补充了 `xeCJK/testfiles/ellipsis01.lvt` 与对应 `.tlg`，把“省略号前应为 `\penalty 10000`”固化为 l3build 回归测试。

## 为什么不是移到 `MiddlePunct`

最初看起来，把 U+2025/U+2026 从 `LongPunct` 移到 `MiddlePunct` 似乎就能让它们走 `\xeCJK_no_break:` 路径，从而修复 issue #681。但这个方案会把省略号整体切换到“居中标点”体系，进一步引入 `MiddlePunct` 专属的 glue / rule / 宽度语义副作用。

也就是说，`LongPunct` 与 `MiddlePunct` 并不是可随意互换的“标点标签”，而是两组绑定了不同排版行为的属性集合。省略号需要的只是“保留 LongPunct 行为，但在前面禁止断行”，这和 `MiddlePunct` 的设计目标并不相同。

因此，最终方案采用新增 `NoBreakLongPunct` 这一正交属性，而不是简单改换分类。

## 容易混淆的点

### `LongPunct` 与 `MiddlePunct` 是正交行为集合，不是可互换别名

这次修复再次说明，这两个集合的差异不只是名字：

- `LongPunct` 负责长标点相关的 kern、成对处理、边界行为等语义
- `MiddlePunct` 负责居中标点的宽度、glue/rule 与相关排版语义

因此，调整默认标点集合时，不能只看“这个字符看起来像哪类标点”，而要先确认它依赖的是哪条节点处理路径、哪组宽度语义和哪套断行规则。

### xeCJK 的 special punct 是可扩展属性系统

这次实现也暴露了 xeCJK 标点系统的一个重要扩展模式：

- 先在 `\g_@@_special_punct_clist` 中声明属性名
- 再由初始化逻辑生成对应的 seq 与判定谓词
- 用户键 `Foo` / `Foo+` / `Foo-` 通过统一的 `\@@_set_special_punct:nn`、`\@@_add_special_punct:nn`、`\@@_sub_special_punct:nn` 接口接入

因此，当某个字符需要“在保留原有主分类行为的前提下，再附加一条独立规则”时，优先考虑新增正交 special punct 属性，而不是硬把它塞进另一个已有分类里。

## 教训

- xeCJK 标点默认集合背后绑定的是具体的断行、kern、glue、rule 与 boundary 处理，不能只按名称直觉理解。
- `LongPunct` 与 `MiddlePunct` 是不同维度的行为集合；想改变某个局部行为时，应优先寻找是否能增加正交属性，而不是简单搬移字符。
- xeCJK 的 special punct 采用“clist + seq + 自动生成 predicate”的扩展模式，这为类似修复提供了低侵入、可维护的实现路径。
- 对这种“默认字符集合 + 断行路径”类修复，最稳妥的方式仍然是补充节点/penalty 级回归测试，而不是只看肉眼排版结果。
