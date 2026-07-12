---
name: "158-165-jamo-cj-interchar-classes"
description: "决策: Hangul Jamo 按 L/V/T 状态转移区分音节内 shaping 与音节间 CJKglue；日文 CJ 用默认 normal、可选 strict 的独立类增加行首禁则而不改变字距"
metadata:
  type: decision
---

# 决策：用专用 interchar 类分别表达 Hangul 音节状态与 CJ 严格禁则

## #158 Hangul Jamo

旧 `HangulJamo` 单类零注入能保持分解音节 shaping，却无法区分音节内部与相邻音节，导致音节间 `CJKglue` 丢失，listings 又按每个 code point 计一格。

采用 Unicode 17 `Hangul_Syllable_Type` 的 L/V/T 三类。只对 UAX #29 音节延续对 L→L、L→V、V→V、V→T、T→T 清空 interchar toks；其余 L/V/T 组合复制 CJK→CJK。listings 对 L 计一格、V/T 计零宽。旧 `HangulJamo` 类保留为空壳兼容入口。

## #165 Conditional Japanese Starter

CJ 字符继续默认按普通 `CJK` 处理，避免恢复历史上的标点压缩问题。新增 `CJLineBreak=normal|strict`；strict 才把 Unicode 17 `Line_Break=CJ` 集合归入 `CJStarter`，复制普通 CJK 字距，并在进入该类前插入 penalty 10000。

`FullRight→CJStarter` 必须把 penalty 放在标点胶之前。该转移使用命名 helper，并在 xeCJKfntef 的 ulem 交换表中提供专用实现，确保下划线环境仍按 fntef 路径处理 glue 与标点。

## 验证

`xeCJK/testfiles/jamo-cj01.lvt` 同时断言字符类、shaping/间距事件、`\CJKsymbol`、选项分组与 reset、严格 penalty、listings 单元宽度及 fntef helper 交换。PR #969 的修复前后 MWE 与截图存于 `gh-assets` 的 `issues/158/` 和 `issues/165/`。
