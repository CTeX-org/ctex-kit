# ctex fontset 与 macOS 系统字体检测

## 适用范围

本文只记录 `ctex/ctex-fontset.dtx` 中 `fontset` 尤其是 `fontset=mac` / `macnew` / `macold` 的稳定行为、分层边界与跨引擎差异。若问题表现为 XeTeX 专属的标点、字符分类或第三方包 hook，应转到 `llmdoc/architecture/package-architecture.md` 中的 `xeCJK` 架构部分。

## fontset 层的职责边界

`ctex` 的字体集层负责把“默认中文正文字体/黑体/仿宋/楷书”等高层角色映射到具体系统字体或发行版字体，并在运行时决定应加载哪份 `ctex-fontset-*.def`。在 `ctex` 的典型加载链中，字体集层位于引擎层之后、方案层之前：

1. `ctex.sty` 建立统一选项与运行期变量；
2. `ctex-engine-*.def` 选择引擎后端；
3. `ctex-fontset-*.def` 把字体角色落到平台字体；
4. `ctex-scheme-*.def` / `ctex-heading-*.def` 再叠加中文样式与标题行为。

因此，`fontset` 相关问题首先要判断是：

- 字体集选择错了；还是
- 已选中的字体集内部又需要按引擎分支做运行时可用性检测。

PR #782 对 `fontset=mac` 的改造属于后一类：保留 `macnew` / `macold` 两个字体集概念，但重写 `mac` 的自动判定与 `macnew` 的运行时字体探测逻辑，而不是再引入新的公开字体集名称。

## `fontset=mac` 的选择不变量

`fontset=mac` 仍然是“自动在 `macnew` 和 `macold` 之间二选一”的入口，不再引入也不保留 `mac15plus` 之类的公开 alias。稳定不变量如下：

- 如果 `/System/Library/Fonts/PingFang.ttc` 存在，直接视为旧式本地安装路径可用，加载 `ctex-fontset-macnew.def`。
- 如果该路径不存在，则再读取 `/System/Library/CoreServices/SystemVersion.plist` 的主版本号。
- 主版本号 `>= 15` 时，仍加载 `ctex-fontset-macnew.def`。
- 主版本号 `< 15` 时，加载 `ctex-fontset-macold.def`。
- 若版本号检测失败，则发出 `macos-version-detect-failed` warning，并回退到 `macold`。

这意味着当前设计把“苹方字体是否仍在传统路径”从唯一判定条件降级为快速路径；当 macOS 15+ 把 CJK 字体改为 downloadable、导致传统路径失效时，系统版本检测成为必要后备。对应实现位于 `ctex/ctex-fontset.dtx` 的 `%<*mac>` 区段。

## 版本号检测的跨引擎实现

`fontset=mac` 的版本号读取不是统一复用一套后端，而是按引擎分别实现：

### LuaTeX

LuaTeX 通过 `\lua_now:n` 直接执行 Lua：

- 用 `io.open` 读取 `SystemVersion.plist`；
- 用 Lua `string.match` 提取 `ProductVersion` 对应 `<string>`；
- 只取主版本号；
- 通过 `token.set_macro(..., "global")` 写回 `\g_@@_macos_ver_tl`。

### XeTeX

XeTeX 路径用 expl3 文件读取完成同一工作：

- `\ior_open:Nn` 打开 `SystemVersion.plist`；
- `\ior_map_inline:Nn` 逐行扫描；
- 先定位包含 `ProductVersion` 的行，再在下一行用 `\regex_replace_once:nnN` 提取主版本号；
- 成功后全局写入 `\g_@@_macos_ver_tl` 并 `\ior_map_break:` 结束扫描。

这个实现分工本身是一个稳定信号：遇到 macOS 平台探测问题时，不应假设 XeTeX 与 LuaTeX 共享同一段底层代码，必须按引擎分别核查 plist 读取链路。

## `macnew` 的运行时字体策略

`macnew` 现在不再假设整组华文字体与苹方字体都稳定常驻本地。它的策略分成两层：

### 1. 核心字体优先保证

以下角色被视为核心能力，优先保证可加载：

- 正文字体：`Songti SC Regular`（字重 400）/ `Songti SC Bold`
- 黑体基础：`Heiti SC Light` / `Heiti SC Medium`

其中宋体与黑体仍作为 `zhsong`、`zhhei` 等主字体族的稳定底座；这保证即使 downloadable 字体缺席，`macnew` 仍能形成可用的主字体配置，而不是整体失效。

