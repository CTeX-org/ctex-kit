# #1122 `engine` 选项：公开选择引擎定义文件

## 背景

`ctex` 与 `ctexart` 等文档类原先只按 `\c_sys_engine_str` 自动检测编译引擎，再载入
`ctex-engine-<检测结果>.def`，并且在内核开头、处理宏包选项之前就检查该文件是否存在。用户没有
公开接口改变这一选择：想为某个引擎换用另一份引擎定义文件，只能改写 `ctex` 的内部常量，依赖
内部命名，`ctex` 重构后会静默失效。

## 决策

新增宏包/文档类选项 `engine`，取值为引擎定义文件名的中间部分：

- `engine = foo` 时载入 `ctex-engine-foo.def`，忽略自动检测的结果；
- 未指定，或者值为空时，仍按自动检测的结果载入；
- 指定的文件不存在时用 `engine-file-not-found` 报错并中止；沿用检测结果时仍用原有的
  `engine-not-supported`。

键只定义在 `ctex / option` 路径下，手册标记为只能作为宏包/文档类选项；`ctex` 键路径不定义它，
因此 `\ctexset` 不能设置它——引擎定义文件在宏包载入期间就已读入。键与存在性检查都在
`class|ctex` 的 docstrip 守卫内；`ctexsize` 与 `ctexheading` 不载入引擎定义文件，不受影响。

## 实现要点

- `\c_@@_engine_str` 的自动检测（含 ApTeX 判断）保持不变，作为默认值。选项值存进
  `\g_@@_engine_tl`，空值表示用默认值；`\tl_if_blank:VTF` 同时覆盖未指定与空值两种情形。
- 文件名的确定与存在性检查从宏包选项处理之前移到 `\ProcessKeyOptions` 之后、载入标准文档类
  之前：选项此刻才读得到，而错误仍然提前中止。`\c_@@_engine_file_str` 仍是常量，只在实际走到
  的那个分支里定义。
- 全仓库只有载入末尾的 `\ctex_file_input:n { \c_@@_engine_file_str }` 用到这个常量，它在新定义
  之后执行，因此推迟定义不会引用到未定义的变量。

## 其他决定

- **值按字面使用**：不折叠大小写，也不剥 `.def` 后缀。`engine = Luatex` 与 `engine = luatex`
  是两个不同的名字。
- **与真实引擎不符时不警告**：第三方引擎定义文件的合法名字本来就可能与检测结果不同，无条件
  警告会在每次正常使用时出现。
- **不公开检测结果**：第三方文件需要按真实引擎分支时用 `\sys_if_engine_*`，
  `\c_@@_engine_str` 保持私有。
- **不加「`engine = 当前引擎` 与不指定等价」的专门用例**：两者载入的是同一个文件，断言接近
  恒真。
- **只替换引擎定义文件，不切换引擎**：中文编码的处理、字体集的自动选择、`fntef` 选项等仍按
  真实引擎分支；引擎定义文件原本负责的设置（例如中文书签参数）须由自定义文件自己完成。手册
  的 `engine` 条目写明这条边界，并说明这些内部接口不保证稳定。
- **不加参数校验**：选项值只按字面拼进文件名，不挡住大小写不符或与真实引擎不符的取值。

## 影响

`ctexopts.cfg` 在选项处理之前读入，因此可以在其中用 `\keys_set:nn { ctex / option }` 给
`engine` 设默认值，不需要再碰内部常量。反过来说，此前靠在 `ctexopts.cfg` 里重定义
`\c__ctex_engine_file_str` 的写法会失效：这个常量现在在 `ctexopts.cfg` 之后才定义，重定义的
结果会被随后的定义覆盖。

## 验证

`ctex/test/testfiles/engine-option01.lvt`（`\documentclass[fontset = fandol, engine = ctextest]`）
与 `engine-option02.lvt`（`\usepackage[engine = doesnotexist]`）在 pdfTeX、XeTeX、LuaTeX、upTeX
四个引擎下通过。两项变异的判别力已实测：把键改成空实现后 `engine-option01` 报
`Variable \c__ctex_engine_option_test_tl undefined`；去掉选项分支的 `file_if_exist` 检查后
`engine-option02` 的期望输出整段消失。

测试支持文件 `ctex/test/support/ctex-engine-ctextest.def` 先记录自己被载入（`\tl_const:Nn`），
再转交给 `ctex-engine-<当前引擎>.def`，使测试文档仍有可用的后端；`engine-option01` 的第二项断言
`\ccwd` 已定义，用来确认这次转交确实发生。

用户手册 `l3build doc` 零错误、零未定义引用；Overfull 宽度多重集与 master 构建一致（19 处）。

## 相关

- Issue：#1122；PR：#1123。
- 实现：`ctex/ctex-kernel.dtx`（选项定义、`\subsubsection{确定引擎定义文件}`、`\changes`）。
- 文档：`ctex/ctex.dtx` 的 `\subsection{编译方式}`。
- 测试：`ctex/test/testfiles/engine-option01.lvt`、`engine-option02.lvt`、
  `ctex/test/support/ctex-engine-ctextest.def`。
- 架构说明：`llmdoc/architecture/ctex-architecture.md`「引擎定义文件的公开选择（`engine` 选项）」。
- 过程反思：[[1122-engine-option-process]]。
