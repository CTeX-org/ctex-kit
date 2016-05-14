#!/usr/bin/env texlua

--[[

  File zhl3build.lua (C) Copyright 2015 The ctex-kit Project

 It may be distributed and/or modified under the conditions of the
 LaTeX Project Public License (LPPL), either version 1.3c of this
 license or (at your option) any later version.  The latest version
 of this license is in the file

    http://www.latex-project.org/lppl.txt

 This file is part of the "zhl3build bundle" (The Work in LPPL)
 and all files in that bundle must be distributed together.

--]]

maindir = maindir or "."
supportdir = supportdir or maindir .. "/build/support"
gitverfiles = gitverfiles or unpackfiles
gbkfiles = gbkfiles or { }
big5files = big5files or { }
context_insatllfiles  = context_insatllfiles  or { }
generic_insatllfiles  = generic_insatllfiles  or { }
plain_insatllfiles    = plain_insatllfiles    or { }
latex_insatllfiles    = latex_insatllfiles    or { }
luatex_insatllfiles   = luatex_insatllfiles   or { }
lualatex_insatllfiles = lualatex_insatllfiles or { }
xetex_insatllfiles    = xetex_insatllfiles    or { }
xelatex_insatllfiles  = xelatex_insatllfiles  or { }
subtexdirs = subtexdirs or { }

typesetopts = typesetopts or "-halt-on-error"

-- MiKTeX 中，环境变量 TEXINPUTS 的优先级低于系统路径
-- 但可以设置编译选项 -include-directory
miktex_hook = os.selfdir:find([[miktex\bin$]]) and function ()
  typesetopts = "-include-directory=" .. relpath(localdir, typesetdir) .. " " .. typesetopts
  unpackopts = "-include-directory=" .. relpath(localdir, unpackdir) .. " " .. unpackopts
end

-- 计算文件的 md5
local md5sum = require("md5").sumhexa
function file_md5 (file)
  local f = io.open(file, "rb")
  if f then
    local data = f:read("*all")
    f:close()
    return data and md5sum(data)
  end
end

-- 以 .aux, .bbl, .glo, .idx, .hd 文件的 md5 来决定编译次数，默认最大为 5 次
max_typeset_run = max_typeset_run or 5
typeset = typeset or function (file)
  local name = stripext(file)
  local path_name = typesetdir .. "/" .. name
  local aux, bbl = path_name .. ".aux", path_name .. ".bbl"
  local glo, idx, hd = path_name .. ".glo", path_name .. ".idx", path_name .. ".hd"
  local aux_md5, bbl_md5, glo_md5, idx_md5, hd_md5
  local prev_aux_md5, prev_bbl_md5, prev_glo_md5, prev_idx_md5, prev_hd_md5
  local errorlevel
  local cnt = 0
  local typeset_flag = true
  while typeset_flag and cnt < max_typeset_run do
    cnt = cnt + 1
    errorlevel = tex(file)
    if errorlevel ~= 0 then return errorlevel end
    errorlevel = biber(name) + bibtex(name)
                             + makeindex(name, ".glo", ".gls", ".glg", glossarystyle)
                             + makeindex(name, ".idx", ".ind", ".ilg", indexstyle)
    if errorlevel ~= 0 then return errorlevel end
    prev_aux_md5, prev_bbl_md5 = aux_md5, bbl_md5
    prev_glo_md5, prev_idx_md5, prev_hd_md5 = glo_md5, idx_md5, hd_md5
    aux_md5, bbl_md5 = file_md5(aux), file_md5(bbl)
    glo_md5, idx_md5, hd_md5 = file_md5(glo), file_md5(idx), file_md5(hd)
    typeset_flag = aux_md5 ~= prev_aux_md5 or bbl_md5 ~= prev_bbl_md5
                                           or glo_md5 ~= prev_glo_md5
                                           or idx_md5 ~= prev_idx_md5
                                           or hd_md5 ~= prev_hd_md5
  end
  return 0
end

-- 返回脚本所在目录
local function script_path()
   local str = debug.getinfo(2, "S").source:sub(2)
   str = str:match("(.*[/\\])") or "./"
   return str:gsub("\\", "/")
end

dtxchecksum = dofile(script_path() .. "dtxchecksum.lua").checksum
zhconv = dofile(script_path() .. "zhconv.lua").conv

-- 只对 .dtx 进行 \CheckSum 校正
function checksum()
  -- 不进行重复解包
  if not is_unpacked then unpack() end
  unpack = function() end
  for _,i in ipairs(typesetsuppfiles) do
    cp (i, supportdir, localdir)
  end
  for _,glob in ipairs(typesetfiles) do
    for _,f in ipairs(filelist(".", glob)) do
      if f:sub(-4) == ".dtx" then
        dtxchecksum(f, localdir)
      end
    end
  end
end

function append_newline(file)
  if os_windows then
    os.execute("echo.>> " .. file)
  else
    os.execute("echo >> " .. file)
  end
end

function shellescape(s)
  if not os_windows then
    s = s:gsub([[\]], [[\\]])
    s = s:gsub([[%$]], [[\$]])
  end
  return s
