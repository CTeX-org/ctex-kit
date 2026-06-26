#!/usr/bin/env bash
# scripts/check-parallel.sh — 加速 l3build check.
#
# 现状: ctex 默认 4 engine (pdftex/xetex/luatex/uptex) × 181 test × 2 checkruns,
# 单进程串行 ~20min. 加速策略:
#   - 主测(无 -c)按 engine 拆 4 个并行进程, 每个独立 build/check-<engine>/
#     (build.lua 通过 L3BUILD_TESTDIR_SUFFIX env 切 testdir).
#   - -c <config> 配置仍串行跑 (config 本身就只针对部分 engine, 数量少,
#     不值得并行).
#
# 用法 (在 ctex/ 等包目录内):
#   ENGINES="pdftex xetex luatex uptex"     # 主测并行 engine 列表
#   CONFIGS="test/config-cmap test/config-contrib test/config-ctxdoc"  # 串行 config
#   ../scripts/check-parallel.sh [extra-l3build-args...]
#
# 前提: build.lua 把 testdir 设为 "./build/check" .. (env L3BUILD_TESTDIR_SUFFIX
# or ""), 这样并行进程不争抢同一 testdir.
set -uo pipefail

ENGINES="${ENGINES:-pdftex xetex luatex uptex}"
CONFIGS="${CONFIGS:-}"
EXTRA_ARGS="$*"

if [ ! -f build.lua ]; then
  echo "ERROR: 必须在含 build.lua 的包目录里跑这个脚本" >&2
  exit 1
fi

# Phase 1: 主测多 engine 并行
echo "==================== Phase 1: 主测 (并行 engines: $ENGINES) ===================="

run_engine_main() {
  local engine="$1"
  L3BUILD_TESTDIR_SUFFIX="-${engine}" \
    l3build check -e "${engine}" -q ${EXTRA_ARGS} \
    2>&1 | sed -u "s/^/[${engine}] /"
  return "${PIPESTATUS[0]}"
}

declare -a MAIN_PIDS=()
declare -A MAIN_RC=()
declare -A MAIN_ENG=()
for engine in $ENGINES; do
  run_engine_main "$engine" &
  pid=$!
  MAIN_PIDS+=("$pid")
  MAIN_ENG["$pid"]="$engine"
done

MAIN_FAIL=0
for pid in "${MAIN_PIDS[@]}"; do
  wait "$pid"
  rc=$?
  engine="${MAIN_ENG[$pid]}"
  MAIN_RC["$engine"]="$rc"
  [ "$rc" -ne 0 ] && MAIN_FAIL=1
done

# Phase 2: -c configs 串行 (单进程, 默认 testdir, 4 engine 内部串行)
CONFIG_FAIL=0
declare -A CONFIG_RC=()
if [ -n "$CONFIGS" ]; then
  echo ""
  echo "==================== Phase 2: configs (串行: $CONFIGS) ===================="
  for c in $CONFIGS; do
    echo "--- config: $c ---"
    if l3build check -c "$c" -q ${EXTRA_ARGS} 2>&1; then
      CONFIG_RC["$c"]=0
    else
      CONFIG_RC["$c"]=$?
      CONFIG_FAIL=1
    fi
  done
fi

# 汇总
echo ""
echo "==================== check-parallel summary ===================="
echo "Phase 1 (main test, parallel by engine):"
for engine in $ENGINES; do
  rc="${MAIN_RC[$engine]}"
  if [ "$rc" -eq 0 ]; then
    echo "  ✓ ${engine}"
  else
    echo "  ✗ ${engine} (rc=${rc})"
  fi
done
if [ -n "$CONFIGS" ]; then
  echo "Phase 2 (configs, serial):"
  for c in $CONFIGS; do
    rc="${CONFIG_RC[$c]:-N/A}"
    if [ "$rc" = "0" ]; then
      echo "  ✓ ${c}"
    else
      echo "  ✗ ${c} (rc=${rc})"
    fi
  done
fi
echo "================================================================"

if [ "$MAIN_FAIL" -ne 0 ] || [ "$CONFIG_FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
