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
  { kind = "clip-left", pattern = "q%s+0%.32345%s+0%.43456%s+m%s+Q" },
  { kind = "clip-right", pattern = "q%s+0%.42345%s+0%.53456%s+m%s+Q" },
  { kind = "split", pattern = "q%s+0%.52345%s+0%.63456%s+m%s+Q" },
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
    current = { left = event, patterns = {}, clips = {}, splits = {} }
  elseif event.kind == "right" then
    check(current, "right anchor without left anchor")
    current.right = event
    rows[#rows + 1] = current
    current = nil
  else
    check(current, event.kind .. " event outside an anchored row")
    if event.kind == "wave" or event.kind == "xout" then
      current.patterns[#current.patterns + 1] = event
    elseif event.kind == "split" then
      current.splits[#current.splits + 1] = event
    else
      current.clips[#current.clips + 1] = event
    end
  end
end
check(not current, "last row has no right anchor")
check(#rows == 32, "expected 32 rows, got " .. #rows)

local expected_kinds = {
  "wave", "wave", "wave", "wave",
  "xout", "xout", "xout", "xout",
  "wave", "wave", "wave", "wave",
  "xout", "xout", "xout", "xout",
  "wave", "wave", "xout", "xout",
  "wave", "xout", "wave", "xout",
  "wave", "xout", "wave", "xout",
  "wave", "wave", "xout", "xout",
}
for index, row in ipairs(rows) do
  check(#row.patterns > 1, "row " .. index .. " has too few pattern boxes")
  check(#row.clips >= 2 and #row.clips % 2 == 0,
    "row " .. index .. " has incomplete clipping markers")
  for _, pattern in ipairs(row.patterns) do
    check(pattern.kind == expected_kinds[index],
      "row " .. index .. " contains the wrong pattern kind")
  end
end

local function pattern_positions(row)
  local positions = {}
  for _, pattern in ipairs(row.patterns) do
    positions[#positions + 1] = pattern.x
  end
  table.sort(positions)
  local unique = {}
  for _, position in ipairs(positions) do
    if #unique == 0 or math.abs(position - unique[#unique]) > 0.01 then
      unique[#unique + 1] = position
    end
  end
  return unique
end

local function gaps(row)
  local positions = pattern_positions(row)
  local result = {}
  for index = 2, #positions do
    result[#result + 1] = positions[index] - positions[index - 1]
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

local function clip_spans(row)
  local spans = {}
  local pending
  for _, clip in ipairs(row.clips) do
    if clip.kind == "clip-left" then
      check(not pending, "nested clipping markers in one row")
      pending = clip
    else
      check(pending, "clip-right marker without clip-left marker")
      spans[#spans + 1] = { left = pending, right = clip }
      pending = nil
    end
  end
  check(not pending, "clip-left marker without clip-right marker")
  return spans
end

local function visible_pattern_spans(row)
  local clips = clip_spans(row)
  local spans = {}
  for _, pattern in ipairs(row.patterns) do
    local left = pattern.x
    local right = pattern.x + unit
    for _, clip in ipairs(clips) do
      if pattern.pos > clip.left.pos and pattern.pos < clip.right.pos then
        left = math.max(left, clip.left.x)
        right = math.min(right, clip.right.x)
        break
      end
    end
    if right - left > 0.01 then
      spans[#spans + 1] = { left = left, right = right }
    end
  end
  table.sort(spans, function(a, b)
    if math.abs(a.left - b.left) <= 0.01 then return a.right < b.right end
    return a.left < b.left
  end)
  local merged = {}
  for _, span in ipairs(spans) do
    local current = merged[#merged]
    if current and span.left <= current.right + 0.02 then
      current.right = math.max(current.right, span.right)
    else
      merged[#merged + 1] = { left = span.left, right = span.right }
    end
  end
  return merged
end

local function check_visible_span_count(row_index, expected, label)
  local spans = visible_pattern_spans(rows[row_index])
  local description = {}
  for _, span in ipairs(spans) do
    description[#description + 1] = string.format("[%.4f, %.4f]",
      span.left, span.right)
  end
  check(#spans == expected,
    label .. " has " .. #spans .. " visible decoration spans; expected "
      .. expected .. ": " .. table.concat(description, ", "))
  return spans
end

local function check_shared_grid(first, last, label)
  local origin = pattern_positions(rows[first])[1]
  for index = first, last do
    for _, pattern in ipairs(rows[index].patterns) do
      local periods = (pattern.x - origin) / unit
      check(math.abs(periods - math.floor(periods + 0.5)) <= 0.01,
        label .. " pattern left the shared leaders grid")
    end
  end
end
check_shared_grid(1, 4, "wave")
check_shared_grid(5, 8, "xout")
check_shared_grid(9, 12, "subtract wave")
check_shared_grid(13, 16, "subtract xout")

local function visible_bounds(row)
  local left, right
  for _, clip in ipairs(row.clips) do
    if clip.kind == "clip-left" then
      left = left and math.min(left, clip.x) or clip.x
    else
      right = right and math.max(right, clip.x) or clip.x
    end
  end
  check(left and right, "clipped row has no visible bounds")
  return left, right
end

local function check_centered(first, last, expected, label)
  for index = first, last do
    local row = rows[index]
    local visible_left, visible_right = visible_bounds(row)
    local left_margin = visible_left - row.left.x
    local right_margin = row.right.x - visible_right
    check(math.abs(left_margin - right_margin) <= 0.02,
      label .. " is not centered at offset row " .. index .. ": "
        .. left_margin .. " vs " .. right_margin)
    check(math.abs(left_margin - expected) <= 0.02,
      label .. " has the wrong visible margin at offset row " .. index
        .. ": " .. left_margin .. " vs " .. expected)
  end
end
check_centered(1, 4, -unit / 2, "wave")
check_centered(5, 8, -unit / 2, "xout")
check_centered(9, 12, unit / 2, "subtract wave")
check_centered(13, 16, unit / 2, "subtract xout")

local function check_unit_gaps(row_index, label)
  local minimum, maximum = minmax(gaps(rows[row_index]))
  check(math.abs(minimum - unit) <= 0.02,
    label .. " has overlapping pattern boxes")
  check(math.abs(maximum - unit) <= 0.02,
    label .. " has a gap between pattern boxes")
end
for index = 1, 24 do
  check_unit_gaps(index, "plain row " .. index)
  check_visible_span_count(index, 1,
    "plain row " .. index)
end

local function check_endpoints(normal_index, subtract_index, prefix)
  local normal = rows[normal_index]
  local subtract = rows[subtract_index]
  local half_unit = unit / 2
  local normal_left, normal_right = visible_bounds(normal)
  local subtract_left, subtract_right = visible_bounds(subtract)
  check(math.abs(normal_left - normal.left.x + half_unit) <= 0.02,
    prefix .. " normal form has the wrong left extension")
  check(math.abs(normal.right.x - normal_right + half_unit) <= 0.02,
    prefix .. " normal form has the wrong right extension: "
      .. (normal.right.x - normal_right) .. " vs " .. -half_unit)
  check(math.abs(subtract_left - subtract.left.x - half_unit) <= 0.02,
    prefix .. " subtract form has the wrong left inset")
  check(math.abs(subtract.right.x - subtract_right - half_unit) <= 0.02,
    prefix .. " subtract form has the wrong right inset")
  local normal_width = normal.right.x - normal.left.x
  local subtract_width = subtract.right.x - subtract.left.x
  check(math.abs(normal_width - subtract_width) <= 0.01,
    prefix .. " command width changed between endpoint forms")
end
check_endpoints(17, 18, "wave")
check_endpoints(19, 20, "xout")

local function check_subtract_gap(row_index, label)
  local row = rows[row_index]
  check(#row.splits == 1, label .. " has no unique command split")
  local split = row.splits[1]
  local before, after
  for _, clip in ipairs(row.clips) do
    if clip.pos < split.pos and clip.kind == "clip-right" then
      before = not before and clip.x or math.max(before, clip.x)
    elseif clip.pos > split.pos and clip.kind == "clip-left" then
      after = not after and clip.x or math.min(after, clip.x)
    end
  end
  check(before and after, label .. " is missing clipping bounds at the split")
  local gap = after - before
  check(math.abs(gap - unit) <= 0.02,
    label .. " does not leave one full visible pattern gap: "
      .. gap .. " vs " .. unit)
  local spans = check_visible_span_count(row_index, 2, label)
  check(math.abs((spans[2].left - spans[1].right) - unit) <= 0.02,
    label .. " visible decoration gap is not one full pattern unit")
end
check_subtract_gap(25, "adjacent subtract wave row")
check_subtract_gap(26, "adjacent subtract xout row")

local function check_explicit_skip_row(row_index, label)
  local row = rows[row_index]
  check(#pattern_positions(row) >= 12,
    label .. " did not decorate the explicit one-em skip")
  check_unit_gaps(row_index, label)
end
check_explicit_skip_row(27, "explicit-skip wave row")
check_explicit_skip_row(28, "explicit-skip xout row")
check_visible_span_count(27, 1, "explicit-skip wave row")
check_visible_span_count(28, 1, "explicit-skip xout row")

check(#rows[29].clips == 2 and #rows[30].clips == 2,
  "single-character wave form did not use exactly one clipped segment")
check(#rows[31].clips == 2 and #rows[32].clips == 2,
  "single-character xout form did not use exactly one clipped segment")
check_endpoints(29, 30, "single-character wave")
check_endpoints(31, 32, "single-character xout")
for index = 29, 32 do
  check_visible_span_count(index, 1,
    "single-character row " .. index)
end

local log = read_all(log_path)
local replacement = table.concat({
  "PASS: ordinary leaders keep one shared grid across fragments and offsets",
  "PASS: subtract forms leave symmetric insets without changing command width",
  "PASS: fixed and stretched CJK glue stay on the shared pattern grid",
  "PASS: adjacent subtract commands leave a visible pattern gap",
  "PASS: ordinary explicit skips remain decorated",
}, "\n")
local count
log, count = log:gsub("PHASE%-CHECK%-PENDING", replacement)
check(count == 1, "log placeholder not found exactly once")
local file = assert(io.open(log_path, "wb"))
file:write(log)
file:close()
