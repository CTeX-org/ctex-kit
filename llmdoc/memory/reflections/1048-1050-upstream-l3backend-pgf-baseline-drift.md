# #1048/#1050 反思：l3backend／pgf 上游漂移与 CI 缓存分叉

## Task

PR #1050 给 xpinyin 补独立回归测试，CI 出现 10 个红，全部落在 `test-ctex` 与
`test-xeCJK`，与本 PR 改动的文件（`xpinyin/`、workflow、`llmdoc/`）无路径交集。
PR #1048（xeCJK 文档订正）为解决同一批失败改了 27 个 `.tlg`。本轮任务是对这批红做
一次根因排查，并判断 #1048 那 27 个 `.tlg` 各自该刷还是该撤回。

## Expected vs Actual

- 预期：`test-xpinyin` 本身全绿、diff 不含改动文件路径，应该能很快确认「与本 PR
  无关」，交给一个独立的基线刷新 PR 处理。
- 实际：确认「无关」本身没有问题（三条独立证据：路径 diff 为空、本地干净 master
  worktree 复现、diff 内容与新增字体包无关）；但排查过程中先把「本机能复现失败」
  当成了「CI 上 master 重跑也会红」的证据，发出了一条错误的 PR 评论，之后又更正。
  根因排查本身分成两条独立的上游问题，一条该刷一条不该刷，且中途两次误判（复现位置
  放错、CLEVEREF 归因跳过本仓库文档）。

## What Went Wrong

### 1. 用本机复现代替 CI 证据，发出了一条错误结论

第一版评论断言「master 上重跑同一 commit 也会红」，依据是在 `/tmp/mbase`（本机
worktree）上跑未改动的 `origin/master` 复现了失败。这条推理不成立：本机 TeX Live
与 CI 的 TL bypass 缓存是两个独立快照，本机能复现只能说明本机的 TL 已经漂移，推不出
CI 缓存也已经漂移。实际查证后，master 同一 commit 在 CI 上重跑（attempt 2）是全绿的。

发出错误评论后，靠对比缓存创建时间与体积才定位到真正原因：CI 的 TL bypass cache key
含 `hashFiles('.github/tl_packages')`；#1050 给 `dejavu`／`gnu-freefont` 加了三行，
key 随之改变，PR 侧 cache miss、当场全新安装拿到当前上游版本；master 命中的是一天前
写入的旧快照。同一个 commit `2dd5af66`，master 绿、PR 红，绿是旧缓存挡住了漂移，不是
代码在新 TL 下仍然通过。旧快照最迟在本周 key 按 `%G-W%V` 轮换时失效，届时 master 自己
也会红。

### 2. 注入替代版本宏包两次放错位置，得到两次假阴性

为了在不碰系统安装的前提下用新版 l3backend 重跑测试，必须把它放进 `build/local`
（`localdir`），由 l3build 在 `checkinit` 阶段复制进 `testdir`（`l3build-check.lua:74-76`）。
直接写 `testdir` 会在每轮开头被 `cleandir` 清空；设 `TEXINPUTS` 也无效，
`l3build-check.lua:850` 写死 `TEXINPUTS=.` 加 localtexmf 覆盖掉。前两次都放错了位置，
两次都得到「仍然红」的结果——如果不核实注入是否真的生效，就会顺势得出「新 backend 也
修不好」这个错误结论。生效判据是跑完之后 `build/test/l3backend-xetex.def`（ctex 是
`build/check/`）里的日期戳仍为 `{2026-07-20}`；没有这个判据，两次假阴性无法与真结论
区分。

### 3. CLEVEREF 归因先跳过了本仓库已有文档

第一版评论把 `cleveref02/03` 那 4 个 `.tlg` 判定为「根因未定位，建议单独查」，走的路径
是直接读上游源码（`latex2e-first-aid-for-external-files.ltx:238`）。之后发现
`llmdoc/architecture/cleveref-patch.md` 早已把根因链记全：LaTeX firstaid 的
`\firstaid@cref@updatelabeldata` 缺 appendix 特判，把 `[appendix][1][2147483647]A.`
覆盖成 `[chapter][1][]A.`，上游 `latex2e#2049` 明确表示不修。本可以先查文档省掉一次
误判，却是直接去读上游源码。

### 4. 临时验证 worktree 建在 `/tmp` 而非项目 `./tmp`

`/tmp/mbase` 用完后已不存在，本次反思写作时想复核当时的对比过程已无法复核。这条规则
本身早已在个人记忆里（临时测试文件放项目 `./tmp`），本次又踩了一次。

## Root Cause

- **本机复现 ≠ CI 复现**：两者是独立的软件快照，没有共同的时间基准。把「本机能复现」
  当作「CI 会复现」的证据，跳过了直接查 CI 侧证据（缓存 key、创建时间、体积）这一步。
- **CI 绿的前提被证伪**：本仓库此前总结的规则是「CI 是已知良好基线，本地与 CI 的差异
  是第一信号」（见 `873-880-meta-url-hbox-math-boundary.md`）。该规则默认 CI 结果在同一
  时间窗口内是一致的；本次 cache key 因 `tl_packages` 改动而分叉，master 与 PR 分别命中
  两个不同时间点的快照，「CI 一致」这个前提本身不成立，原规则因此失效。
