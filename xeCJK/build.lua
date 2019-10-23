#!/usr/bin/env texlua

module = "xecjk"

packtdszip = true
tdsroot = "xelatex"

sourcefiles = {"xeCJK.dtx"}
unpackfiles = {"xeCJK.dtx"}
unpacksuppfiles = {"xeCJK.id", "ctxdocstrip.tex"}
typesetfiles = {"xeCJK.dtx", "xunicode-symbols.tex"}
typesetsuppfiles = {"UnicodeData.txt", "ctxdoc.cls"}
binaryfiles = {"*.pdf", "*.zip", "*.tec"}
installfiles = {"*.sty", "*.cfg", "*.def"}
unpackexe = "xetex"
typesetexe = "xelatex"
makeindexexe = "zhmakeindex"
checkopts = "-file-line-error -halt-on-error -interaction=nonstopmode"
typesetopts = "-file-line-error -halt-on-error -interaction=nonstopmode"

local http_request = require("socket.http").request
local ltn12_sink_file = require("ltn12").sink.file
local zip_open = require("zip").open

local function make_teckit_mapping()
  local unihan_variants = "Unihan_Variants.txt"
  local f = io.open(supportdir .. "/" .. unihan_variants, "r")
  if not f then
    local unihan_zip = supportdir .. "/Unihan.zip"
    local zfile = zip_open(unihan_zip)
    if not zfile then
      local status, err = http_request{
        url  = "http://www.unicode.org/Public/UNIDATA/Unihan.zip",
        sink = ltn12_sink_file(io.open(unihan_zip, "wb")) }
      if not status then
        error([[Download "]] .. "Unihan.zip" .. [[" failed because of ]] .. err .. ".")
      end
      zfile = assert(zip_open(unihan_zip))
    end
    f = assert(zfile:open(unihan_variants))
    zfile:close()
  end

  local unihan_id = ""
  for i = 1, 5 do
    local line = f:read("*line")
    line = line:gsub("^#", ";")
    unihan_id = unihan_id .. line .. "\n"
  end

  local txt = f:read("*all")
  f:close()

  local han_trad_preamble = [[
; TECkit mapping for conversion of simplified Chinese characters to traditional Chinese characters
; from the Unicode Unihan database: <http://www.unicode.org/Public/UNIDATA/Unihan.zip>
]] .. unihan_id .. [[

LHSName "simplified"
RHSName "traditional"

pass(Unicode)

U+201C <> U+300C
U+201D <> U+300D
U+2018 <> U+300E
U+2019 <> U+300F
]]

  local han_simp_preamble = [[
; TECkit mapping for conversion of traditional Chinese characters to simplified Chinese characters
; from the Unicode Unihan database: <http://www.unicode.org/Public/UNIDATA/Unihan.zip>
]] .. unihan_id .. [[

LHSName "traditional"
RHSName "simplified"

pass(Unicode)

U+300C <> U+201C
U+300D <> U+201D
U+300E <> U+2018
U+300F <> U+2019
]]

  local fullwidth_stop = [[
; TECkit mapping for conversion of `IDEOGRAPHIC FULL STOP" to `FULLWIDTH FULL STOP"
;

LHSName "IDEOGRAPHIC FULL STOP"
RHSName "FULLWIDTH FULL STOP"

pass(Unicode)

U+3002 <> U+FF0E
]]

  local full_stop = [[
; TECkit mapping for conversion of `FULLWIDTH FULL STOP" to `IDEOGRAPHIC FULL STOP"
;

LHSName "FULLWIDTH FULL STOP"
RHSName "IDEOGRAPHIC FULL STOP"

pass(Unicode)

U+FF0E <> U+3002
]]

  local full_stop_map = unpackdir .. "/full-stop.map"
  io.output(full_stop_map)
  io.write(full_stop)
  io.close()
  os.execute("teckit_compile " .. full_stop_map)

  local fullwidth_map = unpackdir .. "/fullwidth-stop.map"
  io.output(fullwidth_map)
  io.write(fullwidth_stop)
  io.close()
  os.execute("teckit_compile " .. fullwidth_map)

  local han_trad_map = unpackdir .. "/han-trad.map"
  io.output(han_trad_map)
  io.write(han_trad_preamble, "\n")
  for simp, trad in txt:gmatch("(U%+%x+)\tkTraditionalVariant\t(U%+%x+)") do
    io.write(simp, " <> ", trad, "\n")
  end
  io.close()
  os.execute("teckit_compile " .. han_trad_map)

  local han_simp_map = unpackdir .. "/han-simp.map"
  io.output(han_simp_map)
  io.write(han_simp_preamble, "\n")
  for trad, simp in txt:gmatch("(U%+%x+)\tkSimplifiedVariant\t(U%+%x+)") do
    io.write(trad, " <> ", simp, "\n")
  end
  io.close()
  os.execute("teckit_compile " .. han_simp_map)

end

-- 下载 UnicodeData.txt，并准备 xunicode-symbols.tex
function doc_prehook()
  mkdir(supportdir)
  local unicode_data = supportdir .. "/UnicodeData.txt"
  if not lfs.isfile(unicode_data) then
    local status, err = http_request{
      url  = "http://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt",
      sink = ltn12_sink_file(io.open(unicode_data, "wb")) }
    if not status then
      error([[Download "]] .. "UnicodeData.txt" .. [[" failed because of ]] .. err .. ".")
    end
  end
  cp("xunicode-symbols.tex", unpackdir, maindir)
end

function doc_posthook()
  os.remove(maindir .. "/xunicode-symbols.tex")
end

function copytds_posthook()
  -- 生成字符映射文件
  make_teckit_mapping()
  -- 字符映射文件
  local mapdir = tdsdir .. "/fonts/misc/xetex/fontmapping/" .. ctanpkg
  mkdir(mapdir)
  cp("*.map", unpackdir, mapdir)
  cp("*.tec", unpackdir, mapdir)
  -- 将字符映射文件复制到 CTAN 目录
  mapdir = ctandir .. "/" .. ctanpkg .. "/teckit-mapping"
  mkdir(mapdir)
  cp("*.map", unpackdir, mapdir)
  -- xunicode 符号表
  local docdir = tdsdir .. "/doc/" .. moduledir
  cp("xunicode-*.tex", typesetdir, docdir)
  -- 示例
  local exampledir = docdir .. "/example"
  mkdir(exampledir)
  cp("xeCJK-example-*.tex", unpackdir, exampledir)
end

dofile("../tool/zhl3build.lua")

-- vim:sw=2:et
