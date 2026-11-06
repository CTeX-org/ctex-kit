# #1122：fatal-path 测试与 Overfull 对照

## `.lvt` 不能以 `\usepackage` 作为最后一行

`ctex/test/testfiles/engine-option02.lvt` 用来固定「`engine` 选项指向的文件不存在时 critical
中止」。第一版把 `\usepackage[engine=doesnotexist]{ctex}` 放在文件最后一行，`l3build save` 存下
的基线里没有任何期望内容，只有一行 `)`、`*` 与 `! Emergency stop`；原始日志以
`<*> \input engine-option02.lvt` 和 `(job aborted, no legal \end found)` 收尾，`(./ctex.sty`
一次也没出现——`\usepackage` 根本没执行。

定位办法是在可疑行前后各插一条 `\typeout` 记号：`\typeout` 打出而 `\usepackage` 没有动作，
说明 TeX 在扫描 `\usepackage` 的参数时已经读到文件末尾，此后没有记号可读。判据是日志里有没有
`(ctex.sty`，看退出码或 diff 都看不出这一点。

末尾补一行任何内容（这里用 `\end{document}`，正常路径不会走到）后恢复正常。注意这和
`llmdoc/memory/lessons-learned.md` 里「`\START` 要放在 `\usepackage` 之前」是两条不同的约束：
那条讲观察点在加载之前，这条讲文件的物理末尾。

## 在被拦截的 `\msg_critical` 里调用 `\END` 会写进「Bad conditionals」

`engine-option02.lvt` 沿用 `cjkfntef-luatex02.lvt` 的做法，替换 `\msg_critical:nnn` 记录消息。
但在 `\END` 之前实测 `\currentiflevel` 为 1（报错点仍在条件式内部），而 `\END` 自己的
`\ifnum\currentiflevel>1` 会把那一层算进去、读到 2，于是基线里多出 `Bad conditionals: 1!`。
`cjkfntef-luatex02` 用的是同样的拦截写法，基线里却没有这行，所以照抄它看不出问题。

最终做法是在拦截体里自己写 `END-TEST-LOG` 标记，再用原语结束运行（`\use:c { @@end }`）；
`\END` 的组与条件式检查留给正常路径。`\START` 与 `\AUTHOR` 也放进拦截体，基线里就只剩消息本身，
不会带上 `ctex.sty` 及其依赖的文件打开行。

## 比较 Overfull 要比宽度的多重集

手册改动的验收之一是「不新增 Overfull」。只数条数不够：第一版新增文档段落产生了 21 处、master
为 19 处；改写后仍是 19 处，但其中一处是新出现的 3.98pt（`\texttt{engine-file-not-found}` 那段
实现说明），同时 master 的一处被挤掉，条数相等掩盖了替换。

做法是在 `master` 的 worktree 里跑 `l3build doc`，把两边的 Overfull 行去掉 ` in paragraph at
lines …` 后排序再比：行号会随插入内容整体推移，宽度值不会。这次最终两边的宽度多重集完全一致。
在 worktree 里构建不需要额外准备，`dofile("../support/build-config.lua")` 与 `checkdeps` 都随
worktree 完整存在。

## 可写入稳定文档的内容

- 已写入 `llmdoc/architecture/ctex-architecture.md`：`engine` 选项与「只替换引擎定义文件」的边界。
- 已写入 `llmdoc/memory/decisions/1122-engine-option.md`：键路径、确定时机、值按字面使用、
  不符时不警告、不公开检测结果等决定。
- 已写入 `llmdoc/reference/build-and-test.md`：`engine-option01/02` 的覆盖说明与 fatal-path
  测试的第 11 条技术模式（文件末尾约束、`\END` 的条件式）。
- 已写入 `llmdoc/memory/lessons-learned.md`：`.lvt` 末尾约束、`\END` 的条件式、Overfull 多重集
  对照三条规则。

## 相关

- Issue：#1122；PR：#1123。
- 决策：[[1122-engine-option]]。
- 相邻反思：[[1119-loading-error-log-diagnostic]]（加载期失败的日志与对照条件）。
