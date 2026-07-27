#!/usr/bin/env bash
set -euo pipefail

: "${BASE_SHA:?BASE_SHA is required}"
: "${HEAD_SHA:?HEAD_SHA is required}"
: "${RUNNER_TEMP:?RUNNER_TEMP is required}"

comments_pages="$RUNNER_TEMP/pr-comments-pages.json"
if [[ -n "${COMMENTS_PAGES_FILE:-}" ]]; then
  cp -- "$COMMENTS_PAGES_FILE" "$comments_pages"
else
  : "${GH_TOKEN:?GH_TOKEN is required when COMMENTS_PAGES_FILE is absent}"
  : "${REPOSITORY:?REPOSITORY is required}"
  : "${PR_NUMBER:?PR_NUMBER is required}"
  gh api --paginate --slurp \
    "repos/$REPOSITORY/issues/$PR_NUMBER/comments?per_page=100" \
    > "$comments_pages"
fi

jq '
  [
    .[][]
    | select(
        .user.login == "github-actions[bot]" and
        .user.type == "Bot" and
        .performed_via_github_app.slug == "github-actions"
      )
    | ([.body | scan("(?m)^<!-- pr-review-state:v1:([A-Za-z0-9+/=]+) -->$")] | last // null) as $marker
    | select($marker != null)
    | ($marker[0] | @base64d | fromjson?) as $state
    | select(
        ($state | type) == "object" and
        ($state.head | type == "string" and test("^[0-9a-f]{40}$")) and
        ($state.conclusion | IN("APPROVE", "REQUEST_CHANGES", "COMMENT")) and
        ($state.critical_count | type == "number" and . >= 0 and floor == .) and
        ($state.important_count | type == "number" and . >= 0 and floor == .) and
        ($state.suggestion_count | type == "number" and . >= 0 and floor == .)
      )
    | {comment_id: .id, created_at, body, state: $state}
  ]
  | sort_by(.comment_id)
  | last // null
' "$comments_pages" > "$RUNNER_TEMP/trusted-review.json"

review_mode=full
review_reason=no_trusted_review
if jq -e 'type == "object"' "$RUNNER_TEMP/trusted-review.json" > /dev/null; then
  previous_sha=$(jq -r '.state.head' "$RUNNER_TEMP/trusted-review.json")
  if [[ "$previous_sha" != "$HEAD_SHA" ]] &&
     git cat-file -e "$previous_sha^{commit}" 2>/dev/null &&
     git merge-base --is-ancestor "$previous_sha" "$HEAD_SHA"; then
    critical=$(jq -r '.state.critical_count' "$RUNNER_TEMP/trusted-review.json")
    important=$(jq -r '.state.important_count' "$RUNNER_TEMP/trusted-review.json")
    suggestion=$(jq -r '.state.suggestion_count' "$RUNNER_TEMP/trusted-review.json")
    if (( critical == 0 && important == 0 && suggestion >= 1 && suggestion <= 3 )); then
      review_mode=incremental
      review_reason=one_to_three_prior_minor_findings
    else
      review_reason=prior_review_not_small_increment
    fi
  else
    review_reason=unusable_or_current_cutoff
  fi
fi

if [[ "$review_mode" == incremental ]]; then
  git diff --find-renames "$previous_sha..$HEAD_SHA" > "$RUNNER_TEMP/pr.diff"
  git log --format='%H %s' "$previous_sha..$HEAD_SHA" > "$RUNNER_TEMP/pr-commits.txt"
else
  git diff --find-renames "$BASE_SHA...$HEAD_SHA" > "$RUNNER_TEMP/pr.diff"
  git log --format='%H %s' "$BASE_SHA..$HEAD_SHA" > "$RUNNER_TEMP/pr-commits.txt"
fi

jq -n \
  --arg mode "$review_mode" \
  --arg reason "$review_reason" \
  --slurpfile previous "$RUNNER_TEMP/trusted-review.json" \
  '{
    mode: $mode,
    reason: $reason,
    available: ($previous[0] != null),
    previous: $previous[0]
  }' > "$RUNNER_TEMP/review-history.json"
