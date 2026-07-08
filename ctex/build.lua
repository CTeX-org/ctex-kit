module              = "ctex"
version             = "2.6.2"

--[==========================================================================[--
    Configuration: Check, Tag, Pack, Upload     Do NOT Modify if Unnecessary
--]==========================================================================]--
packtdszip          = true
sourcefiles         = {
  module .. ".dtx",         module .. "-kernel.dtx",  module .. "-engine.dtx",
  module .. "-scheme.dtx",  module .. "-auxpkg.dtx",  module .. "-fontset.dtx",
  "ctexpunct.spa"
}
unpackfiles         = {module .. ".dtx"}
installfiles        = {
  "*.ins", "*.sty",   "*.cls",   "*.clo",  "*.def", "*.cfg",
  "*.fd",  "ct*.tex", "zh*.tex", "*.dict", "*.lua"
}
unpacksuppfiles     = {
  "ctxdocstrip.tex", "ctex-zhconv.lua", "ctex-zhconv-index.lua"
}
typesetfiles        = {module .. ".dtx"}
typesetsuppfiles    = {"ctxdoc.cls"}
-- 手册排版依赖本仓库的 xeCJK (PoZheHaoLigature 等新特性)。
typesetdeps         = {"../xeCJK"}
gitverfiles         = {"ctxdoc.cls"}
testfiledir         = "./test/testfiles"
testsuppdir         = "./test/support"
testdir             = "./build/check"
checkruns           = 2
stdengine           = "xetex"
checkdeps           = {"../xeCJK", "../zhnumber"}
checkengines        = {"pdftex", "xetex", "luatex", "uptex"}
specialformats      = {}
specialformats.latex= {
  pdftex = {format = "latex"},
  uptex  = {binary = "euptex"}
}
-- unfortunately cleveref is incompatible with recent LaTeX2e
excludetests   = {
  "cleveref02",
  "cleveref03",
}
tdslocations = {
  "source/latex/ctex/*-make.lua",
  "source/latex/ctex/*.ins",
  "tex/generic/ctex/zhmap/ctex-zhmap*.tex",
  "tex/generic/ctex/*.tex",
  "tex/latex/ctex/config/*.cfg",
  "tex/latex/ctex/fd/*.fd",
  "tex/latex/ctex/engine/ctex-engine-*.def",
  "tex/latex/ctex/fontset/ctex-fontset-*.def",
  "tex/latex/ctex/heading/ctex-heading-*.def",
  "tex/latex/ctex/scheme/ctex-scheme-*.def",
  "tex/latex/ctex/dictionary/*.dict",
  "tex/luatex/ctex/*.lua",
}

--[================== "Hacks" to `l3build` | Do not Modify ==================]--
function unpack_posthook()
  if install_files_bool then
    for _,i in ipairs{"ctxdoc.cls", "ctxdocstrip.tex", "ctex-zhconv*.lua"} do
      cp(i, supportdir, unpackdir)
    end
  end
end
function copyctan_posthook()
  local dest = ctandir .. "/" .. ctanpkg
  for _,file in ipairs{"ctxdocstrip.tex", "ctex-zhconv.lua", "ctex-zhconv-make.lua"} do
    cp(file, unpackdir, dest)
  end
end
checkinit_hook = function()
  for _,i in ipairs(checkdeps) do
    local unpackdir = i .. "/" .. unpackdir
    for _,i in ipairs(installfiles) do
      cp(i, unpackdir, testdir)
    end
  end
  return 0
end
-- dep_install 只把 typesetdeps 产物放进 dep 自己的 build/local, kpse 搜
-- 不到, 需要仿照 checkinit_hook 手动复制进本包的 localdir。
docinit_hook = function()
  for _,i in ipairs(typesetdeps) do
    local dep_unpackdir = i .. "/" .. unpackdir
    cp("*.sty", dep_unpackdir, localdir)
  end
  return 0
end
dofile("../support/build-config.lua")

--[==========================================================================[--
    CTAN upload                     在 CI 中 用 release-ctan-upload.yml 触发
    版本号定义在此文件, 并通过命令行执行 `l3build tag` 自动更新到相关 dtx 中
    Uploader/Email 移动至 CI: GitHub UI 填写后在 `l3build upload` 命令行注入
--]==========================================================================]--
uploadconfig = ctex_kit_uploadconfig {
  pkg         = "ctex",
  version     = version,
  author      = "Leo Liu; Qing Lee; Liam Huang",
  summary     = "LaTeX classes and packages for Chinese typesetting",
  description = "ctex is a bundle of LaTeX classes and packages for "
             .. "typesetting documents in Chinese. It works with the "
             .. "(pdf)LaTeX, XeLaTeX and LuaLaTeX engines, supports "
             .. "GB2312 / UTF-8 / Unicode input, integrates Chinese "
             .. "punctuation kerning, multi-engine font configuration, "
             .. "and provides Chinese-style section heading commands "
             .. "for the standard article / book / report classes.",
  ctanPath    = "/language/chinese/ctex",
}
-- l3build tag 回写 5 个拆分 .dtx 的 `%<+!driver>\GetIdInfo $Id: ...$` 行.
-- update_tag 由 l3build 逐 tagfile 调用, `file` 即当前文件 basename.
--
-- 幂等性设计: stamp 里的版本号已经等于本文件顶部的 `version` 时**原样保留**
-- (不动 date/sha), 只有版本号不一致 (即发新版 bump 了 version 还没 stamp)
-- 才回写, date/sha 取该 dtx 的 `git log -1`. 若不做这个守卫, stamp 会追着
-- commit 跑: 每次 commit stamp 更新本身就产生新 sha, 下次 tag 又想写新
-- sha, 永不收敛 -- check-tag.yml CI 的 "l3build tag 后 diff 必须为零"
-- 检查就永远 fire.
function update_tag(file, content, tagname, tagdate)
  if not string.match(file, "%.dtx$") then return content end
  local tagname = version
  local filetarget = string.gsub(file, "%-", "%%-")
  -- 现 stamp 的版本号 == version 时跳过, 保证幂等.
  local stamped = content:match(
    "%%<%+!driver>\\GetIdInfo $Id: " .. filetarget .. " (%d+%.%d+%.%w+) ")
  if stamped == tagname then return content end
  local tagdateid = io.popen(
    "git log -1 --pretty=format:'%ai %h %an <%ae>' " .. file):read('*l') or ""
  tagdateid = string.gsub(tagdateid, "%%", "%%%%")
  content   = string.gsub(content,
    "%%<%+!driver>\\GetIdInfo $Id: " .. filetarget .. " " ..
    "%d+%.%d+%.%w+ %d+%-%d+%-%d+ (.-)%$",
    "%%<+!driver>\\GetIdInfo $Id: "  .. file       .. " " ..
    tagname .. " " .. tagdateid ..   "$")
  if string.match(file, module .. "%.dtx$") then
    local tagdocrev = io.popen(
      "git log -1 --format='%h' *.dtx"):read('*l') or ""
    content = string.gsub(content,
      "%% \\GetFileId%[%w+%]", "%% \\GetFileId[" .. tagdocrev .. "]")
  end
  return content
end
