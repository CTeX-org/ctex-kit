--[==========================================================================[--
    L3BUILD FILE FOR ZHLINESKIP                  Copyright (C) by Ruixi Zhang
--]==========================================================================]--

module              = "zhlineskip"
version             = "v1.0f"
date                = "2026-06-27"
maintainer          = "Ruixi Zhang"
email               = "ruixizhang42@gmail.com"
sourcefiles         = {module .. ".dtx", "*.pdf"}
installfiles        = {module .. ".sty", module .. ".ins"}
demofiles           = {module .. "-test.tex"}
unpackfiles         = {module .. ".dtx"}

stdengine           = "pdftex"
checkengines        = {"pdftex"}
checkruns           = 1

dofile("../support/build-config.lua")

function update_tag(file, content, tagname, tagdate)
  tagname = version
  tagdate = date
  if string.match(file, module .. ".dtx$") then
    content = string.gsub(content,
      "%%<++!driver>\\GetIdInfo $Id: " .. module .. ".dtx " ..
      "v%d+%.%d+%w %d+%-%d+%-%d+ (.-)<(.-)>",
      "%%<+!driver>\\GetIdInfo $Id: "  .. module .. ".dtx " ..
      tagname .. " " .. tagdate .. " " .. maintainer .. "<" .. email .. ">")
  end
  return content
end

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
    "mirrors.ctan.org/fonts/notocjksc/NotoSerifCJKsc-Medium.otf")
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
