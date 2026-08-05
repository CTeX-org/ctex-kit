
module = "xpinyin"

-- 发版事实源. 与 xpinyin.dtx 里紧跟 `{\ExplFileDate}` 之后那个参数必须一致
-- (即 `{\ExplFileDate}{3.1}` 中的 `3.1`; \ExplFileDate 本身是日期槽位,
--  \ProvidesExplPackage 的参数顺序是 文件名／日期／版本／说明):
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
-- ctex/build.lua 里写的是本包 installfiles, 那里能正常工作纯属巧合 —— ctex 自己
-- 的 installfiles 恰好覆盖了各依赖的运行时产物类型 (注意并非字面意义的超集:
-- ctex 只有 ct*.tex／zh*.tex, 接不住 xeCJK 的 *.tex, 因此漏掉 xunicode-symbols.tex
-- 与 12 个 xeCJK-example-*.tex; 那些是手册示例, 不影响运行时).
-- 照抄到 xpinyin 就出错了: 本包是 {"*.sty","*.def","*.ins"}, 而 xeCJK 还装
-- "*.cfg"; 于是 xeCJK.sty 用的是工作树版本, xeCJK.cfg 却仍命中系统 TeX Live
-- (实测日志两者路径不同, 且系统那份是 v3.10.4、工作树是 v3.10.5,
-- `\GetIdInfo` 与版本号行都不一样), 恰好破坏本钩子声称要消除的
-- 「测的其实是本机装了什么」.
-- 依赖包的配置由 loadfile 在独立环境里读取 (不是 dofile —— 后者在全局环境执行,
-- 既无法隔离也无法用 pcall 兜住), 而不是硬编码一份清单; 硬编码会在依赖包新增
-- 产物类型时再次静默漏掉.
checkinit_hook = function()
  for _, dep in ipairs(checkdeps) do
    local dep_unpackdir = dep .. "/" .. unpackdir
    -- 在独立环境里读依赖包的 build.lua, 取它自己的 installfiles.
    -- 空 dep_env 里 require／dofile／io／os 全为 nil, 被读的 chunk 无法产生
    -- 文件系统或全局状态影响.
    local dep_env = { }
    local chunk, load_err = loadfile(dep .. "/build.lua", "t", dep_env)
    local dep_installfiles, run_err
    if chunk then
      -- 依赖包的 build.lua 末尾会 dofile 共享配置, 在这个空环境里必然跑不通
      -- (xeCJK 现在是停在 require("zip")). 这是**预期**的: installfiles 在那之前
      -- 就已赋值, 所以正常情况下不打印任何东西 —— 每次 check 都无条件打一行
      -- 「预期行为」只会训练读者忽略它, 真出问题时新错误淹在同一位置.
      -- 错误对象留到下面的失败分支里一起报, 信息不丢且零噪声.
      local ok, err = pcall(chunk)
      if not ok then run_err = err end
      dep_installfiles = dep_env.installfiles
    else
      run_err = load_err
    end
    -- 两道**拒绝**判据 (非表、空表). 上面那个 pcall 错误不是判据 —— 它不拒绝
    -- 任何东西, 只是在这两道判据触发时提供线索.
    -- 实测: 空表与「分步构造、中途出错」两种情形都能通过只判 type 的旧守卫,
    -- 一个文件不复制或只复制一半却毫无提示 —— 那与本钩子刚修掉的
    -- 「只隔离了一半」是同一种症状. 空表现已拒绝; 残缺表仍会通过 (见文档中
    -- 「已接受的缺口」).
    local function fail(reason)
      error(("checkinit_hook: %s (依赖 %s)%s"):format(
        reason, dep,
        run_err and ("; 读取该 build.lua 时的错误: " .. tostring(run_err)) or ""))
    end
    if type(dep_installfiles) ~= "table" then
      fail(("未能读到 installfiles, 得到 %s, 依赖产物会漏复制")
        :format(type(dep_installfiles)))
    end
    if #dep_installfiles == 0 then
      fail("读到的 installfiles 为空表, 依赖产物一个都不会被复制")
    end
    for _, glob in ipairs(dep_installfiles) do
      -- 必须检查 cp 的返回值: l3build 的 cp 在 mkdir 或底层 cp/xcopy 失败时返回
      -- 非零 errorlevel. 丢掉它的话, 复制失败后 checkinit_hook 仍 `return 0`,
      -- check 照常往下跑, 然后拿系统 TeX Live 那份去测 —— 又是「测的其实是本机
      -- 装了什么」. 与另外两个已接受缺口不同, 这条不需要预设依赖包的写法,
      -- 也不会在正常环境下触发 (本机四类产物均复制成功).
      -- 注意 glob 零匹配不算失败: cp 对空 tree 返回 nil, 见下面的 `or 0`
      -- (xeCJK 的 *.map／*.tec 在 check 阶段就是零匹配, 属已接受缺口之二).
      local cp_err = cp(glob, dep_unpackdir, testdir) or 0
      if cp_err ~= 0 then
        fail(("复制 %s 从 %s 到 %s 失败 (errorlevel %s)")
          :format(glob, dep_unpackdir, testdir, tostring(cp_err)))
      end
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
