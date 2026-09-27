# 决策：对 `\disablepinyin` 引入 `*` 变体并规范 `\xpinyin` 作用域控制链


## 背景

Issue #265 报告，在 `pinyinscope` 环境（或 TeX 分组）内调用 `\disablepinyin` 时，控制注音逻辑的变量的作用域会泄漏到组外，无法被正确限制。

此外，修复过程中还发现两种使用场景在设计上相互冲突：

* **场景 1（常规教学排版）**：教师在段落中用 `\disablepinyin` 关闭了全局自动注音，但在段落内仍需要对少数生僻字使用 `\xpinyin{龘}{da2}` 显式标注拼音。
* **场景 2（生成考试试卷）**：用户需要编译出一份**完全没有拼音**的文档来作为试卷，此时需要让 `\disablepinyin` 连同显式的 `\xpinyin` 一并禁用。

这两种需求的逻辑完全相反。如果只是在 `\disablepinyin` 内部禁用 `\xpinyin`，会破坏已有的排版习惯，因此需要引入粒度更细的控制方式。

PR #977（基于提交 `a12c4dda`）通过引入**双层布尔控制链**与**星号变体**解决了这一冲突，并关闭了 #265。


## 根因与设计权衡

原实现中没有一个能够控制 `\xpinyin` 宏自身是否执行的“总开关”变量。

为了同时满足“只关闭自动注音”和“在全局或局部彻底关闭注音”两种需求，设计了以下**双层控制链**：

| 命令 | 对应变量操作 | 语义 | 行为表现 |
| ---- | ------------ | ---- | -------- |
| **`\enablepinyin`**   | `\l_@@_enable_bool` $\to$ true, `\l_@@_enable_all_bool` $\to$ true | **打开总开关和自动注音** | 开启自动注音，且允许 `\xpinyin` 手动注音。 |
| **`\disablepinyin`**  | `\l_@@_enable_bool` $\to$ false                                    | **只关闭自动注音**       | 禁用自动逐字注音，但**保留** `\xpinyin` 显式注音。 |
| **`\disablepinyin*`** | `\l_@@_enable_all_bool` $\to$ false                                | **关闭总开关**           | 彻底禁用注音，连显式的 `\xpinyin` 也不再输出拼音。 |

同时，本仓库 `llmdoc/architecture/xecjk-architecture.md` 的「影子布尔的作用域必须与被控资源的作用域一致」一节（源自 #431）明确要求这一点，`coding-conventions.md` 也有同样的约定。这两个开关状态都需要能在 `pinyinscope` 等环境内局部切换、并在离开分组后恢复，因此它们必须是**局部变量**。


## 决策

引入双层布尔控制链，对 `\xpinyin` 的执行逻辑、变量规范及作用域约束做如下调整：

### 1. 变量规范与初始化

* 新定义局部影子布尔变量 `\l_@@_enable_all_bool`（总开关）与 `\l_@@_enable_bool`（自动注音开关），命名使用 `l_` 前缀，表明它们是受 TeX 分组约束的局部状态。
* 在 `\ExplSyntaxOn` 顶层（此时没有分组）使用 `\bool_set_true:N` 初始化，确保默认开启。
> **注意**：顶层上下文没有分组，因此在这里使用局部赋值 `\bool_set_true:N`，效果与全局初始化相同，也符合 `l_` 命名约定；这样也避免了混用 `\bool_gset_*:N` 可能让后续维护者误解变量命名和作用域的问题。

### 2. 作用域受控的分支切换

* `\enablepinyin`、`\disablepinyin` 及其星号变体 `\disablepinyin*` 内部对变量的操作统一改为**局部赋值**（使用 `\bool_set_true:N` / `\bool_set_false:N`）。
* 在 `pinyinscope` 环境或任意 TeX 分组内调用这些命令时，离开分组后状态会自动恢复，不再泄漏到组外。

### 3. `\xpinyin` 的分支控制与原有行为的一致性

* 在 `\xpinyin` 宏中，用 `\bool_if:NTF \l_@@_enable_all_bool` 选择分支。
* **保持垂直模式下的行为不变**：为了不在禁用（disabled）路径下改变原有的垂直模式行为，把 `\mode_leave_vertical:` 移到 `\bool_if:NTF` 分支判断之前。这样即使在段落开头且拼音被禁用，`\xpinyin` 也会无条件离开垂直模式，与原来的代码行为一致。
* **禁用路径下如何处理参数**：在禁用路径（即 `\l_@@_enable_all_bool` 为 false）下：
  * 非星号形式 `\xpinyin`：用 `\use_i:nn {#3}` 读入并丢弃后面的拼音参数，只输出汉字。
  * 星号形式 `\xpinyin*`：直接输出原始文本 `#3`。


