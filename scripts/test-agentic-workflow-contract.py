#!/usr/bin/env python3
"""离线检查 ctex-kit 本地 Agent workflow 的编排与安全合同。"""

import json
import importlib.util
import os
import re
import subprocess
import tempfile
from pathlib import Path


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


def main() -> None:
    review = workflow("agentic-pr-review.yml")
    issue = workflow("agentic-issue-dispatch.yml")
    llmdoc = workflow("agentic-llmdoc-updater.yml")
    contract = workflow("check-agentic-workflows.yml")
    setup = read(ACTIONS / "setup-agent-tools" / "action.yml")

    test_action_metadata()
    test_embedded_shell(
        tuple(WORKFLOWS / name for name in AGENTIC_WORKFLOWS)
        + (WORKFLOWS / "check-agentic-workflows.yml",)
        + tuple(ACTIONS.glob("*/action.yml"))
    )
    test_model_proxy_contract()
    test_review_result_semantics(review)
    test_runtime_scripts()

    assert not (WORKFLOWS / "agentic-patrol.yml").exists(), "定时 patrol 不应恢复"
    for name, source in zip(AGENTIC_WORKFLOWS, (review, issue, llmdoc), strict=True):
        assert_local_runtime(source, name)
        require_all(source, ("permissions: {}", "runs-on: ubuntu-latest"), name)

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
                "test -z \"$(git -C consumer status --porcelain --untracked-files=all)\"",
            ),
            f"Issue Agent {name}",
        )
        assert_no_write_permission(source, f"Issue Agent {name}")
        assert "secrets.PAT_TOKEN" not in source, f"Issue Agent {name} 不得接触可写 PAT"
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
                "runtime/.claude/skills/update-llmdoc/SKILL.md",
            ),
            f"llmdoc Agent {name}",
        )
        assert_no_write_permission(source, f"llmdoc Agent {name}")
        assert "secrets.PAT_TOKEN" not in source, f"llmdoc Agent {name} 不得接触可写 PAT"
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
            'MODEL_PROXY_SCRIPT="$trusted_runtime/model-api-proxy.py"',
            'bash "$trusted_runtime/run-agent-with-proxy.sh"',
        ),
        "Agent credential runner",
    )
    require_all(
        secure_runner,
        (
            "useradd --system --create-home --user-group",
            ': "${MODEL_PROXY_SCRIPT:?}"',
            "sudo --non-interactive env -i PATH=/usr/bin:/bin LANG=C.UTF-8",
            "sudo --non-interactive -u \"$agent_user\"",
            "env -i",
            "OPENAI_API_KEY=ctex-local-proxy",
            "ANTHROPIC_API_KEY=ctex-local-proxy",
            "test -r \"/proc/$proxy_pid/environ\"",
            "pkill -KILL -u \"$agent_user\"",
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

    # 安装 Action 与现有 CI 共享 key，但 Agent 只能 restore，不能回写共享缓存。
    assert setup.count("uses: actions/cache/restore@v6") == 3
    for forbidden in ("uses: actions/cache@", "actions/cache/save"):
        assert forbidden not in setup, f"Agent 工具缓存必须只读: {forbidden}"
    require_all(
        setup,
        (
            "tl-bypass-${{ runner.os }}-${{ inputs.tl-version }}-${{ steps.tl-cache-key.outputs.week }}-${{ hashFiles(inputs.tl-package-file) }}",
            "ctex-kit-fonts-${{ runner.os }}-${{ hashFiles(inputs.font-url-file) }}-v1",
            "xecjk-fonts-${{ runner.os }}-hanaminB-notoSymbols2-v1",
            "cache: false",
            "procps",
            "python3-yaml",
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

    # 合同 workflow 本身必须随所有本地 runtime 输入变化而运行，并执行 actionlint。
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
