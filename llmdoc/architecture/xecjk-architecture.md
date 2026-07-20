# xeCJK 架构详解

本文档从整体到局部介绍 xeCJK 的设计原理与实现架构。

## 定位与职责

xeCJK 是 XeLaTeX 下的中文排版引擎，负责：

1. CJK 与西文使用不同字体
2. CJK 字符间自动忽略源码空格
3. 全角标点的压缩与挤压样式
4. CJK 与西文字符之间自动插入间距

它不是一个独立的排版系统，而是构建在 XeTeX 的 interchar token 原语之上的字符间距与字体控制层。在 ctex 体系中，ctex 是统一用户入口，xeCJK 是 XeTeX 后端实现。

## 源码组织

核心几乎全部集中在 `xeCJK/xeCJK.dtx`（约 16000 行），通过 docstrip 生成：

| 产物 | 标签 | 职责 |
|------|------|------|
| `xeCJK.sty` | `package` | 主宏包 |
| `xeCJK.cfg` | `config` | 默认配置 |
| `xeCJKfntef.sty` | `fntef` | 下划线/着重号等文字效果 |
| `xeCJK-listings.sty` | `listings` | listings 宏包兼容层 |
| `xunicode-addon.sty` | `xunicode` | xunicode 符号补充 |

## 核心机制：interchar token

xeCJK 的一切行为都建立在 XeTeX 的 **interchar token 机制**之上。

### 工作原理

XeTeX 允许将每个 Unicode 字符归入一个「字符类」（character class）。当两个相邻字符的类别发生变化时，XeTeX 自动在它们之间插入预定义的 token 序列（`\XeTeXinterchartoks`）。

xeCJK 利用这一机制：
- 在 CJK→西文 边界插入 `\CJKecglue`（中西文间距）
- 在 CJK→CJK 边界插入 `\CJKglue`（字间距）
- 在 CJK→标点 边界触发标点压缩逻辑
- 在进入 CJK 区域时切换到 CJK 字体

### 字符分类体系

xeCJK 定义了以下字符类：

| 类别 | 说明 | 典型字符 |
|------|------|----------|
| `Default` (0) | 西文一般符号 | abc123 |
| `CJK` | CJK 表意符号 | 汉字ぁぃぅ |
| `FullLeft` | 全角左标点 | （《：" |
| `FullRight` | 全角右标点 | ，。）》" |
| `HalfLeft` | 半角左标点 | ( [ { |
| `HalfRight` | 半角右标点 | , . ? ) ] } |
| `NormalSpace` | 前后保持原始间距 | - / \\ |
| `Boundary` (4095) | 边界（空格等） | 空格 |
| `CM` | 组合标识 | 异体字选择符 (IVS) |
| `HangulJamo` | 旧朝鲜文字母类，仅保留兼容入口，不再分配字符 | / |
| `HangulJamoL/V/T` | 朝鲜文字母初声/中声/终声 | ᄻ / ᆟ / ᇫ |
| `CJStarter` | 严格模式下禁止出现在行首的日文小假名等 | ゃっ |
| `PoZheHao` | 支持合字的破折号（opt-in，#382） | U+2014/U+2015 |

XeTeX 0.99994+ 支持最多 4096 个字符类；`Boundary` 固定为最大编号（4095）。

上表"典型字符"为静态举例，非完整枚举。`FullLeft`/`FullRight`/`HalfLeft`/`HalfRight` 的实际成员会随 `LatinPunct` 选项（#389/#431，见下文标点压缩系统一节）动态增减：中西文共用码位的弯引号/间隔号/省略号在 `HalfLeft`/`HalfRight` 与 `FullLeft`/`FullRight` 之间切换归属。

### 特殊 interchar 类：零注入、音节状态机与行首禁则

`PoZheHao` 仍是单类零注入模式：类内不插入任何 interchar token，类间关系复制 `FullRight`，让连续 U+2014 可触发 OpenType 合字；它由 `PoZheHaoLigature` 显式启用，避免不支持合字的字体出现空隙。

#158 证明单个 `HangulJamo` 零注入类不足以表达朝鲜文：它能保持分解音节内部 shaping，却无法区分相邻音节边界，因而会吞掉本应存在的 `CJKglue`。当前实现按 Unicode 17 `Hangul_Syllable_Type` 拆成三类：L 为 `1100..115F`、`A960..A97C`，V 为 `1160..11A7`、`D7B0..D7C6`，T 为 `11A8..11FF`、`D7CB..D7FB`。三类对外复制 `CJK` 转移；仅 UAX #29 的音节延续对 L→L、L→V、V→V、V→T、T→T 清空 interchar toks，其余 L/V/T 组合保留 CJK→CJK 行为。因此音节内连续 shaping，T→L 等音节边界恢复 `CJKglue` 和断行机会。旧 `HangulJamo` 类仅为用户代码兼容保留，不再接收默认字符。

`xeCJK-listings` 对 L 计一个宽度 2 的 CJK 单元，对 V/T 走宽度 0 的组合字符路径；一个分解音节因此与一个预组 Hangul 音节等宽，相邻分解音节仍保留配置的 CJK 字距。

#165 的 `CJStarter` 不是零注入类：它必须复制普通 `CJK` 字距，只在进入该类前增加 `\xeCJK_no_break:`。公开选项 `CJLineBreak=normal|strict` 默认 `normal`，保持历史上把 Unicode `Line_Break=CJ` 当作 `CJK` 的行为；`strict` 把 Unicode 17 CJ 集合改归 `CJStarter` 并插入 penalty 10000。局部布尔 `\l_@@_CJ_strict_bool` 与分组局部的 `\XeTeXcharclass` 状态同步，`\xeCJKResetCharClass` 后按当前选项恢复严格分类。

`FullRight→CJStarter` 必须把 penalty 放在 `\@@_punct_glue:NN` 之前，否则标点胶已经提供断点。该转移封装为 `\xeCJK_FullRight_and_CJStarter:`，并在 `xeCJKfntef` 的 `\@@_ulem_initial:` 交换表中映射到 `\@@_ulem_FullRight_and_CJStarter:`；新增或覆写 CJK 转移时，若 fntef 依赖交换命名 helper 来重写 glue/标点路径，就不能只内联等价 token。`jamo-cj01.lvt` 用 hook 断言严格模式下 `\CJKunderline{。ゃ}` 确实进入 fntef 专用转移。

### 类别间转换矩阵

xeCJK 在 `xeCJK.dtx:3140` 定义了完整的 9×9 类别转换矩阵。核心转换规则：

- **进入 CJK 区域**（`Default/HalfLeft/HalfRight/NormalSpace → CJK`）：开启 CJK 分组、切换字体、输出字符
- **离开 CJK 区域**（`CJK → Default/HalfLeft/HalfRight/NormalSpace`）：关闭分组，后续在 `Boundary → Default` 恢复 ecglue
- **CJK 之间**（`CJK → CJK`）：插入 `\CJKglue`
- **CJK ↔ 标点**（`CJK → FullLeft/FullRight`）：触发标点压缩
- **经过 Boundary**（`CJK → Boundary → Default`）：通过标记 kern 记录边界状态，延迟恢复间距

### 外部分配字符类的 `Others` 兼容层（#336）

xeCJK 在导言区结束时比较 XeTeX allocator 与自身已登记类，发现其他宏包或用户在加载 xeCJK 后新建的 interchar class 后，逐个调用 `\@@_set_others_toks:n`。该函数把外部类临时映射为 `Others`，对每个 `\g_@@_CJK_class_seq` 成员复制 `NormalSpace` 模板，并把用户已定义的 `external ↔ Default` tokens 传播到对应的 `external ↔ CJK-class` 转换；空缺的 Boundary 转换也从 Default 模板补齐。

