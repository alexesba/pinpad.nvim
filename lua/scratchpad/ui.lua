local config = require("scratchpad.config")
local store = require("scratchpad.store")
local hl = require("scratchpad.highlights")

local M = {}

local ns = vim.api.nvim_create_namespace("ScratchPad")

---@type integer|nil
M.buf = nil
---@type integer|nil
M.win = nil
---Map from buffer line (1-based) -> task index. nil entries are non-task lines.
---@type table<integer, integer>
local line_to_task = {}

---@return boolean
function M.is_open()
  return M.win ~= nil and vim.api.nvim_win_is_valid(M.win)
end

---Resolve the task index for the current cursor line.
---@return integer|nil
function M.task_under_cursor()
  if not M.is_open() then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(M.win)[1]
  return line_to_task[row]
end

---Move the cursor onto the display line for a given store task index.
---Used so the cursor follows a task after it gets re-sorted.
---@param index integer
function M.focus_index(index)
  if not M.is_open() then
    return
  end
  for line, ti in pairs(line_to_task) do
    if ti == index then
      pcall(vim.api.nvim_win_set_cursor, M.win, { line, 0 })
      return
    end
  end
end

---@param opt number  -- ratio (0-1) or absolute (>1)
---@param total integer
---@return integer
local function dimension(opt, total)
  if opt <= 1 then
    return math.max(1, math.floor(total * opt))
  end
  return math.min(total, math.floor(opt))
end

local function ensure_buf()
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    return M.buf
  end
  M.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[M.buf].buftype = "nofile"
  vim.bo[M.buf].bufhidden = "hide"
  vim.bo[M.buf].swapfile = false
  vim.bo[M.buf].filetype = "scratchpad"
  -- All keys here are buffer-local actions; don't show which-key prefix popups.
  vim.b[M.buf].which_key_disable = true
  vim.api.nvim_buf_set_name(M.buf, "ScratchPad")
  return M.buf
end

---@param task ScratchPadTask
---@return string line, table[] highlights  -- highlights: {group, col_start, col_end}
local function format_task(task)
  local opts = config.options
  local checkbox, dot
  if opts.show_icons then
    checkbox = task.done and opts.icons.done or opts.icons.todo
    dot = opts.icons[task.priority] or opts.icons.medium
  else
    checkbox = task.done and "[x]" or "[ ]"
    local letter = ({ high = "H", medium = "M", low = "L" })[task.priority] or "M"
    dot = "[" .. letter .. "]"
  end

  local prefix = checkbox .. " "
  local dot_str = dot .. " "
  local line = prefix .. dot_str .. task.text

  local highlights = {}
  local dot_start = #prefix
  local dot_end = dot_start + #dot
  table.insert(highlights, { group = hl.priority_group(task.priority), s = dot_start, e = dot_end })
  if task.done then
    table.insert(highlights, { group = hl.groups.done, s = dot_end + 1, e = -1 })
  end
  return line, highlights
end

