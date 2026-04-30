# 构建与测试参考

## 统一构建系统

`ctex-kit` 的现代包大多使用 `l3build`，并通过各自目录下的 `build.lua` 声明模块元数据，再用 `dofile("../support/build-config.lua")` 继承项目级统一行为。见 `ctex/build.lua:71`、`xeCJK/build.lua:151`。

对于理解构建行为，优先区分两层：

- 包级 `build.lua`：描述该包自己的源码、安装文件、测试目录、引擎与额外钩子。
- `support/build-config.lua`：定义整个仓库共享的 l3build 覆写、目标扩展和发布期处理。

## `support/build-config.lua` 的角色

`support/build-config.lua` 是仓库的构建中枢，主要负责以下稳定机制：

### 1. 工具默认值

它统一设置：

- `supportdir`
- `unpackexe = "luatex"`
- `typesetexe = "xelatex"`
- `makeindexexe = "zhmakeindex"`
- `checkopts` / `typesetopts`
- 二进制文件后缀列表

见 `support/build-config.lua:2-10`。

### 2. 文档排版循环

自定义 `typeset()` 会在多轮 TeX / biber / bibtex / makeindex 之间循环，直到 `.aux`、`.bbl`、`.glo`、`.idx`、`.hd` 的 MD5 不再变化，避免文档尚未收敛就停止。见 `support/build-config.lua:25-56`。

### 3. dtx 校验和维护

通过 `target_list.checksum` 和 `dtxchecksum()`，仓库可以批量调整 `\CheckSum{...}`。对 `.dtx` 大改后，如需更新文档校验和，先看这里而不是手工维护。见 `support/build-config.lua:58-76`。

### 4. Git 版本展开

`extract_git_version()`、`expand_git_version()`、`replace_git_id()` 会抽取最近一次 git 提交信息，替换源文件中的 `\GetIdInfo` 区段，并把生成后的 `.id` 信息用于打包。见 `support/build-config.lua:86-133`。

### 5. 测试基线保存

`saveall()` 为所有 `.lvt` 保存验证日志，并在非标准引擎的 `.tlg` 与标准引擎结果一致时删除冗余文件。见 `support/build-config.lua:149-186`。

### 6. 对 l3build 目标的钩子化覆写

它重写并包装了：

- `doc`
- `bundleunpack`
- `install_files`
- `copyctan`

因此很多包级 `*_prehook` / `*_posthook` 逻辑只有结合这个共享文件才能正确理解。见 `support/build-config.lua:188-233`。

## 各包 `build.lua` 的标准结构

现代子包的 `build.lua` 通常遵循同一骨架：

1. `module = "..."`
2. 设定 `sourcefiles`、`unpackfiles`、`installfiles`
3. 设定 `typesetsuppfiles`、`gitverfiles` 等文档/版本相关字段
4. 指定 `testfiledir`、`testdir`、`checkengines`、`stdengine`
5. 必要时补充 `checkdeps` 或自定义 hook
6. 末尾 `dofile("../support/build-config.lua")`

例如 `ctex/build.lua` 还声明了：

- `packtdszip = true`
- `tdslocations` 覆盖 engine/fontset/heading/scheme 等安装路径
- `checkdeps = {"../xeCJK", "../zhnumber"}`
- `checkengines = {"pdftex", "xetex", "luatex", "uptex"}`
- `checkinit_hook()` 把依赖包安装文件复制到测试目录

见 `ctex/build.lua:1-71`。

`xeCJK/build.lua` 则在标准骨架之上增加 TECkit 映射生成逻辑，是“共享框架 + 包级特化”的典型例子。见 `xeCJK/build.lua:1-151`。

## 测试框架

## `.lvt` / `.tlg` 机制

回归测试主要使用 LaTeX3/l3build 的标准测试模型：

- `.lvt`：测试输入
- `.tlg`：期望日志输出
- 引擎差异时可使用 `name.<engine>.tlg`

`ctex/test/testfiles/` 仍是该仓库最完整的回归测试目录。测试文件使用 `\START`、`\END`、`\TEST{...}{...}` 之类标准测试宏组织案例；运行 `l3build check` 后会把实际日志与 `.tlg` 对比。若某引擎结果与标准引擎一致，`saveall()` 会清理重复的引擎专属 `.tlg`。