这是一层兼容机制，不是“任意类继承任意模板”的公开 API。#336 的 URL 场景只需在导言区结束前定义 slash class 与 `slash → Default` 的断行 action，CJK 方向会自动派生；若到正文期才赋 transition，已经错过传播时机。调查既要检查现有能力，也要验证加载顺序：旧 MWE 中手写的五行内部转换不是概念上必需，但在其原始正文期赋值顺序下确实无法被导言区末尾机制看到。决策见 [[../memory/decisions/336-external-interchar-class-others]]。

### 逐字符装盒变换不是局部可加的 class hook（#347）

#347 的 plain XeTeX 原型证明 interchar transition 可以开盒、捕获字符并交给旋转或基线移动函数；迁移到 xeCJK 后，所有可能离开特殊类的边界都必须闭合盒子，包括同类→同类与特殊类→`FullRight` 等路径。只实现 `CJK`/`Boundary` 两侧会把相邻同类字符合进一个盒子，并在后接全角标点时留下未闭合分组。

更根本的边界是处理单位：逐 code point 装盒会切断 IVS、Hangul Jamo 和其他 OpenType shaping 序列，hbox 还会遮蔽基于 `\lastkern` 的边界标记。该原型不在当前状态机上产品化；若未来整体重构输入、fallback、标点和节点生成，应把“捕获 shaping 后的字形簇并统一变换”作为正式流水线阶段，而不是继续补 class pair。决策见 [[../memory/decisions/347-boxed-glyph-transform-prototype]]。

### CJK→Boundary handler（`\xeCJK_CJK_and_Boundary:w`）

`\XeTeXinterchartoks` 中 CJK→Boundary 的处理函数。Boundary class (255/4095) 由以下情况触发：

- 源码空格
- 显式 `{`（catcode 1）和 `}`（catcode 2）
- `\ `（control space）

注意：`\bgroup` / `\egroup`（隐式花括号）**不**触发 Boundary class，因为它们是控制序列而非 catcode 1/2 字符。

handler 在执行时会 peek 下一个 token：
- 若 peek token 是 catcode 2（`}`）：说明当前正在退出一个 TeX 分组（如 `前{中} 后` 中的 `}`），分组结束后会恢复局部变量（包括 `\l_peek_token`），因此必须在 `\@@_boundary_group_end:n` **之前**设置 `\g_@@_glue_check_pending_bool`，以确保后续的 inter-word glue 被正确识别
- 若 peek token 是控制序列（如 `\ `）：不设置 boolean，区分于 catcode 2 的情况

## 边界恢复状态机

这是 xeCJK 最复杂的子系统。直接相邻字符可由 XeTeX interchar class 转换决定间距；一旦中间出现分组、命令、盒子、math 或 whatsit，恢复链还必须保存边界证据、观察命令的实际输出类别，并在节点遮蔽后重建等价边界。

### 基础 marker 与 glue 恢复链

`\xeCJK_make_node:n` 用一对微小 kern 编码最近的可见边界。当前恢复链识别 `CJK`、`CJK-space`、`CJK-widow`、`default`、`default-space`、`normalspace`；#972 曾引入的 `hyperref-default` 已由 annotation stream 吸收并删除。`\g_@@_last_node_tl` 保存语义状态；`\lastkern` / `\lastnodetype` 提供当前列表上的节点证据。两者必须一致，不能只凭可能陈旧的全局 tl 恢复间距。

CJK→Boundary 时，`\@@_boundary_group_end:n` 在仍处于正确 CJK 字体上下文时缓存 `\CJKecglue` 到 `\l_@@_ecglue_skip`；后续恢复使用缓存值，不在命令内部的新字体或字号下重新测量。`\@@_boundary_reserve_space:` 只留下 `CJK-space` marker，不抢先输出会遮蔽 marker 的普通 glue。

Boundary→CJK 的 `\xeCJK_check_for_glue:` 与 Boundary→Default 的 `\xeCJK_check_for_ecglue:` 都先读取可信 marker，再处理压在 marker 上方的源码词间 glue。`\g_@@_glue_check_pending_bool` 是唯一通用门控，由显式分组与 capture 重放可信 CJK marker 时设置；颜色、fntef 等历史专用 pending 已删除。

Boundary→Default 方向由 `\@@_recover_ecglue_source_space:` 暂时移除末尾的候选 glue，再检查其下方节点。候选必须是 finite、带 shrink、自然宽度等于当前词间空格，并且下方确有 `CJK` / `CJK-space` / `CJK-widow` marker；命中后才用缓存的 `\CJKecglue` 替换并清除 pending，未命中则原样还回。该路径补齐了历史上只在 Default→CJK 方向处理源码空格的非对称缺口。

任意 whatsit 或 hlist 仍不能自行成为恢复证据。已知不可见命令使用 transparent capture，盒命令使用 box/wrapped-box，URL 与 codedoc meta 使用完整 stream；基础恢复链不再按任意节点类型猜测 `\g_@@_last_node_tl`。#803 证明了“看到 whatsit 就信任全局 tl”会在引用内部制造错误 ecglue。

### 命令边界的输出等价契约（#491/#992）

命令包装前后的间距以命令实际排出的首、尾可见字符类别为准，不以命令名、参数写法或历史补丁为准。西文和数字按 Default 处理；CJK 输出按 CJK 处理；混合输出的左右两端分别判断；无可见输出的命令应对相邻可见字符透明。

直接输入是唯一语义 oracle。`10` / `01` 分别表示只在左侧 / 右侧边界有源码空格：

| 源码空格 | CJK–西文–CJK | 西文–CJK–西文 |
| --- | --- | --- |
| `11` | `中文 English 中文` | `English 中文 English` |
| `01` | `中文English 中文` | `English中文 English` |
| `10` | `中文 English中文` | `English 中文English` |
| `00` | `中文English中文` | `English中文English` |

纯 CJK 输出还要分别以 `中文 中文 中文` 和 `中文中文中文` 为有、无源码空格 oracle。理想覆盖是“实际输出首尾类别 × 相邻字符类别 × `00/10/01/11`”的全部可表达组合。若引擎机制确实无法区分某些输入，最低保证仍包括有源码空格的中西文切换（如 `中文 \foo{en} 中文`）和无源码空格的纯 CJK（如 `中文\foo{中文}中文`）；其余限制必须给出机制证据与稳定 workaround。

#491 的历史回归通常只覆盖一个命令的一个单元，不能推出整类完成。#992 取代 #491 作为长期状态入口。PR #999 的原型矩阵在固定提交上全绿，但 #992 的活表只记录已合并状态：合并前可在 PR 上保存拟更新预览，不能提前把原型结果写回 issue 活表。

### capture/register 框架（#992 / PR #999）

`\@@_boundary_capture_begin:` 在已注册命令入口执行四件事：

1. 在入口字体与选项上下文中缓存普通词间空格、`\CJKecglue`、`\CJKglue`、`CJKspace` 与 `xCJKecglue` 状态。
2. 保存并移除紧邻入口的源码空格和可信 marker，清空普通恢复状态。
3. 启动一层 capture；Boundary↔CJK 的 interchar transition 会通过 `\@@_boundary_capture_class:n` 把实际 `CJK` / `default` 类别写入所有未暂停的活跃层。
4. 首次观察记录首类别，随后更新末类别；外层 capture 因而也能观察内层命令，混合输出自然得到不同的首尾类别。

