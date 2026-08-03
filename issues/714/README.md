# Issue #714 — jiazhu 传统直排半高夹注正文对齐

对应评论：<https://github.com/CTeX-org/ctex-kit/issues/714#issuecomment-5166947985>

复现环境：`xelatex`（TeX Live 2026），`jiazhu.sty` 由 `l3build unpack` 生成；
本机无 SimSun，字体用 `Noto Serif CJK SC`（`\l__jiazhu_unit_dim` 只取 `\f@size pt`，不查字体度量）。

| 文件 | 说明 |
|---|---|
| `jiazhu714-grid.png` | n=4/5/6/8 四组与 20pt 正文字网格的对照，直观显示半字错位 |
| `jiazhu714-grid.tex` | 上图源码 |
| `jiazhu714-mwe.tex` | 报告者「附图左边情形」的完整复现代码 |
| `jiazhu714-sweep-width.tex` | 盒宽扫描探针：夹注字数 n=1..12 对应盒宽 = ceil(n/2) 个夹注字宽 |
