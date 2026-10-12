# Issue #1108、#1110 资产（PR #1113）

两个 issue 都由 `\href` 等流式命令的正文经宏结束段落引起，由 PR #1113 一并修复。下面每一项都先给 issue 原文里的问题，再给修复前后的实测结果。

测试环境：XeLaTeX，TeX Live 2026，hyperref 2026-06-17 v7.01r。“修复前”是 xeCJK master `60176007`，“修复后”是 PR #1113 `3f2961f0`；用 `TEXINPUTS` 只替换 `xeCJK.sty` 等 xeCJK 文件。

## 1. #1108 原始场景：OI Wiki 导出 PDF 失败

issue 原文：“OI Wiki 的 PDF 构建在更新 TeX Live 环境后出现 `Improper \spacefactor` 错误。原始文档中，超链接内容包含 `figure` 环境。”出错位置是 OI Wiki 首页 `docs/index.md` 的第二行：

```markdown
[![Word Art](images/wordArt.webp)](https://github.com/OI-wiki/OI-wiki)
```

`OI-Wiki-export` 把它转换成 `\hyref{网址}{\includegraphicsEverywhere{图}{说明}}`，后者在链接正文里先 `\par` 再排 `figure` 环境。

![#1108：OI Wiki 原始场景](https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1110/issue1108-oiwiki.png)

上：修复前后的终端输出（摘录，源文件 `issue1108-oiwiki-terminal.tex`，内容照抄实际日志）；下：修复后同一文件排出的第 5 页。

复现方法（不是缩写的示例，而是 OI Wiki 自己的生成器和模板）：

1. 克隆 [OI-wiki/OI-Wiki-export](https://github.com/OI-wiki/OI-Wiki-export)（`8ab161c2`）与 [OI-wiki/OI-wiki](https://github.com/OI-wiki/OI-wiki)（`98cebcfc`，只需 `mkdocs.yml`、`docs/index.md`、`docs/images/wordArt.webp`），在 `remark-snippet`、`remark-latex`、`oi-wiki-export` 下各执行 `npm i`。
2. 把 `oiwiki/issue1108-oiwiki-one-page.js` 放进 `oi-wiki-export/`，执行 `node issue1108-oiwiki-one-page.js <OI-wiki 根目录>`。它只转换首页，管线与参数照抄 `oi-wiki-export/index.js` 的 `convertMarkdown`，得到 `tex/OIwikidocsindexmd.tex`（即本目录的 `oiwiki/OIwikidocsindexmd.tex`）。
3. 让 `includes.tex` 只含 `\chapter{简介}\input{tex/OIwikidocsindexmd}`，用原样的 `oi-wiki-export.tex` 按 OI Wiki CI 的参数编译：`xelatex -shell-escape -file-line-error -halt-on-error oi-wiki-export.tex`。

结果：修复前在首页第 5 行报错并中止（只排出 4 页，退出码 1）；修复后退出码 0，排出 5 页。修复前不用 `-halt-on-error` 时也排出 5 页，与修复后逐页渲染结果完全相同，说明修复没有改变这一页的版面。

修复前的报错原文：

```text
./tex/OIwikidocsindexmd.tex:5: Improper \spacefactor.
<argument> \tex_spacefactor:D

l.5 ...where{{OIwikidocsimageswordArt}}{Word Art}}
                                                  \textsuperscript{\label{en...
You can refer to \spacefactor only in horizontal mode;
```

图中的 Word Art 图片取自 OI Wiki（`docs/images/wordArt.webp`），按 [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.zh) 使用。

说明：只把 `\hyref` 和 `\includegraphicsEverywhere` 两个宏抄进一个简单文档、把链接放在正文段落里，**不能**复现报错，v3.10.6 和 master 都正常编译。首页里链接紧跟在 `\subsection*` 标题之后，修复前要在 OI Wiki 的完整模板里才会触发。所以这里没有用手写的简化文档代替原始场景。

## 2. #1108 原文 MWE

`issue1108-original.tex`：issue 原文的最小工作示例，原样保留。按 issue 的命令 `xelatex -no-pdf -halt-on-error -interaction=nonstopmode` 编译：修复前报 `! Improper \spacefactor.`，退出码 1；修复后退出码 0。

## 3. #1110 原文 MWE 与同类写法

issue 原文：“`\href` 等流式命令的正文先结束段落、又开始新段落时……新段落开头的汉字前面因此多出一个 `\CJKecglue`。”

![#1110：修复前后对比](https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1110/issue1110-before-after.png)

左：修复前；右：修复后。每行是新段落的最后一行，红色是比删去 `\href` 的直接输入多出的间距。第一行就是 issue 原文的 MWE，下面五行是同一问题的其他写法，其中“两段”“三段”是 PR #1113 第一版审查指出的情形。

- `issue1110-original.tex`：issue 原文的 MWE，原样保留。修复前输出 `link: 13.33pt`、`direct: 10.0pt`；修复后两者都是 `10.0pt`。
- `issue1110-before-after.tex`：对比图源文件，用 `xelatex "\def\LABEL{...}\input{issue1110-before-after}"` 编译。

## 不在本 PR 范围

正文里的盒子、脚注内容被当作命令两侧的类别（如 `中\href{u}{\hbox{y}}文`）与段落无关，由 #1114 跟踪，本 PR 前后结果相同。