结束路径按“入口前类别 × 实际首类别 × 左侧是否有源码空格”重建左边界，排回盒子或保留原节点流，再把实际末类别重放为 marker，让正常 Boundary→CJK/Default 恢复链决定右边界。未观察到可见字符时，入口 marker 与源码空格原样恢复。

注册层把命令形状与恢复算法分开：

| 策略 | 节点形状与结束动作 | 当前典型入口 |
| --- | --- | --- |
| `box` | 命令只留下一个末尾 hbox；取出原盒、重建左边界、原样放回并重放末类别 | `\mbox`、`\fbox`、`\makebox`、`\framebox` |
| `wrapped-box` | 命令可能直接写多个节点；用透明 hbox 收集，若无可见输出则解包 | `\colorbox` / `\fcolorbox` 的 `\color@b@x` |
| `stream` | 内容直接写当前列表；首类别一出现就补左边界，结束时重放末类别 | hyperref annotation、`\@setref` / `\real@setref`、完整 URL、`\verb`、`\eqref`、`\meta`、`\cs`、`\lstinline` |
| `transparent` | 命令只有锚点、write、颜色 push/pop 等不可见节点；结束后完整恢复入口状态 | `\HD@target`、`\blx@pagetracker`、`\set@color` / `\reset@color`、l3color 后端 |
| `post-transparent` | 只能使用 after hook；仅在零尺寸尾盒确实遮蔽 marker 时把可信状态移到盒后 | 一般 `\null` |

`auto` 使用实际首尾类别；`default` 固定两端为 Default；`first-default` 只固定首端、末端仍取实际输出。`\eqref` 的括号和 `\meta` 的尖括号决定两端为 Default；`\cs` 只有开头反斜线固定为 Default。box 的 `default` 在结束函数同时覆盖首尾，stream 则在开始 hook 固定首端、结束 hook 固定末端，两条路径的公开语义相同。

`\g_@@_boundary_registered_prop` 阻止同一命令重复注册。常用前两层 capture 的 box/tl register 在加载时预分配，第三层起按首次达到的 depth 惰性创建；`\g_@@_boundary_active_seq` 保证 before/after hook 成对，数学模式与暂停状态只压入 inactive 标记。测试已覆盖 12 层盒嵌套。

`\sbox` 只构造离线 scratch box，不应把测量内容报告成外层命令的可见输出。因此 `cmd/sbox/before` / `after` 分别调用 `\@@_boundary_capture_suspend:` / `resume:`；暂停深度可嵌套，并按层保存/恢复 `\g_@@_last_node_tl` 与 source-space pending，结束后必须归零。

ulem 把正文拆进固定宽度字盒，普通 stream 若直接在首次观察处排 glue，会把弹性间距和装饰 leader 一起困进内部盒。`stream-ulem` 仍由 framework 决定 glue 类型和值，但在 ulem 活跃时通过 `\UL@stop`、普通 `\hskip`、`\UL@start` 把 glue 排到外层且不画线；独立符号命令走普通 skip。包内线型命令在装饰符号测量前请求启动该 stream，原生 `\uline` 等入口由 `\ULon` 补上；二者共用“仅最外层启动”协议，因为嵌套路径会走 `\UL@onin`，没有与重复 begin 对应的独立 end。所有嵌套线型命令复用最外层 stream，由公共结束点唯一收束。

### 右侧源码空格的机制边界

TeX 节点列表不保留“这枚 glue 来自源码空格还是显式 `\hskip`”的来源标签。注册命令结束后，如果用户显式写出的 glue 与当前词间空格具有相同自然宽度并带 shrink，它与源码空格节点完全同构；`\@@_recover_ecglue_source_space:` 在 pending 窗口内无法可靠区分二者。

框架因此只在严格条件下检查：pending 必须来自已知路径，候选必须 finite、带 shrink、自然宽度相同，下方还必须是可信 CJK marker。需要保留这种完全同构的显式 glue 时，在它前面加 `\kern0pt`；也可以改变自然宽度或移除 shrink，使检查过程无法越过显式边界到达 marker。`command-boundary02` 同时锁定歧义和 workaround，避免把机制限制误写成偶发现象。

### 旧边界补丁的吸收结果

#999 的完成条件是删除生效的逐命令边界恢复算法，而不只是让它们与 framework 并存。当前分工如下：

- `\@setref`（无 hyperref）或 `\real@setref`（hyperref 保存的内核副本）直接注册为 `auto` stream；一般 `\null` 仍用 post-transparent。#991 的 `\null\fi` 文本替换、saved-node 与源码空格专用 replay 已删除。
- hyperref 从 `\Hy@BeginAnnot` 到顶层 `\Hy@EndAnnot` 使用 `auto` stream；末尾 math 报告 Default。入口 save/replay、结束端专用 `hyperref-default` marker 均已删除。
- URL 在完成花括号/分隔符扫描后的完整 `\Url@z` 外包围 `default` stream；不再按“当前是否已有 capture”分支，也没有 URL drain。
- `\verb` 使用 `auto` stream；`\@@_flush_language_whatsit:` 只负责让延迟 language whatsit 在 stream 结束前真实进入列表，不判断或恢复边界。`\verb*` 与 shortvrb 共用入口和出口。
- codedoc/doc 的 meta 保留参数 hbox，只为阻断尖括号与 CJK 参数之间不应有的内部 ecglue；完整外侧由 `default` stream 处理，旧 drain 已删除。
- color/xcolor 的 `\set@color` / `\reset@color` 与 l3color 后端使用 transparent capture，`\color@b@x` 使用 wrapped-box；颜色专用 saved marker、hlist/whatsit fallback 与 pending 已删除。l3color 包装器只保留原参数签名。
- biblatex 在 preamble 结束后把最终 `\let` 目标 `\blx@pagetracker` 注册为 transparent；旧的单向 clear 逻辑已删除。
- xeCJKfntef、原生 ulem 与独立 under-symbol 入口使用 `stream-ulem` / stream；旧的 saved-last-node、颜色状态隔离和直接 pending 设置由 capture suspend/replay 取代。ulem 外层 glue callback 只解决装饰与断行节点位置。
- `\lstinline` 的分隔符和花括号扫描入口都启动 `auto` stream，并在共同 `\lst@DeInit` 结束；listings 的 parameter-token rescan 修正属于内容扫描语义，不承担边界恢复。

剩余适配器只处理第三方私有签名、扫描时机、加载时序或命令内部排版语义，均复用共享 begin/end 和 marker/glue 原语。详细决策见 [[../memory/decisions/992-command-boundary-capture-register]]；测试方法见 [[../reference/build-and-test]]。#873/#880/#910/#931/#972、#826/#830/#831 与 #991 的旧 decision/reflection 记录演进路径，不能再当作当前实现说明。

## 字体管理

### 分层设计

```
用户接口层:  \setCJKmainfont, \setCJKsansfont, \setCJKmonofont
             \newCJKfontfamily, \setCJKfamilyfont
                      ↓
xeCJK 内部:  \xeCJK_set_family:nnn  →  NFSS 字体族注册
                      ↓
fontspec:    底层字体加载与 OpenType 特性处理
```

### 字体切换时机

字体切换发生在 interchar token 触发的 CJK 分组入口处（`\xeCJK_select_font:`）。即：只有当 XeTeX 检测到字符类从非 CJK 切换到 CJK 时，才会执行字体切换。CJK 区域内部字符间不重复切换。

### 字体选择与间距语义并非引擎级绑定（#553）

