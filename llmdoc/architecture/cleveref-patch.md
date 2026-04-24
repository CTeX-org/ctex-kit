# cleveref 兼容补丁机制

## 背景

ctex 为使 `\p@<counter>` 兼容 `\labelformat` 语义，对 cleveref 宏包中涉及 `\refstepcounter` 的命令进行文本替换补丁。cleveref 自 CTAN 0.21.4 起长期无人维护，与新版 LaTeX 内核和 hyperref 存在多处不兼容。

## 补丁目的

cleveref 内部的 `\refstepcounter` 变体（`\refstepcounter@noarg`、`\refstepcounter@optarg`）以及 hyperref 重定义的 `\H@refstepcounter` 中，`\p@<counter>` 通过 `\the<counter>` 拼接标签值。ctex 需要在该拼接处插入 `\expandafter`，使 `\p@<counter>` 在展开时能执行 `\labelformat` 注入的格式宏，而不是被逐字拼接。

## 挂钩链

```
ctex.dtx %<*class|heading> 区段:

\ctex_varioref_hook:
  -> \seq_map_inline:Nn \c_@@_headings_seq { \ctex_fix_varioref_label:n }
  -> \ctex_at_end_package:nn { cleveref } { \ctex_cleveref_hook: }

\ctex_cleveref_hook:
  -> \bool_if:NT \l_@@_patch_cleveref_bool  (守卫开关)
  -> 根据 hyperref 是否加载，选择补丁目标:
     - 有 hyperref 且 implicit != false: \H@refstepcounter
     - 无 hyperref: \refstepcounter@noarg, \refstepcounter@optarg
  -> 始终补丁 \appendix

\@@_cleveref_hook_aux:N #1
  -> \ctex_patch_cmd_all:NnnnTF #1
     搜索 { \endcsname \csname the }
     替换 { \expandafter \endcsname \csname the }
```

## 关键代码位置

- `ctex/ctex.dtx` 约 9335-9420 行: `\ctex_varioref_hook:`、`\ctex_cleveref_hook:`、`\@@_cleveref_hook_aux:N`
- `ctex/ctex.dtx` 约 9374-9386 行: `patch/cleveref` 布尔开关定义
- `ctex/ctex.dtx` 约 12178-12185 行: `\ctex_patch_cmd_all:NnnnTF` 通用补丁机制（位于 ctexpatch 区段）
- docstrip 标签: `%<*class|heading>` (行 7660-9448)

## patch/cleveref 开关

`\ctexset{ patch/cleveref = <bool> }` 控制是否应用 cleveref 补丁。

- 类型: 布尔值，绑定到 `\l_@@_patch_cleveref_bool`
- 默认值: `true`
- 作用域: 在 `\ctex_cleveref_hook:` 执行前设置即可生效（通常在导言区）
- 场景: 当 cleveref 补丁与上游修复冲突或引起副作用时，用户可关闭

## Issue #725 问题根因链

LaTeX2e 2024-11-01 之后:

1. hyperref 不再重定义 `\refstepcounter`，改用 socket 机制。
2. LaTeX firstaid 新增 `\firstaid@cref@updatelabeldata`，挂在 label hook 上更新 cleveref 数据。
3. 该函数缺少 appendix 特判: 把 cleveref 正确的 `[appendix][1][2147483647]A.` 覆盖成 `[chapter][1][]A.`。
4. 结果: appendix 后章节的 cleveref 引用类型退化为 chapter 而非 appendix。

这不是 ctex 特有问题 -- 纯 `book + hyperref + cleveref`（不加载 ctex）同样失败。

## 上游追踪

| Issue | 状态 | 说明 |
|-------|------|------|
| `latex2e#1544` / `#1545` | 已修 | `\expandafter` 展开问题 |
| `hyperref#361` | Open | appendix 语义丢失问题 |
| `latex2e#2049` | 不修 | 上游明确不会在 firstaid 完整修复; cleveref 无人维护 |
| cleveref CTAN 0.21.4 | 停滞 | 长期无更新 |
