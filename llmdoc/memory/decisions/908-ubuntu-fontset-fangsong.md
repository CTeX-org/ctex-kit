# 决策：`fontset=ubuntu` 补齐仿宋，采用三级运行时 fallback 且不做基线 hack

## 背景

`fontset=ubuntu`（`ctex/ctex.dtx` `%<*ubuntu>` 段）是唯一没有仿宋（`zhfs` 家族 + `\fangsong` 命令）的预定义字库：`\ttfamily` 直接复用 Noto 宋体顶替。根因是 Noto CJK 不含仿宋字形，Ubuntu 官方（`language-selector` 的 `pkg_depends`）也未预装任何仿宋字体。发版文档（release notes、CTAN 公告等）在 ubuntu 容器里编译，这个空缺同时导致 ctex/xeCJK 手册在该环境下缺仿宋展示（#686 遗留问题的直接成因）。

## 调研过程（issue #908，6 条评论）

### 候选对比

| | FandolFang | 朱雀仿宋（`LXGWZhuqueFangsong-Regular.ttf`） |
|---|---|---|
| 来源 | TeX Live `fandol` 包，`hard` 依赖，`fontset=fandol` 现役 | CTAN 包 [lxgw-fonts](https://ctan.org/pkg/lxgw-fonts)（collection-langchinese，维护者 myhsia），含完整 `ctex-fontset-lxgw.def` |
| 成熟度 | 长期稳定 | beta（family 名带 "(technical preview)"，上游约一年未更新） |
| 字形品质 | 中规中矩 | 民国活字风格，专业设计，与 Noto 更协调（见下） |
| 体积 | 已随 ctex 必装 | lxgw-fonts 约 76MB（常规 TL 中文安装同样在场） |

### 基线定量是决定性证据

10pt「永」字的 `\box_ht:N` / `\box_dp:N` 实测（dp = 字形跌破基线的量）：

| 字体 | ht | dp |
|---|---|---|
| Noto Serif（ubuntu 现役宋体，基准） | 8.34pt | 0.76pt |
| 朱雀仿宋 | 7.91pt | 1.21pt |
| FandolFang | 7.93pt | **1.75pt**（基准 2.3 倍） |

FandolFang 的基线在与 Noto 混排时明显"掉下来"；朱雀仿宋与 Noto 的垂直协调性显著更好。这一点在 `fontset=fandol`（全家都是 Fandol，彼此一致）中不成问题，但在 ubuntu fontset（正文底色是 Noto，仿宋只是穿插字体）中会产生可见的行内跳动。

### 基线抬升 hack 验证有效但判定为有毒性

用 xeCJK 的 `\CJKsymbol` / `\CJKpunctsymbol` 输出钩子重定义为 `\raisebox` 包裹，可以把两个候选的 dp 精确抬升对齐 Noto 基准（FandolFang 需 0.099em、朱雀需 0.045em，`\box_dp` 复测零偏差）。但该方案有三类工程代价，**决定不采用**：

1. 与 xeCJK 标点压缩系统冲突：标点度量按字体缓存，`\raisebox` 引入的 hbox 打断标点边界回看逻辑，组内字符与组外全角标点相邻时触发 `Missing number`；
2. 破坏 `\lastkern` 边界恢复链等按裸 glyph 假设工作的机制（与本仓库 #873/#880/#910 系列 hbox 遮蔽问题同族）；
3. 逐字符一个 `\raisebox` 分组的性能开销。

这把"基线失谐"从否决项降级为"可缓解项"，但缓解手段本身有毒性——结论仍是选基线本来协调的字体，而不是选一个需要 hack 补救的字体。

## 决策（用户拍板）

### 1. ctex 不提供 baseline 调整功能

`\CJKsymbol`/`\CJKpunctsymbol` 重定义方案不进入 fontset 默认配置，也不作为公开接口封装。有该需求的用户可参照 issue 评论中的 MWE 自行实现，代价与边界（标点缓存冲突）由用户自行承担。

### 2. `zhfs`（仿宋）三级 fallback：朱雀仿宋 → FandolFang → Noto 宋体（现状）

仅在 XeTeX/LuaTeX 分支做运行时检测（`\fontspec_font_if_exist:nTF`，`fontset=mac`/`macnew` 已有先例），因为：

- 发版文档编译与 ubuntu 平台主流用法都是这两个引擎；
- pdfTeX(DVI)/upTeX 分支无法可靠做运行时字体探测，走静态映射保持现状（见"实现要点"）。

itshape（楷体）不受影响：`AR PL KaitiM GB`（文鼎，TL `arphic` 包自带）已满足开箱即用，未纳入本次调整范围。

### 3. `DEPENDS.txt` 新增 `soft lxgw-fonts`

TeX Live 提供包依赖声明机制（[官方说明](https://www.tug.org/texlive/pkgdepend.html)）：CTAN 上传物顶层放 `DEPENDS.txt`，每行 `hard|soft <CTAN 包名>`。`hard` 会被 TL 转换为 tlmgr 强制依赖；`soft` 表示条件性/可选依赖，tlmgr 目前忽略，仅作文档记录。ctex 已有 `hard fandol`（保证 fallback 第 2 级必装），本次新增 `soft lxgw-fonts # preferred fangsong of the ubuntu fontset` 记录朱雀仿宋这一"装了更好、不装也能用"的推荐关系。

## 取舍理由

- **为什么不是二选一而是三级 fallback**：朱雀仿宋质量最优但 beta 状态不适合作为唯一/默认必装依赖；FandolFang 已经 `hard` 依赖、开箱即用但基线欠协调；Noto 宋体永远可用但完全没有仿宋字形。三级链条把"质量优先、稳定托底、绝不失败"三个目标同时满足，且与 `fontset=mac`/`macnew` 的运行时探测先例风格一致。
- **为什么不新增独立 `fontset=lxgw` 之外的整合**：lxgw-fonts 自带的 `fontset=lxgw` 已经是"整套朱雀+落霞"体验的正确入口；本次改动的目标只是让 ubuntu 字库的 `zhfs` 单点补齐，不重复建设。
- **为什么 pdfTeX(DVI)/upTeX 不做运行时探测**：这两个引擎路径缺少可靠的运行时字体存在性检测接口，与 `fontset=mac` 的 pdfTeX/upTeX 分支处理方式一致，保持全仓库跨引擎能力边界的统一心智模型。

## 影响范围（详见"实现要点"）

- `ctex/ctex.dtx` `%<*ubuntu>` 段：XeTeX/LuaTeX 三级 fallback 探测、DVI 静态 map 分支、upTeX 分支的 `zhfs` 补全。
- `ctex/ctex.dtx` `\fangsong` 命令定义：移除 `%<!ubuntu>` guard。
- `ctex/ctex.dtx` 用户文档：`fontset` 选项说明、字体命令小节的 ubuntu 例外说明删除。
- `ctex/DEPENDS.txt`：新增 `soft lxgw-fonts` 声明。
- `\changes` 登记于 v2.6.2。

## 实现要点

以下技术点在实现阶段被确认，供未来同类"按引擎能力做运行时字体 fallback"的改动参考：

- **XeTeX/LuaTeX 分支**：`\fontspec_font_if_exist:nTF` 嵌套两层检测（朱雀 → Fandol → Noto），检测结果同时驱动 `\setCJKmonofont`（等宽，`\ttfamily` 对应字体）与 `\setCJKfamilyfont { zhfs }`——两者共用同一次探测，不是各自独立探测，保证 `\ttfamily` 与 `\fangsong` 视觉一致。
- **zhmCJK 分支**（`ctex-fontset-ubuntu.def` 内非 XeTeX/LuaTeX 且启用 zhmCJK 的路径）：补 `\setCJKfamilyfont { zhfs } { :2:NotoSerifCJK-Regular.ttc }` + `\ctex_punct_map_family:nn { zhfs } { zhsong }`（`\ctex_punct_map_family:nn` 的 `#1` 是 clist，`{\CJKttdefault, zhfs}` 单行写法同样合法，此处为对齐现有代码风格拆成两行）。
- **DVI 静态 map 分支**：`\ctex_load_zhmap:nnnn { rm } { zhhei } { zhfs } { ubuntu }` —— 第三参数（对应 `\CJKttdefault`）由 `zhsong` 改为 `zhfs`；`\ctex_load_zhmap:nnnn` 本身只是把 `#1#2#3` 分别赋给 `\CJKrmdefault`/`\CJKsfdefault`/`\CJKttdefault` 再加载 `ctex-zhmap-#4.tex`，物理字体不变仍是 Noto，此处只是族名布置对齐其他字库的 `zhfs` 命名。另需补 `\ctex_punct_map_family:nn { \CJKttdefault } { zhsong }`。
- **upTeX 分支**：`\ctex_set_upfamily:nnn { zhfs } { upzhmono } { }`（`zhmetrics-uptex` 提供的 `upzhmono` 即等宽 = Noto 宋体路径）。
- **`\fangsong` 命令**：去掉 `%<!ubuntu>` guard；用户文档两处同步（`fontset` 选项说明新增仿宋 fallback 顺序描述；字体命令小节删除"除了在 ubuntu 字库中没有 `\fangsong` 的定义外"的例外说明）。至此所有预定义字库都提供 `\songti`/`\heiti`/`\fangsong`/`\kaishu` 四个基本字体命令。

## 验证方法（可复用经验）

- **三级 fallback 全链路测试法**：建临时目录放同名空 ttf/otf 文件，配合 `TEXINPUTS` 优先级遮蔽真实字体，逐级触发 fallback，grep 编译 log 确认实际选用的字体文件名。
- **fontconfig 环境干扰识别**：本机 XeTeX 按字体名查找 `AR PL KaitiM GB`（楷体）需要 `gkai00mp.ttf` 在 fontconfig 可见；TL 自带该字体但 fontconfig 默认不索引 texmf 目录。测试机上用 `ln -s` 进 `~/.local/share/fonts` 解决——这是本地环境配置问题，不是代码缺陷，遇到类似"TL 有字体但 XeTeX 找不到"现象时应先排查 fontconfig 索引范围而非怀疑代码逻辑。
- **upTeX 验证**：`dvitype` 输出 grep `upzh*` 字体名确认族名生效。
- **DVI 分支验证**：检查 `c70zhfs.fd` 加载记录确认静态 map 生效。
- 全量 `l3build check`（4 引擎 × 181 组）通过。

## 关联记录

- Issue #908
- Commit `eb384977`（分支 `issue-908-ubuntu-fontset`）
- `llmdoc/reference/ctex-fontset-mac.md`（`\fontspec_font_if_exist:nTF` 运行时探测先例）
- `llmdoc/memory/decisions/782-fontset-mac-macos15plus-detection.md`（同类"按引擎能力做运行时字体 fallback，检测失败静默/回退"决策模式）
