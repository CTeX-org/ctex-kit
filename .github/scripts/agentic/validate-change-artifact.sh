#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 ARTIFACT_DIR REPO_DIR MODE" >&2
  exit 2
fi

artifact_dir=$1
repo_dir=$2
mode=$3
manifest="$artifact_dir/manifest.json"
result="$artifact_dir/result.json"

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
  (.commit_message | type == "string" and length > 0 and length <= 200 and (test("[\\r\\n]") | not)) and
  (.pr_title | type == "string" and length > 0 and length <= 256 and (test("[\\r\\n]") | not)) and
  (.pr_body | type == "string" and length > 0 and length <= 60000) and
  (.reviewer | IN("codex", "claude")) and
  (.model | IN("gpt-5.6-sol", "claude-opus-5"))
' "$result" > /dev/null

outcome=$(jq -r '.outcome' "$manifest")
[[ "$(jq -r '.outcome' "$result")" == "$outcome" ]]
[[ "$(jq -r '.reviewer' "$result")" == "$(jq -r '.reviewer' "$manifest")" ]]
[[ "$(jq -r '.model' "$result")" == "$(jq -r '.model' "$manifest")" ]]

base_sha=$(jq -r '.base_sha' "$manifest")
[[ "$(git -C "$repo_dir" rev-parse HEAD)" == "$base_sha" ]]

if [[ "$outcome" != READY ]]; then
  [[ ! -e "$artifact_dir/candidate.bundle" ]]
  exit 0
fi

jq -e '
  (.candidate_sha | type == "string" and test("^[0-9a-f]{40}$")) and
  (.bundle_sha256 | type == "string" and test("^[0-9a-f]{64}$")) and
  (.changed_files | type == "array" and length > 0 and all(.[]; type == "string" and length > 0))
' "$manifest" > /dev/null

bundle="$artifact_dir/candidate.bundle"
expected_bundle_sha=$(jq -r '.bundle_sha256' "$manifest")
[[ "$(sha256sum "$bundle" | awk '{print $1}')" == "$expected_bundle_sha" ]]
git -C "$repo_dir" bundle verify "$bundle"
candidate_sha=$(jq -r '.candidate_sha' "$manifest")
git -C "$repo_dir" -c protocol.file.allow=always fetch "$bundle" "$candidate_sha"
[[ "$(git -C "$repo_dir" rev-parse FETCH_HEAD)" == "$candidate_sha" ]]
[[ "$(git -C "$repo_dir" rev-parse "$candidate_sha^")" == "$base_sha" ]]
[[ "$(git -C "$repo_dir" rev-list --count "$base_sha..$candidate_sha")" == 1 ]]
git -C "$repo_dir" diff --check "$base_sha..$candidate_sha"

if git -C "$repo_dir" diff --raw "$base_sha..$candidate_sha" | awk 'substr($1, 2) == "160000" || $2 == "160000" { found=1 } END { exit !found }'; then
  echo "::error::Candidate changes a submodule gitlink"
  exit 1
fi

actual_files=$(git -C "$repo_dir" diff --name-only "$base_sha..$candidate_sha" | jq -R -s 'split("\n") | map(select(length > 0)) | sort')
manifest_files=$(jq -c '.changed_files | sort' "$manifest")
[[ "$(jq -c . <<< "$actual_files")" == "$manifest_files" ]]

if [[ "$mode" == update-llmdoc ]]; then
  invalid_path=$(git -C "$repo_dir" diff --name-only "$base_sha..$candidate_sha" | awk '$0 != "llmdoc" && $0 !~ /^llmdoc\// { print; exit }')
  [[ -z "$invalid_path" ]]
fi

git -C "$repo_dir" checkout --detach "$candidate_sha"
if [[ -x "$RUNNER_TEMP/agentic-validate.sh" ]]; then
  (cd "$repo_dir" && "$RUNNER_TEMP/agentic-validate.sh")
fi
