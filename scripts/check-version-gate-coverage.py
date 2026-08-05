#!/usr/bin/env python3
"""对账「哪些包该被版本校验覆盖」与「哪些包实际被覆盖」。

为什么需要这个脚本
------------------
`check-tag.yml` 用 `paths` 列包、`release.yml` 用 `case` 列包，两处都是**白名单**：
没被列进去的包静默走过，`release.yml` 甚至只打一条 `::notice::...跳过三方校验`
——notice 不是 failure，CI 全绿，没人会去读。

这个失效模式已经发生过两次：

* #1041：xeCJK 从未被覆盖，发 `v3.10.5-rc2` 时 `.dtx` 仍写 `3.10.4`，打出的包
  自报 v3.10.4 而 git tag 是 v3.10.5，两道校验都没拦住。
* 本次：zhnumber 与 xCJK2uni 同样从未被覆盖，而两者的 `.dtx` 都有
  `{\\ExplFileDate}{<ver>}`、`l3build tag` 确实会回写——那条「不使用 l3build tag
  版本 stamp 机制」的 notice 是**错的**。

#1041 的反思里已经写下「白名单式校验应当有一条未覆盖清单的对账机制」，当时留作
后续。同一个缺口出现第二次之后补上。

判据
----
一个包「应当被版本校验覆盖」的判据是**它的 `.dtx` 里有 `l3build tag` 会回写的
版本槽位**，即下面任一种写法：

* `{\\ExplFileDate}{<ver>}`（共享 `update_tag`，见 `support/build-config.lua`）
* `$Id: <file> <ver> ...$`（ctex / zhlineskip 在各自 `build.lua` 里覆写 update_tag）

注意判据是「有没有版本槽位」，不是「有没有 release tag」或「有没有 version 字段」：
后两者都是可以补的，而前者决定了「忘同步会不会发出错版的包」。

已知边界（纯文本对账查不到的）
------------------------------
本脚本只核对「该包有没有出现在这几个位置」，不理解 job 的语义。以下情形它**不会**
报错，别把它当成完备的守卫：

* `tag-<pkg>` job 存在但里面跑的不是 `l3build tag`（例如被改成 `echo skip`）；
* 该 job 的 `if:` 条件指向了别的包的 output；
* 汇总 job 的 `needs` 或 `env` 里漏了某个包（那会让它的失败不影响总状态）。

这些属于「job 存在但被掏空」，需要 review 时人眼核对。之所以不进一步做语义检查：
再往下就要解析 shell 与表达式，脚本本身的脆弱性会超过它防住的问题——而一个会
静默失效的对账脚本比没有更糟（本脚本已经在这上面栽过两次，见 STAMP_PATTERNS 与
`release_covered()` 的注释）。

定位假设失效时本脚本**主动报错**而不是漏报：找不到 `jobs:`、找不到
`Verify version consistency` step、或扫不到任何版本槽位，都会 `sys.exit` 并说明
「本脚本假设已失效」。这条分界是有意的——把「定位失效」与「包漏覆盖」分开报，
才不会让一次正常重构静默关掉这道检查。

退出码
------
0 = 覆盖一致；1 = 存在应覆盖而未覆盖的包（或脚本自身的假设已失效）。
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHECK_TAG = ROOT / ".github/workflows/check-tag.yml"
RELEASE = ROOT / ".github/workflows/release.yml"

# `l3build tag` 会回写的**三种**版本槽位。
#
# 第三条是盲审补上的, 而漏掉它正是本脚本要防的那类错: zhmetrics 只有旧式
# `[<日期> v<版本>]` 写法, 而它**有** `zhmetrics-v*` 触发器 (能发版)、两道校验
# 都放行、初版脚本也扫不到 —— 与 #1041 的 xeCJK 完全同型.
# 实测: `cd zhmetrics && l3build tag 9.9.9` 确实回写 zhmCJK.dtx 的
# `[2026/08/05 v9.9.9 setup CJK fonts dynamically]` 一行.
#
# 判据要跟着 support/build-config.lua 的 update_tag 实际写入的位置走, 不能凭
# 印象列举. 那里当前有两条 gsub: `({\ExplFileDate})%b{}` 与
# `(%[)(%d%d%d%d/%d%d/%d%d) v([^%]%s]+)`; 加上 ctex/zhlineskip 包级覆写版改的
# `$Id:$` stamp, 一共三种.
STAMP_PATTERNS = (
    re.compile(r"\{\\ExplFileDate\}\{[^}]*\}"),
    re.compile(r"\$Id:\s*\S+\s+\S+"),
    re.compile(r"\[\d{4}/\d{2}/\d{2}\s+v[^\]\s]+"),
)


def packages_with_version_stamp() -> dict[str, list[str]]:
    """扫出所有 .dtx 里含版本槽位的包，返回 {目录名: [命中的 dtx 文件名]}。"""
    found: dict[str, list[str]] = {}
    for build_lua in sorted(ROOT.glob("*/build.lua")):
        pkg_dir = build_lua.parent
        hits = []
        for dtx in sorted(pkg_dir.glob("*.dtx")):
            text = dtx.read_text(encoding="utf-8", errors="replace")
            if any(p.search(text) for p in STAMP_PATTERNS):
                hits.append(dtx.name)
        if hits:
            found[pkg_dir.name] = hits
    return found


def check_tag_covered() -> set[str]:
    """从 check-tag.yml 读出**完整**接入的包目录名。

    一个包在这个 workflow 里要接四处, 缺任何一处都不成立, 所以取四者交集:

    1. `on.pull_request.paths` —— 决定 PR 是否触发本 workflow;
    2. `changes` job 的 `outputs:` 映射 —— 决定 filter 结果能否被下游读到;
    3. `changes` job 的 `filters` —— 决定该包的 output 是否为 true;
    4. 一个 `tag-<pkg>` job —— 真正跑 `l3build tag` 的地方。

    第 2 条是盲审补上的: 漏掉它时, 删掉 `outputs:` 里某个包的那一行 (于是
    `needs.changes.outputs.<pkg>` 恒为空、对应 tag job 永不运行) 脚本仍报绿。

    只看其中一处会漏报: `<pkg>/**` 在 (1)(2) 两段里都出现, 早期版本只用一条
    正则扫全文, 于是从 `paths` 里删掉某个包之后, `filters` 里的同名条目仍能让
    它显示为已覆盖 —— 实测确认过这个假阴性。

    job 名单独处理: 它是小写化的 (`tag-xcjk2uni` 对应 `xCJK2uni/`), 与目录名
    对不上, 所以按小写比对。
    """
    text = CHECK_TAG.read_text(encoding="utf-8")

    jobs_idx = text.find("\njobs:")
    if jobs_idx < 0:
        sys.exit(f"::error::{CHECK_TAG.name} 里找不到 'jobs:'; 本脚本假设已失效。")
    header, body = text[:jobs_idx], text[jobs_idx:]

    # (1) 触发路径: 只在 jobs: 之前的部分找。
    in_paths = set(re.findall(r"^\s+- '([^/']+)/\*\*'", header, re.MULTILINE))

    # (2) filters: 在 jobs: 之后、且缩进更深 (14 空格) 的那些条目。
    in_filters = set(re.findall(r"^\s{14}- '([^/']+)/\*\*'", body, re.MULTILINE))

    # (2) changes job 的 outputs: 映射 (键是小写的, 与 job 名同一坐标系)。
    outputs_keys = {
        m.lower()
        for m in re.findall(r"^      ([a-z0-9]+):\s*\$\{\{\s*steps\.filter\.outputs\.", body, re.MULTILINE)
    }

    # (4) tag-<pkg> job (名字是小写的)。
    job_names = {m.lower() for m in re.findall(r"^  tag-([a-z0-9]+):", body, re.MULTILINE)}

    return {
        pkg
        for pkg in (in_paths & in_filters)
        if pkg.lower() in job_names and pkg.lower() in outputs_keys
    }


def release_triggerable() -> set[str]:
    """从 release.yml 的 `on.push.tags` 里读出「能触发发版」的包目录名。

    区分「能发版」与「不能发版」是本脚本的分级依据: 没有 tag 触发器的包即便
    漏了校验也发不出错版的包 (根本发不出去), 属**潜在**缺口, 不该让 CI 硬失败 ——
    否则脚本会在一个当下无法造成事故的项上长期报红, 而长期报红的检查等于没有检查。
    """
    text = RELEASE.read_text(encoding="utf-8")
    idx = text.find("jobs:")
    header = text[: idx if idx > 0 else len(text)]
    return set(re.findall(r"^\s+- '([A-Za-z0-9-]+?)-v\*'", header, re.MULTILINE))


def release_covered() -> set[str]:
    """从 release.yml 三方校验的 case 分支里读出被覆盖的包目录名。

    只取校验那一段 (`Verify version consistency` 之后), 避免把上面 Parse tag
    的 `<pkg>-v*)` 分支也算进来 —— 那一段列的是「能触发发版的包」, 与「被校验
    的包」是两件事, 混淆的话本脚本会漏报。
    """
    text = RELEASE.read_text(encoding="utf-8")
    marker = "Verify version consistency"
    idx = text.find(marker)
    if idx < 0:
        sys.exit(
            f"::error::{RELEASE.name} 里找不到 '{marker}' 步骤; "
            "本脚本的定位假设已失效, 请同步更新。"
        )
    # 区段必须有**终点**: 只写 text[idx:] 时, verify step 之后任何一处 10 空格
    # 缩进的 `<name>)` 都会被算作已覆盖. 盲审实测: 在该 step 之后插入一个这样的
    # 标签、同时删掉真分支, 脚本会静默报绿 —— 对账脚本自己漏报, 比不做对账更糟.
    # 终点取「下一个同级 step 的 `- name:`」, 找不到就到文件末尾 (最后一个 step).
    rest = text[idx:]
    end = re.search(r"^    - name:", rest[len(marker):], re.MULTILINE)
    section = rest[: len(marker) + end.start()] if end else rest

    covered: set[str] = set()
    # 形如 `          ctex)` 或 `          zhnumber|xCJK2uni|zhmetrics)`
    for m in re.finditer(r"^\s{10}([A-Za-z0-9|]+)\)$", section, re.MULTILINE):
        for name in m.group(1).split("|"):
            if name != "*":
                covered.add(name)
    return covered


def main() -> int:
    expected = packages_with_version_stamp()
    if not expected:
        print(
            "::error::未扫到任何含版本槽位的包; STAMP_PATTERNS 或仓库结构已变, "
            "本脚本失去意义, 请同步更新。"
        )
        return 1

    ct = check_tag_covered()
    rl = release_covered()
    triggerable = release_triggerable()

    print(f"扫到 {len(expected)} 个含版本槽位的包:\n")
    print(f"{'包':<20} {'可发版':<8} {'check-tag':<11} {'release':<9} 版本槽位所在 dtx")
    print("-" * 92)

    missing: list[str] = []   # 可发版且漏校验 —— 真缺口, 失败
    latent: list[str] = []    # 不可发版但漏校验 —— 潜在缺口, 只提示
    for pkg, dtxs in sorted(expected.items()):
        in_ct = pkg in ct
        in_rl = pkg in rl
        can_release = pkg in triggerable
        if not (in_ct and in_rl):
            (missing if can_release else latent).append(pkg)
        print(
            f"{pkg:<20} {'✓' if can_release else '—':<8} "
            f"{'✓' if in_ct else '✗ 缺':<11} "
            f"{'✓' if in_rl else '✗ 缺':<9} {', '.join(dtxs)}"
        )

    # 反向对账: 白名单里列了、但已扫不到版本槽位的包 (包被删或版本写法改了)。
    stale = sorted((ct | rl) - set(expected))

    print()
    if missing:
        print("::error::以下包有版本槽位但未被两道校验完全覆盖:")
        for pkg in missing:
            where = []
            if pkg not in ct:
                where.append("check-tag.yml 的 paths + 一个 tag-<pkg> job + 汇总")
            if pkg not in rl:
                where.append("release.yml 三方校验的 case 分支")
            print(f"::error::  {pkg} — 需要补: {'; '.join(where)}")
        print(
            "::error::白名单式校验默认放行, 漏掉的包会在发版时静默走过 "
            "(release.yml 只打 ::notice:: 而非报错)。见 #1041 与 llmdoc "
            "reference/build-and-test.md 的版本管理覆盖矩阵。"
        )
    if latent:
        print(
            "::notice::以下包有版本槽位、但 release.yml 没有对应的 tag 触发器, "
            f"因此发不出版, 属潜在缺口 (给它加发版能力时必须同时补校验): "
            f"{', '.join(latent)}"
        )
    if stale:
        print(
            "::warning::以下包在白名单里但已扫不到版本槽位 "
            f"(包被删除, 或版本写法已变): {', '.join(stale)}"
        )
    if not missing:
        print("✓ 所有**可发版**且含版本槽位的包都已被两道校验覆盖。")

    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
