#!/usr/bin/env texlua

module = "ctex"

sourcefiles = {"ctex.dtx", "ctexpunct.spa"}
unpackfiles = {"ctex.dtx"}
installfiles = {"*.sty", "*.cls", "*.def", "*.cfg", "*.fd", "zh*.tex"}
stdengine = "xetex"
unpackexe = "xetex"
typesetexe = "xelatex"

gbkfiles = {"ctexcap-gbk.cfg"}
makeindexexe = "zhmakeindex"



if string.sub (package.config, 1, 1) == "\\" then
  os_mv = "move /y"
  os_append_newline = "echo.>>"
else
  os_mv = "mv"
  os_append_newline = "echo >>"
end

function extract_git_version()
  os.execute([[git log -1 --pretty=format:"\def\ctexPutVersion{\string\GetIdInfo$Id: ctex.dtx %h %ai %an <%ae> $}" ctex.dtx > ctex.ver]])
  os.execute(os_append_newline .. " ctex.ver")
  os.execute([[git log -1 --pretty=format:"\def\ctexGetVersionInfo{\GetIdInfo$Id: ctex.dtx %h %ai %an <%ae> $}" ctex.dtx >> ctex.ver]])
end

function clean_git_version()
  os.remove("ctex.ver")
end

function hooked_bundleunpack()
  extract_git_version()
  -- Unbundle
  unhooked_bundleunpack()
  -- UTF-8 to GBK conversion
  for _,f in ipairs(gbkfiles) do
    local f_utf = unpackdir .. "/" .. f
    local f_gbk = unpackdir .. "/" .. f .. ".gbk"
    if os_windows then
      f_utf = unix_to_win(f_utf)
      f_gbk = unix_to_win(f_gbk)
    end
    os.execute("iconv -f utf-8 -t gbk " .. f_utf .. " > " .. f_gbk)
    os.execute(os_mv .. " " .. f_gbk .. " " .. f_utf)
  end
end

-- 修改自 l3build.lua 2015/02/01 r5504 的 doc() 函数
-- 只修改了 makeindex 的命令为可配置的
function mod_doc ()
  local function typeset (file)
    local name = stripext (file)
    -- A couple of short functions to deal with the repeated steps in a
    -- clear way
    local function makeindex (name, inext, outext, logext, style)
      if fileexists (typesetdir .. "/" .. name .. inext) then
        run (
          typesetdir ,
          makeindexexe .. " -s " .. style .. " -o " .. name .. outext
            .. " -t " .. name .. logext .. " "  .. name .. inext
          )        
      end
    end
    local function typeset (file)
      local errorlevel =
        os.execute (
            os_setenv .. " TEXINPUTS=" .. typesetdir .. 
              os_pathsep .. localdir .. (typesetsearch and os_pathsep or "") ..
              os_concat ..
            typesetexe .. " " .. typesetopts .. 
              " -output-directory=" .. typesetdir ..
              " \"" .. typesetcmds .. 
              "\\input " .. typesetdir .. "/" .. file .. "\""
          )
      return errorlevel
    end
    os.remove (name .. ".pdf")
    print ("Typesetting " .. name)
    local errorlevel = typeset (file)
    if errorlevel ~= 0 then
      print (" ! Compilation failed")
      return (errorlevel)
    else
      makeindex (name, ".glo", ".gls", ".glg", glossarystyle)
      makeindex (name, ".idx", ".ind", ".ilg", indexstyle)
      typeset (file)
      typeset (file)
      cp (name .. ".pdf", typesetdir, ".")
    end
    return (errorlevel)
  end
  -- Set up
  cleandir (typesetdir)
  for _,i in ipairs (sourcefiles) do
    cp (i, ".", typesetdir)
  end
  for _,i in ipairs (typesetfiles) do
    cp (i, ".", typesetdir)
  end
  for _,i in ipairs (typesetsuppfiles) do
    cp (i, supportdir, typesetdir)
  end
  depinstall (typesetdeps)
  unpack ()
  -- Main loop for doc creation
  for _,i in ipairs (typesetfiles) do
    for _,j in ipairs (filelist (".", i)) do
      local errorlevel = typeset (j)
      if errorlevel ~= 0 then
        return (errorlevel)
      end
    end
  end
  return 0
end

function main (target, file, engine)
  unhooked_bundleunpack = bundleunpack
  bundleunpack = hooked_bundleunpack
  doc = mod_doc
  stdmain(target, file, engine)
  clean_git_version()
end

kpse.set_program_name("kpsewhich")
dofile(kpse.lookup("l3build.lua"))
