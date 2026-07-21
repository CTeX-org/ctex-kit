<!-- xeCJK-inline-math-status-table -->

### 行内公式命令边界状态表

本表是 #992 命令边界状态表在行内公式方面的补充，只检查命令包裹的内容为
`$x$` 时，命令外侧的间距是否与直接输入 `$x$` 相同。

- 每格依次表示源码空格 `00`、`10`、`01`、`11`；第一位是命令左侧，第二位是右侧，`1` 表示有空格。
- 每个编号分为 `xCJKecglue=false`、`true` 两行；候选和直接输入使用相同的选项值。
- ✅ 表示默认间距和可区分间距（`CJKecglue=5pt`、`CJKglue=1pt`）都与直接输入相同；❌ 表示至少一种设置不同。
- 「中·公式·中」和「西·公式·西」检查两侧文字相同的情况；两个混合方向用于分别检查公式左侧和右侧，避免两侧的宽度差互相抵消。

| 编号 | 命令 | `xCJKecglue` | 中·公式·中 | 西·公式·西 | 中·公式·西 | 西·公式·中 | 测试文件 | 排版对照（5pt/1pt） | 说明 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `\(x\)` | false | `✅❌✅❌` | `✅✅✅✅` | `✅❌✅❌` | `✅✅✅✅` | [完整测试](https://github.com/CTeX-org/ctex-kit/blob/gh-assets/issues/1002/inline-math-matrix.tex) | <img src="https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1002/showcase/paren.png" width="300" alt="括号形式行内公式的间距对照"> | 中文位于公式左侧且左侧有源码空格时，与 `$x$` 相差 3.33pt。 |
| 1 | `\(x\)` | true | `✅❌✅❌` | `✅✅✅✅` | `✅❌✅❌` | `✅✅✅✅` | 同上 | 同上 | 同上 |
| 2 | `\ensuremath{x}` | false | `✅❌✅❌` | `✅✅✅✅` | `✅❌✅❌` | `✅✅✅✅` | 同上 | <img src="https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1002/showcase/ensuremath.png" width="300" alt="ensuremath 的间距对照"> | 结果与 `\(x\)` 相同。 |
| 2 | `\ensuremath{x}` | true | `✅❌✅❌` | `✅✅✅✅` | `✅❌✅❌` | `✅✅✅✅` | 同上 | 同上 | 同上 |
| 3 | 原样输出参数的宏 | false | `✅❌✅❌` | `✅✅✅✅` | `✅❌✅❌` | `✅✅✅✅` | 同上 | <img src="https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1002/showcase/macro.png" width="300" alt="普通宏包裹行内公式的间距对照"> | 即使宏只输出参数，左侧源码空格仍与直接输入 `$x$` 不同。 |
| 3 | 原样输出参数的宏 | true | `✅❌✅❌` | `✅✅✅✅` | `✅❌✅❌` | `✅✅✅✅` | 同上 | 同上 | 同上 |
| 4 | 显式分组 `{$x$}` | false | `❌❌❌❌` | `✅✅✅✅` | `❌❌❌❌` | `✅✅✅✅` | 同上 | <img src="https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1002/showcase/group.png" width="300" alt="显式分组包裹行内公式的间距对照"> | 中文位于公式左侧时，四种源码空格都与直接输入不同。 |
| 4 | 显式分组 `{$x$}` | true | `❌❌❌❌` | `✅✅✅✅` | `❌❌❌❌` | `✅✅✅✅` | 同上 | 同上 | 同上 |
| 5 | `\textbf{$x$}` | false | `❌❌❌❌` | `✅✅✅✅` | `❌❌❌❌` | `✅✅✅✅` | 同上 | <img src="https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1002/showcase/textbf.png" width="300" alt="textbf 包裹行内公式的间距对照"> | 默认间距和 5pt/1pt 间距暴露出不同的偏差，因此四格都记为 ❌。 |
| 5 | `\textbf{$x$}` | true | `❌❌❌❌` | `✅✅✅✅` | `❌❌❌❌` | `✅✅✅✅` | 同上 | 同上 | 同上 |
| 6 | `\textit{$x$}` | false | `❌❌❌❌` | `✅✅✅✅` | `❌❌❌❌` | `✅✅✅✅` | 同上 | <img src="https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1002/showcase/textit.png" width="300" alt="textit 包裹行内公式的间距对照"> | 中文位于公式左侧时，四种源码空格都与直接输入不同。 |
| 6 | `\textit{$x$}` | true | `❌❌❌❌` | `✅✅✅✅` | `❌❌❌❌` | `✅✅✅✅` | 同上 | 同上 | 同上 |
| 7 | `\texttt{$x$}` | false | `❌❌❌❌` | `✅✅✅✅` | `❌❌❌❌` | `✅✅✅✅` | 同上 | <img src="https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1002/showcase/texttt.png" width="300" alt="texttt 包裹行内公式的间距对照"> | 默认间距下也存在字体相关的宽度差。 |
| 7 | `\texttt{$x$}` | true | `❌❌❌❌` | `✅✅✅✅` | `❌❌❌❌` | `✅✅✅✅` | 同上 | 同上 | 同上 |
| 8 | `\textcolor{red}{$x$}` | false | `❌❌❌✅` | `✅✅✅✅` | `❌✅❌✅` | `❌❌✅✅` | 同上 | <img src="https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1002/showcase/textcolor.png" width="300" alt="textcolor 包裹行内公式的间距对照"> | 混合方向显示左右两侧都可能出现差异。 |
| 8 | `\textcolor{red}{$x$}` | true | `❌❌❌❌` | `✅✅✅✅` | `❌✅❌✅` | `❌❌✅✅` | 同上 | 同上 | `11` 在 5pt/1pt 间距下仍相差 1.67pt。 |
| 9 | `\mbox{$x$}` | false | `✅❌✅❌` | `✅✅✅✅` | `✅❌✅❌` | `✅✅✅✅` | 同上 | <img src="https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1002/showcase/mbox.png" width="300" alt="mbox 包裹行内公式的间距对照"> | 对应 #992 第 28 行；现在由 #1002 集中记录。 |
| 9 | `\mbox{$x$}` | true | `✅❌✅❌` | `✅✅✅✅` | `✅❌✅❌` | `✅✅✅✅` | 同上 | 同上 | 与 #992 旧表按字母 `x` 比较所得结论不同；本表统一使用直接公式 `$x$`。 |
| 10 | `\makebox{$x$}` | false | `✅❌✅❌` | `✅✅✅✅` | `✅❌✅❌` | `✅✅✅✅` | 同上 | <img src="https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1002/showcase/makebox.png" width="300" alt="makebox 包裹行内公式的间距对照"> | 结果与 `\mbox{$x$}` 相同。 |
| 10 | `\makebox{$x$}` | true | `✅❌✅❌` | `✅✅✅✅` | `✅❌✅❌` | `✅✅✅✅` | 同上 | 同上 | 同上 |
| 11 | `\fbox{$x$}` | false | `❌❌❌✅` | `✅✅✅✅` | `✅❌❌✅` | `✅❌✅✅` | 同上 | <img src="https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1002/showcase/fbox.png" width="300" alt="fbox 包裹行内公式的间距对照"> | 外框盒子两侧分别存在差异。 |
| 11 | `\fbox{$x$}` | true | `❌❌❌❌` | `✅✅✅✅` | `✅❌❌✅` | `✅❌✅✅` | 同上 | 同上 | `xCJKecglue=true` 时，中·公式·中的 `11` 也不一致。 |
| 12 | `\colorbox{yellow}{$x$}` | false | `❌❌❌✅` | `✅✅✅✅` | `✅❌❌✅` | `✅❌✅✅` | 同上 | <img src="https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1002/showcase/colorbox.png" width="300" alt="colorbox 包裹行内公式的间距对照"> | `false` 时结果与 `\fbox{$x$}` 相同。 |
| 12 | `\colorbox{yellow}{$x$}` | true | `❌❌❌❌` | `✅✅✅✅` | `✅❌❌✅` | `✅❌❌✅` | 同上 | 同上 | `true` 时右侧源码空格也暴露出差异。 |
| 13 | `\CJKunderline{$x$}` | false | `❌❌❌❌` | `✅✅✅✅` | `❌❌❌❌` | `✅✅✅✅` | 同上 | <img src="https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1002/showcase/cjkunderline.png" width="300" alt="CJKunderline 包裹行内公式的间距对照"> | 公式装饰后的边界与直接输入不同。 |
| 13 | `\CJKunderline{$x$}` | true | `❌❌❌❌` | `✅❌✅❌` | `❌❌❌❌` | `✅❌❌❌` | 同上 | 同上 | `true` 时西文周边和右侧中文的部分组合也不一致。 |
| 14 | `\CJKunderdot{$x$}` | false | `❌❌❌✅` | `✅✅✅✅` | `✅✅❌✅` | `✅✅✅✅` | 同上 | <img src="https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1002/showcase/cjkunderdot.png" width="300" alt="CJKunderdot 包裹行内公式的间距对照"> | 混合方向可定位到公式右侧的差异。 |
| 14 | `\CJKunderdot{$x$}` | true | `❌❌❌❌` | `✅✅✅✅` | `✅❌❌✅` | `✅❌✅✅` | 同上 | 同上 | `true` 时更多源码空格组合不一致。 |
| 15 | `\CJKsout{$x$}` | false | `❌❌❌❌` | `✅✅✅✅` | `❌❌❌❌` | `✅✅✅✅` | 同上 | <img src="https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1002/showcase/cjksout.png" width="300" alt="CJKsout 包裹行内公式的间距对照"> | 结果与 `\CJKunderline{$x$}` 的 `false` 行相同。 |
| 15 | `\CJKsout{$x$}` | true | `❌❌❌❌` | `✅❌✅❌` | `❌❌❌❌` | `✅❌❌❌` | 同上 | 同上 | 结果与 `\CJKunderline{$x$}` 的 `true` 行相同。 |
| 16 | `\hyperref[...]{$x$}` | false | `✅❌✅❌` | `✅✅✅✅` | `✅❌✅❌` | `✅✅✅✅` | 同上 | <img src="https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1002/showcase/hyperref.png" width="300" alt="hyperref 包裹行内公式的间距对照"> | 左侧中文旁有源码空格时，与直接输入 `$x$` 不同。 |
| 16 | `\hyperref[...]{$x$}` | true | `✅❌✅❌` | `✅✅✅✅` | `✅❌✅❌` | `✅✅✅✅` | 同上 | 同上 | 同上 |
| 17 | `\href{...}{$x$}` | false | `✅❌✅❌` | `✅✅✅✅` | `✅❌✅❌` | `✅✅✅✅` | 同上 | <img src="https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1002/showcase/href.png" width="300" alt="href 包裹行内公式的间距对照"> | 结果与 `\hyperref` 相同。 |
| 17 | `\href{...}{$x$}` | true | `✅❌✅❌` | `✅✅✅✅` | `✅❌✅❌` | `✅✅✅✅` | 同上 | 同上 | 同上 |

<details>
<summary>测试方法和当前统计</summary>

每项测试都把命令包裹的 `$x$` 与直接输入 `$x$` 比较。二者分别放入受限水平盒子测量，并扣除命令自身造成的宽度差，剩余差值只来自左右边界。

完整测试共有 17 种命令、四种周边文字组合、四种源码空格、两个 `xCJKecglue` 值，再分别使用默认间距和 5pt/1pt 间距，共 1088 次比较。按“两个间距设置都通过才记 ✅”的规则，本表共有 544 格，其中 329 格通过、215 格不同。

测试基于 `master` 提交 `10500b33`。完整数值见 [`inline-math-verdicts.tsv`](https://github.com/CTeX-org/ctex-kit/blob/gh-assets/issues/1002/inline-math-verdicts.tsv)，测试文件和图片说明见 [`gh-assets/issues/1002/`](https://github.com/CTeX-org/ctex-kit/blob/gh-assets/issues/1002/README.md)。这些结果记录当前尚未修复的情况；修复合并后，应从新的 `master` 提交重新测试再更新本表。

</details>
