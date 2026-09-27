# 决策：v3.2 的 fixreadings 只固定五个轻声字（PR #1097）

## 背景

xpinyin 的拼音数据库在 unpack 时由 `xpinyin.lua` 从 Unihan 生成，`Unihan.zip` 不固定版本，打包时取最新版（见 `reference/build-and-test.md` 的 Unihan 缓存说明）。首选读音按 `kMandarin` > `kXHC1983` > `kHanyuPinyin` 的顺序取。

CTAN 上的 v3.1 用的是 Unicode 14.0（2021-08-06）的数据；v3.2 打包时是 18.0。对比两者生成的 `xpinyin-database.def`：新增 2943 个字，另有 309 个字的首选读音改变。原因是 Unihan 在 14.0 之后改写了 `kMandarin`：下表这几个字在 14.0 里取的是 `kHanyuPinlu` 中的高频读音（例如「子」取轻声 `zi`），新版改为单字的规范读音（「子」取 `zǐ`）。17.0 的数据已经是这样，不是 18.0 才变。

## 决定

- 只看常用字：《通用规范汉字表》一级字（Unihan 的 `kTGH` 序号 1–3500）及其繁体字形（`kTraditionalVariant`），其中有 32 个字的首选读音改变。
- 其中大多数是按现行规范读音所做的更正，例如「绩」`jī → jì`、「迹」`jī → jì`、「框」`kuāng → kuàng`、「驯」`xún → xùn`、「茸」`rōng → róng`。改回 v3.1 等于恢复过时读音，因此接受新数据。
- 例外是主要用作轻声助词或后缀、且 `kHanyuPinlu` 中轻声占多数的字，把它们加进 `xpinyin.lua` 的 `fixreadings` 表，保留 v3.1 的轻声读音：

| 字 | v3.1 | 新数据 | `kHanyuPinlu` |
|---|---|---|---|
| 子 | `zi` | `zǐ` | zi 6853 次，zǐ 1114 次 |
| 們 | `men` | `mén` | men 14950 次 |
| 啊 | `a` | `ā` | a 1102 次，ā 404 次 |
| 啦 | `la` | `lā` | la 967 次，lā 15 次 |
| 哇 | `wa` | `wā` | wa 76 次，wā 26 次 |

- 「甚」`shén → shèn`、「似」`shì → sì`、「著」`zhe → zhù` 虽然 `kHanyuPinlu` 里旧读音占多数，但新数据给的是规范读音，而旧读音来自「甚么」「似的」这类用法或繁体「著」兼作「着」，不属于上面的轻声助词，接受新数据。需要时由用户用 `\setpinyin` 设置。
- 数据变化与保留的读音写进 v3.2 的 `\changes`，手册 `\setpinyin` 一节也说明了这五个字的读音由宏包固定。

## 以后调整字表时

- 判据是「主要作轻声助词或后缀，且语料里轻声占多数」，不是「与 v3.1 不同」。按后者恢复会把规范更正一并撤销。
- `fixreadings` 覆盖的是 `Mandarin` 这一项，注音用的数据库和查询表都从同一份读音生成，两处同时生效；多音字列表来自 `XHC1983`／`HanyuPinyin`，不受影响。
- 回归测试 `pinyin-query01.lvt` 第 10 节只断言被固定的字，不拿表外的字作对照，否则测试会重新依赖 Unihan 版本（原因见 lessons-learned 里「上游数据变化让被测规则失去数据载体」一条）。
- 对比两版数据的方法：分别生成 `xpinyin-database.def`，按 `\XPYU{字}{码位}{读音}` 逐字比较；常用字范围取 `Unihan_OtherMappings.txt` 的 `kTGH` 与 `Unihan_Variants.txt` 的 `kTraditionalVariant`。

## 相关

- 同一 PR 还修了 `xpinyin.lua` 识别文件头版本行的问题：14.0 写作 `# Unicode version: 14.0.0`，17.0／18.0 写作 `# Unicode Version 18.0.0`，只认前者时生成的文件头一直显示默认值 `7.0.0`。
- [[xpinyin-maintaining-rebase-wording-unihan18]]