以下包接入了独立的 `testfiles/` 回归目录：

- `ctex`
- `xeCJK`
- `zhnumber`
- `CJKpunct`
- `zhlineskip`

这意味着这些子包已不再只依赖主包依赖链覆盖，修改它们时可以直接在各自目录运行 `l3build check`。

此外，现在还维护多个专项测试配置：

- `ctex/test/config-cmap.lua`：CMap 相关测试
- `ctex/test/config-contrib.lua`：contrib 目录相关测试
- `ctex/test/config-ctxdoc.lua`：`support/ctxdoc.cls` patch 健康检查，测试目录为 `ctex/test/testfiles-ctxdoc/`

其中 `config-ctxdoc` 使用 `testfiledir = "./test/testfiles-ctxdoc"`、`stdengine = "xetex"`、`checkengines = {"xetex"}`，并通过 `checksuppfiles = {"ctxdoc.cls"}` 把本地 `support/ctxdoc.cls` 复制到 check 目录，确保测试覆盖仓库中的当前实现，而不是系统安装版本。对应测试 `patch-health.lvt` 会先传入 `fontset=fandol` 以避免系统字体依赖，再加载 `ctxdoc` 验证全部 patch 在 nonstop 模式下也能以致命错误暴露失败。

## 引擎矩阵

`ctex` 的标准测试引擎是：

- `pdftex`
- `xetex`
- `luatex`
- `uptex`

其中 `stdengine = "xetex"`，见 `ctex/build.lua:44-53`。因此：

- XeTeX 结果是主基线
- 其他引擎只在确有差异时保留独立 `.tlg`

新增的卫星包测试矩阵如下：

- `xeCJK`：`testfiledir = "./testfiles"`、`stdengine = "xetex"`、`checkengines = {"xetex"}`，见 `xeCJK/build.lua`。现有回归已覆盖字体命令作用域、第三方包 hook、零宽格式字符过滤、`\lstinline` 在宏参数中的 `#` catcode 保持，以及 `\special`/颜色 whatsit 对 glue 恢复链的影响等 XeTeX 专属行为；例如 `xeCJK/testfiles/zwchars01.lvt` 用 6 个宽度对比用例验证 U+200B/U+200C/U+200D/U+2060/U+FEFF 不会打断字符分类，也不会额外插入 `CJKglue` / `CJKecglue`；`xeCJK/testfiles/color01.lvt` 则用 5 个盒子宽度对比用例验证 `\textcolor` 包裹 Default、单个 CJK、单个数字、混合 Latin 内容与嵌套颜色组时，Boundary→Default 和 Boundary→CJK 过渡中的 `CJKecglue` / `CJKglue` 都能在 whatsit 节点后被正确恢复。
- `zhnumber`：`testfiledir = "./testfiles"`、`stdengine = "xetex"`、`checkengines = {"pdftex", "xetex", "luatex"}`，见 `zhnumber/build.lua`。
- `CJKpunct`：`stdengine = "pdftex"`、`checkengines = {"pdftex"}`，见 `CJKpunct/build.lua`。CJKpunct 仅工作在 pdfTeX (CJK 宏包) 路线下。
- `zhlineskip`：`stdengine = "pdftex"`、`checkengines = {"pdftex"}`，见 `zhlineskip/build.lua`。zhlineskip 是独立 `.sty`（无 `.dtx` unpack），`unpackfiles = {}`。测试使用 vbox 尺寸捕获策略验证行距行为。

`zhnumber` 的 `pdftex` 输出与标准 XeTeX 基线存在差异，因此测试目录中保留了 `.pdftex.tlg` 专属基线，例如 `zhnumber/testfiles/basic01.pdftex.tlg`。

## 非典型测试模式

仓库中仍有一些老包或历史目录没有统一纳入 l3build 测试框架，但 `xeCJK` 已不再只是依赖 example 文档编译来验证功能。当前较新的独立回归测试覆盖面可以概括为：

- `ctex`：主干测试最完整，含多个测试配置。
- `xeCJK`：已有独立 `testfiles/`，专注 XeTeX 行为回归。
- `zhnumber`：已有独立 `testfiles/`，覆盖多引擎差异。

