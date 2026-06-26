#!/usr/bin/env bash
# check-test-tilde.sh — 检查 .lvt 测试文件里 \TEST{...} / \BEGINTEST{...} /
# \TYPE{...} 命令大括号内是否含 `~` 误用 (issue #893).
#
# 重要约束: 仅在 **\ExplSyntaxOff 段** 报错. 在 \ExplSyntaxOn 段内 `~` 是
# 合法的 expl3 空格 (catcode 10), 而普通空格则被 ignore (catcode 9),
# 不能盲目替换.
#
# 用法 (两种形式之一):
#   git diff --cached -U0 -- '*.lvt' | .githooks/check-test-tilde.sh
#   git diff <base> HEAD -U0 -- '*.lvt' | .githooks/check-test-tilde.sh
#
# 仅检 diff 中 `+` 开头 (新增行) 的命中, 不动存量.
#
# 实现:
#   1) 用 awk 从 diff 中提取 (file, lineno, line) 三元组的命中候选
#   2) 对每个候选, 读取工作目录中该文件, 算该行是否在 ExplSyntaxOff 段
#   3) 只报 ExplSyntaxOff 段命中
set -uo pipefail

# Step 1: 从 stdin 的 diff 找命中候选, 输出 "<file>\t<lineno>\t<line>"
# 注: 命令内的 `[^{}]*` 与 fix-test-tilde.py 的 CMD_PATTERN 保持一致 — 不
# 跨嵌套大括号. 嵌套 (如 \TYPE{\foo{bar~baz}}) 不会命中, 但这是 false
# negative 安全方向 (宁可漏报不误报). 当前测试文件中未见这种模式.
candidates=$(awk '
  /^\+\+\+ b\// {
    file = substr($0, 7)
    if (file ~ /\.lvt$/) { interesting = 1 } else { interesting = 0 }
    next
  }
  /^@@/ {
    if (match($0, /\+[0-9]+/)) {
      newline = substr($0, RSTART + 1, RLENGTH - 1) + 0
    }
    next
  }
  /^\+/ {
    if (/^\+\+\+/) { next }
    if (interesting) {
      if (match($0, /\\(TEST|BEGINTEST|TYPE)[[:space:]]*\{[^{}]*~[^{}]*\}/)) {
        # tab-separated triple: file \t lineno \t line
        print file "\t" newline "\t" substr($0, 2)  # 去掉首字符 `+`
      }
    }
    newline++
    next
  }
  /^ / { newline++ }
')

if [ -z "$candidates" ]; then
  exit 0
fi

# Step 2 + 3: 对每个候选, 判断是否在 ExplSyntaxOff 段, 仅报 Off 段.
#
# 缓存策略: 用 tmp 目录的文件做 per-source-file 缓存, 避免 bash 4+ 才有的
# associative array (declare -A) — macOS 自带 bash 是 3.2, 不支持. 这种
# 缓存方式跨任意 bash 版本.
cache_dir="$(mktemp -d)"
trap 'rm -rf "$cache_dir"' EXIT
# 文件路径 -> 缓存路径: 用 sha1 防路径冲突. tr '/' '_' 会让
# `a/b_c.lvt` 与 `a_b/c.lvt` 撞 key, sha1 没这问题. 不依赖 GNU coreutils
# 之外的工具 — sha1sum / shasum (mac) 都支持, 选可用的一个.
if command -v sha1sum >/dev/null 2>&1; then
  cache_key() { printf '%s' "$1" | sha1sum | cut -c1-40; }
elif command -v shasum >/dev/null 2>&1; then
  cache_key() { printf '%s' "$1" | shasum | cut -c1-40; }
else
  # fallback: 路径转义到 hex, 没 sha 也至少没冲突
  cache_key() { printf '%s' "$1" | od -An -tx1 | tr -d ' \n'; }
fi

