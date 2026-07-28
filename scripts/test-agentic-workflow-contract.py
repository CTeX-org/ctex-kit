#!/usr/bin/env python3
"""离线检查 ctex-kit 本地 Agent workflow 的编排与安全合同。"""

import base64
import json
import importlib.util
import os
import re
import shlex
import shutil
import subprocess
import tempfile
import textwrap
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"
ACTIONS = ROOT / ".github" / "actions"
AGENTIC_WORKFLOWS = (
    "agentic-pr-review.yml",
    "agentic-issue-dispatch.yml",
    "agentic-llmdoc-updater.yml",
)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def run(
    args: list[str],
    *,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    input_text: str | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=cwd,
        env=env,
        input=input_text,
        text=True,
        capture_output=True,
        check=check,
    )


def workflow(name: str) -> str:
    return read(WORKFLOWS / name)


def job(source: str, name: str) -> str:
    match = re.search(
        rf"(?ms)^  {re.escape(name)}:\n.*?(?=^  [A-Za-z0-9_-]+:\n|\Z)",
        source,
    )
    assert match, f"找不到 job: {name}"
    return match.group(0)


def parse_workflow(source: str) -> dict:
    """按 YAML 解析 workflow，并避免 YAML 1.1 把顶层 `on` 当作布尔值。"""
    document = yaml.safe_load(re.sub(r"(?m)^on:", '"on":', source, count=1))
    assert isinstance(document, dict), "workflow 顶层必须是 mapping"
    return document


def unique_steps_by_name(steps: list[dict], label: str) -> dict[str, dict]:
    names = [step.get("name") for step in steps]
    assert all(isinstance(name, str) and name for name in names), f"{label} 的每个 step 都必须有名称"
    duplicates = sorted({name for name in names if names.count(name) > 1})
    assert not duplicates, f"{label} 存在重名 step: {duplicates}"
    return dict(zip(names, steps, strict=True))


def parse_single_continued_command(script: str, label: str) -> list[str]:
    """解析由反斜线续行的一条简单命令，拒绝额外命令或复合 shell 语法。"""
    lines = [line.strip() for line in script.splitlines() if line.strip()]
    assert lines, f"{label} 不得为空"
    assert not any(line.startswith("#") for line in lines), f"{label} 不得用注释打断续行命令"

    argv: list[str] = []
    for index, line in enumerate(lines):
        continued = line.endswith("\\")
        if index < len(lines) - 1:
            assert continued, f"{label} 只能包含一条反斜线续行命令"
        else:
            assert not continued, f"{label} 最后一行不得继续到空命令"
        fragment = line[:-1].rstrip() if continued else line
        tokens = shlex.split(fragment, comments=True, posix=True)
        assert len(tokens) == 1, f"{label} 每行必须只提供一个命令名或参数"
        argv.extend(tokens)
    return argv


def assert_pr_review_draft_contract(source: str) -> None:
    document = parse_workflow(source)
    assert document["on"]["pull_request_target"]["types"] == [
        "opened",
        "synchronize",
        "reopened",
    ], "PR Review 必须在 Draft PR 打开、同步或重新打开时触发"

    jobs = document["jobs"]
    assert "if" not in jobs["codex_review"], "Codex 主审不得按 Draft 状态或其他条件恒定跳过"
    assert jobs["claude_review"].get("needs") == "codex_review", "Claude 兜底必须等待 Codex 主审"
    assert jobs["claude_review"].get("if") == "always() && needs.codex_review.result != 'success'", (
        "Claude 兜底条件必须只取决于 Codex 是否成功"
    )
    assert jobs["publish"].get("needs") == ["codex_review", "claude_review"], (
        "PR publisher 必须等待两条审查链"
    )
    assert jobs["publish"].get("if") == "always()", "PR publisher 必须在两条审查链结束后运行"

    publish_steps = unique_steps_by_name(jobs["publish"]["steps"], "PR publisher")
    expected_conditions = {
        "Download Codex review result": "needs.codex_review.result == 'success'",
        "Download Claude review result": "needs.claude_review.result == 'success'",
        "Validate and publish review comment": (
            "needs.codex_review.result == 'success' || needs.claude_review.result == 'success'"
        ),
        "Fail when no reviewer succeeded": (
            "always() && needs.codex_review.result != 'success' && needs.claude_review.result != 'success'"
        ),
    }
    for name, expected in expected_conditions.items():
        assert name in publish_steps, f"PR publisher 缺少 step: {name}"
        assert publish_steps[name].get("if") == expected, f"PR publisher step 条件不正确: {name}"

    download_contracts = {
        "Download Codex review result": "review-result-codex",
        "Download Claude review result": "review-result-claude",
    }
    for name, artifact in download_contracts.items():
        step = publish_steps[name]
        assert step.get("uses") == "actions/download-artifact@v8", f"{name} 必须使用固定下载 Action"
        assert step.get("with") == {"name": artifact, "path": ".review-input"}, f"{name} 输入不正确"

    publish_step = publish_steps["Validate and publish review comment"]
    assert publish_step.get("id") == "result", "实际发布 step 必须提供 publisher outputs 使用的 result id"
    require_all(
        publish_step.get("run", ""),
        (
            "# BEGIN REVIEW_COMMENT_UPSERT",
            "gh api --paginate --slurp",
            "gh api --method PATCH",
            "gh pr comment",
            '>> "$GITHUB_OUTPUT"',
            "# END REVIEW_COMMENT_UPSERT",
        ),
        "PR 实际发布 step",
    )

    failure_step = publish_steps["Fail when no reviewer succeeded"]
    failure_result = run(
        ["bash", "-euo", "pipefail", "-c", failure_step.get("run", "")],
        check=False,
    )
    assert failure_result.returncode != 0, "两条审查链都失败时，publisher 必须以非零状态结束"


def assert_contract_hook_coverage(source: str) -> None:
    document = parse_workflow(source)
    trigger_paths = document["on"]["pull_request"]["paths"]
    assert isinstance(trigger_paths, list), "合同 workflow 的 pull_request.paths 必须是列表"

    steps = document["jobs"]["contract"]["steps"]
    lint_step = next(
        (step for step in steps if step.get("name") == "Lint Agent shell scripts"),
        None,
    )
    assert lint_step is not None, "找不到 step: Lint Agent shell scripts"
    shellcheck_args = parse_single_continued_command(
        lint_step["run"],
        "Lint Agent shell scripts",
    )
    assert shellcheck_args[0] == "shellcheck", "Lint step 必须直接运行一条 ShellCheck 命令"

    hook_paths = (".githooks/pre-push", ".githooks/check-pr-ci.sh")
    shellcheck_inputs = (
        "shellcheck",
        *hook_paths,
        ".github/scripts/agentic/*.sh",
        ".github/scripts/pr-review/prepare-review-history.sh",
    )
    missing_triggers = [path for path in hook_paths if path not in trigger_paths]
    missing_shellcheck = [path for path in shellcheck_inputs if path not in shellcheck_args]
    assert not missing_triggers, f"Agent workflow 触发路径缺少 hook: {missing_triggers}"
    assert not missing_shellcheck, f"Agent workflow ShellCheck 参数缺少 hook: {missing_shellcheck}"


def require_all(source: str, fragments: tuple[str, ...], label: str) -> None:
    missing = [fragment for fragment in fragments if fragment not in source]
    assert not missing, f"{label} 缺少合同片段: {missing}"


def assert_no_write_permission(source: str, label: str) -> None:
    for permission in ("contents: write", "issues: write", "pull-requests: write"):
        assert permission not in source, f"{label} 不得取得 {permission}"


def assert_local_runtime(source: str, label: str) -> None:
    for forbidden in (
        "Lightspeed-Intelligence/agentic-workflow-template",
        "workflow_call:",
    ):
        assert forbidden not in source, f"{label} 不得继续依赖 {forbidden}"


def assert_setup_before_agent(source: str, setup_ref: str, agent_ref: str, label: str) -> None:
    assert source.index(setup_ref) < source.index(agent_ref), f"{label} 必须在可信工具安装和缓存保存后才启动 Agent"


