# 决策：#937 版本管理收敛为 build.lua 单一事实源 + l3build tag 回写 + 双闸 CI

## 决策

对完成 DocStrip & L3 重构的包（zhlineskip PR #892 首创，ctex PR #937 移植），
版本管理统一为：

1. **`build.lua` 顶部 `version` 字段是唯一手改的版本事实源**
2. dtx 源文件的版本行统一为 `\GetIdInfo $Id: <file> <ver> <date> ...$`
   stamp，由本地手跑 `l3build tag` 通过包级重写的 `update_tag` 回写
3. **双闸 CI** 保证 stamp 不 stale：
   - `check-tag.yml`（PR 门禁）：PR 上跑 `l3build tag` + `git diff
     --exit-code`，diff 非零即 fail
   - `release.yml` 三方校验：strip_rc(git tag) == build.lua version ==
     dtx stamp，不一致拒绝发版

## 关键设计点

### update_tag 必须幂等

"回写 git 元数据到源文件"有自指问题：回写产生新 commit → 新 sha → 下次
tag 又想回写。收敛条件：**stamp 版本号 == version 时原样保留**，只有
bump 后未 stamp 才真回写。没有这个守卫，check-tag 的 diff 检查永远 fire。

### RC 版本只存在于 git tag

`-rcN` / `-pre` / `-alpha` / `-beta` 后缀只出现在 git tag；build.lua 与
stamp 均写 base version。校验与 release-notes 提取用同款 sed 剥后缀。
推论：发 rc 前 build.lua 必须已 bump 到目标版本并完成 stamp。

### 发版操作顺序（ctex 拆分后 SOP）

```
1. ctex/build.lua:2       version = "X.Y.Z"           （手改，唯一）
2. 相应 ctex-*.dtx        补 \changes{vX.Y.Z}{...}     （随功能 PR）
3. cd ctex && l3build tag 回写 5 个 dtx 的 $Id:$ 行    （自动）
4. commit + PR （check-tag.yml 验 stamp 同步）
5. merge 后 make tag ctex-vX.Y.Z[-rcN] && git push origin <tag>
   （release.yml 三方校验通过才发版）
```

## 备选与排除

- **CI 自动跑 l3build tag + bot commit**：排除——bot commit 与"git tag 打
  在干净 HEAD"语义冲突，且掩盖作者遗漏而非暴露。
- **release.yml 校验挪到 check-tag.yml 一并做**：排除——PR 阶段没有 git
  tag 可比，第 2 类事故（打 tag 时敲错版本号）只能在 release 出口拦。

## 适用范围

当前 zhlineskip / ctex。其余包（xeCJK 等）沿旧机制（`support/
build-config.lua` 的默认 `update_tag` 只改 `{\ExplFileDate}{...}`），
release 校验对它们打 notice 跳过。未来迁移时：包级 build.lua 重写
update_tag（带幂等守卫）→ check-tag.yml 加 caller job → release.yml
校验 case 加分支。

## 相关

- 反思：[[937-ctex-split-version-stamp-ci]]
- Stable：`llmdoc/reference/build-and-test.md` 版本管理章节
- PR：#937 / #892
