
module = "cjkpunct"

packtdszip = true

gitverfiles  = { }
sourcefiles  = {"CJKpunct.dtx", "CJKpunct.spa"}
unpackfiles  = {"CJKpunct.dtx"}
installfiles = {"CJKpunct.sty", "CJKpunct.spa"}
typesetfiles = {"CJKpunct.dtx"}
unpackexe    = "pdftex"
typesetexe   = "xelatex"

stdengine    = "pdftex"
checkengines = {"pdftex"}
checkruns    = 1

dtxchecksum = dtxchecksum or { }
dtxchecksum.exe     = "xelatex"

function doc_posthook()
  for _, i in pairs(typesetfiles) do
    local name = jobname(i)
    cp(name .. ".pdf", typesetdir, currentdir)
  end
end

function copyctan_posthook()
  local ctandir = ctandir .. "/" .. ctanpkg
  local docdir = tdsdir .. "/doc/" .. moduledir
  cp("examples", currentdir, ctandir)
  cp("examples", currentdir, docdir)
  cp("setpunct", currentdir, ctandir)
  cp("setpunct", currentdir, docdir)
end


dofile("../support/build-config.lua")

-- CJKpunct's driver (ctxdoc) is incompatible with dtxchecksum
checksum = function() end
