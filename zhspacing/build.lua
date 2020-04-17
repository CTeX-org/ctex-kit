
module = "zhspacing"

packtdszip  = true
tdsroot     = "generic"

unpackfiles  = { }
sourcefiles  = {"*.sty", "t-zhspacing.tex"}
installfiles = sourcefiles
typesetfiles = {"zhs-man.tex"}
docfiles     = {"zhspacing-context-test.tex"}
typesetexe   = "xelatex"

tdslocations = {
  "tex/xelatex/zhspacing/zhfont.sty",
  "tex/xelatex/zhspacing/zhulem.sty",
  "tex/context/third/zhspacing/t-zhspacing.tex",
}
