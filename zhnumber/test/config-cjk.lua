-- 需要真正排出汉字的测试单独一个 config.
--
-- 为什么不能放进主 testfiles/: `l3build check` 会把 testfiledir 下的每个 .lvt
-- 拿去跑 checkengines 里的**每一个**引擎, 没有「按文件指定引擎」的机制. 主目录
-- 的用例只做数值与记号层面的断言, 三个引擎通吃; 而本目录的用例要实际把汉字排进
-- 盒子里 —— 那需要中文字体, 只有 XeTeX 路线能直接用 fontspec 载入.
--
-- 混在一起会怎样: pdfTeX 下排 CJK 是硬错误
-- (`Unicode character ... not set up for use with LaTeX') 并中止编译, 而 XeTeX
-- 下只是 `Missing character' 警告 —— 同一个 .lvt 的两个引擎基线会分化成「报错」
-- 与「警告」两种不可共存的结果, 且前者让其后用例静默不执行.
--
-- 做法与 xpinyin/test/config-cjk.lua、ctex/test/config-*.lua 一致.
testfiledir  = "./testfiles-cjk"
stdengine    = "xetex"
checkengines = {"xetex"}
