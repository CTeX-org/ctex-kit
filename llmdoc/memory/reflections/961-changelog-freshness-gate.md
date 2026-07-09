# 反思：PR #961 CHANGELOG.md 生成物新鲜度校验（check-changelog.yml）

## 任务脉络

PR #961（myhsia 主导）给 `scripts/extract-changes.py` 加 `all` 版本参数，
支持一次性抽取 dtx 全部版本的 `\changes` 并按语义化版本分组，同时提交了
5 个包（ctex/xeCJK/zhlineskip/zhmetrics/zhnumber）手工生成的
`CHANGELOG.md`。我方（Liam 侧）在同一分支追加 CI 门禁，确保这批
CHANGELOG.md 不会在后续 PR 中与 `\changes` 脱节。本反思记录流程分歧的
收敛过程、新增的跨平台坑，以及与 #937 版本 stamp CI 复用的架构模式。

## 流程分歧与收敛

myhsia 先后提出两个方案，都被拒绝：

1. **CI 在打 tag 时生成 CHANGELOG.md 并直接 commit** —— 需要 write 权限，
   Liam 直接否决："CI 不宜给 write 权限"。
2. **退而提议 tag 前本地手跑** —— Liam 指出流程不闭环：tag 只能在
   master 打，但改动内容（生成 CHANGELOG.md）必须走分支 + PR，两者对不
   上（`make tag` 是打 git tag 不能顺带改文件，见 #937 反思）。

最终方案（Liam 拍板，与 #937 `check-tag.yml` **同一架构模式**）：CI 在
每个 PR 上重新跑生成脚本 + `git diff --exit-code`，只校验、不回写，因此
不需要 write 权限。这是「CI 不宜给 write 权限」约束下的标准解法，值得
在遇到"生成物需要保持与源同步"的新场景时首先想到复用，而不是重新讨论
写权限方案。

关键差异（vs #937 check-tag.yml）：
- #937 只在 tag 相关的两个包（zhlineskip/ctex）跑，本次覆盖全部 5 个有
  CHANGELOG.md 的包，且**每个 PR** 都跑（而非只在打 tag 时）——触发范围
  用 `paths` filter 限定到相关 dtx / CHANGELOG.md / 脚本自身，五个包合
  一个 job 串行（生成是秒级操作，不需要 caller-per-pkg 拆分，这点也与
  #937 check-tag.yml 一致）。
- #937 校验对象是 dtx 里的 `$Id:$` stamp 行（单行文本），本次校验对象是
  整份 Markdown 文件——因此在"如何让 fail 时的期望内容对 contributor 可
  操作"上要求更高（见下）。

## 新增教训：跨平台字节一致性必须由脚本自己保证

`git diff --exit-code` 校验的前提是"同一输入产出字节完全一致的输出"。
第一版实现依赖 shell 重定向 `python3 extract-changes.py ... > CHANGELOG.md`
生成，这在 Linux/macOS CI 上没问题，但 Windows PowerShell 5 的 `>` 默认
用 **UTF-16LE + CRLF** 编码/换行写文件，与 Linux 上生成的 UTF-8 + LF 字
节不同，会让本地在 Windows 上手跑生成、CI 在 Linux 上校验的场景必然
diff 非零——即使内容语义完全相同。

修法：脚本新增 `-o <file>` 参数，脚本自己用 `encoding="utf-8"` +
`newline="\n"` 显式写文件，不依赖 shell 重定向的默认行为。**任何"字节
级 diff 做门禁"的生成物，只要还可能被 contributor 在 Windows 上手跑，
就不能依赖 shell 重定向，必须让生成脚本自己控制 encoding/newline。**
这是本仓库第一次在 CI 门禁设计中显式踩到这个坑（#937 check-tag.yml 的
`l3build tag` 走的是 Lua io 库不存在这个问题，没有暴露过）。

## 回归验证方法：旧版脚本输出当字节级 oracle

改造 `extract-changes.py` 的输出逻辑（从"边算边打印"收敛为"先攒内存再
统一输出"）时，最大风险是意外改变了单版本模式的输出——这个模式被
`release.yml` / `release-ctan-upload.yml` 复用，任何字节级变化都是隐藏
回归。验证方法：`git show master:scripts/extract-changes.py` 取旧版脚本
输出当 oracle，与新版单版本模式输出做 diff。第一版实现在 `all` 模式末
尾多了一个空行，就是靠这个 diff 抓到的（并非在单版本模式本身出错，而是
在收敛输出逻辑时顺带影响了共用的写出路径）。