function M.render()
  if not (M.buf and vim.api.nvim_buf_is_valid(M.buf)) then
    return
  end

  store.ensure_loaded()
  line_to_task = {}

  ---@type ScratchPadTask[]
  local tasks = store.tasks
  if config.options.sort then
    -- non-destructive ordered view: pending first, then by priority desc.
    -- Tiebreak on the original index so equal items keep a stable order
    -- (table.sort is not stable on its own).
    local order = { high = 3, medium = 2, low = 1 }
    local view = {}
    for i, t in ipairs(tasks) do
      view[i] = { task = t, idx = i }
    end
    table.sort(view, function(a, b)
      if a.task.done ~= b.task.done then
        return not a.task.done
      end
      local pa = order[a.task.priority] or 0
      local pb = order[b.task.priority] or 0
      if pa ~= pb then
        return pa > pb
      end
      return a.idx < b.idx
    end)
    tasks = {}
    for _, v in ipairs(view) do
      tasks[#tasks + 1] = v.task
      -- keep mapping to the real store index
      line_to_task[#tasks] = v.idx
    end
  end

  local lines = {}
  local hl_specs = {}

  if #tasks == 0 then
    lines = { "", "  No tasks — press \"o\" to add one.", "" }
  else
    for display_i, task in ipairs(tasks) do
      local line, highlights = format_task(task)
      lines[display_i] = line
      hl_specs[display_i] = highlights
      if not config.options.sort then
        line_to_task[display_i] = display_i
      end
    end
  end

  vim.bo[M.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(M.buf, ns, 0, -1)

  if #tasks == 0 then
    vim.api.nvim_buf_set_extmark(M.buf, ns, 1, 0, { end_col = #lines[2], hl_group = hl.groups.hint })
  else
    for display_i, highlights in pairs(hl_specs) do
      for _, h in ipairs(highlights) do
        local e = h.e == -1 and #lines[display_i] or h.e
        if e > h.s then
          vim.api.nvim_buf_set_extmark(M.buf, ns, display_i - 1, h.s, {
            end_col = e,
            hl_group = h.group,
          })
        end
      end
    end
  end

  vim.bo[M.buf].modifiable = false
end

function M.open()
  if M.is_open() then
    vim.api.nvim_set_current_win(M.win)
    return
  end
  hl.setup()
  ensure_buf()

  local ui = vim.api.nvim_list_uis()[1]
  local total_w = (ui and ui.width) or vim.o.columns
  local total_h = (ui and ui.height) or vim.o.lines
  local w = dimension(config.options.window.width, total_w)
  local h = dimension(config.options.window.height, total_h)
  local row = math.floor((total_h - h) / 2)
  local col = math.floor((total_w - w) / 2)

  M.win = vim.api.nvim_open_win(M.buf, true, {
    relative = "editor",
    width = w,
    height = h,
    row = row,
    col = col,
    style = "minimal",
    border = config.options.window.border,
    title = config.options.window.title,
    title_pos = "center",
  })
  vim.wo[M.win].cursorline = true
  vim.wo[M.win].wrap = false

  require("scratchpad.actions").attach_mappings(M.buf)
  M.render()
end

function M.close()
  if M.is_open() then
    vim.api.nvim_win_close(M.win, true)
  end
  M.win = nil
end

function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

---Open a small floating editor for a single task's text.
---<CR> opens it (in insert mode); Esc returns to normal mode, then <CR> saves
---& closes; <C-c> or q cancels.
---@param index integer  -- task index in store
function M.edit_entry(index)
  store.ensure_loaded()
  local task = store.tasks[index]
  if not task then
    return
  end

  local parent_win = M.win

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  -- Suppress which-key's popup in the editor (e.g. on <C-w>); harmless if unused.
  vim.b[buf].which_key_disable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { task.text })

  local ui = vim.api.nvim_list_uis()[1]
  local total_w = (ui and ui.width) or vim.o.columns
  local total_h = (ui and ui.height) or vim.o.lines
  local w = math.max(20, math.min(60, total_w - 4))
  local h = 1
  local row = math.floor((total_h - h) / 2)
  local col = math.floor((total_w - w) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = w,
    height = h,
    row = row,
    col = col,
    style = "minimal",
    border = config.options.window.border,
    title = " Edit task ",
    title_pos = "center",
  })
  vim.wo[win].wrap = false

  local closed = false
  local group = vim.api.nvim_create_augroup("ScratchPadEdit_" .. buf, { clear = true })
  ---@param save boolean
  local function finish(save)
    if closed then
      return
    end
    closed = true
    pcall(vim.api.nvim_del_augroup_by_id, group)
    if save and vim.api.nvim_buf_is_valid(buf) then
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local text = vim.trim(table.concat(lines, " "))
      if text ~= "" then
        store.set_text(index, text)
      end
    end
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if parent_win and vim.api.nvim_win_is_valid(parent_win) then
      vim.api.nvim_set_current_win(parent_win)
    end
    M.render()
  end

  local opts = { buffer = buf, nowait = true, silent = true }
  -- Flow: <Esc> leaves insert mode (native), then <CR> in normal mode saves & closes.
  vim.keymap.set("n", "<CR>", function()
    finish(true)
  end, opts)
  -- Ctrl-C / q: cancel without saving.
  vim.keymap.set("i", "<C-c>", function()
    vim.cmd("stopinsert")
    finish(false)
  end, opts)
  vim.keymap.set("n", "<C-c>", function()
    finish(false)
  end, opts)
  vim.keymap.set("n", "q", function()
    finish(false)
  end, opts)
  -- Trap focus: disable window-switching commands (<C-w>…) in normal mode so the
  -- editor can only be left via <CR>/<C-c>/q. (Insert-mode <C-w> word-delete kept.)
  vim.keymap.set("n", "<C-w>", "<Nop>", opts)

  -- Safety net: if focus leaves the editor by any other means, save + close.
  -- Deferred via vim.schedule so window changes happen outside WinLeave textlock
  -- (closing a window inside WinLeave can silently no-op and orphan the float).
  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    group = group,
    buffer = buf,
    callback = function()
      if closed then
        return
      end
      vim.schedule(function()
        finish(true)
      end)
    end,
  })

  vim.cmd("startinsert!")
end

return M
