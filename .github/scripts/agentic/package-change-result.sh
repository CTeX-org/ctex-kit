#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 7 ]]; then
  echo "usage: $0 RESULT_FILE REPO_DIR ARTIFACT_DIR BASE_SHA REVIEWER MODEL MODE" >&2
  exit 2
fi

result_file=$1
repo_dir=$2
artifact_dir=$3
base_sha=$4
reviewer=$5
model=$6
mode=$7

jq -e '
  (type == "object") and
  (.description | type == "string" and length > 0 and length <= 500 and (test("[\\r\\n]") | not)) and
  (.outcome | IN("READY", "NO_CHANGES", "BLOCKED", "INCOMPLETE")) and
  (.comment_body | type == "string" and length > 0 and length <= 60000) and
  (.commit_message | type == "string" and length > 0 and length <= 200 and (test("[\\r\\n]") | not)) and
  (.pr_title | type == "string" and length > 0 and length <= 256 and (test("[\\r\\n]") | not)) and
  (.pr_body | type == "string" and length > 0 and length <= 60000)
' "$result_file" > /dev/null

outcome=$(jq -r '.outcome' "$result_file")
[[ "$outcome" != INCOMPLETE ]]

actual_head=$(git -C "$repo_dir" rev-parse HEAD)
[[ "$actual_head" == "$base_sha" ]]
mkdir -p "$artifact_dir"

normalized="$artifact_dir/result.json"
jq -c --arg reviewer "$reviewer" --arg model "$model" \
  '. + {reviewer: $reviewer, model: $model}' "$result_file" > "$normalized"

block_submodule_change() {
  jq -c '
    .outcome = "BLOCKED"
    | .description = "任务涉及 submodule 变更，自动发布暂不支持跨仓库修改"
    | .comment_body += "\n\n自动实现已停止：当前发布链路暂不支持 submodule 工作树、提交或 gitlink 变更。"
  ' "$normalized" > "$artifact_dir/result.tmp"
  mv "$artifact_dir/result.tmp" "$normalized"
  jq -n \
    --arg base_sha "$base_sha" \
    --arg reviewer "$reviewer" \
    --arg model "$model" \
    '{version: 1, outcome: "BLOCKED", base_sha: $base_sha, reviewer: $reviewer, model: $model}' \
    > "$artifact_dir/manifest.json"
  exit 0
}

if [[ "$outcome" == NO_CHANGES || "$outcome" == READY ]]; then
  worktree_status=$(git -C "$repo_dir" status --porcelain --untracked-files=all --ignore-submodules=none)
  # 单引号中的程序应由各子模块的 shell 展开，而不是由当前 shell 提前展开。
  # shellcheck disable=SC2016
  dirty_submodules=$(git -C "$repo_dir" submodule foreach --quiet --recursive '
    if [ -n "$(git status --porcelain --untracked-files=all)" ]; then
      printf "%s\n" "$displaypath"
    fi
  ')
fi

if [[ "$outcome" == NO_CHANGES && ( -n "$worktree_status" || -n "$dirty_submodules" ) ]]; then
  echo "::error::NO_CHANGES result left a dirty repository or submodule worktree"
  exit 1
fi

if [[ "$outcome" != READY ]]; then
  jq -n \
    --arg outcome "$outcome" \
    --arg base_sha "$base_sha" \
    --arg reviewer "$reviewer" \
    --arg model "$model" \
    '{version: 1, outcome: $outcome, base_sha: $base_sha, reviewer: $reviewer, model: $model}' \
    > "$artifact_dir/manifest.json"
  exit 0
fi

if [[ -z "$worktree_status" ]]; then
  echo "::error::READY result did not modify the worktree"
  exit 1
fi

if [[ -n "$dirty_submodules" ]]; then
  echo "::notice::Blocking dirty submodule worktrees: $dirty_submodules"
  block_submodule_change
fi

git -C "$repo_dir" diff --check
git -C "$repo_dir" add -A

if git -C "$repo_dir" diff --cached --raw | awk 'substr($1, 2) == "160000" || $2 == "160000" { found=1 } END { exit !found }'; then
  block_submodule_change
fi

if [[ "$mode" == update-llmdoc ]]; then
  invalid_path=$(git -C "$repo_dir" diff --cached --name-only | awk '$0 != "llmdoc" && $0 !~ /^llmdoc\// { print; exit }')
  if [[ -n "$invalid_path" ]]; then
    echo "::error::update-llmdoc changed a path outside llmdoc/: $invalid_path"
    exit 1
  fi
fi

commit_message=$(jq -r '.commit_message' "$normalized")
git -C "$repo_dir" config user.name "github-actions[bot]"
git -C "$repo_dir" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git -C "$repo_dir" commit -m "$commit_message"
candidate_sha=$(git -C "$repo_dir" rev-parse HEAD)
parent_sha=$(git -C "$repo_dir" rev-parse HEAD^)
[[ "$parent_sha" == "$base_sha" ]]

git -C "$repo_dir" bundle create "$artifact_dir/candidate.bundle" HEAD "^$base_sha"
bundle_sha256=$(sha256sum "$artifact_dir/candidate.bundle" | awk '{print $1}')
changed_files=$(git -C "$repo_dir" diff --name-only "$base_sha..$candidate_sha" | jq -R -s 'split("\n") | map(select(length > 0))')

jq -n \
  --arg base_sha "$base_sha" \
  --arg candidate_sha "$candidate_sha" \
  --arg bundle_sha256 "$bundle_sha256" \
  --arg reviewer "$reviewer" \
  --arg model "$model" \
  --argjson changed_files "$changed_files" \
  '{
    version: 1,
    outcome: "READY",
    base_sha: $base_sha,
    candidate_sha: $candidate_sha,
    bundle_sha256: $bundle_sha256,
    changed_files: $changed_files,
    reviewer: $reviewer,
    model: $model
  }' > "$artifact_dir/manifest.json"
