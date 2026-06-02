#!/bin/bash
# check-pr-ci.sh — block until the current branch's PR finishes CI, then report.
#
# Exit codes:
#   0  all CI checks passed
#   1  one or more CI checks failed
#   2  no PR found for the current branch, or gh/jq unavailable (non-fatal)
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

poll_tries="${CHECK_PR_CI_POLL_TRIES:-24}"
poll_interval="${CHECK_PR_CI_POLL_INTERVAL:-5}"
for _ in $(seq 1 "$poll_tries"); do
  cnt="$(gh pr checks "$pr_number" --json state --jq 'length' 2>/dev/null)"
  if [ -n "$cnt" ] && [ "$cnt" -gt 0 ]; then
    break
  fi
  sleep "$poll_interval"
done

gh pr checks "$pr_number" --watch --fail-fast --interval 15 >/dev/null 2>&1 || true

checks_json="$(gh pr checks "$pr_number" --json name,state,bucket,link 2>/dev/null)"
if [ -z "$checks_json" ]; then
  log "post-push: could not read CI checks for PR #${pr_number}."
  exit 2
fi

failures="$(printf '%s' "$checks_json" \
  | jq -r '.[] | select(.bucket=="fail" or .bucket=="cancel") | "\(.name)\t\(.link // "")"')"

review_decision="$(gh pr view "$pr_number" --json reviewDecision --jq '.reviewDecision' 2>/dev/null)"
[ -z "$review_decision" ] && review_decision="(no review yet)"

if [ -n "$failures" ]; then
  log ""
  log "════════════════════════════════════════════════════════════"
  log "  ✗ post-push: CI FAILED for PR #${pr_number}"
  log "  Failing checks:"
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

log ""
log "════════════════════════════════════════════════════════════"
log "  ✓ post-push: all CI checks passed for PR #${pr_number}"
log "  → Now check the PR review status (currently: ${review_decision})."
if [ "$review_decision" != "APPROVED" ]; then
  log "  → PR is not yet APPROVED — review before merging."
fi
log "════════════════════════════════════════════════════════════"
exit 0