XeTeX 虽然规定每个字符只能属于一个 `\XeTeXcharclass`，但字符类本身只选择一组 `\XeTeXinterchartoks`，不会在引擎层把“使用哪套字体”与“插入哪种间距”绑定。#553 的普通文本原型新建混合类，复制 `Default` 的全部相邻类转换，并只在进入/离开该类时增加 `\xeCJK_select_font:` 的分组开关；节点列表确认 ASCII 数字可用 CJK 字体输出，同时在 CJK–数字边界保留 `\CJKecglue`、在字母–数字边界不产生 glue。因此，类似需求不能简单判定为“XeTeX 无法实现”。

这项可行性不等于现有架构适合公开混合类。`\g_@@_non_CJK_class_seq` 与 `\g_@@_CJK_class_seq` 把字体选择、标点转换、Boundary 恢复、listings 单元和 fntef 转换建立在 CJK/非 CJK 二分上；“字体语义属于 CJK、间距语义属于 Default”的类无法自然归入任何一边。正式实现前必须反向审计所有直接枚举旧类或复制旧类转换的位置，并覆盖数学、verbatim/listings、fntef/ulem、fallback、字体族/字重切换、颜色、链接和外部分配字符类等路径。

若目标内容可在源文件中明确标记，低风险方案是保持字符的 `Default` 类，只用局部 `\newfontfamily` 命令切换所需数字；这会自然复用现有间距转换。若要求全局按字符范围自动选字体，真实问题属于 range-to-font/composite-font 路由，还必须先明确数学、计数器、页码、引用、URL、代码以及字体族/字形跟随规则，不能收窄成 ASCII 数字特例。#553 因证据不足且产品化影响面过广，以 `not planned` 关闭；决策见 [[../memory/decisions/553-mixed-font-spacing-class-not-planned]]。

### 后备字体 (Fallback)

xeCJK 支持为 CJK 字符范围设置后备字体链。当主字体不包含某字符时，按优先级尝试后备字体。实现基于 `\setCJKfallbackfamilyfont` 和内部的 `\xeCJK_fallback_symbol:NN` 检测机制。

### AutoFakeBold / AutoFakeSlant

当 CJK 字体没有对应粗体/斜体变体时，xeCJK 可通过 XeTeX 的 `embolden` / `slant` 特性自动伪造。通过 `AutoFakeBold` 和 `AutoFakeSlant` 选项控制。

## 标点压缩系统

### 核心依赖

标点压缩依赖 XeTeX 的 `\XeTeXglyphbounds` 原语获取字符的左右边距（side bearings），从而计算需要压缩的空白量。

### 标点样式 (PunctStyle)

xeCJK 预定义了多种标点样式：

| 样式 | 说明 |
|------|------|
| `quanjiao` | 全角：标点占一个汉字宽 |
| `banjiao` | 半角：标点压缩到半个汉字宽 |
| `kaiming` | 开明：句末标点全角，其他半角 |
| `hangmobanjiao` | 行末半角：行末标点压缩 |
| `CCT` | CCT 风格 |
| `plain` | 无压缩，原样输出 |

可通过 `\xeCJKDeclarePunctStyle` 自定义。

### 标点间 kern 计算

相邻标点的压缩量通过 `\xeCJKsetkern` 手动设置或由样式规则自动计算。内部通过 `g_@@_punct/kern/<char1>/<char2>/tl` 属性表存储。

标点函数的结果按 `(标点字体, PunctStyle 风格, 字符)` 三元组缓存（`\@@_punct_csname:n` 生成的属性表键名）。这意味着任何对压缩公式本身的修改，一旦落地即对全部非 `plain` 风格（`quanjiao`/`banjiao`/`kaiming`/`hangmobanjiao`/`CCT`）自动生效，无需分别适配。

### 破折号（U+2014）宽度算法（#382）

CLReq（《中文排版需求》）要求连续破折号总宽随连用数量线性增长（n 个连用 U+2014 占 n 个汉字宽），但破折号所属的 `LongPunct` 类原始压缩公式只保证"中间连续无缝"，不保证总宽不变量。`\@@_long_punct_kerning:N` 与 `\xeCJK_punct_margin_process:NN` 两处联动修复覆盖了这一缺口，两者都要应对同一个根源问题：**不同字库对"破折号字面（glyph ink，`dimen`）"与"破折号字框（advance width，`width`）"的关系定义差异巨大**——中易系字库字面窄于字框、方正兰亭黑字面溢出字框、微软雅黑字框本身宽于字号。任何单一公式都无法同时兼容三类字库。

**中间压缩量（`\@@_long_punct_kerning:N`）**：原公式 `kern = -max(bound_l + bound_r, 0)` 只用两侧 side bearing 之和，仅对"字面居中于字框、字框等于字号"的理想字体成立。修复为 U+2014 专用三路取大（`width` 为字框宽，`dimen` 为字面宽，`F` 为当前字号 `\f@size`，取值下界为 0 因为破折号边界可能为负，如方正新书宋）：

```
kern = -max( bound_l + bound_r,
             dimen + width - 2F,
             2*width - 2F,
             0 )
```

注意 `0` 下界在代码中不是显式的第四路取大：第一路 `bound_l + bound_r` 在进入三路取大之前已被 `\dim_max:nn { ... } { \c_zero_dim }` clamp 为非负，外层 max 含有一个 ≥ 0 的操作数，故结果必然 ≥ 0（kern ≤ 0），不会产生扩张 kern。

三项分别覆盖：`bound 和` 对应字面窄于字框（中易系），`dimen+width-2F` 对应字面溢出字框（方正兰亭黑），`2*width-2F` 对应字框本身宽于字号（微软雅黑）。省略号 U+2025/U+2026 连用不需要压缩，保持零 kern；其余长标点（U+2E3A 二の字点、全角浪线等）行为不变，仍走原 bound 和压缩公式。

**两端补偿 margin（`\xeCJK_punct_margin_process:NN`）**：破折号属于 `MiddlePunct`，原公式两端各补偿 `(目标宽 - dimen) / 2`（各半份空白，使标点在其目标宽度内居中）。但对未启用合字的 U+2014，连用时中间被上面的 kern 挤掉的空白，恰好等于单个字符两端总空白（而非半份），若仍按半份补偿，连用总宽会系统性偏差。修复为新增条件 `\@@_punct_if_full_margin_dash:N`（判定：字符是 U+2014 且未被归入 `PoZheHao` 类），成立时补偿两端**各一整份**（不除以 2）。该条件同时作用于 margin 计算本身与它传给 `\@@_save_punct_skip:nNNnnn` 的 glue plus（stretch）分量——两处必须保持同一份"是否除以 2"的判断，否则自然宽度与弹性分量会不一致。

代价（相对 CLReq 理想值的已知偏差，均在可接受范围）：单个 U+2014 略超 1 字宽（约 1.087 ccwd），三连略欠 1 字宽（约 2.913 ccwd）——这是"仅调整两个自由度（kern、margin）去满足两个不变量（中间无缝、总宽正确）"必然存在的近似残差，测试 `dashwidth01.lvt` 对此按已知值断言而非要求精确 2.0/3.0。

### PoZheHao 字符类（合字 opt-in，#382）

阶段 1 的公式修正只解决"未合字"场景的宽度问题。对提供 OpenType 破折号合字特性的字体（如思源宋体、思源黑体：连续两个 U+2014 被替换为一个两倍字宽的合字字形），interchar 机制默认会在标点处理时于两个 U+2014 之间注入 token，从而阻断 OpenType shaping 层看到"相邻"两个字符、无法触发合字。

