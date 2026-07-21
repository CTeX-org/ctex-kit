# llmdoc 索引

## overview

- `llmdoc/overview/project-overview.md` — 项目范围、仓库组织、核心/卫星包分类、技术栈与维护状态。

## architecture

- `llmdoc/architecture/package-architecture.md` — `ctex` 与 `xeCJK` 的主干架构、引擎适配策略、第三方包补丁子系统与包间依赖图；现含 #381 的 LuaTeX 拒绝传统 `CJKfntef` / XeTeX 透明替换边界、#407/#800 的 `\xeCJKchar` + 定点补丁策略、#158 Hangul L/V/T、#165 `CJStarter`，以及 #992 按实际首尾类别工作的 capture/register 高层模型和 PR #1005 对右边界后续恢复状态的补充。
- `llmdoc/architecture/xecjk-architecture.md` — xeCJK 独立架构详解：
  - interchar token、字符分类（#158/#165/#336/#347/#382）、基础 marker/glue 恢复逻辑、#992 capture/register 策略与直接输入比较、`xCJKecglue=false/true` 双值矩阵、嵌套和 `\sbox` 隔离、TeX 无法区分某些显式 glue 与源码空格的限制，以及 `\kern0pt` 处理方法；其中 PR #1001 为 Boundary→CJK 和 Boundary→Default 使用相同的 glue 检查（#996），并在 box/wrapped-box 结束时同时检查盒子尺寸与末节点类型，按 Default 处理 math/rule 等可见内容，再通过嵌套盒子留下的 marker 逐层更新末类别（#998）；PR #1005 为 #1003 恢复外层 `spacefactor` 与 post-transparent 的有界 `marker + glue` 后缀；#1002 还按空格是否参与外层断行区分 `math-space` 与 `math-space-frozen`；
  - 标点压缩（#975 对 #443/#481/#488 的预设与方向性修复，以及 #511 重构边界）和间距语义（#808）；
  - 兼容补丁（#510、#873/#880/#910/#919/#931/#972）、`\char` 约束及扩展子包。
- `llmdoc/architecture/ctex-architecture.md` — ctex 独立架构详解：分层加载、键值选项、引擎适配（含 pdfTeX UTF-8 `\DeclareUnicodeCharacter` 优先查找和 #381 `CJKfntef` 后端边界）、字号与字距系统（含 #871 `letterpress` 语义及 #402 `autoindent` 零缩进兼容边界）、方案/标题/字体集（含 #275 可展开的标题编号、完整标签与编号开关查询）、命令补丁，以及 Babel/biblatex 公开组合方法与运行时补丁的职责边界。
- `llmdoc/architecture/cleveref-patch.md` — cleveref 兼容补丁机制、挂钩链、`patch/cleveref` 开关与 Issue #725 根因分析。

## reference

- `llmdoc/reference/build-and-test.md` — `l3build`、共享构建配置、根 `Makefile` 本地任务入口（#888，含 `make changelog` #961）、`ctex` 184 个主回归测试，以及 xeCJK #992/#1002 命令边界测试：直接输入 oracle、`00/10/01/11`、`xCJKecglue=false/true`、默认/可区分间距与状态归零断言；`command-boundary01` 当前执行 1668 个绿色单元，`command-boundary-math01` 执行 5504 次公式比较，`command-boundary-math05` 固定尾随空格的伸缩量和不可见节点边界，xeCJK 标准测试当前为 108／108。文档还记录节点测试、显式 glue 的来源限制、`\kern0pt` 处理方法、字体预热、多引擎基线、CI/CD、版本检查和本地 TeX Live usertree 同步。
- `llmdoc/reference/coding-conventions.md` — expl3 命名、e-type 优先约定、`@@` 私有空间、`.choices:nn` 用 `#1` 替代 `\l_keys_choice_str`（#806 / #881）、catcode-class regex 的匹配优势与替换端 codepoint 局限（#378 / #879）、作用域语义（含用户可见命令全局/局部选择 #751 + 镜像分组局部原语状态的布尔标志必须同样局部 #431）、docstrip 标签、`\CTEX@` 遗留接口，以及 ctxdoc 对 l3doc 2026-06-18 的私有接口门禁与 #963 长函数名压缩边界。
- `llmdoc/reference/ctex-fontset-mac.md` — `ctex` 中 `fontset=mac` / `macnew` / `macold` 的选择逻辑、macOS 15+ 检测后备、XeTeX/LuaTeX 字体探测差异与回退语义。
- `llmdoc/reference/repo-git-conventions.md` — 仓库级 git 约定：CODEOWNERS 默认与 zhlineskip 专属审查归属、pre-push self-wrapper 的真实 push/CI/review 状态判定、bot 评论由维护者证据回复确认后的无空提交终止路径，以及长期 orphan 分支 `gh-assets` 的资产组织、安全写入和迁移收尾（现含 #275/#402、#995/#996/#998 等 MWE 与对比图）。

