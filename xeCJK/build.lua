
module = "xecjk"

-- 发版事实源 (#1041). 与 xeCJK.dtx 的 `{\ExplFileDate}{...}` 必须一致:
--   * 本地发版流程: 改这里 -> `l3build tag` 回写 .dtx -> commit;
--   * PR 校验 check-tag.yml 跑 `l3build tag` 后要求 git diff 为零;
--   * release.yml 打 tag 时校验 git tag / version / .dtx 三方一致.
-- 引入原因: v3.10.5-rc2 之前 xeCJK 不在任何版本校验内, 发 rc2 时 .dtx 仍写
-- 3.10.4, 打出的包自报 v3.10.4 而 tag 是 v3.10.5, 无人拦住.
version = "3.10.6"

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

function runtest_tasks(name, run)
  if name == "fntef-phase01" then
    return 'xdvipdfmx -q -z 0 -o "' .. name .. '.pdf" "'
      .. name .. '.xdv"' .. os_concat
      .. 'texlua fntef-phase-check.lua "' .. name .. '.pdf" "'
      .. name .. '.log"'
  end
  return ""
end

dofile("../support/build-config.lua")

-- ── CTAN upload (用 release-ctan-upload.yml workflow 触发) ────────────────
-- 版本号从 xeCJK.dtx 动态读取, 保证投递的版本与打进 zip 的那个一致.
-- (取的是 `{\ExplFileDate}{<版本>}{\ExplFileDescription}` 里**大括号中的版本号**;
--  `\ExplFileDate` 本身是日期占位宏, 详见 support/build-config.lua 的 update_tag.)
-- 注意方向 (#1041 起): 事实源是本文件顶部的 `version`, `l3build tag` 把它回写进 .dtx;
-- 这里再从 .dtx 读回来, 是为了让 upload 拿到的就是打包进 zip 的那个版本.
-- uploader/email 不在此填, 由 workflow 在 `l3build upload` 命令行注入.
uploadconfig = ctex_kit_uploadconfig {
  pkg         = "xecjk",
  version     = read_dtx_version("xeCJK.dtx"),
  author      = "Leo Liu; Qing Lee; Liam Huang",
  summary     = "Typeset CJK in XeLaTeX",
  description = "xeCJK is a package for typesetting documents in Chinese, "
             .. "Japanese or Korean with XeLaTeX. It provides CJK-specific "
             .. "automatic glue between CJK and non-CJK characters, full "
             .. "control over CJK punctuation compression, separate font "
             .. "families for CJK and Latin scripts, and a number of "
             .. "fine-grained typographic refinements for the CJK script.",
  ctanPath    = "/macros/xetex/latex/xecjk",
}
