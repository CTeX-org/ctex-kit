# issue #550 资产：xpinyin 查询汉字读音的四个命令

- `mwe-before.tex` / `mwe-before.png` — 改动前：xpinyin 只能把拼音排在汉字上方，
  拿不到「这个字读什么」这段文字；按拼音给索引分组只能手工写前缀。
- `mwe-after.tex` / `mwe-after.png` — 改动后：四个查询命令、多音字的星号形式、
  `tone` 的四种取值，以及用 `\xpinyinvalue` 自动生成索引排序键。
- `manual-query-p1.png` / `manual-query-p2.png` — 用户手册新增的第 4 节
  「查询汉字的读音」两页，含四个命令的说明、`tone` 与 `scheme` 选项对照表。

编 `mwe-after.tex` 需要本仓库的开发版 xpinyin：
`TEXINPUTS=<repo>/xpinyin/build/unpacked: xelatex mwe-after.tex`
