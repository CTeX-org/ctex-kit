# CTeX-kit

[![ctex-kit test](https://github.com/CTeX-org/ctex-kit/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/CTeX-org/ctex-kit/actions/workflows/test.yml?query=branch%3Amaster)

English | [简体中文](README.md)

CTeX-kit is a collection of TeX/LaTeX macro packages, scripts, and resources for Chinese typesetting. Maintained by the [CTeX community](http://www.ctex.org), it brings together `ctex`, `xeCJK`, `zhspacing`, and other components to provide unified, reliable Chinese typesetting infrastructure across different TeX engines.

## Core Packages

| Package | CTAN Version | Description |
| ------- | ------------ | ----------- |
| [ctex](https://ctan.org/pkg/ctex) | [![CTAN](https://img.shields.io/ctan/v/ctex.svg)](https://ctan.org/pkg/ctex) | Chinese document classes and package bundle — font configuration, heading schemes, and multi-engine adaptation |
| [xeCJK](https://ctan.org/pkg/xecjk) | [![CTAN](https://img.shields.io/ctan/v/xecjk.svg)](https://ctan.org/pkg/xecjk) | CJK font management, character spacing, and punctuation kerning for XeLaTeX |

## Satellite Packages

| Package | CTAN Version | Description |
| ------- | ------------ | ----------- |
| [CJKpunct](https://ctan.org/pkg/cjkpunct) | [![CTAN](https://img.shields.io/ctan/v/cjkpunct.svg)](https://ctan.org/pkg/cjkpunct) | CJK punctuation kerning and spacing |
| [xCJK2uni](https://ctan.org/pkg/xcjk2uni) | [![CTAN](https://img.shields.io/ctan/v/xcjk2uni.svg)](https://ctan.org/pkg/xcjk2uni) | Legacy CJK encoding to Unicode mapping |
| [xpinyin](https://ctan.org/pkg/xpinyin) | [![CTAN](https://img.shields.io/ctan/v/xpinyin.svg)](https://ctan.org/pkg/xpinyin) | Automatic pinyin annotation for Chinese characters |
| [zhnumber](https://ctan.org/pkg/zhnumber) | [![CTAN](https://img.shields.io/ctan/v/zhnumber.svg)](https://ctan.org/pkg/zhnumber) | Chinese number and date formatting |
| [zhlineskip](https://ctan.org/pkg/zhlineskip) | [![CTAN](https://img.shields.io/ctan/v/zhlineskip.svg)](https://ctan.org/pkg/zhlineskip) | Automatic line spacing adjustment for CJK–Latin mixed text |
| [zhspacing](https://ctan.org/pkg/zhspacing) | [![CTAN](https://img.shields.io/ctan/v/zhspacing.svg)](https://ctan.org/pkg/zhspacing) | Automatic CJK–Latin inter-character spacing (LuaTeX approach) |
| [zhmetrics](https://ctan.org/pkg/zhmetrics) | [![CTAN](https://img.shields.io/ctan/v/zhmetrics.svg)](https://ctan.org/pkg/zhmetrics) | Chinese font metrics |
| [zhmetrics-uptex](https://ctan.org/pkg/zhmetrics-uptex) | [![CTAN](https://img.shields.io/ctan/v/zhmetrics-uptex.svg)](https://ctan.org/pkg/zhmetrics-uptex) | Chinese font metrics for upTeX |

## Quick Start

### Installation

All packages are included in [TeX Live](https://www.tug.org/texlive/) and [MiKTeX](https://miktex.org/) — no manual installation is needed. To use the development version, clone this repository directly.

### Basic Usage

Using the `ctexart` document class:

```latex
\documentclass{ctexart}
\begin{document}
你好，\LaTeX{}！
\end{document}
```

Using the `ctex` package with a standard document class:

```latex
\documentclass{article}
\usepackage{ctex}
\begin{document}
你好，\LaTeX{}！
\end{document}
```

Supported engines: XeLaTeX, LuaLaTeX, pdfLaTeX (with CJK package), and upLaTeX. XeLaTeX or LuaLaTeX is recommended for the best experience.

## Repository Structure

```
ctex-kit/
├── ctex/              # Core: Chinese document classes and packages
├── xeCJK/             # Core: XeLaTeX CJK support
├── CJKpunct/          # CJK punctuation kerning
├── xCJK2uni/          # CJK encoding conversion
├── xpinyin/           # Pinyin annotation
├── zhnumber/          # Chinese numbers
├── zhlineskip/        # Line spacing adjustment
├── zhspacing/         # CJK–Latin spacing
├── zhmetrics/         # Font metrics
├── zhmetrics-uptex/   # upTeX font metrics
├── jiazhu/            # Interlinear annotation (jiazhu)
├── gbk2uni/           # GBK→Unicode conversion tool
├── gbkmac/            # GBK encoding support (macOS)
├── zh-luatex/         # LuaTeX Chinese experimental support
├── support/           # Shared build configuration and support files
└── .github/           # CI/CD configuration
```

## Building and Testing

This project uses [l3build](https://ctan.org/pkg/l3build) as its build and test framework.

```bash
# Run ctex test suite
cd ctex
l3build check

# Run xeCJK test suite
cd xeCJK
l3build check

# Build CTAN release package
l3build ctan
```

CI tests against the current TeX Live release on Ubuntu, macOS, and Windows, covering five test suites: `ctex`, `xeCJK`, `zhnumber`, `CJKpunct`, and `zhlineskip`.

## Technology Stack

- **Programming framework**: LaTeX3 / expl3
- **Literate programming**: docstrip (`.dtx` source files)
- **Build system**: l3build
- **CI/CD**: GitHub Actions (testing + automated releases)

## Contributing

Bug reports via [Issues](https://github.com/CTeX-org/ctex-kit/issues) and code contributions via [Pull Requests](https://github.com/CTeX-org/ctex-kit/pulls) are welcome.

Before submitting code, please ensure:

1. All relevant tests pass (`l3build check`)
2. Code follows expl3 conventions
3. Changes to `.dtx` files include `\changes` entries
4. After editing `\changes`, regenerate the package's `CHANGELOG.md` with `make changelog` (or `cd <pkg> && python3 ../scripts/extract-changes.py "*.dtx" all -o CHANGELOG.md`) and commit it together; without a local Python, copy the expected content from the failed check-changelog CI log

## Sponsoring

The repository's CI runs a set of agentic automation workflows (automated PR review, llmdoc documentation updates, and periodic patrol), which incur ongoing LLM API token costs. We accept donations via [Open Collective](https://opencollective.com/ctex-kit), earmarked for these API bills. Funds are held by our fiscal host, Open Source Collective, with a fully transparent public ledger — they never pass through any maintainer's personal account.

## Related Links

- [CTeX Community](http://www.ctex.org)
- [CTAN ctex package page](https://ctan.org/pkg/ctex)
- [LaTeX3 Project](https://www.latex-project.org/latex3/)
- [l3build documentation](https://ctan.org/pkg/l3build)

## License

Packages in this project are released under the [LPPL v1.3c](https://www.latex-project.org/lppl/lppl-1-3c/) (LaTeX Project Public License).

---

Copyright &copy; 2003&ndash;2026 [CTeX Community](http://www.ctex.org)
