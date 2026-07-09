## [zhlineskip-v1.0h](https://github.com/CTeX-org/ctex-kit/releases/tag/zhlineskip-v1.0h)

- 文档等宽字体改用朱雀仿宋，意大利体改用霞鹜文楷 GB Lite。

## [zhlineskip-v1.0g](https://github.com/CTeX-org/ctex-kit/releases/tag/zhlineskip-v1.0g)

- 添加 `quiet` 选项用于削弱警告信息。

## [zhlineskip-v1.0f](https://github.com/CTeX-org/ctex-kit/releases/tag/zhlineskip-v1.0f)

- 使用 LaTeX3 重构，删除对 `kvoptions` 与 `xintexpr` 的依赖。
- 移除布尔选项 `UseMSWordMultipleLineSpacing`，将其并入选项 `MSWordLineSpacingMultiple` 中。
- 修复 `split` 环境行距恢复泄漏导致的 `display` 间距异常。

## [zhlineskip-v1.0e](https://github.com/CTeX-org/ctex-kit/releases/tag/zhlineskip-v1.0e)

- 延迟正文行距调整。

## [zhlineskip-v1.0d](https://github.com/CTeX-org/ctex-kit/releases/tag/zhlineskip-v1.0d)

- 增加警告描述。

## [zhlineskip-v1.0c](https://github.com/CTeX-org/ctex-kit/releases/tag/zhlineskip-v1.0c)

- 对未知的键值选项与无效的用户命令报错。

## [zhlineskip-v1.0b](https://github.com/CTeX-org/ctex-kit/releases/tag/zhlineskip-v1.0b)

- 新增选项 `MSWordSinglespaceRatio`。

## [zhlineskip-v1.0a](https://github.com/CTeX-org/ctex-kit/releases/tag/zhlineskip-v1.0a)

- 去掉了对 `setspace` 与 `caption` 宏包的依赖。
- 去掉了键值选项 `captionleadingratio`。
- 重命名键值选项 `MicrosoftWordLineSpacingMultiple` 为 `MSLineSpacingMultiple`
- 对外提供两个新的宏： `\SetTextEnvironmentSinglespace` 与 `\SetMathEnvironmentSinglespace`，分别用于微调西文环境与数学环境的行距。
- 其余优化与改动只涉及到含 `@` 的内部宏，例如：宏命名更加规范、利用 `sp` 长度做计算。
- 自动计算基础行距对字号的倍数。正文、脚注的基础行距与其字号的比值现在通过 `\f@baselineskip` 与 `\f@size` 计算得到。用户手册还更新了 `mtpro2` 正确的放大方法。
- Add `\textlinespre@d`。如果 scale 了西文字体或数学字体，可以通过 `\textlinespre@d` 或 `\m@thlinespre@d` 微调行距。
