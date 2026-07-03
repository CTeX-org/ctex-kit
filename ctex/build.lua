module              = "ctex"
version             = "2.6.1"

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
  "ctex.id", "ctxdocstrip.tex", "ctex-zhconv.lua", "ctex-zhconv-index.lua"
}
typesetfiles        = {module .. ".dtx"}
typesetsuppfiles    = {"ctxdoc.cls"}
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
dofile("../support/build-config.lua")
bundleunpack = function (...)
  unpack_prehook()
  local retval = unhooked_bundleunpack(...)
  is_unpacked = true
  unpack_posthook()
  return retval
end

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
function update_tag(file, content, tagname, tagdate)
  local tagname = version
  for _, tag in ipairs(sourcefiles) do
    local tagtarget = string.gsub(tag, "%-", "%%-")
    local tagdateid =
      io.popen("git log -1 --pretty=format:'%ai %h %an <%ae>' " .. tag):
      read('*l')
    local tagdateid = string.gsub(tagdateid, "%%", "%%%%")
    if string.match(tagtarget, "%.dtx$") then
      content = string.gsub(content,
        "%%<%+!driver>\\GetIdInfo $Id: " .. tagtarget .. " " ..
        "%d+%.%d+%.%d+ %d+%-%d+%-%d+ (.-)%$",
        "%%<+!driver>\\GetIdInfo $Id: "  .. tag       .. " " ..
        tagname .. " " .. tagdateid ..   "$")
    end
  end
  return content
end
