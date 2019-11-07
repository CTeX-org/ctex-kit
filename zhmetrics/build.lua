#!/usr/bin/env texlua

module = "zhmcjk"

packtdszip = true

gitverfiles = { }
sourcefiles = {"zhmCJK.dtx", "zhmCJK.ins", "zhmCJK.lua", "zhmCJK-addmap.pl"}
unpackfiles = {"zhmCJK.ins"}
installfiles = {"zhmCJK.sty"}
typesetfiles = {"zhmCJK.dtx", "zhmCJK-test.tex"}
binaryfiles = {"*.pdf", "*.tfm", "*.zip", "*.tar.bz2"}
unpackexe = "pdftex"
typesetexe = "latex"
makeindexexe = "zhmakeindex"

function doc_prehook()
  cp("zhmCJK-test.tex", unpackdir, ".")
end

function doc_posthook()
  for _, i in pairs(typesetfiles) do
    local name = stripext(i)
    run(typesetdir, "dvipdfmx " .. name)
    cp(name .. ".pdf", typesetdir, ".")
  end
  os.remove("zhmCJK-test.tex")
end

function copytds_posthook()
  cp("zhmCJK-test.tex", typesetdir, tdsdir .. "/doc/" .. moduledir)
  mkdir(supportdir)
  cp("zhmCJK.lua", ".", supportdir)
  run(supportdir, "texlua zhmCJK.lua map")
  if not lfs.isfile(supportdir .. "/fallback.tar.bz2") then
    run(supportdir, "texlua zhmCJK.lua nomap")
    run(supportdir, "tar --remove-files -cjf fallback.tar.bz2 fallback")
  end
  local ctandir = ctandir .. "/" .. ctanpkg
  local mapdir = tdsdir .. "/fonts/map/fontname"
  mkdir(mapdir)
  for _, i in pairs{"texfonts.map", "zhmCJK.map"} do
    cp(i, supportdir, ctandir)
    cp(i, supportdir, mapdir)
  end
  local tfmdir = tdsdir .. "/fonts/tfm/" .. ctanpkg
  mkdir(tfmdir)
  for _, i in pairs{"zhmCJK.tfm", "fallback.tar.bz2"} do
    cp(i, supportdir, ctandir)
    cp(i, supportdir, tfmdir)
  end
end

dofile("../tool/zhl3build.lua")

-- vim:sw=2:et
