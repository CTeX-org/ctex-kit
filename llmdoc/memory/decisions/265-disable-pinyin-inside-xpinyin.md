# 决策：对 `\disablepinyin` 引入 `*` 变体并规范 `\xpinyin` 作用域控制链


## 背景

Issue #265 报告，控制注音逻辑的变量在 `pinyinscope` 环境（或 TeX 分组）内调用 `\disablepinyin` 时作用域发生泄漏，无法被正确限制。

此外，在深入修复过程中发现了一个深层的用户体验与设计冲突（Case）：

* **Case 1（常规教学排版）**：教师在段落中用 `\disablepinyin` 关闭了全局自动注音，但在段落内仍需要对少数生僻字使用 `\xpinyin{龘}{da2}` 显式标注拼音。
* **Case 2（生成考试试卷）**：用户需要编译出一份**完全没有拼音**的文档来作为试卷，此时需要让 `\disablepinyin` 连同显式的 `\xpinyin` 行为一并禁用。

为了兼顾这两种完全相反的逻辑，单纯地在 `\disablepinyin` 内部禁用 `\xpinyin` 会破坏已有的排版习惯。因此，必须引入更细粒度的控制变体。

PR #977（基于提交 `a12c4dda`）通过引入**双层布尔控制链**与**星号变体**优雅地解决了这一冲突，并关闭了 #265。


## 根因与设计权衡

在原实现中，缺乏一个能够控制 `\xpinyin` 宏自身是否执行的“总开关”变量。

为了同时满足“局部自动注音开关”和“全局/局部强力拉闸”的需求，我们设计了以下**双层控制链（合闸/开灯/拉闸）**：

| 命令 | 对应变量操作 | 语义解释（比喻） | 行为表现 |
| ---- | ------------ | ---------------- | -------- |
| **`\enablepinyin`**   | `\l_@@_enable_bool` $\to$ true, `\l_@@_enable_all_bool` $\to$ true | **合闸并开灯** 💡 | 开启自动注音，且允许 `\xpinyin` 手动注音。 |
| **`\disablepinyin`**  | `\l_@@_enable_bool` $\to$ false                                    | **关灯** 🔌    | 禁用自动逐字注音，但**保留** `\xpinyin` 显式注音。 |
| **`\disablepinyin*`** | `\l_@@_enable_all_bool` $\to$ false                                | **拉闸** 🚫    | 彻底禁用注音，连显式的 `\xpinyin` 也不再输出拼音。 |

同时，本仓库 `coding-conventions.md` 明确规定：“影子布尔的作用域必须与被控资源的作用域一致”（源自 #431 规则）。由于这两个开关状态均需要支持在 `pinyinscope` 等环境内局部切换并在退组后恢复，它们必须是**局部变量**。


## 决策

引入双层布尔控制链，对 `\xpinyin` 的执行逻辑、变量规范及作用域约束进行如下调整：

### 1. 变量规范与初始化

* 新定义局部影子布尔变量 `\l_@@_enable_all_bool`（主控开关）与 `\l_@@_enable_bool`（自动注音开关），其命名使用 `l_` 前缀，显式声明其作为局部状态受 TeX 分组约束。
* 在 `\ExplSyntaxOn` 顶层（此时无分组）使用 `\bool_set_true:N` 进行安全初始化，确保默认开启。
> **注意**：由于顶层上下文没有分组，在此处使用局部赋值 `\bool_set_true:N` 即可达到安全的全局初始化效果，且完美契合 `l_` 命名约定，避免了混用 `\bool_gset_*:N` 给后续维护者带来的命名和作用域误导。

### 2. 作用域受控的分支切换

* 将 `\enablepinyin`、`\disablepinyin` 及其星号变体 `\disablepinyin*` 内部对变量的操作定性为**局部赋值**（使用 `\bool_set_true:N` / `\bool_set_false:N`）。
* 当在 `pinyinscope` 环境或任意 TeX 局部组内调用这些命令时，退出分组后状态会自动恢复，彻底杜绝了作用域跨组泄漏的问题。

### 3. `\xpinyin` 的分支控制与底层行为一致性

* 在 `\xpinyin` 宏中，应用 `\bool_if:NTF \l_@@_enable_all_bool` 进行分支控制。
* **确保垂直模式行为一致**：为了防止在禁用（disabled）路径下破坏原有的垂直模式行为，将 `\mode_leave_vertical:` 移至 `\bool_if:NTF` 分支判断之前。确保即使在段落起始位置且拼音被禁用时，`\xpinyin` 仍能无条件退出垂直模式，与原始代码行为绝对一致。
* **禁用路径下的参数消费**：在禁用路径（即 `\l_@@_enable_all_bool` 为 false）下：
* 非星号形式 `\xpinyin`：正确使用 `\use_i:nn {#3}` 消费并丢弃后续拼音参数，仅输出汉字。
* 星号形式 `\xpinyin*`：直接输出原始文本 `#3`。


