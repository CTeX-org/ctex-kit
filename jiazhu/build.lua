
module = "jiazhu"

packtdszip = true

sourcefiles      = {"jiazhu.dtx"}
unpackfiles      = {"jiazhu.dtx"}
installfiles     = {"*.sty"}
unpacksuppfiles  = {"jiazhu.id", "ctxdocstrip.tex"}
typesetsuppfiles = {"ctxdoc.cls"}

dofile("../support/build-config.lua")