修复采用零注入字符类模式（见上文字符分类体系）：新建 `PoZheHao` 类，类内（U+2014↔U+2014、U+2014↔U+2015）不插入任何 interchar token，交由字体自身的合字特性处理；类间关系复制自 `FullRight`，保证破折号与其他标点/CJK 相邻时仍按全角右标点语义处理。

工程细节与踩坑记录：

- **`\@@_punct_if_right:N` 必须承认 `PoZheHao` 类**：若不修改，「标点+破折号」相邻（如“爱。——”）时，该函数误判 U+2014 不是全角右标点，导致下游取用不存在的 `dim/glue/left/—/tl` 一类缓存键报 `Missing number`。这是 2018 年该功能原型中就已踩过的坑（回归测试 `dashwidth01.lvt` 专门覆盖"标点后接破折号"场景以固化此教训）。
- **`\xeCJKResetPunctClass` 与状态恢复**：该命令会重新声明 `FullRight` 类，导致 U+2014 被重新拉回 `FullRight`（覆盖掉 `PoZheHao` 归类）。为此 `PoZheHaoLigature` 的开关状态记录在布尔 `\l_@@_pozhehao_ligature_bool`（局部，见下文 #431 影子布尔作用域一致性说明）中，`\xeCJKResetPunctClass` 执行尾部按该布尔值自动恢复 `PoZheHao` 类声明，避免用户重置标点类后合字状态跟着丢失。
- **`PoZheHaoLigature=false` 的恢复目标**：U+2014 → `FullRight`，U+2015 → `Default`（普通类，编号 0）。注意 U+2015（水平线）自 v3.3.3 起已不属于 `FullRight`，这一点在本次修复中被实测验证，不能想当然认为两个字符对称恢复到同一个类。
- **为什么是用户 opt-in 而非自动探测**：合字能力完全取决于字体（多数国产字库不提供），XeTeX 没有可靠原语能在不实际 shape 的情况下探测某字体是否具备特定 OpenType 合字特性；对不支持合字的字体启用 `PoZheHaoLigature` 会让连续破折号中间露出空隙（因为零注入类不再提供任何补偿）。因此设计为显式 `\xeCJKsetup{PoZheHaoLigature}` 键控制，且需要用户自行配合开启 `fwid`/`locl` 等 OpenType 特性以获得全角字形。

### LatinPunct 选项：中西文共用码位标点的字体切换（#389/#431）

部分 Unicode 码位是中西文共用的：弯引号 U+2018/U+2019/U+201C/U+201D、间隔号 U+00B7、省略号 U+2025/U+2026/U+2027。xeCJK 默认把它们归入全角标点类（`FullLeft`/`FullRight`），用 CJK 字体输出全角字形。在以西文为主的文档中，这会导致夹在英文单词内部的撇号（如 `Children's` 中的 U+2019——输入法/编辑器的 smart quotes 默认产生这一码位）被排成突兀的全角形式（Issue #431，原型讨论见 #389）。

`\xeCJKsetup{LatinPunct}` 提供归类切换：

| 值 | 归类 | 效果 |
|---|---|---|
| `true`（默认） | U+2018/U+201C → `HalfLeft`；U+00B7/U+2019/U+201D/U+2025/U+2026/U+2027 → `HalfRight` | 西文字体输出，不参与标点压缩 |
| `false` | 对应码位恢复 `FullLeft`/`FullRight` | CJK 字体输出全角字形，参与标点压缩 |

字符集选择归入 `Half*` 而非 `Default`（编号 0）：`Half*` 类保留了半角标点固有的 interchar 间距语义（如与 CJK 字符相邻时的 `\CJKecglue` 处理），`Default` 类语义更泛化、不专属于标点。字符集范围与 `true`/`false` 的处理动作沿用 Issue #389 中 `RuixiZhang42` 提出的 `\xeCJKUseLatinPunct` switch 原型。

**与 `PoZheHaoLigature` 的正交性**：破折号 U+2014、二の字点 U+2E3A 与半字线 U+2013 刻意排除在 `LatinPunct` 字符集之外——它们属于上文 `PoZheHaoLigature`/CLReq 两字宽处理语义，两个选项分别控制不同的字符子集，互不干扰（`dashwidth01.lvt` 与 `latinpunct01.lvt` 均覆盖"破折号不受另一选项影响"的断言）。

**`\xeCJKResetPunctClass` 恢复链**：与 `PoZheHaoLigature` 并列，`\xeCJKResetPunctClass` 重新声明 `FullLeft`/`FullRight` 会覆盖 `LatinPunct` 的归类调整；重置尾部按 `\l_@@_latin_punct_bool` 用 `\keys_set:nn { xeCJK / options } { LatinPunct = true }` 重放（`PoZheHaoLigature` 走同样的重放模式）。目前标点压缩系统里有两个选项走这一恢复模式。

#### 影子布尔的作用域必须与被控资源的作用域一致（#431 工程教训，回溯修正 #382）

初版 `LatinPunct` 状态记录沿用 `PoZheHaoLigature` 既有写法，用全局布尔 `\g_@@_latin_punct_bool`。实测暴露 bug：`\XeTeXcharclass` 赋值本身是 **TeX 分组局部**的——`{\xeCJKsetup{LatinPunct=false} ... }` 退出分组后字符类自动恢复为分组前的值，但全局布尔不会随分组恢复。此后一旦在分组外调用 `\xeCJKResetPunctClass`，就会按已经过时（不再反映当前字符类真实状态）的全局布尔值错误重放。

修复为局部布尔 `\l_@@_latin_punct_bool`，使"记录当前配置"的影子状态与被记录的 `\XeTeXcharclass` 赋值同处于同一 TeX 分组作用域，开组切换、退组恢复能同步生效。

**同一提交顺带修正了 `PoZheHaoLigature`**：`\g_@@_pozhehao_ligature_bool` 存在完全相同的作用域不一致问题，只是此前没有"分组内切换"的测试场景覆盖，未被触发。本次一并改为局部 `\l_@@_pozhehao_ligature_bool`。

**通用教训**：任何"记录某个局部资源（TeX 分组局部生效的原语赋值）当前配置"的影子状态变量，其作用域必须与被记录资源本身的作用域一致——用全局变量记录局部状态，在跨分组场景下必然产生状态与实际不符的窗口期。这一教训同样适用于未来任何基于 `\XeTeXcharclass`/`\catcode` 等分组局部原语的 opt-in 开关设计。

详见决策 [[431-latinpunct-option]]。

### 标点度量的 feature-blind 限制（架构级边界，#382 复测发现）

xeCJK 所有标点尺寸（`dimen`/`width`/`bound` 等）均通过 `\fontcharwd` 与 `\XeTeXglyphbounds n \XeTeXcharglyph` 获取。`\XeTeXcharglyph` 是**基于 cmap 的直接字符→字形编号查找**，不经过 OpenType shaping 管线，因此 `locl`（区域本地化替换）、`fwid`（全角变体替换）等 GSUB 特性替换掉原字形后，xeCJK 拿到的度量仍然是替换前那个"幻影字形"的度量，不会随特性生效而更新。

这是一个已知且当前无法绕过的架构限制：没有原语能取得"shaped 后"的字符度量——advance width 尚可通过临时 `\hbox` 实测宽度间接获得，但 side bearing（字形左右边距，标点压缩公式的关键输入）没有对应的原语或测量手段。

