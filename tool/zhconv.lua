--
--  This is file `zhconv.lua',
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

zhconv        = zhconv or {}
local zhconv  = zhconv
zhconv.module = {
  name        = "zhconv",
  version     = "0",
  date        = "2015/05/01",
  description = "GB18030/Big5 encoder",
  author      = "Qing Lee",
  copyright   = "Qing Lee",
  license     = "LPPL v1.3c"
}

local io = require("io")
local utf8 = require("unicode").utf8
local http_request = require("socket.http").request
local ltn12_sink_file = require("ltn12").sink.file

local math_floor = math.floor
local string_char = string.char
local table_unpack = table.unpack
local utf8_byte, utf8_gsub = utf8.byte, utf8.gsub

zhconv.encoder = { }
local encoder = zhconv.encoder
encoder.big5 = { }
encoder.gb18030 = { }
encoder.big5.mapping, encoder.gb18030.mapping = { }, { }
encoder.gb18030.ranges = { }
encoder.gbk = encoder.gb18030

local big5_mapping, gb18030_mapping = encoder.big5.mapping, encoder.gb18030.mapping
local gb18030_ranges = encoder.gb18030.ranges

-- Let lead be pointer / 190 + 0x81.
-- Let trail be pointer % 190.
-- Let offset be 0x40 if trail is less than 0x3F and 0x41 otherwise.
-- Return two bytes whose values are lead and trail + offset. 
local function gbk_bytes (pointer)
  local lead = math_floor(pointer / 190) + 0x81
  local trail = pointer % 190
  local offset = trail < 0x3F and 0x40 or 0x41
  return string_char(lead) .. string_char(trail + offset)
end

-- Let lead be pointer / 157 + 0x81.
-- If lead is less than 0xA1, return error with code point. 
-- Let trail be pointer % 157.
-- Let offset be 0x40 if trail is less than 0x3F and 0x62 otherwise.
-- Return two bytes whose values are lead and trail + offset. 
local function big5_bytes (pointer)
  local lead = math_floor(pointer / 157) + 0x81
  local trail = pointer % 157
  local offset = trail < 0x3F and 0x40 or 0x62
  return string_char(lead) .. string_char(trail + offset)
end

-- Let byte1 be pointer / 10 / 126 / 10.
-- Set pointer to pointer - byte1 × 10 × 126 × 10.
-- Let byte2 be pointer / 10 / 126.
-- Set pointer to pointer - byte2 × 10 × 126.
-- Let byte3 be pointer / 10.
-- Let byte4 be pointer - byte3 × 10.
-- Return four bytes whose values are byte1 + 0x81, byte2 + 0x30, byte3 + 0x81, byte4 + 0x30.
local function gb18030_bytes (pointer)
  local pointer = pointer
  local byte1 = math_floor(pointer / 12600) + 0x81
  pointer = pointer % 12600
  local byte2 = math_floor(pointer / 1260) + 0x30
  pointer = pointer % 1260
  local byte3 = math_floor(pointer / 10) + 0x81
  local byte4 = pointer % 10 + 0x30
  return string_char(byte1) .. string_char(byte2) .. string_char(byte3) .. string_char(byte4)
end

-- Let offset be the last code point in index gb18030 ranges that is equal to or
-- less than code point and let pointer offset be its corresponding pointer.
-- Return a pointer whose value is pointer offset + code point - offset. 
do
  local mt = { }
  function mt.__index (t, key)
    if type(key) == "number" then
      for i, v in pairs(gb18030_ranges) do
        if v[1] <= key and key < v[2] then
          return gb18030_bytes(i + key - v[1])
        end
      end
    end
  end
  setmetatable(gb18030_mapping, mt)
end

local function script_path ()
  local str = debug.getinfo(2, "S").source:sub(2)
  str = str:match("(.*[/\\])") or './'
  return str:gsub('\\', '/')
end

local function prepare_index (file)
  local file_path = script_path() .. file
  local f = io.open(file_path, "r")
  if f then return f end
  f = io.open(file_path, "wb")
  if not f then
    file_path = file
    f = assert(io.open(file_path, "wb"))
  end
  http_request{
    url  = "http://www.w3.org/TR/encoding/indexes/" .. file, 
    sink = ltn12_sink_file(f) }
  return assert(io.open(file_path, "r"))
end

local pointer, code_point
for _, v in pairs { { "index-big5.txt", big5_mapping, big5_bytes },
                    { "index-gb18030.txt", gb18030_mapping, gbk_bytes } } do
  local file, mapping, bytes = table_unpack(v)
  local f = prepare_index(file)
  for line in f:lines() do
    pointer, code_point = line:match("^%s*(%d+)\t(0x%x+)")
    if pointer and code_point then
      mapping[tonumber(code_point)] = bytes(pointer)
    end
  end
  f:close()
 end
 
local f = prepare_index("index-gb18030-ranges.txt")
local prev_pointer, prev_code_point
for line in f:lines() do
  pointer, code_point = line:match("^%s*(%d+)\t(0x%x+)")
  if pointer and code_point then
    if prev_pointer then
      gb18030_ranges[prev_pointer] = { prev_code_point, tonumber(code_point) }
    end
    prev_pointer, prev_code_point = tonumber(pointer), tonumber(code_point)
  end
end
f:close()
gb18030_ranges[prev_pointer] = { prev_code_point, 0x110000 }

function zhconv.conv (input, output, encoding)
  local encoding = encoding or "gb18030"
  encoding = encoding:lower()
  local encoder = assert(encoder[encoding], "Encoding " .. encoding .. " not available!")
  local mapping = encoder.mapping
  local replace_str = function (s)
    local code_point = utf8_byte(s)
    return code_point > 0x7F and mapping[code_point]
  end
  local f = assert(io.open(input, "r"))
  local stream = f:read("*all")
  f:close()
  f = assert(io.open(output, "wb"))
  stream = stream:gsub("^\xEF\xBB\xBF", "")
  stream = utf8_gsub(stream, "[%C%S]", replace_str)
  f:write(stream)
  f:close()
end

return zhconv
