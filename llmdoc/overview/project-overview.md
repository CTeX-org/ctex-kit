# 项目概述

## 项目是什么

`ctex-kit` 是面向中文 TeX/LaTeX/ConTeXt 用户的宏包、脚本与资源集合，重点服务中文排版，尤其是中文 LaTeX 工作流。仓库由 CTeX 社区维护，汇集了 `ctex`、`xeCJK`、`zhspacing`、LuaTeX 中文支持等多条历史与现代路线的成果，目标是为不同 TeX 引擎提供可用的中文排版基础设施。参见 `README.md:2-9`。

## 仓库组织

该仓库是一个 monorepo，顶层包含 16 个宏包/工具目录：`CJKpunct`、`ctex`、`gbk2uni`、`gbkmac`、`jiazhu`、`xCJK2uni`、`xeCJK`、`xpinyin`、`zh-luatex`、`zhlineskip`、`zhmetrics`、`zhmetrics-uptex`、`zhnumber`、`zhspacing`、`support`、`templates`。此外还有 `.github`（CI 配置）、`ctan.lua`（发布脚本）和 `llmdoc/`（项目文档）等基础设施。

## 核心包与卫星包

### 核心包

- `ctex/`：项目主入口与统一中文文档类/宏包集合，负责把标准 LaTeX 类、中文标题方案、字体集和不同引擎适配层组合起来。核心源码集中在 `ctex/ctex.dtx`。
- `xeCJK/`：XeTeX/XeLaTeX 下的中文字体、间距、标点压缩和扩展环境支持，核心源码集中在 `xeCJK/xeCJK.dtx`。

### 卫星包与工具

- 传统 CJK 路线增强：`CJKpunct/`、`xCJK2uni/`、`gbkmac/`、`gbk2uni/`。
- 中文数字、拼音与注释类功能：`zhnumber/`、`xpinyin/`、`jiazhu/`。
- 行距、间距与引擎特化支持：`zhlineskip/`、`zhspacing/`、`zh-luatex/`。
- 中文字体度量与字库支撑：`zhmetrics/`、`zhmetrics-uptex/`。
- 模板与示例：`templates/`。

根级 `ctan.lua` 当前把 9 个主要 CTAN 发布目标纳入统一打包循环：`CJKpunct`、`ctex`、`xCJK2uni`、`xeCJK`、`xpinyin`、`zhmetrics`、`zhmetrics-uptex`、`zhnumber`、`zhspacing`，见 `ctan.lua:3-21`。这说明仓库中的目录并不等价于 CTAN 发布单元：有些目录是基础设施或历史组件，有些是未纳入统一发布脚本的辅助包。

## 技术栈

### LaTeX3 / expl3

主干代码广泛采用 expl3 命名和编程模型，典型命名空间包括 `\ctex_`、`\xeCJK_`、`\CJKtu_` 与私有的 `\@@_`。与此同时，`ctex` 仍保留部分 `\CTEX@...` 的 LaTeX2e 遗留接口以兼容旧层。相关约定见 `ctex/ctex.dtx`、`xeCJK/xeCJK.dtx`、`xCJK2uni/xCJK2uni.dtx`。

### docstrip / `.dtx`

核心包多数以单体或少量 `.dtx` 文学化源码为中心，通过 docstrip 标签拆出 `.sty`、`.cls`、`.def`、示例和文档。`ctex/ctex.dtx` 和 `xeCJK/xeCJK.dtx` 是两个最重要的单体源文件。

### l3build

多数现代子包以 `build.lua` 驱动 `l3build` 完成解包、构建、测试和 CTAN 打包，并共享 `support/build-config.lua` 中的项目级覆写与钩子。见 `ctex/build.lua:1-71`、`xeCJK/build.lua:1-151`、`support/build-config.lua:1-234`。

## 维护状态

仓库处于持续维护状态：

- 根级 `README.md` 展示了多个 CTAN 包版本徽章与 GitHub Actions 构建状态，见 `README.md:13-49`。
- `.github/workflows/test.yml` 配置了 Ubuntu、macOS、Windows 三平台 CI，按 push、pull request、schedule 与手动触发执行，见 `.github/workflows/test.yml`。
- 当前自动化测试已不再只聚焦 `ctex/`：CI 会在同一 job 中分别运行 `ctex/`、`xeCJK/` 与 `zhnumber/` 的 `l3build check`，其中 `xeCJK` 与 `zhnumber` 已拥有各自的 `testfiles/` 回归目录。这表明仓库的测试维护正从“核心包主导、卫星包间接覆盖”逐步演进为“核心包 + 关键卫星包独立回归”。
- 仍然不是每个卫星包都在 CI 中独立跑一遍；修改未接入测试框架的历史包时，仍要额外关注其本地构建与验证可达性。
