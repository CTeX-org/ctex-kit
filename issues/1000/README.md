# Issue #1000 资产

`siunitx` 的 `\unit`(math 模式排版)遮蔽左侧 CJK marker 并吞掉源码空格,
CJK 上下文四种源码空格组合(00/10/01/11)相对直接输入 oracle 均差一个
ecglue(-3.33pt);v3.10.3 与 #999 合并后的 master `cb6b2f73` 行为一致
(未注册命令,不被 capture/register 框架自动覆盖)。

- `issue1000-mwe.tex` — 最小复现(issue 原 MWE 加 oracle 行)。
- `issue1000-before-after.png` — 左: master 复现;右: 同一 master 仅加
  一行 `\__xeCJK_boundary_register_stream:nn { unit } { default }`,
  四种组合全部与 oracle 一致。

验证结论: 注册 `unit`/`qty`/`num` 为固定 Default 首尾的 stream capture
后,00/10/01/11 全部归零;v2 旧名 `\si`/`\SI` 是独立顶层命令,需单独
注册同样生效。`\ang` 由于 `30°` 的度符号语义,需要另行确定 oracle,
未包含在本验证内。

## 修复分支验证（2026-07-20）

修复分支 `fix-996-998-1000-boundary-capture`（commit `c8c803bf` 起）已按
上述验证落地 `siunitx` package hook（`unit`/`qty`/`num` + 存在性守卫的
`si`/`SI`）。

- `issue1000-matrix.tex` — 扩展矩阵：五个命令 × 中·数·中 / 西·数·西 ×
  00/10/01/11 + 可选参数形式。修复分支上 36/36 全 PASS。回归：
  `xeCJK/testfiles/siunitx-ecglue01.lvt`。