def assert_pr_review_runtime_dependency_closure(source: str) -> None:
    """PR Review 从 base 执行的每个文件都必须在可信 sparse checkout 清单里。

    只改 workflow 里的执行路径、忘记同步 sparse-checkout，会让 job 在找不到文件时
    才失败；这里从实际的 `.trusted-base/...` 引用反推依赖闭环。
    """
    document = yaml.safe_load(source)
    for job_name in ("codex_review", "claude_review"):
        steps = document["jobs"][job_name]["steps"]
        job_text = yaml.safe_dump(steps, allow_unicode=True)
        dependencies = {
            match.rstrip(".,;:")
            for match in re.findall(r"""\.trusted-base/([A-Za-z0-9._/-]+)""", job_text)
        }
        assert dependencies, f"PR Review {job_name} 没有引用任何 base 固定文件"

        checkout = next(
            step
            for step in steps
            if step.get("name") == "Checkout trusted review runtime from base commit"
        )
        sparse_paths = [
            line.strip()
            for line in checkout["with"]["sparse-checkout"].splitlines()
            if line.strip()
        ]
        # sparse-checkout 允许写目录前缀，逐项检查引用是否被某个条目覆盖。
        missing = sorted(
            dependency
            for dependency in dependencies
            if not any(
                dependency == entry or dependency.startswith(f"{entry}/")
                for entry in sparse_paths
            )
        )
        assert not missing, (
            f"PR Review {job_name} 的可信 sparse checkout 缺少被引用的文件: {missing}"
        )


def assert_pr_instruction_isolation(review_source: str, action_source: str) -> None:
    """审查规范必须来自 base 提交，被审查的 checkout 不得提供 CLI 项目指令。

    Agent 在一次性 runner 中拥有完整本地执行权限，因此这里只固定两件事：提示词
    指向 base 固定的规范副本，以及 Claude 保留 `--bare` 不自动发现 `CLAUDE.md`。
    """
    document = parse_workflow(review_source)
    for job_name in ("codex_review", "claude_review"):
        steps = unique_steps_by_name(document["jobs"][job_name]["steps"], f"PR Review {job_name}")
        prompt = steps["Prepare trusted review inputs"].get("run", "")
        require_all(
            prompt,
            (
                "$GITHUB_WORKSPACE/.trusted-base/.claude/skills/pr-review/SKILL.md",
                "$GITHUB_WORKSPACE/.trusted-base/.claude/skills/github-comment/SKILL.md",
            ),
            f"PR Review {job_name} prompt",
        )

    # Claude 会自动读取工作目录的 CLAUDE.md；被审查的 checkout 是不可信输入，
    # 其中的项目指令不得作为 Agent 指令生效。
    assert "--bare" in action_source, "Claude 必须保留 --bare 以禁用项目指令自动发现"


def assert_llmdoc_blocked_notification(source: str) -> None:
    document = parse_workflow(source)
    update = document["jobs"]["update"]
    assert update["outputs"].get("status") == "${{ steps.publish.outputs.status }}"
    update_steps = unique_steps_by_name(update["steps"], "llmdoc publisher")
    publish_run = update_steps["Validate and publish llmdoc update"].get("run", "")
    assert 'echo "status=$(jq -r \'.status\' "$RUNNER_TEMP/public-result.json")"' in publish_run
    notify_steps = unique_steps_by_name(document["jobs"]["notify"]["steps"], "llmdoc notify")
    notify = notify_steps["Notify Feishu"]
    assert notify["with"].get("status") == (
        "${{ needs.update.result == 'success' && needs.update.outputs.status == 'success' "
        "&& 'success' || 'warning' }}"
    ), "llmdoc BLOCKED 和 job 失败都必须发送 warning 通知"


def embedded_run_blocks(source: str) -> list[str]:
    """取出 YAML 中的 literal run block，供 bash 做离线语法检查。"""
    lines = source.splitlines()
    blocks: list[str] = []
    for index, line in enumerate(lines):
        if line.lstrip() != "run: |":
            continue
        indent = len(line) - len(line.lstrip())
        body: list[str] = []
        for candidate in lines[index + 1 :]:
            candidate_indent = len(candidate) - len(candidate.lstrip())
            if candidate.strip() and candidate_indent <= indent:
                break
            body.append(candidate[indent + 2 :] if candidate else "")
        blocks.append("\n".join(body))
    return blocks


def test_embedded_shell(paths: tuple[Path, ...]) -> None:
    for path in paths:
        for script in embedded_run_blocks(read(path)):
            sanitized = re.sub(r"\$\{\{[^\n]*?\}\}", "EXPRESSION", script)
            result = run(["bash", "-n"], input_text=sanitized, check=False)
            assert result.returncode == 0, f"{path} 的 run block 语法错误: {result.stderr}"
    for path in (ROOT / ".github" / "scripts").rglob("*.sh"):
        run(["bash", "-n", str(path)])


def assert_no_early_exit_awk_in_pipe(path: Path) -> None:
    """复合 Action 的默认 shell 带 pipefail，管道右侧提前 exit 会让左侧收到 SIGPIPE。

    `tlmgr conf | awk '...{print;exit}'` 因此以 141 失败并终止整个安装步骤。
    禁止在复合 Action 的管道右侧用提前 exit 的 awk；读完全部输出再取值。
    """
    document = yaml.safe_load(read(path))
    for index, step in enumerate(document["runs"]["steps"]):
        script = step.get("run")
        if not script:
            continue
        for line in script.splitlines():
            if "| awk" not in line and "|awk" not in line:
                continue
            assert not re.search(r"awk\b[^|]*;\s*exit\s*}", line), (
                f"{path}.runs.steps[{index}] 在管道右侧用提前 exit 的 awk，"
                f"pipefail 下左侧会因 SIGPIPE 让整步失败：{line.strip()}"
            )


def test_action_metadata() -> None:
    validator = ROOT / "scripts" / "validate-action-metadata.py"
    action_paths = tuple(ACTIONS.glob("*/action.yml"))
    run(["python3", str(validator), *(str(path) for path in action_paths)])
    for path in action_paths:
        assert_no_early_exit_awk_in_pipe(path)

    with tempfile.TemporaryDirectory(prefix="ctex-action-metadata-") as tmp_name:
        source = read(ACTIONS / "run-agent" / "action.yml")
        bad_using = Path(tmp_name) / "bad-using.yml"
        bad_using.write_text(source.replace("using: composite", "using: composit", 1), encoding="utf-8")
        result = run(["python3", str(validator), str(bad_using)], check=False)
        assert result.returncode != 0, "损坏的 runs.using 必须被 Action metadata 门禁拒绝"

        bad_step = Path(tmp_name) / "bad-step.yml"
        bad_step.write_text(source.replace("      shell: bash", "      sheel: bash", 1), encoding="utf-8")
        result = run(["python3", str(validator), str(bad_step)], check=False)
        assert result.returncode != 0, "拼错的 composite step 字段必须被门禁拒绝"

        # GitHub 只在 job step 上支持 timeout-minutes。复合 Action 写上它会让 runner
        # 在加载 action.yml 时抛 TemplateValidationException，调用步骤整体失败。
        job_only_step = Path(tmp_name) / "job-only-step.yml"
        job_only_step.write_text(
            source.replace("      shell: bash", "      timeout-minutes: 15\n      shell: bash", 1),
            encoding="utf-8",
        )
        result = run(["python3", str(validator), str(job_only_step)], check=False)
        assert result.returncode != 0, "复合 Action step 的 timeout-minutes 必须被门禁拒绝"


