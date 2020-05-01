--
--  File ctex-zhconv.lua
--
--     Copyright (C) 2020 by Qing Lee <sobenlee@gmail.com>
--------------------------------------------------------------------------
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
--     This work has the LPPL maintenance status "maintained".
--
--     The Current Maintainer of this work is Qing Lee.
--
--     This work consists of the files ctex-zhconv.lua, ctex-zhconv-make.lua
--               and the derived file  ctex-zhconv-index.lua.
--
--------------------------------------------------------------------------
--

if status.kpse_used ~= 1 then
  kpse.set_program_name("luatex")
end

local zhconv  = { }
zhconv.module = {
  name        = "ctex-zhconv",
  version     = "0.2",
  date        = "2020/05/02",
  description = "GBK/GB18030/Big5 encoder",
  author      = "Qing Lee",
  copyright   = "Qing Lee",
  license     = "LPPL v1.3c"
}

local utf = require("unicode").utf8
local ubyte, ugsub = utf.byte, utf.gsub

local floor = math.floor
local unpack, insert, sort = table.unpack, table.insert, table.sort
local char, format = string.char, string.format

zhconv.index = require("ctex-zhconv-index")
local index = zhconv.index

zhconv.mapping = { }
local mapping = zhconv.mapping

mapping.big5, mapping.gbk, mapping.gb18030 = { }, { }, { }
local gbk, gb18030, big5 = mapping.gbk, mapping.gb18030, mapping.big5

zhconv.bytes = { }
local bytes = zhconv.bytes

-- Let lead be pointer / 190 + 0x81.
-- Let trail be pointer % 190.
-- Let offset be 0x40 if trail is less than 0x3F and 0x41 otherwise.
-- Return two bytes whose values are lead and trail + offset.
function bytes.gbk (pointer)
  local lead = floor(pointer / 190) + 0x81
  local trail = pointer % 190
  local offset = trail < 0x3F and 0x40 or 0x41
  return format("%c%c", lead, trail + offset)
end

-- Let lead be pointer / 157 + 0x81.
-- If lead is less than 0xA1, return error with code point.
-- Let trail be pointer % 157.
-- Let offset be 0x40 if trail is less than 0x3F and 0x62 otherwise.
-- Return two bytes whose values are lead and trail + offset.
function bytes.big5 (pointer)
  local lead = floor(pointer / 157) + 0x81
  local trail = pointer % 157
  local offset = trail < 0x3F and 0x40 or 0x62
  return format("%c%c", lead, trail + offset)
end

-- Let byte1 be pointer / 10 / 126 / 10.
-- Set pointer to pointer - byte1 × 10 × 126 × 10.
-- Let byte2 be pointer / 10 / 126.
-- Set pointer to pointer - byte2 × 10 × 126.
-- Let byte3 be pointer / 10.
-- Let byte4 be pointer - byte3 × 10.
-- Return four bytes whose values are byte1 + 0x81, byte2 + 0x30, byte3 + 0x81, byte4 + 0x30.
function bytes.gb18030 (pointer)
  local pointer = pointer
  local byte1 = floor(pointer / 12600) + 0x81
  pointer = pointer % 12600
  local byte2 = floor(pointer / 1260) + 0x30
  pointer = pointer % 1260
  local byte3 = floor(pointer / 10) + 0x81
  local byte4 = pointer % 10 + 0x30
  return format("%c%c%c%c", byte1, byte2, byte3, byte4)
end

-- Let offset be the last code point in index gb18030 ranges that is equal to or
-- less than code point and let pointer offset be its corresponding pointer.
-- Return a pointer whose value is pointer offset + code point - offset.
do
  local metatable = { }
  local bytes, ranges = bytes.gb18030, index["gb18030_ranges"]
  function metatable.__index (t, key)
    if type(key) == "number" then
      local n = #ranges
      if key < 0x10000 then
        local s = gbk[key]
        if s then return s end
        repeat
          n = n - 1
        until ranges[n][2] <= key
      end
      local pointer, offset = unpack(ranges[n])
      return bytes(pointer + key - offset)
    end
  end
  gb18030 = setmetatable(gb18030, metatable)
end

-- The index Big5 pointer for code point is the return value of these steps:
-- 1. Let index be index Big5 excluding all entries whose pointer
--    is less than (0xA1 - 0x81) × 157.
-- 2. If code point is U+2550, U+255E, U+2561, U+256A, U+5341, or U+5345,
--    return the last pointer corresponding to code point in index.
local big5_last = {
  [0x2550] = true ,
  [0x255E] = true ,
  [0x2561] = true ,
  [0x256A] = true ,
  [0x5341] = true ,
  [0x5345] = true ,
}

do

local function spairs (t)
  local a = { }
  for i, n in pairs(t) do insert(a, {i, n}) end
  sort(a, function(b, c) return b[1] < c[1] end)
  local i = 0
  local iter = function ()
    i = i + 1
    if a[i] then
      return a[i][1], a[i][2]
    end
  end
  return iter
end

local chars = bytes.big5
local m = (0xA1 - 0x81) * 157
for i, v in spairs(index.big5) do
  if i >= m then
    if big5[v] then
      if big5_last[v] then big5[v] = chars(i) end
    else
      big5[v] = chars(i)
    end
  end
end

local chars = bytes.gbk
for i, v in pairs(index.gb18030) do
  gbk[v] = chars(i)
end

end

-- If the gbk flag is set and code point is U+20AC, return byte 0x80.
gb18030[0x20AC] = gbk[0x20AC]
gbk[0x20AC]     = char(0x80)

local io_open = io.open
local encode_error = "Encoding %q not available!"
local file_error   = "Open file %q failed!"

function zhconv.conv (encoding, input, output)
  local encoding = encoding:lower()
  local mapping = assert(mapping[encoding], encode_error:format(encoding))
  local encoder = function (s)
    local code_point = ubyte(s)
    return code_point > 0x7F and mapping[code_point]
  end
  if output then
    local handle = assert(io_open(input, "rb"), file_error:format(input))
    local stream = handle:read("*all")
    handle:close()
    handle = assert(io_open(output, "wb"), file_error:format(output))
    stream = stream:gsub("^\xEF\xBB\xBF", "")
    stream = ugsub(stream, ".", encoder)
    handle:write(stream)
    handle:close()
  else
    local s = ugsub(input, ".", encoder)
    return s
  end
end

return zhconv
