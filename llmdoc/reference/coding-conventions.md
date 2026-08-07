# 编码约定

## expl3 命名规则与项目命名空间

`ctex-kit` 的现代代码以 expl3 为主，最重要的检索信号是“模块前缀 + 参数签名”。在本仓库中，常见公开命名空间包括：

- `\ctex_`：`ctex` 主模块
- `\xeCJK_`：`xeCJK` 主模块
- `\CJKtu_`：`xCJK2uni` 模块
- `\__ctxdoc_`：`support/ctxdoc.cls` 的内部实现

调查报告确认了以下典型例子：

- `ctex/ctex.dtx` 中存在 `\ctex_define_option:n`
- `xeCJK/xeCJK.dtx` 中存在 `\xeCJK_check_single_env:nnNn`
- `xCJK2uni/xCJK2uni.dtx` 中存在 `\CJKtu_char_to_unicode:n`
- `support/ctxdoc.cls` 中存在 `\__ctxdoc_version_zfill:wnnn`

因此，在搜索符号时，应优先用模块前缀作为入口，而不是先搜通用动词。

## e-type 优先于 x-type

自 #679 起，本仓库（ctex、xeCJK、zhnumber）全面使用 e-type expansion variant 代替 x-type（跟进 l3kernel 的推荐做法）。例如 `\tl_set:Ne` 代替 `\tl_set:Nx`，`\exp_args:Nne` 代替 `\exp_args:Nnx`。

**`Npx` 定义体的处理**：xeCJK/zhnumber 将 `Npx` 一并转为 `Npe`，体内需要延迟展开的 `\exp_args` 使用 `\exp_not:N` 保护；ctex 则将唯一含 `\exp_args:Nnx` 的 `Npx` 重构为 `Npn`（`\@@_disable_package_aux:nnnn`），从而消除了 `\edef` 体内的展开冲突。当前代码中不存在 `Npx`/`Npe` 体内保留裸 x-type `\exp_args` 的情况。

## 写完全可展开的命令时可用的工具（#550）

要让命令能用在 `\edef`、`\csname` 的构造式或 `bib2gls` 的字段里，整条调用链上不能出现任何不可展开的东西。哪些函数可展开不能凭印象判断，下面是 #550 逐个放进 `\edef` 实测的结果。

**确实不可展开**：

| 函数 | 症状 |
|---|---|
| `\str_if_in:nnTF` | 原样输出 `\str_if_in:nnTF {1234}{1}{IN}{OUT}` |
| `\keys_set:nn` | keyval 解析本身不可展开 |
| `\prg_new_protected_conditional:Npnn` 的 `TF` 形式 | 原样输出 `\pcp:nTF {5}{P}{N}` |
| `\tl_if_in:nnTF` | 原样输出整条命令 |
| `\str_remove_all:nn` | 把参数连花括号一起返回（`zhong1` 去掉 `o` 后 `\str_count` 从 6 变 11） |
| 任何 `\cs_new_protected:Npn` 定义的命令 | `e`／`x` 类展开都留不下文本 |

**这几个是可展开的，不要误判**（#550 初版曾把前两个列为不可展开，是错的）：

| 函数 | 实测 |
|---|---|
| `\str_case:nnF` | `\edef` 下正常求值 |
| `\prg_new_conditional:Npnn` 的 `TF` 形式（非 `protected`） | `\edef` 下正常求值 |
| `\str_if_eq:nnTF` | `\edef` 下正常求值 |

**误判的成因值得记**：这类函数会「看起来不可展开」，通常是因为**判据参数里嵌了未展开的函数调用**，而不是函数本身的问题。例如

```
\cs_new:Npn \bad:n #1 { \str_case:nnF { \last:n {#1} } { {1}{T1} } {NONE} }   % 得到 NONE
\cs_new:Npn \good:n #1 { \exp_args:Nf \goodaux:n { \last:n {#1} } }           % 得到 T1
```

