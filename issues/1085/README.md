# Issue #1085 资产

xeCJK 下 CJK 文字紧接源码空格与 `\hfill\null` 时,右侧 `\hfill` 的无限阶填充 glue
位置错乱,导致居中失效。

- `issue-1085-mwe.tex` — 最小复现(需 XeLaTeX)
- `issue-1085-before.png` — 修复前:第 3、4 行(裸 CJK / `\begingroup`)被推到右边距
- `issue-1085-after.png` — 修复后:四行全部居中
- `issue-1085-before-after.png` — 并排对比(左 before / 右 after)
