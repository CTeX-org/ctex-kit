## [zhnumber-v3.3](https://github.com/CTeX-org/ctex-kit/releases/tag/zhnumber-v3.3)

- 新增算筹数字 `\zhrod` 与 `\zhrodbox`（#366）。

## [zhnumber-v3.2](https://github.com/CTeX-org/ctex-kit/releases/tag/zhnumber-v3.2)

- 说明带选项形式在写入辅助文件时的行为：计数器值在写入时即已固定，样式留待读回时套用（#1008）。
- 带选项的 `\zhnum` 与 `\zhdig` 先把计数器展开为数值再交给处理数值的实现，使它们在写入 `.toc` 一类辅助文件时固定为当时的计数器值（#1008）。
- 修正 `\zhdigwithoptions` 把选项当作额外参数传给 `\zhnum_digits_counter:n` 的笔误——带选项的 `\zhdig` 此前直接报 `Use of \??? doesn't match its definition` 并输出乱码。

## [zhnumber-v3.1](https://github.com/CTeX-org/ctex-kit/releases/tag/zhnumber-v3.1)

- 提升 LaTeX3 最低版本要求至 2025/10/09。
- 支持仅输出年或年月。