## guides

- `llmdoc/guides/push-and-pr-review-workflow.md` — 安装 self-wrapping pre-push、无管道执行 push、解读内层 push 与 rc、联合审计 GitHub review 和被 git 忽略的本地 `.code-review` 报告、无需改代码的 bot finding 以维护者证据回复确认并手动复检、按当前增量风险选择验证强度、新分支首次 PR 补跑，以及最终 llmdoc 收尾的完整闭环。
- `llmdoc/guides/release-workflow.md` — 两阶段 release 流程: ① `release.yml` 推 tag 自动打 CTAN zip + 发 GH prerelease(公测); ② `release-ctan-upload.yml` 手动触发, 复用同一 zip + LLM 忠实翻译 `scripts/extract-changes.py` 抽出的 release notes 为英文 announcement 投递 CTAN, 成功后翻 GH Release 为 latest; `announce=false` 可跳过 announcement; 本地 `make tag` 打 release tag; 含 `scripts/extract-changes.py` 参数语义(单版本模式字节兼容承诺 + `all`/`-o` 参数 #961)。

## memory

- `llmdoc/memory/lessons-learned.md` — 从已归档反思提炼的跨任务规则；当前含审查与生成物门禁、按风险收缩验证、节点/视觉证据、命令边界输出等价矩阵、选项与公式形式必须进入 oracle、绿色单元与失败基线分离、先穷举机制再抽象原语、不可判源时公开支持边界、说明层隔离、lazy family 预热、PR 原型预览与已合并 issue 活表分层，以及 feature request 和 git 测试规则。

- `llmdoc/memory/decisions/repo-push-hook-discipline.md` — 决策: 常规 push 必须以无管道命令完整运行 self-wrapping pre-push，按内层 push、CI 和 review 活动输出闭环修复全部问题；无需代码改动的 bot finding 用维护者证据回复确认，避免空提交触发无限 review 循环，并以 llmdoc 更新收尾。
- `llmdoc/memory/decisions/275-heading-query-interfaces.md` — 决策: 为 Beamer 等下游提供可展开、按层级查询裸编号、完整本地化标签和 `numbering` 状态的公共接口；不新增 Beamer insert 命令，也不公开样式私有宏。
- `llmdoc/memory/decisions/402-autoindent-zero-exception.md` — 决策: 保留 `autoindent` 对零 `\parindent` 不执行字号跟随的兼容语义，以保护旧文档和 `minipage`、居中段落等结构；补手册与四引擎回归，不改实现。
- `llmdoc/memory/decisions/158-165-jamo-cj-interchar-classes.md` — 决策: Hangul 用 L/V/T 转移区分音节内 shaping 与音节间 CJKglue；日文 CJ 默认 normal、可选 strict 独立类禁则，并保持 fntef 专用转移。
- `llmdoc/memory/decisions/271-varioref-chinese-upstream-locale.md` — 决策: 中文 varioref 本地化优先以上游 `varioref` 的 `chinese` locale 实现，先推动 latex2e PR #2071，而非在 ctex 侧维护整套描述性文本补丁。
- `llmdoc/memory/decisions/725-cleveref-patch-toggle.md` — 决策: 不在 ctex 侧修复 cleveref appendix 语义问题，改为提供 `patch/cleveref` 开关。
- `llmdoc/memory/decisions/751-newCJKfontfamily-scope.md` — 记录 #751 / PR #773 中 `\newCJKfontfamily` 从全局命令定义改为局部定义的原因、决策与影响范围。
- `llmdoc/memory/decisions/782-fontset-mac-macos15plus-detection.md` — 决策: 不新增 `mac15plus`，改为在 `fontset=mac` 内增加 macOS 版本检测后备，并按 XeTeX/LuaTeX 分别探测 macOS 15+ downloadable 字体。
- `llmdoc/memory/decisions/746-remove-legacy-font-hooks.md` — 决策: 移除对 LaTeX < 2020/10/01 的字体钩子兼容代码，响应上游移除 `\@rmfamilyhook`。
- `llmdoc/memory/decisions/688-pifont-interchartokenstate-leak.md` — 决策: pifont hook 中先进入水平模式防止 interchartokenstate 泄漏到输出例程。
- `llmdoc/memory/decisions/715-hyperref-driverfallback.md` — 决策: hyperref driverfallback 按加载状态分支处理，避免重复设置警告。
- `llmdoc/memory/decisions/717-experiment-cjkecglue.md` — 决策: 将跨引擎 `CJKecglue` 统一接口保持为实验性，并固定在 `ctex / experiment` 子路径下。
- `llmdoc/memory/decisions/543-font-size-system.md` — 决策: 将字号系统切换能力放入 `experiment/font-size-system`，仅在类/宏包选项阶段选择 `word`、`letterpress` 或用户自定义字号表；#813 将原名 `traditional` 更名为 `letterpress` 以明确其金属活字语义。
- `llmdoc/memory/decisions/761-ccglue-override.md` — Issue #761 CJKglue 导言区覆盖问题的修复方案演进与确立的引擎延迟重定义模式。
- `llmdoc/memory/decisions/811-halfright-prebreakpenalty.md` — 决策: #811 对整个 `HalfRight` 类施加条件禁则，不拆分类；其中 `FullRight -> HalfRight` 必须覆写 interchartoks 以保证 penalty 位于 punct glue 之前；"固定 13 个字符"仅为 #811 落地时静态基线，#431 起 `HalfRight` 成员随 `LatinPunct` 开关动态增减。
- `llmdoc/memory/decisions/826-fntef-right-side-cjkglue.md` — 已被 #999 替代的历史决策：旧 fntef pending/filter 由 `stream-ulem` 与统一 source-space 检查吸收，外侧 glue 由 framework 决定并排到装饰区间外。
- `llmdoc/memory/decisions/826-fntef-color-global-state.md` — 已被 #999 替代的历史决策：装饰符号 hbox 的手工状态保存/恢复改由可嵌套 capture suspend/resume 统一隔离。
- `llmdoc/memory/decisions/830-color-wraps-ulem-last-node-tl.md` — 已被 #999 替代的历史决策：ulem 不再保存并覆盖全局末状态，而是把可信末尾 marker 移到外层后由 stream capture 解释实际末类别。
- `llmdoc/memory/decisions/831-boundary-explicit-brace-ecglue.md` — 已被 #999 替代的历史决策：显式分组保留基础 source-space 门控；`\mbox`、color/xcolor 分别进入 box、transparent/wrapped-box 注册，颜色专用 pending 与通用 hlist/whatsit 猜测已删除。
- `llmdoc/memory/decisions/873-880-fixed-point-vs-default-narrowing.md` — 已被 #999 替代的历史决策：`\HD@target` 使用 transparent capture，完整 `\Url@z` 与 codedoc/doc meta 使用 stream；旧 save/replay 与 drain 均已删除。
- `llmdoc/memory/decisions/910-verb-drain-vs-drain-verb.md` — 已被 #999 替代的历史决策：`\verb` 使用 auto stream，旧 drain helper 已删除；#919 的 language whatsit 主动落盘只保留节点时序职责。
- `llmdoc/memory/decisions/931-biblatex-let-shadow.md` — 部分保留的历史决策：最终 `\let` 目标 `\blx@pagetracker` 与 preamble 末安装时机仍有效；旧单向 clear/whatsit 恢复算法已由 transparent capture 取代。
- `llmdoc/memory/decisions/935-check-doc-vs-ctan.md` — 决策: #935 新增 PR 门禁 `check-doc.yml` 用 `l3build doc` 而非 `l3build ctan`。后者内部硬编码调 `l3build check` (整套 regression) 与 test.yml 完全重复; 前者是纯 typeset (docinit + typesetpdf), 精确对应"文档 dtx→PDF 可编译性"维度. 牺牲 tdslocations 打包路径验证 (低频问题, release.yml 兜底).
- `llmdoc/memory/decisions/937-version-single-source-l3build-tag.md` — 决策: #937 版本管理收敛为 build.lua 单一事实源 + `l3build tag` 回写 dtx `$Id:$` stamp + 双闸 CI (check-tag.yml PR 门禁 + release.yml 三方校验 strip_rc(git tag)==build.lua==stamp)。update_tag 必须幂等 (stamp 版本相等即跳过, 否则回写追着 commit 跑永不收敛); RC 后缀只存在于 git tag, 发 rc 前 build.lua 必须已 bump 并 stamp。适用 zhlineskip / ctex, 其他包迁移路径已列出；同一原则延伸到手册首页页脚 shorthash——曾短暂采用编译时 `\sys_get_shell` 现场取 git hash (`--shell-escape`), 四环境实测在 CTAN 典型解压场景导致 Emergency stop 被否决, 改为 `update_tag` 在 `l3build tag` 阶段固化写入 `ctex.dtx` 的 `\GetFileId[<hash>]`。
- `llmdoc/memory/decisions/961-changelog-gate-no-write-perm.md` — 决策: #961 CHANGELOG.md 生成物新鲜度校验收敛为「CI 每 PR 重新生成 + `git diff --exit-code` 只校验不回写」，与 #937 check-tag.yml 同一「生成物新鲜度校验」架构模式；否决 CI 打 tag 时生成并 commit（需 write 权限）与 tag 前本地手跑（流程不闭环）两案。已接受缺憾: zhmetrics 包名前缀推断为 `zhmCJK` 导致版本链接死链、并行 PR 的 CHANGELOG 合并冲突。
- `llmdoc/memory/decisions/972-hyperref-end-annot-trusted-marker.md` — 已被 #999 替代的历史决策：顶层 `\Hy@EndAnnot` 的末尾 math 仍作为 Default 观察点，但从 `\Hy@BeginAnnot` 到结束端的 auto stream 已取代专用 marker。
- `llmdoc/memory/decisions/991-setref-null-marker-replay.md` — 已被 #999 替代的历史决策：保留 `\null` 的目标不变，但 `\@setref` / `\real@setref` 已改用 auto stream，一般 `\null` 走 post-transparent；专用 wrapper、saved-node 与 replay 已删除。
- `llmdoc/memory/decisions/992-command-boundary-capture-register.md` — 决策：#992/PR #999 用 box、wrapped-box、stream、transparent、post-transparent 五种注册策略和运行时首尾类别统一恢复命令两侧间距；记录嵌套、`\sbox` 状态、旧逐命令补丁的替代结果、TeX 无法区分某些显式 glue 与源码空格的限制，以及 `\kern0pt` 处理方法。现含 PR #1001 对 #995/#996/#998/#1000 的修复、PR #1005 对 #1003 的外层 `spacefactor` 同步和有界后缀移动，以及 #1002 的公式 oracle、实际节点确认和 `math-space`／`math-space-frozen` 弹性间距状态；#992 活表已从 PR #1005 的合并提交复验并更新。
- `llmdoc/memory/decisions/1002-inline-math-boundary-oracle.md` — 决策：行内公式命令只去掉外层包装，以直接公式而非西文字母为 oracle；保留 `xCJKecglue=false/true` 对公式旁源码空格的既有语义，并以“所有尾部公式语法只产生候选＋正文排完时的实际节点确认”避免把未知宏消费的分组、`$` 或 `\)` 误认成可见公式；现含 `math-space`／`math-space-frozen` 对参数内尾随空格的分流、不可见节点导致 marker 过期时的 glue 与盒子顺序、ulem 确认时机、5504 次宽度比较和节点回归。
- `llmdoc/memory/decisions/382-dash-width-and-ligature-opt-in.md` — 决策: #382 破折号宽度修复分两阶段——公式修正（`\@@_long_punct_kerning:N` 三路取大 kern + `\xeCJK_punct_margin_process:NN` 全份 margin 补偿）默认生效, OpenType 合字支持通过 `PoZheHao` 字符类 `PoZheHaoLigature` opt-in; margin 选择新增专用条件 `\@@_punct_if_full_margin_dash:N` 而非改变目标宽度基准; 合字选择用户显式开关而非自动探测字体特性。
- `llmdoc/memory/decisions/431-latinpunct-option.md` — 决策: #389/#431 新增 `LatinPunct` 选项让中西文共用码位标点（弯引号/间隔号/省略号）可切换为西文字体输出；归入 `Half*` 类而非 `Default`；破折号/半字线刻意排除保持与 `PoZheHaoLigature` 正交；状态记录改用局部布尔 `\l_@@_latin_punct_bool` 并回溯修正 `PoZheHaoLigature` 同类作用域问题（影子布尔作用域必须与被控 `\XeTeXcharclass` 资源一致）。
- `llmdoc/memory/decisions/336-external-interchar-class-others.md` — 决策: #336 的 CJK URL 断行由既有 `Others` 兼容层覆盖；外部 class 必须在导言区结束前定义 Default transition，不新增通用字符类继承 API。
- `llmdoc/memory/decisions/347-boxed-glyph-transform-prototype.md` — 决策: #347 的 interchar 装盒变换保留为未来整体重构的设计原型，但逐 code point 装盒无法局部接入当前 class/shaping/Boundary 状态机，现阶段 `not planned`。
- `llmdoc/memory/decisions/510-ruby-compatibility-boundary.md` — 决策: #510 的旧 `ruby.sty` crash 已由禁载 `CJK.sty` 解决，但这不构成传统 CJK 私有协议兼容；推荐 PXrubrica，不模拟旧 kern-marker 状态机。
- `llmdoc/memory/decisions/553-mixed-font-spacing-class-not-planned.md` — 决策: #553 的“CJK 字体 + Default 间距”在 XeTeX 上技术可行，但混合类会破坏 xeCJK 的 CJK/非 CJK 二分；当前采用显式局部字体命令，不增加数字特例并以 `not planned` 关闭。
- `llmdoc/memory/decisions/808-inline-code-verb-addon.md` — 决策: #808 的真实需求是行内代码网格而非字体族级 `CJKecglue`；组合等宽字体与 `\xeCJKVerbAddon`，不改变全部 `\texttt` 的断行行为。
- `llmdoc/memory/decisions/859-gh-assets-orphan-branch.md` — 决策: 建立长期 orphan 分支 `gh-assets` 集中托管 issue/PR 讨论静态资源, 取代按事件建临时分支（`tmp-859-assets` / `tmp-456-assets`, 均已删除）; 添加新资产须用 worktree 或纯 plumbing 流, 禁止主工作区 `git checkout --orphan` 以避免 `git clean` 波及未跟踪文件。
- `llmdoc/memory/decisions/456-longpunct-kinsoku-both-sides.md` — 决策: #456 长标点与其他标点相邻断点改为"两侧禁则联合判断"，落在既有 `\@@_punct_kern:NN` 内新增辅助函数 `\@@_punct_kern_break:NN`，不新增字符类/special punct 属性、不引入 penalty 类机制；`\g_@@_last_punct_tl` 参与 `\@@_punct_if_right:N` 前需 `\exp_after:wN` 展开为字符记号，参与 `\@@_punct_if_long:N` 判断则直接传 tl。
- `llmdoc/memory/decisions/908-ubuntu-fontset-fangsong.md` — 决策: #908 `fontset=ubuntu` 补齐仿宋 `zhfs`/`\fangsong`，采用朱雀仿宋（lxgw-fonts）→ FandolFang → Noto 宋体三级运行时 fallback（仅 XeTeX/LuaTeX，`\fontspec_font_if_exist:nTF`）；基线定量（dp: Noto 0.76pt / 朱雀 1.21pt / Fandol 1.75pt）驱动候选排序；`\CJKsymbol`+`\raisebox` 基线抬升 hack 验证有效但判定与标点压缩系统冲突，ctex 不提供该功能；`DEPENDS.txt` 新增 `soft lxgw-fonts`。
- `llmdoc/memory/doc-gaps.md` — 已知文档与实现缺口追踪。
- `llmdoc/memory/archive/2026-07-20/999-command-boundary-capture-framework.md` — 反思: #999 先用完整矩阵把 edge case 收敛为有限节点形状，再建立 capture/register；记录运行时首尾类别、嵌套与 `\sbox`、宽度/节点/可视三层证据、说明层隔离、lazy font 预热、同构 glue 支持边界，以及 PR 预览与 #992 活表的合并状态分层。
- `llmdoc/memory/reflections/1005-xcjkecglue-right-boundary-recovery.md` — 反思：PR #1005 修复 #1003 时，类别 marker 正确但右边界仍缺少外层 `spacefactor` 和 `marker + glue` 的物理相邻关系；记录有界 post-transparent 节点移动、0pt glue 节点契约、1664 个矩阵断言、节点级验证、changelog 门禁、并行 LuaTeX 临时日志缺失，以及合并后从 16 个驱动复验并更新 #992 活表的收尾过程。
- `llmdoc/memory/reflections/717-experiment-cjkecglue.md` — 反思: #717 用 `ctex / experiment` 子路径统一暴露实验性 `CJKecglue` 接口，并记录 xeCJK 参数桥接、xkanjiskip 缓存同步与四引擎基线策略。
- `llmdoc/memory/reflections/715-hyperref-driverfallback.md` — 反思: TYPE 展开陷阱、l3build 命令拦截测试技巧。
- `llmdoc/memory/reflections/671-cjkpunct-rglue-nobreak.md` — 反思: CJKpunct #671 修复中的节点级调试技术与 `\unhbox` 测试模式。
- `llmdoc/memory/reflections/735-zhlineskip-split-leading-leak.md` — 反思: zhlineskip #735 split 行距泄漏的根因（TeX 分组层级）、vbox 尺寸回归测试策略与 l3build 框架补建。
- `llmdoc/memory/reflections/465-fntef-font-state-and-underdot-space.md` — 反思: xeCJKfntef #465 中 ulem 下字体状态跨分组丢失 + `\CJKunderdot` 的 `\ignorespaces` 吞空格，及诊断误判的教训。
- `llmdoc/memory/reflections/581-xecjk-zero-width-format-chars.md` — 反思: xeCJK #581 中零宽格式字符应在输入层忽略，而不是进入 interchar 字符分类。
- `llmdoc/memory/reflections/556-verb-xkanjiskip-lltjcore.md` — 反思: ctex #556 中从 autoxspacing 误判修正为”禁用 ltj-latex 后漏掉 lltjcore 的 `\verb` 补丁”，以及基于 `\showbox` 的节点级定位方法。
- `llmdoc/memory/reflections/378-lstinline-hash-doubling.md` — 反思: xeCJK #378 中 `\lstinline` 宏参数 `#` 双写的根因（rescan 的 stringification 再次双写 cat6 `#`）、catcode 12 vs active 的易错点、`\regex_replace_all` catcode class 匹配技巧。
- `llmdoc/memory/reflections/879-lstinline-parameter-tokens-charcode.md` — 反思: xeCJK #879 中 `\lstinline` 下 catcode 6 token 字符码丢失的根因——#378 catcode-class regex 方案的“替换端硬编码 codepoint”局限在 `\catcode\`\&=6` 场景被暴露，改为 `\tl_map_inline:Nn` + `\token_if_parameter:NTF` + `\char_generate:nn { \int_value:w ``##1 } { 13 }` 逐 token 保留原字符码；promotion 时需显式记录适用边界。
- `llmdoc/memory/reflections/407-char-interchar-bypass.md` — 反思: xeCJK #407 中 `\char` 原语被 interchar 拦截的根因、`\char` vs mathcode 语义差异、测试场景设计偏差。
- `llmdoc/memory/reflections/800-char-let-xint-compat.md` — 反思: xeCJK #800 中 `\char` 重定义必须延迟到 `\AtBeginDocument`，避免破坏 xint 等包在加载期 `\let` 保存原语的假设。
- `llmdoc/memory/reflections/315-252-476-xecjk-ecglue-fixes.md` — 反思: xeCJK #252/#476 的 ecglue 字体度量问题与 #315 一样属于 interchar 边界恢复链，应在正确 CJK 字体上下文中缓存前侧 ecglue，并提前按 CI 依赖链完整验证基线影响。
- `llmdoc/memory/reflections/756-802-spa-unicode17-baseline.md` — 反思: #756 XeTeX 字体查找语法陷阱、#802 Unicode 区块同步流程、xeCJK→ctex 跨包基线联动模式。
- `llmdoc/memory/reflections/807-set-color-stale-state.md` — 反思: xeCJK #807 中 `\set@color` 无节点分支未清空 `\g_@@_last_node_tl`，导致首次 `\textcolor` 把初始化阶段残留的 `default` 误送入 whatsit 恢复链并错误插入 ecglue。
- `llmdoc/memory/reflections/809-810-hyperref-annot-ecglue.md` — 反思: xeCJK #809/#810 中 hyperref 注释起始 whatsit 需在 `\Hy@BeginAnnot` 保存/清空/选择性重放状态；#972 后明确该“开始端”结论只适用于入口污染，不覆盖结束 whatsit 遮蔽真实末节点的独立路径。
- `llmdoc/memory/reflections/324-boundary-reserve-space-glue.md` — 反思: xeCJK #324 中宏路径提前输出空格 glue 遮蔽 `CJK-space` 标记 kern，破坏 `\lastkern` 边界恢复；修复同时揭示 xeCJK→ctex 的广泛基线联动。
- `llmdoc/memory/reflections/826-fntef-boolean-flag-iteration.md` — 反思: xeCJK #826 fntef glue-on-kern-pair 初始修复后的迭代——`\l_@@_last_skip` 状态污染、`\quad` 误处理、fallback 路径错误的根因与三层过滤收敛过程。
- `llmdoc/memory/reflections/831-reset-color-pending-bool.md` — 反思: #831 colorbox/textcolor 右侧间距修复四轮迭代——从 `\reset@color` 直接插入 kern 对到 `\g_@@_reset_color_pending_bool` 专用布尔延迟处理的收敛过程，核心教训为共享全局布尔的语义过载风险。
- `llmdoc/memory/reflections/873-880-meta-url-hbox-math-boundary.md` — 反思: xeCJK #873 / #880 中 `\HD@target` 的 0x0 hbox 与 `\Url@FormatString` 的 math 模式分别遮蔽边界 marker；混合修复（save/replay vs drain），以及本地 TeX Live usertree 与 CI 漂移导致 7 个 false-positive 测试失败的诊断教训（双步同步 + fmt 重生成）。
- `llmdoc/memory/reflections/910-verb-null-hbox-drain.md` — 反思: xeCJK #910 的旧 verb drain 不能在无 marker 时 clear `\g_@@_last_node_tl`；该 helper 后更名为 keep-state，`\verb` 在 #992 已迁移为 auto stream，但这份记录仍解释 FandolFang→FandolSong 的 CJK→CJK 状态要求。
- `llmdoc/memory/reflections/931-biblatex-pagetracker-let-shadow.md` — 反思: xeCJK #931 中 biblatex `authoryear` 通过 `\let\blx@pagetracker\blx@pagetracker@context` 在 bbx 加载时把 pagetracker 行为**值拷贝**——首次 patch 挂在 `\let` 源函数（`\blx@pagetracker@context`）不生效，`\iow_term:x` 打点无输出的假信号误导；正确修法是补丁点改到 `\let` 目标本身 + hook 时机延迟到 `\@@_at_end_preamble:n`（`\@@_package_hook:nn` 对 nested style-load 太早）。补丁点选择的第三维度：目标控制序列的绑定形态（`\def` vs `\let` 拷贝目标）。
- `llmdoc/memory/reflections/935-check-doc-zhspacing-blockers.md` — 反思: #935 新增 `check-doc.yml` PR 门禁跑 `l3build doc` 时首轮 CI 暴露 3 包 typeset 缺陷 (xpinyin fontconfig 索引缺失 / zhmetrics TL 包不含顶层 tfm/map / zhspacing 深层依赖). 关键教训: `l3build ctan` 内部硬编码跑 check 不能作 PR 门禁替代品; fontconfig alias 三种姿势都救不了 XeTeX/fontspec 的字体查找 (`fc-match` 生效但 `\newfontfamily` 依然找不到), CI 上给不存在的字体提供替代唯一稳定办法是 sed patch dtx/sty; nonstopmode 会掩盖 fatal 之后错误链条 (zhspacing 首层 SimSun 修好后暴露 `\@iforloop` undefined 假象); TL 里的包不必等价于 CTAN 项目产物 (zhmetrics 顶层 tfm/map 是 CTAN admin 手工上传的独立文件, TL 打包未纳入); zhspacing 从 caller 删除留 followup 而非强行修完.
- `llmdoc/memory/reflections/937-ctex-split-version-stamp-ci.md` — 反思: PR #937 ctex.dtx 拆成 6 文件 (kernel/auxpkg/engine/scheme/fontset + 主 dtx 保留 ins/README/手册) 的区域规划与配套版本 CI. 关键教训: "回写 git 元数据到源文件"的机制必须有收敛条件否则永动 (stamp commit 产生新 sha → 下次又要回写), ctex update_tag 用"版本号相等即跳过"守卫; awk 取 `$Id:` stamp 版本字段是 $4 不是 $3, 新校验脚本必须先本地模拟正反场景; `make tag` (git tag) 与 `l3build tag` (源文件 stamp) 是两回事; 共享 feature 分支 push 前 pull --rebase.
- `llmdoc/memory/reflections/878-xunicode-symbols-multilevel-fallback.md` — 反思: xeCJK #878 `xunicode-symbols.tex` 驱动从“整段单字体 if-else”升级为 `FreeSerif → Noto Sans Symbols 2 → Symbola → Segoe UI Symbol → DejaVu Sans` 五级逐字符 `\iffontchar` + `\cs_if_exist_use:N` 链；只适用于演示性符号目录驱动文件，不应推广到正文 / CJK 字体路径。
- `llmdoc/memory/reflections/456-longpunct-kinsoku-both-sides.md` — 反思: xeCJK #456 长标点断点两侧禁则修复中"标点属性判断"函数族参数形态不同（`\@@_punct_if_right:N` 吃字符记号需 `\exp_after:wN` 展开 tl，`\@@_punct_if_long:N` 直接吃 tl）、`punct.tlg` 大文件基线联动 diff 用"变化位置共同特征 + 节点变化统一模式"两条证据判定预期变化、以及标点对矩阵 + `\showbox` 节点判定的系统性禁则调试法。
- `llmdoc/memory/reflections/874-876-agentic-fork-shielding-cron.md` — 反思: #875 / #874 `agentic-*.yml` 同时存在两条边界约束——job 级 `if: github.repository == ...` 把 fork 调度挡在 runner 分配之前，`schedule` 频率回退到每天一次北京时间 08:00；未来新增 agentic 工作流时这两条都应作为默认。
- `llmdoc/memory/reflections/ctex-architecture-doc.md` — 反思: ctex 架构独立文档的创建过程、源码阅读方法与已知文档缺口。
- `llmdoc/memory/reflections/961-changelog-freshness-gate.md` — 反思: #961 CHANGELOG.md 生成物新鲜度校验（check-changelog.yml）流程分歧收敛过程、跨平台字节一致性必须由脚本自控 encoding/newline 的新坑、用改造前脚本输出当字节级 oracle 验证回归的方法、门禁 fail 时按校验对象大小设计可操作性（整文件需三通道贴期望内容）、以及「生成物新鲜度校验」作为跨 #937/#961 的通用架构模式的提炼建议。
- `llmdoc/memory/reflections/1001-boundary-capture-gap-fixes.md` — 反思：PR #1001 修复 #996、#998、#1000 时，管道掩盖了六项测试失败；盒子是否直接排出可见内容需要同时检查尺寸和末节点类型；嵌套盒子结束时，外层盒子必须读取节点列表末尾的 marker，不能无条件覆盖所有外层 `last_tl`。文档还记录了两项错误旧基线和 gh-assets 测试驱动引用已删除内部变量的问题。
