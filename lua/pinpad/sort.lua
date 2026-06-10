-- Pure sort/filter helpers for the pad display view. Separated from ui.lua so
-- ordering and filter rules stay unit-testable without a window.

local date = require("pinpad.date")

local M = {}

local PRIORITY = { high = 3, medium = 2, low = 1 }
local DONE_CYCLE = { "all", "pending", "done" }
local PRIORITY_CYCLE = { "all", "high", "medium", "low" }

---@class PinPadViewFilter
---@field today boolean
---@field query string|nil
---@field done "all"|"pending"|"done"
---@field priority "low"|"medium"|"high"|nil

---@return PinPadViewFilter
function M.default_filter()
  return { today = false, query = nil, done = "all", priority = nil }
end

---Whether any filter is active (non-default).
---@param filter PinPadViewFilter
---@return boolean
function M.filter_active(filter)
  return filter.today
    or (filter.query ~= nil and filter.query ~= "")
    or filter.done ~= "all"
    or filter.priority ~= nil
end

---Build a short title suffix, e.g. `(today, pending, "fix", high)`.
---@param filter PinPadViewFilter
---@return string|nil
function M.filter_title_suffix(filter)
  local parts = {}
  if filter.today then
    parts[#parts + 1] = "today"
  end
  if filter.done ~= "all" then
    parts[#parts + 1] = filter.done
  end
  if filter.priority then
    parts[#parts + 1] = filter.priority
  end
  if filter.query and filter.query ~= "" then
    parts[#parts + 1] = string.format('"%s"', filter.query)
  end
  if #parts == 0 then
    return nil
  end
  return table.concat(parts, ", ")
end

---Advance the done-state filter: all → pending → done → all.
---@param current "all"|"pending"|"done"
---@return "all"|"pending"|"done"
function M.cycle_done(current)
  for i, v in ipairs(DONE_CYCLE) do
    if v == current then
      return DONE_CYCLE[(i % #DONE_CYCLE) + 1]
    end
  end
  return "all"
end

---Advance the priority filter: all → high → medium → low → all.
---@param current "low"|"medium"|"high"|nil
---@return "low"|"medium"|"high"|nil
function M.cycle_priority(current)
  local key = current or "all"
  for i, v in ipairs(PRIORITY_CYCLE) do
    if v == key then
      local next = PRIORITY_CYCLE[(i % #PRIORITY_CYCLE) + 1]
      if next == "all" then
        return nil
      end
      return next
    end
  end
  return nil
end

---Compare two view entries `{ task, idx }` for display ordering.
---Pending first, priority desc, optional due-date asc (undated last), then idx.
---@param a { task: PinPadTask, idx: integer }
---@param b { task: PinPadTask, idx: integer }
---@param sort_by_due? boolean
---@return boolean
function M.compare(a, b, sort_by_due)
  if a.task.done ~= b.task.done then
    return not a.task.done
  end
  local pa = PRIORITY[a.task.priority] or 0
  local pb = PRIORITY[b.task.priority] or 0
  if pa ~= pb then
    return pa > pb
  end
  if sort_by_due then
    local ka = date.sort_key(a.task.due)
    local kb = date.sort_key(b.task.due)
    if ka ~= kb then
      return ka < kb
    end
  end
  return a.idx < b.idx
end

---Whether a task should appear under the active view filter.
---@param task PinPadTask
---@param filter PinPadViewFilter|string|nil  -- string legacy: "all"|"today"
---@return boolean
function M.passes_filter(task, filter)
  if filter == nil or filter == "all" then
    return true
  end
  if type(filter) == "string" then
    if filter == "today" then
      return task.due ~= nil and date.is_due_today_or_overdue(task.due)
    end
    return true
  end

  if filter.today then
    if not task.due or not date.is_due_today_or_overdue(task.due) then
      return false
    end
  end
  if filter.query and filter.query ~= "" then
    local needle = filter.query:lower()
    if not task.text:lower():find(needle, 1, true) then
      return false
    end
  end
  if filter.done == "pending" and task.done then
    return false
  end
  if filter.done == "done" and not task.done then
    return false
  end
  if filter.priority and task.priority ~= filter.priority then
    return false
  end
  return true
end

return M
