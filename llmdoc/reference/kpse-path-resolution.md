# kpse 的文件查找语义：`!!` 树与 ls-R

本文档回答一个问题：**把文件拷进某棵 texmf 树之后，kpse 到底能不能看见它。**
这与「怎么把文件装进 usertree」（见 `reference/build-and-test.md` 的「本地 TeX Live
usertree 同步」）是两件不同的事——文件落盘成功不等于查找得到。

## `TEXMFDBS` 与 `!!` 前缀

`texmf.cnf` 里两处配置决定查找方式：

```
TEXMFDBS = {!!$TEXMFLOCAL,!!$TEXMFSYSCONFIG,!!$TEXMFSYSVAR,!!$TEXMFDIST}
```

`TEXMFDBS` 列出哪些树维护 ls-R 文件名数据库。`TEXMF` 搜索列表里的 `$TEXMFHOME`
**没有** `!!` 前缀。

`!!` 的语义是**只查 ls-R，绝不扫磁盘**。实测：在带 `!!` 的树下放一个磁盘上确实存在的
文件，只要 ls-R 里没有它的条目，`kpsewhich` 就完全找不到。

对没有 `!!` 前缀的树，kpse 的行为要宽容得多：**ls-R 比目录的修改时间旧时，它会回退去
扫磁盘**。也就是说索引陈旧不会让文件消失，只是变慢。

`mktexlsr <树>` 在该树还没有 ls-R 时会**新建**一个（不是「只在已存在时刷新」）。

## 反直觉的后果：刷过索引的那一方反而找不到文件

把这三条事实合起来会得到一个违反直觉的结论：**对带 `!!` 的树，刷新 ls-R 会关掉扫盘
回退**。所以「刚刷过索引」的环境比「索引陈旧」的环境更容易找不到文件——只要新文件是在
刷索引之后拷进去的。

`_check-doc-package.yml:251` 与当时的 `scripts/sync-l3backend.sh:113-128`（该脚本已于 #1074 撤除，机制本身不变）的组合是一个实例：
zhmetrics 的 doc job 为了让 kpse 认识自己生成的 `zhmCJK.tfm`／`.map`，在 typeset 之前
跑了 `mktexlsr "$TEXMFHOME"`，把索引刷成最新；随后 `sync-l3backend.sh` 往同一棵树拷进
`l3backend-*.def`，这些文件不在刚刷的索引里，扫盘回退又已被关掉，于是解析回落到
`texmf-dist` 的旧版本。同批其他 doc job 没刷过索引，靠回退扫盘侥幸成功。**偏偏是刷过
索引的那个 job 失败。**

因此往 `TEXMFHOME` 拷文件之后要**无条件**跑 `mktexlsr`。只在「ls-R 已存在时才刷新」是
错的：`TEXMFHOME` 指向 `!!` 树时，没有 ls-R 等于什么都找不到。

## 本地与 CI 的结构性差异：这类问题本地默认复现不出来

`TEXMFHOME` 解析到哪棵树，两边不一样：

| 环境 | `TEXMFHOME` 解析结果 | 是否受 `!!` 约束 |
|------|----------------------|------------------|
| 本地典型安装 | `~/texmf` 一类独立目录，与 `TEXMFLOCAL`（如 `~/texlive/texmf-local`）不是同一个目录 | 否，走磁盘搜索 |
| CI（setup-texlive-action） | `.../setup-texlive-action/texmf-local` | 是 |

`TEXMFDBS` 只给 `TEXMFLOCAL` 等带 `!!`，不含 `TEXMFHOME`。本地 `TEXMFHOME` 因此是普通
树，无论刷不刷 ls-R 都能找到文件；CI 上 setup-texlive-action 把 `TEXMFHOME` 指到那棵带
`!!` 的 `texmf-local`，才会出问题。

**这意味着凡涉及 usertree 可见性的 CI 问题，本地默认不具备复现前提。** 这与
`reference/build-and-test.md` 的「本地测试失败的环境指纹检查表」不是同一类差异：那张表
回答「本地这次失败是不是环境造成的」，这里的问题是**本地不具备失败的前提**，做对照实验
时两种结论表现完全相同。要验证这类机制，应写最小独立复现直接测机制本身（在 `!!` 树上放
文件，刷新／不刷新各查一次 `kpsewhich`），而不是在本地跑真实脚本。

## 相关

- 具体调用：`.github/workflows/_check-doc-package.yml:251`（zhmetrics 的 tfm/map）。另一个实例是
  已于 #1074 撤除的 `scripts/sync-l3backend.sh`（往 `TEXMFHOME` 装 l3backend 后刷 ls-R 并核对解析
  结果）——**它只是历史实例，机制本身不随它消失**。
- 装进 `TEXMFHOME` 与装进 `localdir` 的取舍，见 `reference/build-and-test.md` 的
  「已撤除：`scripts/sync-l3backend.sh`」与「往 check 环境注入替代版本的上游宏包（localdir）」。
- 反思 [[../memory/reflections/1054-l3backend-defense-scope-and-kpse-lsr]] 记录了这条
  机制的排查过程，以及一次因本地不具备复现前提而撤回正确修复的经过。
