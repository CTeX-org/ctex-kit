# Issue #1077 资产

`\zhnumsetup{T1=...}` 改掉的是 `\zhganzhi` 而不是 `\zhtiangan`。**已在 v3.1 修复**
（该版本尚未正式发布，故并入 3.1 而非新起版本）。

![修复前后对比](https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/1077/issue1077-before-after.png)

## 成因：一处复制粘贴笔误

`zhnumber/zhnumber.dtx` 里三组键的目标变量：

```tex
T#1  .tl_set:N = \exp_not:c { l_@@_ganzhi_ #1 _tl }   % 错，应为 tiangan
D#1  .tl_set:N = \exp_not:c { l_@@_dizhi_  #1 _tl }   % 对
GZ#1 .tl_set:N = \exp_not:c { l_@@_ganzhi_ #1 _tl }   % 对
```

`T#1` 与 `GZ#1` 撞在同一个变量上。

**这处笔误单看 `Tn` 那两行是发现不了的**：`\int_step_inline:nn { 10 }` 的步数 10 正好是天干
的个数，`.groups:n` 里的 `tiandi` 也对，只有变量名错。必须把三组键并排比对才看得出来。

## 实测读数

| | `\zhtiangan{1}` | `\zhdizhi{1}` | `\zhganzhi{1}` |
| --- | --- | --- | --- |
| 默认 | 甲 | 子 | 甲子 |
| 设 `T1`／`D1` 后（修复前） | **甲** | 我的子 | **我的甲** |
| 设 `T1`／`D1` 后（修复后） | 我的甲 | 我的子 | 我的甲我的子 |

修复前有两处错：`\zhtiangan` 没变（`T1` 没生效），`\zhganzhi` 被整个替换成「我的甲」而不是
由天干地支组合。

## 测试

新增 `zhnumber/testfiles/tiandi01.lvt`，7 个 TEST。此前 `testfiles/` **完全没有覆盖**
`\zhtiangan`／`\zhdizhi`／`\zhganzhi`，也没覆盖 `Tn`／`Dn`／`GZn`——这是笔误能长期潜伏的
直接原因。

覆盖：默认值、`Tn` 只影响天干并连带影响组合出的干支、`Dn` 侧对照、`Tn`+`Dn` 组合（报告者的
原始用例）、`GZn` 独立于 `Tn`／`Dn`、显式 `GZn` 优先于 `T1D1` 组合、设置不泄漏出分组。

判别力已实测：把绑定改回 `ganzhi`，`custom-T1-tiangan` 由「我的甲」变回「甲」、
`custom-T1-ganzhi` 由「我的甲子」变成「我的甲」，测试变红。

## 一个与实现无关的细节

pdfTeX 需要单独一份基线（`tiandi01.pdftex.tlg`）：它是 8-bit 引擎，中文在日志里按字节转义成
`^^e7^^94^^b2` 这类形式，而 xetex／luatex／uptex 直接记中文字符。

对照关系是每三个 `^^xx` 一个汉字（UTF-8）：`^^e7^^94^^b2` = 甲、`^^e5^^ad^^90` = 子、
`^^e6^^88^^91^^e7^^9a^^84` = 我的。**改动该用例后若只有 pdftex 报红、其余三引擎通过，先怀疑
是不是漏刷了那份基线。**
