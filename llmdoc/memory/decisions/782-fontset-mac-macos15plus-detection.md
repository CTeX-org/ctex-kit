# 决策：保留 `fontset=mac`，在 macOS 15+ 上改为版本检测加运行时字体探测

## 背景

Issue #722 / PR #782 处理的是 `fontset=mac` 在 macOS 15+ 上的失效问题。旧实现以 `/System/Library/Fonts/PingFang.ttc` 是否存在作为 `macnew` / `macold` 的唯一判定条件；这在早期系统上可行，但从 macOS 15 (Sequoia) 起，苹方、楷体、仿宋、隶书、圆体等部分 CJK 字体转为 downloadable，不再位于传统系统字体路径。

结果是：

- `fontset=mac` 会把 macOS 15+ 误判成 `macold`；
- 即使强制走 `macnew`，XeTeX 与 LuaTeX 对 downloadable 字体的可见性也并不相同；
- 原先计划中的 `fontset=mac15plus` 会把“系统版本差异”暴露为新的公开字体集名称，增加长期接口负担。

## 关键观察

在 macOS 26 的实测中，稳定结论是：

- XeTeX 与 LuaTeX 都能读取 `SystemVersion.plist`，因此 macOS 主版本号可作为可靠后备判定信号；
- XeTeX 下 `\fontspec_font_if_exist:nTF { PingFang SC }` 在字体已下载时可用；
- LuaTeX 下同样的名字探针对 `PingFang SC` 不可靠，不能作为 downloadable 字体可用性的判断依据；
- LuaTeX 可以通过扫描 `/System/Library/AssetsV2` 及其 `com_apple_MobileAsset_Font*` 子树，找到 downloadable 字体实际存放的 `AssetData/` 路径，并用 `Path=` + `FontIndex` 显式加载。

## 决策

### 1. 不新增 `fontset=mac15plus`

继续把 `fontset=mac` 作为用户入口，仅在内部保留 `macnew` 与 `macold` 两个字体集概念。`mac15plus` 不作为兼容 alias 保留。

这样可以维持公开接口稳定：用户仍然只需要选择“mac 平台默认字体集”，不需要学习新的系统版本专用字体集名。

### 2. `fontset=mac` 改为双阶段判定

新的自动判定顺序是：

1. 先检查 `/System/Library/Fonts/PingFang.ttc` 是否存在；
2. 若存在，直接视为 `macnew`；
3. 若不存在，再读取 `SystemVersion.plist` 的主版本号；
4. 版本号 `>= 15` 时仍使用 `macnew`，`< 15` 时使用 `macold`；
5. 若版本检测失败，则 warning 后回退到 `macold`。

也就是说，传统路径检测被保留为快速路径，但不再是唯一真相来源。

### 3. `macnew` 内部按引擎使用不同的运行时探测策略

- XeTeX：使用 `\fontspec_font_if_exist:nTF` 按字体名检查可用性；
- LuaTeX：使用 Lua + `lfs.dir` 动态扫描 AssetsV2 路径，并以 `Path=` + `FontIndex` 显式加载 downloadable 字体；
- 核心字体 `Songti SC`、`Heiti SC` 仍作为可用性的稳定底座；
- `PingFang`、`Kaiti`、`STFANGSO`、`Baoli`、`Yuanti` 等视为可选增强，缺失时静默跳过或回退。

### 4. `\pingfang` / `\yahei` 保持命令可用，但允许回退到黑体

当 `PingFang` 不可用时，不再把相关命令暴露为“缺失接口”，而是退回 `\heiti` 语义，以保持旧文档的接口兼容性。

## 取舍理由

### 为什么不保留 `mac15plus`

- 用户心智模型更差：`fontset` 本来表示字体集预设，不应把具体系统版本暴露成新的长期公开名称。
- 维护成本更高：一旦保留 alias，后续还要长期说明 `mac`、`macnew`、`mac15plus` 三者关系。
- 实际问题并不是“需要第三种字体集”，而是 `mac` 的平台检测和 `macnew` 的字体发现机制都需要升级。

### 为什么 LuaTeX 不沿用名字探针

因为在实测里，LuaTeX 对 downloadable 字体的名字可见性并不可靠。若继续依赖 `\fontspec_font_if_exist:nTF { PingFang SC }`，会把“字体已安装但 luaotfload 看不见”的情况误判成字体不存在。

### 为什么检测失败时回退到 `macold`

这是保守失败策略：

- `macold` 不依赖 downloadable 字体；
- 相比误进 `macnew` 后大量 optional 字体缺席，退回 `macold` 更接近旧系统上的稳定最小可用配置；
- 同时保留 warning，便于用户和维护者发现平台探测链路异常。

## 影响范围

- `ctex/ctex.dtx` 中 `%<*mac>`：自动选择 `macnew` / `macold` 的逻辑。
- `ctex/ctex.dtx` 中 `%<*macnew>`：XeTeX 与 LuaTeX 的字体加载策略。
- `ctex/ctex.dtx` 的用户文档：`fontset=mac`、`macnew`、`\pingfang` 的说明。

## 对后续维护的约束

1. 未来若 macOS 再次调整 downloadable 字体的目录编号，LuaTeX 路径应继续依赖 `com_apple_MobileAsset_Font*` 的动态发现，而不是写死具体 `FontN` 目录名。
2. 不要把 XeTeX 与 LuaTeX 的字体探测代码强行合并；两条后端路径的可靠信号不同。
3. 若以后补测试，应把“系统版本判定”和“字体可选回退”视为两个独立行为来覆盖。

## 关联记录

- Issue #722
- PR #782
- `llmdoc/reference/ctex-fontset-mac.md`
