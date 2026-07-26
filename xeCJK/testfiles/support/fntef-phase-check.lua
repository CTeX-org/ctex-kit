local pdf_path = assert(arg[1], "missing PDF path")
local log_path = assert(arg[2], "missing log path")

local function read_all(path)
  local file = assert(io.open(path, "rb"))
  local data = file:read("*a")
  file:close()
  return data
end

local function fail(message)
  io.stderr:write("fntef phase check failed: ", message, "\n")
  os.exit(1)
end

local function check(condition, message)
  if not condition then fail(message) end
end

local pdf = read_all(pdf_path)
local marker_specs = {
  { kind = "left", pattern = "q%s+0%.54321%s+0%.65432%s+m%s+Q" },
  { kind = "right", pattern = "q%s+0%.64321%s+0%.75432%s+m%s+Q" },
  { kind = "wave", pattern = "q%s+0%.12345%s+0%.23456%s+m%s+Q" },
  { kind = "xout", pattern = "q%s+0%.22345%s+0%.33456%s+m%s+Q" },
  { kind = "wave-left-end", pattern = "q%s+0%.32345%s+0%.43456%s+m%s+Q" },
  { kind = "wave-right-end", pattern = "q%s+0%.42345%s+0%.53456%s+m%s+Q" },
  { kind = "xout-left-end", pattern = "q%s+0%.52345%s+0%.63456%s+m%s+Q" },
  { kind = "xout-right-end", pattern = "q%s+0%.62345%s+0%.73456%s+m%s+Q" },
  { kind = "wave-glue-left", pattern = "q%s+0%.72345%s+0%.83456%s+m%s+Q" },
  { kind = "wave-glue-right", pattern = "q%s+0%.82345%s+0%.93456%s+m%s+Q" },
  { kind = "xout-glue-left", pattern = "q%s+0%.92345%s+1%.03456%s+m%s+Q" },
  { kind = "xout-glue-right", pattern = "q%s+1%.02345%s+1%.13456%s+m%s+Q" },
}

local events = {}
for _, spec in ipairs(marker_specs) do
  local init = 1
  while true do
    local first, last = pdf:find(spec.pattern, init)
    if not first then break end
    local tail = pdf:sub(last + 1, last + 300)
    local x, y = tail:match(
      "q%s+[%+%-]?[%d%.]+%s+w%s+"
        .. "([%+%-]?[%d%.]+)%s+([%+%-]?[%d%.]+)%s+m")
    check(x and y, spec.kind .. " coordinate not found")
    events[#events + 1] = {
      kind = spec.kind,
      pos = first,
      x = tonumber(x),
      y = tonumber(y),
    }
    init = last + 1
  end
end
table.sort(events, function(a, b) return a.pos < b.pos end)

