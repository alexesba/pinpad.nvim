if vim.g.loaded_pinpad then
  return
end
vim.g.loaded_pinpad = true

local function sp()
  return require("pinpad")
end

vim.api.nvim_create_user_command("PinPad", function()
  sp().toggle()
end, { desc = "Toggle the PinPad todo window" })

vim.api.nvim_create_user_command("TodoList", function()
  sp().open()
end, { desc = "Open the PinPad todo window" })

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

vim.api.nvim_create_user_command("TodoDue", function(opts)
  sp().set_due(opts.args ~= "" and opts.args or nil)
end, {
  nargs = "*",
  complete = function()
    return { "today", "tomorrow", "+1d", "+3d", "+1w", "clear" }
  end,
  desc = "Set/clear due date of the task under the cursor (in the pad)",
})

vim.api.nvim_create_user_command("TodoToday", function()
  sp().show_today()
end, { desc = "Open the pad filtered to today and overdue tasks" })