- **注入实验缺生效判据**：两次误判都是因为没有核实注入动作本身是否成功，而不是判断
  逻辑本身有误。
- **排查上游问题时先跳到上游源码，而不是先查本仓库文档**：本仓库对已知上游问题有专门
  的架构文档记录根因链，直接去读上游源码等于重新做了一遍本仓库已经做过的调研。

## Missing Docs or Signals

- 现有 `llmdoc/reference/build-and-test.md`「本地测试失败的环境指纹检查表」只覆盖
  「本机 vs CI」这一种分叉场景，没有覆盖「CI 内部因 cache key 变化而分叉、导致同一
  commit 在不同 CI 运行中给出不同结果」这一种。后者的判别特征（缓存创建时间、体积、
  key 里的 hash 输入）与前者不同，值得单独补一条。
- 排查上游宏包问题前「先查本仓库 `llmdoc/architecture/` 是否已有该问题的根因记录」
  没有形成一个显式检查步骤，容易被跳过。
- 用 `build/local` 注入替代版本宏包进行 l3build 实验这一操作方法本身（放哪、判据是
  日期戳）目前只存在于本次 PR 评论文本里，没有进入任何 reference 文档。

## Promotion Candidates

- **「本机能复现」推不出「CI 会复现」，必须直接查 CI 侧证据**——这条比 #873/#880 那条
  「CI 是已知良好基线」的规则更精确，应作为其补充条件写入 `lessons-learned.md`：CI 各次
  运行之间也可能因缓存分叉而不一致，此时应比较缓存 key／创建时间／体积，而不是拿本机
  结果替代任一侧的 CI 结果。
- **注入类实验必须有可核实的生效判据**，可与已有的「探针先自证有效」系列规则并入
  `lessons-learned.md` 同一主题下。
- **排查上游问题前先查本仓库 `llmdoc/` 是否已有根因记录**，可作为通用检查步骤补进
  `lessons-learned.md`（与 #1029 的「报告者变通不能替代对代码历史用途的核实」同属
  「先查已有产出，再去外部找答案」这一类）。
- **上游漂移分类判据**（自愈型 vs 不会回退型；关掉断言不是刷基线）本身适合作为
  decision 记录：若后续真的开一个基线刷新 PR，应引用本反思与 #1048 PR 评论里的分类表
  （PGF 保留、BACKEND 撤回、CLEVEREF 单独按既有决策处理），而不是重新排查一遍。
- `build/local` 注入替代版本宏包的操作步骤（复制位置、`TEXINPUTS` 为何无效、日期戳
  判据）适合补进 `reference/build-and-test.md` 的「本地 TeX Live usertree 同步」附近，
  作为「验证上游某个版本是否已修复」的独立小节。

## Follow-up

- 若后续开独立的基线刷新 PR，直接复用 #1048 PR 评论里的分类结果：PGF 相关 11 个
  `.tlg`（`btrans matrix` / `0.3985 w` / `\pdfliteral origin` 几何）保留；BACKEND
  相关的 `\cleaders`+`\glue` 几何撤回并等 TL 同步 l3backend；`fntef-phase01` 的
  `PHASE-CHECK-PENDING` 占位撤回，因为它把一道能发现问题的检查关掉了；CLEVEREF 4 个
  按 #725 既有决策（`patch/cleveref` 开关）处理，不属于本次漂移。
- 若要把「CI 缓存分叉」判别加入 `build-and-test.md`，需要一份可复用的检查步骤：核对
  两次运行各自的 TL bypass cache key、`actions/cache` 命中记录里的创建时间与大小，
  而不是只看 job 是否绿。
- 下次遇到「本地复现了 CI 失败」的场景，先问一句「本地环境与 CI 环境此刻是否已知
  一致」，不一致时先查 CI 侧证据，再决定要不要发结论性评论。

### 后续进展（#1054）

本反思全篇的路径叙述限定在 `.tlg` 与 `l3build check`，那是当时事实的准确记录；#1054
把范围扩大了：

- 本轮加进 `_test-package.yml` 的内联 workaround 已抽成共享脚本
  `scripts/sync-l3backend.sh`，并接入 doc 与 release 两条此前完全没有防御的排版路径
  （`_check-doc-package.yml` 的 `l3build doc` 之前、`release.yml` 的 `l3build ctan`
  之前）。撤除判据不变，仍是脚本打印的 `::notice::`。
- **同一根因在 doc 路径不触发任何退出码**：编译 exit 0、PDF 页数与体积正常，只在正文
  里散落泄漏文本。因此本反思讨论的判别手段（`.tlg` diff、缓存 key 与创建时间对比）在
  doc 路径上都不适用，那条路径只能靠前置预防加目视检查。两条路径的表现差异与各自的
  判别方式，见 `reference/build-and-test.md` 的「CI 侧的临时 workaround」一节。
- 反思 [[1054-l3backend-defense-scope-and-kpse-lsr]] 另记 kpse `!!` 树与 ls-R 的机制，
  以及本反思「注入类实验必须有可核实的生效判据」的否命题形态（反证失败不等于假设错误）。