local rows = {}
local current
for _, event in ipairs(events) do
  if event.kind == "left" then
    check(not current, "left anchor before previous row ended")
    current = { left = event, patterns = {}, extra = {} }
  elseif event.kind == "right" then
    check(current, "right anchor without left anchor")
    current.right = event
    rows[#rows + 1] = current
    current = nil
  else
    check(current, event.kind .. " event outside an anchored row")
    if event.kind == "wave" or event.kind == "xout" then
      current.patterns[#current.patterns + 1] = event
    else
      current.extra[#current.extra + 1] = event
    end
  end
end
check(not current, "last row has no right anchor")
check(#rows == 20, "expected 20 rows, got " .. #rows)

local expected_kinds = {
  "wave", "wave", "wave", "wave",
  "xout", "xout", "xout", "xout",
  "wave", "wave", "xout", "xout",
  "wave", "xout", "wave", "xout",
  "wave", "xout", "wave", "xout",
}
for index, row in ipairs(rows) do
  check(#row.patterns > 1, "row " .. index .. " has too few pattern boxes")
  for _, pattern in ipairs(row.patterns) do
    check(pattern.kind == expected_kinds[index],
      "row " .. index .. " contains the wrong pattern kind")
  end
end

local function gaps(row)
  local result = {}
  for index = 2, #row.patterns do
    result[#result + 1] = row.patterns[index].x - row.patterns[index - 1].x
  end
  return result
end

local function minmax(values)
  local minimum, maximum = values[1], values[1]
  for index = 2, #values do
    minimum = math.min(minimum, values[index])
    maximum = math.max(maximum, values[index])
  end
  return minimum, maximum
end

local function median(values)
  local copy = {}
  for index, value in ipairs(values) do copy[index] = value end
  table.sort(copy)
  return copy[(#copy + 1) // 2]
end

local unit = median(gaps(rows[1]))
check(unit > 0, "non-positive pattern unit")

local function check_phase(first, last, label)
  local minimum, maximum
  for index = first, last do
    local delta = rows[index].patterns[1].x - rows[index].left.x
    minimum = minimum and math.min(minimum, delta) or delta
    maximum = maximum and math.max(maximum, delta) or delta
  end
  check(maximum - minimum <= 0.01,
    label .. " phase changes with the outer horizontal offset")
end
check_phase(1, 4, "wave")
check_phase(5, 8, "xout")
for index = 1, 4 do
  local wave_delta = rows[index].patterns[1].x - rows[index].left.x
  local xout_delta = rows[index + 4].patterns[1].x - rows[index + 4].left.x
  check(math.abs(wave_delta - xout_delta) <= 0.01,
    "wave and xout use different phase geometry at offset row " .. index)
end

local function check_unit_gaps(row_index, label)
  local minimum, maximum = minmax(gaps(rows[row_index]))
  check(math.abs(minimum - unit) <= 0.02,
    label .. " has overlapping pattern boxes")
  check(math.abs(maximum - unit) <= 0.02,
    label .. " has a gap between pattern boxes")
end
for index = 1, 12 do
  check_unit_gaps(index, "plain row " .. index)
end

local function extras(row, kind)
  local result = {}
  for _, event in ipairs(row.extra) do
    if event.kind == kind then result[#result + 1] = event end
  end
  return result
end

local function check_glue_row(row_index, prefix, label)
  local row = rows[row_index]
  local lefts = extras(row, prefix .. "-glue-left")
  local rights = extras(row, prefix .. "-glue-right")
  check(#row.patterns == 16,
    label .. " emitted pattern boxes inside CJK glue")
  check(#lefts == 3 and #rights == 3,
    label .. " did not expose exactly three CJK glue spans")
  for index = 1, 3 do
    local span = rights[index].x - lefts[index].x
    check(span > 0.02, label .. " has a non-positive CJK glue width")
    local before, after
    for _, pattern in ipairs(row.patterns) do
      if pattern.x < lefts[index].x then
        before = not before and pattern
          or (pattern.x > before.x and pattern or before)
      end
      if pattern.x >= rights[index].x - 0.02 and
          (not after or pattern.x < after.x) then
        after = pattern
      end
    end
    check(before and after, label .. " glue is not between pattern boxes")
    check(math.abs((after.x - before.x) - (unit + span)) <= 0.03,
      label .. " duplicates or drops a pattern box at CJK glue")
  end
end
check_glue_row(13, "wave", "fixed-glue wave row")
check_glue_row(14, "xout", "fixed-glue xout row")
check_glue_row(15, "wave", "stretched-glue wave row")
check_glue_row(16, "xout", "stretched-glue xout row")

local function check_endpoints(normal_index, subtract_index, prefix)
  local normal = rows[normal_index]
  local subtract = rows[subtract_index]
  local lefts = extras(normal, prefix .. "-left-end")
  local rights = extras(normal, prefix .. "-right-end")
  check(#lefts == 1 and #rights == 1,
    prefix .. " normal form is missing a half-unit endpoint")
  check(#extras(subtract, prefix .. "-left-end") == 0 and
        #extras(subtract, prefix .. "-right-end") == 0,
    prefix .. " subtract form unexpectedly draws an outer endpoint")

  local half_unit = unit / 2
  local left_extension = normal.left.x - lefts[1].x
  local right_extension = rights[1].x + half_unit - normal.right.x
  check(math.abs(left_extension - half_unit) <= 0.02,
    prefix .. " left endpoint is not half a pattern unit")
  check(math.abs(right_extension - half_unit) <= 0.02,
    prefix .. " right endpoint is not half a pattern unit")
  check(math.abs(left_extension - right_extension) <= 0.02,
    prefix .. " normal endpoints are not symmetric")

  check(math.abs(subtract.patterns[1].x - subtract.left.x) <= 0.02,
    prefix .. " subtract form does not start at the text boundary")
  check(math.abs(subtract.patterns[#subtract.patterns].x + unit
      - subtract.right.x) <= 0.02,
    prefix .. " subtract form does not end at the text boundary")
  local normal_width = normal.right.x - normal.left.x
  local subtract_width = subtract.right.x - subtract.left.x
  check(math.abs(normal_width - subtract_width) <= 0.01,
    prefix .. " command width changed between endpoint forms")
end
check_endpoints(9, 10, "wave")
check_endpoints(11, 12, "xout")

check_unit_gaps(17, "adjacent subtract wave row")
check_unit_gaps(18, "adjacent subtract xout row")

local function check_explicit_skip_row(row_index, label)
  local row = rows[row_index]
  check(#row.patterns == 12,
    label .. " did not decorate the explicit one-em skip")
  check_unit_gaps(row_index, label)
end
check_explicit_skip_row(19, "explicit-skip wave row")
check_explicit_skip_row(20, "explicit-skip xout row")

local log = read_all(log_path)
local replacement = table.concat({
  "PASS: periodic decoration phase is stable across horizontal offsets",
  "PASS: normal endpoints extend symmetrically and subtract endpoints meet the text",
  "PASS: fixed and stretched CJK glue do not duplicate periodic boxes",
  "PASS: adjacent subtract commands keep one-unit pattern spacing",
  "PASS: ordinary explicit skips remain decorated",
}, "\n")
local count
log, count = log:gsub("PHASE%-CHECK%-PENDING", replacement)
check(count == 1, "log placeholder not found exactly once")
local file = assert(io.open(log_path, "wb"))
file:write(log)
file:close()
