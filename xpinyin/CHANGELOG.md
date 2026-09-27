## [xpinyin-v3.2](https://github.com/CTeX-org/ctex-kit/releases/tag/xpinyin-v3.2)

- 为 `\disablepinyin` 增加带星号的形式，使禁用范围也覆盖 `\xpinyin` 命令本身。（#265）
- 新增查询汉字读音的四个命令 `\xpinyinvalue`、`\xpinyininitial`、`\xpinyinshengmu` 与 `\xpinyinyunmu`，可用于中文索引的分组与排序；数据表由 `query` 选项按需载入。（#550）
- 补齐独立回归测试，并接入按 tag 构建发布包所需的版本一致性校验。宏包代码本身没有变化。
- 在 `xeCJK` 的 `AutoFallBack` 已切换到后备字体时，测量宽度用的盒子不再重新选择主字体，修复注音被压缩到错误宽度的问题（#997）。
- 拼音参数现在可以直接写 `ü`／`Ü`，与原有的 `v`／`V` 写法等价。此前 XeTeX 下 `\pinyin{nü3}` 排出字面的 `nü3`，pdfTeX 加 `CJKutf8` 下则直接报错。（#1069）
- `\setpinyin` 现在也能为数据库未收录的汉字补充查询表读音；此前只更新注音表，`\xpinyinvalue` 仍报「无读音」。（PR #1051）
- `\setpinyin` 存进查询表时去掉表示轻声的末尾 `5`，与查询表「轻声不写数字」的约定一致；此前 `none` 形式会返回 `shi5` 而不是 `shi`。（PR #1051）
- 拼音数据改用 Unicode 18.0 的 `Unihan`（v3.1 使用的是 14.0），新增近 3000 个汉字的读音；约 300 个汉字的首选读音随之改变，多为按现行规范读音更正，例如“绩”由 `jī` 改为 `jì`。“子”“們”“啊”“啦”“哇”保留原来的轻声读音。需要其他读音时可用 `\setpinyin` 设置。