def test_tool_setup_script(setup_source: str) -> None:
    """安装脚本必须校验字体完整性，并且不在 Agent 启动前留下未验证的工具链。"""
    require_all(
        setup_source,
        (
            "set -euo pipefail",
            "command -v l3build",
            "command -v xelatex",
            "::error::CJK 字体缓存不完整。",
            "::error::xeCJK 字体缓存缺少文件：",
        ),
        "Agent 工具安装脚本",
    )
    # 缺少 TeX Live 时必须显式失败，不能让 Agent 在没有排版工具的环境里开始审查。
    assert "::error::TeX Live 不可用" in setup_source, "TeX Live 缺失必须 fail closed"

    with tempfile.TemporaryDirectory(prefix="ctex-tool-setup-") as tmp_name:
        tmp = Path(tmp_name)
        workspace = tmp / "workspace"
        workspace.mkdir()
        font_cache = workspace / ".font-cache"
        xecjk_cache = workspace / ".xecjk-font-cache"
        for cache in (font_cache, xecjk_cache):
            cache.mkdir()
            (cache / ".done").write_text("", encoding="utf-8")

        # 从脚本里取出字体完整性校验片段，用预置的不完整缓存验证它会失败。
        validator = setup_source[
            setup_source.index("shopt -s nullglob") : setup_source.index("sudo mkdir -p /usr/share/fonts")
        ]
        env = os.environ | {
            "GITHUB_WORKSPACE": str(workspace),
            # 片段读取脚本内部变量名，直接以同名环境变量注入。
            "font_cache": str(font_cache),
            "xecjk_font_cache": str(xecjk_cache),
        }
        empty = run(["bash", "-euo", "pipefail", "-c", validator], env=env, check=False)
        assert empty.returncode != 0, "空的 CJK 字体缓存必须被拒绝"

        (font_cache / "NotoSansCJK-Regular.ttc").write_bytes(b"cache")
        partial = run(["bash", "-euo", "pipefail", "-c", validator], env=env, check=False)
        assert partial.returncode != 0, "只有 Sans 的 CJK 字体缓存必须被拒绝"

        (font_cache / "NotoSerifCJK-Regular.ttc").write_bytes(b"cache")
        missing_xecjk = run(["bash", "-euo", "pipefail", "-c", validator], env=env, check=False)
        assert missing_xecjk.returncode != 0, "xeCJK 文档字体缺失必须被拒绝"

        (xecjk_cache / "HanaMinB.ttf").write_bytes(b"cache")
        (xecjk_cache / "NotoSansSymbols2-Regular.ttf").write_bytes(b"cache")
        run(["bash", "-euo", "pipefail", "-c", validator], env=env)


def test_review_result_semantics(review_source: str) -> None:
    filters = [
        match.group(1)
        for match in re.finditer(r"(?ms)jq -e '(.*?)' (?:review-output|\"\$GITHUB_WORKSPACE|\"\$REVIEW_FILE)", review_source)
        if ".suggestion_count" in match.group(1) and ".conclusion" in match.group(1)
    ]
    assert len(filters) == 3, "Codex、Claude 和 publisher 必须各有一份结果语义校验"
    base = {
        "description": "审查完成",
        "review_status": "COMPLETE",
        "conclusion": "COMMENT",
        "critical_count": 0,
        "important_count": 0,
        "suggestion_count": 0,
        "comment_body": "正文",
        "reviewer": "codex",
        "model": "gpt-5.6-sol",
    }
    for jq_filter in filters:
        rejected = run(["jq", "-e", jq_filter], input_text=json.dumps(base), check=False)
        assert rejected.returncode != 0, "零问题 COMMENT 必须被实际 jq 校验拒绝"
        accepted = run(
            ["jq", "-e", jq_filter],
            input_text=json.dumps(base | {"suggestion_count": 1}),
            check=False,
        )
        assert accepted.returncode == 0, "含小问题的 COMMENT 应被实际 jq 校验接受"


def test_review_comment_upsert(review_source: str) -> None:
    document = parse_workflow(review_source)
    publish_steps = unique_steps_by_name(document["jobs"]["publish"]["steps"], "PR publisher")
    publish_step = publish_steps.get("Validate and publish review comment")
    assert publish_step is not None, "找不到实际 PR review 发布 step"
    match = re.search(
        r"(?ms)^\s*# BEGIN REVIEW_COMMENT_UPSERT\n(.*?)^\s*# END REVIEW_COMMENT_UPSERT",
        publish_step.get("run", ""),
    )
    assert match, "找不到 PR review 评论幂等发布片段"
    script = textwrap.dedent(match.group(1))
    assert "REVIEW_MARKER_REGEX='(?m)^<!-- pr-review-state:v1:" in script
    assert '--arg head "$REVIEW_HEAD"' in script
    assert "$state.head == $head" in script

    with tempfile.TemporaryDirectory(prefix="ctex-review-comment-") as tmp_name:
        tmp = Path(tmp_name)
        fake_bin = tmp / "bin"
        fake_bin.mkdir()
        state_path = tmp / "state.json"
        state_path.write_text(
            json.dumps({"comments": [], "create_calls": 0, "patch_calls": 0}),
            encoding="utf-8",
        )
        fake_gh = fake_bin / "gh"
        fake_gh.write_text(
            """#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

state_path = Path(os.environ["FAKE_GH_STATE"])
state = json.loads(state_path.read_text(encoding="utf-8"))
args = sys.argv[1:]

if args[:3] == ["api", "--paginate", "--slurp"]:
    print(json.dumps([state["comments"]]))
elif args[:3] == ["api", "--method", "PATCH"]:
    comment_id = int(args[3].rsplit("/", 1)[1])
    payload = json.loads(Path(args[args.index("--input") + 1]).read_text(encoding="utf-8"))
    comment = next(item for item in state["comments"] if item["id"] == comment_id)
    comment["body"] = payload["body"]
    state["patch_calls"] += 1
elif args[:2] == ["pr", "comment"]:
    body = Path(args[args.index("--body-file") + 1]).read_text(encoding="utf-8")
    state["comments"].append(
        {
            "id": 100 + state["create_calls"] + 1,
            "body": body,
            "user": {"login": "github-actions[bot]", "type": "Bot"},
            "performed_via_github_app": {"slug": "github-actions"},
        }
    )
    state["create_calls"] += 1
else:
    raise SystemExit(f"unexpected gh arguments: {args!r}")

state_path.write_text(json.dumps(state), encoding="utf-8")
""",
            encoding="utf-8",
        )
        fake_gh.chmod(0o755)

        runner_temp = tmp / "runner"
        runner_temp.mkdir()
        comment_file = runner_temp / "review-comment.md"
        env = os.environ | {
            "PATH": f"{fake_bin}:{os.environ['PATH']}",
            "FAKE_GH_STATE": str(state_path),
            "RUNNER_TEMP": str(runner_temp),
            "REPOSITORY": "example/repo",
            "PR_NUMBER": "42",
        }

        def review_body(label: str, head: str) -> str:
            marker = base64.b64encode(json.dumps({"head": head}).encode()).decode()
            return f"{label}\n<!-- pr-review-state:v1:{marker} -->\n"

        head_1 = "1" * 40
        head_2 = "2" * 40
        untrusted_body = review_body("untrusted", head_1)
        state_path.write_text(
            json.dumps(
                {
                    "comments": [
                        {
                            "id": 1,
                            "body": untrusted_body,
                            "user": {"login": "attacker[bot]", "type": "Bot"},
                            "performed_via_github_app": {"slug": "github-actions"},
                        },
                        {
                            "id": 2,
                            "body": untrusted_body,
                            "user": {"login": "github-actions[bot]", "type": "Bot"},
                            "performed_via_github_app": {"slug": "other-app"},
                        },
                    ],
                    "create_calls": 0,
                    "patch_calls": 0,
                }
            ),
            encoding="utf-8",
        )
        for label, head in (
            ("head 1 first", head_1),
            ("head 1 rerun", head_1),
            ("head 2 first", head_2),
            ("head 2 rerun", head_2),
        ):
            env["REVIEW_HEAD"] = head
            body = review_body(label, head)
            comment_file.write_text(body, encoding="utf-8")
            run(["bash", "-euo", "pipefail", "-c", script], env=env)

        state = json.loads(state_path.read_text(encoding="utf-8"))
        controlled = [
            comment
            for comment in state["comments"]
            if comment["user"]["login"] == "github-actions[bot]"
            and comment["performed_via_github_app"]["slug"] == "github-actions"
        ]
        assert len(controlled) == 2, "每个 PR head 必须保留一条独立审查评论"
        assert state["create_calls"] == 2
        assert state["patch_calls"] == 2
        assert controlled[0]["body"].startswith("head 1 rerun\n")
        assert controlled[1]["body"].startswith("head 2 rerun\n")