因此，修改 `xeCJK` 与 `zhnumber` 时，应优先运行各自目录下的标准 l3build 回归测试，而不是只依赖 `ctex` 的依赖链间接覆盖。

## CI/CD 配置

GitHub Actions 工作流当前至少包含两条主线：

- `.github/workflows/test.yml`：跨平台测试工作流
- `.github/workflows/release.yml`：按发布 tag 构建并创建 GitHub prerelease 的自动化工作流

### 测试工作流：`.github/workflows/test.yml`

当前稳定事实如下：

- 触发条件：`pull_request`、`push`、定时 `schedule`、`workflow_dispatch`
- 操作系统矩阵：`ubuntu-latest`、`macos-latest`、`windows-latest`
- TeX Live 安装：`TeX-Live/setup-texlive-action@v4`
- 依赖包清单：`.github/tl_packages`
- 当前 CI 在同一 job 中依次进入 `ctex/`、`xeCJK/`、`zhnumber/`、`CJKpunct/`、`zhlineskip/` 运行测试，而不再只停留在 `ctex/`

见 `.github/workflows/test.yml`。

#### CI 字体策略

当前 CI 已把“字体可用性”视为稳定基础设施，而不是临时环境细节。工作流中实际依赖的字体层次包括：

- `Source Han Serif` OTC：主 CJK 文档字体，供 xeCJK / 文档 driver 使用。
- `Noto Sans CJK` / `Noto Serif CJK` OTC：跨平台 CJK 基础字体。
- `HanaMinB`：作为 `SimSun-ExtB` 缺失时的 Ext-B fallback，覆盖扩展 B 区字符。
- `Noto Sans Symbols 2`：作为 `Segoe UI Symbol` 缺失时的符号字体 fallback。
- `FreeSerif`：通过 `apt install fonts-freefont-ttf` 提供，用于 `xunicode-symbols` 文档路径。
- `FandolSong` / `FandolFang`：由 TeX Live 自带，主要作为无需系统字体下载时的稳定后备。

Linux CI 在手工安装或解压字体后，必须执行 `fc-cache -f` 刷新 fontconfig 缓存；否则即使字体文件已落盘，XeTeX / fontspec 仍可能在同一 job 中看不到新字体。

这套策略对应最近文档驱动兼容性修复的两个关键约束：

- `xeCJK/xeCJK.dtx` driver 不再假定 CI 上一定存在 `SimSun-ExtB`，而是通过 `\IfFontExistsTF` 回退到 `HanaMinB`。
- `xunicode-symbols.tex` 不再假定 Windows 自带的 `Segoe UI Symbol`，而是条件化回退到 `Noto Sans Symbols 2`。

#### `.github/tl_packages` 维护约束

`.github/tl_packages` 是 CI 中 TeX Live 依赖的显式白名单。新增或扩展回归测试时，如果测试输入引入了新的 LaTeX 宏包依赖，必须同步更新这个文件；否则本地环境可能因为已有完整 TeX Live 而通过，但 GitHub Actions 会在精简安装环境里因缺包失败。

PR #799 暴露了一个稳定信号：`xeCJK/testfiles/listings-hash01.lvt` 新增 `\usepackage{listings}` 后，如果 `.github/tl_packages` 中未加入 `listings`，则 CI 会在 `-H`（halt-on-error）模式下于缺包处立即终止。此时生成的测试日志可能是空的 `.xetex.log`，后续表现为 `.tlg` 基线比对失败，但真正根因并不是输出差异，而是编译根本没有继续到产生日志内容的阶段。

因此，遇到“CI 中 `.log` 为空 / `.tlg` 比对失败，但本地看起来不像回归输出差异”的现象时，应优先检查两件事：

- 新增测试是否加载了 CI 尚未安装的宏包；
- `.github/tl_packages` 是否遗漏了相应依赖。

CI 中当前执行的测试步骤是：

- `Test ctex`：在 `./ctex` 运行
  - `l3build check -q`
  - `l3build check -c test/config-cmap -q`
  - `l3build check -c test/config-contrib -q`
  - `l3build check -c test/config-ctxdoc -q`
