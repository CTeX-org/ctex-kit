随便写点什么，测试 fork 场景的触发。
module = "xecjk"

packtdszip = true
tdsroot = "xelatex"

sourcefiles      = {"xeCJK.dtx"}
unpackfiles      = {"xeCJK.dtx"}
installfiles     = {"*.sty", "*.cfg", "*.def", "*.tex", "*.ins", "*.map", "*.tec"}
unpacksuppfiles  = {"xeCJK.id", "ctxdocstrip.tex"}
typesetsuppfiles = {"ctxdoc.cls"}
typesetfiles     = {"xeCJK.dtx", "xunicode-symbols.tex"}
scriptfiles      = {"xunicode-com*.tex"} -- dirty hack

testfiledir  = "./testfiles"
stdengine    = "xetex"
checkengines = {"xetex"}

tdslocations = {
  "doc/xelatex/xecjk/xunicode-*.tex",
  "doc/xelatex/xecjk/example/xeCJK-example-*.tex",
  "source/xelatex/xecjk/*.ins",
  "fonts/misc/xetex/fontmapping/xecjk/*.map",
  "fonts/misc/xetex/fontmapping/xecjk/*.tec",
}

local zip_open = require("zip").open

local function download_file(url, dest)
  local ok, http = pcall(require, "socket.http")
  if ok then
    local lok, ltn12 = pcall(require, "ltn12")
    if lok then
      local fh = io.open(dest, "wb")
      if fh then
        local status = http.request{
          url  = url,
          sink = ltn12.sink.file(fh)
        }
        if status then return true end
      end
    end
  end
  local ret = os.execute('curl -fsSL -o "' .. dest .. '" "' .. url .. '"')
  if ret == 0 or ret == true then return true end
  ret = os.execute('wget -q -O "' .. dest .. '" "' .. url .. '"')
  if ret == 0 or ret == true then return true end
  return false
end

local function make_teckit_mapping()
  local unihan_variants = "Unihan_Variants.txt"
  local f = io.open(supportdir .. "/" .. unihan_variants, "r")
  if not f then
    local unihan_zip = supportdir .. "/Unihan.zip"
    local zfile = zip_open(unihan_zip)
    if not zfile then
      if not download_file(
        "https://www.unicode.org/Public/UNIDATA/Unihan.zip", unihan_zip)
      then
        error(
          'Failed to download Unihan.zip. Try one of:\n'
          .. '  - Run: texlua --socket "$(kpsewhich l3build.lua)" install\n'
          .. '  - Install curl or wget\n'
          .. '  - Manually place Unihan.zip in ' .. supportdir .. '/'
        )
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

function unpack_posthook()
  if install_files_bool then
    make_teckit_mapping()
  end
end

dtxchecksum = dtxchecksum or {}
dtxchecksum.syntonly = false
dtxchecksum.doccfg  = [[\AtBeginDocument{\XeTeXinterchartokenstate=\z@}]] ..
                      [[\AtBeginDocument{\RenewDocumentCommand\PrintPunctList{O{7}mm}{}}]]

dofile("../support/build-config.lua")
