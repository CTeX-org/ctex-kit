# 决策: textcolor 包裹 ulem 类 fntef 命令时 last_node_tl 污染

## 问题

`\textcolor{red}{\CJKunderline{文字}}文字` 等 textcolor 包裹 ulem 类 fntef 命令（`\CJKunderline`, `\CJKsout`, `\CJKunderwave`, `\CJKunderdblline`）时，fntef 效果后续的 CJK 字符前产生多余的 3.33pt CJKecglue（应为 CJKglue）。

## 根因

ulem 的 `\UL@end` 定界符中包含 `*` 字符（ASCII，属于 Default 字符类）。在 ulem 处理结束时，`*` 被排版到最后一个 hbox 段中，触发 XeTeX 的 Default->Boundary interchar class 转换。这将全局变量 `\g__xeCJK_last_node_tl` 从 `CJK` 污染为 `default`。

随后 `\reset@color`（color pop whatsit 后调用）读取被污染的值，插入了 default 类型的 kern pair (`\kern -0.00002 \kern 0.00002`) 而非 CJK 类型 (`\kern -0.00011 \kern 0.00011`)。后续 CJK->CJK 间距检测走到 ecglue 分支，产生多余的 3.33pt 间距。

## 方案

在 `\xeCJK_ulem_right:` / `\__xeCJK_ulem_end:` 前后 save/restore `\g__xeCJK_last_node_tl`：

```
\g__xeCJK_ulem_saved_last_node_tl  (新增变量)

\xeCJK_ulem_right: 开始时：
  \tl_gset_eq:NN \g__xeCJK_ulem_saved_last_node_tl \g__xeCJK_last_node_tl

\__xeCJK_ulem_end: 完成后：
  \tl_gset_eq:NN \g__xeCJK_last_node_tl \g__xeCJK_ulem_saved_last_node_tl
```

## 设计决策

- **与 #826-fntef-color-global-state 的对称性**：
  - fntef(color) 方向（fntef 包裹 textcolor）：通过 `\xeCJK_fntef_sbox:n` 的 hbox 前后隔离 `\g_@@_last_node_tl`
  - color(fntef) 方向（textcolor 包裹 fntef）：通过 `\xeCJK_ulem_right:` / `\__xeCJK_ulem_end:` 的 save/restore 隔离 `\g_@@_last_node_tl`
  两者修复相同变量的不同污染路径，互补覆盖。
- **save/restore 而非禁用 interchar**：ulem 内部已通过 `\makexeCJKinactive` 关闭 interchar，但 `\UL@end` 的 `*` 字符在 interchar 重新激活的上下文中被排版（ulem 的 after-group 机制），因此不能通过延长 inactive 范围来解决，必须显式保护全局状态。
- **新增全局变量 `\g__xeCJK_ulem_saved_last_node_tl`**：使用独立变量而非 `\l_@@_tmp_tl`，因为 ulem 跨越多个分组层级，局部变量不安全。
- **仅影响 ulem 类命令**：`\CJKunderdot`/`\CJKunderdbldot` 不走 ulem 路径，不受此问题影响。

## 测试覆盖

`xeCJK/testfiles/fntef-color01.lvt`：原 Test 8（信息性记录）拆分为 Test 8-12（PASS/FAIL 断言），分别覆盖：
- Test 8: `\textcolor{\CJKunderline{...}}` 后续间距
- Test 9: `\textcolor{\CJKsout{...}}` 后续间距
- Test 10: `\textcolor{\CJKunderwave{...}}` 后续间距
- Test 11: `\textcolor{\CJKunderdblline{...}}` 后续间距
- Test 12: 多种 fntef 效果组合

## 文件变更

- `xeCJK/xeCJK.dtx`: 3 行核心修复 + `\changes` 条目 + CheckSum 11360->11368
- `xeCJK/testfiles/fntef-color01.lvt`: 测试强化
- `xeCJK/testfiles/fntef-color01.tlg`: 基线更新

## 归属

Issue #830，属于边界恢复状态机的 `\g_@@_last_node_tl` 污染修复系列。与 #826-fntef-color-global-state（fntef 包裹 color 方向）构成完整的双向覆盖。
