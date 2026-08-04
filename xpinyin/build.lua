
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
--
-- 复制清单必须取**依赖包自己的** installfiles, 不能用本包的.
-- ctex/build.lua 里写的是本包 installfiles, 那里能work纯属巧合 —— ctex 自己的
-- installfiles 恰好是各依赖的超集. 照抄到 xpinyin 就出错了: 本包是
-- {"*.sty","*.def","*.ins"}, 而 xeCJK 还装 "*.cfg"; 于是 xeCJK.sty 用的是工作树
-- 版本, xeCJK.cfg 却仍命中系统 TeX Live (实测日志两者路径不同, 且系统那份是
-- v3.10.3、工作树是 v3.10.5, `\GetIdInfo` 与版本号行都不一样),
-- 恰好破坏本钩子声称要消除的「测的其实是本机装了什么」.
-- 依赖包的配置由 dofile 读取, 而不是硬编码一份清单 —— 后者会在依赖包新增产物
-- 类型时再次静默漏掉.
checkinit_hook = function()
  for _, dep in ipairs(checkdeps) do
    local dep_unpackdir = dep .. "/" .. unpackdir
    -- 在独立环境里读依赖包的 build.lua, 取它自己的 installfiles.
    local dep_env = { }
    local chunk = loadfile(dep .. "/build.lua", "t", dep_env)
    local dep_installfiles
    if chunk then
      -- 依赖包的 build.lua 末尾会 dofile 共享配置, 在这个空环境里跑不通;
      -- pcall 兜住, 只要 installfiles 已经赋值就够用.
      pcall(chunk)
      dep_installfiles = dep_env.installfiles
    end
    if type(dep_installfiles) ~= "table" then
      error("checkinit_hook: 无法从 " .. dep ..
            "/build.lua 读到 installfiles, 依赖产物会漏复制")
    end
    for _, glob in ipairs(dep_installfiles) do
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
