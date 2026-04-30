---
name: 581-xecjk-zero-width-format-chars
description: xeCJK #581 修复反思：零宽格式字符应在输入层忽略，避免进入 interchar 分类并触发错误的 CJKecglue
type: reflection
---

## 任务

修复 xeCJK issue #581：U+200B ZERO WIDTH SPACE 会导致错误的 `CJKecglue` 插入，进而改变 CJK 与 Latin 边界附近的实际排版间距。

## 修复

在 `xeCJK/xeCJK.dtx` 的字符类别初始化区段，将以下字符统一设为 `\char_set_catcode_ignore:n`：

- U+200B ZERO WIDTH SPACE
- U+200C ZERO WIDTH NON-JOINER
- U+200D ZERO WIDTH JOINER
- U+2060 WORD JOINER

它们与原本已忽略的 U+FEFF（BOM）采用同一处理策略，从 TeX 输入层直接消失，不再参与 xeCJK 的 interchar 分类与 token 插入。

## 关键判断

### `catcode ignore` 比“重新分配字符类”更安全

表面上看，这类零宽字符似乎也可以通过 XeTeX 字符类系统处理，例如塞进 `NormalSpace` 或透明类 256。但真正的问题不在“它们显示成什么”，而在“它们是否进入 class 序列”。只要它们仍参与 xeCJK 的字符分类，就可能把原本连续的 CJK 或 CJK↔Latin 边界切断，导致 `CJKglue` / `CJKecglue`、字体切换或分组 token 的插入位置改变。

因此，这类字符的正确心智模型不是“零宽字符的版式策略”，而是“应当在输入层被过滤掉的格式控制字符”。

### `NormalSpace` 方案会破坏边界判定

把 U+200B 一类字符归入 `NormalSpace` 看似自然，但会把本来相邻的 CJK 字符拆成 `CJK + NormalSpace + CJK`，或把 `CJK + Latin` 拆成 `CJK + NormalSpace + Latin`。这样会直接改变 xeCJK 的 interchar 状态机输入，导致 glue 与字体选择逻辑偏离预期。

### 透明类 256 有已知分组陷阱

`xeCJK.dtx` 已记录：XeTeX 透明类（class 256）虽然不改变状态，但在使用 `\XeTeXinterchartoks` 插入 `\bgroup` / `\egroup` 的场景下，会因为行尾或边界状态导致分组不匹配。这意味着“transparent”并不等于“无副作用”，尤其不适合放进 xeCJK 依赖分组平衡的边界机制里。

## 测试策略

新增 `xeCJK/testfiles/zwchars01.lvt`，使用 6 个宽度比较用例验证：

1. U+200B 不影响纯 CJK 串的 glue
2. U+200B 不影响 CJK-Latin 边界
3. U+200C 被忽略
4. U+200D 被忽略
5. U+2060 被忽略
6. U+FEFF 继续保持被忽略

这里测试的核心不是字符本身“输出什么”，而是插入零宽格式字符后，盒子宽度必须与未插入时完全一致。对 xeCJK 这类以 interchar token 控制间距的系统，宽度相等是验证“没有额外 glue / ecglue 被插入”的最稳定信号。

## 教训

- 遇到不可见 Unicode 字符引发的 xeCJK 间距问题，先检查它是否错误进入了字符分类与 interchar 机制，而不是先调 `PunctStyle` 或 glue 参数。
- XeTeX class 256 透明类并不是通用的“忽略字符”方案；凡是依赖 `\bgroup` / `\egroup` 平衡的 interchartoks 设计，都要警惕透明类造成的边界异常。
- 对零宽格式字符这类输入层问题，最稳妥的回归测试通常是盒子宽度或节点列表不变性测试，而不是只看日志里是否“没有报错”。