已知表现（本次修复中实测确认）：裸 Noto Serif CJK SC（未显式开启 `RawFeature=+fwid`）的连用破折号总宽仍是修复前的 1.78 ccwd 而非 CLReq 要求的 2.0，因为 `\XeTeXglyphbounds` 拿到的是全角替换前的窄字形边界；显式开启 `fwid`/`locl` 后（如 `\setCJKmainfont{Noto Serif CJK SC}[RawFeature=+fwid]`）度量与视觉字形一致，总宽达标 2.0。诊断这类问题时，`fontcharwd`/`\XeTeXglyphbounds` 在同一字体、开关某 OpenType 特性前后返回值恒定不变，本身就是"此路径 feature-blind"的直接证据，无需深入 shaping 引擎即可确认根因。

### #975 的预设修正与方向性标点对策略（#443、#481、#488、#511）

xeCJK v3.10.3 用三项窄修覆盖了 #443、#481、#488，同时保留现有 `PunctStyle`、显式字符对设置和禁则行为。#511 所讨论的完整标点模型重构仍是长期边界。

| Issue | v3.10.3 行为 | 实现与回归证据 |
|---|---|---|
| #443 开明式句末点号宽度 | `kaiming` 的 `mixed-punct-ratio` 从 `0.8` 改为 `1.0`；FandolSong 10pt 下 `字。字` 的句号贡献 10pt，`字，字` 的句内标点仍为 5pt | 只修改 `kaiming` 预设；`punctuation-model-975.lvt` 同时断言句末、句内和相邻标点，既有 `kaimingpunct01`/`punctstyle01` 固化节点基线 |
| #481 港台/日文居中标点相邻时过度挤压 | `quanjiao` 默认启用 `optimize-kerning`，用两枚标点的实际边界下限约束通用 pair kern | 专用 Noto Serif CJK TC 字体面下 `。』？！` 从旧路径 26.04pt 恢复为 31.82pt，JP 字体面从 25pt 恢复为 27.19pt；不能用 `Language=` 替代专用字体面，因为 `\XeTeXglyphbounds` 不观察 GSUB 后字形 |
| #488 `FullLeft→FullRight` 不应压掉自然空白 | 新增 `enabled-left-right-kerning` 样式键，默认 `true`；`quanjiao` 设为 `false`，只取消左标点后接右标点的自动压缩 | Noto Serif CJK SC 下 `（？` 与插入零 kern 阻断自动压缩的自然参考等宽；显式 `\xeCJKsetkern`、`enabled-global-setting=false`、`banjiao`、nobreak 调用、`FullRight→FullLeft` 与 `）（` 均有独立断言 |
| #511 标点模型重构讨论 | 当前实现仍使用 `FullLeft`/`FullRight`、special-punct 列表、单个 `PunctStyle` 实例和 feature-blind 度量 | #975 修正三个具体默认值/策略，不处理语义化句末传播、文种/书写方向 profile、竖排、GSUB 后度量或通用有向 pair matrix |

方向策略落在标点样式层，而不是直接改 `FullLeft→FullRight` transition。`\@@_save_punct_kerning:NN` 必须先 `\UseInstance` 载入当前样式，再判断字符对方向；只有前标点不是 `FullRight` 且后标点是 `FullRight` 时进入 `\@@_save_left_right_kerning:NN`，反方向和同侧组合仍走通用计算。关闭自动压缩时保存零 kern，但原 transition 中的 `\xeCJK_no_break:` 不变，因此自然空白不会变成可断点。

这一层次还保留了两个既有优先级。若 `enabled-global-setting=true` 且该具体字符对存在 `\xeCJKsetkern` 记录，显式设置仍进入通用计算并优先生效；若全局设置关闭，则忽略该记录并保留自然空白。`banjiao`、`kaiming`、`CCT` 和未改写此键的自定义样式继承默认 `true`，保持历史压缩。若在 transition 中无条件跳过 kern，这些样式与显式覆盖都会被一并破坏。

#443 的比例修正只解决“被列入 `KaiMingPunct` 的单个字符宽度”。#511 指出的“真・开明”还包括句末语义跨越右引号等标点传播，因此不能把该比例改动描述成完整的开明式重构。完整方案仍应把 opening/closing 禁则角色与字面位置/可压缩性分离，由文种和书写方向 profile 选择字符属性，再以有方向的 pair matrix 生成 glue/kern/penalty；迁移时保留现有 `PunctStyle` 与 `\xeCJKsetkern` 作为兼容层。

### 长标点断点的两侧禁则检查（`\@@_punct_kern:NN` / `\@@_punct_kern_break:NN`，#456）

v3.6.0（2018/01/23）起，长标点（`LongPunct`，如 U+2014 破折号、U+2026 省略号）与其他标点相邻时的断点策略是"只要一侧是长标点就总允许折行"（`\@@_punct_if_long:NTF #1 { breakable }`）。这只保证了"长标点内部不误断"，未检查断点另一侧是否违反通常的标点禁则，导致三类硬性违规：

- `“——`：可在左引号（`FullLeft`）后断行 → 全角左标点悬于行尾
- `——，` / `——。`：可在逗号/句号（`FullRight`）前断行 → 全角右标点落于行首
- `——……`：可在省略号前断行 → `NoBreakLongPunct`（见 #681）落于行首；v3.10.0（2026/04/27）只修了"右侧是长标点"这一支，"右侧是 `NoBreakLongPunct` 但左侧是长标点"的组合依然漏判

修复重写 `\@@_punct_kern:NN` 的决策树：外层先用 `\bool_lazy_or:nnTF { long_p #1 } { long_p #2 }` 快速筛掉"两侧都不是长标点"的常规情形（保持原有 nobreak 行为不变），只要有一侧是长标点，才进入新增的 `\@@_punct_kern_break:NN` 做两侧禁则联合判断：

- 断点之前（`#1`）必须是全角右标点（`\@@_punct_if_right:NTF`，`PoZheHao` 类也被承认为 right，见上文 #382）或长标点——否则全角左标点会悬于行尾；
- 断点之后（`#2`）必须是全角左标点，或者是长标点且**非** `NoBreakLongPunct`——否则全角右标点或省略号等会落于行首。

两条件同时满足才走 `\@@_punct_breakable_kern:NN`，否则走 `\@@_punct_nobreak_kern:NN`。合法断点保留：`，——`、`……——`、`——（` 仍可断（右侧是长标点或左标点，左侧是全角右标点）。

工程坑位：

- **两类条件函数的参数形态不同**：`\@@_punct_if_right:N`（`prg_new_conditional`，内部用 `\xeCJKtoken_value_class:N` 查询 `\XeTeXcharclass`）要求参数是**字符记号**；而 `\@@_punct_if_long:N`（special punct clist 机制生成，内部 `\if_cs_exist:w` 判断缓存 csname 是否存在）可以直接吃 **tl 变量**作为 `#`-参数。`\@@_punct_kern_break:NN` 的 `#1` 来自 `\g_@@_last_punct_tl`（tl 类型），参与 `\@@_punct_if_right:NTF` 前必须先 `\exp_after:wN` 展开成字符记号，而参与 `\@@_punct_if_long_p:N` 判断时可以直接传 tl，不需要展开。混用这两类条件时必须先确认各自的参数形态要求。
- **`\@@_punct_kern_break:NN` 延续"选函数再喂参数"的既有模式**：函数体只做条件判断、留下 `\@@_punct_breakable_kern:NN` 或 `\@@_punct_nobreak_kern:NN` 这个函数名，真正的 `#1 #2` 参数由外层 `\@@_punct_kern:NN` 尾部统一喂给最终留下的函数——与原 `\@@_punct_kern:NN` 的既有结构一致，未引入新模式。

