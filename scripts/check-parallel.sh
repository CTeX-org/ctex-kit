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
#   LUATEX_BUCKETS=2    # 可选: luatex 内部再切 N 桶 (--first/--last)
#                       # 并行, 用于打平 luatex 远慢于其他 engine 的瓶颈.
#                       # 默认 1 (不切桶).
#   ../scripts/check-parallel.sh [extra-l3build-args...]
#
# bash 兼容: 不依赖 bash 4+ 特性 (declare -A 等). macOS 自带 bash 3.2 可跑.
set -uo pipefail

ENGINES="${ENGINES:-pdftex xetex luatex uptex}"
CONFIGS="${CONFIGS:-}"
LUATEX_BUCKETS="${LUATEX_BUCKETS:-1}"
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
# 失败时**保留** work_root, 让上层 (test.yml 的 || 块) 能 cat 各 engine
# 的 patch-health.log / *.log 做诊断. 成功时再删.
cleanup() { [ "$?" -eq 0 ] && rm -rf "$work_root"; }
trap cleanup EXIT

# 用 git archive | tar 高效生成快照: 比 cp -r 快 (无需扫 build/ 等大目录).
# 需要包目录在 git 控制下.
# 注: 不吞 stderr — snapshot 失败会让 l3build 在难以诊断的位置炸, 让错误
# 直接冒出来更省事.
snapshot_pkg() {
  local dest="$1"
  mkdir -p "$dest"
  # 包根目录的所有 git 跟踪文件; 排除 build/ (l3build 工作区).
  (cd "$pkg_dir" && git ls-files -z | tar --null -T- -cf -) \
    | tar -xf - -C "$dest"
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
  (cd "$dep_src" && git ls-files -z | tar --null -T- -cf -) \
    | tar -xf - -C "$dep_dest"
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

# 从 build.lua 抠 testfiledir (默认 "./testfiles"). 用于 luatex bucket split.
TESTFILEDIR=$(awk -F'"' '/^[[:space:]]*testfiledir[[:space:]]*=/ {print $2; exit}' build.lua)
TESTFILEDIR="${TESTFILEDIR:-./testfiles}"

# bucket-<idx>-of-<N> 的 first/last test 名字 (按字母序). 调用约定:
#   bucket_range <idx> <total>   # idx 从 1 到 total
# 输出 "first last" (空格分隔). l3build --first/--last 按字母序选区间, 这跟
# 它 globbing testfiledir/*.lvt 后 sort 的行为一致.
# 空 testfiledir 或 N > 文件数等极端 case: 返回 "EMPTY", 调用方应跳过该桶.
bucket_range() {
  local idx="$1" total="$2"
  local files all_count start_idx end_idx first last
  files=$(ls "${TESTFILEDIR}"/*.lvt 2>/dev/null | sort | awk -F/ '{n=$NF; sub(/\.lvt$/,"",n); print n}')
  if [ -z "$files" ]; then
    echo "EMPTY"
    return
  fi
  all_count=$(echo "$files" | wc -l)
  # 整数除法 + 余数分摊给前几个 bucket. idx=1..total.
  start_idx=$(( (idx - 1) * all_count / total + 1 ))
  end_idx=$(( idx * all_count / total ))
  if [ "$start_idx" -gt "$end_idx" ]; then
    # bucket 数比文件数还多, 当前桶分不到东西.
    echo "EMPTY"
    return
  fi
  first=$(echo "$files" | sed -n "${start_idx}p")
  last=$(echo "$files" | sed -n "${end_idx}p")
  echo "$first" "$last"
}

# Phase 1: 主测多 engine 并行
PHASE1_DESC="并行 engines: $ENGINES"
if [ "$LUATEX_BUCKETS" -gt 1 ] && echo "$ENGINES" | grep -qw luatex; then
  PHASE1_DESC="$PHASE1_DESC; luatex 切 ${LUATEX_BUCKETS} 桶"
fi
echo "==================== Phase 1: 主测 ($PHASE1_DESC) ===================="

# 为每个 engine (或 luatex bucket) 准备独立子工作目录, 后台跑.
# 用字符串列表保留 pid / label / rc 映射, 避免 declare -A (bash 3.2).
pid_list=""              # space-separated pids
label_for_pid=""         # "pid:label pid:label ..."
exit_for_label=""        # "label:rc label:rc ..."

spawn_check() {
  # spawn_check <label> <workdir> [extra l3build args...]
  local label="$1" workdir="$2"
  shift 2
  local extra=("$@")
  (
    cd "$workdir"
    # bash 3.2 安全: 空数组用 ${arr[@]+"${arr[@]}"} 形式避免 set -u 炸.
    # 用 awk 而非 sed -u 加前缀: awk 默认按行刷, 跨平台 (sed -u 是 GNU 扩展,
    # windows git bash 的 sed 不支持).
    l3build check -q ${extra[@]+"${extra[@]}"} ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} 2>&1 \
      | awk -v prefix="[${label}] " '{ print prefix $0; fflush() }'
    exit "${PIPESTATUS[0]}"
  ) &
  local pid=$!
  pid_list="$pid_list $pid"
  label_for_pid="$label_for_pid ${pid}:${label}"
}

prepare_workdir() {
  # prepare_workdir <slot>  — slot 是 work_root 下的子目录名 (engine 或 engine-bucketK).
  local slot="$1"
  local workdir="${work_root}/${slot}/${pkg_name}"
  snapshot_pkg "$workdir"
  local dep
  for dep in $CHECKDEPS; do
    snapshot_dep "$dep" "${work_root}/${slot}"
  done
  for dep in $SIBLING_ALWAYS; do
    snapshot_dep "$dep" "${work_root}/${slot}"
  done
  echo "$workdir"
}

for engine in $ENGINES; do
  if [ "$engine" = "luatex" ] && [ "$LUATEX_BUCKETS" -gt 1 ]; then
    # luatex 切桶: 各桶独立 workdir, 用 --first/--last 切区间.
    i=1
    while [ "$i" -le "$LUATEX_BUCKETS" ]; do
      slot="luatex-b${i}"
      workdir=$(prepare_workdir "$slot")
      range=$(cd "$workdir" && bucket_range "$i" "$LUATEX_BUCKETS")
      if [ "$range" = "EMPTY" ]; then
        echo "skip luatex/b${i}: empty bucket (LUATEX_BUCKETS > testfile count?)"
        i=$((i + 1))
        continue
      fi
      first=${range% *}
      last=${range#* }
      label="luatex/b${i}"
      echo "spawn ${label}: --first ${first} --last ${last}"
      spawn_check "$label" "$workdir" -e luatex --first "$first" --last "$last"
      i=$((i + 1))
    done
  else
    workdir=$(prepare_workdir "$engine")
    spawn_check "$engine" "$workdir" -e "$engine"
  fi
done

MAIN_FAIL=0
for pid in $pid_list; do
  wait "$pid"
  rc=$?
  # 从 label_for_pid 找回对应 label
  label=$(echo "$label_for_pid" | tr ' ' '\n' | grep "^${pid}:" | cut -d: -f2)
  exit_for_label="$exit_for_label ${label}:${rc}"
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
echo "Phase 1 (main test, parallel):"
for entry in $exit_for_label; do
  label="${entry%:*}"
  rc="${entry#*:}"
  if [ "$rc" -eq 0 ]; then
    echo "  ✓ ${label}"
  else
    echo "  ✗ ${label} (rc=${rc})"
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