## 兼容性与行为变更

### 向后兼容（No Breaking Change）

* **现有用户代码的行为完全不变**：引入星号变体 `\disablepinyin*` 后，普通 `\disablepinyin` 依然允许显式的 `\xpinyin` 排版拼音（即 Case 1 的表现）。
* 只有当用户显式使用新引入的 `\disablepinyin*` 时，才会触发“连同 `\xpinyin` 一并禁用”的新语义（即 Case 2 的表现）。

### 作用域修复

* 所有控制拼音开关命令的作用域现在严格受 TeX 分组（如 `pinyinscope` 环境）约束，退组即失效。若原文档依赖了旧版“跨组泄漏”的副作用，需要调整为在组外重新声明开关状态。


## 回归覆盖

初版 PR 没有任何用例调用星号形式，两条 CI 路线仍然全绿——星号解析、两种 `\xpinyin` 形式的禁用分支、`\enablepinyin` 恢复与退组恢复若失效都不会被发现。补测试时按「设 vs 不设」的对照写法（与 `multiple`／`format`／`footnote` 各键一致），两条路线各自覆盖：

| 路线 | 用例 | 固定的语义 |
| --- | --- | --- |
| XeTeX / xeCJK | `pinyin-scope01` 第 2b 项 | `\l_@@_enable_all_bool` 是局部赋值，退组自动恢复 |
| XeTeX / xeCJK | 第 2c 项 | 普通 `\disablepinyin` 只关自动注音，显式读音仍生效 |
| XeTeX / xeCJK | 第 2d 项 | `\disablepinyin*` 是总开关，显式读音与 `\xpinyin*` 一并失效 |
| XeTeX / xeCJK | 第 2e 项 | `pinyinscope` 环境这条路径的正常输出（#265 的原始场景；对全局赋值变异无判别力，见下） |
| XeTeX / xeCJK | 第 2f 项 | `\enablepinyin` 能把总开关重新置真 |
| CJKutf8 / pdfTeX | `pinyin-cjkutf8-01` TEST 6 | 同 2c／2d 三格，观察量是盒高而非节点列表 |
| CJKutf8 / pdfTeX | TEST 7 | 退组恢复，与「从未禁用过」和「未注音」两个基准双向比对 |

第 2b 项**必须排在 2c／2d 之前**，这是它有判别力的前提，理由见下。

CJKutf8 那条必须单独覆盖，不能只测 XeTeX：禁用分支走 `\use_i:nn` 丢弃读音参数，若它在 `\@@_adjust_CJK_hook:` 那一半出错（例如读音参数没被吃掉而漏排成正文），XeTeX 路线看不见。

判别力经变异实测，三个方向都能让相应用例变红：

* 让星号参数不生效（`\bool_if:NT #1` → `\c_false_bool`）→ 2d 与 CJK TEST 6 红：`yǔ`／`wén` 本不该出现却出现，CJK 侧 `not-annotated` 变 `ANNOTATED`；
* 让普通形式也关总开关（→ `\c_true_bool`）→ 2c 红：显式读音本该保留却消失；
* 局部赋值改为 `\bool_gset_false:N` → 2b（`yīn` 那行消失）与 CJK TEST 7 第二格（`annotated` → `NOT-ANNOTATED`）红。

**「退组恢复」这一项的判别力有两个必要前提**，都是盲审指出后逐项比对才确认的（初版写成了恒真断言，而注释和本文档当时都声称「只有本项会红」）：

1. **组外的观察点必须用不带星号的 `\xpinyin`。** `\xpinyin*` 的星号分支进组后无条件调 `\enablepinyin`（`xpinyin.dtx:680`），而 `\enablepinyin` 会把总开关重新置真（`:716-717`）——它自己就把泄漏的禁用状态修好了。
2. **该项之前不能让 `\l_@@_enable_bool` 为真**，所以 2b 必须排在 2c／2d 之前。`\disablepinyin` 的第二个块以 `\bool_if:NT \l_@@_enable_bool` 为条件（`:741`），`en` 为真时它会连带把 `en` 置假；`en` 的赋值是局部的，退组即恢复成真，于是即便 `all` 泄漏成假，再走一次恢复路径也会把 `all` 拉回真。实测：组前先调 `\enablepinyin`（`en=T`）时，变异后退组读到 `all=F` 却仍照常注音，该项逐字节不变；组前 `en=F` 时，变异后 `3.99994 yīn` 消失。

