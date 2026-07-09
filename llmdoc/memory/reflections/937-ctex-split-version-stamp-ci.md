# 反思：PR #937 ctex.dtx 拆分 + 版本 stamp 双闸 CI

## 任务脉络

PR #937（myhsia 主导）把 10600+ 行的单体 `ctex.dtx` 拆成 6 个文件；我方
（Liam0205 侧）在同一分支上补齐配套的版本管理 CI（check-tag.yml PR 门禁 +
release.yml 三方校验），并做了 `update_tag` 幂等化。本反思记录拆分结构、
版本机制设计与协作过程中的教训。

## 拆分结构（myhsia 的区域规划）

- `ctex.dtx` — `.ins`（`\generate` 段）、README、用户手册（driver 用
  `\DocInput{6 个 dtx}` 合并排版）
- `ctex-kernel.dtx` — 核心宏包/类/heading 的 `.def`（ctex/ctexsize/
  ctexheading/ctexart/ctexbook/ctexrep/ctexbeamer/c5size/cs4size/heading-*）
- `ctex-auxpkg.dtx` — 辅助（内部使用）与过时包残尾（ctexcap/ctexhook/
  ctexpatch）
- `ctex-engine.dtx` — 引擎配置文件
- `ctex-scheme.dtx` — `scheme = plain/chinese` 配置 + `name`
- `ctex-fontset.dtx` — 字库、`zhmap`、pTeX 下的 `.fd` 文件

`build.lua` 的 `sourcefiles` 列全 6 个 dtx；`unpackfiles` 只列主
`ctex.dtx`（`\generate` 通过 `\from{\jobname-kernel.dtx}{...}` 跨文件取
docstrip 段）。

## 版本机制：单一事实源 + 回写 stamp

拆分后版本号收敛到 **`ctex/build.lua:2` 的 `version` 字段**（唯一手改点），
沿 zhlineskip PR #892 首创的模式：

1. `version = "2.6.1"` 是发版事实源，`uploadconfig`（CTAN 投递）直接引用
2. 各 dtx 的版本行是 `\GetIdInfo $Id: <file> <ver> <date> <sha> <author>$`，
   由 `\ProvidesExplPackage{...}{\ExplFileDate}{\ExplFileVersion}{...}` 消费
   —— dtx 里**没有第二处硬编码版本**
3. `l3build tag`（本地手跑）通过 build.lua 重写的 `update_tag` 把 version
   + `git log -1` 的日期/短 sha/作者回写进 stamp 行

### 幂等化（我方修复，check-tag CI 的前提）

原版 `update_tag` 每次都取 `git log -1` 回写 → stamp commit 自身产生新
sha → 下次 tag 又想写新 sha → **永不收敛**。这对"CI 跑 `l3build tag` 后
diff 必须为零"的检查是致命的（永远 fire）。

修法：stamp 里的版本号已等于 `version` 时**原样保留**（不动 date/sha），
只有版本不一致（发新版 bump 了 version 还没 stamp）才回写。同时把"每文件
循环全部 sourcefiles"改为只处理 l3build 传入的当前 file（原实现是 O(n²)
重复 gsub）。

验证方法：连跑两遍 `l3build tag` 第二遍 diff 为零（幂等）；临时 bump
version 至 9.9.9 后 5 个 dtx stamp 全部回写（触发正确）。

## 双闸 CI

### 闸 1：check-tag.yml（PR 门禁）

对支持 l3build tag 的包（当前 zhlineskip / ctex），PR 上跑
`l3build tag` + `git diff --exit-code`。diff 非零 = 作者 bump 了 version
没跑 tag，fail 并提示本地补跑。

结构要点：
- 仿 check-doc.yml 的 paths filter + caller job + 汇总，但 tag 是秒级纯
  文本操作，**不需要 reusable workflow**，两个包各一个内联 job
- TL 最小安装：`packages: l3build latex-bin`（只要 texlua），不需要字体
  不需要引擎
- ctex job 要 `fetch-depth: 0`（update_tag 回写路径用 `git log -1`）

### 闸 2：release.yml 三方一致性校验

打 release tag 时验证 **strip_rc(git tag) == build.lua version == dtx
stamp**，不一致拒绝发版。

RC 语义（用户关键问题）：**RC 后缀只存在于 git tag**，build.lua 与 stamp
均写 base version。校验先 `sed -E 's/-(rc[0-9]+|pre[0-9]*|alpha[0-9]*|beta[0-9]*)$//'`
剥后缀再比对 —— 与 release.yml 既有 release-notes 提取逻辑同款正则，保持
心智一致。推论：**发 rc 前 build.lua 就必须已 bump 到目标版本并跑过
l3build tag**（rc 是"内容已定、公测验证"的 pre-release）。

非 l3build tag 机制的包（xeCJK 等 7 个）跳过校验打 notice —— 未来这些包
若迁移到同一机制，在 release.yml 校验 step 的 case 里加分支即可。

## 教训

### awk 字段数错：$3 vs $4

校验脚本首版用 `awk '{print $3}'` 取 stamp 版本，实际
`\GetIdInfo $Id: <file> <ver>` 里版本是 **$4**（$1=`\GetIdInfo`
$2=`$Id:` $3=file $4=ver）。本地模拟 5 场景（2.6.1 / 2.6.1-rc1 / 2.6.2 /
1.0g / 1.0h）全 FAIL 才暴露。**新校验脚本必须先本地模拟正反两组场景**，
只测 happy path 会漏掉这种字段错位。

### stamp 追 commit 的永动问题是设计雷区

任何"回写 git 元数据到源文件"的机制天然有自指问题：回写本身产生新
commit，新 commit 又使回写内容过期。**必须有收敛条件**（这里用"版本号
相等即跳过"），否则下游一切基于 diff 的校验都失效。zhlineskip 的
update_tag 天然幂等（version/date 都来自 build.lua 字段，不取 git 元
数据），ctex 的实现因为要 per-file 的 date/sha 才引入这个坑。

### 协作分支上的 stash pop 冲突

同分支上 myhsia 与我并行改 `ctex/build.lua`，`git stash pop` 在
`pull --rebase` 后遇到 UU 冲突。处理：`git reset <file>` +
`git checkout HEAD -- <file>` 恢复已提交版本，再重放自己的改动。多人
共享 feature 分支时 push 前 `pull --rebase` 应成为肌肉记忆（用户提醒了
这一点）。

### `make tag` 与 `l3build tag` 是两回事

- `make tag ctex-v2.6.1-rc1` = 打 **git tag**（触发 release.yml）
- `cd ctex && l3build tag` = 回写 **dtx 源文件的 $Id:$ stamp 行**

发版顺序：改 build.lua version → `l3build tag`（stamp）→ commit → PR
merge → `make tag`（git tag）→ push tag 触发 release。此前仓库无任何
workflow 跑 `l3build tag`，纯靠维护者自觉 —— 双闸 CI 补的就是这个洞。

## 促进候选

- ✅ 已促进：`reference/build-and-test.md` 版本管理章节重写（拆分后 SOP
  + 双闸机制）
- 决策文档：[[937-version-single-source-l3build-tag]]
- ✅ 已促进：PR #937 merge 后，`architecture/ctex-architecture.md` 的
  「源码组织」章节已重写为 6 文件源布局（源文件表 + build.lua
  sourcefiles/unpackfiles 跨文件 docstrip 说明）

## 相关

- 决策：[[937-version-single-source-l3build-tag]]
- Stable：`llmdoc/reference/build-and-test.md` 版本管理章节
- PR：#937（拆分 + CI），PR #892（zhlineskip 首创该模式）
