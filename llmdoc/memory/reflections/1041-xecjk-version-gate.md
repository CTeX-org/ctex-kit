# 反思：给 xeCJK 接入 l3build tag 与三方版本校验（#1041）

## 起因是一次已经发出去的错版

打 `xeCJK-v3.10.5-rc2` 并 push 后，`release.yml` 跑成功、prerelease 正常挂出。但那个包自报的版本是 **v3.10.4**：`xeCJK.dtx:216` 的 `{\ExplFileDate}{3.10.4}` 从来没随 v3.10.5 bump 过。

两道本该拦住它的闸门都没拦：

- `check-tag.yml` 的 `paths` 只有 `zhlineskip/**` 与 `ctex/**`，xeCJK 的 PR 根本不触发它；
- `release.yml` 的三方一致性校验里，`case "${DIR}"` 只写了 `ctex)` 和 `zhlineskip)`，xeCJK 落进 `*)`，日志明确打 `##[notice]xeCJK 不使用 l3build tag 版本 stamp 机制, 跳过三方校验`。

也就是说：**这不是门禁失效，是 xeCJK 从来不在门禁覆盖范围内。** 我在推 tag 前恰好查到了这个不一致（对比 `\ExplFileDate` 与 CHANGELOG 头部），但当时 tag 已经打好、用户直接 push 了，包就那样发了出去。

## 最该记的一条：按包 opt-in 的门禁，默认是「放行」

`check-tag.yml` 用 `paths` 列包，`release.yml` 用 `case` 列包。两处都是**白名单**，没被列进去的包静默走过。`release.yml` 甚至贴心地打了一条 `::notice::...跳过三方校验`——notice 不是 failure，CI 全绿，没人会去读。

这类设计的失效方式很隐蔽：加新包、或某个包后来才具备被校验的条件时，没有任何机制提醒「这个包还没接进来」。#935 的 zhspacing 是**有意识地**排除并留了 followup issue；xeCJK 这次是**无意识地**从未接入，而它是仓库里最活跃的包。

**教训：白名单式门禁应当有一条「未覆盖清单」的对账机制**，而不是靠人记得。最省事的形式是让门禁自己枚举「应被覆盖但未覆盖」的包并打 warning，或至少在文档里维护一份显式的覆盖矩阵（本次已在 `build-and-test.md` 补上）。我这次只做了「把 xeCJK 加进去」，没做对账机制——那属于更大的改动，留作可选后续，但这条教训要先记下来。

## `version` 在 l3build 里是个函数，不是 nil

共享 `update_tag` 我原本写成：

```lua
local target = version or tagname
```

意图是「`build.lua` 设了 `version` 就用它，否则用 CLI 参数」。结果其余六个未设 `version` 的包一跑就报 `attempt to index a function value (local 'target')`。

原因：**l3build 自己在全局定义了 `function version()`**（`l3build-help.lua:32`，供 `--version` 用）。未设 `version` 的包里这个名字不是 `nil`，而是那个内建函数，`or` 短路直接把函数当值取走了。改成判类型才对：

```lua
local target = (type(version) == "string") and version or tagname
```

教训：**在 l3build 的 `build.lua` 语境里写全局名判空，要先确认那个名字没被 l3build 自己占用。** 更一般地说，`x or fallback` 只在 `x` 只可能是「想要的值」或 `nil`/`false` 时成立；当 `x` 可能是别的类型（尤其是被框架预先定义的函数），必须判类型。这与仓库里已有的一条教训同构——`ctex_kit_env_or_nil` 就是因为 GH Actions 空 input 注入 `""` 而不得不把空串也当未设置。

## `\ExplFileDate` 装的不是日期

`xeCJK.dtx` 那行是：

```
\ProvidesExplPackage{\ExplFileName}
  {\ExplFileDate}{3.10.5}{\ExplFileDescription}
```