这与既有反思 `feedback_use_latex_output_as_oracle`（.lvt/.tlg 用 LaTeX
自己输出当 oracle）是同一方法论在不同场景的复用：**改造一个有下游消费
者的共享脚本/宏时，用改造前的版本输出做 oracle 回归，比读代码推理更
可靠。**

## 门禁 fail 时的可操作性设计

`check-tag.yml` 校验的是单行 stamp，fail 提示"本地跑 `l3build tag`"即
可。CHANGELOG.md 是整份文件，fail 时必须让**没有 Python 环境的
contributor** 也能过闸——因此把期望内容通过三个通道暴露：`::group::`
折叠的 job log、`$GITHUB_STEP_SUMMARY` 的 `<details>` 折叠块、
`actions/upload-artifact`。三选一，contributor 复制粘贴覆盖本地文件即
可提交，不强制要求本地装 Python。**校验对象越"大"（整文件 vs 单行），
越需要在 fail 分支上做"直接可复制的期望产物"设计，而不只是提示命令。**

## 未深入的分歧（留痕，非本次解决）

Liam 曾质疑"单纯罗列 `\changes` 是否是恰当的 CHANGELOG 形态"（vs AI 整
理成人类可读叙述文本），讨论未深入，最终接受了罗列形态。这是一个产品
形态问题而非工程问题，未来如果有人重提"CHANGELOG 该不该经 AI 转写"，
可以从这里接着讨论，不必视为新问题。

## 已知接受的缺憾（非本次修复范围）

- **未发布版本的死链**：`zhmetrics` 目录里的 dtx 实际是 `zhmCJK.dtx`，
  脚本按文件名推断包名前缀得到 `zhmCJK`，但目录名/发布 tag 习惯是
  `zhmetrics-*`；生成的版本超链接（如 `zhmCJK-v0.9d`）在仓库里根本不存
  在对应 tag，是死链。属于历史命名不一致遗留问题，未来若给 zhmetrics
  发新版应留意 tag 前缀与生成链接是否对得上。
- **并行 PR 的 CHANGELOG 冲突**：两个同时改同一个包 `\changes` 的 PR 会
  在 CHANGELOG.md 上产生 merge 冲突，接受为已知代价（生成物本质如此，
  与源码 merge 冲突同理，未做特殊处理）。

## 顺带发现（未处理，留给后续）

4 个含 dtx 的包（CJKpunct/jiazhu/xCJK2uni/xpinyin）目前没有写任何
`\changes` 条目，因此不在 `CHANGELOG_PKGS` 范围内；补写 `\changes` 后可
直接加入 `Makefile` 的 `CHANGELOG_PKGS` 与 workflow 的包列表，两处需保
持同步（当前 workflow 注释里显式写了"与 Makefile 的 CHANGELOG_PKGS 保
持一致"作为提示）。

## 促进候选

- **「生成物新鲜度校验」应作为通用架构模式提炼**：#937（版本 stamp）与
  #961（CHANGELOG.md）是同一模式两个独立实例，`reference/build-and-test.md`
  的 CI/CD 章节目前分别记录，尚未有一处统一说明"CI 不宜给 write 权限时,
  生成物同步用「重新生成 + diff 校验」门禁"这一仓库级约定。下次再出现
  第三个实例时，应把这条模式抽到独立小节或 `guides/` 下，而不是继续在
  各自 workflow 段落重复解释。
- **跨平台字节一致性约束**：可以补一条到 `reference/coding-conventions.md`
  或 `build-and-test.md`——"任何进 git 且被字节级 diff 校验的生成物,
  必须由生成脚本自己控制 encoding/newline, 不能依赖 shell 重定向"。目前
  只在本反思和 commit message 里，尚未进入 stable 文档。
- llmdoc 的 `reference/build-and-test.md` CI/CD 一节需要在下次
  `/update-doc` 时补入 `check-changelog.yml` 的条目（参照
  `check-tag.yml` / `check-doc.yml` 的现有写法）。

## 相关

- 反思（同构先例）：[[937-ctex-split-version-stamp-ci]]
- 决策（同构先例）：[[937-version-single-source-l3build-tag]]
- 既有反馈：`feedback_use_latex_output_as_oracle.md`
- PR：#961（生成脚本 + CHANGELOG.md 初版），本 session 追加 commit
  c2919872（check-changelog.yml + `-o` 参数 + Makefile + README）
