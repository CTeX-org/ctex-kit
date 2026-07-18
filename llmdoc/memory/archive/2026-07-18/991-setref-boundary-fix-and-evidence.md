# 反思：#991 引用边界修复与自校验 MWE

## 从“命令已修复”改为精确矩阵

#491 汇总了多年命令边界修复，但每个命令通常只展示一个输出类别和一种源码空格组合。重新以直接输入为 oracle 后，同一命令在西文/CJK 输出、左右源码空格和外围字符改变时会进入不同路径；#491 因而被 #992 取代，完成状态改为“实际首尾类别 × 外围类别 × `00/10/01/11`”的精确单元。

#991 是这个方法立即暴露出的实例。数字引用只能证明 Default 末尾；把引用记录改成 CJK 后，LaTeX 内核 `\@setref` 尾随的 `\null` 会遮住另一种 marker。修复必须观察并重放实际末尾类别，而不是根据 `\ref` 名称或常见数字值猜成 Default。

## 修复点为何是 save/replay

`\null` 是已知、稳定且位于可见引用文本之后的固定遮蔽点。实现先迫使真实尾字符进入 Boundary 转换，验证并保存得到的 marker，保留原 hbox，再把 marker 放到 hbox 后。这样后续字符仍走 xeCJK 既有恢复链，节点变化只有 hbox/marker 顺序交换。

这个方案比通用 hbox 恢复窄，也比 drain 更忠实：引用可输出 CJK、Default 或混合内容，只有已观察的 marker 能同时覆盖。CJK 末尾后接源码空格还必须显式转换为 `CJK-space`，否则 hbox 已经让 XeTeX 回到 Boundary，该空格会退化成普通 inter-word glue。

hyperref 又增加了绑定维度。加载 hyperref 时，starred 引用使用其保存的 `\real@setref`；普通 linked-reference 走不同路径且没有尾随 `\null`。补丁因此按控制序列实际绑定分流，不能把“同样叫引用”当成同一实现入口。

## MWE 的说明层也会被系统修改

第一版视觉 MWE 用 `\texttt{\detokenize{#1}}` 展示候选源码。它看似忠实打印 token，实际排版仍经过 xeCJK；CJK 邻接处的源码空格会被 xeCJK 处理，于是 `00/10/01/11` 四种写法在“源码”列里可能看起来相同。证据图因此无法让读者确认测试输入，哪怕测量盒本身完全正确。

修正后把两件事分开：每行直接标 `00/10/01/11`，并把候选源码中的 literal space 显式换成蓝色可见空格 glyph；真正参与 oracle/candidate 宽度比较的盒子保持原输入。这揭示一条更一般的规则：测试报告的标签、源码转录和标尺不能再经过正在被测试的状态机，否则观察装置会抹掉要证明的差异。

## 生成物必须回到 canonical target

实现提交同步写了 `\changes`，但手工整理的 `xeCJK/CHANGELOG.md` 与仓库生成器并不一致，`check-changelog-result` 因而失败。正确入口已在根 Makefile 明确为 `make changelog`：它以 `CHANGELOG_PKGS` 为单一事实源，用 `extract-changes.py ... all -o` 确定性重建 UTF-8/LF 文件。

重新生成后只有 xeCJK CHANGELOG 变化，标题恢复 release 链接，条目正文回到 `\changes` 的实际提取结果。今后遇到跟踪生成物，第一步应读 Makefile/guide 找 canonical target，运行后检查“只产生预期 diff”，而不是把 CI 给出的文本继续手改进去。

## 审查闭环

自动审查总评为 APPROVE，但详情仍指出两份测试对无条件声明的 saved-marker 变量做了多余存在性检查。直接清空变量既让两个 reset helper 完全一致，也让未来内部变量改名时测试显式失败，不会悄悄跳过状态隔离。定向 76 个比较和随后的全平台 CI 均通过，增量审查确认无新问题。

## 结果与剩余边界

v3.10.4 的无 hyperref 内核引用和 hyperref starred 引用矩阵已进入 `ref-ecglue01/02`；ctex 节点基线证明 `\null` 保留、marker 后移。普通 linked-reference 以及 #992 列出的其他命令族仍按各自精确单元追踪，不能由这次 76 个通过项推出全部命令边界完成。

## 相关

- 决策：`llmdoc/memory/decisions/991-setref-null-marker-replay.md`
- 前置反思：`llmdoc/memory/archive/2026-07-18/992-command-boundary-oracle-matrix.md`
- 生成物门禁：`llmdoc/memory/reflections/961-changelog-freshness-gate.md`
- Issues：#991、#992；PR #993
