-- Pure sort/filter helpers for the pad display view. Separated from ui.lua so
-- ordering and filter rules stay unit-testable without a window.

local date = require("pinpad.date")

local M = {}

local PRIORITY = { high = 3, medium = 2, low = 1 }

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

---Whether a task should appear under the active filter.
---@param task PinPadTask
---@param filter "all"|"today"|nil
---@return boolean
function M.passes_filter(task, filter)
  if not filter or filter == "all" then
    return true
  end
  if filter == "today" then
    return task.due ~= nil and date.is_due_today_or_overdue(task.due)
  end
  return true
end

return M
