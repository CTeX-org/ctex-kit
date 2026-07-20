# Issue #998 资产

行内公式 `\mbox{$x$}` 与标尺盒 `\mbox{\vrule ...}` 在 CJK 上下文中的边界
间距与直接输入不一致; 纯西文上下文不受影响。

根因 (机制边界): math 与 rule 不触发 XeTeX interchar class 转换,
capture 观察不到任何首尾类别, box 策略将其按"无可见输出"处理——
原样恢复入口 marker 与源码空格, 违反输出等价契约。
v3.10.3 与 PR #999 的 MWE 输出一致 (预存缺陷, 非 #999 引入)。

- `issue998-mwe.tex` — issue 原 MWE (补字体声明)。
- `issue998-confirm.png` — 四个 DELTA: -6.66pt / 0 / -3.33pt / 0。

Workaround (PR #999 之后):
- math: 左侧有源码空格即正常 (`前 \mbox{$x$} 后`); 无空格场景可写
  `前~\mbox{$x$}` 或 `前\CJKecglue\mbox{$x$}`。
- rule: 改用原语 `\hbox{\auditrule}`, 或在 `\mbox` 后加 `\kern0pt`
  (`前\mbox{\auditrule}\kern0pt\ 后`)。

## 修复分支验证（2026-07-20）

修复分支 `fix-996-998-1000-boundary-capture`（commit `14336c4d` 起）：
box/wrapped-box 捕获在「盒有可见墨迹（宽度非零且高度或深度非零）而未
观察到任何类别」时按 Default 首尾重建边界；空 `\mbox`/`\null`（零尺寸）
与空 `\makebox`/strut（单一非零维度的空白占位盒）保持透明。

- `issue998-matrix.tex` — 扩展矩阵：math 字母/数字、文本数字、rule ×
  中·西双上下文 × 00/10/01/11。修复分支上 32/32 全 PASS
  （math 行 oracle 为直接输入 `$x$`/`$1$`；rule 行 oracle 为 Default
  字母——裸 `\vrule` 直接输入不触发 interchar 转换属引擎机制边界，
  需要该行为可用未注册的原语 `\hbox{\vrule ...}`）。
- 原 `issue998-mwe.tex` 在修复分支上 math 两行 DELTA 归零；rule 行按
  新契约与花括号分组 oracle 有意不同（分组保留外层 CJK marker，属
  分组自身语义）。
