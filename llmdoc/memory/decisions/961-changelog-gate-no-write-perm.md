# 决策：#961 CHANGELOG.md 生成物新鲜度校验不给 CI write 权限（`check-changelog.yml`）

## 背景

PR #961（myhsia）给 `scripts/extract-changes.py` 加 `all` 版本参数，一次性
抽取 dtx 全部版本 `\changes` 生成 5 个包（ctex/xeCJK/zhlineskip/zhmetrics/
zhnumber）的 `CHANGELOG.md`。核心问题：如何保证这批生成的 `CHANGELOG.md`
不会在后续 PR 修改 `\changes` 后与源脱节。

## 被否决的两个方案

1. **CI 在打 tag 时生成 CHANGELOG.md 并直接 commit** —— 需要 write 权限。
   Liam 否决："CI 不宜给 write 权限"。
2. **退而提议 tag 前本地手跑生成再提交** —— 流程不闭环：`make tag` 只能在
   master 上打 git tag，不能顺带改文件；而生成 `CHANGELOG.md` 属于内容
   改动，必须走分支 + PR 走查评审，两个动作的时机对不上。

## 最终方案

CI 在**每个 PR**上重新跑生成脚本 + `git diff --exit-code`，只校验、不
回写，因此不需要 write 权限。与 #937 `check-tag.yml`（版本 stamp 校验）
**同一架构模式**——「CI 不宜给 write 权限」约束下的标准解法。落地为
`.github/workflows/check-changelog.yml`：

- 触发路径限定为相关 dtx / `**/CHANGELOG.md` / 脚本自身。
- 5 个包（`CHANGELOG_PKGS`：ctex/xeCJK/zhlineskip/zhmetrics/zhnumber）在
  单个 job 内依次重新生成 + `git add -N` + diff（生成是秒级操作，不需要
  按包拆 caller job）。
- fail 时通过三通道（job log `::group::` / step summary `<details>` /
  `actions/upload-artifact`）贴出期望的完整 `CHANGELOG.md` 内容，保证没有
  本地 Python 环境的 contributor 也能直接复制粘贴过闸。
- 本地入口 `make changelog` / `make changelog-<pkg>`。

配套修法：`scripts/extract-changes.py` 新增 `-o <file>` 参数，脚本自己以
UTF-8 + LF 写文件，不依赖 shell 重定向（Windows PowerShell 5 `>` 默认
UTF-16LE + CRLF，会让字节级 diff 门禁必然失败）。生成 `CHANGELOG.md`
必须用 `-o` 而非 shell 重定向。单版本模式（供 `release.yml` /
`release-ctan-upload.yml` 消费）输出字节保持与升级前完全一致，无回归。

## 已接受的缺憾

- **`zhmetrics` 版本链接死链**：该包目录里的 dtx 实际文件名是
  `zhmCJK.dtx`，脚本按 basename 的 `commonprefix` 推断包名前缀得到
  `zhmCJK`，但目录名/发布 tag 习惯是 `zhmetrics-*`；生成的版本超链接
  （如 `zhmCJK-v0.9d`）在仓库里没有对应 tag，是死链。属于历史命名不一致
  遗留问题，未来 zhmetrics 发新版时应留意 tag 前缀与生成链接是否对得上，
  不在本次修复范围。
- **并行 PR 的 CHANGELOG 冲突**：两个同时改同一个包 `\changes` 的 PR 会
  在 `CHANGELOG.md` 上产生 merge 冲突，接受为已知代价（生成物本质如此，
  与源码 merge 冲突同理，未做特殊处理）。

## 未参与范围

`CJKpunct`/`jiazhu`/`xCJK2uni`/`xpinyin` 4 个含 dtx 的包目前没有写任何
`\changes` 条目，不在 `CHANGELOG_PKGS` 范围内。补写 `\changes` 后可直接
把包名加入 `Makefile` 的 `CHANGELOG_PKGS` 与 `check-changelog.yml` 的包
列表，两处需手动保持同步。

## 未深入的分歧（留痕）

Liam 曾质疑"单纯罗列 `\changes` 是否是恰当的 CHANGELOG 形态"（vs AI 整理
成人类可读叙述文本），讨论未深入，最终接受了罗列形态。这是产品形态问题
而非工程问题，未来若重提可从这里接着讨论。

## 相关

- 反思：`llmdoc/memory/reflections/961-changelog-freshness-gate.md`
- 同构先例决策：[[937-version-single-source-l3build-tag]]
- 参考：`llmdoc/reference/build-and-test.md`「生成物新鲜度校验模式」小节、
  `llmdoc/guides/release-workflow.md`「`scripts/extract-changes.py` 参数
  语义」小节
- PR：#961（myhsia，生成脚本 `all` 模式 + CHANGELOG.md 初版），同分支
  追加 commit c2919872（Liam，`check-changelog.yml` + `-o` 参数 +
  Makefile + README）
