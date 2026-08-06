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

当前待处理的主要问题是 #1008：`\zhnum` 在写入 ToC 的那一刻不可展开，且各层计数器共享
`\zhnumsetup` 的配置，于是「section 用一种中文数字样式、subsection 用另一种」这类混搭
无法实现。

## 提交改动

zhnumber 的 PR 请以 `zhnumber/maintaining` 为合入目标（而非 `master`）。

改动前后都要跑：

```sh
cd zhnumber
l3build check
```

一条命令覆盖三个引擎。`build.lua` 里 `checkengines = {"pdftex", "xetex", "luatex"}`、
`stdengine = "xetex"`，所以基线文件有两种名字：

- `<name>.tlg` —— `stdengine`（xetex）的基线，**luatex 也比对这一份**（该引擎没有专属
  基线，说明它当前输出与 xetex 一致；若某次改动让两者分化，需要新增 `<name>.luatex.tlg`）；
- `<name>.pdftex.tlg` —— pdfTeX 的基线。

现有三个用例：`basic01`（基本数字转换）、`style01`（`\zhnumsetup` 的各 style）、
`deprecation01`（已废弃接口的告警）。

**改 #1008 时要特别当心 `style01`。** 那个用例固定的正是「`\zhnumsetup` 的配置如何作用于
`\zhnum`」这一层语义，而 #1008 想改的恰好是配置的作用范围（从全局共享改为可按计数器区分）。
如果为了让新行为通过而放宽或删掉 `style01` 的断言，那不是刷基线而是关掉校验 —— 正确做法是
在新语义下重新生成基线，并**逐项**核对每条断言的变化是否都是预期的（`l3build check` 的
退出码只说明「与基线一致」，不说明「基线仍在守着原来那件事」）。

改完之后请确认既有的可展开性约定没有被破坏。这里要分清两件事，手册（`zhnumber.dtx`）对
它们的表述不同：

- 包的英文序言把「命令可正确展开」列为 zhnumber 相对 `CJKnumb` 的**主要优势**，所以不带
  选项的 `\zhnum{counter}` 本身是可展开的；
- 而带选项的形式（`\zhnum[options]{counter}`、`\zhdig[options]{counter}`）手册明确写着
  「这些带了选项的命令是不可展开的，在某些场合使用时要小心」。

#1008 的困境正落在这个交界上：用户要按层级切换样式，唯一的现成手段是带选项的形式或全局
`\zhnumsetup`，前者不可展开、后者所有层级共享。所以「让按层级切换的写法在 ToC 写入时正确
展开」如果通过改变这些命令的展开性来实现，那是一处**行为变更**而非纯修 bug，需要在
`\changes` 与 CHANGELOG 里如实说明，并确认不破坏序言承诺的那条优势。

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
