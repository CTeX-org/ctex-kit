# Issue #1114 资产

命令正文里有用户写的嵌套盒子、脚注时，命令两侧的间距与删去外层命令后的直接输入不一致。

测试环境：XeLaTeX，TeX Live 2026，hyperref 2026-06-17 v7.01r，xeCJK master `e07fcbf2`。

## 复现

![#1114 复现](https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1114/issue1114-repro.png)

源文件：[`issue1114-repro.tex`](https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1114/issue1114-repro.tex)。每组上一行是命令包裹的写法，下一行是删去外层命令的直接输入，正确时两行等宽。上一行用灰框标出盒子，只为显示位置；宽度按不加框的写法量取。

| 写法 | 命令包裹 | 直接输入 | 差 |
|---|---|---|---|
| `中\href{u}{\hbox{y}}文` | 31.94pt | 25.28pt | 两侧各多一枚 `\CJKecglue` |
| `x\href{u}{\hbox{y}}中` | 23.89pt | 20.56pt | 右侧多一枚 |
| `中\href{u}{\parbox{2.5cm}{y}}文` | 94.46188pt | 91.13188pt | 多一枚 |
| `中\mbox{\hbox{y}}文` | 31.94pt | 25.28pt | 两侧各多一枚 |
| `x\href{u}{\footnote{y}}中` | 23.093pt | 19.763pt | 右侧多一枚 |
| `x\href{u}{\setbox0=\hbox{y}文}x` | 23.89pt | 27.22pt | 左侧少一枚 |
| `x\href{u}{\sbox0{y}文}x`（对照） | 27.22pt | 27.22pt | 一致 |

## 根因

直接输入时，xeCJK 看不到盒子里面：`中\hbox{y}文` 里，盒子前后的 `中`、`文` 与盒子之间不补间距。命令边界 capture 却把字符类别报告给所有活动的 capture 层，不管字符排在哪个列表里。用 `trace.tex` 包装 `\__xeCJK_boundary_capture_class:n` 打印每次报告：

```text
===== 中\href{u}{\hbox{y}}文
REPORT CJK depth=0,grouplevel=2,grouptype=14
REPORT default depth=1,grouplevel=6,grouptype=14   ← 盒子里的 y 报告给了链接的 capture
REPORT CJK depth=0,grouplevel=2,grouptype=14
===== 中\hbox{y}文
REPORT CJK depth=0,grouplevel=2,grouptype=14
REPORT default depth=0,grouplevel=3,grouptype=14   ← 没有 capture，不影响两侧
REPORT CJK depth=0,grouplevel=2,grouptype=14
```

链接的 capture 因此以为正文首尾都是西文，按“中、西文之间”在两侧各补一枚 `\CJKecglue`。`\parbox`、`minipage`、`\vbox` 里的字符，脚注正文，以及原语 `\setbox` 的内容都一样被报告给外层；`\sbox` 会暂停 capture，所以对照一行正确。
