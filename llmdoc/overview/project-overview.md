# 项目概述

## 项目是什么

`ctex-kit` 是面向中文 TeX/LaTeX/ConTeXt 用户的宏包、脚本与资源集合，重点服务中文排版，尤其是中文 LaTeX 工作流。仓库由 CTeX 社区维护，汇集了 `ctex`、`xeCJK`、`zhspacing`、LuaTeX 中文支持等多条历史与现代路线的成果，目标是为不同 TeX 引擎提供可用的中文排版基础设施。参见 `README.md:2-9`。

## 仓库组织

该仓库是一个 monorepo，顶层包含 16 个宏包/工具目录：`CJKpunct`、`ctex`、`gbk2uni`、`gbkmac`、`jiazhu`、`xCJK2uni`、`xeCJK`、`xpinyin`、`zh-luatex`、`zhlineskip`、`zhmetrics`、`zhmetrics-uptex`、`zhnumber`、`zhspacing`、`support`、`templates`。此外还有 `.github`（CI 配置）、`ctan.lua`（发布脚本）和 `llmdoc/`（项目文档）等基础设施。

## 核心包与卫星包

### 核心包

- `ctex/`：项目主入口与统一中文文档类/宏包集合，负责把标准 LaTeX 类、中文标题方案、字体集和不同引擎适配层组合起来。#937 后源码按职责拆为 `ctex.dtx`、`ctex-kernel.dtx`、`ctex-auxpkg.dtx`、`ctex-engine.dtx`、`ctex-scheme.dtx`、`ctex-fontset.dtx` 六个文件。
- `xeCJK/`：XeTeX/XeLaTeX 下的中文字体、间距、标点压缩和扩展环境支持，核心源码集中在 `xeCJK/xeCJK.dtx`。

### 卫星包与工具

- 传统 CJK 路线增强：`CJKpunct/`、`xCJK2uni/`、`gbkmac/`、`gbk2uni/`。
- 中文数字、拼音与注释类功能：`zhnumber/`、`xpinyin/`、`jiazhu/`。
- 行距、间距与引擎特化支持：`zhlineskip/`、`zhspacing/`、`zh-luatex/`。
- 中文字体度量与字库支撑：`zhmetrics/`、`zhmetrics-uptex/`。
- 模板与示例：`templates/`。

根级 `ctan.lua` 已被删除，CTAN 发布现已完全由 `.github/workflows/release.yml` 自动化驱动，覆盖全部 9 个 CTAN 发布单元：`CJKpunct`、`ctex`、`xCJK2uni`、`xeCJK`、`xpinyin`、`zhmetrics`、`zhmetrics-uptex`、`zhnumber`、`zhspacing`。这说明仓库中的目录并不等价于 CTAN 发布单元：有些目录是基础设施或历史组件，有些是未纳入统一发布脚本的辅助包。

## 技术栈

### LaTeX3 / expl3

主干代码广泛采用 expl3 命名和编程模型，典型命名空间包括 `\ctex_`、`\xeCJK_`、`\CJKtu_` 与私有的 `\@@_`。与此同时，`ctex` 仍保留部分 `\CTEX@...` 的 LaTeX2e 遗留接口以兼容旧层。相关约定见 `ctex/ctex-kernel.dtx`、`ctex/ctex-engine.dtx`、`xeCJK/xeCJK.dtx`、`xCJK2uni/xCJK2uni.dtx`。

### docstrip / `.dtx`

核心包以单体或少量 `.dtx` 文学化源码为中心，通过 docstrip 标签拆出 `.sty`、`.cls`、`.def`、示例和文档。`xeCJK/xeCJK.dtx` 仍是单体主源；`ctex/` 则由上述六个 `.dtx` 协同生成同一组产物。

### l3build

多数现代子包以 `build.lua` 驱动 `l3build` 完成解包、构建、测试和 CTAN 打包，并共享 `support/build-config.lua` 中的项目级覆写与钩子。见 `ctex/build.lua:1-72`、`xeCJK/build.lua:1-179`、`support/build-config.lua:1-215`。

## 维护状态

仓库处于持续维护状态：

- 根级 `README.md` 展示了多个 CTAN 包版本徽章与 GitHub Actions 构建状态，见 `README.md:13-49`。
- `.github/workflows/test.yml` 配置了 Ubuntu、macOS、Windows 三平台 CI，按 push、pull request、schedule 与手动触发执行，见 `.github/workflows/test.yml`。
- 当前自动化测试已不再只聚焦 `ctex/`：CI 会分别运行 `ctex/`、`xeCJK/`、`xpinyin/`、`zhnumber/`、`CJKpunct/` 与 `zhlineskip/` 的 `l3build check`。`xpinyin/` 自 #1041 起接入，覆盖 XeTeX/xeCJK 与 CJKutf8/pdfTeX 两条互不复用的适配路线，此前该包只靠 `l3build doc` 编得过手册来间接验证。这表明仓库的测试维护已从“核心包主导、卫星包间接覆盖”进一步演进为“核心包 + 多个关键卫星包独立回归”。
- 仓库现已新增 `.github/workflows/release.yml`，可对全部 9 个 CTAN 发布单元的 tag 自动执行打包、release notes 生成、测试门控和 GitHub prerelease 创建，实现了完整的自动化发布覆盖。
- 仓库本地维护三条 agentic 自动化入口及其运行时：PR 自动审查（`agentic-pr-review.yml`）、新 Issue 分派（`agentic-issue-dispatch.yml`）和 llmdoc 文档自动更新（`agentic-llmdoc-updater.yml`）。三条 workflow 不再调用远端 reusable workflow。#1032 起，六个 Codex／Claude Agent job 以 runner 默认用户运行、拥有完整本地执行权限（Codex 用 `--dangerously-bypass-approvals-and-sandbox`，Claude 用 `--dangerously-skip-permissions`），与上游模板 `agentic-workflow-template` 一致；工具安装改为单个 shell 脚本 `setup-agent-tools.sh`（不再是复合 Action），由各 job 以普通 step 调用，缓存仍在 workflow 里只恢复不保存。约束 Agent 影响面的是权限边界而非进程沙箱：Agent job 只持有只读 `GITHUB_TOKEN`，外部写入集中在不运行 Agent、也不接收模型 API key 的发布 job（publisher）；PR Review 的可信运行时来自 base SHA，被审查的 head checkout 只作为数据；Claude 保留 `--bare` 避免被审查仓库注入项目指令。已接受的风险是模型 API key 重新暴露给 Agent 进程可执行的仓库代码，判断依据是当前贡献者均为仓库协作者、跨仓库 PR 为零，且此前的三层隔离（专用用户、模型代理、控制进程加固）是三次连环故障的唯一来源；详见决策 [[1032-agent-runtime-simplification]]。`agentic-workflow-template` 的固定提交只作为最初展开的来源基线。
- CI 与文档构建现在明确依赖一组可在流水线中安装的 CJK / 符号字体，而不再隐含依赖 Windows 自带字体；这反映出项目维护已把“跨平台字体可达性”上升为稳定基础设施约束。
- 仍然不是每个卫星包都在 CI 中独立跑一遍；修改未接入测试框架的历史包时，仍要额外关注其本地构建与验证可达性。
