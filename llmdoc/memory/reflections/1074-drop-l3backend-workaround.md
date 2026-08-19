---
name: 1074-drop-l3backend-workaround
description: 记录 #1074 撤除 l3backend 版本错配 workaround（scripts/sync-l3backend.sh 及三处调用）的过程；上游已把 l3backend 并入 l3kernel，核心教训是撤除条件要看 kpsewhich 实际解析到哪一份文件，不是看旧包在不在（两份同名 .def 可以共存、日期不同）；预判过的失败窗口（CTAN 404 撞上 tlnet 过渡态）没有撞上，但预判本身仍值得记录；撤除的清点范围与引入时对称
metadata:
  type: feedback
---

# 反思：#1074 撤除 l3backend workaround，与「撤除条件」的正确判据

## Task

上游把 `l3backend` 并入 `l3kernel`（latex3#1948）。#1074 是 muzimuzhi 开的预告 issue，
提醒 #1054 引入的 `scripts/sync-l3backend.sh` 届时需要调整。2026-08-18 的 CTAN 公告
（`CTAN update: l3kernel`，版本 2026-08-10）明确写「Integrate `l3backend` files into
`l3kernel` distribution」，即合并已落到 stable 通道；8-19 tlnet 也已跟进。任务是判断
撤除条件是否成立，并据此撤除 `scripts/sync-l3backend.sh` 及其三处调用、四处触发路径条目、
以及相应的文档记载。

## Expected vs Actual

- 预期：CTAN 与 tlnet 都同步之后，旧 `l3backend` 包会从 tlnet 消失，「包不在了」就是撤除
  的信号，是一次直接的清理工作。
- 实际：撤除条件成立，但判据不是「包不在了」——旧 `l3backend` 包（revision 79958，日期
  仍是 07-20）**依然留在 tlnet**，`l3kernel` 只是在 `depend` 里去掉了它，形成「同名
  `.def` 存在于两个包、日期不同」的过渡态。真正的判据是 `kpsewhich l3backend-pdftex.def`
  实际解析到哪一份——两个包同时铺进 usertree 后，命中的是 `l3kernel` 那份（08-10），
  与 `l3kernel` 的 `\ExplFileDate` 一致，脚本的日期比较走空转分支、打出撤除
  `::notice::`。只装新版 `l3kernel` 时同样如此。两种环境下撤除条件都成立。

## What Went Wrong

严格来说这次没有走弯路或引入缺陷，实测与文档改动一次到位。值得记的是判断过程本身纠正了
一个直觉误判，以及一个预判过的风险窗口没有撞上。

### 1. 直觉判据「包没了就能撤」在这里会得出错误结论

第一直觉是查 CTAN 与 tlnet 上「`l3backend` 这个包还在不在」。CTAN 侧确实已经移除
（`ctan.org/json/2.0/pkg/l3backend` 返回 `id: None`，`macros/latex/required/l3backend.zip`
返回 HTTP 404），但 tlnet 侧旧包**仍然存在**，日期还是 07-20。如果判据停在「包在不在」，
会在包还没被 tlnet 撤下的这段过渡期里得出「还不能撤」的错误结论——而实际上此时
`kpsewhich` 已经优先命中 `l3kernel` 提供的新版 `.def`，撤除条件早就成立了。

正确判据是**实际被解析到的那份文件是什么版本**，不是**旧包在不在**。两份同名 `.def`
可以在 tlnet 上长期共存，kpse 的搜索顺序（`l3kernel` 优先于旧 `l3backend`）决定了真正
生效的是哪一份，这与「旧包有没有被清理」是两件独立的事。

### 2. 预判的失败窗口没有撞上，但预判本身是对的

在 #1074 里预判过一个窄窗口：若出现「`l3kernel` 已更新而 `l3backend` 仍旧」的过渡态，
脚本会判定两个日期不一致、进入下载分支，而此时 CTAN 的 `l3backend.zip` 已经 404，脚本
会报出误导性的「这是网络/镜像问题，重跑本 job 即可」——让人反复重跑徒劳的 job，真相却是
「资源已经不存在，该改代码而不是重试」。

现实中恰好因为 kpse 优先命中新版 `l3kernel` 而没有撞上这个窗口：脚本探测到的两个日期从
一开始就是一致的（都是 08-10），从未进入下载分支。但**这不说明这条预判没有价值**：那个
失败形状——404／410 意味着资源已经变了、需要改代码，超时／5xx 才意味着网络抖动、重跑
有意义——对任何「从上游下载单个资源」的步骤都成立。仓库里 `HanaMinB`、`Unihan` 等下载
脚本同样没有做这个区分，遇到 404 时会和遇到超时一样报「重跑即可」。已把这一点补记进
`build-and-test.md`，作为已知但尚未修的技术债。

教训：把「没撞上」记成「不用管」是错的。要区分「风险未实现」（这次没发生，但下次条件
变化可能发生）与「风险不存在」（这个失败形状根本不可能出现）。

### 3. 撤除的清点范围必须与引入时对称

#1054 引入这个脚本时，更新了三处 `run:` 调用却漏了触发面（`on.paths` 白名单与
`_all` filter），被两个 bot 独立指出。这次撤除时同样要清点那几处：脚本本身、三处
`run:` 调用（`_test-package.yml`、`_check-doc-package.yml`、`release.yml`）、四处
触发路径条目（`check-doc.yml` 的 `on.pull_request.paths` 与 `_all` filter、
`test.yml` 的 `_all` filter）。没有这一步会留下指向不存在文件的白名单条目——`paths`
里的文件名不存在不会报错，只是白名单条目变成死代码，不会主动暴露。