## 兼容性与行为变更

### 向后兼容（无破坏性变更）

* **现有用户代码的行为完全不变**：引入星号变体 `\disablepinyin*` 后，普通 `\disablepinyin` 依然允许显式的 `\xpinyin` 排版拼音（即场景 1 的表现）。
* 只有当用户显式使用新引入的 `\disablepinyin*` 时，才会触发“连同 `\xpinyin` 一并禁用”的新语义（即场景 2 的表现）。

### 作用域修复

* 所有控制拼音开关的命令，其作用域现在严格受 TeX 分组（如 `pinyinscope` 环境）约束，离开分组即失效。若原文档依赖了旧版“跨组泄漏”的副作用，需要改为在组外重新声明开关状态。


## 回归覆盖

初版 PR 没有任何用例调用星号形式，两条 CI 路线仍然全绿——即使星号解析、两种 `\xpinyin` 形式的禁用分支、`\enablepinyin` 恢复或退组恢复失效，也都不会被发现。补测试时按「设 vs 不设」的对照写法（与 `multiple`／`format`／`footnote` 各键一致），两条路线各自覆盖：

| 路线 | 用例 | 固定的语义 |
| --- | --- | --- |
| XeTeX / xeCJK | `pinyin-scope01` 第 2b 项 | `\l_@@_enable_all_bool` 是局部赋值，退组自动恢复 |
| XeTeX / xeCJK | 第 2c 项 | 普通 `\disablepinyin` 只关自动注音，显式读音仍生效 |
| XeTeX / xeCJK | 第 2d 项 | `\disablepinyin*` 是总开关，显式读音与 `\xpinyin*` 一并失效 |
| XeTeX / xeCJK | 第 2e 项 | `pinyinscope` 环境这条路径的正常输出（#265 的原始场景；对全局赋值变异没有判别力，见下） |
| XeTeX / xeCJK | 第 2f 项 | `\enablepinyin` 能把总开关重新置真 |
| CJKutf8 / pdfTeX | `pinyin-cjkutf8-01` TEST 6 | 与 2c／2d 相同的三项检查，观察量是盒子高度而不是节点列表 |
| CJKutf8 / pdfTeX | TEST 7 | 退组恢复，与「从未禁用过」和「未注音」两个基准双向比对 |

第 2b 项**必须排在 2c／2d 之前**，这是它有判别力的前提，理由见下。

CJKutf8 路线必须单独覆盖，不能只测 XeTeX：禁用分支用 `\use_i:nn` 丢弃读音参数，若它在 `\@@_adjust_CJK_hook:` 那一半出错（例如读音参数没被丢弃，而是被当作正文排出），XeTeX 路线看不见。

判别力经变异实测，三个方向都能让相应用例变红：

* 让星号参数不生效（`\bool_if:NT #1` → `\c_false_bool`）→ 2d 与 CJK TEST 6 红：`yǔ`／`wén` 本不该出现却出现，CJK 侧 `not-annotated` 变 `ANNOTATED`；
* 让普通形式也关总开关（→ `\c_true_bool`）→ 2c 红：显式读音本该保留却消失；
* 局部赋值改为 `\bool_gset_false:N` → 2b（`yīn` 那行消失）与 CJK TEST 7 第二格（`annotated` → `NOT-ANNOTATED`）红。

**「退组恢复」这一项的判别力有两个必要前提**，都是盲审指出后逐项比对才确认的（初版写成了恒真断言，而注释和本文档当时都声称「只有本项会红」）：

1. **组外的观察点必须用不带星号的 `\xpinyin`。** `\xpinyin*` 进入分组后，`\xpinyin` 的星号分支会无条件调用 `\enablepinyin`，而 `\enablepinyin` 会把总开关重新置真（见 `\enablepinyin` 的第一个 `\bool_if:NF` 块）——它自己就把泄漏的禁用状态修好了。
2. **该项之前不能让 `\l_@@_enable_bool` 为真**，所以 2b 必须排在 2c／2d 之前。`\disablepinyin` 的第二个块以 `\bool_if:NT \l_@@_enable_bool` 为条件：`en`（自动注音开关）为真时，`\disablepinyin` 的这个块会连带把 `en` 置假；`en` 的赋值是局部的，离开分组即恢复成真，于是即便 `all`（总开关）泄漏成假，再走一次恢复路径也会把 `all` 拉回真。实测：进入分组前先调 `\enablepinyin`（`en=T`）时，变异后离开分组读到 `all=F` 却仍照常注音，该项逐字节不变；进入分组前 `en=F` 时，变异后 `3.99994 yīn` 消失。

