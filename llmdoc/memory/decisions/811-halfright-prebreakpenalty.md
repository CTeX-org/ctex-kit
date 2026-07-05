# 决策: 为 HalfRight 类整体添加条件禁则，而不是拆分字符类

- 日期: 2026-05-03
- 关联: Issue #811

## 上下文

xeCJK 新增了实验性选项 `experiment/halfright-prebreakpenalty`，用于阻止半角右标点在 `CJK -> HalfRight` 与 `FullRight -> HalfRight` 过渡中被排到下一行行首。该能力建立在 xeCJK 既有的 `HalfRight` 字符类之上，而不是为个别字符单独建类。

当时 `HalfRight` 类固定包含 13 个字符：`!`、`"`、`%`、`'`、`)`、`,`、`.`、`:`、`;`、`?`、`]`、`}` 与 `U+232A`。这些成员全部属于收尾型右侧标点。

> 更新（#431，2026-07）：`LatinPunct` 选项默认 `true`，会把 U+00B7/U+2019/U+201D/U+2025/U+2026/U+2027 一并动态归入 `HalfRight`（`LatinPunct=false` 时移出）。上述"固定 13 个字符"仅描述 #811 落地时的静态基线，`HalfRight` 类成员现依赖 `LatinPunct` 开关状态。详见 [[431-latinpunct-option]]。

## 决策

1. `experiment/halfright-prebreakpenalty` 直接对整个 `HalfRight` 类生效。
2. 不为其中部分字符再拆出新的 interchar class。
3. 在 `FullRight -> HalfRight` 过渡中完整覆写既有 interchartoks，而不是在原定义末尾追加 penalty。

## 理由

- `HalfRight` 的 13 个既有成员语义一致，都是右侧收尾标点；为了只给其中部分字符加禁则而拆类，会增加字符分类、声明与维护复杂度，但当前没有带来可见收益。
- 该选项是实验性能力，先复用现有 `HalfRight` 整体类可以把实现与测试面控制在最小范围内。
- `FullRight -> HalfRight` 路径上，penalty 必须位于 `\@@_punct_glue:NN` 之前，才能真正阻止在 glue 之前发生断行；如果只是对原 interchartoks 追加 penalty，断行点已经形成，无法达到禁止半角右标点行首出现的目的。

## 关键约束

- penalty 的顺序约束是本决策的核心：必须先插入 penalty 10000，再执行 `\@@_punct_glue:NN`。
- 因此前者适合用 `\xeCJK_inter_class_toks:nnn` 覆写 `FullRight -> HalfRight`，而不是用追加式接口保留旧顺序。
- `CJK -> HalfRight` 路径没有同样的 glue 顺序问题，可以在既有定义上条件追加 `\xeCJK_no_break:`。
- 只有当未来 `HalfRight` 内部出现明确且稳定的语义分裂时，才值得重新评估是否拆分字符类。

## 相关

- 源码: `xeCJK/xeCJK.dtx`
- 测试: `xeCJK/testfiles/halfright-nobreak01.lvt`
