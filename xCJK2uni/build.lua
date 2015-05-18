#!/usr/bin/env texlua

module = "xcjk2uni"

packtdszip = true

sourcefiles = {"xCJK2uni.dtx"}
unpackfiles = {"xCJK2uni.dtx"}
unpacksuppfiles = {"xCJK2uni.ver"}
installfiles = {"*.sty", "xCJK2uni-U*.def", "*.cmap"}
unpackexe = "luatex"
typesetexe = "xelatex"

subtexdirs = {
  ["cmap"] = "*.cmap",
}

function copytds_posthook()
  -- ins 文件
  cp("xCJK2uni.ins", unpackdir, tdsdir .. "/source/" .. moduledir)
end

dofile("../tool/zhl3build.lua")

-- vim:sw=2:et
