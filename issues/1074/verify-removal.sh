#!/usr/bin/env bash
# #1074 撤除条件的可复现验证。
#
# 结论: 无论 TL 有没有撤下旧 l3backend 包, kpsewhich 都命中 l3kernel 提供的那份,
# 两个日期一致 -> 原 sync-l3backend.sh 恒空转 -> 可以删。
#
# 用法: bash verify-removal.sh
set -euo pipefail

TLNET='https://mirror.ctan.org/systems/texlive/tlnet/archive'
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fetch() {  # $1 = 包名, $2 = 解开到哪
  curl -fsS --max-time 120 -o "$work/$1.tar.xz" -L "$TLNET/$1.tar.xz"
  mkdir -p "$2"
  tar -xJf "$work/$1.tar.xz" -C "$2"
}

datestamp() {  # $1 = .def 路径
  grep -ohE '\{l3backend-pdftex\.def\}\{[0-9-]+\}' "$1" | head -1
}

echo "=== 情形 A: 只有新版 l3kernel ==="
A="$work/only-kernel"; fetch l3kernel "$A"
find "$A" -name 'l3backend-pdftex.def' | sed "s|$A/||"
echo "  日期: $(datestamp "$A/tex/latex/l3kernel/l3backend-pdftex.def")"
echo "  kpse 命中: $(TEXMFHOME="$A" kpsewhich l3backend-pdftex.def)"

echo
echo "=== 情形 B: 新旧两包共存(TL 尚未撤下旧包的过渡态) ==="
B="$work/both"; fetch l3kernel "$B"; fetch l3backend "$B"
for d in l3kernel l3backend; do
  f="$B/tex/latex/$d/l3backend-pdftex.def"
  [ -f "$f" ] && echo "  $d: $(datestamp "$f")"
done
echo "  kpse 命中(按优先级):"
TEXMFHOME="$B" kpsewhich -all l3backend-pdftex.def | sed "s|$B|<tree>|;s|^|    |"

echo
echo "=== 两种情形下 expl3 与 backend 日期是否一致 ==="
for name in only-kernel both; do
  t="$work/$name"
  k=$(grep -oE 'ExplFileDate\{[0-9-]+\}' "$(TEXMFHOME=$t kpsewhich expl3.sty)" 2>/dev/null | head -1 || echo '(用系统 expl3)')
  b=$(datestamp "$(TEXMFHOME=$t kpsewhich l3backend-pdftex.def)")
  printf '  %-12s expl3=%s  backend=%s\n' "$name" "$k" "$b"
done
