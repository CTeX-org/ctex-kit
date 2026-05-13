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

XeTeX 0.99994+ 支持最多 4096 个字符类；`Boundary` 固定为最大编号（4095）。

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

1. **不做通用 whatsit 恢复**：只有 `\set@color`、`\reset@color` 和 `\Hy@BeginAnnot` 三处定点补丁，其他 whatsit 不参与恢复（避免 #803 类误判）
2. **ecglue 缓存在 CJK→Boundary 时机**：`\l_@@_ecglue_skip` 在离开 CJK 上下文前测量并缓存，后续恢复不重新展开 `\CJKecglue`
3. **宏路径不提前输出 glue**：`\@@_boundary_reserve_space:` 只保留标记 kern，不抢先输出空格 glue

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
| `url` | 确保 CJK 字体在 URL 数学模式中正确切换 |

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

### xeCJK-listings

重写 `listings` 的字符转换机制，使 CJK 字符不再需要设为 active catcode。核心是用 `\tl_set_rescan:Nno`（即 `\scantokens`）替代 `\lccode` + `\lowercase` 路线。

### xunicode-addon

为 xunicode 补充额外的 Unicode 符号命令定义。

## TECkit 映射

xeCJK 在构建时通过 `xeCJK/build.lua` 中的 `make_teckit_mapping()` 从 Unicode Unihan 数据生成 `.map`/`.tec` 字体映射文件，用于繁简转换和句号形态映射。这部分功能数据在构建阶段动态生成，不完全静态存储。
