#!/usr/bin/env bash
# check-pr-ci.sh — block until the current branch's PR finishes CI, then report.
#
# Exit codes:
#   0  CI 全过 + push 后无新 review 活动 + 无未解决 thread (terminal)
#   1  CI 一项及以上失败
#   2  没找到 PR / gh 不可用 (pre-push 当非致命放行)
#   75 CI 过, 但有 push 后新 review 活动或未解决 thread (pre-push 接到后
#      exit 1, 迫使上层 agent 看 stderr 而非静默 0 通过)
set -uo pipefail

log() { echo "$@" >&2; }

if ! command -v gh >/dev/null 2>&1; then
  log "post-push: gh CLI not found — skipping CI check."
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  log "post-push: jq not found — cannot reliably parse CI checks. Failing safe."
  exit 1
fi

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

pr_number="$(gh pr view --json number --jq '.number' 2>/dev/null)"
if [ -z "$pr_number" ]; then
  log "post-push: no open PR for branch '$branch' yet — skipping CI check."
  log "post-push: (open a PR, then CI status will be watched on the next push)"
  exit 2
fi

log "post-push: watching CI for PR #${pr_number} (branch '$branch')..."

# 等到 gh 看到至少一条 check (新 push 的 workflow 可能还没注册)
poll_tries="${CHECK_PR_CI_POLL_TRIES:-24}"
poll_interval="${CHECK_PR_CI_POLL_INTERVAL:-5}"
for _ in $(seq 1 "$poll_tries"); do
  cnt="$(gh pr checks "$pr_number" --json state --jq 'length' 2>/dev/null)"
  if [ -n "$cnt" ] && [ "$cnt" -gt 0 ]; then
    break
  fi
  sleep "$poll_interval"
done

# 阻塞等待终止状态. --watch 自身忽略 cancel/fail 退码, 这里只是要它"等到全部停"
gh pr checks "$pr_number" --watch --fail-fast --interval 15 >/dev/null 2>&1 || true

checks_json="$(gh pr checks "$pr_number" --json name,state,bucket,link,startedAt 2>/dev/null)"
if [ -z "$checks_json" ]; then
  log "post-push: could not read CI checks for PR #${pr_number}."
  exit 2
fi

