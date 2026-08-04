# Issue #1043 — 更新 xeCJK 后 `\colorbox` 内含 `&` 的数学式编译出错

对应 PR：<https://github.com/CTeX-org/ctex-kit/pull/1044>

复现环境：`xelatex`（TeX Live 2026），`xeCJK.sty` 由 `cd xeCJK && l3build unpack` 生成。
`xecjk1043-mwe.tex` 是报告者邮件里的原始测试档，未作任何改动。

对照的两个版本：

- **修复前**：`2803f0c62d09603ff7ec080090e1506defc4ab15`（本 PR 的 base，v3.10.5）
- **修复后**：`242ae1c5767944e6a13381caf26fc8e5098ac18c`（本 PR 的 head）

| 文件 | 说明 |
|---|---|
| `xecjk1043-mwe-before-after.png` | 原始 MWE 修复前后并排对照（整页裁剪，150 dpi） |
| `xecjk1043-eqnarray-detail.png` | 公式区放大对照（1.6×），看清 `eqnarray` 三段对齐的崩坏与恢复 |
| `xecjk1043-before-full.png` | 修复前整页渲染 |
| `xecjk1043-after-full.png` | 修复后整页渲染 |
| `xecjk1043-mwe.tex` | 报告者原始测试档（原样保留） |
| `xecjk1043-before.log` | 修复前编译日志（28 条 `!`，首条为 `Argument of \__tl_tl_head:w has an extra }`） |
| `xecjk1043-after.log` | 修复后编译日志（0 条 `!`） |

## 图里能看到什么

修复前那一栏，`eqnarray` 的三段结构（`\vb{A}=` / `\xrightarrow` / 结果矩阵）被打散：

- `A =` 之后只剩一个游离的 `0`，黄色 `\colorbox` 的矩阵被挤到下一行；
- 多出一个字面的 `??`（TeX 在错误恢复中吐出的残留）；
- 两个 `\xrightarrow` 与各自的矩阵错位，第二行整段左移。

修复后恢复为 `A = [黄框矩阵] --Row 1--> [矩阵]`，第二行 `--Row 2--> [青框矩阵]` 右对齐，
`\paragraph` 标题也正常显示——报告者所说的「标题消失」是上述报错导致排版全乱的次生结果，
并非独立缺陷（单独复现该症状失败，修掉公式问题后标题自动恢复）。

## 复现命令

```sh
# 修复后
cd xeCJK && l3build unpack && cp build/unpacked/*.sty /tmp/after/
cd /tmp/after && cp .../xecjk1043-mwe.tex . && TEXINPUTS=".:" xelatex -interaction=nonstopmode xecjk1043-mwe.tex
grep -c '^! ' xecjk1043-mwe.log   # → 0

# 修复前（用 base 提交建 worktree 后同样操作）
git worktree add /tmp/wt-base 2803f0c6 && cd /tmp/wt-base/xeCJK && l3build unpack
grep -c '^! ' xecjk1043-mwe.log   # → 28
```

注意 `\colorbox` 参数里放**裸** `&`（如 `\colorbox{yellow}{&$x$}`）本身就不是合法 LaTeX，
不加载 xeCJK 也报错，不能用来判定本缺陷；本 MWE 里的 `&` 都在 `array` 内部，是合法用法。
