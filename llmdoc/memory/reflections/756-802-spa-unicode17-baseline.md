# 756 / 802 / baseline coupling Reflection

## Task
- 记录本轮与 PR #756、Issue #802 以及 ctex `config-contrib` 基线联动相关的可复用维护经验，避免以后在字体加载、Unicode 区块同步和跨包回归验证上重复踩坑。

## Expected vs Actual
- Expected outcome.
  - #756 应让安装在 TeX tree 中、可被 kpathsea 找到的字体正常参与 `.spa` 生成。
  - #802 应只把 Unicode 17.0 中与东亚排版相关的新区块补入 xeCJK 的 CJK 字符范围。
  - xeCJK 行为调整后，ctex 的 `config-contrib` 回归应被视为需要同步检查的下游基线，而不是“无关失败”。
- Actual outcome.
  - `.spa` 问题的真正修复依赖 XeTeX 的文件路径语法 `"[FontName]"`；最初尝试显式补 `.otf` / `.ttf` 扩展名是多余的，kpathsea 本就会解析。
  - 在 `ctex.dtx` 中一度考虑把引擎特化逻辑放进引擎 docstrip guard，但 `ctex.sty` 并不带这些标签，导致该思路本身会被静默剥离。
  - xeCJK #803 之后，ctex `test/config-contrib` 的 `pkuthss` 基线确实需要更新；这是 monorepo 真实模板回归的预期联动。
  - Unicode 17.0 支持不是“机械加入所有新区块”，而是比对 Unicode Blocks 表后，只补入 Tangut / CJK 扩展这类与东亚文字处理直接相关的区块。

## What Went Wrong
- 一开始把 TeX tree 字体加载问题想成“kpsewhich 找到文件后，还需要自己推断并补全真实扩展名”，但 XeTeX 的 bracket 语法已经把这件事交给 kpathsea 处理了。
- 对 docstrip 标签集合的检查不够早，容易把“应该放在生成 `ctex.sty` 的公共区段”与“只在某些输出文件存在的引擎标签区段”混淆。
- xeCJK 行为修复后，如果只盯着 xeCJK 自己的测试，很容易把 ctex `config-contrib` 失败误读成独立问题，而不是跨包基线联动的正常后续动作。
- Unicode 版本升级若没有先参照上一次更新范式，容易陷入“新区块全加”或“靠直觉挑选”的两种不稳定做法。

## Root Cause
- 对 XeTeX 字体查找语义的心智模型不够精确：`"FontName"` 走 fontconfig 名称查找，`"[FontName]"` 走文件/kpathsea 查找，两者不是同一机制的不同写法。
- 对 `.dtx` 产物与 docstrip 标签集合的对应关系缺少先验核对，导致实现位置选择容易受“语义上看似按引擎分支”误导。
- 对 monorepo 测试设计的理解若停留在“每个包自测”，就会低估 `ctex` 对 `xeCJK` 行为变化的模板级回归耦合。
- Unicode 范围维护本质上是“东亚排版相关字符类的 curated 更新”，不是单纯的版本号追赶。

## Missing Docs or Signals
- memory only:
  - 遇到 XeTeX/fontspec 字体加载问题时，先区分“名字查找”与“文件查找”；凡是 `kpsewhich` 已经命中的字体，优先考虑 `"[... ]"` 语法，不要先补扩展名。
  - 修改 `.dtx` 中的条件代码前，先确认目标输出文件实际带哪些 docstrip tag；否则即使语义正确，产物里也可能完全没有这段代码。
  - xeCJK 改动只要可能影响真实模板输出，就应立即补跑 `ctex/l3build check -c test/config-contrib -q`，把失败先视作下游基线更新候选。
  - Unicode 新版本支持优先复用“对比前后 Blocks.txt -> 筛选东亚相关新区块 -> 参照上次提交的模式实现”的流程。
- promotion candidates:
  - `reference/` 可补充 XeTeX/fontspec 字体查找事实：引号语法与方括号语法分别对应 fontconfig 名称查找和 kpathsea 文件查找，后者无需显式扩展名。
  - `reference/` 或 `guides/` 可补充 xeCJK Unicode 版本同步流程，明确“只纳入东亚排版相关新区块”的筛选标准与操作步骤。
  - `reference/build-and-test.md` 可补充一条跨包回归规则：xeCJK 行为改动后，需要同步检查 ctex `config-contrib` 真实模板基线。

## Promotion Candidates
- `reference/`:
  - 增加 XeTeX 字体查找模式说明，明确 `"FontName"` vs `"[FontName]"` 的后端差异与适用场景。
  - 增加 xeCJK Unicode 区块维护清单，记录“比较 Unicode Blocks 表并筛选东亚相关新区块”的事实性流程。
- `guides/`:
  - 增加“xeCJK 改动后的跨包验证顺序”，把 `ctex/test/config-contrib` 列为模板级回归检查项。
- `must/`:
  - 若后续再多次出现同类遗漏，可提升为稳定要求：凡改动 xeCJK 输出行为，提交前至少检查一次 ctex 的 `config-contrib`。

## Follow-up
- 下次遇到 TeX-tree 字体、xeCJK 字符范围或 xeCJK 行为修复时，按以下顺序操作：先确认底层机制语义，再核对 docstrip 产物标签，最后补跑 xeCJK 自测与 ctex `config-contrib` 模板回归，必要时仅更新受影响的 `.tlg` 基线。