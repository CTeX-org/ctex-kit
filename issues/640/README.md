# Issue #640 — jiazhu 竖排模式可以调整基线吗

对应评论：<https://github.com/CTeX-org/ctex-kit/issues/640>

复现环境：`xelatex`（TeX Live 2026），字体 `Noto Serif CJK SC`。

| 文件 | 说明 |
|---|---|
| `jiazhu640-offset.png` | `valign` 四组对照 + 偏移量标度实证 |
| `jiazhu640-offset.tex` | 上图源码 |
| `jiazhu640-probe-leading.tex` | 决定性对照：固定字号 20pt、只改文档行距（20/30/40pt），offset 恒为 10.0pt |
| `jiazhu640-probe-scaling.tex` | 标度扫描：offset = (n-1)/2 x 夹注字号（扫 `lines`、`ratio`、字号） |

两个探针都重定义 `\__jiazhu_put_box:N` 打印 `\l__jiazhu_box_offset_dim`，编译后看终端输出的
`[PROBE]` 行。需要 `jiazhu.sty` 在同目录（或已安装）。

注意：`jiazhu` 在 `\__jiazhu_boot:n` 里用 `\fontsize{s}{s}` + `\linespread{1}` 把夹注组内的
`\baselineskip` 钉死等于夹注字号，所以**在夹注组内**测「半个 baselineskip」与「半个夹注字号」
永远同值，必须在组外改文档行距才能分离二者。
