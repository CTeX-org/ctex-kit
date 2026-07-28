#!/usr/bin/env python3
"""校验本仓库复合 Action metadata 的结构和受支持字段。"""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Any

import yaml


TOP_LEVEL_KEYS = {"name", "author", "description", "inputs", "outputs", "runs", "branding"}
INPUT_KEYS = {"description", "required", "default", "deprecationMessage"}
OUTPUT_KEYS = {"description", "value"}
RUNS_KEYS = {"using", "steps"}
# GitHub 只在复合 Action 的 step 上支持这些字段。多写字段（例如 job step 才有的
# timeout-minutes）会让 runner 在加载 action.yml 时报 TemplateValidationException，
# 整个调用步骤直接失败，所以这里必须是精确白名单。
STEP_KEYS = {
    "id",
    "if",
    "name",
    "run",
    "shell",
    "uses",
    "with",
    "env",
    "working-directory",
    "continue-on-error",
}
# 这些字段在 job step 合法、在复合 Action step 非法，容易被顺手抄进来。
JOB_ONLY_STEP_KEYS = {"timeout-minutes"}
BRANDING_KEYS = {"color", "icon"}


def mapping(value: Any, location: str, errors: list[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        errors.append(f"{location} 必须是 mapping")
        return {}
    if not all(isinstance(key, str) for key in value):
        errors.append(f"{location} 的所有 key 必须是字符串")
    return value


def reject_unknown_keys(
    value: dict[str, Any], allowed: set[str], location: str, errors: list[str]
) -> None:
    unknown = sorted(str(key) for key in value if key not in allowed)
    if unknown:
        errors.append(f"{location} 含未知字段：{', '.join(unknown)}")


def nonempty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value)


def scalar(value: Any) -> bool:
    return isinstance(value, (str, int, float, bool))


def validate_action(path: Path) -> list[str]:
    errors: list[str] = []
    try:
        document = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as error:
        return [f"YAML 解析失败：{error}"]
    action = mapping(document, str(path), errors)
    reject_unknown_keys(action, TOP_LEVEL_KEYS, str(path), errors)

    for key in ("name", "description"):
        if not nonempty_string(action.get(key)):
            errors.append(f"{path}.{key} 必须是非空字符串")
    if "author" in action and not nonempty_string(action["author"]):
        errors.append(f"{path}.author 必须是非空字符串")

    inputs = mapping(action.get("inputs", {}), f"{path}.inputs", errors)
    for input_id, raw_input in inputs.items():
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_-]*", str(input_id)):
            errors.append(f"{path}.inputs 的名称不合法：{input_id}")
        location = f"{path}.inputs.{input_id}"
        input_metadata = mapping(raw_input, location, errors)
        reject_unknown_keys(input_metadata, INPUT_KEYS, location, errors)
        if "description" in input_metadata and not nonempty_string(input_metadata["description"]):
            errors.append(f"{location}.description 必须是非空字符串")
        if "required" in input_metadata and not isinstance(input_metadata["required"], bool):
            errors.append(f"{location}.required 必须是布尔值")
        if "default" in input_metadata and not scalar(input_metadata["default"]):
            errors.append(f"{location}.default 必须是标量")
        if "deprecationMessage" in input_metadata and not nonempty_string(
            input_metadata["deprecationMessage"]
        ):
            errors.append(f"{location}.deprecationMessage 必须是非空字符串")

    outputs = mapping(action.get("outputs", {}), f"{path}.outputs", errors)
    for output_id, raw_output in outputs.items():
        location = f"{path}.outputs.{output_id}"
        output = mapping(raw_output, location, errors)
        reject_unknown_keys(output, OUTPUT_KEYS, location, errors)
        if "description" in output and not nonempty_string(output["description"]):
            errors.append(f"{location}.description 必须是非空字符串")
        if not nonempty_string(output.get("value")):
            errors.append(f"{location}.value 必须是非空字符串")

    runs = mapping(action.get("runs"), f"{path}.runs", errors)
    reject_unknown_keys(runs, RUNS_KEYS, f"{path}.runs", errors)
    if runs.get("using") != "composite":
        errors.append(f"{path}.runs.using 必须精确为 composite")
    steps = runs.get("steps")
    if not isinstance(steps, list) or not steps:
        errors.append(f"{path}.runs.steps 必须是非空列表")
        steps = []
    for index, raw_step in enumerate(steps):
        location = f"{path}.runs.steps[{index}]"
        step = mapping(raw_step, location, errors)
        job_only = sorted(str(key) for key in step if key in JOB_ONLY_STEP_KEYS)
        if job_only:
            errors.append(
                f"{location} 含仅 job step 支持的字段，复合 Action 会被 runner 拒绝："
                f"{', '.join(job_only)}"
            )
        reject_unknown_keys(step, STEP_KEYS | JOB_ONLY_STEP_KEYS, location, errors)
        has_run = "run" in step
        has_uses = "uses" in step
        if has_run == has_uses:
            errors.append(f"{location} 必须且只能包含 run 或 uses 之一")
        if has_run:
            if not nonempty_string(step["run"]):
                errors.append(f"{location}.run 必须是非空字符串")
            if not nonempty_string(step.get("shell")):
                errors.append(f"{location}.shell 必须是非空字符串")
        if has_uses:
            if not nonempty_string(step["uses"]):
                errors.append(f"{location}.uses 必须是非空字符串")
            for forbidden in ("shell", "working-directory"):
                if forbidden in step:
                    errors.append(f"{location} 的 uses 步骤不得包含 {forbidden}")
        for key in ("env", "with"):
            if key in step:
                mapping(step[key], f"{location}.{key}", errors)

    if "branding" in action:
        branding = mapping(action["branding"], f"{path}.branding", errors)
        reject_unknown_keys(branding, BRANDING_KEYS, f"{path}.branding", errors)
        for key in ("color", "icon"):
            if key in branding and not nonempty_string(branding[key]):
                errors.append(f"{path}.branding.{key} 必须是非空字符串")
    return errors


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: validate-action-metadata.py ACTION_YML...", file=sys.stderr)
        return 2
    failed = False
    for raw_path in sys.argv[1:]:
        path = Path(raw_path)
        errors = validate_action(path)
        if errors:
            failed = True
            for error in errors:
                print(f"{path}: {error}", file=sys.stderr)
    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