Issue #994 把宋体的常规直立字形从 `Songti SC Light`（字重 300）改为
`Songti SC Regular`（字重 400）。选择时以 `fontset=ubuntu` 使用的
Noto Serif CJK SC 常规字重为参照；`Songti SC Regular` 与该参照更接近。
这项变化不影响粗体、黑体、圆体等其他多字重配置。

### 2. 可选字体按可用性启用

以下字体被视为可选增强：

- `PingFang` / `PingFang SC`
- `Kaiti` / `Kaiti SC`
- `STFANGSO` / `STFangsong`
- `Baoli` / `Baoli SC`
- `Yuanti` / `Yuanti SC`

这些字体在 macOS 15+ 上可能尚未下载，因此运行时检测采用“可用则配置，不可用则静默跳过或回退”的模型，而不是把缺失视为致命错误。

## `macnew` 的 XeTeX 分支

XeTeX 分支依赖 `fontspec` 的运行时名字解析能力，使用 `\fontspec_font_if_exist:nTF` 检查字体名是否可见。稳定行为如下：

- 正文宋体的常规直立字形直接按具名字体 `Songti SC Regular` 加载，粗体为
  `Songti SC Bold`；黑体仍按 `Heiti SC Light` / `Heiti SC Medium` 加载；
- `PingFang SC` 可见时，将无衬线主字体设为 `PingFang SC`，并定义 `zhpf`；
- `PingFang SC` 不可见时，将 `\setCJKsansfont` 回退为 `Heiti SC Light` / `Heiti SC Medium`；
- `Kaiti SC`、`STFangsong`、`Baoli SC`、`Yuanti SC Light` 都按“检测到才定义相应 family”的方式处理。

这里有一个重要边界：XeTeX 只依赖名字可见性，不处理 AssetsV2 路径扫描。因此在 XeTeX 路线下，问题通常表现为“字体名是否被 fontspec 看见”，而不是“路径拼接是否正确”。

## `macnew` 的 LuaTeX 分支

LuaTeX 分支不能依赖 `\fontspec_font_if_exist:nTF { PingFang SC }` 判断 downloadable 字体，因为该探针在 LuaTeX 下对这类字体并不可靠。当前稳定策略是直接用 Lua 扫描 macOS 的 AssetsV2 目录树：

- 枚举 `/System/Library/AssetsV2` 与 `/System/Library/AssetsV2/PreinstalledAssetsV2/InstallWithOs`；
- 动态发现所有 `com_apple_MobileAsset_Font*` 目录，而不是写死 `Font6` / `Font7` / `Font8` 之类具体编号；
- 在其 hash 子目录下查找 `AssetData/` 中的目标字体文件；
- 找到后，把该 `AssetData/` 路径记录到对应的全局 token list；
- 对 downloadable 字体使用 `Path = ...` + `FontIndex = ...` 显式加载。

当前扫描的目标字体文件包括：

- `PingFang.ttc`
- `Kaiti.ttc`
- `STFANGSO.ttf`
- `Baoli.ttc`
- `Yuanti.ttc`

其中：

- 核心字体仍按名字加载，因为 `luaotfload` 能直接看到它们；正文宋体明确使用
  具名字体 `Songti SC Regular`，粗体使用 `Songti SC Bold`；
- downloadable 字体则必须通过路径加索引显式指定；
- 若某个可选字体未找到，对应 family 不定义或回退，不报错。

这是 PR #782 改造后最关键的 LuaTeX 设计点：LuaTeX 路径对 macOS 15+ downloadable 字体的支持依赖文件系统发现，不依赖名字存在性探针。

## 宋体字形的跨引擎映射与标点数据

`macnew` 的各引擎路径必须指向同一个简体中文 Regular 字形：

- XeTeX 与 LuaTeX 使用具名字体 `Songti SC Regular`；
- LaTeX+DVI 与 upLaTeX 使用 `Songti.ttc` 的 index 6；这是简体中文
  Regular 字形，旧的 Light 字形位于 index 3；
- `ctex-zhmap-mac.tex` 中的宋体映射同样使用 index 6。

字体映射变化还会影响标点压缩所依赖的边界数据。`ctexpunct.spa` 中
`maczhsong` 的数据已在 macOS 上用 XeTeX 加载 `Songti SC Regular` 后重新测量，
不再沿用 Light 字形的度量。以后若调整 `macnew` 的正文宋体，应同时核对具名字体、
`Songti.ttc` 索引、zhmap/upLaTeX 映射和 `maczhsong` 标点数据，避免各引擎实际使用的
字形或标点度量不一致。

