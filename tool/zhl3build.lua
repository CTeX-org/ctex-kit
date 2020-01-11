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
supportdir = supportdir or "../tool"
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
local md5sum = require("md5").sum
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

function zhconv (input, output, encoding)
  local cmdline = "iconv -f utf-8 -t " .. ( encoding or "gbk" ) .. " " .. input
  local handle = assert(io.popen(shellescape(cmdline), "r"))
  local buffer = handle:read("*all")
  assert(handle:close())
  local f = assert(io.open(output, "w"))
  f:write(buffer)
  f:close()
end

function shellescape(s)
  if not os_windows then
    s = s:gsub([[\]], [[\\]])
    s = s:gsub([[%$]], [[\$]])
  end
  return s
end

git_id_info = { }

function extract_git_version()
  mkdir(supportdir)
  for _,i in ipairs(gitverfiles) do
    for _,j in ipairs(filelist(".", i)) do
      local mainname = stripext(j)
      local idfile =  supportdir .. "/" .. mainname .. ".id"
      if os_windows then idfile = unix_to_win(idfile) end
      local cmdline = shellescape([[git log -1 --pretty=format:"$Id: ]]
                                      .. j .. [[ %h %ai %an <%ae> $" ]] .. j)
      local  f = assert(io.popen(cmdline, "r"))
      local id = f:read("*all")
      f:close()
      git_id_info[j] = id
      f = assert(io.open(idfile, "w"))
      f:write(id, "\n")
      f:close()
    end
  end
end

function expand_git_version()
  local sourcedir = tdsdir .. "/source/" .. moduledir
  for _,i in ipairs(gitverfiles) do
    for _,j in ipairs(filelist(sourcedir, i)) do
      replace_git_id(sourcedir, j)
    end
  end
end

function replace_git_id (path, file)
  local f = assert(io.open(path .. "/" .. file, "rb"))
  local s = f:read("*all")
  f:close()
  local id = assert(git_id_info[file])
  local s, n = s:gsub([[(%b<>\GetIdInfo)%b$$]], "%1" .. id)
  if n > 0 then
    f = assert(io.open(path .. "/" .. file, "wb"))
    f:write(s)
    f:close()
    cp(file, path, ctandir .. "/" .. ctanpkg)
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
  unpack_posthook()
  return retval
end

local doc_prehook = doc_prehook or function() end
local doc_posthook = doc_posthook or function() end
function hooked_doc()
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
  -- 展开源文件中的 $Id$
  expand_git_version()
  -- 其他钩子
  copytds_posthook()
end

function hooked_help()
  unhooked_help()
  print("")
  print("zhl3build extension:")
end

-- 更改版本号时不改变换行符
function zh_setversion()
  local function rewrite(file, date, version)
    local changed = false
    local lines = { }
    local f = assert(io.open(file, "rb"))
    local line = f:read("*L")
    local EOL = assert(line:match(".-([\r\n]+)$"))
    assert(f:seek("set"))
    for line in f:lines() do
      local newline = setversion_update_line(line, date, version)
      if newline ~= line then
        line = newline
        changed = true
      end
      table.insert(lines, line)
    end
    f:close()
    if changed then
      ren(".", file, file .. bakext)
      f = assert(io.open(file, "wb"))
      f:write(table.concat(lines, EOL), EOL)
      f:close()
      rm(".", file .. bakext)
    end
  end
  local date = optdate and optdate[1] or os.date("%Y-%m-%d")
  local version = optversion and optversion[1] or "-1"
  for _,i in pairs(versionfiles) do
    for _,j in pairs(filelist(".", i)) do
      rewrite(j, date, version)
    end
  end
  return 0
end

function main (target, file, engine)
  if os_windows then
    os_newline = "\n"
    if tonumber(status.luatex_version) < 100 or
       (tonumber(status.luatex_version) == 100
         and tonumber(status.luatex_revision) < 4) then
      os_newline = "\r\n"
    end
  end
  if miktex_hook then miktex_hook() end
  unhooked_bundleunpack = bundleunpack
  bundleunpack = hooked_bundleunpack
  unhooked_doc = doc
  doc = hooked_doc
  unhooked_copytds = copytds
  copytds = hooked_copytds
  unhooked_help = help
  help = hooked_help
  setversion = zh_setversion
  stdmain(target, file, engine)
end

-- 使用本地固定的版本
dofile(script_path() .. "l3build.lua")

-- vim:sw=2:et
