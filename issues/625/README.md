# Issue #625 — jiazhu 夹注引起预料之外的断行

对应评论：<https://github.com/CTeX-org/ctex-kit/issues/625#issuecomment-5166924480>

复现环境：`xelatex`（TeX Live 2026），`jiazhu.sty` 由 `cd jiazhu && l3build unpack` 生成；
本机无 SimSun，字体用 `Noto Serif CJK SC`。

| 文件 | 说明 |
|---|---|
| `jiazhu625-mechanism.png` | 两个症状的机制图（`\lineskip` 触发链、`\__jiazhu_fill_newline:` 强制换行） |
| `jiazhu625-mechanism.tex` | 上图源码 |
| `jiazhu625-mwe-baseline.tex` | 症状 A 最小复现（正文 20pt、行距 20pt、`ratio=0.5`），vbox 高 39.12pt |
| `jiazhu625-mwe-depthclamp.tex` | 同上 + 「把 depth 夹回原值」补丁，vbox 高 36.26pt |
| `jiazhu625-depthclamp-collision.png` | 上述两者的 600dpi 放大对照：夹注墨迹与下一行由 +1.68pt 间隙变 −1.08pt 重叠 |

`jiazhu625-mwe-*.tex` 需要 `jiazhu.sty` 在同目录（或已安装）。两份文件的夹注文字染成红色，
便于按颜色通道分离夹注墨迹与正文墨迹后测量间距。
