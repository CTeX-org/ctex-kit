## [zhnumber-v3.1](https://github.com/CTeX-org/ctex-kit/releases/tag/zhnumber-v3.1)

- 提升 LaTeX3 最低版本要求至 2025/10/09。
- 支持仅输出年或年月。
- 改用 `\keys_set_exclude_groups:nnnN` 代替已弃用的 `\keys_set_filter:nnnN`，避免 l3kernel 2026-09-09 起在调试模式下报错（#1095）。
