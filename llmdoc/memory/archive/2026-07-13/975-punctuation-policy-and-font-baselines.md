---
name: 975-punctuation-policy-and-font-baselines
description: 反思：#975 的方向性样式策略、专用字体回归、lazy font 预热和 changes 源码位置
type: reflection
---

# 975: 标点策略与字体基线

## 方向性策略不能绕过样式层

#488 表面上只需让 `FullLeft→FullRight` 不再压缩，但直接在 transition 中跳过 kern 会同时绕过 `banjiao`/自定义样式和 `\xeCJKsetkern`。最终把方向开关放入 `PunctStyle`，默认保持旧行为，仅由 `quanjiao` 关闭；实例必须在方向分支前载入，显式字符对设置和 `enabled-global-setting` 才能保持原有优先级。nobreak 留在 transition 中，与是否自动压缩正交。

## 字体相关标点修复需要专用字体面和多层证据

#481 不能只用 SC 字体配 `Language=` 验证，因为 `\XeTeXglyphbounds` 观察不到 GSUB 后字形。回归分别实例化 Noto Serif CJK TC 和 JP，并同时记录旧/新盒宽；PR 证据再配同条件前后截图。#443 也同时测句末和句内宽度，避免只证明一个字符变宽。

`fontspec` 对新字体族是按需初始化的。若首次使用发生在 `\START` 后，一次性 Info 会进入 l3build 日志；在 `\START` 前分别装盒预热所需字体族，可保留测试内容而消除环境相关基线噪声。

## 生成物顺序不能反向支配源码组织

`CHANGELOG.md` 由 `.dtx` 中的 `\changes` 确定性生成。自动审查曾建议把同一 issue 的三条记录集中以改善生成结果连续性，但这会让两条记录脱离对应实现。项目选择让 `\changes` 与 key、`quanjiao`、`kaiming` 定义相邻，接受生成 CHANGELOG 中条目不连续；生成文件继续由 `make changelog` 同步，不能手工重排。
