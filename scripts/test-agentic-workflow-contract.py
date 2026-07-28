#!/usr/bin/env python3
"""离线检查 ctex-kit 本地 Agent workflow 的编排与安全合同。"""

import base64
import json
import importlib.util
import os
import re
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


def top_level_block(source: str, name: str) -> str:
    match = re.search(
        rf"(?ms)^{re.escape(name)}:\n.*?(?=^[A-Za-z0-9_-]+:\n|\Z)",
        source,
    )
    assert match, f"找不到顶层字段: {name}"
    return match.group(0)


def named_step(source: str, name: str) -> str:
    match = re.search(
        rf"(?ms)^      - name: {re.escape(name)}\n.*?(?=^      - name: |\Z)",
        source,
    )
    assert match, f"找不到 step: {name}"
    return match.group(0)


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
    """PR Review 的可信 sparse checkout 必须包含 run-agent 的本地运行时依赖。"""
    action_path = ACTIONS / "run-agent" / "action.yml"
    dependencies: set[str] = set()
    for relative in re.findall(
        r'\$GITHUB_ACTION_PATH/((?:\.\./)+[^"\s\\]+)',
        read(action_path),
    ):
        resolved = (action_path.parent / relative).resolve()
        try:
            dependencies.add(resolved.relative_to(ROOT).as_posix())
        except ValueError as error:
            raise AssertionError(f"run-agent 引用了仓库外路径: {relative}") from error

    assert dependencies, "没有从 run-agent Action 提取到本地运行时依赖"
    document = yaml.safe_load(source)
    for job_name in ("codex_review", "claude_review"):
        steps = document["jobs"][job_name]["steps"]
        checkout = next(
            step
            for step in steps
            if step.get("name") == "Checkout trusted review runtime from base commit"
        )
        sparse_paths = {
            line.strip()
            for line in checkout["with"]["sparse-checkout"].splitlines()
            if line.strip()
        }
        missing = sorted(dependencies - sparse_paths)
        assert not missing, f"PR Review {job_name} 的可信 sparse checkout 缺少 run-agent 依赖: {missing}"


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


def test_action_metadata() -> None:
    validator = ROOT / "scripts" / "validate-action-metadata.py"
    action_paths = tuple(ACTIONS.glob("*/action.yml"))
    run(["python3", str(validator), *(str(path) for path in action_paths)])

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


