local config = require("scratchpad.config")

local M = {}

---@param opts ScratchPadConfig|nil
function M.setup(opts)
  config.setup(opts)

  require("scratchpad.highlights").setup()
  require("scratchpad.store").load()

  M._setup_keymaps()
end

function M._setup_keymaps()
  local k = config.options.keymaps or {}
  local actions = require("scratchpad.actions")
  local ui = require("scratchpad.ui")

  if k.add then
    vim.keymap.set("n", k.add, function()
      actions.add()
    end, { silent = true, desc = "ScratchPad: add todo" })
  end
  if k.toggle then
    vim.keymap.set("n", k.toggle, function()
      ui.toggle()
    end, { silent = true, desc = "ScratchPad: toggle window" })
  end
end

-- Public API ---------------------------------------------------------------

function M.open()
  require("scratchpad.ui").open()
end

function M.close()
  require("scratchpad.ui").close()
end

function M.toggle()
  require("scratchpad.ui").toggle()
end

---@param text? string
function M.add(text)
  require("scratchpad.actions").add(text)
end

function M.toggle_task()
  require("scratchpad.actions").toggle()
end

function M.delete_task()
  require("scratchpad.actions").delete()
end

---@param priority "low"|"medium"|"high"
function M.set_priority(priority)
  require("scratchpad.actions").set_priority_cursor(priority)
end

return M
