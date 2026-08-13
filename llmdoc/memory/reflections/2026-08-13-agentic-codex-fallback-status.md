# 反思：Codex 主链路失败时保持工作流可判别（2026-08-13）

本轮三条 Agent workflow（PR Review、Issue Dispatch、llmdoc Updater）统一处理了一个稳定的运行语义：Codex 主链路可能因 CLI 或结构化结果校验失败，由独立 runner 上的 Claude fallback 接手；这种失败不应单独把主链路 job 标成红色，但也绝不能被 `continue-on-error` 静默吞掉。

## 形成的合同

- Codex CLI 及其结果规范化／导入／打包步骤按链路带 `continue-on-error: true`，随后由 `if: always()` 的汇总步骤检查各步骤的 `outcome`，写出 `status=success|failure` 到 `$GITHUB_OUTPUT`，失败时使用 `::warning::` 和 step summary 记录原因。
- 所有下游条件必须读取 `needs.<codex-job>.outputs.status`，不能再读 `needs.<codex-job>.result`。启用 `continue-on-error` 后，后者通常仍是 `success`，不再具有判别力；llmdoc Updater 的候选生成和独立校验各自导出状态，fallback 与 publisher 必须同时判断两者。
- 只有两条链路都失败时，最终 publisher／dispatch job 才以非零状态结束。这样把“主链路异常”和“整体无法产出结果”分成两个层次，异常仍可在 annotation、summary 和 fallback 结果中追踪。

`scripts/test-agentic-workflow-contract.py` 对三条工作流统一检查上述 output、步骤标记、汇总来源和所有下游条件，并用反例验证删除 output、去掉 `continue-on-error` 或退回 `.result` 时确实失败。以后新增 Codex→fallback 链路时，应复用这一组合同，而不是只把主步骤改成可忽略失败。

## 运行参数变化

`.github/actions/run-agent` 中 Codex 的默认 endpoint 已改为 `https://api.openai.com`（仍由 `OPENAI_BASE_URL` 显式覆盖），并在生成的 `config.toml` 中固定 `service_tier = "priority"` 与 `model_reasoning_effort = "high"`。这属于运行时默认值，修改时要同步检查三条 workflow 的输入传递和合同测试。

## 可复用教训

1. `continue-on-error` 改变的不只是显示颜色，还改变了下游可用的状态信号；任何这种改动都必须穷举所有 `needs.<job>.result` 的读取点。
2. 失败降级应保留可检索的 warning／summary，并由最终汇总 job 决定整体退出码；否则“fallback 成功”和“整个流程没有结果”会混为一谈。
3. 合同测试的反例必须覆盖新状态通道本身，尤其要验证删除状态 output 后不会意外假绿。
