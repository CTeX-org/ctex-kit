#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 6 ]]; then
  echo "usage: $0 ARTIFACT_DIR REPOSITORY BASE_REF BRANCH MODE OUTPUT_FILE" >&2
  exit 2
fi

artifact_dir=$1
repository=$2
base_ref=$3
branch=$4
mode=$5
output_file=$6
manifest="$artifact_dir/manifest.json"
result="$artifact_dir/result.json"

: "${GH_TOKEN:?GH_TOKEN is required}"
git check-ref-format "refs/heads/$base_ref"
git check-ref-format "refs/heads/$branch"
[[ "$mode" == implement || "$mode" == update-llmdoc ]]

jq -e '
  (type == "object") and
  (.version == 1) and
  (.outcome | IN("READY", "NO_CHANGES", "BLOCKED")) and
  (.base_sha | type == "string" and test("^[0-9a-f]{40}$")) and
  (.reviewer | IN("codex", "claude")) and
  (.model | IN("gpt-5.6-sol", "claude-opus-5"))
' "$manifest" > /dev/null
jq -e '
  (type == "object") and
  (.description | type == "string" and length > 0 and length <= 500 and (test("[\\r\\n]") | not)) and
  (.outcome | IN("READY", "NO_CHANGES", "BLOCKED")) and
  (.comment_body | type == "string" and length > 0 and length <= 60000) and
  (.pr_title | type == "string" and length > 0 and length <= 256 and (test("[\\r\\n]") | not)) and
  (.pr_body | type == "string" and length > 0 and length <= 60000) and
  ((.reviewer == "codex" and .model == "gpt-5.6-sol") or
   (.reviewer == "claude" and .model == "claude-opus-5"))
' "$result" > /dev/null

outcome=$(jq -r '.outcome' "$manifest")
[[ "$(jq -r '.outcome' "$result")" == "$outcome" ]]
[[ "$(jq -r '.reviewer' "$result")" == "$(jq -r '.reviewer' "$manifest")" ]]
[[ "$(jq -r '.model' "$result")" == "$(jq -r '.model' "$manifest")" ]]

base_sha=$(jq -r '.base_sha' "$manifest")
reviewer=$(jq -r '.reviewer' "$result")
model=$(jq -r '.model' "$result")
pr_number=null
pr_url=""

if [[ "$mode" == implement ]]; then
  : "${ISSUE_NUMBER:?ISSUE_NUMBER is required for implement}"
  : "${ISSUE_ID:?ISSUE_ID is required for implement}"
  : "${TRIGGER_COMMENT_ID:?TRIGGER_COMMENT_ID is required for implement}"
  : "${COMMENT_TOKEN:?COMMENT_TOKEN is required for implement comments}"
  pr_marker="<!-- agentic-implement:${ISSUE_ID} -->"
else
  pr_marker="<!-- agentic-update-llmdoc:${base_ref} -->"
fi