`\str_case:nnF` 拿字面 token 比对，`\last:n {#1}` 没先展开就永远匹配不上，于是走 `F` 分支。**先用 `\exp_args:Nf` 把判据展开**，问题就消失了。诊断这类现象时，先怀疑自己没展开判据，再怀疑函数不可展开。

**可展开的替代**：

| 需求 | 用法 |
|---|---|
| 判断末字符是不是数字 | 用 <code>\int_compare:nNnTF</code> 比较反引号取到的码位：数字 `1`–`4` 的码位小于字母 `a`，一次比较即可（见 `xpinyin.dtx` 的 `\@@_query_base:nn`） |
| 表驱动分派 | 为每个键定义一个控制序列，用 `\cs_if_exist_use:cF` 查表 |
| 取子串 | `\str_range:nnn` |
| 遍历逗号列表 | `\clist_map_function:nN` |
| 判断串里有没有某几个字符 | 用 `\str_range:nnn` 逐字符取出，交给 `\str_case:enF` 比对（见 `\@@_query_markable_aux:nn`）；`\tl_if_in:` 与 `\str_remove_all:` 都不可展开 |
| 给 `map_function` 传具名函数 | `\exp_args:Nnc`；**不要**在可展开命令里 `\cs_set:Npn` 临时造闭包，那会破坏可展开性 |

**How to apply**：写这类命令时，先用一个最小 `.tex` 文件把每个候选函数放进 `\edef` 试一遍，确认能落成文本再写进实现。#550 在完整实现里调试时反复看到 expl3 内部命令被排进页面，改用独立最小文件后一轮就能定位。**试的时候要把判据也先展开**，否则会像上面那样把自己的展开错误记成函数的限制。

**选项不要放进可展开命令的参数**。keyval 解析不可展开，所以带选项的可展开命令做不出来。#550 的四个查询命令因此不接受可选参数，`scheme` 与 `tone` 一律用 `\xpinyinsetup` 设置，随 TeX 分组恢复；读 `tl` 变量本身是可展开的，且尊重分组。

## `@@` 私有命名空间

本仓库广泛使用 expl3 的私有命名约定 `\@@_...`。其含义不是“全仓库共享私有名”，而是“当前模块在 docstrip/expl3 语义下的私有占位前缀”。

典型例子包括：

- `ctex/ctex.dtx` 中的大量 `\@@_...` 内部例程
- `xeCJK/xeCJK.dtx` 中处理标点 margin/kerning 的 `\@@_calc_kerning_margin:NN`
- `xCJK2uni/xCJK2uni.dtx` 中的编码转换内部函数

阅读 `.dtx` 时，遇到 `@@` 名称应先把它解释为“该模块内部实现细节”，不要把不同文件里的 `\@@_...` 误认为同一命名空间。

## 参数签名是接口的一部分

本项目 expl3 函数名后缀中的参数签名是稳定检索线索，例如：

- `:n`
- `:nn`
- `:Nn`
- `:nnNn`

修改调用点或迁移实现时，必须同时核对函数名前缀和参数签名；仅靠词干匹配容易误改到重载变体。

## expl3 定义命令的作用域约定

在本仓库维护 expl3 代码时，定义命令不仅要看“是否成功生成控制序列”，还要明确其作用域语义：

- `\cs_new_protected:Npx` 是全局定义，对应 `\gdef` 一类语义；如果在组内调用，定义仍会泄漏到组外。
- `\cs_set_protected:Npx` 是局部定义，对应 `\def` 一类语义；如果在组内调用，分组结束后定义会回退。
- `\newcommand` 与现代 `\NewDocumentCommand` 在组内调用时也都是局部定义，因此用它们声明用户可见命令时，默认应按“受 TeX 分组约束”的行为理解。

