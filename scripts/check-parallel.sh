#!/usr/bin/env bash
# scripts/check-parallel.sh — 加速 l3build check, 多 engine 并行.
#
# 设计: l3build 内部用相对路径写 .tlg, 让 build/check 多一层 (如
# build/check-<engine>) 会让 .log 里的相对路径 "../foo" 而非 "foo", 与
# .tlg 不匹配, 整个 baseline 报 diff.
#
# 解决: 每个 engine 进程在**独立的子工作目录**里跑 (整个包 cp 一份),
# testdir 仍是 build/check (相对路径不变, .tlg 兼容).
#
# 用法 (在 ctex/ 等包目录内执行):
#   ENGINES="pdftex xetex luatex uptex"
#   CONFIGS="test/config-cmap test/config-contrib test/config-ctxdoc"
#   ../scripts/check-parallel.sh [extra-l3build-args...]
#
# bash 兼容: 不依赖 bash 4+ 特性 (declare -A 等). macOS 自带 bash 3.2 可跑.
set -uo pipefail

ENGINES="${ENGINES:-pdftex xetex luatex uptex}"
CONFIGS="${CONFIGS:-}"
# 用数组保 EXTRA_ARGS, 避免单字符串模式下 word splitting 出错 (例如未来
# 有用户传 --first foo 这种带空格的参数). bash 3.2 安全: 不依赖 4+ 特性.
EXTRA_ARGS=("$@")

if [ ! -f build.lua ]; then
  echo "ERROR: 必须在含 build.lua 的包目录里跑这个脚本" >&2
  exit 1
fi

pkg_dir="$(pwd)"
pkg_name="$(basename "$pkg_dir")"
parent_dir="$(dirname "$pkg_dir")"

# 工作目录在仓库根的 tmp/parallel-check/<engine>/, 每个 engine 一份完整的
# 包目录 cp. 复用 git ls-files 保证只 cp 受版本控制的文件 (不带 build/).
work_root="${parent_dir}/tmp/parallel-check"
mkdir -p "$work_root"
trap 'rm -rf "$work_root"' EXIT

# 用 git archive | tar 高效生成快照: 比 cp -r 快 (无需扫 build/ 等大目录).
# 需要包目录在 git 控制下.
snapshot_pkg() {
  local dest="$1"
  mkdir -p "$dest"
  # 包根目录的所有 git 跟踪文件; 排除 build/ (l3build 工作区).
  (cd "$pkg_dir" && git ls-files -z | tar --null -T- -cf - 2>/dev/null) \
    | tar -xf - -C "$dest" 2>/dev/null
}

# ctex 的 checkdeps = {"../xeCJK", "../zhnumber"}. 包目录在 work_root/<engine>/<pkg>
# 跑时, ../<dep> 应当是 work_root/<engine>/<dep>. 所以 deps 也要 cp.
snapshot_dep() {
  local dep="$1"
  local dest_root="$2"
  local dep_src="${parent_dir}/${dep}"
  local dep_dest="${dest_root}/${dep}"
  [ -d "$dep_src" ] || return 0
  mkdir -p "$dep_dest"
  (cd "$dep_src" && git ls-files -z | tar --null -T- -cf - 2>/dev/null) \
    | tar -xf - -C "$dep_dest" 2>/dev/null
}

# 从 build.lua 抠出 checkdeps. ctex 是 {"../xeCJK", "../zhnumber"}.
CHECKDEPS=$(awk '/^checkdeps/,/}/ {
  while (match($0, /"\.\.\/[^"]+"/)) {
    s = substr($0, RSTART+4, RLENGTH-5)
    print s
    $0 = substr($0, RSTART+RLENGTH)
  }
}' build.lua | sort -u)

# 始终需要的兄弟目录: support/ 含共享 build-config.lua, 被各包的 build.lua
# 末尾 dofile. 即使 checkdeps 没列也必须 cp.
SIBLING_ALWAYS="support"

# Phase 1: 主测多 engine 并行
echo "==================== Phase 1: 主测 (并行 engines: $ENGINES) ===================="

# 为每个 engine 准备一个独立子工作目录, 后台跑.
declare_pids() { :; }   # no-op marker
pid_list=""              # space-separated; 用字符串避免 declare -A
engine_for_pid=""        # "pid:engine pid:engine ..." 格式
exit_for_engine=""       # "engine:rc engine:rc ..."

for engine in $ENGINES; do
  engine_workdir="${work_root}/${engine}/${pkg_name}"
  snapshot_pkg "$engine_workdir"
  for dep in $CHECKDEPS; do
    snapshot_dep "$dep" "${work_root}/${engine}"
  done
  for sib in $SIBLING_ALWAYS; do
    snapshot_dep "$sib" "${work_root}/${engine}"
  done

  (
    cd "$engine_workdir"
    # bash 3.2 安全: 空数组用 ${arr[@]+"${arr[@]}"} 形式避免 set -u 炸.
    l3build check -e "${engine}" -q ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} 2>&1 \
      | sed -u "s|^|[${engine}] |"
    exit "${PIPESTATUS[0]}"
  ) &
  pid=$!
  pid_list="$pid_list $pid"
  engine_for_pid="$engine_for_pid ${pid}:${engine}"
done

MAIN_FAIL=0
for pid in $pid_list; do
  wait "$pid"
  rc=$?
  # 从 engine_for_pid 找回对应 engine
  engine=$(echo "$engine_for_pid" | tr ' ' '\n' | grep "^${pid}:" | cut -d: -f2)
  exit_for_engine="$exit_for_engine ${engine}:${rc}"
  [ "$rc" -ne 0 ] && MAIN_FAIL=1
done

# Phase 2: -c configs 串行, 在原 pkg_dir 跑 (configs 不并行, 相对路径无忧).
CONFIG_FAIL=0
config_exits=""
if [ -n "$CONFIGS" ]; then
  echo ""
  echo "==================== Phase 2: configs (串行: $CONFIGS) ===================="
  for c in $CONFIGS; do
    echo "--- config: $c ---"
    if l3build check -c "$c" -q ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}; then
      config_exits="$config_exits ${c}:0"
    else
      rc=$?
      config_exits="$config_exits ${c}:${rc}"
      CONFIG_FAIL=1
    fi
  done
fi

# 汇总
echo ""
echo "==================== check-parallel summary ===================="
echo "Phase 1 (main test, parallel by engine):"
for entry in $exit_for_engine; do
  engine="${entry%:*}"
  rc="${entry#*:}"
  if [ "$rc" -eq 0 ]; then
    echo "  ✓ ${engine}"
  else
    echo "  ✗ ${engine} (rc=${rc})"
  fi
done
if [ -n "$CONFIGS" ]; then
  echo "Phase 2 (configs, serial):"
  for entry in $config_exits; do
    c="${entry%:*}"
    rc="${entry#*:}"
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
