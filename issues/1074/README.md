# Issue #1074 资产

`l3backend` 已并入 `l3kernel`，`scripts/sync-l3backend.sh` 及其调用已撤除。

## 撤除依据

`verify-removal.sh` 是可复现的验证脚本，从 tlnet 下载实际的 TDS 包并测两种情形；
`verify-removal.out` 是运行结果。

| 情形 | `kpsewhich l3backend-pdftex.def` 命中 | `expl3` | backend |
| --- | --- | --- | --- |
| 只有新版 `l3kernel` | `tex/latex/l3kernel/` 那份 | 2026-08-10 | 2026-08-10 |
| 新旧两包共存（过渡态） | 仍是 `l3kernel` 那份 | 2026-08-10 | 2026-08-10 |

两种情形下两个日期都一致，所以原脚本恒走空转分支并打出撤除 `::notice::`。

## 判据是「实际解析到哪份」，不是「旧包在不在」

这一点反直觉，值得单独记。撤除时 tlnet 上的旧 `l3backend` 包**还在**（revision 79958，
日期仍是 2026-07-20），`l3kernel` 是 revision 80015、日期 2026-08-10 且已提供 `.def`。

于是同名 `.def` 同时存在于两个包、日期不同：

```
<tree>/tex/latex/l3kernel/l3backend-pdftex.def     2026-08-10   <- kpse 命中这个
<tree>/tex/latex/l3backend/l3backend-pdftex.def    2026-07-20
```

按「包没了才能撤」这个直觉判据会得出「还不能撤」的错误结论。

## 另一个容易搞错的地方

CTAN 的 `l3kernel.zip`（14 MB）里**只有 `.dtx` 与 `l3backend.ins`，没有解包好的 `.def`**：

```
l3kernel/l3backend-basics.dtx
l3kernel/l3backend-color.dtx
...
l3kernel/l3backend.ins
```

`l3backend-*.def` 是 **TeX Live 打包时由 `.ins` 生成**的。所以「`.def` 文件名会不会消失、
还能不能被 `kpsewhich` 找到」取决于 TL 怎么打包，不取决于 CTAN——判断这类问题要下载并解开
tlnet 的 TDS 包（`systems/texlive/tlnet/archive/<pkg>.tar.xz`），不能只看 CTAN 公告或 zip。

## 一个预判到但没撞上的窗口

CTAN 已移除 `l3backend`（`l3backend.zip` 返回 **HTTP 404**）。若 tlnet 恰好处于
「`l3kernel` 已更新而 `l3backend` 仍旧」且 kpse 命中旧那份的组合，原脚本会判定日期不一致、
进入下载分支、三个 mirror 必然全部 404，然后报出：

```
::error::所有 mirror 均无法下载 l3backend; 这是网络/镜像问题, 重跑本 job 即可
```

这会让人反复重跑徒劳的 job，而真相是「包已经不存在了，该删脚本」。实际因为 kpse 优先命中
`l3kernel` 那份而没有撞上。

但这个形状对任何「从上游下载单个资源」的步骤都成立：**404／410 意味着改代码，超时／5xx 才
意味着重跑**。仓库里 `HanaMinB`、`Unihan` 等下载同样没有这个区分，已记进
`llmdoc/reference/build-and-test.md`。
