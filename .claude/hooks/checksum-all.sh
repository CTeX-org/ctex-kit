#!/bin/bash
# Stop hook: verify dtx checksums across all projects.
# Exit 2 blocks Claude from stopping so it can handle the mismatch.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$PROJECT_DIR" || exit 0

# Snapshot dtx diff BEFORE running checksum
before=$(git diff -- '*.dtx' | sha256sum)

for dir in ctex xeCJK zhnumber xpinyin jiazhu xCJK2uni zhmetrics; do
  if [ -d "$dir" ] && [ -f "$dir/build.lua" ]; then
    (cd "$dir" && l3build checksum) > /dev/null 2>&1 || true
  fi
done

# Only flag if l3build checksum introduced NEW changes
after=$(git diff -- '*.dtx' | sha256sum)
if [ "$before" != "$after" ]; then
  echo "Checksum mismatch detected — l3build checksum auto-corrected:"
  echo "$after"
  echo ""
  echo "Please review and commit the checksum changes."
  exit 2
fi

exit 0
