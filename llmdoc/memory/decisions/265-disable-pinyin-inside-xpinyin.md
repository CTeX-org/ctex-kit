# 决策：引入 `\disablepinyin*` 变体并规范 `\xpinyin` 作用域控制链

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

## 影响范围

* `xpinyin/xpinyin.dtx`（更新了实现、补充了 `\disablepinyin*` 用户文档及 `\changes`）
* `Makefile`（同步更新了 `CHANGELOG_PKGS` 接入与相关注释）
* `CHANGELOG.md`

## 关联记录

* PR #977
* Closes #265
