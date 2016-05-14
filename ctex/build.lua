#!/usr/bin/env texlua

module = "ctex"

packtdszip = true

sourcefiles = {"ctex.dtx", "ctexpunct.spa"}
unpackfiles = {"ctex.dtx"}
unpacksuppfiles = {"ctex.id","ctxdocstrip.tex"}
installfiles = {"*.sty", "*.cls", "*.clo", "*.def", "*.cfg", "*.fd", "*.tex", "*.dict"}
unpackexe = "xetex"
typesetexe = "xelatex"
makeindexexe = "zhmakeindex"

gbkfiles = {"ctex-name-gbk.cfg", "*-ChineseGBK.dict"}
generic_insatllfiles = {"*.tex"}
subtexdirs = {
    ["config"] = "*.cfg",
    ["fd"] = "*.fd",
    ["engine"] = "ctex-engine-*.def",
    ["fontset"] = "ctex-fontset-*.def",
    ["scheme"] = "ctex-scheme-*.def",
    ["dictionary"] = "*.dict",
}

function copytds_posthook()
  cp("ctex.ins", unpackdir, ctandir .. "/" .. ctanpkg)
  cp("ctex.ins", unpackdir, tdsdir .. "/source/" .. moduledir)
end

dofile("../tool/zhl3build.lua")

-- vim:sw=2:et