`llmdoc/memory/lessons-learned.md` 里那条规则（Source: #1054）本来只写了引入侧
（「抽出共享脚本时触发白名单与 job filter 属于调用点的一部分」），本次已补上
「撤除时对称成立」，而不是新开一条独立条目——这是同一条规则的另一半，不是新规则。

## Root Cause

- **「资源是否存在」与「资源是否被实际使用」是两个独立的判据，前者不能替代后者。**
  kpse 的搜索路径决定了「哪份文件生效」，这个决定与「旧文件有没有被物理删除」无关。
  判断一个 workaround 是否还需要，要看它防御的那个错配**是否还会在实际解析路径上发生**，
  不是看造成错配的旧资源是否已经清理干净。
- **验证撤除条件时要覆盖两种时序，不能只测最终稳态。** 只测「两边都更新完成」这一种
  情形不够，因为脚本会在中间过渡态（一边更新一边没更新）运行；本次专门实测了「只有
  新 `l3kernel`」与「新旧两包共存」两种环境，确认两者都成立才敢下撤除结论。

## Missing Docs or Signals

- CTAN 的打包内容与 TeX Live 打包内容之间的差异此前没有记录。CTAN 的 `l3kernel.zip`
  （14 MB）里只有 `.dtx` 与 `l3backend.ins`，`l3backend-*.def` 是 **TeX Live 打包时由
  `.ins` 生成**的，不在 CTAN 的 zip 里。判断「某个文件名会不会消失、还能不能被
  `kpsewhich` 找到」这类问题，要看 tlnet 的 TDS 包（`systems/texlive/tlnet/archive/
  <pkg>.tar.xz`），不能只看 CTAN 公告或 CTAN zip 内容——这一点已补进
  `build-and-test.md`，因为它对任何「按 CTAN 公告判断 TeX Live 分发内容」的场景都成立。
- 「下载失败要区分资源已不存在与网络故障」这条规则此前也不存在，脚本对下载失败一律报
  「重跑即可」。已记入 `build-and-test.md` 作为已知技术债，未修复（本次撤除后这段代码
  已随脚本删除，但同类模式仍存在于 `HanaMinB`／`Unihan` 等下载步骤里）。

## Promotion Candidates

**已并入 `memory/lessons-learned.md` 既有条目（未新开条目）：**

- 「抽出被多个调用点共用的脚本时，触发白名单与 job filter 属于『调用点』的一部分」
  （Source: #1054）补充「撤除共享脚本时对称成立」，用 #1074 的实例说明。

**建议下次遇到类似「上游合并/废弃某个包」的场景时直接复用的判据（本次未新增到
lessons-learned，因为目前只有一个实例，先记在本反思供后续参考）：**

- 判断一个上游 workaround 是否可以撤除，去查「实际被解析/生效的资源是什么版本」，
  不要停在「旧资源是否已被清理」；两者在打包过渡期可能长期不一致。
- 验证撤除条件时至少覆盖两种时序：仅新版本存在、新旧版本共存的过渡态；只测其中一种
  可能漏掉过渡期的边界情况。

## Follow-up

- 「下载失败要区分资源已不存在与网络故障」这条技术债留在 `build-and-test.md` 里，
  未修复。如果 `HanaMinB`／`Unihan` 等下载脚本未来遇到同类 404，可以参考本次记录的
  失败形状（404/410→改代码，超时/5xx→重跑）来修。
- CI 侧的实际验证（08-10 那个 `l3kernel` 组合下 `l3build doc`／`check` 是否仍然全绿）
  要等下周一 TL bypass cache 失效、CI 装到新版 TeX Live 之后才能确认；本地验证只能
  证明「删掉脚本不破坏现有流程」，不能证明「新版本组合下也正常」，两者是不同的命题。

## 相关

- Issue：#1074（预告）；上游根因：latex3#1948（`l3backend` 并入 `l3kernel`）。
- 实现：删除 `scripts/sync-l3backend.sh`；删除三处 `run:` 调用
  （`_test-package.yml`、`_check-doc-package.yml`、`release.yml`）；删除四处触发路径
  条目（`check-doc.yml` 的 `on.pull_request.paths` 与 `_all` filter、`test.yml` 的
  `_all` filter）；改写 `llmdoc/reference/build-and-test.md`（原「CI 侧的临时
  workaround」一节改写为「已撤除：`scripts/sync-l3backend.sh`」，保留仍适用的机制部分）、
  `llmdoc/guides/release-workflow.md`（删第 6 步并重编号，「第 6 步为什么必须在 ctan
  之前」改写为「打包路径上的污染不触发任何退出码」）、`llmdoc/memory/doc-gaps.md`、
  `llmdoc/memory/lessons-learned.md`、`llmdoc/reference/kpse-path-resolution.md`。
- 相关反思：[[1054-l3backend-defense-scope-and-kpse-lsr]]（引入本 workaround 的前一轮，
  确立「抽出共享脚本时触发白名单与 job filter 属于调用点的一部分」，本轮把这条规则
  扩展到撤除侧）、[[1048-1050-upstream-l3backend-pgf-baseline-drift]]（同一上游漂移的
  最早排查，确立「刷基线前先按上游根因分类：会自愈的不刷」——本轮的撤除正是「会自愈」
  分类兑现的时刻）。