offending=""
n=0
while IFS=$'\t' read -r file lineno line; do
  [ -z "$file" ] && continue

  # 缓存每个文件的 line→state 表
  ckey="$(cache_key "$file")"
  cfile="${cache_dir}/${ckey}"
  if [ ! -s "$cfile" ]; then
    if [ ! -f "$file" ]; then
      # 文件可能被删除, 跳过
      continue
    fi
    awk '
      BEGIN { state = "off"; depth = 0 }
      # awk (POSIX) 不支持 \b 字符级锚, 用 [^a-zA-Z] 替代防止前缀
      # 误匹配 (e.g. \ExplSyntaxOnDemand).
      #
      # 状态切换只在 file-level top scope (depth == 0) 生效. depth>0
      # 时即便看到 \ExplSyntaxOff 也是某个 group 内局部切换, 出 group
      # 后自动恢复, 字面状态机不该跟. 这能正确处理
      # \sys_if_engine_luatex:F { \ExplSyntaxOff ... } 这种 expl3
      # group 内的局部 catcode 切换.
      #
      # 简化假设: 状态机按整行判定 — 同一行同时出现 \ExplSyntaxOff 和
      # \TEST{...} 时, 该行 state 用上一行末尾的 state (因为先 print
      # state 再算 depth, 而 depth 更新在最后). 实际 .lvt 不会这么写,
      # 这条记录是为未来注意.
      {
        # TeX 注释 (% 后): % 不在 escape 里就吃掉余下. \% 转义不算.
        # 这避免 % } 或 % \ExplSyntaxOff 被状态机错算.
        stripped = $0
        # 找第一个非转义 %; gawk 的 gensub 不可移植, 用 awk 标准 match
        # 循环找到 % 位置, 且前一字符不是 \\ (反斜杠).
        i = 1
        while (i <= length(stripped)) {
          c = substr(stripped, i, 1)
          if (c == "%" && (i == 1 || substr(stripped, i-1, 1) != "\\")) {
            stripped = substr(stripped, 1, i-1)
            break
          }
          i++
        }
        if (stripped ~ /\\ExplSyntaxOn([^a-zA-Z]|$)/  && depth == 0) state = "on"
        if (stripped ~ /\\ExplSyntaxOff([^a-zA-Z]|$)/ && depth == 0) state = "off"
        print NR "\t" state
        # 数本行净的 {/} 差, 更新 depth (留到下一行使用). 用 stripped
        # (去注释) 而非 $0, 避免 % { 这种字面字符被当 group 边界.
        sline = stripped
        o = 0; while (match(sline, /\{/)) { o++; sline = substr(sline, RSTART+1) }
        sline = stripped
        c = 0; while (match(sline, /\}/)) { c++; sline = substr(sline, RSTART+1) }
        depth = depth + o - c
      }
    ' "$file" > "$cfile"
  fi

  # 查 lineno 对应的 state
  state=$(awk -F'\t' -v ln="$lineno" '$1 == ln { print $2; exit }' "$cfile")

  if [ "$state" = "off" ]; then
    n=$((n + 1))
    offending="${offending}  ${file}:${lineno}: ${line}"$'\n'
  fi
done <<< "$candidates"

if [ "$n" -gt 0 ]; then
  {
    printf "✗ check-test-tilde: 发现 %d 处 .lvt 测试命令大括号内含 \`~\` (issue #893)\n" "$n"
    printf "\n"
    printf "%s" "$offending"
    printf "\n"
    printf "  说明: \\\\TEST/\\\\BEGINTEST 标题与 \\\\TYPE log 输出里, 在 \\\\ExplSyntaxOff\n"
    printf "        段 (默认 LaTeX catcode), \`~\` 是 active char (不可断空格), 会让\n"
    printf "        .tlg baseline 出现字面 \`~\`. 应改为普通空格.\n"
    printf "\n"
    printf "  注: \\\\ExplSyntaxOn 段内 \`~\` 是 expl3 合法空格 (catcode 10), 本检查\n"
    printf "      自动跳过该段, 不会误报.\n"
    printf "\n"
    printf "  紧急跳过: git commit --no-verify\n"
  } >&2
  exit 1
fi

exit 0
