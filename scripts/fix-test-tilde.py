#!/usr/bin/env python3
"""scripts/fix-test-tilde.py — 修 .lvt 文件中 \\TEST/\\BEGINTEST/\\TYPE 命令
大括号里的 `~` 误用 (#893).

策略 (与 .githooks/check-test-tilde.sh 对称):
  - 扫所有 .lvt
  - 维护 group-depth-aware 的 \\ExplSyntax 状态机:
      * 状态切换只在 file-level top scope (depth == 0) 生效
      * depth > 0 时即便看到 \\ExplSyntaxOff 也是 group 内局部切换, 出 group
        自动恢复, 状态机不跟. 正确处理
        \\sys_if_engine_luatex:F { \\ExplSyntaxOff ... } 这种 expl3 group
        内的局部 catcode 切换 (例 ctex/test/testfiles/verb01.lvt)
  - 仅在 ExplSyntaxOff 状态下, 把 \\TEST/\\BEGINTEST/\\TYPE 大括号里的
    `~` 替换为空格. ExplSyntaxOn 段内 `~` 是合法 expl3 空格 (catcode 10),
    不动 (改成普通空格反而被 ignore, 例 zhnumber/testfiles/basic01.lvt)

为何用状态机而非"以 .tlg 为 oracle":
  - .tlg 只记录实际执行到的输出. 死代码路径 (例 \\showbox 中断后的代码)
    / 未触发的 \\if 分支不出 .tlg, oracle 漏检
    (例 xeCJK/testfiles/fntef-nest01.lvt 第 24/32 行)
  - hook 与 fix 必须对称: hook 报告的命中就该是 fix 处理的命中

为何不顺手改 .tlg:
  - 字面 `~` 在 .tlg 里**可能来自其它命令** (例 ctex 的
    \\ctexset{section/name = {Section~}} 用户故意用 `~` 作 nobreakspace,
    .tlg 输出 `Section~2` 是正确的, 不该改)
  - 改 .lvt 后由 maintainer 跑 `l3build save` 重 baseline, 让 LaTeX 自己
    决定 .tlg 内容. 这是唯一不会误伤的办法.

边界情况:
  - GBK / iso-8859-1 编码的 .lvt (例 ctex/.../hyperref-pdfstringdef0[23].lvt)
    用 bytes 模式处理. \\TEST/\\BEGINTEST/\\TYPE/\\ExplSyntax 全是 ASCII,
    在任何编码下字节一致, 正则匹配安全.

用法: 在仓库根跑 python3 scripts/fix-test-tilde.py
"""

import re
import subprocess
from pathlib import Path

# 匹配 \TEST/\BEGINTEST/\TYPE { ...~... } (允许命令后空格).
CMD_PATTERN = re.compile(
    rb"(\\(?:TEST|BEGINTEST|TYPE)\s*)\{([^{}]*~[^{}]*)\}"
)

# \ExplSyntaxOn/Off 检测, 后跟非字母字符或行尾, 防 \ExplSyntaxOnDemand 误匹配.
EXPL_ON  = re.compile(rb"\\ExplSyntaxOn(?:[^a-zA-Z]|$)")
EXPL_OFF = re.compile(rb"\\ExplSyntaxOff(?:[^a-zA-Z]|$)")


def _strip_tex_comment(line: bytes) -> bytes:
    """剥掉 TeX 注释 — 第一个非转义 `%` 之后的内容.

    转义判定: `%` 前面**连续**的反斜杠数为奇数才是 \\% 转义. `\\\\%` 是
    "字面反斜杠 + 注释开始", 前面 2 个 `\\` 互为转义对, `%` 本身**不**
    被转义, 应当作注释起点."""
    i = 0
    while i < len(line):
        if line[i:i+1] == b"%":
            # 数 i 前面连续的 `\` 个数
            bs = 0
            j = i - 1
            while j >= 0 and line[j:j+1] == b"\\":
                bs += 1
                j -= 1
            if bs % 2 == 0:
                return line[:i]
        i += 1
    return line


def _replace_tildes_in_match(m: "re.Match[bytes]") -> bytes:
    """\\TEST/\\BEGINTEST/\\TYPE 命中里把 body 中的 `~` 替换为空格."""
    head, body = m.group(1), m.group(2)
    new_body = body.replace(b"~", b" ")
    return head + b"{" + new_body + b"}"


def fix_lvt(path: Path) -> int:
    """改 .lvt: 用 group-depth-aware 状态机判定, 仅 ExplSyntaxOff 段内的
    \\TEST/\\BEGINTEST/\\TYPE 大括号内 `~` 替换为空格. 返回替换次数.

    简化假设: 状态机按整行判定 — 同一行同时出现 \\ExplSyntaxOff 和
    \\TEST{...} 时, 该行的 state 是该行 ExplSyntax 切换**之后**的状态.
    实际 .lvt 不会这么混杂写, 这条记录是为未来注意."""
    data = path.read_bytes()
    out_lines = []
    state = "off"
    depth = 0
    changes = 0

    for line in data.splitlines(keepends=True):
        # 状态切换与 depth 更新都基于剥掉 TeX 注释后的内容, 否则 `% }`
        # 或 `% \ExplSyntaxOff` 这种字面字符会误算.
        stripped = _strip_tex_comment(line)

        # 状态切换只在 file-level top scope (depth == 0) 生效. depth > 0
        # 时即便看到 \ExplSyntaxOff 也是某 group 内局部切换, 出 group 自动
        # 恢复, 状态机不该跟.
        if depth == 0:
            if EXPL_ON.search(stripped):
                state = "on"
            if EXPL_OFF.search(stripped):
                state = "off"

        if state == "off":
            new_line, n = CMD_PATTERN.subn(_replace_tildes_in_match, line)
            changes += n
            out_lines.append(new_line)
        else:
            out_lines.append(line)

        # 更新 depth 留给下一行用 (基于 stripped, 避免 `% {` 影响)
        depth += stripped.count(b"{") - stripped.count(b"}")

    if changes:
        path.write_bytes(b"".join(out_lines))
    return changes


def find_lvts(repo: Path) -> list[Path]:
    out = []
    for p in repo.rglob("*.lvt"):
        # 用 path parts 而非子串匹配, 避免 rebuild/ 等被误过滤
        if "build" in p.parts:
            continue
        out.append(p)
    return out


def main():
    repo = Path(
        subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"], text=True
        ).strip()
    )

    modified = []
    for lvt in sorted(find_lvts(repo)):
        n = fix_lvt(lvt)
        if n:
            modified.append((lvt.relative_to(repo), n))

    if not modified:
        print("Nothing to fix.")
        return

    pkgs = sorted({str(f).split("/")[0] for f, _ in modified})
    print(
        f"Modified {len(modified)} .lvt files "
        f"({sum(n for _, n in modified)} substitutions)"
    )
    for f, n in modified:
        print(f"  {f}  ({n} subs)")
    print()
    print("Next steps:")
    for pkg in pkgs:
        print(f"  cd {pkg} && l3build save && l3build check   # 重 baseline + 验证")


if __name__ == "__main__":
    main()

