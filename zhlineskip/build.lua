--[==========================================================================[--
    L3BUILD FILE FOR ZHLINESKIP                     Copyright (C) by CTeX-kit
--]==========================================================================]--

module              = "zhlineskip"
sourcefiles         = {module .. ".dtx", "*.pdf"}
installfiles        = {module .. ".sty", module .. ".ins"}
demofiles           = {module .. "-test.tex"}
unpackfiles         = {module .. ".dtx"}

stdengine           = "pdftex"
checkengines        = {"pdftex"}
checkruns           = 1

function unpack_posthook()
  if install_files_bool then
    for _,i in ipairs{"ctxdoc.cls", "ctxdocstrip.tex", "ctex-zhconv*.lua"} do
      cp(i, supportdir, localdir)
    end
  end
end
function fetchdocsupp(shortlink)
  run(typesetdir, "curl -O -L \"https://" .. shortlink .. "\"")
  return 0
end
function docinit_hook()
  fetchdocsupp(
    "mirrors.ctan.org/fonts/notocjksc/NotoSerifCJKsc-Regular.otf")
  fetchdocsupp(
    "mirrors.ctan.org/fonts/notocjksc/NotoSerifCJKsc-Bold.otf")
  fetchdocsupp(
    "mirrors.ctan.org/fonts/notocjksc/NotoSerifCJKsc-Black.otf")
  fetchdocsupp(
    "mirrors.ctan.org/fonts/notocjksc/NotoSansCJKsc-Regular.otf")
  fetchdocsupp(
    "mirrors.ctan.org/fonts/notocjksc/NotoSansCJKsc-Bold.otf")
  cp(ctanreadme, unpackdir, currentdir)
  return 0
end

dofile("../support/build-config.lua")
