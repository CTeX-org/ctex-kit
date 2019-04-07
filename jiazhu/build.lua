#!/usr/bin/env texlua

module = "jiazhu"

packtdszip = true

sourcefiles = {"jiazhu.dtx"}
unpackfiles = {"jiazhu.dtx"}
unpacksuppfiles = {"jiazhu.id", "ctxdocstrip.tex"}
typesetsuppfiles = {"ctxdoc.cls"}
installfiles = {"*.sty"}
unpackexe = "xetex"
typesetexe = "xelatex"

dofile("../tool/zhl3build.lua")

-- vim:sw=2:et
