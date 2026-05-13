#!/bin/bash
# Stop hook: verify dtx checksums across all projects.
# Exit 2 blocks Claude from stopping so it can handle the mismatch.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$PROJECT_DIR" || exit 0

for dir in ctex xeCJK zhnumber xpinyin jiazhu xCJK2uni zhmetrics; do
  if [ -d "$dir" ] && [ -f "$dir/build.lua" ]; then
    (cd "$dir" && l3build checksum) 2>/dev/null
  fi
done

changed=$(git diff --name-only -- '*.dtx')
if [ -n "$changed" ]; then
  echo "Checksum mismatch detected in:"
  echo "$changed"
  echo ""
  echo "The .dtx files have been auto-corrected. Please review and commit."
  exit 2
fi

exit 0