因此 2e（`pinyinscope` 环境）对全局赋值变异**没有**判别力——环境自己在开头就调 `\enablepinyin`，正好落入前提 2 的反面。它固定的是该路径的正常输出，属回归价值，不是变异判别力；如实记下而不夸大。

**测试项之间会通过残留状态互相干扰，新增项可能破坏既有项的证据。** 补完上述用例后，第 9b 项（`footnote=true` 时脚注内注音）的判据 `3.19995pt` 从基线里消失了——`75766ee9` 有、`1521e53f` 起没有。根因：`\enablepinyin` 的第二个块以 `\bool_if:NF \l_@@_enable_bool` 为守卫（`xpinyin.dtx:718`），我新增的 2c／2d／2f 都在顶层留下 `en=T`，于是 9b 进环境时那个守卫不放行，`\@@_restore_footnote:` 没有重新执行，脚注里的注音就没了。逐项二分确认是这三项各自都会触发。修法是把它们各自用 `{...}` 包住，让 `en` 的改动不外泄；包好后 `3.19995` 回到基线。**新增测试项后要检查既有项的关键判据是否还在**，而不是只看退出码。

**观察点的选择要按「该路径是否真的查被测状态」来定，不同项的理由可能不同。** 2f 声称守护「`\enablepinyin` 把总开关重新置真」这条路径，但初版用 `\xpinyin*{语}` 观察，实测把 `:716` 的守卫改成 `\bool_if:NF \c_true_bool`（让 `\enablepinyin` 永不置真总开关）后整份文件仍全绿——因为 `\xpinyin*` 的注音由 `\@@_replace_CJKsymbol:` 装的 `\CJKsymbol` 自动钩子产生，那条路不查 `\l_@@_enable_all_bool`。改用 `\xpinyin{长}{chang2}` 后该变异使 `cháng` 消失。注意这与 2b 的原因不同：2b 是观察点自己调 `\enablepinyin` 把状态改回去，2f 是观察点根本不经过被测的那个判断。

**2b 的顺序依赖机制，初版解释有误。** 原写「`all` 被拉回真」，但探针直读两种写法退组后的 `all` **都是 F**；真正原因是 `en=T` 时注音改走 `\CJKsymbol` 自动钩子，那条路绕过 `all`。现象（组前 `en=T` 则恒真、`en=F` 则变红）是真的，解释已更正。

**另一条方法教训：整份文件变红不足以判定单项判别力。** 全局赋值变异下 `pinyin-scope01` 确实变红，但红的是既有的第 3／7b／7c／8 项；按段落切分逐字节比对才发现新增那一项完全没变。

CJK 侧 TEST 7 的初版是恒真断言，两个坑值得记住：

1. **`\hbox_set:Nn` 不能写在 CJK 环境内部**，否则出环境后该盒 `ht = 0pt`，与任何基准比都得不出结论。成因是局部赋值被环境分组还原成 void（环境内读它是 12.75551pt，改 `\hbox_gset:Nn` 后环境外也读到该值），不是汉字排不进盒子。每个盒子必须自带 `\begin{CJK}...\end{CJK}`，禁用用的子分组开在盒内。这与文件头已记录的 TEST 3 那个坑同源。
2. **不能把禁用组和组后的字放进同一个盒子再比总高**。全局赋值变异下该盒仍然更高（8.46454pt vs 8.39754pt）——多出的高度来自盒内其他内容而不是拼音，`>` 比较照报 `restored`。改为组后单独装盒，并与「从未禁用过」的基准比对，变异才真的变红。基准也必须取另一个从未禁用过的盒子：拿变异后的两个值互比，它们会同为 `8.39754pt` 而仍然相等。


## 影响范围

* `xpinyin/xpinyin.dtx`（更新了实现、补充了 `\disablepinyin*` 用户文档及 `\changes`）
* `Makefile`（同步更新了 `CHANGELOG_PKGS` 接入与相关注释）
* `CHANGELOG.md`
* `xpinyin/testfiles/pinyin-scope01.lvt`／`.tlg`、`xpinyin/testfiles-cjk/pinyin-cjkutf8-01.lvt`／`.tlg`（补齐上述回归覆盖）


## 关联记录

* PR #977
* Closes #265
* 测试设计的通用约定见 `llmdoc/reference/build-and-test.md` 的「xpinyin 的注音回归（#1041）」一节
