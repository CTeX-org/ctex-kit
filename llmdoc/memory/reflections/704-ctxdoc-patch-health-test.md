# Reflection: Issue #704 ctxdoc patch 健康检查测试

## 背景

为 `support/ctxdoc.cls` 新增 patch 健康检查测试并接入 CI，目标是让 `ctxdoc` 对上游 LaTeX2e / l3kernel 结构变化导致的 patch 失效能够在回归测试和持续集成中第一时间暴露，而不是在文档构建时静默退化。

## 关键发现

### 1. `checksuppfiles` 对 check 目标是必需的

`support/ctxdoc.cls` 不在 `ctex/` 模块自己的源文件目录里，而是在仓库共享的 `support/` 目录下。为 `ctex/test/config-ctxdoc.lua` 新增专项测试时，若只设置 `testfiledir = "./test/testfiles-ctxdoc"`，`l3build check` 不会自动把 `ctxdoc.cls` 复制到 check 目录，测试会退回到系统安装版本或直接找不到文件。

因此，测试配置必须显式加入：

- `checksuppfiles = {"ctxdoc.cls"}`

这样才能保证 check 阶段使用仓库中的本地 `support/ctxdoc.cls`，真正覆盖当前补丁实现。

### 2. `typesetsuppfiles` 不能替代 `checksuppfiles`

一开始容易把 `ctxdoc.cls` 归类为“文档支持文件”，直觉上想到 `typesetsuppfiles`。但实际验证后确认：

- `typesetsuppfiles` 只在 `doc` / 排版目标生效
- `check` 目标不会复制 `typesetsuppfiles`

因此，对回归测试来说，`typesetsuppfiles` 不能替代 `checksuppfiles`。凡是测试依赖 `support/` 目录或其他模块外部支持文件时，都要优先检查是否需要在对应 `config-*.lua` 中补 `checksuppfiles`。

### 3. `\msg_error` 在 nonstop 模式下不会终止编译

patch 健康检查的目标不是“输出一条错误信息”，而是“让测试失败”。实践中发现，若 patch 失败仍使用 `\msg_error`，在 CI 默认的 nonstop / batch 型运行模式下，TeX 会继续编译，导致：

- patch 失败被记录在日志里
- 但构建流程未必以失败结束
- 回归测试不能稳定把失效 patch 识别为真正失败

因此，`support/ctxdoc.cls` 中相关 patch 失败路径必须升级为 `\msg_critical`，包括 expl3 层 `\ctex_patch_failure:N` 与 LaTeX2e 包装层 `\ctxdoc@patchfail`。只有这样，patch 失效时才能可靠终止编译，让 l3build 与 CI 都把它视为失败。

## 影响到的稳定认知

- 为 `support/` 目录下的共享类/宏包写 l3build check 测试时，需要显式考虑 support 文件是否会被复制进 check 目录。
- `check` 与 `doc` 的支持文件复制机制不同，不能假设排版能找到的文件在回归测试里也自动可见。
- 对“必须让 CI 立刻红灯”的失败条件，`\msg_error` 级别不够，需要使用 `\msg_critical`。

## 建议复用点

未来若再为 `support/` 下的共享基础设施补测试，可直接复用这次模式：

1. 单独建立 `config-*.lua` 测试配置
2. 用 `checksuppfiles` 显式复制共享支持文件
3. 在 `.lvt` 中优先消除字体等环境依赖（如 `fontset=fandol`）
4. 对 patch 健康检查类失败，优先验证其在 nonstop 模式下是否真的会终止编译