这条约定在定义用户可见切换命令时尤其重要：若命令的存在性本身属于用户接口的一部分，就必须先判断它应该是“全局注册”还是“仅在当前组有效”。Issue #751 的修复正是一个典型案例：字体族注册可继续全局保存，但 `\newCJKfontfamily` 生成的用户切换命令需要改为局部定义，才能与 `fontspec` / LaTeX 用户对命令作用域的直觉保持一致。

同样的作用域一致性问题也出现在**镜像分组局部原语状态的布尔标志**上：`\bool_new:N` 声明的开关变量如果用来记录 `\XeTeXcharclass` 等本身受 TeX 分组约束的原语赋值当前状态，就必须同样声明为局部（`\bool_set_true:N`/`\bool_set_false:N`），而不能用全局布尔（`\bool_gset_true:N`/`\bool_gset_false:N`）——否则退组后原语状态自动回退，但全局布尔不回退，二者从此不一致。Issue #431（顺带回溯修正 #382）是该问题的具体案例，详见 `llmdoc/architecture/xecjk-architecture.md` "影子布尔的作用域必须与被控资源的作用域一致" 一节。

## expl3 正则里的 catcode class 记法

处理 token 级 catcode 问题时，优先记住 `\regex_replace_all` 可直接匹配字符类别，而不只是字符字面值：常见写法如 `\cP`（parameter，catcode 6）、`\cA`（active，catcode 13）、`\cO`（other，catcode 12）。这类语法适合区分“同样显示为 `#`、但 catcode 不同”的 token；若目标是只转换某一类 token，普通 `str`/`tl` 字符串替换往往不够精确（\#378）。

**反例 / 适用边界（\#879）**：`\regex_replace_all:nnN { \cP . } { \cA \x{23} } ...` 这类写法只在匹配端精确，**替换端 `\x{NN}` 是字面 codepoint**——所有匹配项被一律映射到固定字符码，丢失输入侧 token 的原字符身份。当用户通过 `\catcode\`\&=6` 等方式把其它字符设为 catcode 6 时，该前提被打破。需要保留原 codepoint 的场景应改用 token 级路径：`\tl_map_inline:Nn` + `\token_if_parameter:NTF` + `\char_generate:nn { \int_value:w ``##1 } { 13 }` 逐 token 重建。`\@@_listings_rescan:Nn` 的 \#378 → \#879 演化是典型案例。

## 字面字符当替换模式时必须核对 catcode régime（#1043）

`\tl_replace_all:Nnn` 这类 token 级替换按 **catcode + charcode 双重相等**匹配，所以模式里
写的字面字符必须与目标 token 同类别，否则**静默失效**：不报错、测试不挂，只是什么都没替换掉。

具体到 `&`：在 `\ExplSyntaxOn` 区域里直接写 `{ & }` 作模式**能匹配** `\halign` 语境的对齐符，
但原因是**LaTeX 环境默认把 `&` 设为 catcode 4（`latex.ltx` 里的 `\catcode`\&=4`），
而 `\ExplSyntaxOn` 不改 38**（实测它把 9、32 设为 9，58、95 设为 11，126 设为 10；
38 前后都是 4）。**不要把这归因于 `\c_code_cctab`**：catcode 表常量只在
`\cctab_select:N` 选中时才生效，xeCJK 从不选它（实测：环境设 `\catcode`\&=12` 后再
`\ExplSyntaxOn`，`&` 仍是 12；只有显式 `\cctab_select:N \c_code_cctab` 才变 4）。
注意本仓库并非完全不用：`ctex/ctex-auxpkg.dtx` 的 `\c__ctex_package_cctab` 就以
`\cctab_select:N \c_document_cctab` 派生，但那条路径不覆盖 xeCJK 的加载。

