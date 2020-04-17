
module = "zhmcjk"

packtdszip = true

gitverfiles  = { }
sourcefiles  = {"zhmCJK.dtx", "zhmCJK.ins", "zhmCJK.lua", "zhmCJK-addmap.pl"}
unpackfiles  = {"zhmCJK.ins"}
installfiles = {"zhmCJK.sty"}
typesetfiles = {"zhmCJK.dtx", "zhmCJK-test.tex"}
unpackexe    = "pdftex"
typesetexe   = "latex"

dtxchecksum = dtxchecksum or { }
dtxchecksum.exe     = "latex"
dtxchecksum.cfgfile = "ltxdoc.cfg"

function docinit_hook()
  cp("zhmCJK-test.tex", unpackdir, typesetdir)
  return 0
end

function doc_posthook()
  for _, i in pairs(typesetfiles) do
    local name = jobname(i)
    run(typesetdir, "dvipdfmx " .. name)
    cp(name .. ".pdf", typesetdir, currentdir)
  end
end

function copyctan_posthook()
  mkdir(supportdir)
  cp("zhmCJK.lua", currentdir, supportdir)
  run(supportdir, "texlua zhmCJK.lua map")
  if not lfs.isfile(supportdir .. "/miktex-tfm.tar.bz2") then
    run(supportdir, "texlua zhmCJK.lua nomap")
    run(supportdir, "tar --remove-files -cjf miktex-tfm.tar.bz2 miktex-tfm")
  end
  local ctandir = ctandir .. "/" .. ctanpkg
  local mapdir = tdsdir .. "/fonts/map/fontname"
  mkdir(mapdir)
  for _, i in ipairs{"texfonts.map.template", "zhmCJK.map"} do
    cp(i, supportdir, ctandir)
    cp(i, supportdir, mapdir)
  end
  local tfmdir = tdsdir .. "/fonts/tfm/" .. ctanpkg
  mkdir(tfmdir)
  for _, i in ipairs{"zhmCJK.tfm", "miktex-tfm.tar.bz2"} do
    cp(i, supportdir, ctandir)
    cp(i, supportdir, tfmdir)
  end
end

dofile("../support/build-config.lua")
