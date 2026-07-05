---
name: "431-latinpunct-option"
description: "决策: #389/#431 新增 LatinPunct 选项让共用码位标点（弯引号/间隔号/省略号）可切换为西文字体输出——归入 Half* 而非 Default; 排除破折号保持与 PoZheHaoLigature 正交; 状态记录改用局部 boolean 并回溯修正 PoZheHaoLigature 同类作用域问题"
metadata:
  type: decision
---

# 决策：#389/#431 新增 LatinPunct 选项，状态布尔改为局部作用域

## 背景

部分 Unicode 码位中西文共用：弯引号 U+2018/U+2019/U+201C/U+201D、间隔号 U+00B7、省略号 U+2025/U+2026/U+2027。xeCJK 默认把它们归入全角标点类，用 CJK 字体输出全角字形。这在以西文为主的文档中会造成问题：输入法/编辑器的 smart quotes 默认产生这些码位，夹在英文单词内部的撇号（如 `Children's` 中的 U+2019）被排成突兀的全角形式，用户极易在不知情的情况下踩坑（Issue #431）。Issue #389 中 `RuixiZhang42` 提出了 `\xeCJKUseLatinPunct` switch 原型，本次基于该原型正式实现为 `xeCJKsetup` 选项。

## 决策 1：新增 `LatinPunct` 选项，归入 `Half*` 类而非 `Default` 类

`\xeCJKsetup{LatinPunct}`：`true`（默认）把 U+2018/U+201C 归入 `HalfLeft`、U+00B7/U+2019/U+201D/U+2025/U+2026/U+2027 归入 `HalfRight`；`false` 恢复 `FullLeft`/`FullRight`。

**备选方案**：归入 `Default`（编号 0，最泛化的西文类）。

**采纳方案**：归入 `HalfLeft`/`HalfRight`。

**理由**：`Half*` 类保留了半角标点固有的 interchar 间距语义（与 CJK 字符相邻时按半角标点规则处理边界间距/`\CJKecglue`），语义上更贴合"这些字符本质是标点，只是恰好共用码位"这一事实；`Default` 类语义泛化到"任意西文字符"，会丢失标点专属的间距处理路径。字符集选择与 `true`/`false` 的处理动作直接沿用 #389 中已验证过的 `\xeCJKUseLatinPunct` 原型，不重新设计语义。

## 决策 2：破折号（U+2014/U+2E3A）与半字线（U+2013）刻意排除在 `LatinPunct` 字符集之外

**理由**：这三个字符属于 #382 引入的 `PoZheHaoLigature`/CLReq 两字宽处理语义——U+2014 连用需要满足"总宽随连用数量线性增长"的排版不变量，且可选启用 OpenType 合字。这与 `LatinPunct` 要解决的问题（单个标点字符该用哪种字体、要不要压缩）完全不同维度。两个选项分别控制不同的字符子集，保持正交，互不干扰；`latinpunct01.lvt` 与既有 `dashwidth01.lvt` 都各自包含"另一选项不影响本选项字符集"的断言。

## 决策 3：状态记录布尔改为局部作用域（`\l_@@_latin_punct_bool`），并回溯修正 `PoZheHaoLigature`

初版实现沿用 `PoZheHaoLigature` 既有写法，用全局布尔 `\g_@@_latin_punct_bool` 记录开关状态。

**发现的 bug**：`\XeTeXcharclass` 赋值本身是 TeX 分组局部的——`{\xeCJKsetup{LatinPunct=false} ... }` 退出分组后字符类自动恢复，但全局布尔不随分组恢复。此后若在分组外调用 `\xeCJKResetPunctClass`，会按已经过时的全局布尔值错误重放归类。

**采纳方案**：改为局部布尔 `\l_@@_latin_punct_bool`，使影子状态与被记录的 `\XeTeXcharclass` 赋值同处于同一 TeX 分组作用域。

**理由**：任何"记录某个局部资源当前配置"的影子状态变量，其作用域必须与被记录资源本身的作用域一致，否则跨分组场景下必然出现状态与实际不符的窗口期。这不是 `LatinPunct` 独有的问题，而是所有基于 `\XeTeXcharclass`/`\catcode` 等分组局部原语设计 opt-in 开关时的通用约束。

**回溯修正**：审查后发现 `PoZheHaoLigature` 的 `\g_@@_pozhehao_ligature_bool` 存在完全相同的作用域不一致问题，只是此前测试未覆盖"分组内切换后退组"场景，未被触发。本次一并改为局部 `\l_@@_pozhehao_ligature_bool`。两个选项现在都遵循同一作用域约束，且都在 `\xeCJKResetPunctClass` 末尾按各自局部布尔值重放归类。

## 影响范围

- `\xeCJKResetPunctClass` 的公开行为不变（仍然重放两个选项的当前状态），但内部依赖的布尔变量名从 `\g_@@_pozhehao_ligature_bool` 改为 `\l_@@_pozhehao_ligature_bool`——这是私有实现细节变更，不影响任何公开接口，无需用户侧适配。
- `llmdoc/memory/decisions/811-halfright-prebreakpenalty.md` 中"`HalfRight` 类固定包含 13 个字符"的历史描述已过时（`LatinPunct` 默认 true 会追加 6 个共用码位标点），已在该决策文档中补充更新说明。

## 归属与关联

- 实现：`xeCJK/xeCJK.dtx`（`LatinPunct` 选项、`\l_@@_latin_punct_bool`、`\l_@@_pozhehao_ligature_bool`、`\xeCJKResetPunctClass`），commit `d4125106`，分支 `issue-431-shared-quotes`。
- 回归测试：`xeCJK/testfiles/latinpunct01.lvt`（6 组：默认全角类断言、切换后类断言+盒宽实测、分组局部性、`\xeCJKResetPunctClass` 保持、关闭恢复、破折号不受影响）。xeCJK 92/92、ctex 181/181 全量通过。
- 架构文档：`llmdoc/architecture/xecjk-architecture.md` 标点压缩系统一节新增 "LatinPunct 选项" 小节（含影子布尔作用域一致性教训）；字符分类体系表补充动态成员说明。
- 关联决策：[[382-dash-width-and-ligature-opt-in]]（`PoZheHaoLigature` 正交关系与零注入字符类模式先例）、[[811-halfright-prebreakpenalty]]（`HalfRight` 类历史基线已随本决策更新）。
