---
title: "735: zhlineskip split 行距泄漏修复"
type: reflection
---

# 735: zhlineskip split 行距泄漏修复

## 问题

zhlineskip 的 `restoremathleading` 机制对 `\gather@split` 的 patch 将 `\linespread{1}\selectfont` 放在 `\vcenter\bgroup` **之前**。这导致行距恢复泄漏到外层 display 组，改变了 TeX 在 `$$` 级别用于 display skip 计算和垂直居中的 `\baselineskip`。

表现：`equation` + `split` 的公式看起来"贴顶"，上方间距偏小；而 `aligned` 不受影响（它不走 `\gather@split` 路径）。

## 修复

将 `\linespread` 恢复和 `\spread@equation` 一起移入 `\vcenter\bgroup` 内部：

```diff
  \patchcmd\gather@split
-   {\spread@equation}
-   {\linespread{\ZhLS@mathlinespread}\selectfont\spread@equation}
+   {\spread@equation\vcenter\bgroup}
+   {\vcenter\bgroup\linespread{\ZhLS@mathlinespread}\selectfont\spread@equation}
    {}{}
```

关键洞察：`\patchcmd` 的搜索模式需要扩展到包含 `\vcenter\bgroup`，才能把整个操作移入 vcenter 组。

## 诊断技巧

1. **分组层级追踪**：在 `\endmathdisplay` 处 hook `\typeout{\the\baselineskip}` 对比 `equation` / `split` / `aligned` 三者的值，发现 split 路径的外层 baselineskip 被意外改小。
2. **vbox 尺寸对比**：把 `text + equation + text` 放入 `\vbox`，测量总高度。bug 存在时 split 版本比修复后矮约 1.5pt（因 display skip 用了错误的 baselineskip）。
3. **回退验证**：临时还原 bug，确认测试确实 FAIL。

## 测试框架

zhlineskip 之前没有 l3build 测试基础设施。本次为其新建了完整框架：

- `build.lua`：`stdengine = "pdftex"`, `checkengines = {"pdftex"}`
- `testfiles/basic-leading.lvt`：body baselineskip、gather/align/multline vbox 尺寸
- `testfiles/split-leading.lvt`：多行 split、单行 split、split+tag 的 vbox 尺寸（#735 回归）

回归测试的策略是捕获 vbox 绝对尺寸。若 bug 重现，split 的 vbox 高度会变化，导致 `.tlg` 基线不匹配。

## 教训

- **TeX 分组语义在 patch 中至关重要**：`\patchcmd` 做的是 token 替换，不理解分组层级。把副作用放在正确的组内需要人工确认 token 流中的 `\bgroup` / `\egroup` 位置。
- **不同多行数学环境走不同代码路径**：`split` 走 `\gather@split` + `\vcenter`；`aligned` 走 `\start@aligned`；`gather`/`align`/`multline` 各有自己的 `\start@*`。不能假设一个环境的 patch 策略适用于所有环境。
- **为没有测试的包补上框架的成本很低**：zhlineskip 的 `build.lua` 只需 15 行，两个测试文件即可覆盖核心功能和回归场景。
