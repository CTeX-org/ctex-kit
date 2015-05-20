#!/usr/bin/env texlua

module = "xpinyin"

packtdszip = true

gitverfiles = {"xpinyin.dtx"}
sourcefiles = {"xpinyin.dtx", "xpinyin.ins"}
unpackfiles = {"xpinyin.ins"}
unpacksuppfiles = {"xpinyin.ver", "xpinyin.db"}
installfiles = {"*.sty", "*.def"}
unpackexe = "luatex"
typesetexe = "xelatex"

function unpack_prehook()
  cleandir(unpackdir)
  os.execute(unpackexe .. " -output-directory=" .. unpackdir .." xpinyin.dtx > " .. os_null)
  cp("xpinyin.ins", unpackdir, ".")
  mkdir(supportdir)
  cp("xpinyin.lua", unpackdir, supportdir)
  run(supportdir, "texlua xpinyin.lua")
end

function unpack_posthook()
  os.remove("xpinyin.ins")
end

function copytds_posthook()
  cp("xpinyin.ins", unpackdir, tdsdir .. "/source/" .. moduledir)
  cp("xpinyin.ins", unpackdir, ctandir .. "/" .. ctanpkg)
end

dofile("../tool/zhl3build.lua")

-- vim:sw=2:et
