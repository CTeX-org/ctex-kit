---
name: "910-verb-drain-vs-drain-verb"
description: "决策: xeCJK #910 \\verb 修复用专用 \\@@_drain_ecglue_verb: 而非复用 \\@@_drain_ecglue:, 关键差别在 else 分支是否 clear \\g_@@_last_node_tl"
metadata:
  type: decision
---

# 决策：#910 `\verb` 修复使用专用 drain 函数

## 背景

xeCJK issue #910 修复 CJK 文字与 `\verb` / shortvrb 之间 `\CJKecglue` 丢失。`\verb` 入口 `\leavevmode\null` 产生 0×0 hbox，与 #873 `\HD@target` 的 `\raisebox` 同型遮蔽。但 `\verb` 是分隔符扫描宏，patch 包装时控制流被 `\@ifstar\@sverb\@verb` 接管，无法在原命令调用后注入 save/replay，因此只能用 drain（与 #880 同型）。

最初实现复用 `\@@_drain_ecglue:`（#880 `\Url@FormatString` 用的 drain）。`xeCJK` 自带的 `verb-ecglue01.lvt` PASS，但 `make check-ctex` 在 `verbatim01.xetex` 上 fail：verb 内 FandolFang CJK 字体的 `内联代码` 与 verb 外 FandolSong 的 `和` 之间少了一个 `\glue 0.0 plus 0.60931`（CJKglue）。

## 候选方案

**方案 A（采纳）**：新增 `\@@_drain_ecglue_verb:`，复制 `\@@_drain_ecglue:` 的整体结构但 else 分支什么都不做。

**方案 B（未采纳）**：直接复用 `\@@_drain_ecglue:`，更新 ctex `verbatim01.tlg` baseline 接受 `\CJKglue` 缺失。

## 决策

采纳方案 A：

```tex
\cs_new_protected:Npn \@@_drain_ecglue_verb:
  {
    \xeCJK_if_last_node:TF
      {
        \tl_if_empty:NF \g_@@_last_node_tl
          {
            \xeCJK_remove_node:
            \skip_horizontal:N \l_@@_ecglue_skip
          }
      }
      { }
  }
```

与 `\@@_drain_ecglue:` 的唯一差别：else 分支不调 `\tl_gclear:N \g_@@_last_node_tl`。

## 理由

`\@@_drain_ecglue:` 的 else 分支主动 clear `\g_@@_last_node_tl` 是给 #880 `\Url@FormatString` 设计的：

- `\url` 内容进 math 模式，math 节点直接吞掉 marker；此时 `\xeCJK_if_last_node:TF` 走 else 分支。
- math 模式不参与 interchar token transition，math 退出后由 `\@@_if_last_math:` 路径单独处理边界。
- 因此 tl 状态不会被下游再次消费，**主动 clear 是为防止它残留误导后续 `\@@_recover_glue_whatsit:` default 分支**（避免类似 #807 的 stale state）。

但 `\verb` 与之不同：

- `\verb` 不进 math 模式，verb 内字符仍参与 token-level interchar。
- ctex `fontset=fandol` 模式下，`\setCJKmonofont { FandolFang-Regular.otf }` 让 `\verb` 内 CJK 字符走 FandolFang（仍是 CJK class），verb 出口到外部 CJK 字符仍触发 CJK→CJK transition，需要 `\g_@@_last_node_tl` 保持当前值才能正确输出 `\CJKglue`。
- 主动 clear 会破坏这条 transition，造成 `代码` 与 `和` 之间 `\CJKglue` 丢失。

方案 B 被否决：

- ctex `verbatim01` 的 baseline 是合理的语义——verb 内 CJK 字体到 verb 外 CJK 字体之间应有 `\CJKglue`（CJK 字符默认 0.0+0.6pt 间距），不应被 patch 破坏。
- 更新 baseline 接受 `\CJKglue` 缺失等于在 ctex 模式下引入新 bug 来交换 xeCJK 模式下的 bug 修复。

## 后续

- 若未来增加新的 `\verb`-like 调用方（分隔符扫描宏 + 调用方之后仍有 token-level interchar），可复用 `\@@_drain_ecglue_verb:`。
- 若新调用方在 ctex 模式下走特殊字体路径（如 `\verbatim@font` hook 切换字体），仍需用 `_verb` 版本保留 tl。
- 进一步推广可考虑统一抽象成 `\@@_drain_ecglue:` 接 boolean 参数控制 else 行为，但当前只两个变体不值得抽象。

## 落地引用

- 实现：`xeCJK/xeCJK.dtx` `\@@_drain_ecglue_verb:` / `\@@_patch_verb:`（commits `d6e28be1` 主修复 + `d0cf09a1` v3.10.1 + `32553705` 专用 drain）。
- 回归测试：`xeCJK/testfiles/verb-ecglue01.lvt` / `.tlg`。
- 反思：[[../reflections/910-verb-null-hbox-drain]]。
- 关联决策：[[873-880-fixed-point-vs-default-narrowing]]（"修复位置由被遮蔽的节点类型决定"，本决策补一个子规则：drain 的 else 分支策略由"调用方之后是否仍有 token-level interchar"决定）。
