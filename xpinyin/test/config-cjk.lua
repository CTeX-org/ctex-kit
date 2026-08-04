-- (pdf)LaTeX / CJKutf8 路线的测试配置.
--
-- 为什么要单独一个 config 而不是把这些 .lvt 放进主 testfiles/:
-- `l3build check` 会把 testfiledir 下的每个 .lvt 拿去跑 checkengines 里的
-- **每一个**引擎, 没有「按文件指定引擎」的机制. 主目录的用例要 xeCJK (XeTeX),
-- 本目录的用例要 CJKutf8 (pdfTeX), 混在一起会互相拿对方的引擎跑,
-- 缺基线直接报 "failed to find any reference or expectation file".
--
-- 这与 ctex/test/config-cmap.lua、config-ctxdoc.lua 的做法一致: 引擎需求不同的
-- 测试各自一个 config + 一个目录.
--
-- checkdeps 显式清空: 本路线不加载 xeCJK, 不需要把它的产物复制进测试目录.
-- 主 build.lua 的 checkinit_hook 遍历 checkdeps, 这里为空即自然不复制.

testfiledir  = "./testfiles-cjk"
stdengine    = "pdftex"
checkengines = {"pdftex"}
checkdeps    = { }
