#!/usr/bin/env texlua

bundle = ""
module = "zhspacing"

packtdszip  = true
tdsroot     = "generic"

unpackfiles  = { }
installfiles = {"*.sty", "t-zhspacing.tex"}
sourcefiles  = installfiles
typesetfiles = {"zhs-man.tex"}
demofiles    = {"zhspacing-context-test.tex"}
typesetexe   = "xelatex"

context_insatllfiles = {"t-zhspacing.tex"}
xelatex_insatllfiles = {"zhfont.sty", "zhulem.sty"}

dofile("../tool/zhl3build.lua")
