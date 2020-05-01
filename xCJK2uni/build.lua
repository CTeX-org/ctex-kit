
module = "xcjk2uni"

packtdszip = true

sourcefiles      = {"xCJK2uni.dtx"}
unpackfiles      = {"xCJK2uni.dtx"}
installfiles     = {"*.sty", "xCJK2uni-U*.def", "*.cmap", "*.ins"}
unpacksuppfiles  = {"xCJK2uni.id", "ctxdocstrip.tex"}
typesetsuppfiles = {"ctxdoc.cls"}

tdslocations = {
  "source/latex/xcjk2uni/*.ins",
  "tex/latex/xcjk2uni/cmap/*.cmap",
}

dofile("../support/build-config.lua")
