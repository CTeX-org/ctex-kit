
module = "zhnumber"

packtdszip = true

sourcefiles      = {"zhnumber.dtx"}
unpackfiles      = {"zhnumber.dtx"}
installfiles     = {"*.sty", "*.cfg", "*.ins"}
unpacksuppfiles  = {"zhnumber.id", "ctxdocstrip.tex", "ctex-zhconv.lua", "ctex-zhconv-index.lua"}
typesetsuppfiles = {"ctxdoc.cls"}

tdslocations = {
  "source/latex/zhnumber/*.ins",
}

dofile("../support/build-config.lua")