def test_pre_push_bot_comment_audit() -> None:
    hook = read(ROOT / ".githooks" / "check-pr-ci.sh")
    audit_start = hook.index('new_bot_comment_after_push="$(gh api')
    audit_end = hook.index("| jq -r", audit_start)
    audit_fetch = hook[audit_start:audit_end]
    assert "gh api --paginate --slurp" in audit_fetch
    assert "comments?per_page=100" in audit_fetch
    match = re.search(
        r"(?ms)^\s*# BEGIN BOT_COMMENT_AUDIT_JQ\n(.*?)^\s*# END BOT_COMMENT_AUDIT_JQ",
        hook,
    )
    assert match, "找不到 pre-push Bot 评论审计过滤器"
    jq_filter = textwrap.dedent(match.group(1))
    head_time = "2026-07-27T12:00:00Z"
    comments = [
        {
            "user": {"login": "github-actions[bot]", "type": "Bot"},
            "created_at": "2026-07-27T12:01:00Z",
            "updated_at": "2026-07-27T12:03:00Z",
            "html_url": "https://example.invalid/bot",
        },
        {
            "user": {"login": "maintainer", "type": "User"},
            "author_association": "OWNER",
            "created_at": "2026-07-27T12:02:00Z",
            "html_url": "https://example.invalid/stale-reply",
        },
    ]
    stale_reply = run(
        ["jq", "-r", "--arg", "t", head_time, jq_filter],
        input_text=json.dumps([comments]),
    )
    assert "github-actions[bot]\tCOMMENT\t2026-07-27T12:03:00Z" in stale_reply.stdout

    comments.append(
        {
            "user": {"login": "maintainer", "type": "User"},
            "author_association": "OWNER",
            "created_at": "2026-07-27T12:04:00Z",
            "html_url": "https://example.invalid/fresh-reply",
        }
    )
    fresh_reply = run(
        ["jq", "-r", "--arg", "t", head_time, jq_filter],
        input_text=json.dumps([comments]),
    )
    assert fresh_reply.stdout == "", "只有 Bot 评论最后更新之后的维护者回复才能关闭审计"

    old_page = [
        {
            "user": {"login": f"user-{index}", "type": "User"},
            "author_association": "NONE",
            "created_at": "2026-07-27T11:00:00Z",
            "html_url": f"https://example.invalid/old-{index}",
        }
        for index in range(100)
    ]
    second_page_bot = {
        "user": {"login": "github-actions[bot]", "type": "Bot"},
        "created_at": "2026-07-27T12:05:00Z",
        "updated_at": "2026-07-27T12:06:00Z",
        "html_url": "https://example.invalid/second-page-bot",
    }
    second_page_reply = run(
        ["jq", "-r", "--arg", "t", head_time, jq_filter],
        input_text=json.dumps([old_page, [second_page_bot]]),
    )
    assert "second-page-bot" in second_page_reply.stdout, (
        "当前 head 的 Bot 评论位于第二页时也必须被审计"
    )


def git(repo: Path, *args: str) -> str:
    return run(["git", *args], cwd=repo).stdout.strip()


def init_fixture_repo(path: Path) -> str:
    path.mkdir()
    run(["git", "init", "-q"], cwd=path)
    git(path, "config", "user.name", "Agent contract test")
    git(path, "config", "user.email", "contract@example.invalid")
    git(path, "config", "commit.gpgsign", "false")
    (path / "llmdoc").mkdir()
    (path / "llmdoc" / "index.md").write_text("base\n", encoding="utf-8")
    git(path, "add", "llmdoc/index.md")
    git(path, "commit", "-q", "-m", "base")
    return git(path, "rev-parse", "HEAD")


def candidate_result(outcome: str = "READY") -> dict[str, str]:
    return {
        "description": "候选已准备",
        "outcome": outcome,
        "commit_message": "docs: update fixture",
        "pr_title": "docs: update fixture",
        "pr_body": "测试候选正文",
        "comment_body": "测试候选说明",
    }


def package_llmdoc_fixture(
    tmp: Path,
    base_repo: Path,
    base_sha: str,
    content: str,
) -> tuple[Path, str]:
    candidate_repo = tmp / "candidate"
    run(["git", "clone", "-q", "--local", str(base_repo), str(candidate_repo)])
    git(candidate_repo, "config", "user.name", "Agent contract test")
    git(candidate_repo, "config", "user.email", "contract@example.invalid")
    git(candidate_repo, "config", "commit.gpgsign", "false")
    (candidate_repo / "llmdoc" / "index.md").write_text(content, encoding="utf-8")
    result = tmp / "candidate.json"
    result.write_text(json.dumps(candidate_result()), encoding="utf-8")
    artifact = tmp / "artifact"
    run(
        [
            "bash",
            str(ROOT / ".github" / "scripts" / "agentic" / "package-change-result.sh"),
            str(result),
            str(candidate_repo),
            str(artifact),
            base_sha,
            "codex",
            "gpt-5.6-sol",
            "update-llmdoc",
        ]
    )
    candidate_sha = json.loads((artifact / "manifest.json").read_text(encoding="utf-8"))[
        "candidate_sha"
    ]
    return artifact, candidate_sha


def install_fake_publisher_gh(tmp: Path, state: dict) -> tuple[Path, Path]:
    fake_bin = tmp / "bin"
    fake_bin.mkdir()
    state_path = tmp / "fake-gh-state.json"
    state_path.write_text(json.dumps(state), encoding="utf-8")
    fake_gh = fake_bin / "gh"
    fake_gh.write_text(
        """#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

state_path = Path(os.environ["FAKE_GH_STATE"])
state = json.loads(state_path.read_text(encoding="utf-8"))
args = sys.argv[1:]

def save() -> None:
    state_path.write_text(json.dumps(state), encoding="utf-8")

if args == ["auth", "setup-git"]:
    raise SystemExit(0)
if args[:2] == ["pr", "list"]:
    print(json.dumps(state.get("prs", [])))
    raise SystemExit(0)
if args[:2] == ["pr", "create"]:
    state["create_calls"] = state.get("create_calls", 0) + 1
    if state.get("fail_create_count", 0) > 0:
        state["fail_create_count"] -= 1
        save()
        print("simulated gh pr create failure", file=sys.stderr)
        raise SystemExit(1)
    number = state.get("next_number", 7)
    url = f"https://example.invalid/pr/{number}"
    body = Path(args[args.index("--body-file") + 1]).read_text(encoding="utf-8")
    state["prs"] = [{"number": number, "url": url, "body": body}]
    save()
    print(url)
    raise SystemExit(0)
if args[:2] == ["pr", "view"]:
    print(state["prs"][0]["number"])
    raise SystemExit(0)
if args[:2] == ["pr", "edit"]:
    body = Path(args[args.index("--body-file") + 1]).read_text(encoding="utf-8")
    state["prs"][0]["body"] = body
    save()
    raise SystemExit(0)
raise SystemExit(f"unexpected gh arguments: {args!r}")
""",
        encoding="utf-8",
    )
    fake_gh.chmod(0o755)
    return fake_bin, state_path


