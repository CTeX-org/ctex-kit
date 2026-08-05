# xpinyin 的维护状态

xpinyin 原由 @qinglee 维护。社区自 2022 年起与其断联约四年，与 CTAN 管理员沟通后的安排是：
若 2026 年 9 月底前仍未收到回复，则考虑启动维护者变更流程。详见 #1041。

在维护权归属明确之前，xpinyin 的改动集中在 `xpinyin/maintaining` 分支上集成，而不是逐个
直接并入 `master`。这样做是为了随时能看清「若接手维护，累积的改动是什么」，也便于在一处
验证各改动之间的相互影响。

## 提交改动

xpinyin 的 PR 请以 `xpinyin/maintaining` 为合入目标（而非 `master`）。

改动前后都要跑两条测试路线：

```sh
cd xpinyin
l3build check                      # 主套件：XeTeX + xeCJK
l3build check -c test/config-cjk   # CJKutf8 + pdfTeX
```

两条都必须跑。xpinyin 内部是 `\@@_adjust_xeCJK_hook:` 与 `\@@_adjust_CJK_hook:` 两套
互不复用的适配，字体选择、码位转换和接管 `\CJKsymbol` 的方式都不同，只跑一条会让另一半
完全没有覆盖。luatex 被 `\msg_critical:nn` 明确拒绝，不在支持范围内。

测试的设计依据、判别力教训和已接受的覆盖缺口记在
`llmdoc/reference/build-and-test.md` 的「xpinyin 的注音回归（#1041）」一节。

## 版本与发布

`xpinyin/build.lua` 的 `version` 是发版事实源，须与 `xpinyin.dtx` 的两处版本号保持一致：

- `\ProvidesExplPackage` 里紧跟在 `{\ExplFileDate}` **之后**的那个参数（当前是 `{3.1}`）。
  注意 `\ExplFileDate` 本身是**日期**槽位，不要改它——`\ProvidesExplPackage` 的参数顺序是
  文件名、日期、版本、说明。
- `xpinyin-database.def` 的 `\ProvidesFile` 方括号里 `v` 后面的版本号
  （当前是 `[2022/07/14 v3.1 xpinyin database]`）。

回写由 `l3build tag` 完成，实现是 `support/build-config.lua` 里共享的 `update_tag`：一条
`({\ExplFileDate})%b{}` 替换负责上面第一处（`%b{}` 匹配紧随其后的花括号组），另一条
`[<日期> v<版本>]` 分支负责第二处。`check-tag.yml` 会要求跑完后 `git diff` 为空。

面向用户的变更写进 `xpinyin.dtx` 的 `\changes`，`CHANGELOG.md` 由 `make changelog-xpinyin`
生成，不要手写。
