#!/usr/bin/env texlua

module = "xpinyin"

packtdszip = true

gitverfiles = {"xpinyin.dtx"}
sourcefiles = {"xpinyin.dtx", "xpinyin.ins"}
unpackfiles = {"xpinyin.ins"}
unpacksuppfiles = {"xpinyin.id", "xpinyin.db", "ctxdocstrip.tex"}
typesetsuppfiles = {"ctxdoc.cls"}
installfiles = {"*.sty", "*.def"}
unpackexe = "luatex"
typesetexe = "xelatex"

function unpack_prehook()
  cleandir(unpackdir)
  cp("ctxdocstrip.tex", supportdir, ".")
  os.execute(unpackexe .. " -output-directory=" .. unpackdir .." xpinyin.dtx > " .. os_null)
  os.remove("ctxdocstrip.tex")
  cp("xpinyin.ins", unpackdir, ".")
  cp("xpinyin.lua", unpackdir, supportdir)
  run(supportdir, "texlua xpinyin.lua")
end

function unpack_posthook()
  os.remove("xpinyin.ins")
end

function copytds_posthook()
  cp("xpinyin.ins", unpackdir, ctandir .. "/" .. ctanpkg)
  cp("xpinyin.ins", unpackdir, tdsdir .. "/source/" .. moduledir)
end

dofile("../tool/zhl3build.lua")

-- vim:sw=2:et
