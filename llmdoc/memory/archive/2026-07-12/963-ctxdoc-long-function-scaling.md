# Reflection: Issue #963 ctxdoc 长函数名压缩

## 背景

`support/ctxdoc.cls` 原先沿用 l3doc 对超长函数名整体右移的处理，函数列表可能越过左侧边界。目标是在不压缩 Added/Updated 日期与可展性标记的前提下，只水平压缩函数名。

## 方案演进

首版在 `\__codedoc_function_assemble:` 阶段缩放整个 functions coffin，虽然修正了边界，却把 Added/Updated 日期一并压缩。最终补丁点上移到 `\__codedoc_typeset_function_block:nN`：函数名与 TF 后缀先进入独立 hbox，压缩完成后再输出 EXP/rEXP 标记、variants 和日期行。

最终压缩采用两阶段模型而不是一次缩到固定宽度。正常范围依次乘以 `5/6`、`4/5`、`3/4`、`2/3`、`1/2`，望远镜乘积使累计宽度成为原宽的 `5/6`、`4/6`、`3/6`、`2/6`、`1/6`，即相对原宽等差下降；五档后仍超宽才直接自适应到可用边注宽度。可用宽度总是扣除 `\marginparsep`，EXP 与 rEXP 再分别为右栏标记预留约 `1.2em` 与 `1.5em`，不可展函数不额外扣除。

#963 的讨论最初提出约 85% 的 hard limit，随后先尝试固定减量，最终发现该因子仍随当前宽度变化，不能形成真正等差的累计字宽，因此改用上述望远镜比例形成少量等差档位，极端长度才自适应。最终的 `1.2em` / `1.5em` 不是任意常数：l3doc 的 function 表在可展性标记前增加 6pt 列间距，实测 `$\star$` 加 6pt 约为 `1.2em`，`\ding{73}` 加 6pt 约为 `1.5em`；使用 em 近似可以随当前字号缩放。

## 上游兼容边界

最终实现完整重定义 l3doc 私有函数，因此把依赖收敛到 l3doc 2026-06-18：`\LoadClass` 声明该最低日期，随后用 `\@ifclasslater` 再做硬门禁，失败时复用 `\ctex_patch_failure:N` 的 critical 路径。源码注释同时列出重定义依赖的六个 l3doc 私有接口，供升级时核对。

版本门禁自身也经过两轮审查修正：一次把 expl3 命令放进 `\ExplSyntaxOff` 区域，导致失败分支会按错误 catcode 分词；另一次条件分支在整理时丢失，使 critical 路径无条件触发并令全部文档构建失败。最终顺序固定为先进入 expl3 语法、声明消息并定义 `\ctex_patch_failure:N`，再执行 `\@ifclasslater`，最后退出 expl3 语法。版本门禁必须用旧版本和正常版本两条路径审查，不能只验证 happy path。

## Review 循环中的语义校验

早期自动审查曾按命令名称直觉把 `\dim_until_do:nNnn` 误读为先执行后判断，并建议换成 `\dim_do_while:nNnn`；作者对照 `interface3` 后指出前者实际先比较，关系为假时才执行循环体。提交历史短暂采纳错误建议后又恢复原写法。对名称相近的 expl3 循环接口，审查结论必须来自接口文档原文或最小实验，不能从英语词序推断。

## 测试策略

`ctex/test/testfiles-ctxdoc/resize-function.lvt` 在现有 `config-ctxdoc` 专项配置下使用 `\loggingoutput` 比较节点结构，覆盖 Added 日期、rEXP、pTF 与不同长度函数名。它与 `patch-health.lvt` 分工：前者守排版结构，后者守类加载及 patch 硬失败。

## 可复用教训

- 修复复合排版对象时，应先找到最窄的可变子对象；缩放整个父 coffin 容易连带改变日期、标签等稳定元素。
- 完整覆盖上游私有宏时，源码对标日期、最低版本门禁、依赖接口清单和专项回归必须一起维护。
- 自动审查对底层接口语义的判断需要用官方接口文档或最小实验复核；连续增量审查也要覆盖失败分支，避免 catcode 和条件丢失只在异常路径暴露。
