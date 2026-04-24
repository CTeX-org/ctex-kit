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

现在除 `ctex` 外，`xeCJK/` 与 `zhnumber/` 也已经接入独立的 `testfiles/` 回归目录：

- `xeCJK/testfiles/`：`basic01`、`punctstyle01`、`fonts01`
- `zhnumber/testfiles/`：`basic01`、`style01`、`deprecation01`

这意味着这两个子包已不再只依赖主包依赖链覆盖，修改它们时可以直接在各自目录运行 `l3build check`。

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

- `xeCJK`：`testfiledir = "./testfiles"`、`stdengine = "xetex"`、`checkengines = {"xetex"}`，见 `xeCJK/build.lua`。
- `zhnumber`：`testfiledir = "./testfiles"`、`stdengine = "xetex"`、`checkengines = {"pdftex", "xetex", "luatex"}`，见 `zhnumber/build.lua`。

`zhnumber` 的 `pdftex` 输出与标准 XeTeX 基线存在差异，因此测试目录中保留了 `.pdftex.tlg` 专属基线，例如 `zhnumber/testfiles/basic01.pdftex.tlg`。

## 非典型测试模式

仓库中仍有一些老包或历史目录没有统一纳入 l3build 测试框架，但 `xeCJK` 已不再只是依赖 example 文档编译来验证功能。当前较新的独立回归测试覆盖面可以概括为：

- `ctex`：主干测试最完整，含多个测试配置。
- `xeCJK`：已有独立 `testfiles/`，专注 XeTeX 行为回归。
- `zhnumber`：已有独立 `testfiles/`，覆盖多引擎差异。

因此，修改 `xeCJK` 与 `zhnumber` 时，应优先运行各自目录下的标准 l3build 回归测试，而不是只依赖 `ctex` 的依赖链间接覆盖。

## CI/CD 配置

GitHub Actions 工作流位于 `.github/workflows/test.yml`。当前稳定事实如下：

- 触发条件：`pull_request`、`push`、定时 `schedule`、`workflow_dispatch`
- 操作系统矩阵：`ubuntu-latest`、`macos-latest`、`windows-latest`
- TeX Live 安装：`TeX-Live/setup-texlive-action@v4`
- 依赖包清单：`.github/tl_packages`
- 字体准备：下载 Noto Sans/Serif CJK OTC 并解压到系统字体目录
- 当前 CI 在同一 job 中依次进入 `ctex/`、`xeCJK/`、`zhnumber/` 运行测试，而不再只停留在 `ctex/`

见 `.github/workflows/test.yml`。

CI 中当前执行的测试步骤是：

- `Test ctex`：在 `./ctex` 运行
  - `l3build check -q`
  - `l3build check -c test/config-cmap -q`
  - `l3build check -c test/config-contrib -q`
- `Test xeCJK`：在 `./xeCJK` 运行 `l3build check -q`
- `Test zhnumber`：在 `./zhnumber` 运行 `l3build check -q`

`Test xeCJK` 与 `Test zhnumber` 都带有 `if: ${{ !cancelled() }}`，因此只要工作流未被取消，就会继续执行，不会因为前一个测试步骤失败而自动跳过。两个卫星包步骤还会在运行前检测 `testfiles` 目录或 `build.lua` 中的 `testfiledir` 配置；若未发现测试配置，则安全输出跳过信息，而不是直接失败。

失败时，artifact 上传范围也已扩展为：

- `ctex/build/**/*.diff`
- `xeCJK/build/**/*.diff`
- `zhnumber/build/**/*.diff`

另外，`ctex` 测试步骤的 step id 已由 `test` 调整为 `test-ctex`，以便与新增的 `test-xecjk`、`test-zhnumber` 一起在后续 artifact 条件表达式中区分引用。


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
