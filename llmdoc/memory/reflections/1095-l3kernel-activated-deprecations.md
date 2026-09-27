---
name: 1095-l3kernel-activated-deprecations
description: 记录 #1095／PR #1096 排查 l3kernel 2026-09-09 启用两批弃用后 xeCJK、zhnumber、ctex 调试模式测试全红的过程；两次弯路分别是按 CHANGELOG 的 Deprecated 条目认定成因、未读编译日志就提出环境假设
metadata:
  type: feedback
---

# 反思：#1095 l3kernel 启用弃用导致调试模式测试全红

## Task

PR #1056（`zhnumber/maintaining`）rebase 后推送，`test.yml` 的 push 运行里
`test-xeCJK`、`test-zhnumber`、`test-ctex`、`test-ctex-luatex` 在三个平台全红。同一提交的
pull_request 运行显示成功，但主仓自家分支的 pull_request 运行按设计跳过全部包测试
（`test.yml:59-86` 注释），真实结果只在 push 运行里。master 09-21 的定时运行仍是绿的，
因为当时 tlnet 还没有 l3kernel 2026-09-09。任务是查明根因并修复。

## Expected vs Actual

- 预期：找到上游改动，在本地复现，改代码后三包测试恢复通过。
- 实际：最终结论正确，修复范围小（两处换新名、删一行多余的变体声明）。但定位成因和本地
  复现各绕了一次弯路。

结论：l3kernel 2026-09-09 包含上游 `03b50f7e`、`17c031ed` 两个提交，把早已宣布的弃用
改为启用：旧名 `\cs_argument_spec:N` 由 `\cs_parameter_spec:N` 替代，旧名
`\keys_set_filter:nnnN` 等由 `\keys_set_exclude_groups:*` 替代。启用 `\debug_on:n { deprecation }` 或 `{ all }`
时，用到旧名会立即报错。

- xeCJK `loading01` 用 `{all}`，`xeCJK.dtx` 的 `\__xeCJK_math_robust:NN` 用了
  旧名 `\cs_argument_spec:N`，报 “Forbidden control sequence found while scanning definition”。
- zhnumber `deprecation01` 用 `{deprecation}`，`zhnumber.dtx` 有 4 处 `\keys_set_filter`。
- ctex 经 `checkdeps` 加载仓库里的 zhnumber，所以 ctex 的 zhnumber 等测试也红。
- zhnumber 与 ctex 的 diff 显示 `.log` 为空（`index e69de29`）：错误发生在 `\START` 之前，
  而 l3build 不保留 `\START` 之前的输出。

修复（PR #1096）：从 master 切分支，两处换新名，删除多余的
`\cs_generate_variant:Nn \keys_set_filter:nnnN { nno }`（l3keys 已提供
`\keys_set_exclude_groups:nnoN`）。旧名只是新名的别名，行为不变；新名分别自 2022-06、
2024-01 起可用，早于两包的最低版本要求（xeCJK 要求 LaTeX2e 2026/06/01，zhnumber 要求
L3 2025/10/09），所以直接换名即可。新内核下 zhnumber、xeCJK
123/123、ctex 四引擎加三个附加配置全部通过；旧内核下 zhnumber、xeCJK 全部通过。PR CI
39 项通过、24 项跳过，Bot 审查 APPROVE，没有审查意见。

我起初认为换名对用户没有可见影响，没有写 `\changes`。用户指出这也要发版：下游宏包若在
开启调试检查的测试里加载 ctex／xeCJK／zhnumber，会与本仓库 CI 一样失败，而问题出在本
仓库的包里，下游自己修不了；上游将来删除旧名后，普通编译也会报错。于是补了
`\changes`：xeCJK 记在 v3.10.7（`build.lua` 3.10.6 → 3.10.7），zhnumber 记在尚未发布的
v3.1，随 3.1 一起发布。

用户决定另开 issue 并向 master 提 PR，而不是在 #1056 分支上修：master 同样受影响，
#1056 也不该混入 xeCJK 改动。合入后 #1056 再 rebase。同一轮 CI 里 `doc-zhlineskip` 的
失败是下载 install-tl 时网络超时，与本问题无关。

## What Went Wrong

### 1. 按 CHANGELOG 的 “Deprecated” 条目认定成因

先在 l3kernel CHANGELOG 里看到 “Deprecated: `\exp_after:wN`”，就以为是它。查
`l3deprecation.dtx` 才发现 `\exp_after:wN` 那行 patch 是注释掉的，上游注明它用得太普遍，
不会移除；真正生效的是 08-27 两个标题为 “Activate” 的提交。CHANGELOG 的 “Deprecated”
只说明“宣布弃用”，不说明“开始报错”。

### 2. 未读编译日志就提出环境假设

