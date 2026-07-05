---
name: "382-dash-width-and-ligature-opt-in"
description: "决策: #382 破折号宽度修正分两阶段落地——公式修正（三路取大 kern + margin 全份补偿）默认生效, OpenType 合字支持通过 PoZheHao 字符类 opt-in; margin 选择不除以 2 而非改变目标宽度基准; 合字选择用户显式开关而非自动探测字体特性"
metadata:
  type: decision
---

# 决策：#382 破折号宽度分两阶段修复，合字支持 opt-in

## 背景

Issue #382：xeCJK 中连续使用的破折号（U+2014）总宽不符合 CLReq（《中文排版需求》）要求——n 个连用应占 n 个汉字宽，但原压缩公式只保证"中间连续无缝"，不保证总宽不变量。同时部分 OpenType 字体（思源宋体/黑体等）提供破折号合字特性，但 xeCJK 的 interchar 标点处理机制会在字符间注入内容，阻断合字触发。

## 决策 1：两阶段方案，公式修正默认生效，合字支持 opt-in

不做成单一修复，拆分为：

- **阶段 1**（默认生效，无需用户配置）：修正 `\@@_long_punct_kerning:N` 的中间压缩公式与 `\xeCJK_punct_margin_process:NN` 的两端补偿逻辑，让"未合字"场景下的破折号宽度更接近 CLReq 要求。
- **阶段 2**（opt-in，`\xeCJKsetup{PoZheHaoLigature}`）：新增 `PoZheHao` 零注入字符类，让支持合字的字体能触发 OpenType 破折号合字。

**理由**：阶段 1 的公式修正对所有用户都是纯粹的宽度精度改进，没有副作用，理应默认生效。阶段 2 涉及字体特性依赖（见决策 3），不能默认开启。两阶段互不阻塞——即使用户不使用支持合字的字体，阶段 1 依然改善了破折号宽度的准确性。

## 决策 2：margin 补偿改为"不除以 2"，而非改变目标宽度基准

`\xeCJK_punct_margin_process:NN` 原公式两端各补偿 `(目标宽 - dimen) / 2`。备选方案是保持除以 2 的结构，转而调高"目标宽"这个基准量（例如把破折号的目标宽度基准从 1 字宽上调）。

**采纳方案**：保留原目标宽度基准不变，新增条件 `\@@_punct_if_full_margin_dash:N`（U+2014 且未启用合字），命中时两端补偿改为各一整份（不除以 2）。

**理由**：

- 连用破折号中间被 `\@@_long_punct_kerning:N` 挤掉的空白，其数量级恰好等于单个字符两端总空白（一整份），而不是半份——这是由压缩公式的三路取大结构直接推导出的关系，不是任意选择的系数。
- 改"目标宽度基准"会牵动所有引用该基准的下游计算（包括非破折号的其他 `MiddlePunct` 字符共用的默认基准逻辑），影响面不可控；新增一个只对 U+2014 生效的专用条件，影响面精确限定在破折号这一个字符上。
- 该条件同时套用在两处调用点（`xeCJK_punct_margin_process:NN` 内部一处、传给 `\@@_save_punct_skip:nNNnnn` 的 glue plus 分量计算一处），保证自然宽度与弹性分量（stretch）使用同一套"是否除以 2"判断，避免两者不一致导致 shrink/stretch 场景下的二次偏差。

**已知代价（接受）**：单个 U+2014 略超 1 字宽（约 1.087 ccwd），三连略欠 1 字宽（约 2.913 ccwd）。这是"只调整两个自由度（kern、margin）去满足两个不变量（中间无缝、总宽正确）"必然存在的近似残差，视为可接受的已知偏差，测试按此实测值断言。

## 决策 3：合字支持用用户显式 opt-in，不做自动探测

考虑过在字体加载时自动探测是否支持 OpenType 破折号合字特性，命中则自动启用 `PoZheHao` 类。

**采纳方案**：`PoZheHaoLigature` 默认关闭，用户需显式 `\xeCJKsetup{PoZheHaoLigature}` 开启。

**理由**：

- 合字能力完全取决于字体本身（思源系字体支持，多数国产字库不支持），XeTeX 没有可靠原语能在不实际执行 shaping 的情况下探测某字体是否具备特定 OpenType 合字特性。
- 对不支持合字的字体错误启用该选项会产生负面效果（连续破折号中间露出空隙，因为零注入类不再提供任何补偿间距），这一失败模式比"不开启合字优化"更差，不能在探测不可靠的前提下默认开启。
- 用户通常还需要额外配合开启 `fwid`/`locl` 等 OpenType 特性才能获得全角合字字形，这本身就需要用户对字体特性有主动认知，与"opt-in"的心智模型一致。

## 归属与关联

- 实现：`xeCJK/xeCJK.dtx`（`\@@_long_punct_kerning:N`、`\xeCJK_punct_margin_process:NN`、`\@@_punct_if_full_margin_dash:N`、`PoZheHao` 字符类、`\@@_punct_if_right:N`、`PoZheHaoLigature` 选项），commit `8f67da87`，分支 `issue-382-dash-width`，PR #944。
- 回归测试：`xeCJK/testfiles/dashwidth01.lvt`；`loading01.tlg` 登记新字符类 `\c__xeCJK_PoZheHao_class_int`。
- 架构文档：`llmdoc/architecture/xecjk-architecture.md` 标点压缩系统一节（破折号宽度算法、`PoZheHao` 字符类、标点度量 feature-blind 限制）；字符分类体系表；零注入字符类模式小节（`HangulJamo`/`PoZheHao` 通用总结）。
- 反思：[[382-dash-width-punct-if-right-and-cmap-metrics]]。