# 修假阳: concurrency cancel-in-progress 会把同名 workflow 的旧 run 标记为
# cancelled. gh pr checks 把所有 run 一股脑列出来, 直接看 .bucket=="fail" or
# "cancel" 会把这些"被取代的"旧 run 误报成失败 (PR #887/#888 已两次踩坑).
# 修法: 按 .name 分组只保留 startedAt 最新的一条; 之后再判 fail/cancel.
# (cancel 在 latest 仍出现极少, 几种正常路径: 1) 主分支合并并发触发 2) 用户手
# 动 cancel — 后者本就该是 fail, 前者是 bug, 不在这里兜底.)
latest_per_workflow="$(printf '%s' "$checks_json" \
  | jq -c '
      group_by(.name)
      | map(
          sort_by(.startedAt // "") | last
        )
    ' 2>/dev/null)"

if [ -z "$latest_per_workflow" ] || [ "$latest_per_workflow" = "null" ]; then
  log "post-push: could not deduplicate CI checks (jq failed)."
  exit 2
fi

# bucket=="fail" 视为失败; bucket=="cancel" 在 latest 中视为失败 (用户手动 cancel
# 或确实没跑完, 都应当不通过).
failures="$(printf '%s' "$latest_per_workflow" \
  | jq -r '.[] | select(.bucket=="fail" or .bucket=="cancel") | "\(.name)\t\(.link // "")"')"

review_decision="$(gh pr view "$pr_number" --json reviewDecision --jq '.reviewDecision' 2>/dev/null)"
[ -z "$review_decision" ] && review_decision="(no review yet)"

if [ -n "$failures" ]; then
  log ""
  log "════════════════════════════════════════════════════════════"
  log "  ✗ post-push: CI FAILED for PR #${pr_number}"
  log "  Failing checks (latest run per workflow, cancelled-by-concurrency excluded):"
  while IFS=$'\t' read -r name link; do
    [ -z "$name" ] && continue
    log "    • ${name}"
    [ -n "$link" ] && log "        ${link}"
  done <<< "$failures"
  log ""
  log "  → Investigate the failing jobs above."
  log "  → Also check the PR review status (currently: ${review_decision})."
  log "════════════════════════════════════════════════════════════"
  exit 1
fi

# CI 过. 看 push 后是否有新 review 活动或未解决 thread.
#
# 拿到 INNER push 头 commit 时间作为基线. (gh pr view 的 headRefOid commits)
head_sha="$(gh pr view "$pr_number" --json headRefOid --jq '.headRefOid' 2>/dev/null)"
head_committed_at=""
if [ -n "$head_sha" ]; then
  head_committed_at="$(git show -s --format=%cI "$head_sha" 2>/dev/null || true)"
fi

# 1) push 之后是否有新 review (state != PENDING && submittedAt > head_committed_at)
new_review_after_push=""
if [ -n "$head_committed_at" ]; then
  new_review_after_push="$(gh pr view "$pr_number" --json reviews \
    --jq --arg t "$head_committed_at" '
      .reviews[]?
      | select(.state != "PENDING")
      | select((.submittedAt // "") > $t)
      | "\(.author.login // "?")\t\(.state)\t\(.submittedAt)"
    ' 2>/dev/null || true)"
fi

# 2) 未解决的 review thread
# 一次 gh repo view 拿 owner+name, 喂给 GraphQL 而非两次子 shell.
repo_owner_name="$(gh repo view --json owner,name --jq '"\(.owner.login)\t\(.name)"' 2>/dev/null)"
repo_owner="${repo_owner_name%$'\t'*}"
repo_name="${repo_owner_name#*$'\t'}"
unresolved_threads="$(gh api graphql -f query='
  query($owner:String!, $repo:String!, $pr:Int!) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$pr) {
        reviewThreads(first:100) {
          nodes {
            isResolved
            comments(first:1) { nodes { author { login } body url } }
          }
        }
      }
    }
  }
' -F owner="$repo_owner" \
   -F repo="$repo_name" \
   -F pr="$pr_number" 2>/dev/null \
  | jq -r '
      .data.repository.pullRequest.reviewThreads.nodes[]?
      | select(.isResolved == false)
      | .comments.nodes[0]
      | "\(.author.login // "?")\t\(.body // "" | gsub("\n"; " ") | .[0:80])\t\(.url // "")"
    ' 2>/dev/null || true)"

# 状态报告: 区分三档
if [ -n "$new_review_after_push" ] || [ -n "$unresolved_threads" ]; then
  log ""
  log "════════════════════════════════════════════════════════════"
  log "  ⚠ post-push: CI passed for PR #${pr_number}, but review activity pending"
  if [ -n "$new_review_after_push" ]; then
    log ""
    log "  New review(s) submitted after this push:"
    while IFS=$'\t' read -r who state when; do
      [ -z "$who" ] && continue
      log "    • ${who}  [${state}]  @${when}"
    done <<< "$new_review_after_push"
  fi
  if [ -n "$unresolved_threads" ]; then
    log ""
    log "  Unresolved review thread(s):"
    while IFS=$'\t' read -r who body url; do
      [ -z "$who" ] && continue
      log "    • ${who}: ${body}"
      [ -n "$url" ] && log "        ${url}"
    done <<< "$unresolved_threads"
  fi
  log ""
  log "  → Review the comments above and address them in a follow-up commit."
  log "  → Then re-push; this hook will re-watch CI and re-check review activity."
  log "════════════════════════════════════════════════════════════"
  exit 75
fi

log ""
log "════════════════════════════════════════════════════════════"
log "  ✓ post-push: all CI checks passed for PR #${pr_number}"
log "  → No new review activity or unresolved threads since this push."
log "  → PR review status: ${review_decision}."
if [ "$review_decision" != "APPROVED" ]; then
  log "  → PR is not yet APPROVED — request review before merging."
fi
log "════════════════════════════════════════════════════════════"
exit 0
