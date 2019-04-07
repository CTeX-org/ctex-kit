#!/usr/bin/env texlua

module = "xcjk2uni"

packtdszip = true

sourcefiles = {"xCJK2uni.dtx"}
unpackfiles = {"xCJK2uni.dtx"}
unpacksuppfiles = {"xCJK2uni.id", "ctxdocstrip.tex"}
typesetsuppfiles = {"ctxdoc.cls"}
installfiles = {"*.sty", "xCJK2uni-U*.def", "*.cmap"}
unpackexe = "luatex"
typesetexe = "xelatex"

subtexdirs = {
  ["cmap"] = "*.cmap",
}

dofile("../tool/zhl3build.lua")

-- vim:sw=2:et
