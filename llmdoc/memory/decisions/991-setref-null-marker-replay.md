# 决策：#991 在 `\@setref` 的 `\null` 后重放实际末尾 marker

## 背景

LaTeX 内核 `\@setref` 在已定义的引用文本后排出 `\null`。这个 0×0 hbox 保留内核语义，却遮住 xeCJK 在引用末尾产生的 kern pair marker；后续字符因而不能按引用实际输出类别恢复间距。引用值可以是数字、西文、CJK 或混合内容，单凭命令名不能推断末尾类别。

## 决策

v3.10.4 采用调用点 fixed-point save/replay，并保留原 hbox：

- xeCJK 加载 `ctexpatch`，在导言区末尾精确把 `\null \fi` 替换为 xeCJK wrapper 加原 `\fi`。
- 无 hyperref 时补丁 `\@setref`；存在 `\real@setref` 时补丁这个由 hyperref 保存的内核副本，覆盖 starred `\ref` / `\pageref`。
- wrapper 在文本模式用 Boundary 转换取得并验证引用的真实末尾 marker，清空旧全局状态，排出原 `\null`，越过内部 `\fi` 后再重放 marker。
- 保存的末尾为 `CJK` 且后接源码空格时，消费该空格并改发 `CJK-space`，对齐直接输入语义。
- 数学模式和未定义引用保持内核原路径。

## 未采用的方案

- **硬编码 `Default` 后 drain**：只能覆盖数字/西文引用，会破坏 CJK 输出和混合末尾，违背 #992 的 output-equivalence oracle。
- **删除或替换 `\null` 的内核语义**：hbox 可能被其他内核或宏包逻辑依赖；本问题只需移动 xeCJK marker 的可观察位置。
- **把任意 hbox 当作可恢复边界**：#803 一类经验表明通用恢复会把无证据节点误判为合法边界；补丁应固定在已知遮蔽点。
- **始终补丁 `\@setref`**：hyperref 会保存并改写引用调用链，starred 路径实际使用 `\real@setref`；补错绑定无法覆盖目标路径。

## 支持边界与验证

`ref-ecglue01/02` 用 36+40 个 direct-input oracle 覆盖无 hyperref 与 starred hyperref 引用的输出类别、外围类别和源码空格组合；`label-ref01` 与 `thuthesis` 的节点基线锁定 hbox/marker 新顺序。hyperref 的普通 linked-reference 路径没有这枚尾随 `\null`，不由本决策泛化，继续由 #992 按精确单元追踪。

## 相关

- 架构：`llmdoc/architecture/xecjk-architecture.md`「命令边界的输出等价契约」
- 测试方法：`llmdoc/reference/build-and-test.md`「xeCJK 命令边界矩阵」
- 前置决策：`llmdoc/memory/decisions/873-880-fixed-point-vs-default-narrowing.md`
- Issues：#991、#992
