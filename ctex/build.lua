#!/usr/bin/env texlua

module = "ctex"

packtdszip = true

sourcefiles = {"ctex.dtx", "ctexpunct.spa"}
unpackfiles = {"ctex.dtx"}
unpacksuppfiles = {"ctex.id","ctxdocstrip.tex"}
installfiles = {"*.sty", "*.cls", "*.clo", "*.def", "*.cfg", "*.fd", "*.tex", "*.dict"}
unpackexe = "xetex"
typesetexe = "xelatex"
makeindexexe = "zhmakeindex"

gbkfiles = {"ctex-name-gbk.cfg", "*-ChineseGBK.dict"}
generic_insatllfiles = {"*.tex"}
subtexdirs = {
    ["config"] = "*.cfg",
    ["fd"] = "*.fd",
    ["engine"] = "ctex-engine-*.def",
    ["fontset"] = "ctex-fontset-*.def",
    ["scheme"] = "ctex-scheme-*.def",
    ["dictionary"] = "*.dict",
}

function setversion_update_line (line, date, version)
  local left, right = line:match([[^(%%%b<>  {\ExplFileDate}{).-(}{.+})$]])
  if left and right then
    local line = left .. version .. right
    print(line)
    return line
  end
  if line:sub(-7) == "(CTEX)]" then
    local line = line:gsub("%d+/%d+/%d+ v%S+", date:gsub("-","/") .. " v" .. version)
    print(line)
    return line
  end
  return line
end

-- dofile("../tool/zhl3build.lua")
maindir        = "."
supportdir     = "../tool"
testfiledir    = "./test/testfiles"
testsuppdir    = "./test/support"
testdir        = "./build/check"
checkruns      = 2
stdengine      = "xetex"
checkengines   = {"pdftex", "xetex", "luatex", "uptex"}
specialformats = {}
specialformats.latex = {
  pdftex = {binary = "latex", options = "-output-format=dvi"},
  uptex  = {binary = "euptex"}
}
