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

gitverfiles = gitverfiles or unpackfiles
gbkfiles = gbkfiles or { }
generic_insatllfiles = generic_insatllfiles or { }
subtexdirs = subtexdirs or { }

-- 返回脚本所在目录
local function script_path()
   local str = debug.getinfo(2, "S").source:sub(2)
   str = str:match("(.*[/\\])") or './'
   return str:gsub('\\', '/')
end

dtxchecksum = dofile(script_path() .. "dtxchecksum.lua").checksum
-- 只对 .dtx 进行 \CheckSum 校正
function checksum()
  unpack ()
  -- 不进行重复解包
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
  for _,f in ipairs(gitverfiles) do
    local mainname = f:match("(.*)%.") or f
    local vername = mainname .. '.ver'
    os.execute(shellescape([[git log -1 --pretty=format:"\def\]].. mainname .. [[PutVersion{\string\GetIdInfo]] ..
      [[$Id: ]] .. f .. [[ %h %ai %an <%ae> $}" ]] .. f .. ' > ' .. vername))
    append_newline(vername)
    os.execute(shellescape([[git log -1 --pretty=format:"\def\]] .. mainname .. [[GetVersionInfo{\GetIdInfo]] ..
      [[$Id: ]] .. f .. [[ %h %ai %an <%ae> $}" ]] .. f .. ' >> ' .. vername))
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
    mv(f_gbk, f_utf)
  end
end

function hooked_doc()
  checksum()
  return unhooked_doc()
end

function hooked_copytds()
  unhooked_copytds()
  -- 移动文件到 tex/generic/<module>/ 目录
  local tds_latexdir = tdsdir .. "/tex/latex/" .. module
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
  unhooked_help()
  print " build checksum              - adjust checksum"
end

function main (target, file, engine)
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
