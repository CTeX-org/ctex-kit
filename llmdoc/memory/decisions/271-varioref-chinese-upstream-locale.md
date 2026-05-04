# 决策: 中文 varioref 本地化先以上游 `chinese` locale 为主

- 日期: 2026-05-04
- 关联: Issue #271, latex2e PR #2071

## 背景

Issue #271 请求 `ctex` 为 `varioref` 宏包提供中文本地化字符串，把英文描述性文本如 “on page 231” 转成中文形式（如“第 231 页”）。

`varioref` 属于 LaTeX2e 内核的 tools bundle，负责带页码信息的增强交叉引用。该能力的真正文本来源不在 `ctex`，而在 `varioref` 自身的 locale 选项与一组 `\reftext...` / `\vref...format` 宏。

## 当前状态

`ctex` 已有 `\ctex_varioref_hook:`，用于在检测到 `varioref` 后修正 `\labelformat`，使中文标题编号能正确出现在标签中。这一 hook 只覆盖标签格式，不覆盖 `varioref` 的描述性文本。

上游 `required/tools/varioref.dtx` 已有日语 locale（2020 年加入，gh/352），说明 `varioref` 本身支持按语言选项内建本地化字符串；但目前没有中文 locale。

用户今天可以通过手工重定义如下宏得到中文输出：

- `\reftextfaceafter`
- `\reftextfacebefore`
- `\reftextafter`
- `\reftextbefore`
- `\reftextcurrent`
- `\reftextfaraway`
- `\reftextpagerange`
- `\reftextlabelrange`

以及相关格式宏如 `\vrefformat`、`\Vrefformat`、`\fullrefformat`、`\vrefrangeformat`。但这种方式需要用户自己了解 `varioref` 内部接口，使用门槛较高。

## 决策

1. 中文 `varioref` 文本本地化优先在上游 `varioref` 中实现，而不是先在 `ctex` 侧叠加一层完整文本补丁。
2. 以上游 PR `latex2e#2071` 为主线，向 `varioref` 新增 `chinese` option，按既有日语 locale 模式提供完整中文字符串与格式定义。
3. 本轮上游方案包含 8 个 `reftext` 宏与 4 个 format 宏：
   - `\reftextfaceafter`
   - `\reftextfacebefore`
   - `\reftextafter`
   - `\reftextbefore`
   - `\reftextcurrent`
   - `\reftextfaraway`
   - `\reftextpagerange`
   - `\reftextlabelrange`
   - `\vrefformat`
   - `\Vrefformat`
   - `\fullrefformat`
   - `\vrefrangeformat`
4. 中文 format 宏采用全角括号 `U+FF08` / `U+FF09`，使输出更符合中文排版习惯。
5. 在上游 PR 合并前，`ctex` 维持现状：继续保留 `\ctex_varioref_hook:` 处理标签格式，不在当前仓库内新增一套长期维护的 `varioref` 中文文本补丁层。

## 理由

- 责任边界清晰：描述性文本属于 `varioref` 自身的 locale 语义，放在上游实现比由 `ctex` 旁路 patch 更符合模块职责。
- 维护成本更低：若 `ctex` 先自行补齐整套 `\reftext...` / format 宏，未来要持续跟踪上游 `varioref` 的接口变化，容易形成双重维护。
- 与既有上游模式一致：日语 locale 已证明 `varioref` 接受按语言 option 内建本地化，中文沿同一路径实现检索和使用成本都更低。
- 用户体验更自然：最终理想状态应是 `varioref` 原生理解中文 locale，而不是要求 `ctex` 用户额外记忆一组兼容 patch 或手工 `\renewcommand`。

## 已确定方案范围

上游 PR `latex2e#2071` 当前要新增的中文本地化接口包括：

- 8 个描述性文本宏：用于“前页/后页/本页/远页/页范围/标签范围”等自然语言片段。
- 4 个格式宏：用于 `\vref`、`\Vref`、完整引用与范围引用的最终排版形式。

这意味着中文支持不是只改某一个 “on page X” 字符串，而是补齐 `varioref` 中文 locale 所需的一整组稳定接口。

## 对 ctex 的后续影响

上游若合并 `chinese` option，`ctex` 后续需要单独评估是否在加载 `varioref` 时自动激活该 option，类似今天已有的 `\ctex_varioref_hook:` 集成方式。

这个后续动作目前尚未决定，需等上游接口稳定后再判断：

1. 是否应由 `ctex` 自动传递 `chinese` option；
2. 自动激活是否会影响用户显式选择的其他 locale；
3. 是否只在 `scheme=chinese` 或中文文档类路径下启用。

因此，当前决策只确定“中文文本本地化先上游化”，不预先承诺 `ctex` 一定自动开启该 locale。

## 后续待办

1. 等待 `latex2e#2071` 合并。
2. 上游合并后，评估 `ctex` 是否需要在加载 `varioref` 时自动激活 `chinese` option。
3. 若上游方案最终落地，关闭 Issue #271。
