# Issue #1080 资产

master 定时回归从 2026-08-17 起失败，四个用例红。成因是**两个互不相干的上游改动同时撞上**。
已通过刷新 12 份基线解决。

## 为什么这里没有「修复前后」对比图

两个改动的排版结果都**没有变化**，所以看不出差别——贴一张对比图只会误导。证据用节点树与
文件清单的差异呈现，见下。

`issue1080-toc-normal.png` 是 `tocloft` v3.0a 下目录的实际排版（`issue1080-mwe.tex` 编译所
得），它要证明的正是「新增的 kern 净宽为零，版面不变」。

## 成因一：`tocloft` 主版本跳变

| | 版本 | 日期 |
| --- | --- | --- |
| 之前 | v2.3i | 2017/08/31 |
| 现在 | **v3.0a** | **2026-08-12** |

九年未动的包跳了主版本。影响 `github472-03`／`github472-04`——仓库里唯一两个
`\usepackage{tocloft}` 的用例，四个引擎全红。

基线差异的全部内容就是每个页码后多出一对 kern：

```diff
 ....\kern -0.0002
 ....\kern 0.0002
+....\kern -1.0
+....\kern 1.0
 ....\penalty 10000
```

`-1.0` 与 `1.0` 相邻且立即抵消，**净宽度为零**。八份 diff 各 4 行新增、0 行删除，没有任何
非 kern 的新增行（LuaTeX 写作 `\kern-1.0`，无空格，形态相同）。

## 成因二：`fontspec` 不再加载 `xparse`

影响 `files01`／`files02`——它们用 `\listfiles` 固定「加载了哪些文件」这份清单：

```diff
-xparse.sty
```

四份 diff 各只有这一行删除。pdfTeX 与 upTeX 不经 `fontspec`，因此不受影响——这正好解释了
「只有 XeTeX 与 LuaTeX 红」这个分布。

## 引擎分布是「成因不止一个」的线索

| 用例 | pdfTeX | XeTeX | LuaTeX | upTeX |
| --- | --- | --- | --- | --- |
| `github472-03/04` | ✗ | ✗ | ✗ | ✗ |
| `files01/02` | | ✗ | ✗ | |

两种分布不同，说明是两条独立路径。最初我发现 `tocloft` 主版本跳变后，一度想用它解释全部四个
用例，还去查了「`tocloft` 是否间接影响 fontspec 加载链」——方向错了。**同一个成因通常产生
同一种分布；出现两种分布就该假设有两个成因。**

## 刷基线前做的分类检查

`llmdoc` 里既有的判据是「会自愈的不刷、上游不会回退的必须刷」（#1048/#1050），本次两者都属
后者。但那只回答了「要不要刷」，没回答「刷了会不会把上游的新缺陷冻结进基线」——#1037 那次
正是把残留缺陷冻结成了预期基线。

所以额外逐份核对了 diff 的**内容形态**：

- `tocloft` 侧只有净宽为零的 kern 对，无节点丢失、无数值变化；
- `fontspec` 侧只有文件名行删除，且删掉的是上游包。

两者都没有本包补丁失效的迹象，才 `l3build save`。刷完的净变化是 32 行新增（全是 kern
±1.0）+ 4 行删除（全是 `xparse.sty`），与逐份核对的 diff 完全对应、零意外。

## 顺带修掉的诊断缺口

排查时发现失败的 job **拿不到任何 diff**：

```
##[warning]No files were found with the provided path: ctex/build/**/*.diff.
$ gh run download ...
no valid artifacts found to download
```

真正原因不是「l3build 写到 `build/check/`」（我最初在 issue 里的说法，只是表面），而是
`scripts/check-parallel.sh` 给每个引擎在 `tmp/parallel-check/<engine>/<pkg>/` 下各开一份完整
工作区，diff 落在那里面，而上传路径只有 `<pkg>/build/**/*.diff`。

已补上并行路径，并新增 `Show test diffs` 步骤把 diff 正文直接打进日志（每份截断 200 行并提示
总行数）——只有 artifact 不够用，路径一旦不匹配就完全没有诊断信息。
