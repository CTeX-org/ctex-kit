---
name: 874-876-agentic-fork-shielding-cron
description: agentic 定时工作流的双重约束——“仅在主仓库运行”与“放大调度间隔”——背后的原因、修复模式与可复用规则
metadata:
  type: feedback
---

# 反思: #874 / #876 agentic 定时任务的来源与频率约束

## 起因

仓库的 `.github/workflows/agentic-*.yml` 系列工作流包含 `pull_request_target`
触发的 PR 审查、定时触发的 llmdoc 更新与定时触发的 patrol 巡查。
两个被本轮处理的相关问题：

1. **#875 → PR #876**：定时 `schedule` 触发会在 fork 仓库里**也**被 GitHub Actions 启动。
   fork 通常没有配置 `ANTHROPIC_API_KEY` 等密钥，定时 job 启动后立刻进入鉴权失败、
   或更糟：在被 fork 的镜像上发出对真实仓库的 API 调用，污染 issue 时间线。
2. **#874**：patrol 巡查最初配置为每 4 小时一次。这是 Claude Code 自动化早期“尽可能
   及时”的默认值。运行一段时间后发现：
   - patrol 任务大部分时段只是“扫描，无事可做”；
   - 高频运行带来无意义的 token 消耗，对一个志愿者维护的仓库不可持续；
   - 在偶发 outage 或瞬时网络错误时，反而放大失败噪声。

## 修复模式

### 仓库归属门控（#876）

在所有 `agentic-*.yml` 的定时与手动触发 job 顶部加入：

```yaml
if: ${{ github.repository == 'CTeX-org/ctex-kit' }}
```

这条 `if` 必须挂在 **job 级**而不是某一 step 上：fork 启动 workflow runner
本身就消耗 fork 主用的 Actions 配额，挡在 step 上时 runner 已经被分配。
挂在 job 级时，GitHub Actions 在调度阶段直接判定为跳过，不分配 runner。

同一模式也适用于 `pull_request_target` 类工作流，但那种触发由 PR 行为驱动，
fork 默认就拿不到密钥；本次主要约束的是**纯 `schedule` 触发**与
**`workflow_dispatch` 触发**这两类不会被 PR 来源天然过滤的入口。

### 频率回退（#874）

`agentic-patrol.yml` 的 `schedule` 表达式从“每 4 小时一次”调整为
“每天一次，触发时刻 UTC 0:00 = 北京时间 08:00”：

```yaml
schedule:
  - cron: '0 0 * * *'
```

选择 08:00 北京时间的考量是：维护者人活动峰值集中在白天，需要尽快发现并人工
跟进 patrol 报告时，工作时段开始前刚完成的扫描结果最有用；同时也避开了
高峰 GitHub Actions 队列时段（通常工作日 UTC 14:00–18:00）。

## 为什么这两条要一起记

**Why:** 这两个修复看上去独立（“fork 别跑” vs “跑得别那么频繁”），
但都属于“agentic 自动化的运行边界条件”，未来再加 agentic 工作流时应
**同时**考虑这两件事：来源是否需要门控、频率是否需要回退。

**How to apply:**
- 任何新增 `agentic-*.yml`：
  1. job 级加 `if: ${{ github.repository == 'CTeX-org/ctex-kit' }}`，除非该 job
     的设计就是为了被 fork 复用。
  2. `schedule` 触发频率默认走“每天一次北京时间白天”，不要默认 4 小时或 1 小时。
     更高频率需要明确的工程动机（如 release notes 实时拼装等不能等一天的场景）。
- 修改已有 agentic 工作流时，**不要顺手把这两条去掉**：
  - fork 门控如果出现在 PR diff 里被建议移除，先确认是否真的要让 fork 跑。
  - 频率调高时应该附带说明为什么不能再等一天。

## 教训

1. **GitHub Actions 在 fork 上仍会调度 `schedule` workflow**。这是
   GitHub Actions 的设计行为，文档上有但实际维护者经常忽略。一旦该
   workflow 调用了外部 API，fork 的运行可能产生**真实**的 issue/comment
   写入（如果 fork 里 secret 被 fork 拥有者补齐）。
2. **agentic 任务的频率不是“越高越好”**。高频运行会放大瞬时错误、消耗
   token 配额、淹没真正有信号的 patrol 输出。每天一次足以覆盖
   ctex-kit 这种以周为节奏的维护节拍。
3. **`if` 的位置很重要**：job 级 `if` 才能避免 runner 被分配，step 级
   `if` 只是阻止该 step 执行。在 fork 上分配 runner 也算 fork 主消耗。

## 相关引用

- 触发约束实现：`.github/workflows/agentic-patrol.yml`、
  `.github/workflows/agentic-llmdoc-updater.yml`、
  `.github/workflows/agentic-pr-review.yml`（PR #876 的相关 hunk）。
- 频率配置：`.github/workflows/agentic-patrol.yml` 的 `schedule` 段（PR #874）。
- 已有 agentic 工作流定位：参见 [[reference/build-and-test]] 中
  “CI/CD 配置”小节列出的三条 agentic 工作流。
