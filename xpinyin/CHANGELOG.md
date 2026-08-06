## [xpinyin-v3.2](https://github.com/CTeX-org/ctex-kit/releases/tag/xpinyin-v3.2)

- 为 `\disablepinyin` 增加 star 版本：用于将其作用域覆盖到 `\xpinyin` 自身。（#265）
- 补齐独立回归测试，并接入按 tag 构建发布包所需的版本一致性校验。宏包代码本身没有变化。
- 在 `xeCJK` 的 `AutoFallBack` 已切换到后备字体时，量宽盒子不再重选主字体，修复注音被压缩到错误宽度的问题（#997）。
