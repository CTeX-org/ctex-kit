# 决策：xeCJK 接入 l3build tag 与三方版本校验（#1041）

## 背景：一次已发出的错版

`xeCJK-v3.10.5-rc2` 打 tag 并 push 后 `release.yml` 跑成功、prerelease 正常挂出，但包自报版本是 **v3.10.4**——`xeCJK.dtx` 的 `{\ExplFileDate}{3.10.4}` 从未随 v3.10.5 bump。

两道闸门都没拦，因为 **xeCJK 从来不在覆盖范围内**：

| 闸门 | 覆盖方式 | xeCJK 的情况 |
|---|---|---|
| `check-tag.yml`（PR 门禁） | `paths` 白名单 | 只列 `zhlineskip/**`、`ctex/**`，xeCJK 的 PR 不触发 |
| `release.yml` 三方校验 | `case "${DIR}"` 白名单 | 落进 `*)`，打 `::notice::xeCJK 不使用 l3build tag 版本 stamp 机制, 跳过三方校验` |

`::notice::` 不是 failure，CI 全绿。

## 决策

把 xeCJK 接入同一套双闸，但**沿用它自己的版本写法**，不改成 ctex/zhlineskip 的 `$Id:$` stamp 形态。

### 1. `xeCJK/build.lua` 新增 `version` 作为事实源

```lua
version = "3.10.5"
```

与 #937 对 ctex/zhlineskip 的约定一致：`build.lua` 顶部 `version` 是唯一手改处。

### 2. 共享 `update_tag` 以 `version` 优先，并加幂等守卫

xeCJK 用 `support/build-config.lua` 的**共享** `update_tag`（与 CJKpunct / jiazhu / xCJK2uni / xpinyin / zhmetrics / zhnumber 共用），不像 ctex/zhlineskip 那样在包级覆写。因此改动落在共享函数里，必须对另外六个包无副作用：

```lua
local target = (type(version) == "string") and version or tagname
if type(target) ~= "string" then return content end
...
local stamped = content:match("{\\ExplFileDate}{([^}]*)}")
if stamped == target then return content end   -- 幂等
```

三点设计：

- **`version` 优先、CLI `tagname` 兜底**：设了 `version` 的包（目前只有 xeCJK）可以无参跑 `l3build tag`，这是 PR 门禁「跑 tag 后 diff 必须为零」得以成立的前提；未设的六包保持原有 `l3build tag <ver>` 行为。
- **必须判类型**：l3build 自己定义了全局 `function version()`（`l3build-help.lua:32`），未设 `version` 的包里这个名字是**函数**不是 `nil`。原来的 `version or tagname` 会取到那个函数并报 `attempt to index a function value`。顺带修掉了这六个包裸跑 `l3build tag` 时既有的 `attempt to concatenate a nil value`（`tagname` 为 nil）。
- **幂等**：版本已一致时原样返回。没有这个守卫，`l3build tag` 后的 diff 永不为零，`check-tag.yml` 会恒失败（同 #937 的收敛条件）。

### 3. 只改版本号，不碰日期

`\ProvidesExplPackage` 的参数顺序是 `{name}{date}{version}{description}`，所以：

```
%<!driver>  {\ExplFileDate}{3.10.5}{\ExplFileDescription}
```

里的 `\ExplFileDate` 是**日期占位宏**（由 `\GetIdInfo$Id: ...$` 从 git stamp 取 commit 日期），大括号里的 `3.10.5` 才是版本号。日期由 `replace_git_id` 打包时填入、自动跟进 commit，不在 `update_tag` 里写死——硬写会让每次 tag 都产生 diff。

### 4. `check-tag.yml` 增加 `tag-xecjk` job

- `paths` 与 `changes` filter 增加 `xeCJK/**` 与 `support/build-config.lua`（后者是共享 `update_tag` 所在，改它必须重跑三个包的门禁）。
- **不需要 `fetch-depth: 0`**：共享 `update_tag` 只改 `{\ExplFileDate}{...}`，不读 `git log`（ctex 的覆写版本才需要）。
- **diff 范围只限 `.`**：写成 `git diff --exit-code -- . ../support` 是错的——`l3build tag` 的回写目标只有本包 `.dtx`，把 `../support` 纳入会让任何改 `support/build-config.lua` 的 PR 被误判成 stamp 不同步。
- 汇总 job `check-tag-result` 的 `needs` 与循环列表同步加 xeCJK。

### 5. `release.yml` 增加 `xeCJK)` case

```sh
LUA_VER=$(sed -nE 's/^version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "${DIR}/build.lua" | head -1)
STAMP_VERS=$(grep -hoE '\{\\ExplFileDate\}\{[0-9]+\.[0-9]+\.[0-9a-z]+\}' "${DIR}/xeCJK.dtx" \
             | grep -oE '[0-9]+\.[0-9]+\.[0-9a-z]+' | sort -u)
```

case 标签用 `xeCJK`（大写 CJK）以匹配 `parse tag` 输出的 `dir=xeCJK`。RC 后缀剥离沿用既有的 `BASE_VER` 逻辑。

### 幂等守卫的观察范围必须覆盖全部写入范围

本函数写两处：`{\ExplFileDate}{<ver>}` 与旧式 `[YYYY/MM/DD v<ver>]`。守卫最初只看前者就提前 `return`，于是当一个 `.dtx` 两种写法并存、且只有后者失同步时，该行**再也不会被修复**——而改造前的旧代码会修。`xpinyin.dtx` 正是这种文件（`{\ExplFileDate}{3.1}` 与 `[2022/07/14 v3.1 xpinyin database]`），且它不在任何版本门禁内，失同步无人发现。

