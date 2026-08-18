---
name: 1080-upstream-tocloft-fontspec
description: 记录 #1080 排查 master 定时回归四个红（github472-03/04、files01/02）时的两个互不相干的上游根因——tocloft v2.3i→v3.0a 主版本跳变新增净宽为零的 kern 对，fontspec 起不再显式加载 xparse——以及诊断链路本身有缺口（并行 check 的 diff artifact 路径缺失）时只能靠猜的教训；核心是失败集合的引擎分布差异本该是「不止一个成因」的信号，却先被拿第一个找到的成因去套第二组失败
metadata:
  type: feedback
---

# 反思：#1080 两个互不相干的上游漂移撞在同一批 CI 红上，与诊断链路本身的缺口

## 任务

master 定时回归从 2026-08-17 起失败，四个用例红：`github472-03`／`github472-04`（四引擎全红）与
`files01`／`files02`（仅 XeTeX 与 LuaTeX）。上一次定时跑（08-10）是绿的，其间 master 未碰
`ctex/`。本地当时全部通过。任务是排查这批红的根因，并处置基线。

## 结论与实现

两个互不相干的上游改动同时撞上：

1. **`tocloft` 从 v2.3i（2017/08/31）跳到 v3.0a（2026-08-12）**，主版本号跳变。影响
   `github472-03/04`（仓库里唯一两个 `\usepackage{tocloft}` 的用例）。差异是每个页码后多出
   一对 `\kern -1.0` / `\kern 1.0`——净宽度为零、相邻立即抵消，八份 diff 各 4 行新增、0 行
   删除，无任何非 kern 的新增行（LuaTeX 写作 `\kern-1.0` 无空格，形态相同）。
2. **`fontspec` 起不再显式加载 `xparse.sty`**。影响 `files01/02`——它们用 `\listfiles`
   固定加载文件清单，四份 diff 各只少一行 `xparse.sty`。pdfTeX／upTeX 不经 `fontspec`，所以
   不受影响，这正好解释了引擎分布。

处置：`l3build save` 刷 12 份基线。净变化 32 行新增（全是 kern ±1.0）+ 4 行删除（全是
`xparse.sty`），与逐份核对的 diff 完全对应、零意外。

另修一个诊断缺口：`_test-package.yml` 的 diff artifact 上传路径只有
`${{ inputs.pkg }}/build/**/*.diff`，而 `scripts/check-parallel.sh` 给每个引擎在
`tmp/parallel-check/<engine>/<pkg>/` 下各开一份工作区，diff 落在那里面。并行路径失败时
artifact 恒为空（CI 报 `No files were found`，`gh run download` 得到
`no valid artifacts found`）。已补上并行路径，并新增 `Show test diffs` 步骤把 diff 正文打进
日志（每份截断 200 行并提示总行数）。

## 核心教训

### 第一层：一次 CI 变红可能有多个不相干的成因，不要用第一个找到的成因去解释全部失败

最初发现 `tocloft` 主版本跳变后，就把 `files01/02` 也挂在它名下找原因，还去查了「`tocloft`
是否间接影响 fontspec 加载链」。实际它们毫无关系。**引擎分布本来就是提示**：
`github472-*` 四引擎全红而 `files0*` 只有两个引擎红——两种分布不同，说明是两条独立路径。
当时看到了这个差异，却没把它当成「成因不止一个」的信号。

教训：**失败集合的分布差异是成因数量的线索**。同一个成因通常产生同一种分布；出现两种分布
就该假设有两个成因，分别查。

这与 `llmdoc/memory/lessons-learned.md` 的「现象、联系、穷尽性、成因是四个独立命题」
（Source: `1046-1047-meta-anchor-font-context.md`）同源但角度不同：那条讲的是「同一个观察
对应多种可能解释，不能只验证一种就定论」；这里讲的是「多个失败的观察，可能对应多个互不
相干的成因，不能把其中一个成因的适用范围默认扩大到覆盖全部观察」。两者都指向「先划清观察
的边界，再谈成因」，但一个管解释的穷尽性，一个管观察集合本身要不要拆分——记两条不同的规则。

### 第二层：诊断缺口让排查只能靠猜，而缺口本身早已存在

`_test-package.yml` 的 diff artifact 路径不匹配导致并行路径失败时零诊断信息。原 issue 里
一度把原因写成「l3build 写到 `build/check/`」，那只是表面；真正原因是并行包装脚本
（`scripts/check-parallel.sh`）另开了工作区（`tmp/parallel-check/<engine>/<pkg>/`）。是自动
分析（agentic-issue-dispatch）指出的，核实后确认它对。

教训：**排查上游漂移之前先确认诊断链路是通的**。基础设施的缺口会把「读数据」变成「猜」，
而猜出来的归因即使方向对，细节也常常是错的（如本次「写到 build/check」这个说法）。

### 第三层：刷基线前必须先分类，且分类要有可核对的判据

