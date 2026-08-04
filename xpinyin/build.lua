
module = "xpinyin"

-- 发版事实源. 与 xpinyin.dtx 的 `{\ExplFileDate}{...}` 必须一致:
--   * 本地发版流程: 改这里 -> `l3build tag` 回写 .dtx -> commit;
--   * PR 校验 check-tag.yml 跑 `l3build tag` 后要求 git diff 为零;
--   * release.yml 打 tag 时校验 git tag / version / .dtx 三方一致.
-- 回写由 support/build-config.lua 的共享 update_tag 完成 (与 xeCJK 同一套,
-- 见 #1041); 它同时覆盖 `{\ExplFileDate}{<ver>}` 与
-- `[<日期> v<ver> ...]` 两种写法 — xpinyin.dtx 两处都有
-- (`\ProvidesExplPackage` 与 `xpinyin-database.def` 的 `\ProvidesFile`).
version = "3.1"

packtdszip = true

sourcefiles      = {"xpinyin.dtx", "xpinyin.ins"}
unpackfiles      = {"xpinyin.ins"}
gitverfiles      = {"xpinyin.dtx"}
installfiles     = {"*.sty", "*.def", "*.ins"}
unpacksuppfiles  = {"xpinyin.id", "xpinyin.db", "ctxdocstrip.tex"}
typesetsuppfiles = {"ctxdoc.cls"}

-- 回归测试 (#1041 的后续: 该包此前只靠 `l3build doc` 编得过手册来间接验证).
--
-- 引擎选择由包自己的支持面决定, 不是抽样: xpinyin.dtx 用
-- `bool_lazy_or:nnF { xetex } { pdftex }` 把 luatex 挡在
-- `\msg_critical:nn` 上 (实测 lualatex 直接以 "Engine `luatex' is not yet
-- supported" 中止), 所以只有 xetex 与 pdftex 两条路线 —— 而两条都必须测:
-- 包内是 \@@_adjust_xeCJK_hook: 与 \@@_adjust_CJK_hook: 两套**互不复用**的
-- 适配 (字体选择、码位转换、接管 \CJKsymbol 的方式都不同), 只测 xetex 会让
-- CJKutf8 那一半零覆盖.
--
-- 两条路线**不能共用一个 testfiledir**: `l3build check` 把目录下每个 .lvt 都拿去
-- 跑 checkengines 里的每一个引擎, 没有按文件指定引擎的机制. 主目录的用例要
-- xeCJK (XeTeX), CJKutf8 的用例要 pdfTeX, 混在一起会互相拿对方的引擎跑并因缺基线
-- 报 "failed to find any reference or expectation file".
-- 因此 pdfTeX 那条线放在 test/config-cjk.lua + testfiles-cjk/ 里,
-- 跑法是 `l3build check -c test/config-cjk` (仿 ctex/test/config-*.lua 的做法).
testfiledir  = "./testfiles"
stdengine    = "xetex"
checkengines = {"xetex"}

-- xeCJK 是 XeTeX 路线的运行时依赖: 用工作树里的版本, 而不是系统 TeX Live
-- 里装的那个, 否则测的其实是本机装了什么, 跨机器不可复现.
checkdeps    = {"../xeCJK"}

tdslocations = {
  "source/latex/xpinyin/*.ins",
}

-- 光声明 checkdeps **不会**让测试用到依赖包的产物 —— 它只保证依赖包先被
-- unpack, 产物留在依赖包自己的 build/unpacked/ 里, kpse 搜不到, 于是
-- `\usepackage{xeCJK}` 照旧命中系统 TeX Live 的版本 (实测: 不加本钩子时
-- 测试日志里的路径是 texmf-dist/tex/xelatex/xecjk/xeCJK.sty).
-- 必须像 ctex/build.lua 那样手工把产物复制进本包的测试目录.
checkinit_hook = function()
  for _, dep in ipairs(checkdeps) do
    local dep_unpackdir = dep .. "/" .. unpackdir
    for _, glob in ipairs(installfiles) do
      cp(glob, dep_unpackdir, testdir)
    end
  end
  return 0
end

function unpack_prehook()
  cleandir(unpackdir)
  cp("ctxdocstrip.tex",  supportdir, currentdir)
  os.execute(unpackexe .. " -output-directory=" .. unpackdir .." xpinyin.dtx > " .. os_null)
  rmfile(".", "ctxdocstrip.tex")
  cp("xpinyin.ins", unpackdir, currentdir)
  cp("xpinyin.lua", unpackdir, supportdir)
  run(supportdir, "texlua xpinyin.lua")
end

function unpack_posthook()
  rmfile(currentdir, "ctxdocstrip.tex")
  rmfile(currentdir, "xpinyin.ins")
end

dofile("../support/build-config.lua")
