
module = "ctex"

packtdszip = true

sourcefiles      = {"ctex.dtx", "ctexpunct.spa"}
unpackfiles      = {"ctex.dtx"}
installfiles     = {"*.sty", "*.cls", "*.clo", "*.def", "*.cfg", "*.fd", "ct*.tex", "zh*.tex", "*.dict", "*.lua"}
unpacksuppfiles  = {"ctex.id", "ctxdocstrip.tex", "zhconv.lua", "zhconv-index.lua"}
typesetsuppfiles = {"ctxdoc.cls"}
gitverfiles      = {"ctex.dtx", "ctxdoc.cls"}

tdslocations = {
  "source/latex/ctex/zhconv-make.lua",
  "tex/generic/ctex/*.tex",
  "tex/latex/ctex/config/*.cfg",
  "tex/latex/ctex/fd/*.fd",
  "tex/latex/ctex/engine/ctex-engine-*.def",
  "tex/latex/ctex/fontset/ctex-fontset-*.def",
  "tex/latex/ctex/heading/ctex-heading-*.def",
  "tex/latex/ctex/scheme/ctex-scheme-*.def",
  "tex/latex/ctex/dictionary/*.dict",
  "tex/luatex/ctex/*.lua",
}

function unpack_posthook()
  if install_files_bool then
    for _,i in ipairs{"ctxdoc.cls", "ctxdocstrip.tex",
                      "zhconv*.lua", "zhconv*.luc", } do
      cp(i, supportdir, unpackdir)
    end
  end
end

function copyctan_posthook()
  local dest = ctandir .. "/" .. ctanpkg
  for _,file in ipairs{"ctxdocstrip.tex", "zhconv.lua", "zhconv-make.lua"} do
    cp(file, unpackdir, dest)
  end
end

testfiledir    = "./test/testfiles"
testsuppdir    = "./test/support"
testdir        = "./build/check"
checkruns      = 2
stdengine      = "xetex"
checkdeps      = {"../xeCJK","../zhnumber"}
checkengines   = {"pdftex", "xetex", "luatex", "uptex"}
specialformats = {}
specialformats.latex = {
  pdftex = {format = "latex"},
  uptex  = {binary = "euptex"}
}

checkinit_hook = function()
  for _,i in ipairs(checkdeps) do
    local unpackdir = i .. "/" .. unpackdir
    for _,i in ipairs(installfiles) do
      cp(i, unpackdir, testdir)
    end
  end
  return 0
end

dofile("../support/build-config.lua")