**风险发生在加载期，不是调用期。** 字面模式的类别在文件被 tokenise 的那一刻冻结：加载后
再改 `\catcode` 对字面写法和常量写法都没有影响（实测两者结果一致）。真正会失配的是
「本文件被读取时 `&` 已不是 4」——例如 `\usepackage` 之前做过 `\catcode`\&=12`。所以
防御性写法是在局部组里自行构造模板常量，把模式类别钉死在代码里，与读取时的 régime 解耦：

```latex
% —— 加载期执行一次：常量的 catcode 在这里钉死 ——
\group_begin:
  \char_set_catcode_alignment:N \&
  \tl_const:Nn \c_@@_alignment_tl { & }
\group_end:

% —— 调用期每次执行：模式取自上面那个常量 ——
\cs_new_protected:Npn \@@_some_function:n #1
  {
    \tl_set:Nn \l_@@_some_tl {#1}
    \tl_replace_all:NVn \l_@@_some_tl \c_@@_alignment_tl { \scan_stop: }
  }
```

两段分处两个时刻，正是本节的要点：常量在**加载期**建立（其 catcode 随之固定），替换在
**调用期**执行（此时环境的 `\catcode` 已无关）。

（`\tl_replace_all:NVn` 是 expl3 原生变体，无需自行 `\cs_generate_variant:Nn`。）

**判定某个 expl3 函数或变体是否存在，用 `\cs_if_exist:NTF` 在引擎里问，不要 grep 源码**：
变体是按组生成的（如 `\cs_generate_variant:Nn \tl_replace_all:Nnn { NnV , Nne , NV , ... }`
再加尾部补齐），字面 grep 必然搜不到，据此下「不存在」的结论会写出多余的声明（#1043 的
`NVn` 就是这样多声明了一次）。探针要带对照组：测一个确实不存在的变体（如
`\tl_replace_all:NnVn`）确认返回假，才说明这次判定有判别力。

配套注意事项：

- **清理输入时用惰性 token 占位，不要直接删除。** 删除会改变位置关系：`&$x$` 删掉 `&`
  后首项从 `&` 变成 `$`，下游「首项是不是公式」的判断随之误判。换成 `\scan_stop:`
  才是位置等价的变换（#1043 的 `\@@_boundary_math_set:n`）。
- **探针必须先用已知答案自证。** `\char_value_catcode:n` 本身就是可展开的整数量，
  **不要再加 `\int_use:N`（即 `\the`）前缀**：`\the` 会撞上展开结果的第一个数字，报
  `You can't use 'the character 1' after \the`，输出被截断成废数据——#1043 的原始误判
  正是这样来的（`{`(123) 读成 0、`$`(36) 读成 0、`a`(97) 读成 `01`）。直接写
  `\iow_term:x { ... \char_value_catcode:n {123} }` 读数是正确的（实测 123→1、36→3、
  97→11、92→0、38→4）；要保险也可以用 `\int_eval:n` 包一层。关键是**先测几个已知
  catcode 的字符确认读数正确，再相信目标字符的结果**——本轮的教训不是某个写法不能用，
  而是探针不自证就会把废数据当事实。

因为这类失败是静默的，修复**必须做门禁反向验证**：确认缺陷版 `l3build check` 退出码非 0，
而不只是确认修复版通过。注意反向验证要针对真正的失效机制——#1043 验证的是「删除替换」，
它不能证明「模板 catcode 写错」这一假设，后者需要单独变异（实测那样写并不失效）。
参见 `llmdoc/memory/reflections/1043-halign-alignment-tab-in-boundary-args.md`。
与 #879 的替换端 `\x{NN}` 丢失原 codepoint 属同类问题：凡拿字面字符做 token 级匹配或替换，
先问它在当前 catcode régime 下是什么类别。

## `.lvt` 测试文件中 `~` 的使用约定（#893）

`.lvt` 测试文件里 `~` 的合法性取决于所在的 catcode 段，写测试时必须区分：

- **`\ExplSyntaxOff` 段（默认 LaTeX catcode）**：`~` 是 active char（不可断空格）。在 `\TEST{...}` / `\BEGINTEST{...}` 标题与 `\TYPE{...}` 的 log 输出大括号内若把 `~` 当普通空格用，会让 `.tlg` baseline 出现字面 `~`，污染基线。**应改用普通空格。**
- **`\ExplSyntaxOn` 段（expl3 catcode）**：`~` 是合法的 expl3 空格（catcode 10），而普通空格反被 ignore（catcode 9）。此处的 `~` 不能盲目替换。

该约定由两道同源检查强制执行，共用脚本 `.githooks/check-test-tilde.sh`：

- **pre-commit 钩子**（`.githooks/pre-commit`）：本地提交时对 `git diff --cached` 检查。
- **CI 工作流**（`.github/workflows/lint-test-files.yml`）：PR 触发，对 base→head 的 `.lvt` 改动检查。

两者都**只检 diff 中新增行**（`+` 行），不动存量；并用 group-depth-aware 状态机判定当前是否在 `\ExplSyntaxOff` 段——进入大括号 group（如 `\sys_if_engine_luatex:F { \ExplSyntaxOff ... }`）后忽略内层 ExplSyntax 切换，避免误伤 expl3 内的合法 `~`。匹配 `[^{}]*` 不跨嵌套大括号，宁可漏报不误报。紧急情况可用 `git commit --no-verify` 跳过本地钩子。

存量一次性修复由 `scripts/fix-test-tilde.py` 完成：它以 `.tlg` 作 oracle（LaTeX 已求过 catcode，`.tlg` 字面是 ground truth），定位 `.tlg` 中 `text~text` 形态的 `~` 再回改对应 `.lvt`。#893 首轮修了 45 个 `.lvt`、约 280 处，影响 `ctex` 与 `xeCJK`，并同步刷新 `.tlg` baseline。

### `\ExplSyntaxOn` 宏定义中嵌入 Lua

在 `\ExplSyntaxOn` 下扫描宏定义时，源码中的普通空格已经按 expl3 类别码规则被
忽略。等到宏执行时再在 `\lua_now:n` 等入口内修改空格类别码，无法恢复定义阶段
已经丢失的空格。

因此，在这类定义中嵌入 Lua 时，应使用 `~` 明确生成 Lua 语法所需的空格，并用
分号或其他明确分隔符隔开相邻语句和关键字。不要依赖源码排版中的普通空格，也不要
假定换行一定能阻止 TeX 扫描后的 Lua 记号粘连。`fontset-macnew01.lvt` 的 LuaTeX
字体节点探针是这一规则的现有实例。

## `.choices:nn` 中优先使用 `#1` 而非 `\l_keys_choice_str`

l3keys 的 `<key>.choices:nn = {<choice 列表>}{<code>}` 在 `<code>` 中既可以读 `\l_keys_choice_str`（被选中分支名的字符串变量），也可以直接读 `#1`。**优先使用 `#1`**：

- `#1` 在选项解析时已被替换为字面分支名，不依赖运行时局部变量；
- `\l_keys_choice_str` 是局部状态，在 `\exp_args:N...`、`\ctex_at_end:n` 这类延迟展开链中容易因分组结束被回滚或被嵌套选项解析覆盖。

`ctex/ctex.dtx` 中 `space .choices:nn` 即因此踩过坑：原写法用 `\exp_args:Ne \ctex_at_end:n { ... \l_keys_choice_str ... }` 试图把选中值带到 `\AtEndOfPackage` 阶段执行，但延迟执行时 `\l_keys_choice_str` 已不再持有当时的值。PR #881（#806）将其改写为 `\ctex_at_end:n { \ctex_set:n { space = #1 } }`，同时把 `xeCJK / jiazhu / zhnumber` 中同类用法（如 `\use:c { bool_gset_ #1 :N }`）一并简化。

**Why:** `#1` 解决了“选项参数在静态展开期就固化”的需求，不需要纠结后续是否还在 keys 解析的局部组里。

**How to apply:** 新写 `.choices:nn` 时直接用 `#1`；遇到旧代码读 `\l_keys_choice_str` 而又涉及 `\exp_args`、`\AtEndOfPackage`、`\AtEndOfClass` 等延迟点时，应顺手替换为 `#1`。仅当代码确实需要“当前 key 名”等其它 l3keys 局部状态（如 `\l_keys_key_str`）时才保留显式变量。

## docstrip 标签系统

`ctex-kit` 的核心源码大量使用 docstrip 标签在单个 `.dtx` 中生成多个产物。稳定事实包括：

- 一个 `.dtx` 可同时输出 `.sty`、`.cls`、`.def`、示例文件和文档。
- `ctex/ctex.dtx` 是“单体源 + 多运行期配置文件”模式。
- `xeCJK/xeCJK.dtx` 是“单体源 + 主包/扩展包/示例/映射文件”模式。

因此，修改 `.dtx` 前要先判断目标代码属于哪个 docstrip 标签块，否则可能出现：

- 改了文档区，未改实现区
- 改了某个产物对应标签，却遗漏并行产物
- 错判某段代码的实际输出文件

### 引擎标签与 ctex.sty 的陷阱

`ctex.sty` 以 `{style,ctex}` 标签从 `ctex.dtx` 生成，**不含**引擎标签（`pdftex`、`xetex`、`luatex`、`uptex`）。引擎 `.def` 文件分别以 `{pdftex}`、`{xetex}`、`{luatex}`、`{uptex}` 标签生成。

关键约束：在 `ctex.sty` 输出的公共代码区域中使用 `%<*pdftex|xetex>` 守卫，该代码会被 docstrip 剥离，**不会**出现在 `ctex.sty` 中。这是一个已确认的陷阱（Issue #761 修复中踩过）。

引擎条件代码的正确做法：在引擎 `.def` 代码段中，用 `\ctex_at_end:n`（= `\AtEndOfPackage`）延迟到包加载末尾重定义公共区域中已存在的默认实现。

调查报告还指出，`xeCJK` 的 example 文档直接封装在 `xeCJK.dtx` 的剥离块里；这类文件既是示例，也是该包当前重要的验证载体。

## XeTeX 字体查找语法

XeTeX/fontspec 中两类常用字体写法对应不同后端：`"FontName"` 走 fontconfig 名称查找，适合系统字体；`"[FontName]"` 走文件/kpathsea 查找，适合 TeX tree 中、可被 `kpsewhich` 找到的字体。使用方括号语法时通常不需要显式写 `.otf` 或 `.ttf` 扩展名，kpathsea 会自行解析。维护字体相关代码时，只要目标字体来自 TeX tree，就应优先用方括号语法；这一区别会同时出现在 `ctex-spa-make.tex` 的字体加载和 `fontset` 层的字体定义里。

## `\CTEX@` 遗留接口与 expl3 共存

`ctex` 不是“纯 expl3、新写一遍”的项目；它保留了部分 `\CTEX@...` 风格的 LaTeX2e 遗留内部接口，与 `\ctex_...` 新接口并存。调查中给出的代表符号是 `\CTEX@char@n`，见 `ctex/ctex.dtx`。

这带来两个稳定约束：

1. 修改 `ctex` 时，不要假设所有内部调用都已迁移到 expl3。
2. 若发现同一功能同时经过 `\CTEX@...` 和 `\ctex_...` 两层包装，要先判断哪一层是兼容桥，哪一层才是实际后端。

通常：

- expl3 层更适合新增逻辑与统一选项处理。
- `\CTEX@...` 层常与旧接口兼容、LaTeX2e 钩子或历史行为保持有关。

## 文档排版类 `support/ctxdoc.cls`

`support/ctxdoc.cls` 是仓库共享的文档排版基础设施，供多个 `.dtx` 文档构建使用；其角色可理解为该项目自己的 `l3doc` 风格文档类。相关构建链会通过：

- 包级 `typesetsuppfiles = {"ctxdoc.cls"}`
- `support/build-config.lua` 的文档流程

把它复制到排版环境中，见 `ctex/build.lua:8-10`、`xeCJK/build.lua:9-12`、`support/build-config.lua:170-178`。

因此，如果文档构建、索引、变更记录排版或 `.dtx` 文档样式出问题，优先检查 `support/ctxdoc.cls`，不要先怀疑业务包逻辑。

### l3doc 私有接口兼容门禁

`support/ctxdoc.cls` (`\__codedoc_typeset_function_block:nN` override): ctxdoc 会完整重定义 l3doc 的函数条目排版函数，因此最低依赖与实现对标日期统一固定为 2026-06-18。`\LoadClass` 声明最低日期后，类还会用 `\@ifclasslater` 复核；版本过低时通过 `\ctex_patch_failure:N` 发出 critical 错误，而不是带着不匹配的私有接口继续排版。门禁必须放在 `\ExplSyntaxOn` 区域内，并位于消息声明和 `\ctex_patch_failure:N` 定义之后；否则只有旧版本失败分支才会暴露 catcode 或前向引用错误。

完整重定义依赖 `\__codedoc_function_index:e`、`\__codedoc_function_label:eN`、`\__codedoc_typeset_TF:`、`\__codedoc_typeset_expandability:`、`\g__codedoc_variants_seq`、`\__codedoc_typeset_variant_list:nN`、`\l__codedoc_macro_EXP_bool` 与 `\l__codedoc_macro_rEXP_bool`。升级 l3doc 时需要把这些接口、对标日期和 `ctex/test/testfiles-ctxdoc/` 专项基线一起核对；仅确认类能加载不足以证明排版补丁仍兼容。

### 长函数名压缩边界

`support/ctxdoc.cls` (`\l__ctxdoc_function_block_box`): 只把函数名本体与 pTF 后缀装入独立 hbox 并水平缩放，Added/Updated 日期、EXP/rEXP 标记与 variants 保持原尺寸。目标宽度是 `\marginparwidth - \marginparsep`，EXP 与 rEXP 分别再预留对应的右栏空间，不可展函数不额外预留；两档预留来自 function 表 6pt 列间距加可展性符号的 box 宽度测量，测量结果随字号缩放。若上游新增可展性类别，版本升级审计还必须为新标记补充对应预留宽度。

压缩分两阶段。正常弹性范围以整数 6 起步，依次把当前宽度乘以 `5/6`、`4/5`、`3/4`，累计宽度因此是原宽的 `5/6`、`4/6`、`3/6`，形成相对原始宽度等差的档位；若三档后仍超宽，再一次自适应到目标宽度，并广播 note 型警告函数名过长。循环只在当前宽度严格大于目标宽度时执行，精确相等时必须停止。修改这一算法时不能退回缩放整个 functions coffin，否则日期行也会被压缩；也不能把各轮因子误当成累计比例。

## 实际修改时的检索顺序

对现代包代码，推荐按以下顺序检索：

1. 目标包前缀，例如 `\ctex_` 或 `\xeCJK_`
2. 同名私有实现 `\@@_`
3. 若在 `ctex` 中，再补查 `\CTEX@`
4. 再回看对应 `.dtx` 的 docstrip 标签边界与生成产物

这比从生成后的 `.sty`/`.cls` 逆向追踪更稳定，因为真实维护入口通常仍在 `.dtx`。

## `.dtx` 中用户文档与实现文档的区分

`ctex.dtx` 和 `xeCJK.dtx` 中包含两类文档：

- **用户文档**（手册正文）：使用 `\begin{function}...\end{function}` 描述面向用户的接口，排版后出现在手册前半部分。
- **实现文档**（代码实现部分）：使用 `\begin{macro}...\end{macro}` 描述内部机制，排版后出现在手册后半部分。

新增选项或命令时，两处都需要添加说明：`\begin{function}` 面向用户解释用法和效果，`\begin{macro}` 面向开发者说明实现细节。