更换正文常规字形时，应把以下项目当作一份不可拆开的同步清单：

- XeTeX 与 LuaTeX 使用的具名字体；
- LaTeX+DVI 与 upLaTeX 使用的 TTC index；
- `ctex-zhmap-mac.tex` 中的 zhmap 映射；
- `ctex-spa-make.tex` 中的 SPA 生成源；
- `ctexpunct.spa` 中由目标字形实际测得的跟踪数据；
- 用户手册、变更记录和专项回归测试。

只改其中一项会造成不同后端选择不同字形，或者让标点压缩继续使用旧字形的度量。

## `macnew` 平台专属回归的证据分层

`ctex/test/testfiles/fontset-macnew01.lvt` 把配置检查与字体运行时检查分开，二者不能
互相替代：

1. 所有平台都检查解包后的 `ctex-fontset-macnew.def`、`ctex-zhmap-mac.tex` 和
   `ctex-spa-make.tex`，确认具名字体、TTC index、zhmap 与 SPA 生成源已经同步。
   这些断言只检查生成配置，不会加载 Apple 字体。
2. macOS XeTeX 分支直接加载 `Songti SC Regular`，逐个取得标点的字形编号和
   字形边界，现场生成 `maczhsong` 数据，再与仓库跟踪的 `ctexpunct.spa`
   比较。字体缺失、字形映射变化或边界数据不同都会使测试失败。
3. macOS LuaTeX 分支先设置该字体，再实际排出中文字形；探针递归进入 `hlist` 和
   `vlist`，从字形（glyph）节点取得字体对象，并核对 `fullname` 或 PostScript 字体名为
   `Songti SC Regular` 或 `SongtiSC-Regular`。只让字体族声明不报错不足以证明
   按需加载的字体已经用于排版。

Linux 服务器没有 `Songti SC` 等 Apple 字体时，同一测试仍可通过生成配置检查，
但 macOS 条件分支不会执行。因此，本地绿色结果不能表述为“Apple 字体实际加载
通过”，必须注明运行了哪一层检查。LaTeX+DVI 与 upLaTeX 当前也只检查 TTC index
和 zhmap 配置，尚未覆盖从文档排版到 `dvipdfmx` 加载字体的完整流程，不能把这部分
说成端到端字体回归。

## `\pingfang` / `\yahei` 的稳定回退语义

`macnew` 下仍保留与旧用户接口兼容的字体命令，但其语义已变为“尽量使用苹方，否则退回黑体”：

- 若 `PingFang` / `PingFang SC` 可用，则定义 `zhpf`，`\pingfang` 指向该 family；
- 若不可用，则不再把 `\pingfang` / `\yahei` 视为不可用命令，而是回退为 `\heiti` 的别名。

因此，对外接口的稳定承诺是“命令继续存在”，而不是“命令总能指向苹方本身”。用户若需要完整的苹方、楷体、仿宋、隶书、圆体集合，应先在字体册中下载相应字体资源。

## 排障检索顺序

遇到 `fontset=mac` 相关问题时，按以下顺序判断：

1. `fontset=mac` 是否选错了 `macnew` / `macold`；
2. 若是 macOS 15+，检查 `SystemVersion.plist` 读取链是否成功；
3. 区分 XeTeX 还是 LuaTeX：
   - XeTeX：优先检查 `\fontspec_font_if_exist:nTF` 对字体名的可见性；
   - LuaTeX：优先检查 AssetsV2 扫描与 `Path`/`FontIndex` 显式加载；
4. 若缺的是 `PingFang`、`Kaiti`、`STFangsong`、`Baoli`、`Yuanti` 一类字体，再判断它是否本来就属于可选 downloadable 字体，而不是核心必备字体。

## 相关源码入口

- `ctex/ctex-fontset.dtx` 中 `%<*mac>`：`fontset=mac` 的 `macnew` / `macold` 自动判定。
- `ctex/ctex-fontset.dtx` 中 `%<*macnew>`：`macnew` 在 XeTeX / LuaTeX / upLaTeX 路径下的字体设定。
- `ctex/ctex.dtx` 中 `fontset` 用户文档区：`macnew`、`\pingfang`、`\yahei` 的用户可见说明。
