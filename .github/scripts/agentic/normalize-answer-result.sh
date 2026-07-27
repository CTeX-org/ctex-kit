#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "usage: $0 RESULT_FILE OUTPUT_FILE REVIEWER MODEL MODE" >&2
  exit 2
fi

result_file=$1
output_file=$2
reviewer=$3
model=$4
mode=$5

common='(type == "object") and
  (.description | type == "string" and length > 0 and length <= 500 and (test("[\\r\\n]") | not)) and
  (.result_status | IN("COMPLETE", "INCOMPLETE")) and
  (.comment_body | type == "string" and length > 0 and length <= 60000)'

case "$mode" in
  question)
    jq -e "$common and
      ((keys | sort) == [\"comment_body\", \"description\", \"result_status\"])
    " "$result_file" > /dev/null
    ;;
  issue-dispatch)
    jq -e "$common and
      ((keys | sort) == [\"auto_fix_eligible\", \"comment_body\", \"cost\", \"description\", \"issue_type\", \"result_status\", \"severity\"]) and
      (.issue_type | IN(\"bug\", \"feature\", \"question\")) and
      (.severity | IN(\"critical\", \"high\", \"medium\", \"low\", \"n/a\")) and
      (.cost | IN(\"small\", \"medium\", \"large\", \"extra-large\", \"n/a\")) and
      (.auto_fix_eligible | type == \"boolean\")
    " "$result_file" > /dev/null
    ;;
  *)
    echo "unsupported answer result mode: $mode" >&2
    exit 2
    ;;
esac

jq -c --arg reviewer "$reviewer" --arg model "$model" \
  '. + {reviewer: $reviewer, model: $model}' "$result_file" > "$output_file"

# A schema-valid soft failure must trigger the independent fallback.
jq -e '.result_status == "COMPLETE"' "$output_file" > /dev/null
