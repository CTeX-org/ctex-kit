# zhnumber 的维护状态

zhnumber 原由 @qinglee 维护。社区自 2022 年起与其断联约四年，与 CTAN 管理员沟通后的安排是：
若 2026 年 9 月底前仍未收到回复，则考虑启动维护者变更流程。详见 #1041。

在维护权归属明确之前，zhnumber 的改动集中在 `zhnumber/maintaining` 分支上集成，而不是逐个
直接并入 `master`。这样做是为了随时能看清「若接手维护，累积的改动是什么」，也便于在一处
验证各改动之间的相互影响。

xpinyin 用的是同一套做法（分支 `xpinyin/maintaining`，PR
[#1051](https://github.com/CTeX-org/ctex-kit/pull/1051)）。注意那边的
`xpinyin/MAINTAINING.md` 只存在于它自己那条维护分支上、不在 `master`，所以在当前分支按
路径找不到它；要看范例请走
[这个链接](https://github.com/CTeX-org/ctex-kit/blob/xpinyin/maintaining/xpinyin/MAINTAINING.md)。

这条分支上已经集成的改动：

- **#1008**（PR #1058，版本 3.2）——带选项的 `\zhnum[opts]{counter}` 原先把计数器**名**
  而不是当时的值写进 `.toc`，读回时计数器已归零，于是「section 用一种中文数字样式、
  subsection 用另一种」这类混搭做不出来。修法是在 `\zhnum` 这一层先把计数器展开成
  数值，再交给处理数值的实现。
- **#366**（PR #1062，版本 3.3）——新增算筹数字：可展开的 `\zhrod`、负责排版效果的
  `\zhrodbox`，以及配置入口 `\zhrodsetup`（七个键，注册在独立模块 `zhnum / rod`）。

#366 还留下两条文档待办，是审计报告在 PR 合并后才送到的，需要后续处理：手册里
「`\zhrod{1{ab}4}` 报八条错误」这个条数有争议（两次独立复现给出 4 与 8 两个读数，需要
核准计数口径——引擎、是否计入缺字警告、字体上下文）；driver 区两行新增中文注释用了半角
标点。另外 `build.lua` 里那句「仅 `rod-engine01` 需要 `.uptex.tlg`」写于 `rod-engine02`
从它拆出之前，现在两个用例各有一份，属注释滞后。

（原先还有第三条「`\changes` 与 `CHANGELOG.md` 漏记 `\zhrodsetup`」，已在本分支补上。）

## 提交改动

zhnumber 的 PR 请以 `zhnumber/maintaining` 为合入目标（而非 `master`）。

改动前后都要跑**两条**命令：

```sh
cd zhnumber
l3build check                        # 主测试目录, 四个引擎
l3build check -c test/config-cjk     # CJK 测试目录, 仅 xetex
```

第二条容易漏，但不能省。主目录的用例只在记号层面比对，凡是要检验「实际排出的是哪个
字形」的用例都放在 CJK 目录，它需要单独指定 config 才会跑；CI 里这两条是分别执行的
（`configs` 列表里带上了 `test/config-cjk`）。漏跑第二条会完全跳过 `legacy-entry01`
与 `rod01`。

第一条命令覆盖四个引擎。`build.lua` 里
`checkengines = {"pdftex", "xetex", "luatex", "uptex"}`、`stdengine = "xetex"`，
所以基线文件有四种名字：

- `<name>.tlg` —— `stdengine`（xetex）的基线，**输出与它一致的引擎也比对这一份**；
- `<name>.pdftex.tlg` —— pdfTeX 的基线；
- `<name>.luatex.tlg` —— LuaTeX 的基线，仅在它与 xetex 分化时才需要；
- `<name>.uptex.tlg` —— upTeX 的基线，同上。

判断要不要加专属基线，看的是**该引擎的输出是否与 xetex 分化**，不是看有几个引擎。
最初 luatex 没有专属基线，就是因为它当时的输出与 xetex 一致。后来两次分化各有缘由：
`counter-options01`／`counter-options02` 的 `.luatex.tlg` 是因为 luatex 在可展开报错
之后打印的 help 行比 xetex/pdftex 少四行（#1008）；两个算筹引擎用例的
`.luatex.tlg` 与 `.uptex.tlg` 是因为它们测的正是「引擎能不能表示算筹码位」，四个引擎
分成能与不能两组，报错文本各不相同（#366）。

upTeX 是随 #366 加进来的。加它的理由是：算筹在 U+1D360–U+1D371，upTeX 与 pdfTeX 同为
8-bit 引擎、无法表示这些码位，所以引擎判定必须把它排除在外；而若判定误把 upTeX 算作
可用，在只有三个引擎的情况下不会有任何用例发现（实测把判据改成接受 upTeX 后两套 check
仍全绿）。配套还要给 `specialformats.latex` 补 `uptex = {binary = "euptex"}`。

主测试目录现有七个用例：`basic01`（基本数字转换）、`style01`（`\zhnumsetup` 的各
style）、`deprecation01`（已废弃接口的告警）、`counter-options01`／`counter-options02`
（带选项的命令写入辅助文件，#1008）、`rod-engine01`／`rod-engine02`（算筹的引擎判定与
两个命令各自的报错分支，#366）。

CJK 测试目录（`testfiles-cjk/`，配置见 `test/config-cjk.lua`）现有两个用例：
`legacy-entry01`、`rod01`（算筹的实际输出与排版效果，11 个断言）。这个目录只在 xetex
下跑，因为它检验的是排出来的字形本身。

`rod01` 需要 `LXGWWenKaiGBLite-Regular.ttf` 与 `JuliaMono-Regular.ttf` 两款字体
（来自 TeX Live 的 `lxgw-fonts` 与 `juliamono`，后者随 #366 加进
`.github/tl_packages`）。本地缺任一款都会让该用例在载入字体阶段中止。要两款是因为两种
负号记法所依赖的字符恰好互补：含全部算筹字形的 19 款字体里，`lxgw-fonts` 的 5 款只有
U+FF3C（`minus=slash` 用），`juliamono` 的 14 款只有 U+20E5（`minus=overlay` 用），
没有一款同时具备。

**改动涉及样式配置时要特别当心 `style01`。** 那个用例固定的正是「`\zhnumsetup` 的配置
如何作用于 `\zhnum`」这一层语义。如果为了让新行为通过而放宽或删掉它的断言，那不是刷基线
而是关掉校验 —— 正确做法是在新语义下重新生成基线，并**逐项**核对每条断言的变化是否都是
预期的（`l3build check` 的退出码只说明「与基线一致」，不说明「基线仍在守着原来那件事」）。

已集成的两个改动都没有触碰它，可作参照：#1008 改的是「计数器何时被展开成数值」，样式的
作用范围语义未变；#366 的配置走独立模块 `zhnum / rod`，`\zhrodsetup` 与 `\zhnumsetup`
各管一件事（后者管「每个数字写成哪个汉字」，前者管「按位值选哪一式筹码」），键不通用。
两者区间内 `style01.lvt` 与 `style01.tlg` 均零改动，两处 `\zhnumsetup` 断言原样保留。

改完之后请确认既有的可展开性约定没有被破坏。这里要分清两件事，手册（`zhnumber.dtx`）对
它们的表述不同：

- 包的英文序言把「命令可正确展开」列为 zhnumber 相对 `CJKnumb` 的**主要优势**，所以不带
  选项的 `\zhnum{counter}` 本身是可展开的；
- 而带选项的形式（`\zhnum[options]{counter}`、`\zhdig[options]{counter}`）手册明确写着
  「这些带了选项的命令是不可展开的，在某些场合使用时要小心」。

#1008 的困境正落在这个交界上：用户要按层级切换样式，现成手段只有带选项的形式（不可展开）
或全局 `\zhnumsetup`（所有层级共享）。它最终**没有**改这些命令的展开性——那样做只会把
「不可展开」换成「静默用错样式」，因为样式靠赋值实现，而赋值无法在 `\edef` 的展开中生效。
实际修法是让写进辅助文件的内容从「计数器名」变成「已固定的数值」，样式留待读回时套用。

#366 又一次撞上同一条界线，处理方式是**分成两个命令**：`\zhrod` 只产字符，因此可展开，
能进 `.toc` 与 PDF 书签；`\zhrodbox` 要切字体、压字距，因此不可展开，不能写进辅助文件。
这两件事无法兼得，与其做一个「有时对有时错」的命令，不如让接口本身把差别摆明。

所以后续若有改动要通过改变展开性来实现某个功能，那是一处**行为变更**而非纯修 bug，需要在
`\changes` 与 CHANGELOG 里如实说明，并确认不破坏序言承诺的那条优势。上面两次的经验是：
先问「这个效果是否必须在排版期才能产生」，若是，就不要试图把它塞进可展开的路径。

## 版本与发布

`zhnumber/build.lua` 的 `version` 是发版事实源（随 PR #1055 补上），须与 `zhnumber.dtx`
里紧跟在 `{\ExplFileDate}` **之后**的那个参数一致（当前是 `{3.3}`）。

注意 `\ExplFileDate` 本身是**日期**槽位，不要改它——`\ProvidesExplPackage` 的参数顺序是
文件名、日期、版本、说明。

回写由 `l3build tag` 完成（`support/build-config.lua` 里共享的 `update_tag`，用
`({\ExplFileDate})%b{}` 替换紧随其后的花括号组）。两道 CI 校验会盯着它：

- `check-tag.yml` 的 `tag-zhnumber` job 要求跑完 `l3build tag` 后 `git diff` 为空；
- `release.yml` 打 tag 时校验 git tag / `version` / dtx stamp 三方一致。

这两道校验是 PR #1055 补的——在那之前 zhnumber 不在任何版本校验内，`release.yml` 会打一条
「不使用 l3build tag 版本 stamp 机制, 跳过三方校验」的 `::notice::` 然后放行，而那句话是
错的。同批还补了 `scripts/check-version-gate-coverage.py` 做白名单对账。

面向用户的变更写进 `zhnumber.dtx` 的 `\changes`，`CHANGELOG.md` 由
`make changelog-zhnumber` 生成，不要手写。

## CTAN 投递

zhnumber **尚未**接入 CTAN 投递自动化（`release-ctan-upload.yml` 目前只支持
ctex / xeCJK / zhlineskip）。那个 workflow 对其余包直接 `::error::` 退出，是 fail-closed，
不会误投，所以属能力缺失而非安全缺口。

接入需要两处：workflow 的 `Parse tag` 加 case，以及 `build.lua` 加 `uploadconfig`
（用共享的 `ctex_kit_uploadconfig`）。后者要填 CTAN 目录的对外描述（`summary`、
`description`、`ctanPath` 等），且「谁有权代表这个包向 CTAN 上传」本身取决于 #1041 的
结论，所以这件事留到维护权明确之后再做。