def test_font_cache_staging() -> None:
    action_path = ACTIONS / "setup-agent-tools" / "action.yml"
    document = yaml.safe_load(read(action_path))
    steps = document["runs"]["steps"]
    step_by_name = {step["name"]: step for step in steps}

    tl_restore_name = "Restore shared TeX Live cache"
    tl_verify_name = "Verify TeX Live installation and mirror on cache miss"
    tl_save_name = "Save trusted TeX Live cache before Agent"
    prepare_name = "Prepare clean font cache staging directories"
    cjk_restore_name = "Restore shared CJK font cache"
    xecjk_restore_name = "Restore xeCJK document font cache"
    cjk_prepare_name = "Prepare CJK font cache"
    cjk_install_name = "Install CJK fonts"
    cjk_validate_name = "Validate prepared CJK font cache before save"
    cjk_save_name = "Save trusted CJK font cache before Agent"
    xecjk_prepare_name = "Prepare xeCJK document font cache"
    xecjk_install_name = "Install xeCJK document fonts"
    xecjk_validate_name = "Validate prepared xeCJK document font cache before save"
    xecjk_save_name = "Save trusted xeCJK document font cache before Agent"
    cleanup_name = "Remove workspace font staging directories"
    names = [step["name"] for step in steps]
    assert names.index(tl_restore_name) < names.index(tl_verify_name) < names.index(tl_save_name)
    assert names.index(tl_save_name) < names.index(prepare_name)
    assert names.index(prepare_name) < names.index(cjk_restore_name)
    assert names.index(prepare_name) < names.index(xecjk_restore_name)
    assert names.index(cjk_restore_name) < names.index(cjk_prepare_name) < names.index(cjk_validate_name)
    assert names.index(cjk_validate_name) < names.index(cjk_install_name) < names.index(cjk_save_name)
    assert names.index(cjk_save_name) < names.index(cleanup_name)
    assert names.index(xecjk_restore_name) < names.index(xecjk_prepare_name) < names.index(xecjk_validate_name)
    assert names.index(xecjk_validate_name) < names.index(xecjk_install_name) < names.index(xecjk_save_name)
    assert names.index(xecjk_save_name) < names.index(cleanup_name)
    assert step_by_name[tl_save_name]["uses"] == "actions/cache/save@v6"
    assert step_by_name[cjk_save_name]["uses"] == "actions/cache/save@v6"
    assert step_by_name[xecjk_save_name]["uses"] == "actions/cache/save@v6"
    assert "steps.tl-cache.outputs.cache-hit != 'true'" in step_by_name[tl_save_name]["if"]
    assert step_by_name[cjk_save_name]["if"] == "steps.font-cache.outputs.cache-hit != 'true'"
    assert step_by_name[xecjk_save_name]["if"] == "steps.xecjk-font-cache.outputs.cache-hit != 'true'"

    with tempfile.TemporaryDirectory(prefix="ctex-font-cache-staging-") as tmp_name:
        tmp = Path(tmp_name)
        workspace = tmp / "workspace"
        external = tmp / "external-xecjk-cache"
        workspace.mkdir()
        external.mkdir()

        cjk_cache = workspace / ".font-cache"
        cjk_cache.mkdir()
        (cjk_cache / ".done").touch()
        (cjk_cache / "Injected.ttc").write_bytes(b"untrusted")

        (external / ".done").touch()
        (external / "Injected.ttf").write_bytes(b"untrusted")
        (workspace / ".xecjk-font-cache").symlink_to(external, target_is_directory=True)

        env = os.environ | {"GITHUB_WORKSPACE": str(workspace)}
        run(
            ["bash", "-euo", "pipefail", "-c", step_by_name[prepare_name]["run"]],
            env=env,
        )

        for path in (workspace / ".font-cache", workspace / ".xecjk-font-cache"):
            assert path.is_dir() and not path.is_symlink(), "restore 目标必须重建为普通目录"
            assert not any(path.iterdir()), "PR 预置的字体 cache 内容必须在 restore 前清空"
        assert (external / "Injected.ttf").exists(), "清理 staging symlink 不得遍历到链接目标"

        cjk_validator = step_by_name[cjk_validate_name]["run"]
        cjk_cache = workspace / ".font-cache"
        (cjk_cache / ".done").touch()
        (cjk_cache / "Injected.ttc").write_bytes(b"untrusted")
        rejected = run(
            ["bash", "-euo", "pipefail", "-c", cjk_validator],
            env=env,
            check=False,
        )
        assert rejected.returncode != 0, "恢复后的 CJK cache 必须拒绝额外字体"
        shutil.rmtree(cjk_cache)
        cjk_cache.mkdir()
        (cjk_cache / ".done").touch()
        (cjk_cache / "NotoSansCJK-Regular.ttc").write_bytes(b"trusted-cache")
        incomplete = run(
            ["bash", "-euo", "pipefail", "-c", cjk_validator],
            env=env,
            check=False,
        )
        assert incomplete.returncode != 0, "CJK cache 必须同时包含黑体和宋体"
        (cjk_cache / "NotoSerifCJK-Regular.ttc").write_bytes(b"trusted-cache")
        run(["bash", "-euo", "pipefail", "-c", cjk_validator], env=env)

        xecjk_validator = step_by_name[xecjk_validate_name]["run"]
        xecjk_cache = workspace / ".xecjk-font-cache"
        (xecjk_cache / ".done").touch()
        (xecjk_cache / "Injected.ttf").write_bytes(b"untrusted")
        rejected = run(
            ["bash", "-euo", "pipefail", "-c", xecjk_validator],
            env=env,
            check=False,
        )
        assert rejected.returncode != 0, "恢复后的 xeCJK cache 必须拒绝额外字体"
        shutil.rmtree(xecjk_cache)
        xecjk_cache.mkdir()
        (xecjk_cache / ".done").touch()
        (xecjk_cache / "HanaMinB.ttf").write_bytes(b"trusted-cache")
        incomplete = run(
            ["bash", "-euo", "pipefail", "-c", xecjk_validator],
            env=env,
            check=False,
        )
        assert incomplete.returncode != 0, "xeCJK 文档 cache 必须同时包含两个指定字体"
        (xecjk_cache / "NotoSansSymbols2-Regular.ttf").write_bytes(b"trusted-cache")
        run(["bash", "-euo", "pipefail", "-c", xecjk_validator], env=env)


