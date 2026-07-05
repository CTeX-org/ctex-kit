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

核心几乎全部集中在 `xeCJK/xeCJK.dtx`（约 14800 行），通过 docstrip 生成：

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
| `HangulJamo` | 朝鲜文字母 | ᄻᆟᇫ |
| `PoZheHao` | 支持合字的破折号（opt-in，#382） | U+2014/U+2015 |

XeTeX 0.99994+ 支持最多 4096 个字符类；`Boundary` 固定为最大编号（4095）。

### 零注入字符类模式（`HangulJamo` / `PoZheHao`）

xeCJK 有两个字符类采用同一种"零注入"设计模式：类内相邻字符之间的 `\XeTeXinterchartoks` **不插入任何内容**，类间关系（与其他类的过渡处理）则复制自某个已有类。这是"interchar 机制打断字符序列"问题族（#382 破折号合字、#158 朝鲜文音节、#165 假名）的通用解法模板：

| 字符类 | 类间关系复制自 | 目的 |
|---|---|---|
| `HangulJamo` | `CJK` | 朝鲜文字母连续输入时不产生字距干扰 |
| `PoZheHao` | `FullRight`（`\AtEndOfPackage` 内通过 `\xeCJK_copy_inter_class_toks:nnnn` 复制） | 连续 U+2014 之间不注入内容，使 OpenType 破折号合字（如思源宋体/黑体的两字宽合字形）可以触发；与其他字符类的边界仍按全角右标点处理 |

`PoZheHao` 类是 opt-in 的：用户通过 `\xeCJKsetup{PoZheHaoLigature}` 显式启用后，才把 U+2014、U+2015 从 `FullRight`/`Default` 改归为 `PoZheHao`；因为合字能力取决于字体（思源系字体支持，多数国产字库不支持），xeCJK 无法自动探测字体是否具备该 OpenType 特性，对不支持合字的字体启用会让连续破折号中间露出空隙。

### 类别间转换矩阵

xeCJK 在 `xeCJK.dtx:3140` 定义了完整的 9×9 类别转换矩阵。核心转换规则：

- **进入 CJK 区域**（`Default/HalfLeft/HalfRight/NormalSpace → CJK`）：开启 CJK 分组、切换字体、输出字符
- **离开 CJK 区域**（`CJK → Default/HalfLeft/HalfRight/NormalSpace`）：关闭分组，后续在 `Boundary → Default` 恢复 ecglue
- **CJK 之间**（`CJK → CJK`）：插入 `\CJKglue`
- **CJK ↔ 标点**（`CJK → FullLeft/FullRight`）：触发标点压缩
- **经过 Boundary**（`CJK → Boundary → Default`）：通过标记 kern 记录边界状态，延迟恢复间距

### CJK→Boundary handler（`\xeCJK_CJK_and_Boundary:w`）

`\XeTeXinterchartoks` 中 CJK→Boundary 的处理函数。Boundary class (255/4095) 由以下情况触发：

- 源码空格
- 显式 `{`（catcode 1）和 `}`（catcode 2）
- `\ `（control space）

注意：`\bgroup` / `\egroup`（隐式花括号）**不**触发 Boundary class，因为它们是控制序列而非 catcode 1/2 字符。

handler 在执行时会 peek 下一个 token：
- 若 peek token 是 catcode 2（`}`）：说明当前正在退出一个 TeX 分组（如 `前{中} 后` 中的 `}`），分组结束后会恢复局部变量（包括 `\l_peek_token`），因此必须在 `\@@_boundary_group_end:n` **之前**设置 `\g_@@_ulem_pending_bool`，以确保后续的 inter-word glue 被正确识别
- 若 peek token 是控制序列（如 `\ `）：不设置 boolean，区分于 catcode 2 的情况

## 边界恢复状态机

这是 xeCJK 最复杂的子系统。当 CJK 字符与西文之间有「边界」（空格、命令等）间隔时，简单的相邻类检测不再适用，需要一个多层状态机来判断是否以及如何恢复间距。

### 三层架构

