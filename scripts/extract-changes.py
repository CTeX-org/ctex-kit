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


# 辅助函数：将文本转换为 Markdown 行内代码，自动处理内部的反引号（`）以防语法冲突
def to_inline_code(s: str) -> str:
    if '`' not in s:
        return f"`{s}`"
    # 计算内部最大连续反引号的数量
    max_ticks = max(len(t) for t in re.findall(r'`+', s))
    delimiter = '`' * (max_ticks + 1)
    # 如果开头或结尾本身就是反引号，按照 Markdown 规范需补一个空格保护
    start_space = ' ' if s.startswith('`') else ''
    end_space = ' ' if s.endswith('`') else ''
    return f"{delimiter}{start_space}{s}{end_space}{delimiter}"

# 从 dtx 中抽取指定版本的 \changes 条目，返回字符串列表
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
        # 先把续行拼接成完整逻辑行, 再抽第三个 {} 的内容: \changes 的
        # 版本/日期与正文可能分行书写 (dtx 常见折行风格, 如
        # `% \changes{v3.10.2}{2026/07/05}` + `% {正文...}`), 不能要求
        # 三个 { 都出现在 tag 所在的物理行上.
        # 续行: 以 `% ` 开头, 且不开新的 \changes / macrocode block.
        text = line.rstrip("\n")
        i += 1
        while (
            i < len(lines)
            and re.match(r"^%\s+\S", lines[i])
            and "\\changes{" not in lines[i]
            and "\\begin{" not in lines[i]
        ):
            text += " " + lines[i].lstrip("% ").rstrip("\n")
            i += 1
        m = re.search(r"\\changes\{[^}]*\}\s*\{[^}]*\}\s*\{", text)
        if not m:
            continue
        text = text[m.end():]
        # 用花括号深度匹配剥掉结尾 }, 容忍 text 内的嵌套 {}.
        depth = 1
        result: list[str] = []
        # 跳过 LaTeX 转义 \{ 和 \}，避免增减 depth
        idx = 0
        while idx < len(text):
            ch = text[idx]
            if ch == "\\":
                # 如果是检测到 \{ 或 \}，作为整体存入，不改变花括号深度
                if idx + 1 < len(text) and text[idx + 1] in ("{", "}"):
                    result.append(ch)
                    result.append(text[idx + 1])
                    idx += 2
                    continue
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    break
            result.append(ch)
            idx += 1
        text = "".join(result)
        text = re.sub(r"\s+", " ", text).strip()
        # 消除 CJK 字符及标点之间因换行引入的冗余空格
        text = re.sub(
            r"([\u4e00-\u9fff\u3000-\u303f\uff00-\uffef\u2014\u2026])"
            r"\s+(?=[\u4e00-\u9fff\u3000-\u303f\uff00-\uffef\u2014\u2026])",
            r"\1", text)
        # 抽取并保护数学公式环境 $...$, 防止其中的特殊命令被后续的 Markdown 转换规则误伤
        math_blocks = []
        def _save_math(m):
            block = m.group(0)
            # 洗练数学环境内部的特殊命令：剥离 \texttt 并将
            # \textbackslash 规范化为 \backslash
            block = re.sub(r"\\texttt\{((?:\\.|[^}])*)\}", r"\1", block)
            block = block.replace(r"\textbackslash", r"\backslash")
            math_blocks.append(block)
            return f"\x02{len(math_blocks) - 1}\x03"
        text = re.sub(r"\$(?:\\\$|[^$])+\$", _save_math, text)
        # 使用 (?:\\.|[^}])*，使其能够安全匹配包含 \} 的命令参数
        # \cs / \tn → `\<name>` (先用 \x00..\x01 临时占位, 避开后面 \\
        # 命令通杀正则把 \cs 自己也吃掉).
        text = re.sub(r"\\(?:cs|tn)\{((?:\\.|[^}])*)\}",
                      lambda m: "\x00" + m.group(1) + "\x01", text)
        # 抽取并保护 shortvrb 的 |...|、"..." 以及 \texttt{...} 环境,
        # 防止其中的原生命令被后续的宏清理正则误伤
        verbatim_blocks = []
        def _save_verbatim(m):
            content = m.group(1)
            # 还原 \textbackslash 并自动吃掉后面因 TeX 宏特性而产生的多余空格
            content = re.sub(r"\\textbackslash\s*", "\\\\", content)
            # 清理代码块内部因配合 TeX 编译环境而残留的字符转义符（如 \& -> &）
            content = re.sub(r"\\([&%#{}])", r"\1", content)
            verbatim_blocks.append(content)
            return f"\x04{len(verbatim_blocks) - 1}\x05"
        text = re.sub(r"\|([^|]+)\|", _save_verbatim, text)
        text = re.sub(r'"([^"]+)"', _save_verbatim, text)
        text = re.sub(r"\\texttt\{((?:\\.|[^}])*)\}", _save_verbatim, text)
        # 转换为 md 行内代码，并增加对潜在内部反引号的防御
        text = re.sub(r"\\(?:pkg|cls|file|env)\{((?:\\.|[^}])*)\}",
                      lambda m: to_inline_code(m.group(1)), text)
        # 处理 \opt 中可能出现的 !=
        text = re.sub(r"\\opt\{((?:\\.|[^}])*?)!=((?:\\.|[^}])*?)\}",
                      lambda m: to_inline_code(f"{m.group(1)} = {m.group(2)}"),
                      text)
        text = re.sub(r"\\opt\{((?:\\.|[^}])*)\}",
                      lambda m: to_inline_code(m.group(1)),   text)
        text = re.sub(r"\\textbf\{((?:\\.|[^}])*)\}", r"**\1**", text)
        text = re.sub(r"\\#", "#", text)
        # 将残留的 LaTeX 转义 `\{` 和 `\}` 还原为 md 里的常规 `{` 和 `}`
        text = re.sub(r"\\\{", "{", text)
        text = re.sub(r"\\\}", "}", text)
        # LaTeX 系列 logo 命令的常见形态: \LaTeX, \LaTeX\<space>, \LaTeX{}.
        text = re.sub(r"\\LaTeXe(?:\\\s|\{\})?", "LaTeX2e ", text)
        text = re.sub(r"\\LaTeXiii(?:\\\s|\{\})?", "LaTeX3 ", text)
        text = re.sub(r"\\LaTeX3(?:\\\s|\{\})?", "LaTeX3 ", text)
        text = re.sub(r"\\XeLaTeX(?:\\\s|\{\})?", "XeLaTeX ", text)
        text = re.sub(r"\\LuaLaTeX(?:\\\s|\{\})?", "LuaLaTeX ", text)
        text = re.sub(r"\\pdfLaTeX(?:\\\s|\{\})?", "pdfLaTeX ", text)
        text = re.sub(r"\\upLaTeX(?:\\\s|\{\})?", "upLaTeX ", text)
        text = re.sub(r"\\ApLaTeX(?:\\\s|\{\})?", "ApLaTeX ", text)
        text = re.sub(r"\\pLaTeX(?:\\\s|\{\})?", "pLaTeX ", text)
        text = re.sub(r"\\LaTeX(?:\\\s|\{\})?", "LaTeX ", text)
        text = re.sub(r"\\XeTeX(?:\\\s|\{\})?", "XeTeX ", text)
        text = re.sub(r"\\LuaTeX(?:\\\s|\{\})?", "LuaTeX ", text)
        text = re.sub(r"\\pdfTeX(?:\\\s|\{\})?", "pdfTeX ", text)
        text = re.sub(r"\\upTeX(?:\\\s|\{\})?", "upTeX ", text)
        text = re.sub(r"\\ApTeX(?:\\\s|\{\})?", "ApTeX ", text)
        text = re.sub(r"\\pTeX(?:\\\s|\{\})?", "pTeX ", text)
        text = re.sub(r"\\TeX(?:\\\s|\{\})?", "TeX ", text)
        # 余下的 \xxx / \xxx{} 一律剥掉
        # (\changes 里其他命令通常是引用类, 直接去掉名字不影响信息量).
        text = re.sub(r"\\[A-Za-z]+(?:\{\})?\s*", "", text)
        # 杂项: \<space> 当 inter-word, ~ 当 non-break space, 多空格压一.
        # 修改位置: 移到占位符还原动作之前, 防止洗掉已经还原出的
        # Markdown 行内代码内部的反斜杠与空格
        text = re.sub(r"\\\s", " ", text)
        text = text.replace("~", " ")
        text = re.sub(r"  +", " ", text).strip()
        # 安全还原数学公式环境 $...$ 到清洗完毕后的逻辑文本中
        text = re.sub(r"\x02(\d+)\x03",
                      lambda m: math_blocks[int(m.group(1))], text)
        # 合并并还原连续的 \cs / \tn / \texttt / shortvrb
        # 占位符为单一的 Markdown 行内代码块
        def _restore_combined_code(m):
            pieces = []
            # 迭代找出该连续块中的每一个代码占位符，恢复出对应的原始文本片段
            for sm in re.finditer(r"\x00([^\x01]*)\x01|\x04(\d+)\x05",
                                  m.group(0)):
                if sm.group(1) is not None:
                    pieces.append("\\" + sm.group(1))
                else:
                    pieces.append(verbatim_blocks[int(sm.group(2))])
            return to_inline_code("".join(pieces))
        # 匹配一段或多段连续挨在一起的 \x00...\x01 或 \x04...\x05 占位符
        text = re.sub(r"(?:\x00[^\x01]*\x01|\x04\d+\x05)+",
                      _restore_combined_code, text)
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
