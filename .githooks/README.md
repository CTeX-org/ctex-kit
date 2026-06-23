# .githooks

仓库 Git hooks.

## 安装(一次性)

```bash
make hooks    # 等同 git config core.hooksPath .githooks
```

## 各 hook 职责

| hook | 时机 | 做什么 | 量级 |
|---|---|---|---|
| `commit-msg` | 提交时 | 强制 `type(scope): subject` 格式 | 毫秒级 |
| `pre-push` | 推送前 + 推送后 | ① 可选 l3build sanity(`LATEX_PREPUSH_BUILD=1` 启用);② self-wrapping inner push;③ 阻塞等 CI + 抓 PR 新评论活动 | 推送时秒级 + CI 等待 |

- 所有 hook 在 CI 环境(`$CI`/`$GITHUB_ACTIONS`)自动短路。
- 完整测试(`l3build check`)**不在 hook 里跑** —— LaTeX 单包全量 check 动辄 20min,那是 CI 的事。
- 紧急跳过:`git commit --no-verify` / `git push --no-verify`(仅紧急情况)。

## `commit-msg` 允许的 type

`feat fix doc docs test chore perf refactor ci bench build revert`

scope 可选,字符集 `[A-Za-z0-9/_., -]+`。允许大小写、逗号/空格,以兼容仓库已有的 `xeCJK`、`CJKpunct`、`xCJK2uni` 大写包名,以及 `chore(ctex, xeCJK, zhlineskip): ...` 多包风格。

放行的自动消息:`Merge ...` / `Revert ...` / `fixup! ...` / `squash! ...`。

例子:

- ✓ `fix(xeCJK): 修复 \lstinline 中 catcode 6 字符原字符码丢失 (#879)`
- ✓ `docs(llmdoc): 同步架构图至最新实现`
- ✓ `chore(ctex, xeCJK, zhlineskip): 声明依赖 LaTeX2e 2026-06-01`
- ✗ `update README` (无 type)
- ✗ `WIP` (无 `: `)

## `pre-push` 可选本地 sanity

默认跳过本地构建,保持推送极速。需要做轻量验证时:

```bash
LATEX_PREPUSH_BUILD=1 git push origin <branch>
```

会对每个含 `build.lua` 的包跑 `l3build unpack -q` —— 仅验证 `.dtx` 能解包,不编译 PDF、不跑 `check`。

## `pre-push` self-wrapper 详解

git 无原生 post-push hook。`pre-push` 模拟办法:

1. **OUTER push 进入 hook**:跑 sanity → sanity 过后从 stdin 读 refspec → 用 `GIT_POSTPUSH=1` 标记跑一次 **INNER push**(逐字镜像 refspec,force/tag/delete/multi-ref 都正确)
2. **INNER push 重入 hook**:看到 `GIT_POSTPUSH` 标记从顶部直接 `exit 0` 放行
3. **控制流回 OUTER**:调用 `check-pr-ci.sh` 阻塞等 CI 结果 + 抓 PR 评论活动
4. **OUTER push 紧接着会失败**(原子 ref 保护 / 连接被掐),这是**预期且无害**的 —— push 已经经 INNER 成功。真正的 verdict 看 `pre-push` 的 stderr ✓/✗ 报告

INNER push 自动行为:

- **`--force-with-lease=<ref>:<remote_sha>`**:非快进时自动加,精确镜像 git 在 stdin 看到的远端 sha,避免裸 lease 依赖 stale 跟踪引用造成误判。
- **`--set-upstream`**:当前 HEAD 分支被推送且**没有 upstream** 时自动加。等同 outer `git push -u` 的预期效果(git 不把 outer 命令行参数透传给 hook,需 hook 自行接力)。

## `check-pr-ci.sh` exit codes

| rc | 含义 | `pre-push` 行为 |
|---|---|---|
| `0`  | CI 全过 + push 后无新 review 活动 + 无未解决 thread(terminal) | 放行 |
| `1`  | CI 一项及以上失败 | exit 1 |
| `2`  | 没找到 PR / `gh` 不可用 | 非致命,放行 |
| `75` | CI 过,但有 push 后新 review 活动或未解决 thread | exit 1(迫使上层 agent 看 stderr) |

**为什么需要 75**:返回 0 会让 OUTER push 退 0,只看 exit status 的工具(agent loop / CI driver)就会静默漏掉「address review feedback」那段 stderr 指令。

**并发取消假阳处理**:`gh pr checks` 会把同名 workflow 的旧 run(被 `cancel-in-progress` 取代的)列为 `cancelled`。脚本按 `.name` 分组只保留 `startedAt` 最新的一条再判 fail/cancel,避免误报。
