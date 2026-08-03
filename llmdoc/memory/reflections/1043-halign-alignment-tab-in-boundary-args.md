# #1043 反思：boundary 判断遇到 catcode-4 `&`

任务：修复用户客诉——更新到 xeCJK 3.10.4 后，`\colorbox{...}{$...&...$}` 写在
`eqnarray` 里编译报错。

## 缺陷本身

`\@@_boundary_color_box:nnn` 把**原始**第三参数交给 `\@@_boundary_if_math_head:n`，
后者用 expl3 的 `\tl_if_head_eq_meaning:nNTF` 做语法判断。该条件式内部要把 token
list 包进花括号组再扫描，而 `\halign` 语境（`eqnarray`/`align`/`tabular`）里用户参数
中的 `&` 带 catcode 4，会破坏扫描平衡，报
`! Argument of \__tl_tl_head:w has an extra }.`

回归区间：TeX Live 版 v3.10.3 干净，master v3.10.5 报 26 个错；引入提交是
`c8923052`（#1002 那套 inline-math boundary 代码），与报告者说的「3.10.4 起出问题」吻合。

修复：新增 `\@@_boundary_math_set:n`，在 `_head:n` / `_tail:n` 这一层统一把判断用副本里
catcode-4 的 `&` 换成 `\scan_stop:`。

## 教训

### 1. `\ExplSyntaxOn` 下 `&` 是 catcode 0，不是 4

我第一版直接写 `\tl_replace_all:Nnn \l_..._tl { & } { \scan_stop: }`，**逻辑看起来完全
正确但完全无效**：expl3 catcode régime 下 `&` 是 escape char（catcode 0），拿它当模式
匹配不到 `\halign` 里的对齐符，替换静默失效、缺陷依旧。实测 `\char_value_catcode:n {`&}`
在 `\ExplSyntaxOn` 段和 document 内都返回 0。

正确写法是在局部组里构造模板常量：

```latex
\group_begin:
  \char_set_catcode_alignment:N \&
  \tl_const:Nn \c_@@_alignment_tl { & }
\group_end:
```

这类「替换模式的 catcode 必须与目标 token 一致」的坑与 #879 同源（那次是替换端
`\x{NN}` 丢失原 codepoint）。**通用规则：凡是拿字面字符当 token 级替换的模式或替换值，
先问它在当前 catcode régime 下是什么类别。**

危险之处在于失败是静默的——不报错、测试不挂，只是缺陷没修好。若我当时只跑
「修复后不报错」这一项而没跑「缺陷版必须报错」的门禁反向验证，就会交付一个无效补丁。

### 2. 占位而非删除，保住位置语义

先试过直接删掉 `&`。语法判断能过，但 `&$x$` 的首项从 `&` 变成 `$`，被误判成
「首项是公式」。换成 `\scan_stop:` 占位后，实测五种位置（中间／开头／结尾／多个／
嵌套组）的 head/tail 判定都正确。**清理输入以适配下游解析器时，删除会改变位置关系，
替换成惰性 token 才是等价变换。**

### 3. 报告者的两个症状只有一个是真缺陷

客诉说「数学式和 `\paragraph` 标题都出不来」。实测标题症状**无法独立复现**（单独测、
用他的完整导言区测都正常），修掉数学式问题后标题自动恢复——它是第一个症状那串报错
导致后续排版全乱的次生结果。**多症状客诉要逐一验证复现，不要假设它们是并列的独立缺陷；
否则会为不存在的第二个缺陷设计修复。**

### 4. `\tl_replace_all:NVn` 需自行声明变体，且要在使用点之前

expl3 不原生提供 `NVn`。dtx 里已有的 `\cs_generate_variant:Nn \tl_replace_all:Nnn { Nno }`
在 10037 行，远在我使用点（4720 行）之后，不能依赖。变体声明必须紧邻首次使用之前。

## 促进候选

- 教训 1 已够通用且会复现，值得进 `reference/coding-conventions.md` 的 catcode 一节，
  与 #879 并列。
- 教训 2、4 偏 expl3 手法，同样适合进 coding-conventions。
- 教训 3 属调研方法而非本仓库知识，留在本反思即可。
