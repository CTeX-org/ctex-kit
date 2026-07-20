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

## 修复分支验证（2026-07-20）

修复分支 `fix-996-998-1000-boundary-capture`（commit `085f4f86` 起）：
Boundary→CJK 的源码空格检查补齐与 Default 方向对称的
`\__xeCJK_skip_if_interword:N` 校验（候选须 finite、带 shrink、自然宽度
等于当前词间空格），并在顶层恢复链于空列表探测时使过期 pending 失效
（capture 活跃时不做此判断，保护 ulem 内部流）。实测本目录 MWE 输出
`FIRST=30.0pt SECOND=30.0pt DELTA=0.0pt`；与词间空格同构的显式 glue
仍处于文档化歧义窗口（workaround 仍为前置 `\kern0pt`）。回归：
`xeCJK/testfiles/boundary-crossbox01.lvt`（7 断言：MWE、kern
workaround、同盒分组、跨盒同构 glue、歧义窗口、源码空格两方向）。
