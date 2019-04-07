#!/usr/bin/env texlua

module = "zhnumber"

packtdszip = true

sourcefiles = {"zhnumber.dtx"}
unpackfiles = {"zhnumber.dtx"}
unpacksuppfiles = {"zhnumber.id", "ctxdocstrip.tex"}
typesetsuppfiles = {"ctxdoc.cls"}
installfiles = {"*.sty", "*.cfg"}
unpackexe = "xetex"
typesetexe = "xelatex"

gbkfiles = {"zhnumber-gbk.cfg"}
big5files = {"zhnumber-big5.cfg"}

dofile("../tool/zhl3build.lua")

-- vim:sw=2:et
