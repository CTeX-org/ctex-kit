# Issue #995 资产

`\settowidth{...}{甲\colorbox{yellow}{乙}}` 的离线测量污染 xeCJK 全局边界状态,
使随后构造的相同 `\hbox{丙\special{audit} 丁}` 宽度改变 (23.33pt → 20.0pt)。

- `issue995-mwe.tex` — 最小复现 (基于 issue 原 MWE, 补 Fandol 字体声明)。
- `issue995-before-after.png` — 左: xeCJK v3.10.3 复现 (DELTA=-3.33pt);
  右: PR #999 capture/register 框架下 DELTA=0pt (colorbox 注册为
  wrapped-box, 颜色 push/pop 注册为 transparent, 状态不再跨盒泄漏)。

回归测试: `xeCJK/testfiles/colorbox-measure01.lvt` (PR #999)。
