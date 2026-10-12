# Issue #1110 资产（PR #1113，含 #1108）

`\href` 等流式命令的正文经宏结束段落时有两种问题：

- **#1108**：正文以 `\par` 结束、命令结束时已在垂直模式，xeCJK 在垂直模式读取 `\spacefactor`，报 `Improper \spacefactor`（OI Wiki 的 PDF 构建因此失败）。
- **#1110**：正文结束一个或多个段落、又开始新段落时，命令结束时已回到水平模式，但 xeCJK 记录的首尾类别、入口 marker 与源码空格都属于之前的段落；按它们重放，新段落开头就多出一枚 `\CJKecglue`（默认间距下 3.33pt）。v3.9.1 正确，v3.10.0 起出错。

修复：命令结束时在垂直模式就只清理状态（#1108）；段落结束时把 capture 恢复到刚开始的状态，并由同一层的下一段认领，正文结束几段就依次跟随几段，命令结束时只按最后一段里实际观察到的类别处理（#1110）。

- `issue1110-mwe.tex`：MWE。第一节是 #1108 的写法；第二节三组是 #1110 的写法，每组第一行是链接，第二行是删去 `\href` 的直接输入，两行应等宽。
- `issue1110-before-after.tex`／`issue1110-before-after.png`：带标注的对比图。左：master `60176007`；右：PR #1113（`3f2961f0`）。每行是新段落的最后一行，红色是比直接输入多出的间距。用 `xelatex "\def\LABEL{...}\input{issue1110-before-after}"` 编译，用 `TEXINPUTS` 指定要比较的 xeCJK 版本。

修复前编译 MWE 的报错（修复后不报错）：

```text
! Improper \spacefactor.
<argument> \tex_spacefactor:D

l.15 \href{https://example.com}{\EndPar}

You can refer to \spacefactor only in horizontal mode;
```

测试环境：XeLaTeX，TeX Live 2026，hyperref 2026-06-17 v7.01r，`FandolSong-Regular.otf`。

正文里的盒子、脚注内容被当作命令两侧类别的问题（如 `中\href{u}{\hbox{y}}文`）与段落无关，由 #1114 跟踪，不在本 PR 处理。