```
┌─────────────────────────────────────────────┐
│ 第一层：边界判定（\lastkern 标记 kern）       │
│   CJK→Boundary 时写入标记 kern               │
│   Boundary→Default 时通过 \lastkern 读回     │
├─────────────────────────────────────────────┤
│ 第二层：异常回退（whatsit 定点恢复）          │
│   \textcolor 等插入 whatsit 打断 \lastkern    │
│   仅对已知安全场景（color/hyperref）定点补丁  │
├─────────────────────────────────────────────┤
│ 第三层：取值时机（CJK→Boundary 缓存 ecglue） │
│   在离开 CJK 字体上下文前缓存 \CJKecglue     │
│   恢复时使用缓存值，不重新测量               │
└─────────────────────────────────────────────┘
```

### 标记 kern 类型

xeCJK 使用不同值的 kern 作为内部标记：

- `CJK` — 上一个可见字符是 CJK 字符
- `CJK-space` — CJK 后跟了空格（保留空格位置信息）
- `CJK-widow` — CJK 孤字标记
- `default` — 上一个可见字符是西文
- `default-space` — 西文后跟了空格
- `normalspace` — NormalSpace 类字符标记

### 恢复判定流程（`\xeCJK_check_for_glue:`）

```
Boundary → CJK 时：
  1. \lastkern 存在？
     → 是：根据 kern 值选择插入 \CJKglue 或 ecglue
  2. 上一节点是 whatsit？
     → 是：走定点 whatsit 恢复（仅 color/hyperref）
  3. 上一节点是 math？
     → 是：插入 ecglue
  4. 上一节点有 glue？
     → 是：\@@_check_for_glue_skip: 处理
```

### glue 分支处理（`\@@_check_for_glue_skip:`）

当 `\@@_if_last_glue:TF` 为真时，进入 `\@@_check_for_glue_skip:` 处理。这一分支处理 xeCJKfntef 命令（如 `\CJKsout`、`\CJKunderdot`）右侧出现的 inter-word space glue 叠加在 CJK kern pair 标记上的情况。

**背景**：xeCJKfntef 的内容在 ulem 的 hbox 中排版，不在主 hlist 上。XeTeX 的 interchar class 在 `}` 后看到的不是 CJK 字符，因此源码空格产生 finite inter-word glue，叠在 CJK kern pair 标记上方。原先的 `check_for_glue` 没有处理"glue on top of kern pair"的情况。

**处理逻辑**：

```
\@@_check_for_glue_skip:
  0. finite/shrink 前置检查（不依赖 boolean）
     \skip_if_finite:nTF {\lastskip}
     → 非 finite（fil 级 glue）：回退到 \@@_check_for_glue_auxii:
     → finite：继续
     \tex_glueshrink:D > 0 检查
     → glueshrink = 0（\quad 等）：回退到 \@@_check_for_glue_auxii:
     → glueshrink > 0：进入分支路径

  kern 路径（boolean 门控）：
  1. \g_@@_ulem_pending_bool 门控
     → false：进入非 kern 路径
     → true：保存 \lastskip 到 \l_@@_last_skip
  2. \unskip 移除 glue
  3. 检查下方是否有 CJK kern pair 标记
     （CJK / CJK-space / CJK-widow）
  4. 如果找到 kern pair：
     移除标记 kern，放置正确的 CJKglue
  5. 如果不是 kern pair：
     恢复 glue，调用 \@@_check_for_glue_auxii:

  非 kern 路径（三分支）：
  1. hlist 分支（无门控）：
     \lastnodetype = 1（hbox）且 \g_@@_last_node_tl 非空
     → \unskip 移除 glue，路由到 \@@_check_for_glue_skip_hlist_aux:
     覆盖 \mbox 场景
  2. whatsit 分支（\g_@@_reset_color_pending_bool 门控）：
     hlist 检查失败后，boolean 为真且 \lastnodetype 为 whatsit
     → 路由到 \@@_check_for_glue_skip_hlist_aux:
     覆盖 \textcolor color-pop 场景
  3. fallback：
     → 回退到 \@@_check_for_glue_auxii:
```

