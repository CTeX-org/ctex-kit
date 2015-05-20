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
generic_insatllfiles = generic_insatllfiles or { }
subtexdirs = subtexdirs or { }

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

-- 以 .aux, .glo, .idx, .hd 文件的 md5 来决定编译次数，默认最大为 5 次
max_typeset_run = max_typeset_run or 5
typeset = typeset or function (file)
  local name = stripext(file)
  local path_name = typesetdir .. "/" .. name
  local aux, glo, idx, hd = path_name .. ".aux", path_name .. ".glo", path_name .. ".idx", path_name .. ".hd"
  local aux_md5, glo_md5, idx_md5, hd_md5, prev_aux_md5, prev_glo_md5, prev_idx_md5, prev_hd_md5
  local errorlevel
  local cnt = 0
  local typeset_stop = true
  repeat
    cnt = cnt + 1
    errorlevel = tex(file)
    if errorlevel ~= 0 then return errorlevel end
    prev_aux_md5, prev_glo_md5, prev_idx_md5, prev_hd_md5 = aux_md5, glo_md5, idx_md5, hd_md5
    aux_md5, glo_md5, idx_md5, hd_md5 = file_md5(aux), file_md5(glo), file_md5(idx), file_md5(hd)
    typeset_stop = aux_md5 == prev_aux_md5 and hd_md5 == prev_hd_md5
    if glo_md5 ~= prev_glo_md5 then
      typeset_stop = false
      errorlevel = makeindex(name, ".glo", ".gls", ".glg", glossarystyle)
      if errorlevel ~= 0 then return errorlevel end
    end
    if idx_md5 ~= prev_idx_md5 then
      typeset_stop = false
      errorlevel = makeindex(name, ".idx", ".ind", ".ilg", indexstyle)
      if errorlevel ~= 0 then return errorlevel end
    end
  until typeset_stop or cnt >= max_typeset_run
  return 0
end

-- 返回脚本所在目录
local function script_path()
   local str = debug.getinfo(2, "S").source:sub(2)
   str = str:match("(.*[/\\])") or './'
   return str:gsub('\\', '/')
end

dtxchecksum = dofile(script_path() .. "dtxchecksum.lua").checksum
zhconv = dofile(script_path() .. "zhconv.lua").conv

-- 只对 .dtx 进行 \CheckSum 校正
function checksum()
  -- 不进行重复解包
  if not is_unpacked then unpack() end
  unpack = function() end
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
  unhooked_bundleunpack()
  -- UTF-8 to GBK conversion
  for _,f in ipairs(gbkfiles) do
    local f_utf = unpackdir .. "/" .. f
    zhconv(f_utf, f_utf)
  end
  -- UTF-8 to Big5 conversion
  for _,f in ipairs(big5files) do
    local f_utf = unpackdir .. "/" .. f
    zhconv(f_utf, f_utf, "big5")
  end
  is_unpacked = true
  unpack_posthook()
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
  -- 移动文件到 tex/generic/<module>/ 目录
  local tds_latexdir = tdsdir .. "/tex/" .. moduledir
  local tds_genericdir = tdsdir .. "/tex/generic/" .. module
  if next(generic_insatllfiles) ~= nil then
    mkdir(tds_genericdir)
  end
  for _,glob in ipairs(generic_insatllfiles) do
    for _,f in ipairs(filelist(tds_latexdir, glob)) do
      mv(tds_latexdir .. "/" .. f, tds_genericdir .. "/" .. f)
    end
  end
  -- 移动文件到 tex/latex/<module>/ 下的子目录
  for subdir,glob in pairs(subtexdirs) do
    mkdir(tds_latexdir .. "/" .. subdir)
    for _,f in ipairs(filelist(tds_latexdir, glob)) do
      mv(tds_latexdir .. "/" .. f, tds_latexdir .. "/" .. subdir .. "/" .. f)
    end
  end
  -- 其他钩子
  copytds_posthook()
end

function hooked_bundlectan()
  local err = unhooked_bundlectan()
  -- 复制 docstrip 生成的 README 文件
  if err == 0 then
    for _,f in ipairs (readmefiles) do
      cp(f, unpackdir, ctandir .. "/" .. ctanpkg .. "/" .. stripext(f))
      cp(f, unpackdir, tdsdir .. "/doc/" .. tdsroot .. "/" .. bundle .. "/" .. stripext(f))
    end
  end
  return err
end

function hooked_help()
  print ""
  io.stdout:write " build checksum              - adjust checksum"
  unhooked_help()
end

function main (target, file, engine)
  if miktex_hook then miktex_hook() end
  unhooked_bundleunpack = bundleunpack
  bundleunpack = hooked_bundleunpack
  unhooked_doc = doc
  doc = hooked_doc
  unhooked_copytds = copytds
  copytds = hooked_copytds
  unhooked_bundlectan = bundlectan
  bundlectan = hooked_bundlectan
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
