# 决策: hyperref driverfallback 按加载状态分支处理 (#715)

## 问题

`ctex` 通过 `\ctex_hypersetup:n` 统一设置 hyperref 选项。当 hyperref 在 ctex 之前被加载（如 beamer 内部加载），`\ctex_hypersetup:n` 变成 `\hypersetup`。但 `driverfallback` 是 hyperref 的加载选项（load-time option），加载后被 `\Hy@DisableOption` 禁用，通过 `\hypersetup` 设置会触发警告。

## 决策

不修改 `\ctex_hypersetup:n` 的通用机制，而是在使用 `driverfallback` 的两处调用点（pdftex 和 uptex/aptex 引擎文件）单独处理：

- hyperref 未加载：`\PassOptionsToPackage { driverfallback = dvipdfmx } { hyperref }`
- hyperref 已加载：跳过 `driverfallback`，仅设置其他运行时选项

## 理由

1. `driverfallback` 是 hyperref 中少数"加载后不可设"的选项，不值得为此改变 `\ctex_hypersetup:n` 的通用设计
2. 现代 hyperref 的驱动自动检测已足够可靠，跳过 `driverfallback` 在实际场景中不会造成功能问题
3. 只有两处使用 `driverfallback`（pdftex 和 uptex/aptex），改动范围可控

## 影响

- beamer + ctex 等场景不再产生无害警告
- 极端情况下（pdfTeX DVI 模式 + hyperref 自动检测失败），可能缺少 dvipdfmx fallback，但这在现代 TeX Live 中几乎不会发生