**设计决策**：
- finite/shrink 检查提到 boolean 门控之前：这使 fil 级 glue（如 listings）和 `\quad` 等无 shrink 的显式空距在 boolean 判断前就被过滤掉，减少误触发
- kern 路径由 boolean 门控保护 `space=true` 模式：`\g_@@_ulem_pending_bool` 确保只有"已知会产生多余 inter-word glue"的场景才执行 `\unskip` + kern pair 探测
- 非 kern 路径分三支：hlist 分支不依赖 boolean（`\mbox{中}` 产生 hbox，通过 `\g_@@_last_node_tl` 判断）；whatsit 分支由 `\g_@@_reset_color_pending_bool` 门控（`\textcolor` color-pop）；其余 fallback
- `\g_@@_ulem_pending_bool` 的三个 set 点（全局置真，不变）：
  1. `\@@_ulem_group_end:n`：fntef 模块在 ulem hbox 关闭时设置（覆盖 `\CJKsout`、`\CJKunderline` 等使用 ulem group 的命令）
  2. `\@@_under_symbol_auxii:nnnnnn`：着重号独立模式（`\CJKunderdot`、`\CJKunderdbldot`）不走 ulem group，在 hbox 关闭后的末尾单独设置
  3. `\xeCJK_CJK_and_Boundary:w`：CJK→Boundary handler 中，当 peek token 是 catcode 2（显式 `}`）时设置——因为显式 `}` 结束的 TeX 分组后，若紧跟源码空格，XeTeX 看到的不是 CJK 字符类，会产生 inter-word glue
- `\g_@@_ulem_pending_bool` 在 `\@@_check_for_glue_skip:` 消费后即刻清除（全局置假），保证不向后续字符泄漏
- `\g_@@_reset_color_pending_bool`（专用 boolean）：仅由 `\reset@color` 补丁设置（当最后节点是 hlist 且 `\g_@@_last_node_tl` 非空），在 `\@@_check_for_glue_skip:` whatsit 分支消费后清除。不能复用 `\g_@@_ulem_pending_bool`，因为 catcode 2 的 `}` 会先设置后者，与 `\reset@color` 的 `\aftergroup` 回调时序交叉
- glueshrink 检查区分 inter-word space（有 shrink）和 `\quad`（无 shrink），避免吞掉用户有意的显式空距
- 所有 fallback 统一到 `\@@_check_for_glue_auxii:`（包含 punct 检测链），而非 `\xeCJK_check_for_xglue:`

### 关键约束

1. **不做通用 whatsit 恢复**：只有 `\set@color`、`\reset@color`、`\Hy@BeginAnnot` 和 `l3color` 后端四类定点补丁，其他 whatsit 不参与恢复（避免 #803 类误判）。其中 `l3color`（expl3 内置）的颜色机制使用独立的后端代码路径，不经过 `\set@color`/`\reset@color`；#832 对 `\__color_select:N`（颜色推入）和 `\__color_backend_reset:`（颜色弹出）施加了与 `\set@color`/`\reset@color` 相同的 kern 对保护
2. **ecglue 缓存在 CJK→Boundary 时机**：`\l_@@_ecglue_skip` 在离开 CJK 上下文前测量并缓存，后续恢复不重新展开 `\CJKecglue`
3. **宏路径不提前输出 glue**：`\@@_boundary_reserve_space:` 只保留标记 kern，不抢先输出空格 glue

### 边界恢复修复点选择矩阵

修复 marker 失效问题时，**修复位置由“被遮蔽的节点类型”决定，不由 marker 类型决定**。已实际落地的四类对照：

| 遮蔽类型 | 案例 | 修复位置 | 修复模式 |
|---------|------|---------|---------|
| hbox 节点（marker 仍在但 `\lastkern` 回看不到） | #873 `\HD@target` 的 `\raisebox` 0x0 hbox、#910 `\verb` 的 `\leavevmode\null` 同型 hbox | 调用方入口（fixed-point patch） | **save/replay** 或 **drain**（具体见下） |
| math 模式（marker 被 math 节点吞掉） | #880 `\Url@FormatString` 的 `$ \fam\z@ ... $` | 调用方入口（fixed-point patch） | **drain**：入口 `\xeCJK_remove_node:` 拔掉 marker，直接补 `\l_@@_ecglue_skip` |
| whatsit 节点（color / hyperref annot 等） | #807 / #809 / #810 / #831 | `\@@_recover_glue_whatsit:` 或调用方入口 | **whatsit 恢复链**，必要时配合**专用 pending boolean**（如 `\g_@@_reset_color_pending_bool`） |
| 用户显式分组（catcode 2 `}`） | #831 catcode 2 路径 | CJK→Boundary handler 内 | **brace 路径状态保存**：在 handler 内部识别 catcode 2，设置 `\g_@@_ulem_pending_bool` 让下游 glue-skip 接管 |

