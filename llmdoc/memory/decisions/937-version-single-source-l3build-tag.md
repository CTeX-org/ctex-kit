# 决策：#937 build.lua 单一事实源 + l3build tag 回写（版本 stamp 双闸 CI + 手册页脚 hash 固化）

## 决策

对完成 DocStrip & L3 重构的包（zhlineskip PR #892 首创，ctex PR #937 移植），
版本管理与手册元信息回写统一收敛为「**打包时固化，而非编译时现场获取**」：

1. **`build.lua` 顶部 `version` 字段是唯一手改的版本事实源**
2. dtx 源文件的版本行统一为 `\GetIdInfo $Id: <file> <ver> <date> ...$`
   stamp，由本地手跑 `l3build tag` 通过包级重写的 `update_tag` 回写
3. **双闸 CI** 保证 stamp 不 stale：
   - `check-tag.yml`（PR 门禁）：PR 上跑 `l3build tag` + `git diff
     --exit-code`，diff 非零即 fail
   - `release.yml` 三方校验：strip_rc(git tag) == build.lua version ==
     dtx stamp，不一致拒绝发版
4. **手册首页页脚 `*ctex-kit rev. <shorthash>.`** 同样由 `update_tag` 在
   处理主 dtx 时固化写入 `ctex.dtx` 里的 `\GetFileId[<hash>]{ctex.sty}`，
   取代了曾短暂采用、后被否决的编译时 `\sys_get_shell` 现场取 git hash
   方案（详见下「手册页脚 shorthash」与「备选与排除」）

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

## 手册页脚 shorthash：打包时固化，不做运行时现取

### 背景问题

`ctex.dtx` 拆分移除了原来生成 `ctex.id` 的 `gitverfiles` 设施。手册首页
页脚 `*ctex-kit rev. <shorthash>.` 依赖这个 hash，`\GetFileInfo` 拿不到
`ctex.id` → fallback 显示成 `-1`（`*ctex-kit rev. -1.`）。

### 曾走过的弯路：编译时 `\sys_get_shell` 现场取 hash（已否决）

拆分早期的修复（合并前 commit d628e729 / ee3a133c）新增
`\GetFileHash`：用 `\sys_get_shell:nnN { git log -1 --format=%h -- '*.dtx' }`
在**手册编译时现场跑 git** 取 hash，并给 `ctex/build.lua` 加了
`typesetopts = "--shell-escape"`。这把 **git 仓库 + `--shell-escape`
变成了"文档可编译性"的运行时硬依赖**。

四环境实测（PR review 中确认为 regression）：

| 场景 | `--shell-escape` | git 仓库 | 结果 |
|---|:---:|:---:|---|
| CI / `l3build doc`（发布产物） | ✓ | ✓ | 页脚正确，exit 0 |
| 维护者手动编译，未开 shell-escape | ✗ | ✓ | Emergency stop |
| CTAN 用户开了 shell-escape，非 git 目录 | ✓ | ✗ | 页脚空 hash |
| **CTAN 用户典型场景**（解压 zip，默认 restricted，无 git） | ✗ | ✗ | **Emergency stop** |

根因：`\sys_get_shell` 的管道命令被 web2c restricted 模式白名单拒绝
（`runpopen command not allowed: git`），TeX 转而把 `"|git log..."`
整串当文件名去找，找不到 —— nonstopmode 下直接 Emergency stop。
**原症状只是页脚显示 `-1` 但手册能编出来，这个方案反而让 CTAN 典型场景
编译中断，是更严重的 regression。**

`check-doc.yml` 恰好同时满足"带 `--shell-escape`" + "跑在 git 仓库里"
两个条件，CI 因此绿灯，掩盖了这个 regression——教训见下。

### 最终方案：打包时固化（现已在 master，commit 8c6212ee）

- `\sys_get_shell` / `--shell-escape` 依赖**完全移除**。
- `support/ctxdoc.cls`：`\GetFileId` 签名从 `{ m }` 改为 `{ O{} m }`，
  可选参数接收固化的 hash：`\tl_set:Nn \filehash {#1}` 再
  `\GetFileInfo {#2}`（date/version 仍走原 `\GetFileInfo` 路径不变）。
- `ctex/ctex.dtx` 手册导言区写死 `\GetFileId[097bc3d5]{ctex.sty}`，
  hash 直接固化在 dtx 源码里，不在编译时求值。
- `ctex/build.lua` 的 `update_tag`：只在处理 module 主 dtx（`ctex.dtx`）
  时，跑 `git log -1 --format='%h' *.dtx` 取最新 hash，用正则
  `%% \GetFileId%[%w+%]` 回写进 `\GetFileId[<hash>]` —— hash 在
  **维护者本地 `l3build tag` 阶段固化**，不是手册编译时现取。
- 效果（合并后 worktree 验证）：CTAN 用户在非 git 目录、无
  `--shell-escape` 下重编 `.dtx`，exit 0，页脚正常显示固化 hash
  `097bc3d5`，`runpopen` / 找不到文件 0 处，运行时零外部依赖。

### 教训（长期价值）

手册页脚/版本这类"编译时元信息"应在**打包时固化进随包文件**，而非在
文档编译时通过 `\sys_get_shell` 现场获取——后者把 git + shell-escape
变成终端用户重编的硬依赖，且 CI 环境（恰好带 shell-escape + 跑在 git
仓库里）会掩盖该依赖导致的 regression，必须跳出 CI 绿灯去模拟真实
CTAN 解压场景才能发现。这与本决策 `update_tag` 版本 stamp"打包时回写"
是同一思路的延伸：**凡是需要 git 元数据的信息，一律在 `l3build tag`
阶段回写进源文件，不允许编译期现场查询 git**。

## 备选与排除

- **CI 自动跑 l3build tag + bot commit**：排除——bot commit 与"git tag 打
  在干净 HEAD"语义冲突，且掩盖作者遗漏而非暴露。
- **release.yml 校验挪到 check-tag.yml 一并做**：排除——PR 阶段没有 git
  tag 可比，第 2 类事故（打 tag 时敲错版本号）只能在 release 出口拦。
- **手册页脚 hash 编译时 `\sys_get_shell` 现场取**：排除——见上「手册页
  脚 shorthash」，把 git + `--shell-escape` 变成 CTAN 用户重编的运行时
  硬依赖，四环境实测在典型 CTAN 场景下导致 Emergency stop，比原症状
  `-1` 更差；改为 `l3build tag` 阶段固化写入。

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
