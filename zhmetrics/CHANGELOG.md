## [zhmCJK-v0.9d](https://github.com/CTeX-org/releases/tag/zhmCJK-v0.9d)

- 兼容 LaTeX 2020/10/01 的钩子机制。

## [zhmCJK-v0.9c](https://github.com/CTeX-org/releases/tag/zhmCJK-v0.9c)

- 支持字体属性可选项在后的新语法。

## [zhmCJK-v0.9b](https://github.com/CTeX-org/releases/tag/zhmCJK-v0.9b)

- 使用 `\CJK@@enc` 避免一些定义问题。
- UTF8 编码不使用 `\CJK@makeActive`。

## [zhmCJK-v0.9a](https://github.com/CTeX-org/releases/tag/zhmCJK-v0.9a)

- 使用 `CJK*` 的环境头代替完整 `CJK*` 环境，可以减少一个全局分组。（由李清建议）
- 保存重复的字体映射。（李清）
- 处理 UTF-8 编码下的拼音符号输入。

## [zhmCJK-v0.9](https://github.com/CTeX-org/releases/tag/zhmCJK-v0.9)

- 增加宏包 `cmap` 选项选择 DVIPDFMx 的 CMap 映射。
- 增加宏包 `embed` 选项，允许 DVIPDFMx 驱动不嵌入字体。
- 重新实现伪粗体、伪斜体功能，使之可以正常处理断行、标点压缩等问题。
- 支持伪粗斜体。
- 设置字体 `cmap` 选项。
- 设置字体 `embed` 选项。

## [zhmCJK-v0.8](https://github.com/CTeX-org/releases/tag/zhmCJK-v0.8)

- 增加宏包 `encoding` 选项选择默认编码。
- 设置字体 `encoding` 选项。

## [zhmCJK-v0.7](https://github.com/CTeX-org/releases/tag/zhmCJK-v0.7)

- 宏包载入时进行编译引擎测试
- 更改语法，修改选项位置。
- 修改可选参数位置，以与 `xeCJK` 包语法一致。
- 生成 TFM 时加入版权说明。

## [zhmCJK-v0.6](https://github.com/CTeX-org/releases/tag/zhmCJK-v0.6)

- 增加宏包 `AutoFakeSlant` 选项
- 增加字体 `AutoFakeSlant` 选项

## [zhmCJK-v0.5](https://github.com/CTeX-org/releases/tag/zhmCJK-v0.5)

- 使用 Lua 脚本生成 TFM 和映射文件；为 MiKTeX 生成单独的 TFM 文件。将原来的 `zhmetrics.tfm` 改名为 `zhmCJK.tfm`，不再依赖原有的 `zhmetrics` 包。

## [zhmCJK-v0.4](https://github.com/CTeX-org/releases/tag/zhmCJK-v0.4)

- 增加宏包 `AutoFakeBold` 选项
- 设置字体 `AutoFakeBold` 选项。
- 设置字体 `BoldFont` 选项。
- 设置字体 `ItalicFont` 选项。
- 设置字体 `BoldItalicFont` 选项。
- 设置字体 `SlantedFont` 选项。
- 设置字体 `BoldSlantedFont` 选项。

## [zhmCJK-v0.3](https://github.com/CTeX-org/releases/tag/zhmCJK-v0.3)

- 增加宏包 `pdffakebold` 选项
- 使用 PDF 原语生成伪粗体
- 新增 `\setCJKmainfont` 的别名。

## [zhmCJK-v0.2](https://github.com/CTeX-org/releases/tag/zhmCJK-v0.2)

- 编写宏包文档。增加 `CJKpunct`。做一些小的代码调整。

## [zhmCJK-v0.1](https://github.com/CTeX-org/releases/tag/zhmCJK-v0.1)

- 初始版本

