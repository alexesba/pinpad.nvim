-- Pure date helpers for pinpad due dates. All dates are plain calendar days in
-- ISO `YYYY-MM-DD` form (no time / timezone). Kept dependency-free and free of
-- side effects so it is easy to unit test.

local M = {}

local DAY = 24 * 60 * 60

---Convert a `YYYY-MM-DD` string into a Unix timestamp (anchored at local noon
---to stay clear of DST edges). Returns nil if the string is not a real date.
---@param d string
---@return integer|nil
local function to_time(d)
  if type(d) ~= "string" then
    return nil
  end
  local y, m, day = d:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if not y then
    return nil
  end
  y, m, day = tonumber(y), tonumber(m), tonumber(day)
  local t = os.time({ year = y, month = m, day = day, hour = 12 })
  if not t then
    return nil
  end
  -- Reject values os.time silently normalised (e.g. month 13, day 32).
  if tonumber(os.date("%Y", t)) ~= y or tonumber(os.date("%m", t)) ~= m or tonumber(os.date("%d", t)) ~= day then
    return nil
  end
  return t
end

---Today's date as `YYYY-MM-DD`.
---@return string
function M.today()
  return os.date("%Y-%m-%d")
end

---Whether `d` is a valid `YYYY-MM-DD` calendar date.
---@param d any
---@return boolean
function M.is_valid(d)
  return to_time(d) ~= nil
end

---Shift a date by a number of days (may be negative). Returns nil if invalid.
---@param d string
---@param days integer
---@return string|nil
function M.offset(d, days)
  local t = to_time(d)
  if not t then
    return nil
  end
  return os.date("%Y-%m-%d", t + days * DAY)
end

---Whole-day difference `b - a` (positive when b is later). Returns nil if either
---date is invalid.
---@param a string
---@param b string
---@return integer|nil
function M.diff_days(a, b)
  local ta, tb = to_time(a), to_time(b)
  if not ta or not tb then
    return nil
  end
  return math.floor((tb - ta) / DAY + 0.5)
end

---Parse user input into a normalised `YYYY-MM-DD`, or nil if unparseable.
---Accepts: an ISO date, `today` / `tomorrow` / `yesterday`, and relative
---offsets `+Nd` / `-Nd` (days) and `+Nw` / `-Nw` (weeks). Empty input is nil.
---@param input string|nil
---@return string|nil
function M.parse(input)
  if type(input) ~= "string" then
    return nil
  end
  local s = vim.trim(input):lower()
  if s == "" then
    return nil
  end
  if s == "today" then
    return M.today()
  elseif s == "tomorrow" then
    return M.offset(M.today(), 1)
  elseif s == "yesterday" then
    return M.offset(M.today(), -1)
  end
  local sign, num, unit = s:match("^([+-])(%d+)([dw])$")
  if sign then
    local n = tonumber(num) * (unit == "w" and 7 or 1)
    return M.offset(M.today(), sign == "-" and -n or n)
  end
  local t = to_time(s)
  if t then
    return os.date("%Y-%m-%d", t)
  end
  return nil
end

---Short human label for a due date relative to a reference day (default today).
---e.g. "overdue (2d)", "today", "tomorrow", "in 5d".
---@param due string
---@param ref? string
---@return string
function M.relative_label(due, ref)
  local d = M.diff_days(ref or M.today(), due)
  if d == nil then
    return tostring(due)
  end
  if d < 0 then
    return string.format("overdue (%dd)", -d)
  elseif d == 0 then
    return "today"
  elseif d == 1 then
    return "tomorrow"
  end
  return string.format("in %dd", d)
end

---Classify a due date for highlighting: "overdue" | "soon" | "later".
---"soon" covers today and tomorrow. Returns nil for invalid dates.
---@param due string
---@param ref? string
---@return "overdue"|"soon"|"later"|nil
function M.status(due, ref)
  local d = M.diff_days(ref or M.today(), due)
  if d == nil then
    return nil
  end
  if d < 0 then
    return "overdue"
  elseif d <= 1 then
    return "soon"
  end
  return "later"
end

return M
