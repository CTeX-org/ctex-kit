#!/usr/bin/env python3
"""Extract \\changes{v<ver>}{...}{...} entries from .dtx files and emit
markdown bullet list to stdout.

Usage:
    extract-changes.py <dtx_path> <version_with_v_prefix>

Example:
    extract-changes.py xeCJK/xeCJK.dtx v3.10.0
    extract-changes.py ctex/*.dtx v3.10.0

设计意图: release.yml 用它生成 GH Release body, release-ctan-upload.yml
用它生成 CTAN announcement 的事实材料 (不再让 LLM 直接读 \\changes,
避免 LLM 凭空脑补 release notes 里没有的变更, zhlineskip-v1.0f 就是这
样多写出 split env 修复 / LaTeX3 重写两段不存在的内容).

LaTeX 命令清洗规则与 release.yml 之前内联的 Python 完全一致.
"""
import glob, os, re, sys


def extract(dtx_path: str, target_ver: str) -> list[str]:
    # 显式指定 utf-8: 不依赖 locale.getpreferredencoding(). GH Actions
    # Ubuntu runner 默认是 UTF-8, 但本地调试 / 别的 runner 不一定. dtx
    # 偶发的损坏字节走 errors="replace" 不阻塞抽取.
    with open(dtx_path, encoding="utf-8", errors="replace") as f:
        lines = f.readlines()

    tag = "\\changes{" + target_ver + "}"
    entries: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if tag not in line:
            i += 1
            continue
        # 抽 \changes{v<ver>}{<date>}{<text...>} 的第三个 {} 内容.
        m = re.search(r"\\changes\{[^}]*\}\{[^}]*\}\{", line)
        if not m:
            i += 1
            continue
        text = line[m.end():]
        # 续行: 以 `% ` 开头, 且不开新的 \changes / macrocode block.
        i += 1
        while (
            i < len(lines)
            and re.match(r"^%\s+\S", lines[i])
            and "\\changes{" not in lines[i]
            and "\\begin{" not in lines[i]
        ):
            text += " " + lines[i].lstrip("% ").rstrip("\n")
            i += 1
        # 用花括号深度匹配剥掉结尾 }, 容忍 text 内的嵌套 {}.
        depth = 1
        result: list[str] = []
        for ch in text:
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    break
            result.append(ch)
        text = "".join(result)
        text = re.sub(r"\s+", " ", text).strip()
        # \cs / \tn → `\<name>` (先用 \x00..\x01 临时占位, 避开后面 \\
        # 命令通杀正则把 \cs 自己也吃掉).
        text = re.sub(r"\\(?:cs|tn)\{([^}]*)\}", lambda m: "\x00" + m.group(1) + "\x01", text)
        text = re.sub(r"\\(?:opt|pkg|cls|file|texttt)\{([^}]*)\}", r"`\1`", text)
        text = re.sub(r"\\textbf\{([^}]*)\}", r"**\1**", text)
        text = re.sub(r"\\#", "#", text)
        # LaTeX 系列 logo 命令的常见形态: \LaTeX, \LaTeX\<space>, \LaTeX{}.
        text = re.sub(r"\\LaTeXe(?:\\\s|\{\})?", "LaTeX2e ", text)
        text = re.sub(r"\\LaTeXiii(?:\\\s|\{\})?", "LaTeX3 ", text)
        text = re.sub(r"\\XeLaTeX(?:\\\s|\{\})?", "XeLaTeX ", text)
        text = re.sub(r"\\LuaLaTeX(?:\\\s|\{\})?", "LuaLaTeX ", text)
        text = re.sub(r"\\pdfLaTeX(?:\\\s|\{\})?", "pdfLaTeX ", text)
        text = re.sub(r"\\upLaTeX(?:\\\s|\{\})?", "upLaTeX ", text)
        text = re.sub(r"\\LaTeX(?:\\\s|\{\})?", "LaTeX ", text)
        text = re.sub(r"\\XeTeX(?:\\\s|\{\})?", "XeTeX ", text)
        text = re.sub(r"\\LuaTeX(?:\\\s|\{\})?", "LuaTeX ", text)
        text = re.sub(r"\\pdfTeX(?:\\\s|\{\})?", "pdfTeX ", text)
        text = re.sub(r"\\upTeX(?:\\\s|\{\})?", "upTeX ", text)
        text = re.sub(r"\\TeX(?:\\\s|\{\})?", "TeX ", text)
        # 余下的 \xxx / \xxx{} 一律剥掉 (\changes 里其他命令通常是引用类,
        # 直接去掉名字不影响信息量).
        text = re.sub(r"\\[A-Za-z]+(?:\{\})?\s*", "", text)
        # 还原 \cs / \tn 占位符 → `\<name>`.
        text = re.sub(r"\x00(.*?)\x01", r"`\\\1`", text)
        # 杂项: \<space> 当 inter-word, ~ 当 non-break space, 多空格压一.
        text = re.sub(r"\\\s", " ", text)
        text = text.replace("~", " ")
        text = re.sub(r"  +", " ", text).strip()
        if text:
            entries.append(text)
    return entries


def main() -> int:
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <dtx_path...> <version>", file=sys.stderr)
        return 2

    target_ver, path_patterns = sys.argv[-1], sys.argv[1:-1]
    dtx_files: list[str] = []
    for pattern in path_patterns:
        matches = glob.glob(pattern)
        dtx_files.extend(sorted(matches))
    global_seen: set[str] = set()

    for file in dtx_files:
        if os.path.isfile(file):
            entries = extract(file, target_ver)
            for e in entries:
                if e not in global_seen:
                    global_seen.add(e)
                    print(f"- {e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
