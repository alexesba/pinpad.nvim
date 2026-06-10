local M = {}

M.groups = {
  high = "PinPadHigh",
  medium = "PinPadMedium",
  low = "PinPadLow",
  done = "PinPadDone",
  hint = "PinPadHint",
  overdue = "PinPadOverdue",
  due_soon = "PinPadDueSoon",
}

---Define default highlight groups (only sets defaults; user overrides win).
function M.setup()
  local set = function(name, opts)
    vim.api.nvim_set_hl(0, name, vim.tbl_extend("keep", opts, { default = true }))
  end
  set(M.groups.high, { fg = "#f87171", bold = true }) -- red
  set(M.groups.medium, { fg = "#fbbf24" }) -- amber
  set(M.groups.low, { fg = "#4ade80" }) -- green
  set(M.groups.done, { fg = "#6b7280", strikethrough = true }) -- dim + strike
  set(M.groups.hint, { fg = "#6b7280", italic = true })
  set(M.groups.overdue, { fg = "#ef4444", bold = true }) -- red, emphasised
  set(M.groups.due_soon, { fg = "#fb923c" }) -- orange
end

---@param priority "low"|"medium"|"high"
---@return string
function M.priority_group(priority)
  return M.groups[priority] or M.groups.medium
end

return M
