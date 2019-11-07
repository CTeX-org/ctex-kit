#!/usr/bin/env texlua

module = "cjkpunct"

packtdszip = true

gitverfiles = { }
sourcefiles = {"CJKpunct.dtx", "CJKpunct.spa"}
unpackfiles = {"CJKpunct.dtx"}
installfiles = {"CJKpunct.sty", "CJKpunct.spa"}
typesetfiles = {"CJKpunct.dtx"}
unpackexe = "pdftex"
typesetexe = "latex"

function doc_posthook()
  for _, i in pairs(typesetfiles) do
    local name = stripext(i)
    run(typesetdir, "dvipdfmx " .. name)
    cp(name .. ".pdf", typesetdir, ".")
  end
end

function copytds_posthook()
  local ctandir = ctandir .. "/" .. ctanpkg
  local docdir = tdsdir .. "/doc/" .. moduledir
  cp("examples", ".", ctandir)
  cp("examples", ".", docdir)
  cp("setpunct", ".", ctandir)
  cp("setpunct", ".", docdir)
end

dofile("../tool/zhl3build.lua")

-- vim:sw=2:et
