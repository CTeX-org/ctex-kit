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
      if (match($0, /\\(TEST|BEGINTEST|TYPE)[[:space:]]*\{[^}]*~[^}]*\}/)) {
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

# Step 2 + 3: 对每个候选, 判断是否在 ExplSyntaxOff 段, 仅报 Off 段
declare -A explsyntax_cache
offending=""
n=0
while IFS=$'\t' read -r file lineno line; do
  [ -z "$file" ] && continue

  # 缓存每个文件的 line→state 表
  if [ -z "${explsyntax_cache[$file]:-}" ]; then
    if [ ! -f "$file" ]; then
      # 文件可能被删除, 跳过
      continue
    fi
    explsyntax_cache[$file]=$(awk '
      BEGIN { state = "off"; depth = 0 }
      # awk (POSIX) 不支持 \b 字符级锚, 用 [^a-zA-Z] 替代防止前缀
      # 误匹配 (e.g. \ExplSyntaxOnDemand).
      #
      # 状态切换只在 file-level top scope (depth == 0) 生效. depth>0
      # 时即便看到 \ExplSyntaxOff 也是某个 group 内局部切换, 出 group
      # 后自动恢复, 字面状态机不该跟. 这能正确处理
      # \sys_if_engine_luatex:F { \ExplSyntaxOff ... } 这种 expl3
      # group 内的局部 catcode 切换.
      {
        if ($0 ~ /\\ExplSyntaxOn([^a-zA-Z]|$)/  && depth == 0) state = "on"
        if ($0 ~ /\\ExplSyntaxOff([^a-zA-Z]|$)/ && depth == 0) state = "off"
        print NR "\t" state
        # 数本行净的 {/} 差, 更新 depth (留到下一行使用)
        sline = $0
        o = 0; while (match(sline, /\{/)) { o++; sline = substr(sline, RSTART+1) }
        sline = $0
        c = 0; while (match(sline, /\}/)) { c++; sline = substr(sline, RSTART+1) }
        depth = depth + o - c
      }
    ' "$file")
  fi

  # 查 lineno 对应的 state
  state=$(echo "${explsyntax_cache[$file]}" | awk -F'\t' -v ln="$lineno" '$1 == ln { print $2; exit }')

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
