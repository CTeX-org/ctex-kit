# #275 标题查询接口

## 背景

Issue #275 最初来自 ctex 1.x 时代的 Beamer 标题编号需求。当前 Beamer 已提供
`\insertpart`、`\insertsection`、`\insertsubsection` 作为标题文本接口，但不提供
CTeX 本地化的裸编号、完整标签和 `numbering` 键状态。SJTUBeamer v3.2.0 因而直接
读取六个 `\CTEX@...` 私有变量，形成对 ctex 内部存储的长期依赖。

## 决策

提供三个稳定、可展开、按层级参数化的公开查询：`\CTEXheadingnumber` 返回裸编号，
`\CTEXheadinglabel` 返回 `name` 前缀、编号和后缀组成的完整标签，
`\CTEXifheadingnumbering` 只反映对应 `numbering` 键。三者在使用时读取当前值，
因此响应后续及局部 `\ctexset`。

公开边界只包含语义稳定的标题数据与布尔状态。接口不应用任何标题格式，不返回标题
文本，也不公开 `\CTEX@...` 样式变量。Beamer 主题保留模板、字体、颜色、换行和间距
的所有权，并与既有 insert 接口组合。

## 未采用方案

- 不新增 `\insertCTEXsection` 一类命令。它会复制 Beamer 已有标题文本接口，并把
  CTeX 数据与 Beamer 模板命名体系耦合。
- 不把 `\CTEX@...` 私有变量直接声明为公共 API。它们混合存储数据、格式与实现细节，
  会冻结内部组织并扩大兼容承诺。
- 不提供格式化后的整块标题。下游需求是读取本地化编号后自行排版，不是让 ctex
  接管主题视觉层。

## 验证

`ctex/test/testfiles/heading-query01.lvt` 覆盖三个 Beamer 层级、三类查询、局部动态设置
与分组恢复。PR #983 的 SJTUBeamer 迁移样例覆盖 maxplus、max、min 三种布局的
part/section/subsection 页面，私有宏与公开接口版本共 9 页逐页栅格比较均为 `AE=0`；
另一个 MWE 验证 `numbering=false` 时标签及其附属布局按预期消失。
