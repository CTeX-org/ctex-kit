# Issue #761: CJKglue 导言区设置被覆盖

## 问题

用户在导言区通过 `\xeCJKsetup{CJKglue=...}` 或直接重定义 `\CJKglue` 设置的字间距，在 `\begin{document}` 后被 ctex 的 linestretch 机制无条件覆盖。

## 根因

`\selectfont` -> `\ctex_update_size:` -> `\ctex_update_stretch:` 在 linestretch 启用时走 `\@@_update_stretch_auxii:`，该路径无条件调用 `\ctex_update_ccglue:` 覆盖用户设置。而 linestretch 禁用时的路径 `\@@_update_stretch_auxi:` 已有 `\ctex_if_ccglue_touched:TF` 守卫。

## 方案演进

### 初始方案（无效）

在 `\@@_update_stretch_auxii:` 的定义体内用 `%<*pdftex|xetex>` docstrip 守卫包裹 `\ctex_if_ccglue_touched:TF` 检查。

失败原因：`ctex.sty` 以 `{style,ctex}` 标签生成，不含引擎标签，守卫内容被 docstrip 剥离。

### 最终方案

1. 提取 linestretch 计算逻辑到 `\@@_update_stretch_auxiii:`。
2. `\@@_update_stretch_auxii:` 在公共区域定义为直接调用 `auxiii:`（所有引擎默认行为）。
3. pdftex/xetex 引擎 `.def` 中通过 `\ctex_at_end:n`（= `\AtEndOfPackage`）在包加载末尾重定义 `auxii:` 加入守卫。
4. luatex/uptex 不修改：其 `\ctex_if_ccglue_touched:` 存在预存缺陷（`\l_@@_ccglue_skip` 未初始化），留作后续修复。

## 确立的模式

在 ctex.sty 公共代码中定义默认实现，在引擎 `.def` 中用 `\ctex_at_end:n` 延迟重定义实现引擎特化。这是 docstrip 标签边界约束下的正确引擎条件化方案。

## 未关闭项

luatex/uptex 的 `\ctex_if_ccglue_touched:` 检测机制中 `\l_@@_ccglue_skip` 未初始化，需理解 luatexja 等包的初始化时序后另行处理。

## 相关

- PR #771，分支 `fix/761-ccglue-override`
- 源码 `ctex/ctex.dtx`
- 回归测试 `ctex/test/testfiles/ccglue01.lvt`
