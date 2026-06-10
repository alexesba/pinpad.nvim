local config = require("pinpad.config")

local M = {}

---@param opts PinPadConfig|nil
function M.setup(opts)
  config.setup(opts)

  require("pinpad.highlights").setup()
  require("pinpad.store").load()

  M._setup_keymaps()
end

function M._setup_keymaps()
  local k = config.options.keymaps or {}
  local actions = require("pinpad.actions")
  local ui = require("pinpad.ui")

  if k.add then
    vim.keymap.set("n", k.add, function()
      actions.add()
    end, { silent = true, desc = "PinPad: add todo" })
  end
  if k.toggle then
    vim.keymap.set("n", k.toggle, function()
      ui.toggle()
    end, { silent = true, desc = "PinPad: toggle window" })
  end
end

-- Public API ---------------------------------------------------------------

function M.open()
  require("pinpad.ui").open()
end

function M.close()
  require("pinpad.ui").close()
end

function M.toggle()
  require("pinpad.ui").toggle()
end

---@param text? string
function M.add(text)
  require("pinpad.actions").add(text)
end

function M.toggle_task()
  require("pinpad.actions").toggle()
end

function M.delete_task()
  require("pinpad.actions").delete()
end

---@param priority "low"|"medium"|"high"
function M.set_priority(priority)
  require("pinpad.actions").set_priority_cursor(priority)
end

return M