end

function extract_git_version()
  mkdir(supportdir)
  for _,f in ipairs(gitverfiles) do
    local mainname = f:match("(.*)%.") or f
    local vername =  supportdir .. '/' .. mainname .. '.ver'
    if os_windows then vername = unix_to_win(vername) end
    os.execute(shellescape([[git log -1 --pretty=format:"\expandafter\def\csname\detokenize{]]
                               .. mainname .. [[PutVersion}\endcsname{\string\GetIdInfo]] .. [[$Id: ]]
                               .. f .. [[ %h %ai %an <%ae> $}" ]] .. f .. ' > ' .. vername))
    append_newline(vername)
    os.execute(shellescape([[git log -1 --pretty=format:"\expandafter\def\csname\detokenize{]]
                               .. mainname .. [[GetVersionInfo}\endcsname{\GetIdInfo]] .. [[$Id: ]]
                               .. f .. [[ %h %ai %an <%ae> $}" ]] .. f .. ' >> ' .. vername))
    append_newline(vername)
  end
end

function mv(src, dest)
  local mv = "mv"
  if os_windows then
    mv = "move /y"
    src = unix_to_win(src)
    dest = unix_to_win(dest)
  end
  os.execute(mv .. " " .. src .. " " .. dest .. " > " .. os_null)
end

local unpack_prehook = unpack_prehook or function() end
local unpack_posthook = unpack_posthook or function() end
function hooked_bundleunpack()
  extract_git_version()
  unpack_prehook()
  -- Unbundle
  local retval = unhooked_bundleunpack()
  -- UTF-8 to GBK conversion
  for _,glob in ipairs(gbkfiles) do
    for _,f in ipairs(filelist(unpackdir,glob)) do
      local f_utf = unpackdir .. "/" .. f
      zhconv(f_utf, f_utf)
    end
  end
  -- UTF-8 to Big5 conversion
  for _,glob in ipairs(big5files) do
    for _,f in ipairs(filelist(unpackdir,glob)) do
      local f_utf = unpackdir .. "/" .. f
      zhconv(f_utf, f_utf, "big5")
    end
  end
  is_unpacked = true
  return retval
end

local doc_prehook = doc_prehook or function() end
local doc_posthook = doc_posthook or function() end
function hooked_doc()
  checksum()
  doc_prehook()
  local retval = unhooked_doc()
  doc_posthook()
  return retval
end

copytds_prehook = copytds_prehook or function() end
copytds_posthook = copytds_posthook or function() end
function hooked_copytds()
  copytds_prehook()
  unhooked_copytds()
  -- 移动文件到对应的 tds 子目录
  local tds_basedir = tdsdir .. "/tex/" .. moduledir
  local tds_t = {
    { context_insatllfiles,  tdsdir .. "/tex/context/third/" .. module } ,
    { generic_insatllfiles,  tdsdir .. "/tex/generic/" .. module } ,
    { plain_insatllfiles,    tdsdir .. "/tex/plain/" .. module } ,
    { latex_insatllfiles,    tdsdir .. "/tex/latex/" .. module } ,
    { luatex_insatllfiles,   tdsdir .. "/tex/luatex/" .. module } ,
    { lualatex_insatllfiles, tdsdir .. "/tex/lualatex/" .. module } ,
    { xetex_insatllfiles,    tdsdir .. "/tex/xetex/" .. module } ,
    { xelatex_insatllfiles,  tdsdir .. "/tex/xelatex/" .. module } ,
  }
  for _,t in ipairs(tds_t) do
    local files, dir = t[1], t[2]
    if next(files) ~=nil then
      mkdir(dir)
      for _,glob in ipairs(files) do
        for _,f in ipairs(filelist(tds_basedir, glob)) do
          mv(tds_basedir .. "/" .. f, dir .. "/" .. f)
        end
      end
    end
  end
  -- 移动文件到 tex/latex/<module>/ 下的子目录
  for subdir,glob in pairs(subtexdirs) do
    mkdir(tds_basedir .. "/" .. subdir)
    for _,f in ipairs(filelist(tds_basedir, glob)) do
      mv(tds_basedir .. "/" .. f, tds_basedir .. "/" .. subdir .. "/" .. f)
    end
  end
  -- 其他钩子
  copytds_posthook()
end

function hooked_help()
  unhooked_help()
  print("")
  print("zhl3build extension:")
  print([[   checksum   Adjust \CheckSum{...}]])
end

function main (target, file, engine)
  if miktex_hook then miktex_hook() end
  unhooked_bundleunpack = bundleunpack
  bundleunpack = hooked_bundleunpack
  unhooked_doc = doc
  doc = hooked_doc
  unhooked_copytds = copytds
  copytds = hooked_copytds
  unhooked_help = help
  help = hooked_help
  if target == "checksum" then
    checksum()
  else
    stdmain(target, file, engine)
  end
end

-- 使用本地固定的版本
dofile(script_path() .. "l3build.lua")

-- vim:sw=2:et
