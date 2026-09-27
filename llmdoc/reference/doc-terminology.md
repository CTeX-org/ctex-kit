# llmdoc 用词约定

根 `CLAUDE.md` 的「语言约定」列出了不要用的词和总体原则。本文只记录它没有写明、但在 #1093 全库修订中已经定下来的替换决定，供以后写文档时直接沿用。

## 已定下来的替换

| 概念 | 写法 | 不写 |
|---|---|---|
| contract（契约测试、行为约定） | 契约、契约测试 | 合同、合同测试 |
| CI 上拦截 PR 的 gate | PR 检查、CI 检查、校验 | 门禁、闸门 |
| 代码里决定是否执行某段逻辑的条件 | 条件判断、判断条件、由 …… 控制是否执行 | 门控 |
| TeX box | 盒子、外层盒子、片段盒子、盒子宽度、盒子内部 | 盒、父盒、盒尾、盒内、盒宽 |
| 测试对缺陷无区分能力 | 没有判别力 | 零判别力 |
| 反思末尾“哪些内容值得写进稳定文档”的小节 | `## 可写入稳定文档的内容`，条目标“已写入” | 促进候选、已促进 |
| 同一规律再次出现 | 再次出现、又一个实例 | 发作、镜面发作 |
| 统计口径 | 统计方式、计数方式、说法 | 口径 |
| 具体数目 | 确切数字 | 确数 |
| 否定一个结论 | 推翻、否定 | 证否 |
| 过程中的错误 | 问题、容易出错的地方、失误 | 坑、踩坑 |
| 失败的表现 | 失败方式；其他语境写写法、形式 | 形态 |

引用原文（例如他人注释的原话）和删除线里撤回的原话保持原样，不按上表替换。

“真分支”“为真”“置真”等表示逻辑真值的说法保留；只有“真跑”“真回写”这类用“真”强行强调的写法需要改。

## 纯措辞修改的检查方法

纯措辞修改不应改变行内代码、`[[wiki 链接]]` 和 Markdown 链接目标。检查方法是逐文件比对 `git show HEAD:<file>` 与工作区版本中这三类片段的排序后集合，再运行 `git diff --check`。

行内代码不能用 `` `[^`]+` `` 这类只认单个反引号的正则提取：遇到 ``` `` \` `` ``` 这类用多个反引号包住、内容本身含反引号的行内代码，它会配错对，产生大量误报。下面的脚本按行扫描，按 CommonMark 规则配对：n 个反引号开头、同样 n 个反引号结尾，两端都不紧邻其他反引号。在仓库根目录运行 `python3 - [基准提交] <<'PY'`，粘贴脚本后以 `PY` 结束；不给基准提交时与 `HEAD` 比对。

```python
import re, subprocess, sys
from collections import Counter

CODE = re.compile(r'(?<!`)(`+)(?!`)(.+?)(?<!`)\1(?!`)')
WIKI = re.compile(r'\[\[[^\]]+\]\]')
LINK = re.compile(r'\]\([^)]+\)')

def pieces(text):
    out = []
    for line in text.splitlines():
        out += [m.group(0) for m in CODE.finditer(line)]
        out += WIKI.findall(line) + LINK.findall(line)
    return Counter(out)

base = sys.argv[1] if len(sys.argv) > 1 else 'HEAD'
files = subprocess.run(['git', 'diff', '--name-only', base, '--', 'llmdoc'],
                       capture_output=True, text=True, check=True).stdout.split()
for f in files:
    if not f.endswith('.md'):
        continue
    old = subprocess.run(['git', 'show', f'{base}:{f}'], capture_output=True, text=True)
    if old.returncode != 0:
        print(f'new file: {f}')
        continue
    try:
        new = open(f, encoding='utf-8').read()
    except FileNotFoundError:
        print(f'deleted: {f}')
        continue
    a, b = pieces(old.stdout), pieces(new)
    if a != b:
        print(f'changed: {f}')
        for s in sorted((a - b).elements()):
            print(f'  - {s}')
        for s in sorted((b - a).elements()):
            print(f'  + {s}')
```

脚本逐项列出消失（`-`）和新增（`+`）的片段，有差异的地方要逐处确认是否是有意修改。脚本不区分围栏代码块，改动代码块本身时，块内的反引号片段也会出现在差异里。在提交 `98eca332` 上实测，旧正则报出 15 行差异，这个脚本只报出 3 处有意修改。

标题或被转述的原句改名后，要用**完整的旧文本**在全库精确匹配，检查旧文本是否仍被引用（例如其他文档里用「」转述这个标题的地方），并同步修改。不要用前缀匹配：新标题通常保留了旧标题的开头，前缀会命中新标题自身，结果全是误报。

来源：[[1093-llmdoc-wording-cleanup]]、[[xpinyin-maintaining-rebase-wording-unihan18]]。
