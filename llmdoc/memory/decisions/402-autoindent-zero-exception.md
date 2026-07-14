# #402 `autoindent` 零缩进兼容语义

## 背景

#402 从 #401 的标题缩进修复中分离出来，讨论 `\ctex_update_parindent:` 是否应删除
`\parindent=0pt` 判断。删除后，只要启用 `autoindent`，每次字号变化都会无条件把
`\parindent` 设为配置值。

## 决策

保留现有判断，并把它作为用户可依赖的兼容契约写入手册：

- `autoindent=false` 清空自动更新策略；
- `autoindent` 启用且当前 `\parindent` 非零时，字号变化把它更新为配置值；
- 当前 `\parindent=0pt` 时继续保持零。

现代文档若要明确关闭自动更新仍应使用 `autoindent=false`，但旧式零值做法继续兼容。

## 理由

早期 ctex 没有 `autoindent=false`，文档只能用 `\parindent=0pt` 关闭自动调整。LaTeX 的
`minipage`、`\centering` 及 array/parbox 恢复路径也会主动把段首缩进设为零。无条件
赋值会破坏旧文档，并要求持续给这些结构打补丁临时关闭 `autoindent`。

#401 已通过在标题格式内部局部关闭自动更新解决，不再需要借此判断掩盖标题问题；这不
改变零值判断本身的独立兼容价值。

## 未采用方案

- 不删除零值判断。显式 `autoindent` 覆盖零值虽然表面更直接，但兼容破坏范围更大。
- 不逐个补丁 LaTeX 结构设置 `autoindent=false`。结构集合开放且由第三方扩展，维护成本
  和遗漏风险高于保留统一哨兵。

## 验证

`ctex/test/testfiles/autoindent01.lvt` 在 pdfTeX、XeTeX、LuaTeX、upTeX 下先启用
`autoindent=3`，再把 `\parindent` 置零并切换字号，四路均断言结果为 `0.0pt`。
PR #984 只修改用户手册、CHANGELOG 与回归基线，不改运行代码。
