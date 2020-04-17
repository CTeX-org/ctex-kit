
module = "xcjk2uni"

packtdszip = true

sourcefiles      = {"xCJK2uni.dtx"}
unpackfiles      = {"xCJK2uni.dtx"}
installfiles     = {"*.sty", "xCJK2uni-U*.def", "*.cmap"}
unpacksuppfiles  = {"xCJK2uni.id", "ctxdocstrip.tex"}
typesetsuppfiles = {"ctxdoc.cls"}

tdslocations = {
  "tex/latex/xcjk2uni/*.cmap",
}

dofile("../support/build-config.lua")
