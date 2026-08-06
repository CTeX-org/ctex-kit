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

XeTeX 那条路线依赖 xeCJK 的若干内部函数，改动前请先看下一节。

## 依赖的 xeCJK 内部接口

XeTeX 路线（`\@@_adjust_xeCJK_hook:` 及其相关代码）不只是「加载 xeCJK」，还直接使用
xeCJK 的内部量。下面这份清单已逐项核对到 `xpinyin/xpinyin.dtx` 的行号（行号会随 dtx 改动漂移，
改动该文件后请重新核对，或按接口名检索）：

| 接口 | 用处 |
|---|---|
| `\makexeCJKinactive`（913 行） | 进入量宽盒子前关掉 interchar 机制，避免盒内的汉字再触发一遍字符类转换。 |
| `\xeCJK_select_font:` / `\xeCJK@setfont`（969-970 行） | 把量宽盒子切到 CJK 字体；后者是前者的兼容名，用 `\cs_if_exist_use:NF` 择一。 |
| `\l_xeCJK_current_font_tl`（895、900 行） | 拼音盒子缓存键的一部分，用来区分不同 CJK 字体下的排版结果。 |
| `\xeCJK@family`（907 行） | 上一项不存在时的退路，同样用于构造缓存键。 |
| `\CJKsymbol`（789、806、814 行） | 接管单个 CJK 字符的输出入口，是自动注音的挂载点。 |
| `\xeCJK_reset_fallback_font:`（959、961 行，#997 新增） | 判断当前是否处于后备字体状态，见下。 |

**`\xeCJK_reset_fallback_font:` 的判据语义。** 它同时是恢复动作和状态标记：未启用后备字体
时等于 `\prg_do_nothing:`；xeCJK 切换到后备字体后，它被重定义为「恢复该字体 + 清除标记」。
所以 `\cs_if_eq:NNTF \xeCJK_reset_fallback_font: \prg_do_nothing:` 就是「当前不在后备字体
状态」。xpinyin 用它决定量宽盒子要不要重选主 CJK 字体——已在后备字体里时当前字体正是该用
的那一个，重选反而会因为 `\xeCJK_select_font:` 内部先调 `\xeCJK_clear_fallback_font:` 而
退回主字体、量出缺字形的错误宽度（这就是 #997）。

这一项比 `\xeCJK_select_font:` 更容易在上游重构中改名：后者在 `xeCJK.dtx` 里有独立的
`[int]` 文档条目，前者只夹在 `\xeCJK_fallback_symbol:NN` 那块代码里，没有独立条目。机制细节
记在 `llmdoc/architecture/xecjk-architecture.md` 的「后备字体 (Fallback)」一节，那里也留了
「xeCJK 侧改动需通知下游」的说明。

**xeCJK 升级、或上表任一项改名时**，除了跑上一节那两条测试路线，还要核对
`testfiles/pinyin-fallback01.lvt` 是否仍有判别力。可用的检查是把 `\@@_reselect_CJK_font:`
的函数体换成无条件的 `\@@_select_CJK_font:`（即回退成原缺陷），确认基线变红。

注意三点，都是 #997 审查时实测澄清的：

1. 「把条件取反」**不是**一个独立的检查——取反后变红来自第 1、2 项回到原缺陷，与第 3 项无关；
   而且它并非「总是跳过」，实测产物与无条件重选逐字节相同（分支计数探针显示两支都仍走到）。
2. 「**整支重选被跳过**」这一侧没有用例能拦住（把函数体置空实测 5/5 全绿、产物与基线逐字节
   相同），属已接受的覆盖缺口。
3. 但第 3 项**不是**没有判别力：它是「重选切到**错误的 CJK 族**」这一形态的唯一防线——保持
   条件结构不动、只在 `\@@_select_CJK_font:` 开头插 `\CJKfamily{\CJKrmdefault}`，实测只有第 3
   项变红。**精简用例时不要因为第 2 点就删掉它**；它的对照字体必须与后备字体不同（现为
   `FandolKai`），否则这项判别力不存在。

接口一旦改名，`\cs_if_exist:NTF` 会走 F 分支、退化为无条件重选，这种情形能被第 1、2 项抓到。

## `\pinyin` 的 `v` 到 `ü` 只在 `l`、`n` 之后生效

`\@@_replace_v:n` 把输入里的 `v` 转成 `ü` 时，只在前一个字母是 `l` 或 `n`（含大写）时才转，
其余情况一律当作 `u`。这是 `\pinyin` 的既有设计：`ju`、`qu`、`xu` 没有歧义，不必写 `ü`。

因此**以 `v` 开头的片段排不出 `ü`**：`\pinyin{v3}` 得到 `ǔ` 而不是 `ǚ`，`\pinyin{ve4}`
得到 `uè` 而不是 `üè`（声调位置是对的，丢的是分音符）。

#550 的查询命令有两处受这条限制影响，都改为输出无调形式而不是静默给出错的字形：

- `scheme=official` 的韵母是音位形式，可能以 `v` 开头（`yue` 还原成 `ve`）；
- `scheme=literal` 下「女」的韵母本身就是 `v`。

改动 `\@@_replace_v:n` 或查询命令的标调路径时，请一并复核 `pinyin-query01.lvt` 第 4、5c 项。

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