def test_runtime_scripts() -> None:
    scripts = ROOT / ".github" / "scripts" / "agentic"
    normalizer = scripts / "normalize-answer-result.sh"
    package = scripts / "package-change-result.sh"
    validate = scripts / "validate-change-artifact.sh"

    with tempfile.TemporaryDirectory(prefix="ctex-agent-contract-") as tmp_name:
        tmp = Path(tmp_name)

        raw_answer = tmp / "answer.json"
        normalized = tmp / "normalized.json"
        raw_answer.write_text(
            json.dumps(
                {
                    "description": "分析完成",
                    "result_status": "COMPLETE",
                    "comment_body": "正文",
                    "issue_type": "bug",
                    "severity": "medium",
                    "cost": "small",
                    "auto_fix_eligible": False,
                }
            ),
            encoding="utf-8",
        )
        run(
            [
                "bash",
                str(normalizer),
                str(raw_answer),
                str(normalized),
                "codex",
                "gpt-5.6-sol",
                "issue-dispatch",
            ]
        )
        assert json.loads(normalized.read_text(encoding="utf-8"))["reviewer"] == "codex"

        # F-005 反例：普通 git status 看不到 assume-unchanged 的脚本改写。
        # 运行 Agent 前保存的副本不受这次改写影响。
        answer_repo = tmp / "answer-repo"
        answer_script = answer_repo / ".github" / "scripts" / "agentic" / normalizer.name
        answer_script.parent.mkdir(parents=True)
        shutil.copy2(normalizer, answer_script)
        run(["git", "init", "-q"], cwd=answer_repo)
        git(answer_repo, "config", "user.name", "Agent contract test")
        git(answer_repo, "config", "user.email", "contract@example.invalid")
        git(answer_repo, "config", "commit.gpgsign", "false")
        git(answer_repo, "add", ".")
        git(answer_repo, "commit", "-q", "-m", "trusted normalizer")
        trusted_normalizer = tmp / "trusted-normalizer.sh"
        shutil.copy2(answer_script, trusted_normalizer)
        hidden_marker = tmp / "hidden-normalizer-ran"
        answer_script.write_text(
            f"#!/usr/bin/env bash\nprintf owned > {hidden_marker}\n",
            encoding="utf-8",
        )
        git(answer_repo, "update-index", "--assume-unchanged", str(answer_script.relative_to(answer_repo)))
        assert git(answer_repo, "status", "--porcelain") == ""
        trusted_output = tmp / "trusted-normalized.json"
        run(
            [
                "bash",
                str(trusted_normalizer),
                str(raw_answer),
                str(trusted_output),
                "codex",
                "gpt-5.6-sol",
                "issue-dispatch",
            ]
        )
        assert not hidden_marker.exists(), "runner 不得执行 Agent 隐藏改写后的 consumer 脚本"
        assert json.loads(trusted_output.read_text(encoding="utf-8"))["reviewer"] == "codex"

        # F-006 反例：Agent 控制的 .git/config 可以让 git status 执行 fsmonitor。
        # 只导入 llmdoc/ 到固定 base 的新 checkout 后，打包不再读取该配置。
        trusted_base = tmp / "trusted-base"
        trusted_base_sha = init_fixture_repo(trusted_base)
        agent_repo = tmp / "agent-repo"
        safe_repo = tmp / "safe-package-base"
        run(["git", "clone", "-q", "--local", str(trusted_base), str(agent_repo)])
        run(["git", "clone", "-q", "--local", str(trusted_base), str(safe_repo)])
        (agent_repo / "llmdoc" / "index.md").write_text("base\nagent change\n", encoding="utf-8")
        fsmonitor_marker = tmp / "agent-fsmonitor-ran"
        fsmonitor = agent_repo / "agent-fsmonitor.sh"
        fsmonitor.write_text(
            f"#!/usr/bin/env bash\nprintf triggered > {fsmonitor_marker}\nexit 0\n",
            encoding="utf-8",
        )
        fsmonitor.chmod(0o755)
        git(agent_repo, "config", "core.fsmonitor", str(fsmonitor))
        run(["git", "status", "--porcelain"], cwd=agent_repo, check=False)
        assert fsmonitor_marker.exists(), "反例必须证明 Agent 的 fsmonitor 会被 Git 解释"
        fsmonitor_marker.unlink()

        shutil.rmtree(safe_repo / "llmdoc")
        shutil.copytree(agent_repo / "llmdoc", safe_repo / "llmdoc", symlinks=True)
        safe_result = tmp / "safe-candidate.json"
        safe_result.write_text(json.dumps(candidate_result()), encoding="utf-8")
        run(
            [
                "bash",
                str(package),
                str(safe_result),
                str(safe_repo),
                str(tmp / "safe-artifact"),
                trusted_base_sha,
                "codex",
                "gpt-5.6-sol",
                "update-llmdoc",
            ]
        )
        assert not fsmonitor_marker.exists(), "可信 package-base 不得解释 Agent 的 .git/config"

        repo = tmp / "repo"
        runner_temp = tmp / "runner"
        runner_temp.mkdir()
        base = init_fixture_repo(repo)
        (repo / "llmdoc" / "index.md").write_text("base\nchange\n", encoding="utf-8")
        result = tmp / "candidate.json"
        result.write_text(json.dumps(candidate_result()), encoding="utf-8")
        artifact = tmp / "artifact"
        run(
            [
                "bash",
                str(package),
                str(result),
                str(repo),
                str(artifact),
                base,
                "codex",
                "gpt-5.6-sol",
                "update-llmdoc",
            ]
        )
        git(repo, "reset", "-q", "--hard", base)
        env = os.environ.copy()
        env["RUNNER_TEMP"] = str(runner_temp)
        run(["bash", str(validate), str(artifact), str(repo), "update-llmdoc"], env=env)
        manifest = json.loads((artifact / "manifest.json").read_text(encoding="utf-8"))
        assert manifest["base_sha"] == base
        assert manifest["changed_files"] == ["llmdoc/index.md"]

        rejected_repo = tmp / "rejected"
        rejected_base = init_fixture_repo(rejected_repo)
        (rejected_repo / "outside.txt").write_text("invalid\n", encoding="utf-8")
        rejected = run(
            [
                "bash",
                str(package),
                str(result),
                str(rejected_repo),
                str(tmp / "rejected-artifact"),
                rejected_base,
                "codex",
                "gpt-5.6-sol",
                "update-llmdoc",
            ],
            check=False,
        )
        assert rejected.returncode != 0, "llmdoc 候选不得修改 llmdoc/ 之外的路径"


def test_publish_preserves_unmerged_llmdoc_candidate() -> None:
    publish = ROOT / ".github" / "scripts" / "agentic" / "publish-change.sh"

    with tempfile.TemporaryDirectory(prefix="ctex-llmdoc-publish-") as tmp_name:
        tmp = Path(tmp_name)
        base_repo = tmp / "base"
        base_sha = init_fixture_repo(base_repo)
        remote = tmp / "server" / "example" / "repo.git"
        remote.parent.mkdir(parents=True)
        run(["git", "init", "--bare", "-q", str(remote)])
        git(base_repo, "remote", "add", "origin", str(remote))
        git(base_repo, "push", "-q", "origin", "HEAD:refs/heads/master")

        old_repo = tmp / "old-candidate"
        run(["git", "clone", "-q", "--local", str(base_repo), str(old_repo)])
        git(old_repo, "config", "user.name", "Agent contract test")
        git(old_repo, "config", "user.email", "contract@example.invalid")
        git(old_repo, "config", "commit.gpgsign", "false")
        (old_repo / "llmdoc" / "index.md").write_text("base\nold candidate\n", encoding="utf-8")
        git(old_repo, "add", "llmdoc/index.md")
        git(old_repo, "commit", "-q", "-m", "old llmdoc candidate")
        old_sha = git(old_repo, "rev-parse", "HEAD")
        branch = "agentic/update-llmdoc-master"
        git(old_repo, "push", "-q", str(remote), f"HEAD:refs/heads/{branch}")

        artifact, _ = package_llmdoc_fixture(
            tmp,
            base_repo,
            base_sha,
            "base\nnew candidate\n",
        )

        fake_bin, state_path = install_fake_publisher_gh(
            tmp,
            {
                "prs": [
                    {
                        "number": 7,
                        "url": "https://example.invalid/pr/7",
                        "body": "<!-- agentic-update-llmdoc:master -->",
                    }
                ]
            },
        )
        runner_temp = tmp / "runner"
        runner_temp.mkdir()
        env = os.environ | {
            "PATH": f"{fake_bin}:{os.environ['PATH']}",
            "FAKE_GH_STATE": str(state_path),
            "GH_TOKEN": "test-token",
            "RUNNER_TEMP": str(runner_temp),
            "GITHUB_SERVER_URL": f"file://{tmp / 'server'}",
        }
        rejected = run(
            [
                "bash",
                str(publish),
                str(artifact),
                "example/repo",
                "master",
                branch,
                "update-llmdoc",
                str(tmp / "public-result.json"),
            ],
            env=env,
            check=False,
        )
        assert rejected.returncode != 0
        assert "Refusing to replace unmerged llmdoc candidate" in rejected.stdout, (
            f"unexpected publisher failure\nstdout:\n{rejected.stdout}\nstderr:\n{rejected.stderr}"
        )
        remote_sha = run(
            ["git", "ls-remote", "--heads", str(remote), f"refs/heads/{branch}"]
        ).stdout.split()[0]
        assert remote_sha == old_sha, "发布失败后必须保留旧 llmdoc 候选 head"

        state_path.write_text(json.dumps({"prs": []}), encoding="utf-8")
        runner_without_pr = tmp / "runner-without-pr"
        runner_without_pr.mkdir()
        unknown = run(
            [
                "bash",
                str(publish),
                str(artifact),
                "example/repo",
                "master",
                branch,
                "update-llmdoc",
                str(tmp / "unknown-result.json"),
            ],
            env=env | {"RUNNER_TEMP": str(runner_without_pr)},
            check=False,
        )
        assert unknown.returncode != 0
        assert "differs from the current candidate and has no workflow-owned open PR" in unknown.stdout
        remote_sha = run(
            ["git", "ls-remote", "--heads", str(remote), f"refs/heads/{branch}"]
        ).stdout.split()[0]
        assert remote_sha == old_sha, "无法认证归属的分支必须保持不变"