`llmdoc` 里已有「上游宏包版本漂移的识别与基线处置」一节（#1048/#1050），判据是「会自愈的
不刷、上游不会回退的必须刷」。本次两者都属后者（`tocloft` 是发布方主动的版本跳变、
`fontspec` 是发布方主动改变依赖加载方式，都不是 TL 打包滞后的临时快照）。但额外做了一步值得
固化的检查：**逐份核对 diff 的内容形态**——确认 `tocloft` 侧只有净宽为零的 kern 对、
`fontspec` 侧只有文件名行删除，没有节点丢失、也没有 ctex 的补丁失效迹象，才敢 save。

教训：「上游不会回退」只回答了「要不要刷」，没回答「刷了会不会把上游的新缺陷冻结进基线」。
后者要靠核对 diff 的**内容性质**：净宽为零的 kern、纯文件名行增删是安全的；节点缺失、数值
变化则必须先查本包的补丁是否仍成立。这条与 #1037 那次「把残留缺陷冻结成预期基线」是同一个
家族——那次是把非零缺陷量写成预期值，这次是刷基线前先排除有没有非零缺陷量藏在里面，是同一
条规则应用在「刷新前」而不是「刷新后」。

## 具体的坑

1. **并发跑 `l3build check` 会让先跑的那个崩溃。** 在全套跑的过程中另起了单用例 check，
   两者共用 `build/` 目录，先跑的那个报 `./build/check/part-format01.log: No such file or
   directory` 并 traceback 退出——看起来像测试失败，实际是自己造成的干扰。教训：同一包目录
   下 `l3build check` 不能并发；要并行得用 `scripts/check-parallel.sh`（它给每个引擎单独开
   工作区，正是为此）。这与 #1026 反思记录的「并行跑 `l3build save` 和 `l3build check`
   互相清掉了共享的 `build/test` 目录」同源，都是共享 `build/` 目录导致的争用，只是本次是
   两个 `check` 而不是 `save` 与 `check`。

2. **诊断脚本不要用 `set -e` 也不要用进程替换。** 新增的 `Show test diffs` 步骤是纯诊断，
   任何一环失败都不该盖掉真正的测试失败，所以不设 `set -e`；`find` 无匹配时返回非零也用
   `|| true` 兜住。另外 Windows 那条 matrix 用的是 `C:\msys64\usr\bin\bash.exe -e {0}`，为
   避开 shell 差异，改用临时列表文件而不是 `< <(...)` 进程替换。

3. **给用例补了「失败诊断说明」注释。** `files01/02` 与 `github472-03/04` 各加了一段注释，
   写明它们分别对什么敏感、下次同类失败如何判断（看 diff 是否只有文件名行增删／只有净宽为
   零的 kern）、以及为什么保留这种脆弱基线。这类注释的价值在于：后来者遇到红的时候，判据
   就在用例里，不必翻 issue 历史。

## Promotion Candidates

以下一条建议新开条目提升到 `lessons-learned.md`：

- **失败集合的分布差异是成因数量的线索。** 同一批 CI 红若在不同引擎／不同用例上呈现不同的
  受影响范围，应假设有多个互不相干的成因，分别排查，而不是把第一个找到的成因套到全部失败
  观察上。

以下一条建议追加到既有的「刷 `.tlg` 基线前先按上游根因分类」（Source: #1048/#1050）附近，
作为该判据的补充步骤，不新开条目：

- 判定「上游不会回退，必须刷」之后，还要逐份核对 diff 的内容形态（净宽为零的 kern、纯文件
  名行增删是安全信号；节点缺失、数值变化则要先查本包补丁是否仍成立），否则会把上游的新
  缺陷一起冻结进基线。

## Follow-up

- recorder：`llmdoc/reference/build-and-test.md` 的「上游宏包版本漂移的识别与基线处置」
  一节补入本次两个实例，并补记 diff artifact 的两条路径、`Show test diffs` 步骤、并行工作区
  路径这一事实，以及「同一包目录下 l3build check 不能并发」。
- recorder：`llmdoc/index.md` 加一行索引指向本反思。

## 相关

- Issue：#1080。
- 实现：`.github/workflows/_test-package.yml`（`Show test diffs` 步骤新增；`Upload test
  diffs` 的 `path` 补 `tmp/parallel-check/**/build/**/*.diff`）；12 份 `.tlg` 基线刷新
  （`ctex/test/testfiles/{files01,files02,github472-03,github472-04}*.tlg`）。
- 相关反思：[[1048-1050-upstream-l3backend-pgf-baseline-drift]]（上游漂移分类判据的来源）、
  [[1026-ulem-literal-body-outer-shrink]]（并发 `l3build` 争用共享 `build/` 目录的先例）、
  [[1046-1047-meta-anchor-font-context]]（「现象、联系、穷尽性、成因是四个独立命题」）。