基线联动：ctex `punct.tlg`（180+ 测试的大文件）中 `……」` 组合从 `\rule(0pt) + \glue`（可断）变为 `\penalty 10000 + \glue`（禁则保护）——这正是本修复的目标行为，属预期变化，直接 `l3build save punct` 更新基线。

测试：新增 `xeCJK/testfiles/longpunct-kinsoku01.lvt`，用 `\hsize=9em` 窄版面 + `\loggingoutput` 让断行真实发生，覆盖三类禁则违反场景（左引号/括号+破折号、破折号+逗号/句号、破折号+省略号）与两个合法断点保留场景（逗号后断、省略号后断）。

详见决策 [[456-longpunct-kinsoku-both-sides]] 与反思 [[456-longpunct-kinsoku-both-sides]]。

### 标点补偿 glue 的边界保护（`\@@_punct_boundary_guard:`）

全角标点的压缩量通过补偿 glue 实现。但在某些上下文中，`\unskip` 会移除水平列表末尾的 glue，吞掉标点补偿 glue，导致宽度计算错误。`\@@_punct_boundary_guard:` 函数在补偿 glue 之后插入保护节点，防止被 `\unskip` 移除。

- **Inner mode**（`\env{tabular}` 单元格、`\tn{hbox}` 等，#827）：在 glue 之后插入 `\penalty 0`，使最后节点不再是 glue，从而保护补偿 glue 不被 `\\` 触发的 `\unskip` 移除。
- **段落模式**（`experiment/punct-measure-fix` 选项，#859）：LaTeX 的 `\para_end:` 在执行 `\tex_par:D` 之前会通过 `\unskip` 移除水平列表末尾的 glue。如果段末恰好是全角标点，其补偿 glue 也会被移除，导致 `tabularray` 等使用 `\par` 结束测量段落的宏包得到不正确的宽度。

  启用 `experiment/punct-measure-fix` 后，xeCJK 通过以下机制补偿：
  - `\g_@@_par_guard_bool`：全局标志，记录段末是否存在需要保护的标点补偿 glue。
  - `\g_@@_par_guard_dim`：全局尺寸，记录被保护的标点补偿 glue 的自然宽度（`\lastskip`）。
  - `para/begin` 钩子：重置 `\g_@@_par_guard_bool`，避免跨段落残留状态。
  - `para/end` 钩子：若标志为真，插入等宽 `\kern` 补偿被 `\unskip` 移除的 glue 自然宽度。
  - inter-class tokens 重置：当 `Boundary` 之后紧跟其他字符类（`Default`、`CJK`、`FullLeft` 等）时，说明标点不在段末，重置标志。

  **设计权衡**：使用 `\kern` 而非 `\hskip`——`\kern` 不会被 `\unskip` 移除（无需额外保护），也不构成合法断行点。但 `\kern` 只保留了原 glue 的自然宽度，丢弃了弹性分量（stretch/shrink）。对于段末最后一行，`\parfillskip` 的 `0pt plus 1fil` 拉伸量会吸收所有剩余空间，因此弹性丢失在绝大多数情况下无视觉影响。

  使用示例：`\xeCJKsetup{experiment/punct-measure-fix}`

## 间距系统

| 间距类型 | 作用位置 | 默认值 | 配置方式 |
|----------|----------|--------|----------|
| `\CJKglue` | CJK ↔ CJK | `0pt plus 0.08\baselineskip` | `\xeCJKsetup{CJKglue=...}` |
| `\CJKecglue` | CJK ↔ 西文 | `~`（当前字体空格） | `\xeCJKsetup{CJKecglue=...}` |
| 标点 kern | 标点 ↔ 标点/CJK | 由 PunctStyle 决定 | `\xeCJKsetkern` |

### 行内代码语义与 `\xeCJKVerbAddon`（#808）

`\texttt` 只切换字体族，不表达代码语义；同一等宽字体也可能用于允许断行的普通正文。#808 所需的“片段内部取消 CJK–Latin 可见间距并保持半角/全角网格，外部仍有正常正文边界”已由公开命令 `\xeCJKVerbAddon` 提供：它在当前等宽字体度量下校准 CJK 单元、调整 CJK–CJK/CJK–Latin 间距，并禁止作用域内部自动断行。

对可作为普通宏参数读取的短代码，应先切换 `\ttfamily`，再在同一局部分组执行 `\xeCJKVerbAddon`；需要 verbatim 扫描时使用 `\verb`、`\lstinline` 等既有集成。不能把 addon 无条件挂到所有 `\ttfamily`/`\texttt`，否则长篇等宽普通文字会失去断行并产生 overfull。由此不增加“按字体族设置 `CJKecglue`”功能；决策见 [[../memory/decisions/808-inline-code-verb-addon]]。

## 兼容性补丁子系统

xeCJK 通过 `\@@_package_hook:nn` 为第三方包注册延迟加载的兼容补丁：

| 目标包 | 补丁内容 |
|--------|----------|
| `color`/`xcolor` | `\set@color` / `\reset@color` 注册为 `transparent`；`\color@b@x` 注册为 `wrapped-box`（#831/#992） |
| `hyperref` | `\Hy@BeginAnnot` 启动 `auto` stream；顶层 `\Hy@EndAnnot` 报告末尾 math 为 Default 后结束 capture（#809/#810/#972/#992） |
| `ulem` | 通过 `stream-ulem` 观察实际首尾；framework 决定外侧 glue，`\UL@stop` / `\UL@start` 保证它位于装饰区间外 |
| `pifont` | 输出前先进入水平模式，防止 interchartokenstate 泄漏 |
| `listings` | 用 `\scantokens` 替代 `\lowercase` 字符转换；`\lstinline` 两类扫描入口使用 `auto` stream |
| `url` | 在完整 `\Url@z` 格式化阶段外包围 `default` stream（#880/#992） |
| `hypdoc` | `\HD@target` 注册为 `transparent`；`\meta` / `\cs` 按固定首尾语义注册 stream（#873/#992） |
| `biblatex` | preamble 结束后把最终 `\let` 目标 `\blx@pagetracker` 注册为 `transparent`（#931/#992） |

传统 `CJK.sty` 与 xeCJK 不可同时加载。xeCJK 通过 `\ctex_disable_package:n` 拦截 `CJK` 等冲突包，因此 #510 中旧 `ruby.sty` 的 `\RequirePackage{CJK}` 现在只产生预期 warning，不再触发 `\CJKglue already defined`。这只是阻止加载冲突，不代表 xeCJK 实现了旧 CJK 的私有 kern-marker 协议；简单 MWE 能编译也不能据此声称完整语义兼容。XeLaTeX 的一般 ruby 推荐加载 PXrubrica，只有出现具体可复现的边界问题时才增加定点兼容，不在 xeCJK 中模拟整套旧协议。决策见 [[../memory/decisions/510-ruby-compatibility-boundary]]。

### 补丁模式

典型兼容补丁遵循同一模式：

```latex
\@@_package_hook:nn { <package> }
  {
    % 在目标包加载后执行
    % 通常重定义目标包的关键命令
    % 在命令内临时 \makexeCJKinactive 关闭 interchar
    % 由 TeX 分组自动恢复
  }
```

## `\char` 原语约束

XeTeX 的 interchar 机制工作在 token 层，无法区分字符来自 Unicode 输入还是 `\char` 原语。这是一个架构级红线：