def test_publish_recovers_llmdoc_branch_states() -> None:
    publish = ROOT / ".github" / "scripts" / "agentic" / "publish-change.sh"

    with tempfile.TemporaryDirectory(prefix="ctex-llmdoc-publish-retry-") as tmp_name:
        tmp = Path(tmp_name)
        base_repo = tmp / "base"
        base_sha = init_fixture_repo(base_repo)
        remote = tmp / "server" / "example" / "repo.git"
        remote.parent.mkdir(parents=True)
        run(["git", "init", "--bare", "-q", str(remote)])
        git(base_repo, "remote", "add", "origin", str(remote))
        git(base_repo, "push", "-q", "origin", "HEAD:refs/heads/master")
        branch = "agentic/update-llmdoc-master"
        artifact, candidate_sha = package_llmdoc_fixture(
            tmp,
            base_repo,
            base_sha,
            "base\nretry candidate\n",
        )
        fake_bin, state_path = install_fake_publisher_gh(
            tmp,
            {"prs": [], "fail_create_count": 1, "next_number": 8},
        )
        common_env = os.environ | {
            "PATH": f"{fake_bin}:{os.environ['PATH']}",
            "FAKE_GH_STATE": str(state_path),
            "GH_TOKEN": "test-token",
            "GITHUB_SERVER_URL": f"file://{tmp / 'server'}",
        }

        first_runner = tmp / "runner-first"
        first_runner.mkdir()
        first = run(
            [
                "bash",
                str(publish),
                str(artifact),
                "example/repo",
                "master",
                branch,
                "update-llmdoc",
                str(tmp / "first-result.json"),
            ],
            env=common_env | {"RUNNER_TEMP": str(first_runner)},
            check=False,
        )
        assert first.returncode != 0, "第一次建 PR 的模拟故障必须传递失败状态"
        remote_sha = run(
            ["git", "ls-remote", "--heads", str(remote), f"refs/heads/{branch}"]
        ).stdout.split()[0]
        assert remote_sha == candidate_sha, "建 PR 失败后必须保留经过校验的精确候选 head"

        retry_runner = tmp / "runner-retry"
        retry_runner.mkdir()
        public_result = tmp / "retry-result.json"
        run(
            [
                "bash",
                str(publish),
                str(artifact),
                "example/repo",
                "master",
                branch,
                "update-llmdoc",
                str(public_result),
            ],
            env=common_env | {"RUNNER_TEMP": str(retry_runner)},
        )
        published = json.loads(public_result.read_text(encoding="utf-8"))
        assert published["pr_number"] == 8
        assert published["pr_url"] == "https://example.invalid/pr/8"
        state = json.loads(state_path.read_text(encoding="utf-8"))
        assert state["create_calls"] == 2

    with tempfile.TemporaryDirectory(prefix="ctex-llmdoc-publish-merged-") as tmp_name:
        tmp = Path(tmp_name)
        original = tmp / "original"
        init_fixture_repo(original)
        remote = tmp / "server" / "example" / "repo.git"
        remote.parent.mkdir(parents=True)
        run(["git", "init", "--bare", "-q", str(remote)])
        merged = tmp / "merged"
        run(["git", "clone", "-q", "--local", str(original), str(merged)])
        git(merged, "config", "user.name", "Agent contract test")
        git(merged, "config", "user.email", "contract@example.invalid")
        git(merged, "config", "commit.gpgsign", "false")
        (merged / "llmdoc" / "index.md").write_text("base\nmerged candidate\n", encoding="utf-8")
        git(merged, "add", "llmdoc/index.md")
        git(merged, "commit", "-q", "-m", "merged llmdoc candidate")
        merged_sha = git(merged, "rev-parse", "HEAD")
        branch = "agentic/update-llmdoc-master"
        git(merged, "push", "-q", str(remote), "HEAD:refs/heads/master")
        git(merged, "push", "-q", str(remote), f"HEAD:refs/heads/{branch}")
        artifact, candidate_sha = package_llmdoc_fixture(
            tmp,
            merged,
            merged_sha,
            "base\nmerged candidate\nnext candidate\n",
        )
        fake_bin, state_path = install_fake_publisher_gh(
            tmp,
            {"prs": [], "next_number": 9},
        )
        runner_temp = tmp / "runner"
        runner_temp.mkdir()
        public_result = tmp / "public-result.json"
        run(
            [
                "bash",
                str(publish),
                str(artifact),
                "example/repo",
                "master",
                branch,
                "update-llmdoc",
                str(public_result),
            ],
            env=os.environ
            | {
                "PATH": f"{fake_bin}:{os.environ['PATH']}",
                "FAKE_GH_STATE": str(state_path),
                "GH_TOKEN": "test-token",
                "RUNNER_TEMP": str(runner_temp),
                "GITHUB_SERVER_URL": f"file://{tmp / 'server'}",
            },
        )
        remote_sha = run(
            ["git", "ls-remote", "--heads", str(remote), f"refs/heads/{branch}"]
        ).stdout.split()[0]
        assert remote_sha == candidate_sha, "已合入 base 的保留分支必须能在精确 lease 下更新"
        assert json.loads(public_result.read_text(encoding="utf-8"))["pr_number"] == 9