第一次在重建的新内核格式下跑 ctex，pdftex 几乎全红。我先怀疑临时 `TEXMFHOME` 遮住了
`~/texmf` 里的字体文件；用 `kpsewhich` 查过后证伪，相关文件都在 `texmf-dist`。读编译
日志才看到 “Mismatched LaTeX support files … format dated 2026-07-20 … require
2026-09-09”。原因是 `ctex/build.lua` 给 pdftex 指定
`specialformats.latex.pdftex = {format = "latex"}`，而我只重建了 `pdflatex` 格式，没有
重建 `latex` 格式。补建后全部通过。`build-and-test.md` 的 usertree 一节其实已经写明要按
引擎逐个重建 `latex`／`xelatex`／`lualatex`／`uplatex`，也写明漏建时的报错正是这一条。

## Root Cause

- 弯路 1：把 CHANGELOG 当成“哪些旧名会报错”的依据。决定是否报错的是
  `l3deprecation.dtx` 中未被注释的 `\__kernel_patch_deprecation:nnNNpn` 行，CHANGELOG 只能
  用来缩小范围。
- 弯路 2：看到大面积失败后，先根据“刚改了环境变量”这一事实猜原因，没有先读失败用例
  编译日志里的第一个 `!` 错误。那条错误信息本身就指出了原因，而且与文档中已记录的症状
  一致。

## Missing Docs or Signals

- 此前文档没有说明：l3kernel 的弃用分“宣布”和“启用”两个阶段，启用后只在开启
  `\debug_on:n` 的测试里报错，普通编译不受影响。
- 此前文档没有说明：expl3 预载在格式里，`localdir` 注入换不了 l3kernel，要验证新内核
  只能用临时 TEXMF 树重建格式。
- usertree 一节已有“按引擎逐个重建格式”的要求，但没有提示“格式名不一定等于引擎名”
  （ctex 的 pdftex 用 `latex` 而不是 `pdflatex`）。这次正是漏在这一点上。

## Promotion Candidates

### 可写入稳定文档的内容

以下内容已写入 `llmdoc/reference/build-and-test.md`，本反思不再重复展开：

- 【已写入】上游启用弃用的识别与处置：按 `l3deprecation.dtx` 中未注释的
  `\__kernel_patch_deprecation:nnNNpn` 行列出启用的旧名（本次共 65 个），在全仓
  `git grep`；新名的引入日期早于包的最低版本要求时直接换名。
- 【已写入】本地用新版 l3kernel 复现：从 CTAN 下载
  `install/macros/latex/required/l3kernel.tds.zip` 解到临时目录，设
  `TEXMFHOME`／`TEXMFVAR`／`TEXMFCONFIG` 指向临时目录后运行 `fmtutil-user --byfmt`
  重建格式，不改本机安装；格式名要按 `build.lua` 的 `specialformats` 确定（ctex 的 pdftex
  用 `latex` 而不是 `pdflatex`）；先在未修改的 master 上复现与 CI 相同的失败，再验证修复。
- 【已写入】主仓自家分支的 pull_request 运行跳过全部包测试，真实结果只看 push 运行。
- 【已写入】`.log` 为空（`index e69de29`）这一指纹：错误发生在 `\START` 之前。

以下只留在本反思里，暂不提升：

- CHANGELOG 的 “Deprecated” 条目不等于启用；本次被 `\exp_after:wN` 误导。它已被上面
  “已写入”的识别方法覆盖，单独再写一条规则意义不大。
- 大面积失败时先读编译日志里的第一个 `!` 错误，再提出环境假设。目前只出现一次；若再次
  出现，可以提升到 `lessons-learned.md`，并与 #1048／#1050 的“注入类实验必须有可核实的
  生效判据”放在同一主题下。
- 判断“对用户有没有影响”时，要把开启调试检查的下游测试也算作用户；已写入 build-and-test.md
  「上游激活弃用（#1095）」一节的处置部分。
- `ctex/test/support/cleveref-body.tex` 仍用 `\seq_set_map_x:NNn`，这是已启用的旧名，
  但目前不触发失败，本次未处理。

## Follow-up

- #1096 合入后，把 #1056 rebase 到 master，并确认其 push 运行中四个包的测试全部通过。
- 视情况单独处理 `ctex/test/support/cleveref-body.tex` 的 `\seq_set_map_x:NNn`：上游以后
  若把它从“启用弃用”推进到“删除”，它会直接报错。
- 下次重建格式后出现大面积失败，先 `grep -m1 '^!'` 失败用例的编译日志，再考虑环境原因。

## 相关

- Issue：#1095；PR：#1096；受影响的 PR：#1056。
- 相关反思：[[1048-1050-upstream-l3backend-pgf-baseline-drift]]（上游漂移的识别与
  `localdir` 注入）、[[1080-upstream-tocloft-fontspec]]（上游漂移造成定时回归变红）。
