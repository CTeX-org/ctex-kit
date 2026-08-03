# #1041 版本门禁实测

基线取本 PR 的父提交 `4635be92`（即 master）。

## 事故复现与拦截

把 `xeCJK.dtx` 的 `{\ExplFileDate}` 改回 `3.10.4`（即 v3.10.5-rc2 当时的状态）后：

| 闸门 | 基线 | 本 PR |
|---|---|---|
| PR 门禁（`check-tag.yml`）| 不触发（xeCJK 不在 paths 白名单）| `l3build tag` 回写 → `git diff` 非零 → **拒绝** |
| release 门禁（`release.yml`）| 走 `*)` 打 notice 跳过 | `✗ tag=3.10.5 但 stamp=3.10.4` → **拒绝** |

## release 闸变异矩阵

| 场景 | 结果 |
|---|---|
| 三方一致（3.10.5）| 通过 |
| rc 后缀（3.10.5-rc3）| 通过（后缀已剥离）|
| `v` 前缀（version = "v3.10.5"）| 通过（与写入侧一致地剥离）|
| 打错 tag（3.10.6）| 拒绝 |
| 复现 rc2 事故 | 拒绝 |
| 干净树 | no-op，不误报 |

## 版本号形态兼容性

写入侧（`update_tag` 的 `%b{}`）对内容零约束，因此校验侧与读取侧都必须同等宽松：

| 形态 | release 闸提取 | `read_dtx_version` |
|---|---|---|
| `3.10.5` | `3.10.5` | `3.10.5` |
| `3.11` | `3.11` | `3.11` |
| `3.11a` | `3.11a` | `3.11a` |
| `0.0-beta` | `0.0-beta` | `0.0-beta` |
| `1.0g` | `1.0g` | `1.0g` |

占位宏必须**不**被匹配（ctex 五个拆分 dtx 的版本行是 `{\ExplFileDate}{\ExplFileVersion}{...}`，真实版本在 `$Id:$` 行）：

| 文件 | `read_dtx_version` |
|---|---|
| `ctex/ctex.dtx` | `2.6.4` |
| `ctex/ctex-kernel.dtx` | `2.6.4` |
| `ctex/ctex-engine.dtx` | `2.6.4` |
| `xeCJK/xeCJK.dtx` | `3.10.5` |
| `jiazhu/jiazhu.dtx` | `0.0-beta` |

## 九个包无副作用

共用 `support/build-config.lua` 的 update_tag 共七个包，另有 ctex / zhlineskip 各自覆写。逐个跑 `l3build tag`：

```
xeCJK        报错=0  dtx=no-op
CJKpunct     报错=0  dtx=no-op
jiazhu       报错=0  dtx=no-op
xCJK2uni     报错=0  dtx=no-op
xpinyin      报错=0  dtx=no-op
zhmetrics    报错=0  dtx=no-op
zhnumber     报错=0  dtx=no-op
ctex         报错=0  dtx=no-op
zhlineskip   报错=0  dtx=no-op
```

基线上这六个未设 `version` 的包裸跑 `l3build tag` 会抛 `attempt to concatenate a nil value`；现在给出可操作提示。

## 回归

xeCJK 117/117、ctex 四引擎 185/185、`l3build doc`（247 页）、CHANGELOG 门禁。
