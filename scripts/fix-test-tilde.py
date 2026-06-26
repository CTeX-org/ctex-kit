#!/usr/bin/env python3
"""scripts/fix-test-tilde.py — 修 .lvt 文件中 \\TEST/\\BEGINTEST/\\TYPE 命令
大括号里的 `~` 误用 (#893).

策略 (用 .tlg 作 oracle):
  - .tlg 是 LaTeX 自己输出的 baseline; 里面字面 `~` = 该位置的 `~` 在
    LaTeX/expl3 catcode 求值后是 active char (不可断空格), 即 #893 想
    清掉的形态.
  - .tlg 不含字面 `~` = 该 .lvt 里所有 `~` 都没产生 active 输出
    (要么在 expl3 group 里被当 space, 要么没被执行).
  - 因此: 仅修改**对应 .tlg 含字面 `~`** 的 .lvt 文件, 把它所有
    \\TYPE/\\TEST/\\BEGINTEST 大括号里的 `~` 换为空格. 同时把 .tlg 里
    所有的 `~` 也换为空格 (.tlg 是文本, 字面替换直观无歧义).

为何这样**比写状态机靠谱**:
  - 不用判断 \\ExplSyntaxOn/Off 段
  - 不用追踪 group 嵌套
  - 不用区分 catcode
  - LaTeX 已经把 catcode 求过值, 字面结果就在 .tlg, 这是 ground truth

边界情况:
  - 多 engine 测试 (xeCJK.luatex.tlg / .pdftex.tlg / .uptex.tlg) 等都同时
    处理 (它们都从同一 .lvt 跑出, 字符一致).
  - .lvt 与 .tlg 文件名一一对应 (basename 相同, 后缀不同).

用法: 在仓库根跑 python3 scripts/fix-test-tilde.py
"""

import re
import subprocess
from pathlib import Path

# 匹配 .tlg 里 "text~text" 形态: `~` 两侧都是字母数字 / 常见标点 ASCII
# 这种"文本字符". 关键是要排除 LaTeX font tracing 的 ".../12.045/76 ~"
# (前面是空格 / 行末) 与 line-end 空 `~` — 那些 `~` 不源自 \TYPE/\TEST.
#
# `=` 必须在范围内因 `\TYPE{key~=~value}` 是常见模式 (verb01.luatex.tlg).
TLG_TEXT_TILDE = re.compile(rb"[a-zA-Z0-9):,;.][~]+[=a-zA-Z0-9(]")

# 匹配 \TEST/\BEGINTEST/\TYPE { ...~... } (允许命令后空格).
# 用 bytes 因仓库有 GBK 编码 .lvt; ASCII 命令在任何编码下字节一致.
CMD_PATTERN = re.compile(
    rb"(\\(?:TEST|BEGINTEST|TYPE)\s*)\{([^{}]*~[^{}]*)\}"
)


def find_tlg_with_text_tilde(repo: Path) -> list[Path]:
    """找所有含 'text~text' 的 .tlg (排除 build 目录, 排除 LaTeX trace 中
    的孤立 ~)."""
    out = []
    for p in repo.rglob("*.tlg"):
        if "build/" in str(p):
            continue
        try:
            if TLG_TEXT_TILDE.search(p.read_bytes()):
                out.append(p)
        except OSError:
            pass
    return out


def tlg_to_lvt(tlg: Path) -> Path:
    """从 .tlg 路径推 .lvt 路径. 处理 multi-engine 的 *.<engine>.tlg.

    e.g. ctex/test/testfiles/foo.luatex.tlg → foo.lvt
         xeCJK/testfiles/bar.tlg            → bar.lvt
    """
    name = tlg.name
    # 剥多 engine 后缀
    for eng in (".luatex", ".pdftex", ".uptex", ".xetex"):
        if name.endswith(eng + ".tlg"):
            stem = name[: -len(eng + ".tlg")]
            break
    else:
        stem = name[: -len(".tlg")]
    return tlg.parent / (stem + ".lvt")


def fix_lvt(path: Path) -> int:
    """改 .lvt: \\TEST/\\BEGINTEST/\\TYPE 大括号内 `~` → 空格. 返回替换次数."""
    data = path.read_bytes()
    changes = 0

    def _sub(m):
        nonlocal changes
        head, body = m.group(1), m.group(2)
        new_body = body.replace(b"~", b" ")
        changes += 1
        return head + b"{" + new_body + b"}"

    new_data = CMD_PATTERN.sub(_sub, data)
    if changes:
        path.write_bytes(new_data)
    return changes


def fix_tlg(path: Path) -> int:
    """改 .tlg: 仅替换 'text~text' 形态的 `~` 为空格 (与 oracle 一致, 不动
    LaTeX trace 里的孤立 `~`). 返回替换次数."""
    data = path.read_bytes()
    n = 0

    def _sub(m):
        nonlocal n
        s = m.group(0)
        n += s.count(b"~")
        return s.replace(b"~", b" ")

    new_data = TLG_TEXT_TILDE.sub(_sub, data)
    if n:
        path.write_bytes(new_data)
    return n


def main():
    repo = Path(
        subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"], text=True
        ).strip()
    )

    tlgs = find_tlg_with_text_tilde(repo)
    if not tlgs:
        print("No .tlg files contain text-surrounded `~`. Nothing to do.")
        return

    # .tlg -> .lvt; .lvt 去重
    lvt_set = set()
    for t in tlgs:
        lvt = tlg_to_lvt(t)
        if lvt.exists():
            lvt_set.add(lvt)

    modified_lvt = []
    for lvt in sorted(lvt_set):
        n = fix_lvt(lvt)
        if n:
            modified_lvt.append((lvt.relative_to(repo), n))

    modified_tlg = []
    for tlg in sorted(tlgs):
        n = fix_tlg(tlg)
        if n:
            modified_tlg.append((tlg.relative_to(repo), n))

    print(
        f"Modified {len(modified_lvt)} .lvt files "
        f"({sum(n for _, n in modified_lvt)} substitutions)"
    )
    for f, n in modified_lvt:
        print(f"  {f}  ({n} subs)")
    print()
    print(
        f"Modified {len(modified_tlg)} .tlg files "
        f"({sum(n for _, n in modified_tlg)} substitutions)"
    )
    for f, n in modified_tlg:
        print(f"  {f}  ({n} subs)")
    print()
    print("Next steps:")
    print("  cd <pkg> && l3build check   # 验证 .lvt 和 .tlg 同步; 应当 0 diff")


if __name__ == "__main__":
    main()