if [[ "$outcome" == READY ]]; then
  bundle="$artifact_dir/candidate.bundle"
  candidate_sha=$(jq -r '.candidate_sha' "$manifest")
  expected_bundle_sha=$(jq -r '.bundle_sha256' "$manifest")
  [[ "$(sha256sum "$bundle" | awk '{print $1}')" == "$expected_bundle_sha" ]]

  publish_repo="$RUNNER_TEMP/agentic-publish.git"
  git init --bare "$publish_repo"
  git -C "$publish_repo" remote add origin "$GITHUB_SERVER_URL/$repository.git"
  gh auth setup-git
  git -C "$publish_repo" fetch --no-tags origin \
    "refs/heads/$base_ref:refs/heads/publish-base"
  git -C "$publish_repo" merge-base --is-ancestor "$base_sha" refs/heads/publish-base
  git -C "$publish_repo" bundle verify "$bundle"
  git -C "$publish_repo" -c protocol.file.allow=always fetch "$bundle" "$candidate_sha"
  [[ "$(git -C "$publish_repo" rev-parse FETCH_HEAD)" == "$candidate_sha" ]]
  [[ "$(git -C "$publish_repo" rev-parse "$candidate_sha^")" == "$base_sha" ]]
  [[ "$(git -C "$publish_repo" rev-list --count "$base_sha..$candidate_sha")" == 1 ]]
  git -C "$publish_repo" diff --check "$base_sha..$candidate_sha"
  if git -C "$publish_repo" diff --raw "$base_sha..$candidate_sha" | awk 'substr($1, 2) == "160000" || $2 == "160000" { found=1 } END { exit !found }'; then
    echo "::error::Validated candidate changes a submodule gitlink"
    exit 1
  fi

  existing_pr=$(gh pr list --repo "$repository" --state open --head "$branch" \
    --json number,url,body --limit 1)
  existing_pr_number=$(jq -r '.[0].number // empty' <<< "$existing_pr")
  existing_remote_sha=$(git -C "$publish_repo" ls-remote --heads origin "refs/heads/$branch" | awk '{print $1}')

  if [[ -n "$existing_remote_sha" && -z "$existing_pr_number" ]]; then
    echo "::error::Refusing to overwrite $branch because it has no workflow-owned open PR"
    exit 1
  fi
  if [[ -n "$existing_pr_number" ]]; then
    jq -e --arg marker "$pr_marker" '.[0].body | contains($marker)' <<< "$existing_pr" > /dev/null
  fi

  if [[ -n "$existing_remote_sha" ]]; then
    git -C "$publish_repo" push origin \
      --force-with-lease="refs/heads/$branch:$existing_remote_sha" \
      "$candidate_sha:refs/heads/$branch"
  else
    git -C "$publish_repo" push origin "$candidate_sha:refs/heads/$branch"
  fi

  jq -r '.pr_body' "$result" > "$RUNNER_TEMP/pr-body.md"
  if [[ "$mode" == implement ]]; then
    printf '\n\nCloses #%s\n' "$ISSUE_NUMBER" >> "$RUNNER_TEMP/pr-body.md"
  fi
  {
    echo
    echo "---"
    echo "_候选变更由 ${reviewer} / ${model} 生成并经独立 job 校验；PR 由隔离 publisher 创建。_"
    echo "$pr_marker"
  } >> "$RUNNER_TEMP/pr-body.md"
  pr_title=$(jq -r '.pr_title' "$result")

  if [[ -n "$existing_pr_number" ]]; then
    gh pr edit "$existing_pr_number" --repo "$repository" \
      --title "$pr_title" --body-file "$RUNNER_TEMP/pr-body.md"
    pr_number=$existing_pr_number
    pr_url=$(jq -r '.[0].url' <<< "$existing_pr")
  else
    pr_url=$(gh pr create --repo "$repository" --base "$base_ref" --head "$branch" \
      --title "$pr_title" --body-file "$RUNNER_TEMP/pr-body.md")
    pr_number=$(gh pr view "$pr_url" --repo "$repository" --json number --jq .number)
  fi
fi

if [[ "$mode" == implement ]]; then
  issue_marker="<!-- agentic-implement-result:${TRIGGER_COMMENT_ID} -->"
  jq -r '.comment_body' "$result" > "$RUNNER_TEMP/issue-comment.md"
  if [[ -n "$pr_url" ]]; then
    printf '\n\n**PR**: %s\n' "$pr_url" >> "$RUNNER_TEMP/issue-comment.md"
  fi
  {
    echo
    echo "---"
    echo "_由 ${reviewer} / ${model} 生成；外部副作用由隔离 publisher 执行。_"
    echo "$issue_marker"
  } >> "$RUNNER_TEMP/issue-comment.md"

  existing_comment_id=$(GH_TOKEN="$COMMENT_TOKEN" gh api --paginate \
    "repos/$repository/issues/$ISSUE_NUMBER/comments?per_page=100" \
    --jq ".[] | select(
      .user.login == \"github-actions[bot]\" and
      .performed_via_github_app.slug == \"github-actions\" and
      (.body | contains(\"$issue_marker\"))
    ) | .id" | tail -n 1)
  if [[ -n "$existing_comment_id" ]]; then
    jq -n --rawfile body "$RUNNER_TEMP/issue-comment.md" '{body: $body}' > "$RUNNER_TEMP/comment-payload.json"
    GH_TOKEN="$COMMENT_TOKEN" gh api --method PATCH "repos/$repository/issues/comments/$existing_comment_id" \
      --input "$RUNNER_TEMP/comment-payload.json" > /dev/null
  else
    GH_TOKEN="$COMMENT_TOKEN" gh issue comment "$ISSUE_NUMBER" --repo "$repository" \
      --body-file "$RUNNER_TEMP/issue-comment.md"
  fi
fi

case "$outcome" in
  READY|NO_CHANGES) status=success ;;
  BLOCKED) status=blocked ;;
esac

jq -c \
  --arg status "$status" \
  --arg branch_name "$branch" \
  --arg pr_url "$pr_url" \
  --argjson pr_number "$pr_number" \
  'del(.comment_body, .pr_body, .commit_message)
   | . + {status: $status, branch_name: $branch_name, pr_number: $pr_number, pr_url: $pr_url}' \
  "$result" > "$output_file"
