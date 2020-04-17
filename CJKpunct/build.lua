
module = "cjkpunct"

packtdszip = true

gitverfiles  = { }
sourcefiles  = {"CJKpunct.dtx", "CJKpunct.spa"}
unpackfiles  = {"CJKpunct.dtx"}
installfiles = {"CJKpunct.sty", "CJKpunct.spa"}
typesetfiles = {"CJKpunct.dtx"}
unpackexe    = "pdftex"
typesetexe   = "latex"

dtxchecksum = dtxchecksum or { }
dtxchecksum.exe     = "latex"
dtxchecksum.cfgfile = "ltxdoc.cfg"

function doc_posthook()
  for _, i in pairs(typesetfiles) do
    local name = jobname(i)
    run(typesetdir, "dvipdfmx " .. name)
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
