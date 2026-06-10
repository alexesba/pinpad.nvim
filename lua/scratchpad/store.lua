local config = require("scratchpad.config")

local M = {}

---@class ScratchPadTask
---@field id string
---@field text string
---@field done boolean
---@field priority "low"|"medium"|"high"

---@type ScratchPadTask[]
M.tasks = {}

local PRIORITIES = { "low", "medium", "high" }
M.PRIORITIES = PRIORITIES

local loaded = false
local id_counter = 0

---@return string
local function next_id()
  id_counter = id_counter + 1
  return tostring(os.time()) .. "-" .. tostring(id_counter)
end

---@param p any
---@return boolean
function M.is_valid_priority(p)
  return p == "low" or p == "medium" or p == "high"
end

---Read + decode the JSON file. Missing/corrupt => empty list (warn once).
function M.load()
  M.tasks = {}
  if not config.options.persist then
    loaded = true
    return
  end

  local path = config.resolve_path()
  local fd = io.open(path, "r")
  if not fd then
    loaded = true
    return
  end

  local content = fd:read("*a")
  fd:close()
  if not content or content == "" then
    loaded = true
    return
  end

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" then
    vim.notify("[ScratchPad] Could not parse " .. path .. ", starting empty.", vim.log.levels.WARN)
    loaded = true
    return
  end

  for _, item in ipairs(decoded) do
    if type(item) == "table" and type(item.text) == "string" then
      table.insert(M.tasks, {
        id = (type(item.id) == "string" and item.id) or next_id(),
        text = item.text,
        done = item.done == true,
        priority = M.is_valid_priority(item.priority) and item.priority or config.options.default_priority,
      })
    end
  end
  loaded = true
end

---Ensure tasks are loaded exactly once.
function M.ensure_loaded()
  if not loaded then
    M.load()
  end
end

---Encode + write the JSON file (no-op when persistence disabled).
function M.save()
  if not config.options.persist then
    return
  end

  local path = config.resolve_path()
  local dir = vim.fs.dirname(path)
  if dir then
    vim.fn.mkdir(dir, "p")
  end

  local ok, encoded = pcall(vim.json.encode, M.tasks)
  if not ok then
    vim.notify("[ScratchPad] Failed to encode tasks.", vim.log.levels.ERROR)
    return
  end

  local fd = io.open(path, "w")
  if not fd then
    vim.notify("[ScratchPad] Cannot write " .. path, vim.log.levels.ERROR)
    return
  end
  fd:write(encoded)
  fd:close()
end

---@param text string
---@param priority? "low"|"medium"|"high"
---@param index? integer  -- 1-based insertion position; defaults to end
---@return ScratchPadTask|nil
function M.add(text, priority, index)
  text = vim.trim(text or "")
  if text == "" then
    return nil
  end
  local task = {
    id = next_id(),
    text = text,
    done = false,
    priority = M.is_valid_priority(priority) and priority or config.options.default_priority,
  }
  if index and index >= 1 and index <= #M.tasks + 1 then
    table.insert(M.tasks, index, task)
  else
    table.insert(M.tasks, task)
  end
  M.save()
  return task
end

---@param index integer
---@param text string
function M.set_text(index, text)
  local t = M.tasks[index]
  if not t then
    return
  end
  text = vim.trim(text or "")
  if text == "" then
    return
  end
  t.text = text
  M.save()
end

---@param index integer
function M.toggle(index)
  local t = M.tasks[index]
  if not t then
    return
  end
  t.done = not t.done
  M.save()
end

---@param index integer
function M.delete(index)
  if not M.tasks[index] then
    return
  end
  table.remove(M.tasks, index)
  M.save()
end

---Set the done state for every task whose id is in the list. Returns count changed.
---@param ids string[]
---@param done boolean
---@return integer
function M.set_done_ids(ids, done)
  local set = {}
  for _, id in ipairs(ids) do
    set[id] = true
  end
  local changed = 0
  for _, t in ipairs(M.tasks) do
    if set[t.id] and t.done ~= done then
      t.done = done
      changed = changed + 1
    end
  end
  if changed > 0 then
    M.save()
  end
  return changed
end

---Delete every task whose id is in the given list. Returns the count removed.
---@param ids string[]
---@return integer
function M.delete_ids(ids)
  local set = {}
  for _, id in ipairs(ids) do
    set[id] = true
  end
  local kept, removed = {}, 0
  for _, t in ipairs(M.tasks) do
    if set[t.id] then
      removed = removed + 1
    else
      kept[#kept + 1] = t
    end
  end
  if removed > 0 then
    M.tasks = kept
    M.save()
  end
  return removed
end

---@param index integer
---@param priority "low"|"medium"|"high"
function M.set_priority(index, priority)
  local t = M.tasks[index]
  if not t or not M.is_valid_priority(priority) then
    return
  end
  t.priority = priority
  M.save()
end

---@param current "low"|"medium"|"high"
---@param step integer  -- +1 raise, -1 lower
---@param wrap boolean
---@return "low"|"medium"|"high"
local function shift_priority(current, step, wrap)
  local idx = 2
  for i, p in ipairs(PRIORITIES) do
    if p == current then
      idx = i
      break
    end
  end
  idx = idx + step
  if wrap then
    idx = ((idx - 1) % #PRIORITIES) + 1
  else
    idx = math.max(1, math.min(#PRIORITIES, idx))
  end
  return PRIORITIES[idx]
end

---Rotate low->medium->high->low.
---@param index integer
function M.rotate_priority(index)
  local t = M.tasks[index]
  if not t then
    return
  end
  t.priority = shift_priority(t.priority, 1, true)
  M.save()
end

---@param index integer
function M.priority_up(index)
  local t = M.tasks[index]
  if not t then
    return
  end
  t.priority = shift_priority(t.priority, 1, false)
  M.save()
end

---@param index integer
function M.priority_down(index)
  local t = M.tasks[index]
  if not t then
    return
  end
  t.priority = shift_priority(t.priority, -1, false)
  M.save()
end

return M
