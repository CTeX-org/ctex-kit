# 文档缺口

## luatex/uptex CJKglue touched 检测缺陷

luatex/uptex 的 `\ctex_if_ccglue_touched:` 检测机制中 `\l_@@_ccglue_skip` 未初始化，导致该分支无法正确判断用户是否已设置 CJKglue。Issue #761 修复仅覆盖 pdftex/xetex，luatex/uptex 需理解 luatexja 等包的初始化时序后另行处理。相关决策见 `llmdoc/memory/decisions/761-ccglue-override.md`。
