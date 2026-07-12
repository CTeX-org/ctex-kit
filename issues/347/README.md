# Issue 347 原型复核

测试环境：`ctex-kit` master `0aefee06`、TeX Live 2026、XeLaTeX，使用当前
xeCJK 解包文件。

## `prototype.tex`

将 #347 的核心思路迁移到当前 LaTeX3/xeCJK。单个目标字可以装盒并旋转；两个
相邻目标字因同类之间没有触发原型定义的开盒/关盒转移，会进入同一个盒子并作为
整体旋转。`prototype.png` 是实际输出。

## `punctuation-failure.tex`

用“天地，玄黄”检查目标字后接 `FullRight` 全角标点的情况。原型只定义了目标类
到 `CJK` 和 `Boundary` 的关盒转移，没有定义目标类到 `FullRight` 的转移，因而
编译结束时盒子仍未闭合。实际日志包含：

- `Missing \endgroup inserted`
- `Missing } inserted`
- `\end occurred inside a group at level 1`

`punctuation-failure.log.txt` 是日志摘录，`punctuation-failure.png` 是对应图示。

这些结果说明该原型若要直接接入当前 xeCJK，需要统一覆盖完整字符类矩阵，并处理
CM/IVS、Jamo shaping、fallback、标点和边界状态。它不适合作为现有架构上的局部
增量功能；但如果未来完整重构 xeCJK 的字符输入与变换流水线，“在统一入口捕获
字符盒并交给变换函数”仍是值得重新评估的设计原型。