#### 选择 drain 还是 save/replay 的判断

第一维度（遮蔽点之后的内容类型）：

- 如果遮蔽点之后**始终是西文**（如 `\url` 内容必然是西文），CJK→西文方向边界永远是 ecglue，无需保留 marker 类型，用 drain。
- 如果遮蔽点之后可能既是 CJK 又是西文（如 `\HD@target` 后面什么都可能），必须保留 marker 类型让下游状态机判断，用 save/replay。

第二维度（调用方控制序列的 token 扫描语义）：

| 调用方语义 | 例子 | 可用模式 |
|---|---|---|
| 普通无参/受参控制序列（patch 体可 wrap，原命令后能注入代码） | `\HD@target` (#873)、`\set@color` (#807/#831)、`\Hy@BeginAnnot` (#809/#810) | save/replay 或 drain |
| 分隔符扫描宏（patch 体只能在原命令**前**插代码，调用结束控制流不回到 patch 下文） | `\verb` (#910)、`\Url@FormatString` (#880) | **仅 drain** |
| math 模式直接吞掉 marker | `\Url@FormatString` (#880) | **仅 drain** |

即：**遮蔽节点类型** 决定 `\@@_check_for_glue:` 探测失败的根因，**调用方扫描语义** 决定能在哪个时机注入修复。`\verb` 与 `\HD@target` 都是 0×0 hbox 遮蔽，但 `\verb` 是分隔符扫描宏（读到分隔符 `|`/`+` 等才结束），patch 包装时控制流被 `\@ifstar\@sverb\@verb` 接管，没法在原命令后注入 replay，因此只能用 drain。

#### drain 的两种变体（else 分支策略）

xeCJK 内部维护两个 drain 函数，差别仅在 `\xeCJK_if_last_node:TF` 的 else 分支（无 marker 时）：

| 函数 | else 分支 | 适用场景 |
|---|---|---|
| `\@@_drain_ecglue:` | **主动 `\tl_gclear:N \g_@@_last_node_tl`** | 调用方之后**不再有 token-level interchar 转换**（如 `\Url@FormatString` 进 math，math 模式不参与 interchar），需要主动清防御 tl 残留误导下游 `\@@_recover_glue_whatsit:` |
| `\@@_drain_ecglue_verb:` | **保持 `\g_@@_last_node_tl` 不动** | 调用方之后仍走 token-level interchar（如 `\verb` 内 catcode-12 字符或 ctex 模式下 verb 内 CJK 字体延续，verb 关组后仍触发 Default→CJK 或 CJK→CJK transition），需要 tl 状态延续 |

`\verb` 不能复用 `\@@_drain_ecglue:` 的具体证据：ctex `fontset=fandol` 下 `\verb|内联代码|` 内部 `内联代码` 是 FandolFang CJK 字体（仍是 CJK class），verb 外 `和` 是 FandolSong CJK，二者间需要 CJK→CJK transition 输出 `\CJKglue`。如果 else 分支 clear 了 `\g_@@_last_node_tl`，下游 transition 失败，ctex `verbatim01.xetex` 测试 fail。详见 [[910-verb-drain-vs-drain-verb]] 决策。

#### `\verb` 右侧的另一类根因：language whatsit 排出时序（#919）

上面的矩阵处理的都是 **marker 被遮蔽 → ecglue 少补** 的问题（欠补）。`\verb` 右侧还有一处**性质相反**的独立问题（#919）：ecglue **多补成双倍**（过补）。它与遮蔽无关，根因在 TeX 节点顺序：

- `\verb` 组内 `\language` 被切到 `\l@nohyphenation`，组关闭后 TeX 的 language whatsit 是**延迟**排出的——要等下一个字符节点进入水平列表时才补插。
- 于是 `\verb` 与后文之间的**源码空格**产生的 inter-word glue 先进列表，`\setlanguage` whatsit 反而排在 glue **之后**：
  `kern pair → glue(source space) → setlanguage → [探测点]`
- 后续 CJK 字符触发类别转换时，`\xeCJK_check_for_glue:` 看到的 last node 是 whatsit 而非 glue，走 `\@@_recover_glue_whatsit:` 的 default 分支再补一个 `CJKecglue`——与已有的 inter-word glue 相加成**双倍间距**。

不从探测端修（`\lastskip` 无法穿透 whatsit，default 分支也不能收窄——无源码空格的 `字\verb...字` 场景依赖它补合法 ecglue），而是从**节点顺序**入手：在 `\verb@egroup` 关组后立即执行 `\setlanguage\language`，强制 language whatsit 当场排出。此后源码空格的 glue 排在 whatsit 之后：
`kern pair → setlanguage → glue(source space) → [探测点]`
探测点看到的 last node 是 glue，走 `\@@_check_for_glue_skip:` 正确处理，不再重复补 ecglue；无源码空格时 last node 是排出的 whatsit，default 分支照常补上合法 ecglue，原有行为不变。

实现为独立内部宏 `\@@_flush_language_whatsit:`（`\mode_if_horizontal:T { \tex_setlanguage:D \tex_language:D }`），仅在外层水平模式执行——数学模式 / 行首无此时序问题，restricted horizontal mode（`\hbox` 内）根本不产生延迟 whatsit。挂载点是 `\verb@egroup`（`\tl_gput_right:Nn`），与 #910 的 `\@@_drain_ecglue_verb:`（挂 `\@@_patch_verb:`）共存互不干扰；shortvrb 短记号与 `\verb*` 都经由同一 `\verb@egroup`，两个补丁自动覆盖。未来若有其他切换 `\language` 的分组宏需要同样的时序修正，可复用 `\@@_flush_language_whatsit:`。

#### 第三维度：补丁点的绑定形态（`\def` vs `\let` 拷贝目标）

选定"补哪个语义"（save/replay/drain/clear tl）之后，还得选"补哪个**名字**"。第三方宏包如果通过"选项驱动 → `\let\A\B`"把可选行为绑定成硬拷贝，`\A` 会在 `\let` 那一刻**冻结**到 `\B` 的 meaning，后续再改 `\B` 不影响 `\A`。所以补丁点必须挂在 `\A`（`\let` 目标）而非 `\B`（`\let` 源）。

| 绑定形态 | 例子 | 补丁点选 | Hook 时机 |
|---|---|---|---|
| 普通 `\def` / `\protected\def` | `\Url@FormatString` (#880)、`\HD@target` (#873)、`\Hy@BeginAnnot` (#809/#810) | 该 `\def` 本身 | `\@@_package_hook:nn` 即可 |
| `\let` 拷贝目标（选项驱动的行为绑定） | `\blx@pagetracker` (#931) | **`\let` 目标**（不是 `\let` 源） | **必须** `\@@_at_end_preamble:n` 或 `\@@_after_preamble:n`，等 `\let` 执行完 |

#### Hook 三档时机对照

xeCJK 三档 hook 的 fire 时机相对包加载的先后：

| Hook | 实际展开 | fire 时机 | 捕获包 nested `\Require*Style` 后的 `\let` |
|---|---|---|---|
| `\@@_package_hook:nn { pkg }` | `package/pkg/after` | pkg 主 sty 加载完 | ✗（`.bbx` 已加载完，`\let` 已定型） |
| `\@@_at_end_preamble:n` | `begindocument/before` | 全 preamble 结束前 | ✓ |
| `\@@_after_preamble:n` | `begindocument/end` | 全 preamble 结束后 | ✓ |

**关键判断（选择 hook 时机的决策流程）**：

1. 先在 `pkg.sty` 里 grep `\RequireBibliographyStyle` / `\RequireCitationStyle` / `\LoadClass` 或类似的 **nested style-load** 语句
2. 若存在，进一步在被 load 的 style 里 grep `\ExecuteBibliographyOptions` / `\let` 等**运行时绑定**
3. 若上述二者都命中 → `\@@_package_hook:nn` **不够晚**，必须选 `\@@_at_end_preamble:n` 或 `\@@_after_preamble:n`；否则默认 `\@@_package_hook:nn` 即可

**诊断流程根因（相关工具选择）**：如果第一次 patch 挂在"看起来对"的名字上却不生效，先 `\iow_term:x` 打点验证 patch 是否 fire——但打点必须写到**最终被调用的名字**（`\let` 目标）而非源函数上，否则打点无输出**并不能证明 "patch 没装"**，反而恰恰暴露"patch 装在了错的名字上"。#931 首次尝试就踩到这个陷阱：patch `\blx@pagetracker@context`（`\let` 源）+ 打点 `\blx@pagetracker@context`，运行时 `\blx@bibitem` 调 `\blx@pagetracker`（`\let` 目标，指向旧拷贝）→ 打点无输出。

详见反思 [[931-biblatex-pagetracker-let-shadow]] 与决策 [[931-biblatex-let-shadow]]。

#### 与"收窄 `\@@_recover_glue_whatsit:` default 分支"思路的边界

PR #831 在 whatsit 路径上用 `\g_@@_reset_color_pending_bool` 实现了“只在已知调用方显式置位时才允许 fallback 分支吐 ecglue”的门控。这一思路理论上可继续推广到 `\@@_recover_glue_whatsit:` 的 default 分支以收窄“任意 whatsit 误触发”的攻击面，但与 #873 / #880 / #910 无关——hbox 走 else 分支、math 直接吃 marker，都不进入 `recover_glue_whatsit`。是否做这一收窄是独立 PR 范畴。

详见反思 [[873-880-meta-url-hbox-math-boundary]] 与 [[910-verb-null-hbox-drain]]。落地点：`xeCJK/xeCJK.dtx` 中 `\@@_patch_hd_target:` / `\@@_patch_url_format:` / `\@@_patch_verb:` / `\@@_flush_language_whatsit:` 段，回归测试 `xeCJK/testfiles/hypdoc-ecglue01.lvt` / `url-ecglue01.lvt` / `verb-ecglue01.lvt` / `verb-ecglue02.lvt`（#919 language whatsit 时序）。

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

三项分别覆盖：`bound 和` 对应字面窄于字框（中易系），`dimen+width-2F` 对应字面溢出字框（方正兰亭黑），`2*width-2F` 对应字框本身宽于字号（微软雅黑）。省略号 U+2025/U+2026 连用不需要压缩，保持零 kern；其余长标点（U+2E3A 二の字点、全角浪线等）行为不变，仍走原 bound 和压缩公式。

**两端补偿 margin（`\xeCJK_punct_margin_process:NN`）**：破折号属于 `MiddlePunct`，原公式两端各补偿 `(目标宽 - dimen) / 2`（各半份空白，使标点在其目标宽度内居中）。但对未启用合字的 U+2014，连用时中间被上面的 kern 挤掉的空白，恰好等于单个字符两端总空白（而非半份），若仍按半份补偿，连用总宽会系统性偏差。修复为新增条件 `\@@_punct_if_full_margin_dash:N`（判定：字符是 U+2014 且未被归入 `PoZheHao` 类），成立时补偿两端**各一整份**（不除以 2）。该条件同时作用于 margin 计算本身与它传给 `\@@_save_punct_skip:nNNnnn` 的 glue plus（stretch）分量——两处必须保持同一份"是否除以 2"的判断，否则自然宽度与弹性分量会不一致。

代价（相对 CLReq 理想值的已知偏差，均在可接受范围）：单个 U+2014 略超 1 字宽（约 1.087 ccwd），三连略欠 1 字宽（约 2.913 ccwd）——这是"仅调整两个自由度（kern、margin）去满足两个不变量（中间无缝、总宽正确）"必然存在的近似残差，测试 `dashwidth01.lvt` 对此按已知值断言而非要求精确 2.0/3.0。

### PoZheHao 字符类（合字 opt-in，#382）

阶段 1 的公式修正只解决"未合字"场景的宽度问题。对提供 OpenType 破折号合字特性的字体（如思源宋体、思源黑体：连续两个 U+2014 被替换为一个两倍字宽的合字字形），interchar 机制默认会在标点处理时于两个 U+2014 之间注入 token，从而阻断 OpenType shaping 层看到"相邻"两个字符、无法触发合字。

修复采用零注入字符类模式（见上文字符分类体系）：新建 `PoZheHao` 类，类内（U+2014↔U+2014、U+2014↔U+2015）不插入任何 interchar token，交由字体自身的合字特性处理；类间关系复制自 `FullRight`，保证破折号与其他标点/CJK 相邻时仍按全角右标点语义处理。

工程细节与踩坑记录：

- **`\@@_punct_if_right:N` 必须承认 `PoZheHao` 类**：若不修改，「标点+破折号」相邻（如“爱。——”）时，该函数误判 U+2014 不是全角右标点，导致下游取用不存在的 `dim/glue/left/—/tl` 一类缓存键报 `Missing number`。这是 2018 年该功能原型中就已踩过的坑（回归测试 `dashwidth01.lvt` 专门覆盖"标点后接破折号"场景以固化此教训）。
- **`\xeCJKResetPunctClass` 与状态恢复**：该命令会重新声明 `FullRight` 类，导致 U+2014 被重新拉回 `FullRight`（覆盖掉 `PoZheHao` 归类）。为此 `PoZheHaoLigature` 的开关状态记录在全局布尔 `\g_@@_pozhehao_ligature_bool` 中，`\xeCJKResetPunctClass` 执行尾部按该布尔值自动恢复 `PoZheHao` 类声明，避免用户重置标点类后合字状态跟着丢失。
- **`PoZheHaoLigature=false` 的恢复目标**：U+2014 → `FullRight`，U+2015 → `Default`（普通类，编号 0）。注意 U+2015（水平线）自 v3.3.3 起已不属于 `FullRight`，这一点在本次修复中被实测验证，不能想当然认为两个字符对称恢复到同一个类。
- **为什么是用户 opt-in 而非自动探测**：合字能力完全取决于字体（多数国产字库不提供），XeTeX 没有可靠原语能在不实际 shape 的情况下探测某字体是否具备特定 OpenType 合字特性；对不支持合字的字体启用 `PoZheHaoLigature` 会让连续破折号中间露出空隙（因为零注入类不再提供任何补偿）。因此设计为显式 `\xeCJKsetup{PoZheHaoLigature}` 键控制，且需要用户自行配合开启 `fwid`/`locl` 等 OpenType 特性以获得全角字形。

### 标点度量的 feature-blind 限制（架构级边界，#382 复测发现）

xeCJK 所有标点尺寸（`dimen`/`width`/`bound` 等）均通过 `\fontcharwd` 与 `\XeTeXglyphbounds n \XeTeXcharglyph` 获取。`\XeTeXcharglyph` 是**基于 cmap 的直接字符→字形编号查找**，不经过 OpenType shaping 管线，因此 `locl`（区域本地化替换）、`fwid`（全角变体替换）等 GSUB 特性替换掉原字形后，xeCJK 拿到的度量仍然是替换前那个"幻影字形"的度量，不会随特性生效而更新。

这是一个已知且当前无法绕过的架构限制：没有原语能取得"shaped 后"的字符度量——advance width 尚可通过临时 `\hbox` 实测宽度间接获得，但 side bearing（字形左右边距，标点压缩公式的关键输入）没有对应的原语或测量手段。

已知表现（本次修复中实测确认）：裸 Noto Serif CJK SC（未显式开启 `RawFeature=+fwid`）的连用破折号总宽仍是修复前的 1.78 ccwd 而非 CLReq 要求的 2.0，因为 `\XeTeXglyphbounds` 拿到的是全角替换前的窄字形边界；显式开启 `fwid`/`locl` 后（如 `\setCJKmainfont{Noto Serif CJK SC}[RawFeature=+fwid]`）度量与视觉字形一致，总宽达标 2.0。诊断这类问题时，`fontcharwd`/`\XeTeXglyphbounds` 在同一字体、开关某 OpenType 特性前后返回值恒定不变，本身就是"此路径 feature-blind"的直接证据，无需深入 shaping 引擎即可确认根因。

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

## 兼容性补丁子系统

xeCJK 通过 `\@@_package_hook:nn` 为第三方包注册延迟加载的兼容补丁：

| 目标包 | 补丁内容 |
|--------|----------|
| `color`/`xcolor` | `\set@color` 后重放 xeCJK 边界标记；`\reset@color` hlist 路径设置 `\g_@@_reset_color_pending_bool` 后调用原始 reset（#831） |
| `hyperref` | `\Hy@BeginAnnot` 处保存/清空/选择性重放节点状态 |
| `ulem` | 临时关闭 interchar (`\makexeCJKinactive`) |
| `pifont` | 输出前先进入水平模式，防止 interchartokenstate 泄漏 |
| `listings` | 用 `\scantokens` 替代 `\lowercase` 字符转换 |
| `url` | `\Url@FormatString` 入口 drain marker kern 并补 ecglue（#880） |
| `hypdoc` | `\HD@target` 入口 save/replay `\g_@@_last_node_tl`，保证 hbox 节点不遮蔽 marker（#873） |

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

**`\xeCJK_fntef_sbox:n` 的全局状态隔离**：该函数通过 `\hbox_set:Nn` 渲染装饰符号（如 underdot 的 `.`）。hbox 内部的字符会触发 XeTeX interchar toks，全局修改 `\g_@@_last_node_tl`（例如从 `CJK-space` 变为 `default`）。这会污染外层水平列表的状态，导致 `\set@color` 补丁用错误的节点类型重建 kern pair，后续 `\@@_check_for_glue_skip:` 走 ecglue 路径而非 CJKglue 路径。

修复方式：在 `\hbox_set:Nn` 前后保存/恢复 `\g_@@_last_node_tl`。这是一个通用模式——**任何包含 CJK 字符的 `\hbox_set:Nn` 都可能通过 interchar toks 污染全局节点标记状态**，应在 hbox 前后隔离 `\g_@@_last_node_tl`。

**`\xeCJK_ulem_right:` / `\__xeCJK_ulem_end:` 的全局状态隔离（#830）**：当 `\textcolor` 包裹 ulem 类 fntef 命令时，ulem 的 `\UL@end` 定界符中的 `*` 字符（Default 字符类）在 ulem 处理结束时被排版，触发 Default->Boundary interchar class 转换，将 `\g_@@_last_node_tl` 从 `CJK` 污染为 `default`。随后 `\reset@color` 读取被污染的值，用 default 类型 kern pair 标记，导致后续 CJK->CJK 间距检测走到 ecglue 分支。修复方式：在 `\xeCJK_ulem_right:` 开始时将 `\g_@@_last_node_tl` 保存到 `\g__xeCJK_ulem_saved_last_node_tl`，在 `\__xeCJK_ulem_end:` 完成后恢复。

**两个方向的完整覆盖**：
- fntef(color) 方向：fntef 包裹 textcolor — `\xeCJK_fntef_sbox:n` hbox 隔离（#826-fntef-color-global-state）
- color(fntef) 方向：textcolor 包裹 fntef — `\xeCJK_ulem_right:` save/restore 隔离（#830）

测试覆盖见 `xeCJK/testfiles/fntef-color01.lvt`（Test 1-7 覆盖 fntef(color)，Test 8-12 覆盖 color(fntef)）。

### xeCJK-listings

重写 `listings` 的字符转换机制，使 CJK 字符不再需要设为 active catcode。核心是用 `\tl_set_rescan:Nno`（即 `\scantokens`）替代 `\lccode` + `\lowercase` 路线。

`\@@_listings_rescan:Nn`（`xeCJK.dtx` L11856-11878）在 rescan 前用 `\tl_map_inline:Nn` 逐 token 扫描 `\l_@@_tmp_tl`，对 catcode 6 parameter token 通过 `\char_generate:nn { \int_value:w ``##1 } { 13 }` 转换为**同字符码**的 active token，避免 `\scantokens` 字符串化阶段对 catcode 6 token 的二次双写，同时保留用户通过 `\catcode\`\&=6` 等方式自定义的 parameter token 原字符身份。该模式由 \#378 → \#879 演化而来：\#378 用 catcode-class regex 修双写（替换端硬编码 codepoint），\#879 在 `\catcode\`\&=6` 场景下显式暴露其局限，改为 token-level map 保留原 codepoint。

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