`\ProvidesExplPackage` 的参数顺序是 `{name}{date}{version}{description}`。所以 `\ExplFileDate` 是**日期占位宏**（由 `\GetIdInfo$Id: ...$` 从 git stamp 取到 commit 日期），紧跟其后大括号里的 `3.10.5` 才是**版本号**。

我一开始按名字去理解，差点让 `update_tag` 同时改日期。实际上日期不该在这里写死：它随 `replace_git_id` 打包时填入的 commit 日期自动跟进，硬写反而会让每次 `l3build tag` 都产生 diff，把 PR 门禁变成恒失败。

教训：**改回写逻辑前先确认被回写的那个位置到底是什么语义，尤其当宏名与内容不符时。** 判据是去读消费方的参数顺序（这里是 `\ProvidesExplPackage`），而不是读宏名。

## PR 门禁的 diff 范围踩了一次

`tag-xecjk` job 我最初写成：

```sh
git diff --exit-code -- . ../support
```

想法是「`update_tag` 在 `support/build-config.lua` 里，那也一起看」。这是错的：`l3build tag` 的**回写目标**只有本包目录的 `.dtx`；把 `../support` 纳入 diff，会让任何修改 `support/build-config.lua` 的 PR 都被误判成「stamp 不同步」——那份改动本身就是 diff。

我是在本地跑验证时发现的：干净状态下门禁本该 pass，却报 diff 非零，一看是我自己未提交的 `support/` 改动被算进去了。

教训：**「重新生成 + git diff」型门禁，diff 范围必须精确等于生成动作的写入范围**，不能顺手扩大到「相关文件」。扩大范围不会增加检出能力，只会把无关改动误判为不同步。验证方式也要跟上：我最后是用干净 worktree（`git worktree add`）模拟 CI 环境重跑，才确认是 no-op——在有未提交改动的主工作区验证这类门禁，结论不可信。

## 复现事故本身作为验证手段

我没有只验证「加了门禁之后正常状态能过」，而是**把 rc2 那次事故复现了一遍**：把 `\ExplFileDate` 改回 `3.10.4`，然后

- 跑 PR 门禁的等价命令 → `l3build tag` 真回写 → diff 非零 → 拒绝；
- 跑 release 三方校验的等价 shell → 报 `✗ tag=3.10.5 但 stamp=3.10.4` → 拒绝。

外加两个变体：打错 tag（`3.10.6`）应拒绝、rc 后缀（`3.10.5-rc3`）应剥离后通过。

这比只验证 happy path 有用得多——门禁的价值完全取决于它对**那个具体事故**是否有判别力。这与 xeCJK 测试里「变异验证」是同一条原则：新增门禁必须实测它在缺陷重现时会失败。

## Promotion Candidates

- **白名单式门禁默认放行**：按包 opt-in 的 CI 门禁（`paths` filter / `case` 分支）对未列出的包静默跳过，`::notice::` 不会引起注意；需要覆盖矩阵或自动对账。
- **l3build 的 `build.lua` 里 `version` 等全局名可能已被框架占用**（`function version()`），判空要判类型。
- **`\ExplFileDate` 是日期占位宏，其后大括号里才是版本号**；按 `\ProvidesExplPackage{name}{date}{version}{desc}` 的参数顺序读，别按宏名读。
- **「重新生成 + diff」门禁的 diff 范围必须精确等于生成动作的写入范围**；且要在干净 worktree 里验证 no-op。
- **新增门禁要用「复现原事故」验证判别力**，不能只跑 happy path。

## 相关

- Issue/PR：#1041；触发事故的 tag：`xeCJK-v3.10.5-rc2`（已发出，包自报 v3.10.4）。
- 实现：`xeCJK/build.lua`（新增 `version`）、`support/build-config.lua`（共享 `update_tag`）、`.github/workflows/check-tag.yml`（`tag-xecjk` job）、`.github/workflows/release.yml`（`xeCJK)` case）。
- 相关决策：[[../decisions/1041-xecjk-version-gate]]、[[../decisions/937-version-single-source-l3build-tag]]、[[../decisions/961-changelog-gate-no-write-perm]]。
