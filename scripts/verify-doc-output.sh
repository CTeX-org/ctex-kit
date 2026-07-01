#!/usr/bin/env bash
# 用途: 校验 l3build doc 是否为指定包产出了预期的 PDF 文件. 仅在
# check-doc.yml 里跑, 保证 l3build doc 退出码 0 之外, 实际期望的
# typesetfiles 都真的编成了 PDF (防 fallback 到 rerun 静默漏排, 或
# typesetfiles 表被误改).
#
# 用法:
#   scripts/verify-doc-output.sh <pkg-dir>
#
# 在 <pkg-dir> 下检查 build/doc/*.pdf. 期望清单硬编码在下方 case 里,
# 与 release.yml 里 pkg → module 映射对齐, 覆盖 typesetfiles / 特殊
# typeset 命令 (zhmetrics 双 typeset, xeCJK 双 typeset). typesetfiles
# 为空的包 (zhmetrics-uptex) 期望零 PDF, 单独处理.

set -euo pipefail

PKG_DIR="${1:?usage: $0 <pkg-dir>}"

if [ ! -d "$PKG_DIR" ]; then
  echo "::error::Package dir not found: $PKG_DIR"
  exit 1
fi

DOC_DIR="$PKG_DIR/build/doc"

# 期望 PDF 清单. 与各包 build.lua 的 typesetfiles 精确对齐.
case "$PKG_DIR" in
  ctex)             expected=("ctex.pdf") ;;
  xeCJK)            expected=("xeCJK.pdf" "xunicode-symbols.pdf") ;;
  CJKpunct)         expected=("CJKpunct.pdf") ;;
  zhnumber)         expected=("zhnumber.pdf") ;;
  xCJK2uni)         expected=("xCJK2uni.pdf") ;;
  xpinyin)          expected=("xpinyin.pdf") ;;
  # zhmetrics/build.lua typesetfiles 里有 zhmCJK.dtx + zhmCJK-test.tex.
  # test.tex 硬编码 simsun.ttc/simhei.ttf 文件名 (走 kpse 查文件, 不是 friendly
  # name, fontconfig alias 救不了), CI 无这两个字体, dvipdfmx 中止. 我们只
  # 校验主文档 zhmCJK.pdf 存在 — test.tex 本身是包内部字体安装 demo, 与
  # "文档可编译性"这个 CI 目标无关.
  zhmetrics)        expected=("zhmCJK.pdf") ;;
  zhmetrics-uptex)  expected=() ;;  # typesetfiles = {} — 空即通过.
  zhlineskip)       expected=("zhlineskip.pdf") ;;
  *)
    echo "::error::Unknown package: $PKG_DIR"
    exit 1
    ;;
esac

echo "Verifying PDF outputs for pkg=$PKG_DIR (expected: ${expected[*]:-<none>})"

# 特例: 无 typesetfiles → 只要 l3build doc 已经 exit 0 就通过 (调用方
# 已保证), 这里不需要 doc dir 存在.
if [ "${#expected[@]}" -eq 0 ]; then
  echo "  ✓ no typesetfiles configured; skip"
  exit 0
fi

if [ ! -d "$DOC_DIR" ]; then
  echo "::error::$DOC_DIR does not exist. l3build doc may have skipped typesetting entirely."
  exit 1
fi

fail=0
# 最小合法 PDF 大小. Hello-world xelatex PDF ~10 KB, 我们的都远超 100 KB;
# dvipdfmx fatal 后残留的 stub 只有几十字节 (%PDF 头 + 空). 设 1024 字节
# 上限最保守也能抓住 stub, 又不误伤 (真实 doc 从不低于几十 KB).
MIN_PDF_BYTES=1024
for pdf in "${expected[@]}"; do
  target="$DOC_DIR/$pdf"
  if [ ! -f "$target" ]; then
    echo "::error::$PKG_DIR: missing $target"
    fail=1
    continue
  fi
  # sanity: PDF 至少像样 (前 4 字节 "%PDF"). 防 typesetpdf 静默产 0 字节
  # 或残留 old log 冒充.
  head4="$(head -c 4 "$target" 2>/dev/null || true)"
  if [ "$head4" != "%PDF" ]; then
    echo "::error::$PKG_DIR: $target does not start with %PDF magic (got: '$head4')"
    fail=1
    continue
  fi
  size=$(stat -c %s "$target" 2>/dev/null || wc -c < "$target")
  # 抓 dvipdfmx fatal 后残留的空 %PDF header. 见 zhmetrics zhmCJK-test 场景.
  if [ "$size" -lt "$MIN_PDF_BYTES" ]; then
    echo "::error::$PKG_DIR: $target too small ($size bytes < $MIN_PDF_BYTES) — likely dvipdfmx/xetex bailed out mid-write"
    fail=1
    continue
  fi
  echo "  ✓ $pdf ($size bytes)"
done

if [ "$fail" -ne 0 ]; then
  echo "::group::Actual PDFs in $DOC_DIR"
  ls -la "$DOC_DIR"
  echo "::endgroup::"
  exit 1
fi

echo "All expected PDFs present for $PKG_DIR"
