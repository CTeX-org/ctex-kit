---
name: "782-mac15plus-ci-os-gated-smoke-test"
description: "反思: macOS 专属字体问题需要 CI 级 OS 条件 smoke test 覆盖"
type: reflection
---

## 反思

- macOS-specific 的字体或系统 API 问题，往往无法在 Linux/Windows 或本地 fontconfig 环境中稳定复现；如果只依赖通用平台回归，很容易误判为“问题已不可复现”。
- 对这类依赖系统字体可见性、Core Text/LuaTeX 行为差异的场景，应该在 CI 中增加按操作系统门控的测试步骤，直接在目标 runner 上验证。
- shell 级编译 smoke test 不走 l3build `.tlg` 基线比对，更适合检查“能否成功加载字体集并完成编译”这类跨平台字体差异问题；它是回归测试矩阵之外的一种补充，而不是替代。
