# ScratchPad.nvim

A floating **todo-list** inside Neovim, written in Lua. Add, complete, prioritize,
and delete tasks with Vim-style keys — with optional JSON persistence across sessions.

> ⚠️ The name `scratchpad.nvim` is already taken on GitHub
> ([athar-qadri/scratchpad.nvim](https://github.com/athar-qadri/scratchpad.nvim)).
> A final, unique name is still **TBD** before publishing.

---

## Features

- Floating window todo-list with priorities (`low` / `medium` / `high`).
- Auto-sorts by priority as you change it (pending first, then high → low); the
  cursor follows the task as it moves. Disable with `sort = false`.
- Colored priority dots + checkboxes, with a plain-text fallback.
- Vim-native, buffer-local mappings (`x`, `dd`, `o`, `O`, `p`, `>`, `<`).
- Optional JSON persistence at `stdpath("data")/scratchpad.json`.
- Global shortcuts to add a todo or toggle the pad.

## Requirements

- Neovim **0.10+** (uses `vim.fs.joinpath`, `vim.json`, floating-window titles).
- Default icons (`☐ ☑ ●`) are plain Unicode and need no special font. The dot
  color comes from highlight groups. Set `show_icons = false` for an ASCII
  fallback (`[ ]`/`[x]`, `[H]/[M]/[L]`), or swap in Nerd Font glyphs via `icons`.

## Installation

### lazy.nvim
```lua
{
  "you/scratchpad.nvim", -- name TBD
  opts = {},             -- calls require("scratchpad").setup(opts)
}
```

### packer.nvim
```lua
use({
  "you/scratchpad.nvim",
  config = function()
    require("scratchpad").setup()
  end,
})
```

## Configuration

Defaults shown below; pass any subset to `setup()`.

```lua
require("scratchpad").setup({
  persist = true,                 -- save/load JSON across sessions
  path = nil,                     -- nil => stdpath("data").."/scratchpad.json"
  default_priority = "medium",    -- "low" | "medium" | "high"
  show_icons = true,              -- colored dots + checkboxes (needs Nerd Font)
  sort = true,                    -- auto-sort: pending first, then high→medium→low
                                  -- (display-only, stable; insertion order kept on disk)
  open_on_add = false,            -- open the pad after :TodoAdd (false => quick-capture)
  notify_on_add = true,           -- notify "Task added" when capturing from elsewhere

  window = {
    width = 0.5,                  -- ratio (0-1) of editor, or absolute columns (> 1)
    height = 0.6,
    border = "rounded",
    title = " ScratchPad ",
  },

  icons = {
    done = "☑", todo = "☐",
    high = "●", medium = "●", low = "●", -- colored via highlight groups
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
    quit = "q",
  },

  -- global keymaps (set to false to disable)
  keymaps = {
    add = "<leader>ta",           -- :TodoAdd
    toggle = "<leader>tp",        -- :ScratchPad (toggle the pad)
  },
})
```

## Commands

| Command | Description |
|---|---|
| `:ScratchPad` | Toggle the floating window |
| `:TodoList` | Open the window |
| `:TodoAdd [text]` | Add a task (prompts when no text is given). Quick-capture: shows a notification instead of opening the pad (configurable) |
| `:TodoToggle` | Toggle done state of the task under the cursor |
| `:TodoDelete` | Delete the task under the cursor |
| `:TodoPriority {low\|medium\|high}` | Set priority of the task under the cursor |

## In-window mappings

| Key | Action |
|---|---|
| `x` | Toggle done |
| `<CR>` | Edit task text in a floating editor (Esc → normal mode, then `<CR>` saves; `<C-c>`/`q` cancel) |
| `dd` | Delete task |
| `o` / `O` | Add task below / above (prompts for text) |
| `p` | Rotate priority `low → medium → high → low` |
| `>` / `<` | Raise / lower priority |
| `q` / `<Esc>` | Close window |
| `j` / `k` | Move between tasks |

All in-window mappings are buffer-local, and the buffer is non-modifiable, so
your global `p`, `dd`, `<`, `>` behavior is never affected elsewhere.

## Persistence format

```json
[
  { "id": "1", "text": "Revisar PR #42", "done": true, "priority": "high" },
  { "id": "2", "text": "Implementar función X", "done": false, "priority": "medium" }
]
```

A missing or corrupt file starts you with an empty list (with a one-time warning).
