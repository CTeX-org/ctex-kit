--
--  This is file `dtxchecksum.lua',
--
--     Copyright (C) 2015 by Qing Lee <sobenlee@gmail.com>
--------------------------------------------------------------------
--
--     This work may be distributed and/or modified under the
--     conditions of the LaTeX Project Public License, either
--     version 1.3c of this license or (at your option) any later
--     version. This version of this license is in
--        http://www.latex-project.org/lppl/lppl-1-3c.txt
--     and the latest version of this license is in
--        http://www.latex-project.org/lppl.txt
--     and version 1.3 or later is part of all distributions of
--     LaTeX version 2005/12/01 or later.
--
--     This work has the LPPL maintenance status `maintained'.
--
--     The Current Maintainer of this work is Qing Lee.
--
--     This work consists of this file.
--
--------------------------------------------------------------------
--

dtxchecksum        = dtxchecksum or {}
local dtxchecksum  = dtxchecksum
dtxchecksum.module = {
  name        = "dtxchecksum",
  version     = "0",
  date        = "2015/05/18",
  description = "Correction of \\CheckSum{...} entry in dtx file",
  author      = "Qing Lee",
  copyright   = "Qing Lee",
  license     = "LPPL v1.3c"
}

local os, print, error = os, print, error

local checksumexe = dtxchecksum.exe or "xelatex"
local checksumopt = dtxchecksum.opt or ( checksumexe == "xelatex" and "-no-pdf" or "-draftmode")

local ltxdocfile = dtxchecksum.cfgfile or "l3doc.cfg"
local ltxdoccfg  = dtxchecksum.doccfg or ( checksumexe == "xelatex" and [[\AtBeginDocument{\XeTeXinterchartokenstate=\z@}]]
                                                                    or "" )

local kpathsea = kpse.new(checksumexe)

local cfg = [[
\typeout{* version for dtxchecksum *}
\AtEndOfClass{%
  \DontCheckModules
  \DisableCrossrefs
  \def\DisableCrossrefs{\@bsphack\@esphack}%
  \let\EnableCrossrefs\DisableCrossrefs
  \let\CodelineIndex\relax
  \let\PageIndex\relax
  \let\CodelineNumbered\relax
  \let\PrintChanges\relax
  \let\PrintIndex\relax
  \let\tableofcontents\relax
  \PassOptionsToPackage{bookmarks=false}{hyperref}%
  \expandafter\xdef\csname ver@hypdoc.sty\endcsname{}%
  \expandafter\xdef\csname ver@bmhydoc.sty\endcsname{}%
  \nofiles
  \hfuzz\maxdimen
  \pretolerance10000 %
  \tolerance10000 %
  \csname DisableDocumentation\endcsname
  \usepackage{syntonly}%
  \AtBeginDocument{\syntaxonly}
  ]] .. ltxdoccfg .. [[
}
\endinput
]]

local os_null, os_copy, os_rmdir
if os.type == "windows" then
  os_null = "nul"
  function os_copy (src, dest)
    os.execute("copy /y " .. src .. " " .. dest .. " > " .. os_null)
  end
  function os_rmdir (dir)
    os.execute("rmdir /s /q " .. dir)
  end
else
  os_null = "/dev/null"
  function os_copy (src, dest)
    os.execute("cp -f " .. src .. " " .. dest)
  end
  function os_rmdir (dir)
    os.execute("rm -rf " .. dir)
  end
end

local function stripext (file)
  return file:match ("^(.*)%.") or file
end

local function typeset (dir, dtx)
  local f = assert(io.open(dir .. "/" .. ltxdocfile, "w"))
  f:write(cfg)
  f:close()
  os_copy(dtx, dir)
  print("*** Running " .. checksumexe .. " for checksum generation ...")
  os.execute(checksumexe .. " -interaction=batchmode -output-directory=" .. dir .. " "
                         .. checksumopt .. " " .. dir .. "/" .. dtx .. " > " .. os_null)
end

local function find_checksum (logfile)
  print("*** Looking for checksum statement ...")
  local f = assert(io.open(logfile, "r"), "Cannot open log file " .. logfile .. "!")
  local file = f:read("*all")
  f:close()
  if file:find("%* Checksum passed %*") then
    return true, false
  end
  local old, new = file:match("Checksum not passed %((%d+)<>(%d+)%)")
  if old and new then
    return true, true, old, new
  end
  local new = file:match("The checksum should be (%d+)!")
  if new then
    return true, true, 0, new
  end
end

local function fix_checksum (dir, dtx, old, new)
  print("==> Checksum not passed (" .. old .. "<>" .. new .. ").")
  print("*** Fixing Checksum ...")
  local f = assert(io.open(dir .. "/" .. dtx , "rb"))
  local file = f:read("*all")
  f:close()
  local s, fixed = file:gsub("(\\CheckSum%s*{%s*)" .. old .. "(%s*})", "%1" .. new .. "%2")
  local f = assert(io.open(dtx , "wb"))
  f:write(s)
  f:close()
  if fixed == 0 then
    error("\"\\CheckSum{...}\" not found!")
  end
  if fixed > 1 then
    error("More than one \"\\CheckSum\" command found!")
  end
end

function dtxchecksum.checksum (dtx, texinputs)
  local tempdir = assert(os.tmpdir(), "Cannot create the temporary directory!")
  local kpse_texinputs, os_texinputs
  if texinputs then
    if os.selfdir:find([[miktex\bin$]]) then
      checksumopt = "-include-directory=" .. texinputs .. " " .. checksumopt
    else
      kpse_texinputs = kpathsea:var_value("TEXINPUTS")
      os_texinputs = kpse_texinputs and texinputs .. "//;" .. kpse_texinputs
                                     or texinputs .. "//"
      os.setenv("TEXINPUTS", os_texinputs)
    end
  end
  typeset(tempdir, dtx)
  local logfile = tempdir .. "/" .. stripext(dtx) .. ".log"
  local found, changed, old, new = find_checksum(logfile)
  assert(found, "Checksum statement not found in log file!")
  if changed then
    fix_checksum(tempdir, dtx, old, new)
  else
    print("*** Checksum passed.")
  end
  os_rmdir(tempdir)
  if os_texinputs then
    os.setenv("TEXINPUTS", kpse_texinputs)
  end
end

return dtxchecksum
