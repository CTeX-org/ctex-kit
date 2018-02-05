#!/usr/bin/env texlua

module = "xgezhu"

packtdszip = true

sourcefiles = {"xgezhu.dtx"}
unpackfiles = {"xgezhu.dtx"}
unpacksuppfiles = {"xgezhu.id", "ctxdocstrip.tex"}
typesetsuppfiles = {"ctxdoc.cls"}
installfiles = {"*.sty"}
unpackexe = "xetex"
typesetexe = "xelatex"

function copytds_posthook()
  cp("xgezhu.ins", unpackdir, ctandir .. "/" .. ctanpkg)
  cp("xgezhu.ins", unpackdir, tdsdir .. "/source/" .. moduledir)
end

dofile("../tool/zhl3build.lua")

-- vim:sw=2:et
