
module = "zhnumber"

packtdszip = true

sourcefiles      = {"zhnumber.dtx"}
unpackfiles      = {"zhnumber.dtx"}
installfiles     = {"*.sty", "*.cfg", "*.ins"}
unpacksuppfiles  = {"zhnumber.id", "ctxdocstrip.tex", "zhconv.lua", "zhconv-index.lua"}
typesetsuppfiles = {"ctxdoc.cls"}

tdslocations = {
  "source/latex/zhnumber/*.ins",
}

dofile("../support/build-config.lua")
