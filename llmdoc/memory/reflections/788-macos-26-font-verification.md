---
title: "788: macOS 26 CJK 字体验证"
type: reflection
---

# 788: macOS 26 CJK 字体验证

## 任务

针对 issue #788，验证 macOS 26.4.1 上 ctex/xeCJK 默认字体路径与可用性，重点确认 `fontset=mac` / LuaLaTeX 路线在新系统上的真实字体分布。

## 关键发现

### PingFang.ttc 已完全不可用

在 macOS 26 上，`PingFang.ttc` 不仅不在传统字体目录中，连 AssetsV2 中也不存在。这与早期 macOS 版本“系统字体可能迁移位置但仍可找到”的经验不同，意味着不能再把 PingFang 视为一个可通过路径探测补回的稳定候选。

### AssetsV2 目录编号从 Font7 变为 Font8

系统可下载字体资产目录的编号发生变化，从此前观察到的 `Font7` 迁移到 `Font8`。这再次说明：依赖硬编码 AssetsV2 子目录编号是脆弱的，只能作为临时调查线索，不能当成稳定实现假设。

### Kaiti / STFangsong 迁入 Font8

`Kaiti.ttc`、`STFangsong.ttf` 从 `/Library/Fonts/` 迁入 AssetsV2 的 `Font8` 目录。也就是说，部分中文字体并非“消失”，而是转入按需下载/资源资产路径管理。

## 对引擎行为的影响

### LuaLaTeX 可用字体进一步缩减

LuaLaTeX 对系统字体的可见集合进一步收缩。对于依赖文件系统路径扫描或 `luaotfload` 可见性的方案，新系统上可直接使用的中文字体比旧版 macOS 更少。

### XeLaTeX 可触发下载，但首次编译会失败

XeLaTeX 能触发 downloadable 字体的系统下载对话框，但首次编译仍会失败。这意味着“能弹出下载提示”不等于“本次编译可成功完成”；自动化测试与用户文档都不能把它当成成功路径。

## 经验

- **macOS 字体问题要同时区分“存在”“可见”“可即时编译”三件事**：文件存在不代表 LuaLaTeX 可见；能触发下载也不代表 XeLaTeX 首次编译成功。
- **不要把 AssetsV2 内部编号当稳定接口**：`Font7` 到 `Font8` 的变化表明该编号随系统版本可变。
- **PingFang 缺失是比“路径迁移”更强的信号**：相关字体策略需要改为基于实测可用集，而不是继续追踪旧路径。
- **macOS 新版本验证需要单独记录**：这类系统级变化不会从源码中显现，但会直接影响 fontset 默认值与用户支持判断。
