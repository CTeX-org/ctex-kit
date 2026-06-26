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


def fix_lvt(path: Path) -> int:
    """改 .lvt: 用 group-depth-aware 状态机判定, 仅 ExplSyntaxOff 段内的
    \\TEST/\\BEGINTEST/\\TYPE 大括号内 `~` 替换为空格. 返回替换次数."""
    data = path.read_bytes()
    out_lines = []
    state = b"off"
    depth = 0
    changes = 0

    for line in data.splitlines(keepends=True):
        # 状态切换只在 file-level top scope (depth == 0) 生效. depth > 0
        # 时即便看到 \ExplSyntaxOff 也是某 group 内局部切换, 出 group 自动
        # 恢复, 状态机不该跟.
        if depth == 0:
            if EXPL_ON.search(line):
                state = b"on"
            if EXPL_OFF.search(line):
                state = b"off"

        if state == b"off":
            def _sub(m):
                nonlocal changes
                head, body = m.group(1), m.group(2)
                new_body = body.replace(b"~", b" ")
                changes += 1
                return head + b"{" + new_body + b"}"

            new_line = CMD_PATTERN.sub(_sub, line)
            out_lines.append(new_line)
        else:
            out_lines.append(line)

        # 更新 depth 留给下一行用
        depth += line.count(b"{") - line.count(b"}")

    if changes:
        path.write_bytes(b"".join(out_lines))
    return changes


def find_lvts(repo: Path) -> list[Path]:
    out = []
    for p in repo.rglob("*.lvt"):
        if "build/" in str(p):
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

