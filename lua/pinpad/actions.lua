local config = require("pinpad.config")
local store = require("pinpad.store")

local M = {}

---Lazily require ui to avoid a circular require at load time.
local function ui()
  return require("pinpad.ui")
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

---Resolve the task ids covered by the current visual selection, then leave
---visual mode so window/buffer state is settled before any re-render.
---@return string[] ids, PinPadTask[] tasks
local function visual_selection()
  local first = vim.fn.line("v")
  local last = vim.fn.line(".")
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  local ids, tasks = {}, {}
  for _, idx in ipairs(ui().tasks_in_range(first, last)) do
    local t = store.tasks[idx]
    if t then
      ids[#ids + 1] = t.id
      tasks[#tasks + 1] = t
    end
  end
  return ids, tasks
end

---Delete every task covered by the current visual selection.
function M.delete_visual()
  local ids = visual_selection()
  if #ids == 0 then
    return
  end
  local removed = store.delete_ids(ids)
  ui().render()
  if removed > 0 then
    vim.notify(string.format("[PinPad] Deleted %d task%s", removed, removed == 1 and "" or "s"), vim.log.levels.INFO)
  end
end

---Toggle done for every task in the current visual selection. Smart toggle:
---if all selected are already done, un-complete them; otherwise complete all.
function M.toggle_visual()
  local ids, tasks = visual_selection()
  if #ids == 0 then
    return
  end
  local all_done = true
  for _, t in ipairs(tasks) do
    if not t.done then
      all_done = false
      break
    end
  end
  store.set_done_ids(ids, not all_done)
  ui().render()
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
  -- Inherit the neighbour's priority so the new task lands adjacent to it
  -- (equal priority => stable insertion order keeps it where you put it).
  -- Falls back to the configured default when there is no task under the cursor.
  local neighbour = cursor_index and store.tasks[cursor_index]
  local priority = (neighbour and neighbour.priority) or config.options.default_priority
  vim.ui.input({ prompt = "New task: " }, function(text)
    if not text or vim.trim(text) == "" then
      return
    end
    local insert_at = nil
    if cursor_index then
      insert_at = below and (cursor_index + 1) or cursor_index
    end
    local task = store.add(text, priority, insert_at)
    ui().render()
    if task then
      -- Keep the cursor on the freshly added task.
      for i, t in ipairs(store.tasks) do
        if t.id == task.id then
          ui().focus_index(i)
          break
        end
      end
    end
  end)
end

---Public add used by :TodoAdd and the global keymap.
---Opens the pad if needed so the result is visible.
---@param text? string
function M.add(text)
  local function do_add(value, priority)
    if not value or vim.trim(value) == "" then
      return
    end
    store.ensure_loaded()
    local task = store.add(value, priority)
    if ui().is_open() then
      -- Already visible: just refresh in place.
      ui().render()
    else
      if config.options.open_on_add then
        ui().open()
      end
      if task and config.options.notify_on_add then
        vim.notify("[PinPad] Task added: " .. task.text, vim.log.levels.INFO)
      end
    end
  end

  -- Resolve the quick-capture priority, optionally prompting the user.
  local function with_priority(value)
    if not value or vim.trim(value) == "" then
      return
    end
    local mode = config.options.add_priority
    if mode == "ask" then
      vim.ui.select({ "low", "medium", "high" }, { prompt = "Priority:" }, function(choice)
        do_add(value, choice or config.options.default_priority)
      end)
    else
      local priority = store.is_valid_priority(mode) and mode or config.options.default_priority
      do_add(value, priority)
    end
  end

  if text and vim.trim(text) ~= "" then
    with_priority(text)
  else
    vim.ui.input({ prompt = "New task: " }, with_priority)
  end
end

---Set priority of the cursor task (used by :TodoPriority).
---@param priority "low"|"medium"|"high"
function M.set_priority_cursor(priority)
  if not store.is_valid_priority(priority) then
    vim.notify("[PinPad] Invalid priority: " .. tostring(priority), vim.log.levels.ERROR)
    return
  end
  with_cursor_task(function(i)
    store.set_priority(i, priority)
  end, true)
end

---Attach buffer-local mappings to the pinpad buffer.
---@param buf integer
function M.attach_mappings(buf)
  local m = config.options.mappings
  local map = function(lhs, fn, desc)
    if lhs == false or lhs == nil then
      return
    end
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true, desc = desc })
  end

  map(m.toggle, M.toggle, "PinPad: toggle done")
  map(m.edit, M.edit, "PinPad: edit task text")
  map(m.delete, M.delete, "PinPad: delete task")
  -- Visual selection mirrors normal mode: d = delete, x = toggle done (bulk).
  local vmap = function(lhs, fn, desc)
    vim.keymap.set("x", lhs, fn, { buffer = buf, nowait = true, silent = true, desc = desc })
  end
  vmap("d", M.delete_visual, "PinPad: delete selected tasks")
  vmap("x", M.toggle_visual, "PinPad: toggle selected done")
  map(m.add_below, function()
    M.add_relative(true)
  end, "PinPad: add below")
  map(m.add_above, function()
    M.add_relative(false)
  end, "PinPad: add above")
  map(m.rotate_priority, M.rotate_priority, "PinPad: rotate priority")
  map(m.priority_up, M.priority_up, "PinPad: raise priority")
  map(m.priority_down, M.priority_down, "PinPad: lower priority")
  map(m.quit, function()
    ui().close()
  end, "PinPad: close")
  map(m.help, function()
    ui().show_help("PinPad")
  end, "PinPad: show keymaps")
  map("<Esc>", function()
    ui().close()
  end, "PinPad: close")
  -- Repurpose <C-w> to show this buffer's bindings instead of which-key's window
  -- menu (our buffer-local map shadows the global window trigger).
  map("<C-w>", function()
    ui().show_help("PinPad")
  end, "PinPad: show keymaps")
end

return M
