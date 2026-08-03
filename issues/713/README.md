# Issue #713 — jiazhu 直排全高窄体夹注跨行不对齐

对应评论：<https://github.com/CTeX-org/ctex-kit/issues/713#issuecomment-5166936841>

复现环境：`xelatex`（TeX Live 2026），`jiazhu.sty` 由 `l3build unpack` 生成；
本机无 SimSun，字体用 `Noto Serif CJK SC`（换字体后症状不变）。

| 文件 | 说明 |
|---|---|
| `jiazhu713-mechanism.png` | 机制图：`FakeStretch` 只改前进宽度，而 `\__jiazhu_dim_normalize:N` 按名义字号取整，每字缺 7.5pt |
| `jiazhu713-mechanism.tex` | 上图源码 |
| `jiazhu713-mwe.tex` | 复现文件（内容同 issue 原文，仅替换字体名） |
| `jiazhu713-measure-fakestretch.tex` | 单字宽度测量：12.5pt 字号下 `FakeStretch=1.6` 使前进宽度变 20.0pt，高/深不变 |
