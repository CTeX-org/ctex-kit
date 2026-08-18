## [xpinyin-v3.2](https://github.com/CTeX-org/ctex-kit/releases/tag/xpinyin-v3.2)

- 为 `\disablepinyin` 增加 star 版本：用于将其作用域覆盖到 `\xpinyin` 自身。（#265）
- 新增查询汉字读音的四个命令 `\xpinyinvalue`、`\xpinyininitial`、`\xpinyinshengmu` 与 `\xpinyinyunmu`，可用于中文索引的分组与排序；数据表由 `query` 选项按需载入。（#550）
- 补齐独立回归测试，并接入按 tag 构建发布包所需的版本一致性校验。宏包代码本身没有变化。
- 在 `xeCJK` 的 `AutoFallBack` 已切换到后备字体时，量宽盒子不再重选主字体，修复注音被压缩到错误宽度的问题（#997）。
- 拼音参数现在可以直接写 `ü`／`Ü`，与既有的 `v`／`V` 写法等价。此前 XeTeX 下 `\pinyin{nü3}` 排出字面的 `nü3`， pdfTeX 加 `CJKutf8` 下则直接报错。（#1069）
- `\setpinyin` 现在也能为数据库未收录的汉字补充查询表读音；此前只更新注音表，`\xpinyinvalue` 仍报「无读音」。（PR #1051）
