# Reflection: Issue #531 下划线 leader 相位

## 目标与纠偏

Issue #531 的原图同时展示普通 `\CJKunderline` 与 `subtract` 变体。早期调查把普通下划线相对文字的横向偏移解释为 ulem 回退覆盖与驱动浮点累积误差；PR #798 则只修改 subtract 才会进入的 `\xeCJK_ulem_leaders:`，试图补满相邻变体的接缝。前者未能在当前与 2020 年源码上复现文字游标漂移，后者既到不了普通命令路径，也违背 subtract “首尾减少一定距离，避免前后下划线连在一起”的公开语义。

原图中的有效信号是线条相对文字近似等长平移。恢复默认段首缩进，并分别增加 0pt、1pt、3pt、5pt 前置位移后，普通 `\leaders` 的线条起点随外层相位跳变；去掉段首缩进恰好会掩盖问题。固定字体、字号和正文宽度后，命令盒宽始终不变，因此宽度回归无法区分正确与错误输出。

## 根因与方案

`\CJKunderline` 用宽度 `.2em` 的 rule box 作为 ulem mark，并通过普通 `\leaders` 重复。TeX 只输出完整落入 leader 区域的盒，且普通 leaders 相对外层水平列表保持统一相位；当前文字起点变化时，首尾被舍弃的余量落在同一侧，于是连续规则看起来整体横移。`\cleaders` 把余量均分到区域两端，固定 rule 因而相对正文居中；subtract 模式也自然得到对称的首尾缩短和稳定接缝。

#965 最初只在 `\CJKunderline` 的局部分组中通过 ulem 公共扩展点 `\ULleaders` 选择 `\cleaders`，当时为保留跨 ulem 小片段的全局配准而让波浪线和叉线等图案继续使用普通 `\leaders`。随后 #967 用同一组非零起点、普通/`subtract`、标点和换行实验确认，其他线型命令同样存在端点随外层相位错落的问题。规则型的 `\CJKunderdblline`、`\CJKsout`、`\CJKxout`、`\CJKunderanyline` 因而改用局部 `\cleaders`。第一版也把 `\CJKunderwave` 改成 `\cleaders`，但放大观察多汉字普通/`subtract` 输出后发现：每个 CJK 片段独立居中会在字间接缝形成双峰。0/1/3/5pt 起点对比确认 `\xleaders` 同时消除外层相位漂移并维持周期图案跨片段连续，因此波浪线最终单独使用 `\xleaders`。这不是对 ulem 或 `\xeCJKfntefon` 的全局替换。

## 验证与可复用方法

回归在 3pt 非零起点下检查普通与 subtract 两条路径的 leader 节点：规则型命令为 8 次 `\cleaders`，波浪线为 2 次 `\xleaders`；多汉字节点链另行覆盖普通/`subtract` 的 CJK→CJK 分片接缝。既有 fntef 基线仅改变 leader 类型，glue、字体节点、分页与尺寸均未改变。额外用 Noto Sans CJK SC Black 在多个起始偏移下对比输出坐标和放大栅格图：`\leaders` 端点随外层相位漂移，`\cleaders` 波浪线字间双峰，`\xleaders` 同时保持端点稳定与字间连续。

可复用的调查顺序是先确认命令实际进入哪个宏路径，再区分文字节点、leader 区域和 shipout 坐标；看到“少一个重复盒宽”的缺口时优先检查 TeX 的完整盒与相位语义。视觉实验必须保留触发问题的段首缩进或前置位移，不能为了简化 MWE 把关键相位条件删掉。
