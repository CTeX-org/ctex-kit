# 717 experiment CJKecglue Reflection

## Task
- 记录 ctex Issue #717 的实现经验：为不同引擎提供统一的「汉英文间胶长设定」接口，并将其以实验性 key `experiment/CJKecglue` 暴露给用户。

## Expected vs Actual
- 预期结果：用户能在 `ctex` 层通过一个统一 key 传入 skip 值，由各引擎后端分别映射到 XeTeX、LuaTeX、upTeX 的既有机制；pdfTeX 明确给出不支持信号，而不是伪装成可用。
- 实际结果：实现最终通过 `ctex` keypath 下新增 `experiment` 子路径完成，并在 `CJKecglue` key 中按引擎分派：XeTeX 把 skip 值包装成 `\skip_horizontal:n {#1}` 交给 `xeCJKsetup`，LuaTeX/upTeX 同时更新 `\l_@@_xkanjiskip_tl` 与 `\l_@@_xkanjiskip_skip` 后立即写回引擎原语，pdfTeX 输出 warning。接口可用，但其跨引擎行为并不完全同构，因此被明确标记为实验性。

## What Went Wrong
- 最容易踩坑的地方是误把“统一接口”理解成“统一底层语义”。实际上四个引擎里只有三条后端路径存在对应概念，而且 XeTeX 的 `xeCJK` 接口接收的是命令序列，不是纯 skip 值；若直接把用户输入原样塞给 `xeCJKsetup`，接口表面统一了，实质却没有对齐参数契约。
- 另一个隐蔽点是 LuaTeX/upTeX 不能只改当前原语值。`ctex` 自身已有 `\ctex_update_xkanjiskip:` 在 `\selectfont` 路径中按“缓存值是否匹配当前引擎值”决定是否重算；若新 key 只更新原语，不同步内部 tl/skip 缓存，后续字体切换会把新设置冲掉，形成“设置当下有效、选字体后失效”的伪成功。
- 测试层面也不能只保存一份通用 `.tlg`。四个引擎的日志观察点不同：XeTeX 看到的是 `xeCJK` 路径，LuaTeX 看 `ltjgetparameter`，upTeX 看 `\xkanjiskip`，pdfTeX 则只能验证 warning/跳过行为。若沿用单基线思路，很容易把“引擎输出本来就不同”误判为实现不一致。

## Root Cause
- 根因是这个需求天然跨越了“用户接口一致”与“底层能力不一致”两层：`ctex` 需要抽象出一个统一入口，但其后端分别落在 xeCJK、luatexja/upTeX 原语与 pdfTeX 的缺失能力上，本质上不是一个完全可同构封装的功能。
- 同时，`ctex` 对 xkanjiskip 已经存在一套内部状态源与 `\selectfont` 守卫机制；新接口若只关注立即写回效果，而忽略内部缓存的持续一致性，就会破坏现有更新链的约束。

## Missing Docs or Signals
- 缺少一份稳定文档说明 `ctex` 下“实验性 key 的命名空间模式”以及何时应放进 `experiment/`，何时应直接进入主 keypath。这次实现实际确立了 `ctex / experiment` 的子路径模式，但此前没有成文约束。
- 缺少一份面向维护者的说明，明确 `xkanjiskip` 相关状态至少有“用户输入 tl”“缓存 skip”“引擎当前原语值”三层，新增接口必须同时考虑 `\ctex_update_xkanjiskip:` 的守卫逻辑，而不能只改其中一层。
- 测试文档虽然已有多引擎基线原则，但还可以更明确地点出：当同一接口在不同引擎故意暴露不同观察面时，应主动预期需要 `.luatex.tlg`、`.uptex.tlg`、`.pdftex.tlg` 等专属基线，而不是事后把它们当成例外。

## Promotion Candidates
- 可提升到 `guides/` 或 `reference/`：`ctex` 新增实验性接口时，应优先采用 `ctex / experiment` 子路径，而不是把能力边界尚不稳定的 key 直接放进主命名空间。
- 可提升到 `reference/`：涉及 `xkanjiskip` 的新接口或修复时，必须同时同步 `\l_@@_xkanjiskip_tl`、`\l_@@_xkanjiskip_skip` 与当前引擎原语，避免被后续 `\selectfont` 更新链回滚。
- 可提升到 `reference/build-and-test.md`：像 `CJKecglue` 这类跨引擎统一接口，只要底层观测值不同，就应在设计测试时直接按四引擎拆分基线，而不是先假设单基线可复用。
- 仅保留在 memory：本次 XeTeX 侧通过 `\skip_horizontal:n {#1}` 把 skip 值转成 xeCJK 可接受命令序列，这属于该接口的具体桥接技巧，后续若 xeCJK 自身接口变化，未必值得固化成长期稳定文档。

## Follow-up
- 下一步应在稳定文档中补一条 `experiment/` 子路径模式与 `xkanjiskip` 三层状态约束，便于后续继续扩展实验性跨引擎接口时复用，而不必重新从实现中逆向总结。
