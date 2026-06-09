if vim.g.loaded_scratchpad then
  return
end
vim.g.loaded_scratchpad = true

local function sp()
  return require("scratchpad")
end

vim.api.nvim_create_user_command("ScratchPad", function()
  sp().toggle()
end, { desc = "Toggle the ScratchPad todo window" })

vim.api.nvim_create_user_command("TodoList", function()
  sp().open()
end, { desc = "Open the ScratchPad todo window" })

vim.api.nvim_create_user_command("TodoAdd", function(opts)
  sp().add(opts.args ~= "" and opts.args or nil)
end, { nargs = "*", desc = "Add a new todo (prompts if no text given)" })

vim.api.nvim_create_user_command("TodoToggle", function()
  sp().toggle_task()
end, { desc = "Toggle done state of the task under the cursor" })

vim.api.nvim_create_user_command("TodoDelete", function()
  sp().delete_task()
end, { desc = "Delete the task under the cursor" })

vim.api.nvim_create_user_command("TodoPriority", function(opts)
  sp().set_priority(opts.args)
end, {
  nargs = 1,
  complete = function()
    return { "low", "medium", "high" }
  end,
  desc = "Set priority of the task under the cursor",
})
