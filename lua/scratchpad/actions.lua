local config = require("scratchpad.config")
local store = require("scratchpad.store")

local M = {}

---Lazily require ui to avoid a circular require at load time.
local function ui()
  return require("scratchpad.ui")
end

---Run a mutation against the task under the cursor, then re-render.
---@param fn fun(index: integer)
---@param follow? boolean  -- keep the cursor on the same task after re-sort
local function with_cursor_task(fn, follow)
  local index = ui().task_under_cursor()
  if not index then
    return
  end
  fn(index)
  ui().render()
  if follow then
    ui().focus_index(index)
  end
end

function M.toggle()
  with_cursor_task(function(i)
    store.toggle(i)
  end, true)
end

function M.delete()
  with_cursor_task(function(i)
    store.delete(i)
  end)
end

function M.rotate_priority()
  with_cursor_task(function(i)
    store.rotate_priority(i)
  end, true)
end

function M.priority_up()
  with_cursor_task(function(i)
    store.priority_up(i)
  end, true)
end

function M.priority_down()
  with_cursor_task(function(i)
    store.priority_down(i)
  end, true)
end

---Edit the text of the task under the cursor in a floating editor.
function M.edit()
  local index = ui().task_under_cursor()
  if not index then
    return
  end
  ui().edit_entry(index)
end

---@param below boolean  -- insert relative to cursor task
function M.add_relative(below)
  local cursor_index = ui().task_under_cursor()
  vim.ui.input({ prompt = "New task: " }, function(text)
    if not text or vim.trim(text) == "" then
      return
    end
    local insert_at = nil
    if cursor_index then
      insert_at = below and (cursor_index + 1) or cursor_index
    end
    store.add(text, config.options.default_priority, insert_at)
    ui().render()
  end)
end

---Public add used by :TodoAdd and the global keymap.
---Opens the pad if needed so the result is visible.
---@param text? string
function M.add(text)
  local function do_add(value)
    if not value or vim.trim(value) == "" then
      return
    end
    store.ensure_loaded()
    local task = store.add(value, config.options.default_priority)
    if ui().is_open() then
      -- Already visible: just refresh in place.
      ui().render()
    else
      if config.options.open_on_add then
        ui().open()
      end
      if task and config.options.notify_on_add then
        vim.notify("[ScratchPad] Task added: " .. task.text, vim.log.levels.INFO)
      end
    end
  end

  if text and vim.trim(text) ~= "" then
    do_add(text)
  else
    vim.ui.input({ prompt = "New task: " }, do_add)
  end
end

---Set priority of the cursor task (used by :TodoPriority).
---@param priority "low"|"medium"|"high"
function M.set_priority_cursor(priority)
  if not store.is_valid_priority(priority) then
    vim.notify("[ScratchPad] Invalid priority: " .. tostring(priority), vim.log.levels.ERROR)
    return
  end
  with_cursor_task(function(i)
    store.set_priority(i, priority)
  end, true)
end

---Attach buffer-local mappings to the scratchpad buffer.
---@param buf integer
function M.attach_mappings(buf)
  local m = config.options.mappings
  local map = function(lhs, fn, desc)
    if lhs == false or lhs == nil then
      return
    end
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true, desc = desc })
  end

  map(m.toggle, M.toggle, "ScratchPad: toggle done")
  map(m.edit, M.edit, "ScratchPad: edit task text")
  map(m.delete, M.delete, "ScratchPad: delete task")
  map(m.add_below, function()
    M.add_relative(true)
  end, "ScratchPad: add below")
  map(m.add_above, function()
    M.add_relative(false)
  end, "ScratchPad: add above")
  map(m.rotate_priority, M.rotate_priority, "ScratchPad: rotate priority")
  map(m.priority_up, M.priority_up, "ScratchPad: raise priority")
  map(m.priority_down, M.priority_down, "ScratchPad: lower priority")
  map(m.quit, function()
    ui().close()
  end, "ScratchPad: close")
  map("<Esc>", function()
    ui().close()
  end, "ScratchPad: close")
end

return M
