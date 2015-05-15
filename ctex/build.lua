#!/usr/bin/env texlua

module = "ctex"

packtdszip = true

sourcefiles = {"ctex.dtx", "ctexpunct.spa"}
unpackfiles = {"ctex.dtx"}
unpacksuppfiles = {"ctex.ver"}
installfiles = {"*.sty", "*.cls", "*.clo", "*.def", "*.cfg", "*.fd", "zh*.tex", "ctex*spa*.tex"}
unpackexe = "xetex"
typesetexe = "xelatex"
makeindexexe = "zhmakeindex"

gbkfiles = {"ctex-name-gbk.cfg"}
generic_insatllfiles = {"zh*.tex", "ctex*spa*.tex"}
subtexdirs = {
    ["config"] = "*.cfg",
    ["fd"] = "*.fd",
    ["engine"] = "ctex-engine-*.def",
    ["fontset"] = "ctex-fontset-*.def",
    ["scheme"] = "ctex-scheme-*.def",
}

dofile("../tool/zhl3build.lua")

-- vim:sw=2:et
