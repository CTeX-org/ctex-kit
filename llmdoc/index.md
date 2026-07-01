# llmdoc 索引

## overview

- `llmdoc/overview/project-overview.md` — 项目范围、仓库组织、核心/卫星包分类、技术栈与维护状态。

## architecture

- `llmdoc/architecture/package-architecture.md` — `ctex` 与 `xeCJK` 的主干架构、引擎适配策略、第三方包补丁子系统与包间依赖图；现含 xeCJK 对 #407/#800 的 `\xeCJKchar` + 定点补丁策略，以及边界恢复链中 `\lastkern` 标记 kern、whatsit 定点重放（含 `\set@color` / `\reset@color` / `\Hy@BeginAnnot` / `l3color` 后端四类）、#324 宏路径多余 glue 遮蔽、#826 fntef 右侧 glue-on-kern-pair 遮蔽、#831 显式 `}` / `\textcolor` color-pop / `\mbox` hlist 三种变体、#832 l3color `\__color_select:N`/`\__color_backend_reset:` kern 对保护、ecglue 缓存取值四层约束的统一心智模型；fntef 双向 `\g_@@_last_node_tl` 全局状态隔离模式（`\xeCJK_fntef_sbox:n` hbox 隔离 + #830 ulem save/restore 隔离）；以及 #859 `experiment/punct-measure-fix` 段落模式下 `\unskip` 吞掉段末标点补偿 glue 的 `para/end` 钩子补偿机制。
- `llmdoc/architecture/xecjk-architecture.md` — xeCJK 独立架构详解：interchar token 机制、字符分类体系、类别转换矩阵（含 CJK→Boundary handler 对 catcode 2 的处理）、边界恢复状态机三层模型（含 `\@@_check_for_glue_skip:` kern 路径 + 非 kern 三分支：hlist / whatsit（`\g_@@_reset_color_pending_bool` 门控）/ fallback；`\g_@@_ulem_pending_bool` 三 set 点）、`\reset@color` 与 `l3color` 后端定点补丁（#832 `\__color_select:N`/`\__color_backend_reset:` kern 对保护）、字体管理、标点压缩系统（含 `\@@_punct_boundary_guard:` inner mode penalty 保护与 #859 `experiment/punct-measure-fix` 段落模式 `para/end` 钩子补偿）、间距系统、兼容性补丁模式、`\char` 约束与扩展子包（含 xeCJKfntef 双向全局状态隔离 + xunicode-symbols.tex 五级逐字符字体回退链 #878）；#873/#880/#910/#931 边界恢复修复点选择矩阵（三维度：遮蔽节点类型 + 调用方扫描语义 + 补丁点绑定形态 `\def` vs `\let` 目标；drain 两种变体 `\@@_drain_ecglue:` vs `\@@_drain_ecglue_verb:`；hook 三档时机对照）。
- `llmdoc/architecture/ctex-architecture.md` — ctex 独立架构详解：分层加载、键值选项、引擎适配（含 pdfTeX UTF-8 `\DeclareUnicodeCharacter` 优先查找）、字号系统（含 #871 `letterpress` 仅为金属活字字号体系**之一**的勘误说明）、方案/标题/字体集、命令补丁与实验性接口。
- `llmdoc/architecture/cleveref-patch.md` — cleveref 兼容补丁机制、挂钩链、`patch/cleveref` 开关与 Issue #725 根因分析。

## reference

- `llmdoc/reference/build-and-test.md` — `l3build`、共享构建配置、根 `Makefile` 本地任务入口（#888）、`ctex` 180 个主回归测试的覆盖簇、多引擎基线策略、LuaTeX 预热、CI/CD、CI 字体策略（含 #878 `xunicode-symbols.tex` 五级逐字符字体回退链最低保证）、agentic 工作流来源与频率约束（#874/#876）、LaTeX2e 2026-06-01 格式依赖声明（#883）、本地 TL usertree 同步双步流程（#873/#880）。
- `llmdoc/reference/coding-conventions.md` — expl3 命名、e-type 优先约定、`@@` 私有空间、`.choices:nn` 用 `#1` 替代 `\l_keys_choice_str`（#806 / #881）、catcode-class regex 的匹配优势与替换端 codepoint 局限（#378 / #879）、作用域语义、docstrip 标签、`\CTEX@` 遗留接口与文档排版基础设施。
- `llmdoc/reference/ctex-fontset-mac.md` — `ctex` 中 `fontset=mac` / `macnew` / `macold` 的选择逻辑、macOS 15+ 检测后备、XeTeX/LuaTeX 字体探测差异与回退语义。