改为「先算出两处的目标形态，再与现状整体比较」。

**放弃自动修复陈旧日期，是有意取舍而非遗漏。** `[<日期> v<版本>]` 行现在只在版本号需要改时才连日期一起重写；版本号已对则整段原样保留，包括陈旧的日期。两侧都实测过（`zhmetrics/zhmCJK.dtx` 是唯一能单独触发该格的文件——有 `[...]` 行却没有 `{\ExplFileDate}`）：

| 状态 | 改造前旧代码 | 现在 |
|---|---|---|
| 版本陈旧 | 修复 | 修复 |
| 版本对、日期陈旧 | 修复（刷成今天） | **不修复** |
| 已同步 | **把日期刷成今天** → 每次 tag 都产生 diff | no-op |

第三行是取舍的理由：保留旧行为的话，一旦 `zhmetrics` 接入 PR 门禁，「tag 后 diff 必须为零」将永远无法满足。版本号是发版事实源、日期只是附带信息，因此优先保证幂等；需要更新日期时手改，或改 `version` 触发整段重写。

### 不需要自己再比较一次内容

函数末尾曾写 `if new_content == content then return content end`。那是**无可观察效果的死代码**：l3build 的 `update_file_tag` 自己按值比较（`l3build-tagging.lua:52` 字面为 `if content == updated_content then`），内容相同时根本不落盘。已删除，并订正原注释里「它是门禁的前提」这一错误说法。

### `[...]` 行的版本号模式不能用 `%S+`

`%S+` 会把紧跟版本号的 `]` 一起吃掉：`[2022/07/14 v3.1]` 回写后丢失右括号；更糟的是版本号已相同时捕获到的是 `"3.1]"`，`v == target` 守卫失效而落进重写分支，**同时破坏内容与幂等性**。改用 `[^%]%s]+`。

现网两处 `[...]` 行的版本号后都跟着描述文字（`xpinyin database` / `setup CJK fonts dynamically`），碰不到这个坑；但本次把该模式从「替换的一部分」提升成了「幂等守卫的判据」，语义责任更重，故一并收紧。

### CLI 参数被忽略时要显式告警

设了 `version` 的包里 CLI 的 `tagname` 会被忽略。原实现静默丢弃，`l3build tag 3.10.6` 退出码 0、打印 `Tagging`、什么也不做。现在会打印一行提示，指明 `build.lua` 的 `version` 才是事实源。实测：冲突时告警，无参/同版本/未设 `version` 的包传参时均不告警。

两个细节：路径取**当前目录名**而非 `module`（xeCJK 的 `module` 是小写 `xecjk`，目录却是 `xeCJK/`，用 `module` 会打印出不存在的 `xecjk/build.lua`）——取目录名用 `lfs.currentdir()` 而非 `os.getenv("PWD")`，后者是可被污染的环境变量（实测 `PWD=/somewhere/else l3build tag 3.10.6` 会打印 `else/build.lua`，恰恰又是个不存在的路径），且 Windows 上本就没有 `PWD`；`lfs` 在 texlua 下是预置全局表，l3build 自身也用（`l3build-file-functions.lua:32`）。另外**只告警不中止**——`update_tag` 没有向 l3build 报错的通道（返回值是新内容而非 errorlevel），`error()` 会让命令以 Lua 栈回溯收场、更难读。因此这条消息是便利提示，版本一致性仍由两道 CI 闸把关，不依赖它被看见。

## 验证：复现原事故

不只验证 happy path，而是把 rc2 那次事故复现一遍：

| 场景 | PR 门禁 | release 三方校验 |
|---|---|---|
| 当前状态（三方均 3.10.5） | `l3build tag` no-op、diff 为零 → pass | `✓ 三方一致: 3.10.5` |
| **复现事故**：dtx 回到 3.10.4 | `l3build tag` 真回写 → diff 非零 → **拒绝** | `✗ tag=3.10.5 但 stamp=3.10.4` → **拒绝** |
| 打错 tag（3.10.6） | — | `✗ tag=3.10.6 但 build.lua=3.10.5` → **拒绝** |
| rc 后缀（3.10.5-rc3） | — | `✓ 三方一致: 3.10.5`（后缀已剥离） |

九个包逐个实测 `l3build tag`：xeCJK 回写后幂等，其余八包零报错、零改动（此前六包裸跑会抛 `attempt to concatenate a nil value`）。

PR 门禁的 no-op 验证在**干净 worktree**（`git worktree add`）里做——主工作区有未提交改动时 `git diff` 会把它们算进来，结论不可信。

包自报版本实测由 `v3.10.4` 变为 `v3.10.5`（编译一份文档读 `\ver@xeCJK.sty`）。

## 未做的部分

**白名单未覆盖的对账机制没做。** 两处门禁都是白名单，新包或后来才具备条件的包会静默跳过，没有任何提醒——xeCJK 这次就是如此。本次只把 xeCJK 加进去，并在 `build-and-test.md` 补了一份显式覆盖矩阵；自动对账（让门禁枚举「应覆盖未覆盖」的包并 warning）属更大改动，留作后续。

与 #935 的 zhspacing 不同：那是**有意识**排除并留了 followup issue，本次是**无意识**从未接入。

## 相关

- 反思：[[../reflections/1041-xecjk-version-gate]]
- 前身：[[937-version-single-source-l3build-tag]]（双闸 CI 与幂等守卫的由来）、[[961-changelog-gate-no-write-perm]]（同款「重新生成 + diff」模式）
- 实现：`xeCJK/build.lua`、`support/build-config.lua`、`.github/workflows/check-tag.yml`、`.github/workflows/release.yml`