- `\char` **必须始终保持 XeTeX primitive 身份**
- xeCJK 提供 `\xeCJKchar` 作为「绕过 interchar 的字符输出」接口
- 对已知受影响的包做定点自动补丁（如 `mtpro2`）
- 其他场景需用户手动用 `\makexeCJKinactive` 分组包装

## 扩展子包

### xeCJKfntef

提供 `\CJKunderline`、`\CJKunderdot`、`\CJKsout` 等中文文字效果命令。基于 `ulem` 机制重实现，处理 CJK 字符的下划线位置和连续性。

**线型命令的 leader 相位（#531/#967）**：`ulem` 的 `\leaders` 会把重复盒对齐到外层水平列表的相位，而不是当前装饰文字的起点。段首缩进或前置水平位移因而会改变首尾丢弃的非完整盒，使装饰相对正文等长平移；总盒宽保持不变，仅比较 `\wd` 无法捕获。规则型的 `\CJKunderline`、`\CJKunderdblline`、`\CJKsout`、`\CJKxout` 和 `\CJKunderanyline` 在各自 ulem 局部分组内把 `\ULleaders` 设为 `\cleaders`，让每个 leader 区域独立均分余量；普通模式的端点相对正文对称，`subtract` 模式两端等量缩短。周期图案 `\CJKunderwave` 则使用 `\xleaders`：它同样不继承外层 `\leaders` 相位，又把余量均匀分配到重复盒间距，避免 `\cleaders` 使逐个 CJK 片段独立居中而在字间接缝形成双峰。leader 原语必须按 mark 的连续性要求选择，不能把规则型线条的方案机械推广到周期图案。逐字放置的 `\CJKunderdot`、`\CJKunderanysymbol` 不走该 leader 路径，`\xeCJKfntefon` 和 ulem 全局状态也不修改。

**边界状态与装饰盒隔离（#826/#830/#992）**：`\xeCJK_fntef_sbox:n` 渲染装饰符号时调用可嵌套的 capture suspend/resume，按层保存并恢复 `\g_@@_last_node_tl` 与 source-space pending，同时阻止 scratch glyph 被外层 stream 当作正文。原生 ulem 与 xeCJKfntef 线型命令相互嵌套时，只有最外层拥有 `stream-ulem`；内层复用该层，不能重复 begin，因为 `\UL@onin` 路径没有独立 end。ulem 结束时把内部真实末尾 marker 移到外层列表，由唯一的 stream end 以列表证据校正不可见定界字符产生的观察值；旧的 fntef saved-last-node 与颜色方向专用 save/restore 均已删除。

**外侧 glue 不参与装饰**：首次可见类别出现时，`stream-ulem` 让 framework 统一选择 `CJKglue`、`CJKecglue` 或源码空格的数值；若此时处于 ulem 扫描状态，就先 `\UL@stop`，排普通 elastic skip，再 `\UL@start`。这样 glue 保留伸缩与断行位置，不变成 underline 的 `\leaders`。`command-boundary01` 覆盖 `\CJKunderline`、`\CJKunderdot`、`\CJKsout` 与原生 `\uline` 的四种源码空格，并覆盖原生 ulem 与 fntef 线型/符号命令的双向嵌套；逐格 idle-stack 断言要求 capture depth、active stack 与 suspend depth 全部归零。`command-boundary02` 以节点日志确认 `\uline` 左右的 1pt CJKglue 位于装饰区间外；`fntef-color01` 的 12 项继续覆盖 fntef(color) 与 color(fntef) 两个方向。

### xeCJK-listings

重写 `listings` 的字符转换机制，使 CJK 字符不再需要设为 active catcode。核心是用 `\tl_set_rescan:Nno`（即 `\scantokens`）替代 `\lccode` + `\lowercase` 路线。

`\@@_listings_rescan:Nn`（`xeCJK.dtx` L11856-11878）在 rescan 前用 `\tl_map_inline:Nn` 逐 token 扫描 `\l_@@_tmp_tl`，对 catcode 6 parameter token 通过 `\char_generate:nn { \int_value:w ``##1 } { 13 }` 转换为**同字符码**的 active token，避免 `\scantokens` 字符串化阶段对 catcode 6 token 的二次双写，同时保留用户通过 `\catcode\`\&=6` 等方式自定义的 parameter token 原字符身份。该模式由 \#378 → \#879 演化而来：\#378 用 catcode-class regex 修双写（替换端硬编码 codepoint），\#879 在 `\catcode\`\&=6` 场景下显式暴露其局限，改为 token-level map 保留原 codepoint。

`\lstinline` 的正文不由公开命令参数直接读取：分隔符路径经过 `\lstinline@`，花括号路径直接进入 `\lst@InlineG`。两处都启动 `auto` stream，并在共同的 `\lst@DeInit` 通过 `\aftergroup` 结束；因此颜色 push/pop、CJK/Default 混合内容与左右源码空格都进入统一边界恢复。`listings-color01` 用 braced Latin、braced CJK、两种混合方向与 delimiter Latin 共 20 个 direct-input oracle 验证，`listings-hash01` 独立保护 rescan/catcode 行为。

### xunicode-addon

为 xunicode 补充额外的 Unicode 符号命令定义。

#### `xunicode-symbols.tex` 驱动的逐字符多级字体回退（#878）

`xunicode-symbols.tex` 是 `xunicode-addon` 用于演示其覆盖字符集合的驱动文件，由 `l3build install --full` 排版生成 `xunicode-symbols.pdf`。该集合横跨多个 Unicode 区段（符号、几何形状、CJK Stroke 等），**不存在**在主流 Windows / Linux / macOS 上都默认装且覆盖完整的单一字体；此前版本采用“整段单字体 if-else”的回退策略时，凡是被选中字体未覆盖的字符都会以 `Missing character` 警告出现。

PR #886（fix #878）将驱动改为“逐字符多级字体回退链”：

1. 用 fontspec 的 `\IfFontExistsTF` 条件声明候选 NFSS 字体家族 `\xunsymNoto`、`\xunsymSymbola`、`\xunsymSegoe`、`\xunsymDejaVu`，主字体仍为 `FreeSerif`。
2. `\UnicodeTextSymbol` 在排出每个 codepoint 前，使用 `\reverse_if:N \tex_iffontchar:D \tex_font:D #1 \exp_stop_f:` 测试当前激活字体是否含该字符；不命中则通过 `\cs_if_exist_use:N` 切换到下一级候选家族后再次测试，形成 `FreeSerif → Noto Sans Symbols 2 → Symbola → Segoe UI Symbol → DejaVu Sans` 五级嵌套链。
3. `\cs_if_exist_use:N` 用于在“候选字体在本机不存在 ⇒ `\newfontfamily` 未定义该家族”时静默跳过、由外层 `\reverse_if:N` 继续向下级落，避免 `! Undefined control sequence`。

该模式只适用于“演示性符号目录”驱动文件，**不应**推广到 xeCJK 正文 / CJK 字体路径（后者属于字符分类驱动的字体切换，不是 codepoint glyph 级缺失）。详细根因、嵌套顺序选择理由与适用边界见反思 [[878-xunicode-symbols-multilevel-fallback]]；驱动新增段对应 `xeCJK.dtx` `\changes` v3.10.0 2026/06/23。

## TECkit 映射

xeCJK 在构建时通过 `xeCJK/build.lua` 中的 `make_teckit_mapping()` 从 Unicode Unihan 数据生成 `.map`/`.tec` 字体映射文件，用于繁简转换和句号形态映射。这部分功能数据在构建阶段动态生成，不完全静态存储。