## guides

- `llmdoc/guides/release-workflow.md` — 两阶段 release 流程: ① `release.yml` 推 tag 自动打 CTAN zip + 发 GH prerelease(公测); ② `release-ctan-upload.yml` 手动触发, 复用同一 zip + LLM 忠实翻译 `scripts/extract-changes.py` 抽出的 release notes 为英文 announcement 投递 CTAN, 成功后翻 GH Release 为 latest; `announce=false` 可跳过 announcement; 本地 `make tag` 打 release tag。

## memory

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
- `llmdoc/memory/decisions/811-halfright-prebreakpenalty.md` — 决策: #811 对整个 `HalfRight` 类施加条件禁则，不拆分类；其中 `FullRight -> HalfRight` 必须覆写 interchartoks 以保证 penalty 位于 punct glue 之前。
- `llmdoc/memory/decisions/826-fntef-right-side-cjkglue.md` — 决策: #826 新增 `\@@_check_for_glue_skip:` 三层过滤（boolean flag + finite check + glueshrink）处理 xeCJKfntef 命令右侧 glue 叠在 CJK kern pair 标记上方导致 CJKglue 恢复失败的问题；`\g_@@_ulem_pending_bool` 现有三个 set 点（ulem group / underdot 独立模式 / CJK→Boundary catcode 2）。
- `llmdoc/memory/decisions/826-fntef-color-global-state.md` — 决策: fntef+textcolor 组合时 `\xeCJK_fntef_sbox:n` 的 `\hbox_set:Nn` 内 interchar toks 全局修改 `\g_@@_last_node_tl` 导致 `\set@color` 补丁用错误节点类型重建 kern pair；修复为 hbox 前后保存/恢复该状态。
- `llmdoc/memory/decisions/830-color-wraps-ulem-last-node-tl.md` — 决策: textcolor 包裹 ulem 类 fntef 命令时，ulem `\UL@end` 的 `*` 字符触发 Default→Boundary interchar 转换污染 `\g_@@_last_node_tl`；修复为 `\xeCJK_ulem_right:` / `\__xeCJK_ulem_end:` 前后 save/restore，与 #826 fntef(color) 方向互补。
- `llmdoc/memory/decisions/831-boundary-explicit-brace-ecglue.md` — 决策: #831 显式 `}` / `\mbox` / `\textcolor` 右侧多余 inter-word glue 的三阶段修复：CJK→Boundary handler catcode 2 set 点、`\reset@color` 设置专用 `\g_@@_reset_color_pending_bool`、`\@@_check_for_glue_skip:` 非 kern 三分支（hlist / whatsit 门控 / fallback）。
- `llmdoc/memory/decisions/873-880-fixed-point-vs-default-narrowing.md` — 决策: #873 / #880 选 input-side fixed-point patch（#873 save/replay、#880 drain），不选收窄 `\@@_recover_glue_whatsit:` default 分支——修复位置由被遮蔽的节点类型决定，与 marker 类型无关。
- `llmdoc/memory/decisions/910-verb-drain-vs-drain-verb.md` — 决策: #910 `\verb` 修复用专用 `\@@_drain_ecglue_verb:` 而非复用 `\@@_drain_ecglue:`，关键差别在 else 分支是否 clear `\g_@@_last_node_tl`；ctex `fontset=fandol` 模式下 verb 内 FandolFang CJK → verb 外 FandolSong CJK 仍走 CJK→CJK transition，需保留 tl 状态。
- `llmdoc/memory/decisions/931-biblatex-let-shadow.md` — 决策: #931 biblatex 补丁点选 `\let` 目标 `\blx@pagetracker` 且 hook 时机改用 `\@@_at_end_preamble:n`——补丁点必须挂到宏包内部 `\let` 拷贝的目标而非源，且必须在 `\let` 执行后装 patch，`\@@_package_hook:nn` 对 nested style-load 场景不够晚。
- `llmdoc/memory/doc-gaps.md` — 已知文档与实现缺口追踪。
- `llmdoc/memory/reflections/717-experiment-cjkecglue.md` — 反思: #717 用 `ctex / experiment` 子路径统一暴露实验性 `CJKecglue` 接口，并记录 xeCJK 参数桥接、xkanjiskip 缓存同步与四引擎基线策略。
- `llmdoc/memory/reflections/715-hyperref-driverfallback.md` — 反思: TYPE 展开陷阱、l3build 命令拦截测试技巧。
- `llmdoc/memory/reflections/671-cjkpunct-rglue-nobreak.md` — 反思: CJKpunct #671 修复中的节点级调试技术与 `\unhbox` 测试模式。
- `llmdoc/memory/reflections/704-ctxdoc-patch-health-test.md` — 反思: 为 `support/ctxdoc.cls` 建立 patch 健康检查时，确认 l3build `check` 目标需要用 `checksuppfiles` 显式复制 support 文件，且 nonstop 模式下必须使用 `\msg_critical` 才能把 patch 失败升级为真正终止编译的错误。
- `llmdoc/memory/reflections/735-zhlineskip-split-leading-leak.md` — 反思: zhlineskip #735 split 行距泄漏的根因（TeX 分组层级）、vbox 尺寸回归测试策略与 l3build 框架补建。
- `llmdoc/memory/reflections/465-fntef-font-state-and-underdot-space.md` — 反思: xeCJKfntef #465 中 ulem 下字体状态跨分组丢失 + `\CJKunderdot` 的 `\ignorespaces` 吞空格，及诊断误判的教训。
- `llmdoc/memory/reflections/581-xecjk-zero-width-format-chars.md` — 反思: xeCJK #581 中零宽格式字符应在输入层忽略，而不是进入 interchar 字符分类。
- `llmdoc/memory/reflections/556-verb-xkanjiskip-lltjcore.md` — 反思: ctex #556 中从 autoxspacing 误判修正为”禁用 ltj-latex 后漏掉 lltjcore 的 `\verb` 补丁”，以及基于 `\showbox` 的节点级定位方法。
- `llmdoc/memory/reflections/284-fullwidth-tilde-longpunct.md` — 反思: xeCJK #284 中全角波浪号等连接号的残留问题不在可见空格，而在 MiddlePunct 引入的不必要标点压缩节点；应借助 `\showbox` 对比确认 LongPunct 路径的更干净节点模型。
- `llmdoc/memory/reflections/378-lstinline-hash-doubling.md` — 反思: xeCJK #378 中 `\lstinline` 宏参数 `#` 双写的根因（rescan 的 stringification 再次双写 cat6 `#`）、catcode 12 vs active 的易错点、`\regex_replace_all` catcode class 匹配技巧。
- `llmdoc/memory/reflections/879-lstinline-parameter-tokens-charcode.md` — 反思: xeCJK #879 中 `\lstinline` 下 catcode 6 token 字符码丢失的根因——#378 catcode-class regex 方案的“替换端硬编码 codepoint”局限在 `\catcode\`\&=6` 场景被暴露，改为 `\tl_map_inline:Nn` + `\token_if_parameter:NTF` + `\char_generate:nn { \int_value:w ``##1 } { 13 }` 逐 token 保留原字符码；promotion 时需显式记录适用边界。
- `llmdoc/memory/reflections/407-char-interchar-bypass.md` — 反思: xeCJK #407 中 `\char` 原语被 interchar 拦截的根因、`\char` vs mathcode 语义差异、测试场景设计偏差。
- `llmdoc/memory/reflections/800-char-let-xint-compat.md` — 反思: xeCJK #800 中 `\char` 重定义必须延迟到 `\AtBeginDocument`，避免破坏 xint 等包在加载期 `\let` 保存原语的假设。
- `llmdoc/memory/reflections/315-252-476-xecjk-ecglue-fixes.md` — 反思: xeCJK #252/#476 的 ecglue 字体度量问题与 #315 一样属于 interchar 边界恢复链，应在正确 CJK 字体上下文中缓存前侧 ecglue，并提前按 CI 依赖链完整验证基线影响。
- `llmdoc/memory/reflections/756-802-spa-unicode17-baseline.md` — 反思: #756 XeTeX 字体查找语法陷阱、#802 Unicode 区块同步流程、xeCJK→ctex 跨包基线联动模式。
- `llmdoc/memory/reflections/807-set-color-stale-state.md` — 反思: xeCJK #807 中 `\set@color` 无节点分支未清空 `\g_@@_last_node_tl`，导致首次 `\textcolor` 把初始化阶段残留的 `default` 误送入 whatsit 恢复链并错误插入 ecglue。
- `llmdoc/memory/reflections/809-810-hyperref-annot-ecglue.md` — 反思: xeCJK #809/#810 中 hyperref 注释起始 whatsit 需在 `\Hy@BeginAnnot` 处保存/清空/选择性重放节点状态；`default` 分支保留给 color/xcolor，但不应在注释开始端被重放。
- `llmdoc/memory/reflections/324-boundary-reserve-space-glue.md` — 反思: xeCJK #324 中宏路径提前输出空格 glue 遮蔽 `CJK-space` 标记 kern，破坏 `\lastkern` 边界恢复；修复同时揭示 xeCJK→ctex 的广泛基线联动。
- `llmdoc/memory/reflections/826-fntef-boolean-flag-iteration.md` — 反思: xeCJK #826 fntef glue-on-kern-pair 初始修复后的迭代——`\l_@@_last_skip` 状态污染、`\quad` 误处理、fallback 路径错误的根因与三层过滤收敛过程。
- `llmdoc/memory/reflections/831-reset-color-pending-bool.md` — 反思: #831 colorbox/textcolor 右侧间距修复四轮迭代——从 `\reset@color` 直接插入 kern 对到 `\g_@@_reset_color_pending_bool` 专用布尔延迟处理的收敛过程，核心教训为共享全局布尔的语义过载风险。
- `llmdoc/memory/reflections/873-880-meta-url-hbox-math-boundary.md` — 反思: xeCJK #873 / #880 中 `\HD@target` 的 0x0 hbox 与 `\Url@FormatString` 的 math 模式分别遮蔽边界 marker；混合修复（save/replay vs drain），以及本地 TeX Live usertree 与 CI 漂移导致 7 个 false-positive 测试失败的诊断教训（双步同步 + fmt 重生成）。
- `llmdoc/memory/reflections/910-verb-null-hbox-drain.md` — 反思: xeCJK #910 中 `\verb` 入口 `\leavevmode\null` 0×0 hbox 与 #873 同型遮蔽 marker，但 `\verb` 是分隔符扫描宏不能 save/replay 只能 drain；首版直接复用 `\@@_drain_ecglue:` 在 ctex `fontset=fandol` `verbatim01.xetex` 上 fail，根因是 else 分支主动 clear `\g_@@_last_node_tl` 破坏 verb 内 CJK 字体→外部 CJK 的 CJK→CJK transition；改用专用 `\@@_drain_ecglue_verb:` 保留 tl。
- `llmdoc/memory/reflections/931-biblatex-pagetracker-let-shadow.md` — 反思: xeCJK #931 中 biblatex `authoryear` 通过 `\let\blx@pagetracker\blx@pagetracker@context` 在 bbx 加载时把 pagetracker 行为**值拷贝**——首次 patch 挂在 `\let` 源函数（`\blx@pagetracker@context`）不生效，`\iow_term:x` 打点无输出的假信号误导；正确修法是补丁点改到 `\let` 目标本身 + hook 时机延迟到 `\@@_at_end_preamble:n`（`\@@_package_hook:nn` 对 nested style-load 太早）。补丁点选择的第三维度：目标控制序列的绑定形态（`\def` vs `\let` 拷贝目标）。
- `llmdoc/memory/reflections/878-xunicode-symbols-multilevel-fallback.md` — 反思: xeCJK #878 `xunicode-symbols.tex` 驱动从“整段单字体 if-else”升级为 `FreeSerif → Noto Sans Symbols 2 → Symbola → Segoe UI Symbol → DejaVu Sans` 五级逐字符 `\iffontchar` + `\cs_if_exist_use:N` 链；只适用于演示性符号目录驱动文件，不应推广到正文 / CJK 字体路径。
- `llmdoc/memory/reflections/874-876-agentic-fork-shielding-cron.md` — 反思: #875 / #874 `agentic-*.yml` 同时存在两条边界约束——job 级 `if: github.repository == ...` 把 fork 调度挡在 runner 分配之前，`schedule` 频率回退到每天一次北京时间 08:00；未来新增 agentic 工作流时这两条都应作为默认。
- `llmdoc/memory/reflections/ctex-architecture-doc.md` — 反思: ctex 架构独立文档的创建过程、源码阅读方法与已知文档缺口。
