local M = {}

---@class PinPadWindowOpts
---@field width number      -- ratio (0-1) of editor width, or absolute columns when > 1
---@field height number     -- ratio (0-1) of editor height, or absolute rows when > 1
---@field border string     -- any nvim border style
---@field title string

---@class PinPadIcons
---@field done string
---@field todo string
---@field high string
---@field medium string
---@field low string

---@class PinPadMappings
---@field toggle string|false
---@field edit string|false
---@field delete string|false
---@field add_below string|false
---@field add_above string|false
---@field rotate_priority string|false
---@field priority_up string|false
---@field priority_down string|false
---@field set_due string|false
---@field undo string|false
---@field quit string|false
---@field help string|false

---@class PinPadGlobalKeymaps
---@field add string|false      -- global shortcut for :TodoAdd
---@field toggle string|false   -- global shortcut for :PinPad

---@class PinPadConfig
---@field persist boolean
---@field path string|nil
---@field default_priority "low"|"medium"|"high"
---@field add_priority "low"|"medium"|"high"|"ask"|nil
---@field show_icons boolean
---@field sort boolean
---@field open_on_add boolean
---@field notify_on_add boolean
---@field window PinPadWindowOpts
---@field icons PinPadIcons
---@field mappings PinPadMappings
---@field keymaps PinPadGlobalKeymaps

---@type PinPadConfig
M.defaults = {
  persist = true,
  path = nil, -- nil => stdpath("data").."/pinpad.json"
  default_priority = "medium",
  -- Priority for :TodoAdd / <leader>ta quick-capture:
  -- "low" | "medium" | "high" | "ask" (prompt to choose) | nil (= default_priority)
  add_priority = "low",
  show_icons = true,
  sort = true, -- auto-sort: pending first, then high->medium->low (stable)
  open_on_add = false, -- open the pad after :TodoAdd (false => quick-capture)
  notify_on_add = true, -- show a confirmation notification when a task is added

  window = {
    width = 0.5,
    height = 0.6,
    border = "rounded",
    title = " PinPad ",
  },

  icons = {
    done = "☑",
    todo = "☐",
    high = "●",
    medium = "●",
    low = "●",
  },

  -- buffer-local mappings (set any to false to disable)
  mappings = {
    toggle = "x",
    edit = "<CR>",
    delete = "dd",
    add_below = "o",
    add_above = "O",
    rotate_priority = "p",
    priority_up = ">",
    priority_down = "<",
    set_due = "D", -- set/clear a due date (prompts; accepts ISO date or +Nd/today/...)
    undo = "u", -- restore the most recently deleted task(s)
    quit = "q",
    help = "g?",
  },

  -- global keymaps (set to false to disable)
  keymaps = {
    add = "<leader>ta", -- :TodoAdd
    toggle = "<leader>tp", -- :PinPad (toggle pad)
  },
}

---@type PinPadConfig
M.options = vim.deepcopy(M.defaults)

---@param opts PinPadConfig|nil
---@return PinPadConfig
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

---Resolve the on-disk persistence path.
---@return string
function M.resolve_path()
  if M.options.path and M.options.path ~= "" then
    return vim.fn.expand(M.options.path)
  end
  return vim.fs.joinpath(vim.fn.stdpath("data"), "pinpad.json")
end

return M