因此 2e（`pinyinscope` 环境）对全局赋值变异**没有**判别力——环境自己在开头就调 `\enablepinyin`，正好违反了前提 2。它固定的是该路径的正常输出，价值在于回归测试，而不是对变异有判别力；这里如实记下，不夸大。

**测试项之间会通过残留状态互相干扰，新增项可能破坏既有项的证据。** 补完上述用例后，第 9b 项（`footnote=true` 时脚注内注音）的判据 `3.19995pt` 从基线里消失了——`75766ee9` 有、`1521e53f` 起没有。根因：`\enablepinyin` 的第二个 `\bool_if:NF` 块以 `\bool_if:NF \l_@@_enable_bool` 为条件，我新增的 2c／2d／2f 都在顶层留下 `en=T`，于是 9b 进入环境、调用 `\enablepinyin` 时那个条件不成立，`\@@_restore_footnote:` 没有重新执行，脚注里的注音就没了。逐项二分排查，确认这三项各自都会造成这个问题。修正办法是把它们各自用 `{...}` 包住，让 `en` 的改动不外泄；包好后 `3.19995` 回到基线。**新增测试项后要检查既有项的关键判据是否还在**，而不是只看退出码。

**观察点的选择要按「该路径是否确实检查被测状态」来定，不同项的理由可能不同。** 2f 声称覆盖「`\enablepinyin` 把总开关重新置真」这条路径，但初版用 `\xpinyin*{语}` 观察，实测把 `\enablepinyin` 的那个判断条件改成 `\bool_if:NF \c_true_bool`（让 `\enablepinyin` 永不置真总开关）后整份文件仍全绿——因为 `\xpinyin*` 的注音由 `\@@_replace_CJKsymbol:` 装的 `\CJKsymbol` 自动钩子产生，那条路径不检查 `\l_@@_enable_all_bool`。改用 `\xpinyin{长}{chang2}` 后该变异使 `cháng` 消失。注意这与 2b 的原因不同：2b 是观察点自己调 `\enablepinyin` 把状态改回去，2f 是观察点根本不经过被测的那个判断。

**2b 的顺序依赖机制，初版解释有误。** 原写「`all` 被拉回真」，但探针直接读取两种写法离开分组后的 `all`，**都是 F**；真正原因是 `en=T` 时注音改走 `\CJKsymbol` 自动钩子，那条路绕过 `all`。现象（进入分组前 `en=T` 则恒真、`en=F` 则变红）属实，解释已更正。

**另一条方法教训：整份文件变红不足以判定单项判别力。** 全局赋值变异下 `pinyin-scope01` 确实变红，但红的是既有的第 3／7b／7c／8 项；按段落切分逐字节比对才发现新增那一项完全没变。

CJK 侧 TEST 7 的初版是恒真断言，有两个容易出错的地方值得记住：

1. **`\hbox_set:Nn` 不能写在 CJK 环境内部**，否则离开环境后该盒子 `ht = 0pt`，与任何基准比都得不出结论。成因是局部赋值被环境分组还原成 void（环境内读它是 12.75551pt，改 `\hbox_gset:Nn` 后环境外也读到该值），不是汉字排不进盒子。每个盒子必须自带 `\begin{CJK}...\end{CJK}`，用于禁用的子分组放在盒子内部。这与文件头已记录的 TEST 3 那个问题同源。
2. **不能把禁用组和组后的字放进同一个盒子再比总高**。全局赋值变异下该盒子仍然更高（8.46454pt vs 8.39754pt）——多出的高度来自盒子里的其他内容而不是拼音，`>` 比较照报 `restored`。改为把组后的字单独放进一个盒子，并与「从未禁用过」的基准比对，变异才会变红。基准也必须取另一个从未禁用过的盒子：拿变异后的两个值互比，它们会同为 `8.39754pt` 而仍然相等。


## 影响范围

* `xpinyin/xpinyin.dtx`（更新了实现、补充了 `\disablepinyin*` 用户文档及 `\changes`）
* `Makefile`（同步更新了 `CHANGELOG_PKGS` 与相关注释）
* `CHANGELOG.md`
* `xpinyin/testfiles/pinyin-scope01.lvt`／`.tlg`、`xpinyin/testfiles-cjk/pinyin-cjkutf8-01.lvt`／`.tlg`（补齐上述回归覆盖）


## 关联记录

* PR #977
* Closes #265
* 测试设计的通用约定见 `llmdoc/reference/build-and-test.md` 的「xpinyin 的注音回归（#1041）」一节