def test_model_proxy_contract() -> None:
    proxy_path = ROOT / ".github" / "scripts" / "agentic" / "model-api-proxy.py"
    spec = importlib.util.spec_from_file_location("ctex_model_api_proxy", proxy_path)
    assert spec and spec.loader
    proxy = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(proxy)

    codex_upstream = proxy.parse_upstream("https://example.invalid/v1")
    assert proxy.upstream_target(codex_upstream, "/responses") == "/v1/responses"
    assert proxy.request_is_allowed("codex", "POST", "/responses")
    assert not proxy.request_is_allowed("codex", "POST", "/v1/messages")
    assert proxy.request_is_allowed("claude", "POST", "/v1/messages")
    assert not proxy.request_is_allowed("claude", "CONNECT", "/v1/messages")

    headers = proxy.upstream_headers(
        (
            ("Authorization", "Bearer attacker-controlled"),
            ("x-api-key", "attacker-controlled"),
            ("Content-Type", "application/json"),
            ("X-Forwarded-Host", "attacker.invalid"),
        ),
        "claude",
        "real-secret",
        2,
    )
    assert headers["Authorization"] == "Bearer real-secret"
    assert headers["x-api-key"] == "real-secret"
    assert headers["Content-Length"] == "2"
    assert "X-Forwarded-Host" not in headers


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
    match = re.search(
        r"(?ms)^\s*# BEGIN REVIEW_COMMENT_UPSERT\n(.*?)^\s*# END REVIEW_COMMENT_UPSERT",
        review_source,
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
    scripts = ROOT / ".github" / "scripts" / "agentic"
    package = scripts / "package-change-result.sh"
    publish = scripts / "publish-change.sh"

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

        candidate_repo = tmp / "new-candidate"
        run(["git", "clone", "-q", "--local", str(base_repo), str(candidate_repo)])
        git(candidate_repo, "config", "commit.gpgsign", "false")
        (candidate_repo / "llmdoc" / "index.md").write_text(
            "base\nnew candidate\n", encoding="utf-8"
        )
        result = tmp / "candidate.json"
        result.write_text(json.dumps(candidate_result()), encoding="utf-8")
        artifact = tmp / "artifact"
        run(
            [
                "bash",
                str(package),
                str(result),
                str(candidate_repo),
                str(artifact),
                base_sha,
                "codex",
                "gpt-5.6-sol",
                "update-llmdoc",
            ]
        )

        fake_bin = tmp / "bin"
        fake_bin.mkdir()
        fake_gh = fake_bin / "gh"
        fake_gh.write_text(
            """#!/usr/bin/env python3
import sys

args = sys.argv[1:]
if args == ["auth", "setup-git"]:
    raise SystemExit(0)
if args[:2] == ["pr", "list"]:
    print('[{"number": 7, "url": "https://example.invalid/pr/7", '
          '"body": "<!-- agentic-update-llmdoc:master -->"}]')
    raise SystemExit(0)
raise SystemExit(f"unexpected gh arguments: {args!r}")
""",
            encoding="utf-8",
        )
        fake_gh.chmod(0o755)
        runner_temp = tmp / "runner"
        runner_temp.mkdir()
        env = os.environ | {
            "PATH": f"{fake_bin}:{os.environ['PATH']}",
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


def test_agent_result_channel_sandbox() -> None:
    """仓库进程持续改写时，工作区沙箱外的控制结果必须保持不变。"""
    bwrap = shutil.which("bwrap")
    assert bwrap, "合同门禁需要 bubblewrap 验证 Agent 结果通道的文件系统边界"

    with tempfile.TemporaryDirectory(prefix="ctex-agent-result-channel-") as tmp_name:
        tmp = Path(tmp_name)
        workspace = tmp / "consumer"
        control = tmp / "control"
        workspace.mkdir()
        control.mkdir()
        result = control / "raw-result.json"
        result.write_text('{"source":"model"}\n', encoding="utf-8")
        attack = workspace / "attack.sh"
        attack.write_text(
            textwrap.dedent(
                """\
                #!/usr/bin/env bash
                for _ in {1..100}; do
                  printf '%s\\n' '{"source":"forged"}' > "$1" 2>/dev/null || true
                done
                """
            ),
            encoding="utf-8",
        )
        attack.chmod(0o755)

        attempted = run(
            [
                bwrap,
                "--die-with-parent",
                "--new-session",
                "--ro-bind",
                "/",
                "/",
                "--dev",
                "/dev",
                "--proc",
                "/proc",
                "--bind",
                str(workspace),
                str(workspace),
                "--chdir",
                str(workspace),
                "bash",
                "./attack.sh",
                str(result),
            ],
            check=False,
        )
        assert attempted.returncode == 0, attempted.stderr
        assert json.loads(result.read_text(encoding="utf-8")) == {"source": "model"}, (
            "工作区内的恶意后台进程不得改写沙箱外的 Agent 结果通道"
        )


def test_agent_control_process_hardening() -> None:
    """同 UID 子进程不能通过父 CLI 的 /proc fd 绕过文件系统沙箱。"""
    source = ROOT / ".github" / "scripts" / "agentic" / "agent-control-hardening.c"
    with tempfile.TemporaryDirectory(prefix="ctex-agent-control-hardening-") as tmp_name:
        tmp = Path(tmp_name)
        library = tmp / "agent-control-hardening.so"
        result = tmp / "raw-result.json"
        result.write_text('{"source":"model"}\n', encoding="utf-8")
        run(
            [
                "cc",
                "-shared",
                "-fPIC",
                "-O2",
                "-Wall",
                "-Wextra",
                "-Werror",
                str(source),
                "-o",
                str(library),
            ]
        )
        target = textwrap.dedent(
            """
            import ctypes
            import os
            import subprocess
            import sys

            result = sys.argv[1]
            descriptor = os.open(result, os.O_RDWR)
            parent_fd = f"/proc/{os.getpid()}/fd/{descriptor}"
            attacker = "import os,sys; fd=os.open(sys.argv[1],os.O_WRONLY); os.write(fd,b'forged')"
            probe = subprocess.run([sys.executable, "-c", attacker, parent_fd], capture_output=True)
            dumpable = ctypes.CDLL(None).prctl(3, 0, 0, 0, 0)
            raise SystemExit(0 if dumpable == 0 and probe.returncode != 0 else 1)
            """
        )
        env = os.environ | {"LD_PRELOAD": str(library)}
        run(["python3", "-c", target, str(result)], env=env)
        assert json.loads(result.read_text(encoding="utf-8")) == {"source": "model"}


def main() -> None:
    review = workflow("agentic-pr-review.yml")
    issue = workflow("agentic-issue-dispatch.yml")
    llmdoc = workflow("agentic-llmdoc-updater.yml")
    contract = workflow("check-agentic-workflows.yml")
    setup = read(ACTIONS / "setup-agent-tools" / "action.yml")

    test_action_metadata()
    test_font_cache_staging()
    test_embedded_shell(
        tuple(WORKFLOWS / name for name in AGENTIC_WORKFLOWS)
        + (WORKFLOWS / "check-agentic-workflows.yml",)
        + tuple(ACTIONS.glob("*/action.yml"))
    )
    test_model_proxy_contract()
    test_review_result_semantics(review)
    test_review_comment_upsert(review)
    test_pre_push_bot_comment_audit()
    test_runtime_scripts()
    test_publish_preserves_unmerged_llmdoc_candidate()
    test_agent_result_channel_sandbox()
    test_agent_control_process_hardening()

    assert not (WORKFLOWS / "agentic-patrol.yml").exists(), "定时 patrol 不应恢复"
    for name, source in zip(AGENTIC_WORKFLOWS, (review, issue, llmdoc), strict=True):
        assert_local_runtime(source, name)
        require_all(source, ("permissions: {}", "runs-on: ubuntu-latest"), name)
        for forbidden in ("uses: actions/cache@", "uses: actions/cache/restore@", "uses: actions/cache/save@"):
            assert forbidden not in source, f"{name} 不得在 Agent job 内直接注册 cache action: {forbidden}"

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
                "uses: ./.trusted-base/.github/actions/setup-agent-tools",
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
            "uses: ./.trusted-base/.github/actions/setup-agent-tools",
            "uses: ./.trusted-base/.github/actions/run-agent",
            f"PR Review {name}",
        )

    assert_pr_review_runtime_dependency_closure(review)
    broken_review = review.replace(
        "            .github/scripts/agentic/agent-control-hardening.c\n",
        "",
        1,
    )
    try:
        assert_pr_review_runtime_dependency_closure(broken_review)
    except AssertionError:
        pass
    else:
        raise AssertionError("可信 sparse checkout 缺少 run-agent 运行时依赖的反例必须失败")

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
    assert review.count("uses: ./.trusted-base/.github/actions/setup-agent-tools") == 2
    assert review.count("uses: ./.trusted-base/.github/actions/run-agent") == 2
    require_all(
        review,
        (
            ".github/scripts/agentic/model-api-proxy.py",
            ".github/scripts/agentic/run-agent-with-proxy.sh",
            "ignore_repository_rules: 'true'",
            ".suggestion_count > 0",
        ),
        "PR Review credential and result boundary",
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
                "uses: ./consumer/.github/actions/setup-agent-tools",
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
            "uses: ./consumer/.github/actions/setup-agent-tools",
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
    assert issue.count("uses: ./consumer/.github/actions/setup-agent-tools") == 2
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
                "uses: ./runtime/.github/actions/setup-agent-tools",
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
            "uses: ./runtime/.github/actions/setup-agent-tools",
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
    assert llmdoc.count("uses: ./runtime/.github/actions/setup-agent-tools") == 2
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
    secure_runner = read(ROOT / ".github" / "scripts" / "agentic" / "run-agent-with-proxy.sh")
    require_all(
        runner,
        (
            "Run pinned agent CLI behind root credential proxy",
            "MODEL_API_KEY: ${{ inputs.api_key }}",
            "ctex-agent-trusted-runtime.XXXXXX",
            "install -m 700",
            "install -m 600",
            "agent-control-hardening.c",
            "agent-control-hardening.so",
            "cc -shared -fPIC -O2 -Wall -Wextra -Werror",
            'MODEL_PROXY_SCRIPT="$trusted_runtime/model-api-proxy.py"',
            'CONTROL_HARDENING_LIBRARY="$trusted_runtime/agent-control-hardening.so"',
            'bash "$trusted_runtime/run-agent-with-proxy.sh"',
        ),
        "Agent credential runner",
    )
    require_all(
        secure_runner,
        (
            "useradd --system --create-home --user-group",
            ': "${MODEL_PROXY_SCRIPT:?}"',
            ': "${CONTROL_HARDENING_LIBRARY:?}"',
            "sudo --non-interactive env -i PATH=/usr/bin:/bin LANG=C.UTF-8",
            "sudo --non-interactive -u \"$agent_user\"",
            "env -i",
            "OPENAI_API_KEY=ctex-local-proxy",
            "ANTHROPIC_API_KEY=ctex-local-proxy",
            "test -r \"/proc/$proxy_pid/environ\"",
            "stop_agent_processes",
            "pkill -KILL -u \"$agent_user\"",
            "/run/ctex-agent-session.XXXXXX",
            "--sandbox workspace-write",
            "--ask-for-approval never",
            '"enabled": true',
            '"failIfUnavailable": true',
            '"autoAllowBashIfSandboxed": true',
            '"allowUnsandboxedCommands": false',
            "--permission-mode dontAsk",
            '"LD_PRELOAD=$control_hardening_library"',
            'sudo --non-interactive rm -rf -- "$session_dir"',
            "rm -f -- \"$secret_file\"",
        ),
        "Agent process isolation",
    )
    for leaked in (
        'export OPENAI_API_KEY="$API_KEY"',
        'export ANTHROPIC_API_KEY="$API_KEY"',
        'Authorization: Bearer $API_KEY',
    ):
        assert leaked not in runner + secure_runner, f"Agent 子进程不得直接继承模型密钥: {leaked}"
    assert "GITHUB_ACTION_PATH" not in secure_runner, "安全启动脚本不得在交出工作区后继续依赖工作区路径"
    assert "$agent_home/raw-result.json" not in secure_runner
    assert "--dangerously-bypass-approvals-and-sandbox" not in secure_runner
    assert "--dangerously-skip-permissions" not in secure_runner

    # 三类缓存都在 Agent 启动前恢复；未命中时由可信安装阶段显式保存。
    # 不能改用会在 Agent 返回后运行 post step 的合并式 actions/cache。
    assert setup.count("uses: actions/cache/restore@v6") == 3
    assert setup.count("uses: actions/cache/save@v6") == 3
    assert "uses: actions/cache@" not in setup, "Agent job 不得注册 post-job cache save"
    require_all(
        setup,
        (
            "tl-bypass-${{ runner.os }}-${{ inputs.tl-version }}-${{ steps.tl-cache-key.outputs.week }}-${{ hashFiles(inputs.tl-package-file) }}",
            "ctex-kit-fonts-${{ runner.os }}-${{ hashFiles(inputs.font-url-file) }}-v1",
            "xecjk-fonts-${{ runner.os }}-hanaminB-notoSymbols2-v1",
            "cache: false",
            "Save trusted TeX Live cache before Agent",
            "Save trusted CJK font cache before Agent",
            "Save trusted xeCJK document font cache before Agent",
            "procps",
            "python3-yaml",
            "bubblewrap",
            "gcc",
            "socat",
            "rm -rf -- \"$GITHUB_WORKSPACE/.font-cache\" \"$GITHUB_WORKSPACE/.xecjk-font-cache\"",
        ),
        "Agent tool cache",
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
    trigger = top_level_block(contract, "on")
    require_all(
        trigger,
        (
            "- '.githooks/pre-push'",
            "- '.githooks/check-pr-ci.sh'",
        ),
        "Agent workflow contract trigger paths",
    )
    shellcheck_step = named_step(contract, "Lint Agent shell scripts")
    require_all(
        shellcheck_step,
        (
            "shellcheck",
            ".githooks/pre-push",
            ".githooks/check-pr-ci.sh",
            ".github/scripts/agentic/*.sh",
            ".github/scripts/pr-review/prepare-review-history.sh",
        ),
        "Agent workflow ShellCheck inputs",
    )

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