- `Test xeCJK`：在 `./xeCJK` 运行 `l3build check -q`
- `Test zhnumber`：在 `./zhnumber` 运行 `l3build check -q`
- `Test CJKpunct`：在 `./CJKpunct` 运行 `l3build check -q`
- `Test zhlineskip`：在 `./zhlineskip` 运行 `l3build check -q`

`Test xeCJK`、`Test zhnumber`、`Test CJKpunct` 都带有 `if: ${{ !cancelled() }}`，因此只要工作流未被取消，就会继续执行，不会因为前一个测试步骤失败而自动跳过。卫星包步骤还会在运行前检测 `testfiles` 目录或 `build.lua` 中的 `testfiledir` 配置；若未发现测试配置，则安全输出跳过信息，而不是直接失败。

失败时，artifact 上传范围也已扩展为：

- `ctex/build/**/*.diff`
- `xeCJK/build/**/*.diff`
- `zhnumber/build/**/*.diff`
- `CJKpunct/build/**/*.diff`
- `zhlineskip/build/**/*.diff`

另外，`ctex` 测试步骤的 step id 已由 `test` 调整为 `test-ctex`，以便与新增的 `test-xecjk`、`test-zhnumber`、`test-cjkpunct` 一起在后续 artifact 条件表达式中区分引用。

### Release 工作流：`.github/workflows/release.yml`

release 自动化只在以下 tag 推送时触发：

- `ctex-v*`
- `xeCJK-v*`
- `CJKpunct-v*`

工作流按 tag 前缀解析目标包，再依次完成：

- 安装 TeX Live
- 安装 `zhmakeindex`
- 安装 CJK 字体并在 Linux 上执行 `fc-cache -f`
- 针对 `xeCJK` 预下载 `support/Unihan.zip`
- 在目标子目录运行 `l3build ctan`
- 把 `<module>-ctan.zip` 改名为发布资产 `<module>-v<ver>.zip`
- 生成 release notes
- 在真正创建 release 前等待 `test.yml` 对同一 `head_sha` 成功
- 删除已存在的同名 release 并重建为 `prerelease`

门控机制的关键点是：构建、asset 准备与 notes 生成可以先完成，只有最后 `Create GitHub Release` 之前才轮询 `actions/workflows/test.yml/runs?head_sha=<sha>`，确认测试 CI 通过。这避免了在 release 任务最前面空等测试，同时保持发布出口受测试结果保护。

release notes 的稳定优先级是：

1. 优先从目标 `.dtx` 中提取 `\changes{v<ver>}{...}{...}` 条目；
2. 若不存在对应 `\changes`，则回退到上一版本 tag 与当前 tag 之间、限定到目标目录的 git log；
3. 若仍无内容，则写入最小占位说明。

因此，维护发布说明时，首选入口仍是各包 `.dtx` 中的 `\changes` 记录，而不是依赖提交历史临时拼装。

详见 `llmdoc/guides/release-workflow.md`。

## CTAN 发布流程

根级 `ctan.lua` 是统一发布入口。它定义了一个包数组，并对每个子目录执行：

- 切换到包目录
- 执行 `l3build ctan`
- 返回原目录

见 `ctan.lua:1-21`。

这意味着 CTAN 发布的稳定入口不是手工逐包记忆命令，而是：

- 先确认包是否在 `ctan.lua` 列表中
- 再由该脚本触发各包自己的 `build.lua` 打包逻辑

每个包是否生成 TDS zip、安装哪些文件、如何排版文档，最终仍由该包目录下的 `build.lua` 决定。

## 版本管理

## `.dtx` 内联版本信息

该仓库不依赖单独的 `CHANGELOG.md`。版本与变更信息主要嵌入 `.dtx`：

- 包头使用 `\ExplFileDate`、`\ExplFileVersion`
- 变更历史使用 `\changes{版本号}{日期}{说明}`

调查在 `ctex/ctex.dtx` 中确认了这套机制。文档排版时，这些信息会进入最终文档输出。

## Git 信息注入

发布/打包过程中，`support/build-config.lua` 会借助 git 历史展开 `\GetIdInfo`，把最近提交标识写入相应 `.id` 文件及输出产物。见 `support/build-config.lua:86-133`。

因此，修改版本相关内容时，要同时区分三件事：

- `.dtx` 中声明的公开版本号
- `\changes` 中的人类可读变更记录
- 打包阶段自动注入的 git 标识
