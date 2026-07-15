# CTeX-kit

[![ctex-kit test](https://github.com/CTeX-org/ctex-kit/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/CTeX-org/ctex-kit/actions/workflows/test.yml?query=branch%3Amaster)

[English](README-en.md) | 简体中文

CTeX-kit 是面向中文 TeX 用户的宏包、脚本与资源集合，为中文 LaTeX 工作流提供完整的排版基础设施。项目由 [CTeX 社区](http://www.ctex.org) 维护，汇集了 `ctex`、`xeCJK`、`zhspacing` 等多条技术路线的成果，目标是在不同 TeX 引擎下提供统一、可靠的中文排版支持。

## 核心宏包

| 宏包 | CTAN 版本 | 说明 |
| ---- | --------- | ---- |
| [ctex](https://ctan.org/pkg/ctex) | [![CTAN](https://img.shields.io/ctan/v/ctex.svg)](https://ctan.org/pkg/ctex) | 中文文档类与宏包集合，统一封装字体配置、标题方案和多引擎适配 |
| [xeCJK](https://ctan.org/pkg/xecjk) | [![CTAN](https://img.shields.io/ctan/v/xecjk.svg)](https://ctan.org/pkg/xecjk) | XeLaTeX 下的 CJK 字体管理、字间距和标点压缩 |

## 卫星宏包

| 宏包 | CTAN 版本 | 说明 |
| ---- | --------- | ---- |
| [CJKpunct](https://ctan.org/pkg/cjkpunct) | [![CTAN](https://img.shields.io/ctan/v/cjkpunct.svg)](https://ctan.org/pkg/cjkpunct) | CJK 标点压缩与间距调整 |
| [xCJK2uni](https://ctan.org/pkg/xcjk2uni) | [![CTAN](https://img.shields.io/ctan/v/xcjk2uni.svg)](https://ctan.org/pkg/xcjk2uni) | 传统 CJK 编码到 Unicode 的映射 |
| [xpinyin](https://ctan.org/pkg/xpinyin) | [![CTAN](https://img.shields.io/ctan/v/xpinyin.svg)](https://ctan.org/pkg/xpinyin) | 为汉字自动添加拼音注音 |
| [zhnumber](https://ctan.org/pkg/zhnumber) | [![CTAN](https://img.shields.io/ctan/v/zhnumber.svg)](https://ctan.org/pkg/zhnumber) | 中文数字与日期格式化 |
| [zhlineskip](https://ctan.org/pkg/zhlineskip) | [![CTAN](https://img.shields.io/ctan/v/zhlineskip.svg)](https://ctan.org/pkg/zhlineskip) | 中西文混排行距自动调整 |
| [zhspacing](https://ctan.org/pkg/zhspacing) | [![CTAN](https://img.shields.io/ctan/v/zhspacing.svg)](https://ctan.org/pkg/zhspacing) | 中西文间距自动插入（LuaTeX 路线） |
| [zhmetrics](https://ctan.org/pkg/zhmetrics) | [![CTAN](https://img.shields.io/ctan/v/zhmetrics.svg)](https://ctan.org/pkg/zhmetrics) | 中文字体度量文件 |
| [zhmetrics-uptex](https://ctan.org/pkg/zhmetrics-uptex) | [![CTAN](https://img.shields.io/ctan/v/zhmetrics-uptex.svg)](https://ctan.org/pkg/zhmetrics-uptex) | upTeX 中文字体度量 |

## 快速开始

### 安装

所有宏包均已收录于 [TeX Live](https://www.tug.org/texlive/) 和 [MiKTeX](https://miktex.org/)，通常无需手动安装。如需使用开发版本，请直接克隆本仓库。

### 基本用法

使用 `ctexart` 文档类：

```latex
\documentclass{ctexart}
\begin{document}
你好，\LaTeX{}！
\end{document}
```

使用 `ctex` 宏包配合标准文档类：

```latex
\documentclass{article}
\usepackage{ctex}
\begin{document}
你好，\LaTeX{}！
\end{document}
```

支持的编译引擎：XeLaTeX、LuaLaTeX、pdfLaTeX（搭配 CJK 宏包）和 upLaTeX。推荐使用 XeLaTeX 或 LuaLaTeX 以获得最佳体验。

## 仓库结构

```
ctex-kit/
├── ctex/              # 核心：中文文档类与宏包
├── xeCJK/             # 核心：XeLaTeX CJK 支持
├── CJKpunct/          # CJK 标点压缩
├── xCJK2uni/          # CJK 编码转换
├── xpinyin/           # 拼音注音
├── zhnumber/          # 中文数字
├── zhlineskip/        # 行距调整
├── zhspacing/         # 中西文间距
├── zhmetrics/         # 字体度量
├── zhmetrics-uptex/   # upTeX 字体度量
├── jiazhu/            # 夹注排版
├── gbk2uni/           # GBK→Unicode 转换工具
├── gbkmac/            # GBK 编码支持（macOS）
├── zh-luatex/         # LuaTeX 中文实验支持
├── support/           # 共享构建配置与辅助文件
└── .github/           # CI/CD 配置
```

## 构建与测试

本项目使用 [l3build](https://ctan.org/pkg/l3build) 作为构建和测试框架。

```bash
# 运行 ctex 测试套件
cd ctex
l3build check

# 运行 xeCJK 测试套件
cd xeCJK
l3build check

# 生成 CTAN 发布包
l3build ctan
```

CI 在 Ubuntu、macOS 和 Windows 三个平台上针对当前 TeX Live 发行版进行测试，覆盖 `ctex`、`xeCJK`、`zhnumber`、`CJKpunct` 和 `zhlineskip` 五个测试套件。

## 技术栈

- **编程框架**：LaTeX3 / expl3
- **文学化编程**：docstrip (`.dtx` 源文件)
- **构建系统**：l3build
- **CI/CD**：GitHub Actions（测试 + 自动化发布）

## 参与贡献

欢迎通过 [Issue](https://github.com/CTeX-org/ctex-kit/issues) 报告问题，或提交 [Pull Request](https://github.com/CTeX-org/ctex-kit/pulls) 参与开发。

在提交代码前，请确保：

1. 相关测试通过 (`l3build check`)
2. 遵循 expl3 编程规范
3. 对于 `.dtx` 文件的修改，请在 `\changes` 中记录变更
4. 修改 `\changes` 后，运行 `make changelog`（或 `cd <pkg> && python3 ../scripts/extract-changes.py "*.dtx" all -o CHANGELOG.md`）重新生成对应包的 `CHANGELOG.md` 并一并提交；本地没有 Python 时，可直接从 CI（check-changelog）失败日志中复制期望内容

## 赞助

仓库的 CI 运行着一组 agentic 自动化工作流（PR 自动审查、llmdoc 文档自动更新、定期巡查），它们调用 LLM API 会产生持续的 token 费用。我们通过 [Open Collective](https://opencollective.com/ctex-kit) 接受捐赠，专项用于支付这些 API 账单。资金由财政托管方 Open Source Collective 持有，收支账本公开透明，不经过任何维护者的个人账户。

## 相关链接

- [CTeX 社区](http://www.ctex.org)
- [CTAN ctex 包页面](https://ctan.org/pkg/ctex)
- [LaTeX3 项目](https://www.latex-project.org/latex3/)
- [l3build 文档](https://ctan.org/pkg/l3build)

## 许可证

本项目中各宏包遵循 [LPPL v1.3c](https://www.latex-project.org/lppl/lppl-1-3c/) (LaTeX Project Public License) 发布。

---

Copyright &copy; 2003&ndash;2026 [CTeX 社区](http://www.ctex.org)
