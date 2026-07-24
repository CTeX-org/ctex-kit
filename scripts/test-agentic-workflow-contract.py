#!/usr/bin/env python3
"""离线检查 ctex-kit 的 Agent reusable workflow caller 契约。"""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"
TEMPLATE = "Lightspeed-Intelligence/agentic-workflow-template/.github/workflows"
TEMPLATE_REF = "00a5244ea6150ef6a4c43b680d15d73dafabd343"


def read(name: str) -> str:
    return (WORKFLOWS / name).read_text(encoding="utf-8")


def require_all(source: str, fragments: tuple[str, ...], label: str) -> None:
    missing = [fragment for fragment in fragments if fragment not in source]
    assert not missing, f"{label} 缺少合同片段: {missing}"


def main() -> None:
    assert re.fullmatch(r"[0-9a-f]{40}", TEMPLATE_REF), "模板引用必须是完整提交 SHA"

    issue = read("agentic-issue-dispatch.yml")
    llmdoc = read("agentic-llmdoc-updater.yml")
    review = read("agentic-pr-review.yml")
    contract = read("check-agentic-workflows.yml")

    assert not (WORKFLOWS / "agentic-patrol.yml").exists(), "定时 patrol 不应继续存在"

    require_all(
        issue,
        (
            "issues:\n    # 只监听 opened",
            "types: [opened]",
            "group: issue-dispatch-${{ github.event.issue.number }}",
            "cancel-in-progress: false",
            "issues: write",
            "if: github.repository == 'CTeX-org/ctex-kit'",
            f"uses: {TEMPLATE}/issue-dispatch.yml@{TEMPLATE_REF}",
            "ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}",
            "ANTHROPIC_BASE_URL: ${{ secrets.ANTHROPIC_BASE_URL }}",
            "PAT_TOKEN: ${{ secrets.PAT_TOKEN }}",
            "FEISHU_WEBHOOK_TOKEN: ${{ secrets.FEISHU_WEBHOOK_TOKEN }}",
            "use_feishu_notify: true",
        ),
        "Issue 分派 caller",
    )
    assert "schedule:" not in issue, "Issue 分派不应保留周期巡检触发"
    assert "workflow_dispatch:" not in issue, "手动事件没有 Issue 上下文，不能触发分派"
    assert "runs-on:" not in issue and "anthropics/" not in issue

    require_all(
        llmdoc,
        (
            "cron: '0 21 * * *'",
            "workflow_dispatch:",
            "group: agentic-llmdoc-updater-${{ github.repository }}",
            "cancel-in-progress: false",
            "if: github.repository == 'CTeX-org/ctex-kit'",
            f"uses: {TEMPLATE}/update-llmdoc.yml@{TEMPLATE_REF}",
            "ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}",
            "ANTHROPIC_BASE_URL: ${{ secrets.ANTHROPIC_BASE_URL }}",
            "PAT_TOKEN: ${{ secrets.PAT_TOKEN }}",
            "FEISHU_WEBHOOK_TOKEN: ${{ secrets.FEISHU_LLMDOC_WEBHOOK_TOKEN }}",
            "since_period: ${{ inputs.since_period || '24 hours ago' }}",
            "target_branch: master",
        ),
        "llmdoc caller",
    )
    for obsolete in ("prepare-llmdoc", "gh pr close", "runs-on:", "anthropics/"):
        assert obsolete not in llmdoc, f"llmdoc caller 不应保留本地编排: {obsolete}"
    assert "issues: write" not in llmdoc, "llmdoc caller 不需要 Issue 写权限"

    require_all(
        review,
        (
            "pull_request_target:",
            f"uses: {TEMPLATE}/pr-review.yml@{TEMPLATE_REF}",
        ),
        "PR Review caller",
    )

    for caller in (issue, llmdoc, review):
        require_all(
            caller,
            (
                "contents: write",
                "pull-requests: write",
                "id-token: write",
            ),
            "Agent caller 权限",
        )

    require_all(
        contract,
        (
            "permissions:\n  contents: read",
            "if: github.repository == 'CTeX-org/ctex-kit'",
            "persist-credentials: false",
            "run: python3 scripts/test-agentic-workflow-contract.py",
        ),
        "caller 合同门禁",
    )

    print("agentic workflow caller contracts: PASS")


if __name__ == "__main__":
    main()
