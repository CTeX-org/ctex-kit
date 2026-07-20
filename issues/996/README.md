# Issue #996 资产

`\hbox{中\hskip10pt plus 1pt minus 1pt 文}` 连续构造两次, 第二个盒子的显式
`\hskip` 被边界恢复链误判为源码空格并替换成 CJKglue (30.0pt → 20.0pt)。

根因: 盒尾 `}` (catcode 2) 的 CJK→Boundary handler 置位的
`\g__xeCJK_glue_check_pending_bool` 跨 `\setbox` 泄漏; 下一个盒内
Boundary→CJK 路径在 pending 状态下消费了显式 glue。v3.10.3 与 PR #999
行为一致 (预存缺陷, 非 #999 引入)。

- `issue996-mwe.tex` — 最小复现 + workaround。
- `issue996-confirm.png` — 复现输出: FIRST=30pt, SECOND=20pt;
  `中\kern0pt\hskip10pt...` (显式 glue 前加 `\kern0pt`) 恢复 30pt。

Workaround: 在显式 `\hskip` 前加 `\kern0pt`, 阻断源码空格检查越过
显式边界到达 CJK marker。