def main() -> None:
    review = workflow("agentic-pr-review.yml")
    issue = workflow("agentic-issue-dispatch.yml")
    llmdoc = workflow("agentic-llmdoc-updater.yml")
    contract = workflow("check-agentic-workflows.yml")
    setup = read(ROOT / ".github" / "scripts" / "agentic" / "setup-agent-tools.sh")

    test_action_metadata()
    test_tool_setup_script(setup)
    test_embedded_shell(
        tuple(WORKFLOWS / name for name in AGENTIC_WORKFLOWS)
        + (WORKFLOWS / "check-agentic-workflows.yml",)
        + tuple(ACTIONS.glob("*/action.yml"))
    )
    test_review_result_semantics(review)
    test_review_comment_upsert(review)
    test_pre_push_bot_comment_audit()
    test_runtime_scripts()
    test_publish_preserves_unmerged_llmdoc_candidate()
    test_publish_recovers_llmdoc_branch_states()

    assert not (WORKFLOWS / "agentic-patrol.yml").exists(), "定时 patrol 不应恢复"
    for name, source in zip(AGENTIC_WORKFLOWS, (review, issue, llmdoc), strict=True):
        assert_local_runtime(source, name)
        require_all(source, ("permissions: {}", "runs-on: ubuntu-latest"), name)
        # 缓存只恢复不保存：保存发生在 post job，届时 Agent 已经运行过仓库代码。
        for forbidden in ("uses: actions/cache@", "uses: actions/cache/save@"):
            assert forbidden not in source, f"{name} 不得在 Agent job 内保存共享缓存: {forbidden}"

    # PR Review：base SHA 提供可信规范、脚本和安装 Action；PR head 只作为审查对象。
    require_all(
        review,
        (
            "pull_request_target:",
            "types: [opened, synchronize, reopened]",
            "group: pr-review-${{ github.event.pull_request.number }}",
            "cancel-in-progress: true",
        ),
        "PR Review trigger",
    )
    assert_pr_review_draft_contract(review)
    duplicate_codex_download = review.replace(
        "        if: needs.codex_review.result == 'success'\n",
        "        if: 0 == 1\n",
        1,
    ).replace(
        "      - name: Download Claude review result\n",
        "      - name: Download Codex review result\n"
        "        if: needs.codex_review.result == 'success'\n"
        "        run: \"true\"\n\n"
        "      - name: Download Claude review result\n",
        1,
    )
    for broken_review, label in (
        (
            review.replace(
                "    name: Review with Codex (primary)\n    runs-on:",
                "    name: Review with Codex (primary)\n    if: 0 == 1\n    runs-on:",
                1,
            ),
            "Codex 主审恒假条件",
        ),
        (
            review.replace(
                "    if: always() && needs.codex_review.result != 'success'\n",
                "    if: always() && needs.codex_review.result != 'success' && 0 == 1\n",
                1,
            ),
            "Claude 兜底恒假条件",
        ),
        (
            review.replace(
                "    if: always()\n",
                "    if: always() && 0 == 1\n",
                1,
            ),
            "publisher 恒假条件",
        ),
        (
            review.replace("    needs: codex_review\n", "", 1),
            "Claude 兜底缺少 Codex 依赖",
        ),
        (
            review.replace("    needs: [codex_review, claude_review]\n", "", 1),
            "publisher 缺少审查链依赖",
        ),
        (
            review.replace(
                "        if: needs.codex_review.result == 'success'\n",
                "        if: 0 == 1\n",
                1,
            ),
            "Codex artifact 下载被禁用",
        ),
        (
            review.replace(
                "        if: needs.claude_review.result == 'success'\n",
                "        if: 0 == 1\n",
                1,
            ),
            "Claude artifact 下载被禁用",
        ),
        (
            review.replace(
                "        if: needs.codex_review.result == 'success' || needs.claude_review.result == 'success'\n",
                "        if: 0 == 1\n",
                1,
            ),
            "实际发布 step 被禁用",
        ),
        (
            review.replace(
                "        if: always() && needs.codex_review.result != 'success' && needs.claude_review.result != 'success'\n",
                "        if: 0 == 1\n",
                1,
            ),
            "双失败终止 step 被禁用",
        ),
        (
            duplicate_codex_download,
            "重名空操作掩护被禁用的 Codex 下载",
        ),
        (
            review.replace(
                "      - name: Download Codex review result\n"
                "        if: needs.codex_review.result == 'success'\n"
                "        uses: actions/download-artifact@v8\n"
                "        with:\n"
                "          name: review-result-codex\n",
                "      - name: Download Codex review result\n"
                "        if: needs.codex_review.result == 'success'\n"
                "        uses: actions/download-artifact@v8\n"
                "        with:\n"
                "          name: review-result-claude\n",
                1,
            ),
            "Codex 下载错误 artifact",
        ),
        (
            review.replace(
                "        run: |\n"
                "          echo \"::error::Codex 主链路与 Claude Code fallback 均执行失败\"\n"
                "          exit 1\n",
                "        run: \"true\"\n",
                1,
            ),
            "双失败 step 不再失败",
        ),
    ):
        try:
            assert_pr_review_draft_contract(broken_review)
        except AssertionError:
            pass
        else:
            raise AssertionError(f"{label}的反例必须失败")
    for name in ("codex_review", "claude_review"):
        source = job(review, name)
        require_all(
            source,
            (
                "contents: read",
                "pull-requests: read",
                "ref: ${{ github.event.pull_request.head.sha }}",
                "persist-credentials: false",
                "token: ${{ github.token }}",
                "ref: ${{ github.event.pull_request.base.sha }}",
                "bash .trusted-base/.github/scripts/agentic/setup-agent-tools.sh",
                "uses: ./.trusted-base/.github/actions/run-agent",
                ".trusted-base/.claude/skills/pr-review/SKILL.md",
                ".trusted-base/.github/scripts/pr-review/prepare-review-history.sh",
            ),
            f"PR Review {name}",
        )
        assert_no_write_permission(source, f"PR Review {name}")
        assert "secrets.PAT_TOKEN" not in source, f"PR Review {name} 不得接触可写 PAT"
        assert_setup_before_agent(
            source,
            "bash .trusted-base/.github/scripts/agentic/setup-agent-tools.sh",
            "uses: ./.trusted-base/.github/actions/run-agent",
            f"PR Review {name}",
        )

    assert_pr_review_runtime_dependency_closure(review)
    broken_review = review.replace(
        "            .github/scripts/agentic/setup-agent-tools.sh\n",
        "",
        1,
    )
    try:
        assert_pr_review_runtime_dependency_closure(broken_review)
    except AssertionError:
        pass
    else:
        raise AssertionError("可信 sparse checkout 缺少被引用文件的反例必须失败")

    publisher = job(review, "publish")
    require_all(publisher, ("pull-requests: write", "actions/download-artifact@"), "PR publisher")
    for forbidden in (
        "actions/checkout@",
        "setup-agent-tools",
        "@openai/codex",
        "@anthropic-ai/claude-code",
    ):
        assert forbidden not in publisher, f"PR publisher 不得包含 {forbidden}"
    assert review.count("pull-requests: write") == 1, "只有 PR publisher 可以写 PR"
    assert review.count("bash .trusted-base/.github/scripts/agentic/setup-agent-tools.sh") == 2
    assert review.count("uses: ./.trusted-base/.github/actions/run-agent") == 2
    require_all(
        review,
        (
            ".trusted-base/.claude/skills/github-comment/SKILL.md",
            ".suggestion_count > 0",
        ),
        "PR Review result boundary",
    )

    # Issue Dispatch：只分析 opened 事件；Agent 无写权限，独立 job 发布评论。
    require_all(
        issue,
        (
            "issues:\n    # 只监听 opened",
            "types: [opened]",
            "group: issue-dispatch-${{ github.event.issue.number }}",
            "cancel-in-progress: false",
        ),
        "Issue Dispatch trigger",
    )
    assert "schedule:" not in issue
    assert "workflow_dispatch:" not in issue
    prepare_issue = job(issue, "prepare")
    require_all(
        prepare_issue,
        ("if: github.repository == 'CTeX-org/ctex-kit'", "contents: read", "issues: read"),
        "Issue prepare",
    )
    for name in ("codex_analyze", "claude_analyze"):
        source = job(issue, name)
        require_all(
            source,
            (
                "contents: read",
                "ref: ${{ github.sha }}",
                "persist-credentials: false",
                "token: ${{ github.token }}",
                "bash consumer/.github/scripts/agentic/setup-agent-tools.sh",
                "uses: ./consumer/.github/actions/run-agent",
                "consumer/.github/scripts/agentic/normalize-answer-result.sh",
                "TRUSTED_ANSWER_NORMALIZER",
                'bash "$TRUSTED_ANSWER_NORMALIZER"',
            ),
            f"Issue Agent {name}",
        )
        post_agent = source.split("uses: ./consumer/.github/actions/run-agent", 1)[1]
        assert "git -C consumer" not in post_agent, f"Issue Agent {name} 返回后不得对 Agent 仓库执行 Git"
        assert (
            "bash consumer/.github/scripts/agentic/normalize-answer-result.sh" not in post_agent
        ), f"Issue Agent {name} 返回后不得执行 consumer 中的脚本"
        assert_no_write_permission(source, f"Issue Agent {name}")
        assert "secrets.PAT_TOKEN" not in source, f"Issue Agent {name} 不得接触可写 PAT"
        assert_setup_before_agent(
            source,
            "bash consumer/.github/scripts/agentic/setup-agent-tools.sh",
            "uses: ./consumer/.github/actions/run-agent",
            f"Issue Agent {name}",
        )
    dispatch = job(issue, "dispatch")
    require_all(
        dispatch,
        ("if: always() && github.repository == 'CTeX-org/ctex-kit'", "issues: write"),
        "Issue publisher",
    )
    assert issue.count("issues: write") == 1, "只有 Issue publisher 可以写 Issue"
    assert issue.count("bash consumer/.github/scripts/agentic/setup-agent-tools.sh") == 2
    require_all(
        job(issue, "notify"),
        ("if: always() && github.repository == 'CTeX-org/ctex-kit'", "uses: ./.github/actions/feishu-notify"),
        "Issue notify",
    )

    # llmdoc：固定 master，Agent 只产出候选；校验和发布分别在独立 job 完成。
    require_all(
        llmdoc,
        (
            "cron: '0 21 * * *'",
            "workflow_dispatch:",
            "group: agentic-llmdoc-updater-${{ github.repository }}",
            "cancel-in-progress: false",
        ),
        "llmdoc trigger",
    )
    prepare_llmdoc = job(llmdoc, "prepare")
    require_all(
        prepare_llmdoc,
        (
            "if: github.repository == 'CTeX-org/ctex-kit'",
            "ref: master",
            "TARGET_BRANCH: master",
            "SINCE_PERIOD: ${{ inputs.since_period || '24 hours ago' }}",
            "base_sha=$(git -C consumer rev-parse HEAD)",
        ),
        "llmdoc prepare",
    )
    for name in ("codex_candidate", "claude_candidate"):
        source = job(llmdoc, name)
        require_all(
            source,
            (
                "contents: read",
                "ref: ${{ needs.prepare.outputs.base_sha }}",
                "persist-credentials: false",
                "token: ${{ github.token }}",
                "bash runtime/.github/scripts/agentic/setup-agent-tools.sh",
                "uses: ./runtime/.github/actions/run-agent",
                "runtime/.github/scripts/agentic/package-change-result.sh",
                "path: package-base",
                "Import Agent llmdoc content into fresh packaging base",
                "test ! -L consumer/llmdoc",
                "cp -R --no-preserve=mode,ownership,timestamps",
                '"$GITHUB_WORKSPACE/package-base"',
                "runtime/.claude/skills/update-llmdoc/SKILL.md",
                "$RUNNER_TEMP/agent-input/task.json",
                "$RUNNER_TEMP/agent-input/recent-commits.txt",
            ),
            f"llmdoc Agent {name}",
        )
        post_agent = source.split("uses: ./runtime/.github/actions/run-agent", 1)[1]
        assert "git -C consumer" not in post_agent, f"llmdoc Agent {name} 返回后不得对 Agent 仓库执行 Git"
        assert (
            '"$GITHUB_WORKSPACE/consumer"' not in post_agent
        ), f"llmdoc Agent {name} 打包不得使用 Agent 控制的 Git 仓库"
        assert_no_write_permission(source, f"llmdoc Agent {name}")
        assert "secrets.PAT_TOKEN" not in source, f"llmdoc Agent {name} 不得接触可写 PAT"
        assert_setup_before_agent(
            source,
            "bash runtime/.github/scripts/agentic/setup-agent-tools.sh",
            "uses: ./runtime/.github/actions/run-agent",
            f"llmdoc Agent {name}",
        )
    for name in ("validate_codex", "validate_claude"):
        source = job(llmdoc, name)
        require_all(
            source,
            (
                "contents: read",
                "runtime/.github/scripts/agentic/validate-change-artifact.sh",
                "ref: ${{ needs.prepare.outputs.base_sha }}",
            ),
            f"llmdoc validator {name}",
        )
        assert_no_write_permission(source, f"llmdoc validator {name}")
    llmdoc_publisher = job(llmdoc, "update")
    require_all(
        llmdoc_publisher,
        (
            "if: always() && github.repository == 'CTeX-org/ctex-kit'",
            "contents: write",
            "pull-requests: write",
            "runtime/.github/scripts/agentic/publish-change.sh",
            "ref: ${{ needs.prepare.outputs.base_sha }}",
        ),
        "llmdoc publisher",
    )
    assert "setup-agent-tools" not in llmdoc_publisher
    assert llmdoc.count("contents: write") == 1
    assert llmdoc.count("pull-requests: write") == 1
    assert llmdoc.count("bash runtime/.github/scripts/agentic/setup-agent-tools.sh") == 2
    require_all(
        job(llmdoc, "notify"),
        (
            "if: always() && github.repository == 'CTeX-org/ctex-kit'",
            "needs: [prepare, update]",
            "ref: ${{ needs.prepare.outputs.base_sha || 'master' }}",
            "uses: ./.github/actions/feishu-notify",
            "secrets.FEISHU_LLMDOC_WEBHOOK_TOKEN",
        ),
        "llmdoc notify",
    )

    runner = read(ACTIONS / "run-agent" / "action.yml")
    assert_pr_instruction_isolation(review, runner)
    for broken_review, broken_action, label in (
        (
            review.replace(
                "$GITHUB_WORKSPACE/.trusted-base/.claude/skills/pr-review/SKILL.md",
                ".claude/skills/pr-review/SKILL.md",
                1,
            ),
            runner,
            "prompt 改读工作树而非 base 固定的审查规范",
        ),
        (
            review,
            runner.replace("--bare", "--verbose"),
            "Claude 丢掉 --bare 而自动发现工作树的 CLAUDE.md",
        ),
    ):
        try:
            assert_pr_instruction_isolation(broken_review, broken_action)
        except AssertionError:
            pass
        else:
            raise AssertionError(f"{label}的反例必须失败")
    assert_llmdoc_blocked_notification(llmdoc)
    for broken_llmdoc, label in (
        (
            llmdoc.replace("      status: ${{ steps.publish.outputs.status }}\n", "", 1),
            "llmdoc publisher 不再导出公开状态",
        ),
        (
            llmdoc.replace(
                "status: ${{ needs.update.result == 'success' && needs.update.outputs.status == 'success' && 'success' || 'warning' }}",
                "status: ${{ needs.update.result == 'success' && 'success' || 'warning' }}",
                1,
            ),
            "BLOCKED 重新显示为成功通知",
        ),
    ):
        try:
            assert_llmdoc_blocked_notification(broken_llmdoc)
        except AssertionError:
            pass
        else:
            raise AssertionError(f"{label}的反例必须失败")
    require_all(
        runner,
        (
            "Run pinned agent CLI",
            "API_KEY: ${{ inputs.api_key }}",
            "--dangerously-bypass-approvals-and-sandbox",
            "--dangerously-skip-permissions",
            "--bare",
            "--no-session-persistence",
            "--output-schema",
            "--json-schema",
        ),
        "Agent CLI runner",
    )
    # 结果必须是结构化对象，不能把 CLI 的自由文本直接当成审查结论。
    assert "jq -e 'type == \"object\"'" in runner, "Agent 结果必须校验为 JSON 对象"
    for removed_input in (
        "ignore_repository_rules",
        "trusted_review_skill_file",
        "trusted_comment_skill_file",
    ):
        assert removed_input not in runner, f"已删除的隔离输入不应回归: {removed_input}"

    # 三类缓存都在 Agent 启动前恢复，未命中时当场安装；Agent 启动后不写回缓存。
    for source, name, prefix in (
        (review, "PR Review", ".trusted-base"),
        (issue, "Issue Dispatch", "consumer"),
        (llmdoc, "llmdoc Updater", "runtime"),
    ):
        assert source.count("uses: actions/cache/restore@v6") == 6, (
            f"{name} 的两个 Agent job 必须各恢复三类缓存"
        )
        require_all(
            source,
            (
                f"tl-bypass-${{{{ runner.os }}}}-2026-${{{{ steps.tl-cache-key.outputs.week }}}}-${{{{ hashFiles('{prefix}/.github/tl_packages') }}}}",
                f"ctex-kit-fonts-${{{{ runner.os }}}}-${{{{ hashFiles('{prefix}/.github/font-urls.txt') }}}}-v1",
                "xecjk-fonts-${{ runner.os }}-hanaminB-notoSymbols2-v1",
                "cache: false",
                f"bash {prefix}/.github/scripts/agentic/setup-agent-tools.sh",
            ),
            f"{name} 工具缓存",
        )

    tools = (
        "actionlint",
        "fc-match",
        "gs",
        "kpsewhich",
        "l3build",
        "magick",
        "pdfcrop",
        "pdffonts",
        "pdfimages",
        "pdfinfo",
        "pdftoppm",
        "pdftotext",
        "sha256sum",
        "shellcheck",
        "texlua",
        "xdvipdfmx",
        "xelatex",
        # ctex 手册的索引依赖它；缺失时 l3build doc 会在生成 PDF 之后才失败。
        "zhmakeindex",
    )
    require_all(setup, tools, "Agent toolchain")

    # 合同 workflow 本身必须随所有本地 runtime 输入变化而运行，并执行静态检查。
    require_all(
        contract,
        (
            "permissions:\n  contents: read",
            "if: github.repository == 'CTeX-org/ctex-kit'",
            "persist-credentials: false",
            "run: python3 scripts/test-agentic-workflow-contract.py",
            "'.github/actions/**'",
            "'.github/scripts/**'",
            "'.claude/skills/**'",
            "'.github/tl_packages'",
            "'.github/font-urls.txt'",
            "'scripts/validate-action-metadata.py'",
            "actionlint@v1.7.7",
        ),
        "Agent workflow contract gate",
    )
    assert_contract_hook_coverage(contract)
    for broken_contract, label in (
        (
            contract.replace(
                "      - '.githooks/pre-push'\n",
                "      # - '.githooks/pre-push'\n",
                1,
            ),
            "注释 trigger path",
        ),
        (
            contract.replace(
                "            .githooks/pre-push \\\n",
                "            # .githooks/pre-push \\\n",
                1,
            ),
            "注释 ShellCheck 参数",
        ),
        (
            contract.replace(
                "          shellcheck \\\n            .githooks/pre-push \\\n",
                "          echo .githooks/pre-push\n          shellcheck \\\n",
                1,
            ),
            "hook 只作为 echo 参数",
        ),
    ):
        try:
            assert_contract_hook_coverage(broken_contract)
        except AssertionError:
            pass
        else:
            raise AssertionError(f"{label}的反例必须失败")

    provenance = read(ROOT / ".github" / "agentic-runtime.md")
    require_all(
        provenance,
        (
            "Lightspeed-Intelligence/agentic-workflow-template",
            "2a0bb28e6583d869645e0a0522568df4a5d4d921",
            "运行时不再检出或调用该上游仓库",
        ),
        "Agent runtime 来源记录",
    )

    print("local agentic workflow contracts: PASS")


if __name__ == "__main__":
    main()
