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


def assert_bubblewrap_runner_setup(setup_source: str, contract_source: str) -> None:
    """Agent job 和独立合同 job 都必须先打开并实测未特权 user namespace。"""
    setup_document = yaml.safe_load(setup_source)
    setup_steps = unique_steps_by_name(setup_document["runs"]["steps"], "Agent 工具 Action")
    contract_document = parse_workflow(contract_source)
    contract_steps = unique_steps_by_name(
        contract_document["jobs"]["contract"]["steps"],
        "Agent 合同 workflow",
    )
    expected_script = (
        "set -euo pipefail\n"
        "if [[ -e /proc/sys/kernel/apparmor_restrict_unprivileged_userns ]]; then\n"
        "  sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0\n"
        "fi\n"
        "if [[ -e /proc/sys/kernel/unprivileged_userns_clone ]]; then\n"
        "  sudo sysctl -w kernel.unprivileged_userns_clone=1\n"
        "fi\n"
        "bwrap --unshare-net --die-with-parent --new-session \\\n"
        "  --ro-bind / / --dev /dev --proc /proc /usr/bin/true\n"
    )

    for label, steps in (
        ("Agent 工具 Action", setup_steps),
        ("Agent 合同 workflow", contract_steps),
    ):
        step = steps.get("Enable and verify Bubblewrap sandbox")
        assert step is not None, f"{label} 缺少 Bubblewrap runner 准备步骤"
        script = step.get("run", "")
        assert script == expected_script, f"{label} 必须逐字使用受控的 Bubblewrap runner 准备脚本"


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


def assert_pr_instruction_isolation(
    review_source: str,
    action_source: str,
    runner_source: str,
) -> None:
    """PR head 只能作为显式审查目录，不能提供 CLI 项目指令或改写可信规范。"""
    document = parse_workflow(review_source)
    for job_name in ("codex_review", "claude_review"):
        steps = unique_steps_by_name(document["jobs"][job_name]["steps"], f"PR Review {job_name}")
        prompt = steps["Prepare trusted review inputs"].get("run", "")
        require_all(
            prompt,
            (
                "@@TRUSTED_INSTRUCTION_DIR@@/pr-review.md",
                "@@TRUSTED_INSTRUCTION_DIR@@/github-comment.md",
            ),
            f"PR Review {job_name} prompt",
        )
        assert "$GITHUB_WORKSPACE/.trusted-base/.claude/skills/" not in prompt, (
            f"PR Review {job_name} prompt 不得在 Agent 运行时读取已移交所有权的 base checkout"
        )
        agent_step = next(step for step in steps.values() if step.get("uses", "").endswith("/run-agent"))
        inputs = agent_step.get("with", {})
        assert inputs.get("ignore_repository_rules") == "true"
        assert inputs.get("trusted_review_skill_file") == (
            "${{ github.workspace }}/.trusted-base/.claude/skills/pr-review/SKILL.md"
        )
        assert inputs.get("trusted_comment_skill_file") == (
            "${{ github.workspace }}/.trusted-base/.claude/skills/github-comment/SKILL.md"
        )

    require_all(
        action_source,
        (
            "trusted_review_skill_file:",
            "trusted_comment_skill_file:",
            'test -f "$TRUSTED_REVIEW_SKILL_FILE" && test ! -L "$TRUSTED_REVIEW_SKILL_FILE"',
            'test -f "$TRUSTED_COMMENT_SKILL_FILE" && test ! -L "$TRUSTED_COMMENT_SKILL_FILE"',
            'trusted_instruction_dir="$trusted_runtime/review-instructions"',
            'TRUSTED_INSTRUCTION_DIR="$trusted_instruction_dir"',
        ),
        "run-agent 可信规范副本",
    )
    assert action_source.count('install -m 444 "$TRUSTED_') == 2, "两份可信规范都必须复制为只读文件"
    require_all(
        runner_source,
        (
            'agent_root="$session_dir/work-root"',
            'test -w "$trusted_path"',
            'test -w "$TRUSTED_INSTRUCTION_DIR"',
            's|@@TRUSTED_INSTRUCTION_DIR@@|$TRUSTED_INSTRUCTION_DIR|g',
            'codex_args+=(--cd "$agent_root" --add-dir "$CONSUMER_WORKSPACE" --ignore-rules)',
            "--bare",
        ),
        "Agent 仓库指令隔离",
    )


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
    test_publish_recovers_llmdoc_branch_states()
    test_agent_result_channel_sandbox()
    test_agent_control_process_hardening()
    assert_bubblewrap_runner_setup(setup, contract)
    for broken_setup, broken_contract, label in (
        (
            setup.replace(
                "sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0",
                "# sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0",
                1,
            ),
            contract,
            "Agent 工具 Action 把 AppArmor user namespace 命令改成注释",
        ),
        (
            setup,
            contract.replace(
                "bwrap --unshare-net --die-with-parent --new-session",
                "# bwrap --unshare-net --die-with-parent --new-session",
                1,
            ),
            "合同 workflow 把 Bubblewrap 探针主命令改成注释",
        ),
        (
            setup.replace(
                "bwrap --unshare-net --die-with-parent --new-session \\",
                "bwrap --unshare-net --die-with-parent --new-session \\ # 探针续行失效",
                1,
            ),
            contract,
            "Agent 工具 Action 用转义空格破坏 Bubblewrap 探针续行",
        ),
    ):
        try:
            assert_bubblewrap_runner_setup(broken_setup, broken_contract)
        except AssertionError:
            pass
        else:
            raise AssertionError(f"{label}的反例必须失败")

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
    assert_pr_instruction_isolation(review, runner, secure_runner)
    for broken_review, broken_action, broken_runner, label in (
        (
            review,
            runner,
            secure_runner.replace(
                'codex_args+=(--cd "$agent_root" --add-dir "$CONSUMER_WORKSPACE" --ignore-rules)',
                'codex_args+=(--cd "$CONSUMER_WORKSPACE" --ignore-rules)',
                1,
            ),
            "Codex 回到不可信 PR 根目录",
        ),
        (
            review,
            runner.replace("install -m 444", "install -m 644"),
            secure_runner,
            "可信审查规范变为可写",
        ),
        (
            review.replace(
                "@@TRUSTED_INSTRUCTION_DIR@@/pr-review.md",
                "$GITHUB_WORKSPACE/.trusted-base/.claude/skills/pr-review/SKILL.md",
                1,
            ),
            runner,
            secure_runner,
            "prompt 重新读取 Agent 可写的 base checkout",
        ),
    ):
        try:
            assert_pr_instruction_isolation(broken_review, broken_action, broken_runner)
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
