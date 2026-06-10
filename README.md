# pinpad.nvim

A floating **todo-list** inside Neovim, written in Lua. Add, complete, prioritize,
and delete tasks with Vim-style keys — with optional JSON persistence across sessions.

---

## Features

- Floating window todo-list with priorities (`low` / `medium` / `high`).
- Auto-sorts by priority as you change it (pending first, then high → low); the
  cursor follows the task as it moves. Disable with `sort = false`.
- Bulk actions: select tasks in visual line mode (`V`), then `d` to delete or
  `x` to toggle done on all of them.
- Undo deletes with `u` — single or bulk, restored to their original positions.
- Clear completed tasks with `Z` or `:TodoClearDone` (undoable with `u`).
- Optional due dates with `D` — shown as a relative hint (`today`, `in 3d`,
  `overdue (2d)`) and colored by urgency. Accepts ISO dates or shorthands like
  `today` / `tomorrow` / `+3d` / `+2w`.
- Auto-sorts by due date within the same priority (earliest first; undated last).
- **Today view** — `T` toggles a filter for overdue + due-today tasks;
  `:TodoToday` opens the pad in that view.
- Colored priority dots + checkboxes, with a plain-text fallback.
- Vim-native, buffer-local mappings (`x`, `dd`, `o`, `O`, `p`, `>`, `<`).
- Optional JSON persistence at `stdpath("data")/pinpad.json`.
- Global shortcuts to add a todo or toggle the pad.

## Requirements

- Neovim **0.10+** (uses `vim.fs.joinpath`, `vim.json`, floating-window titles).
- Default icons (`☐ ☑ ●`) are plain Unicode and need no special font. The dot
  color comes from highlight groups. Set `show_icons = false` for an ASCII
  fallback (`[ ]`/`[x]`, `[H]/[M]/[L]`), or swap in Nerd Font glyphs via `icons`.

## Dependencies

**None.** pinpad.nvim has no required dependencies — it relies only on built-in
Neovim APIs, so it works the same with any plugin manager (lazy.nvim, packer,
vim-plug, mini.deps, paq, or a manual `runtimepath` setup).

[which-key.nvim](https://github.com/folke/which-key.nvim) is an **optional**
enhancement: when installed, the `g?` / `<C-w>` cheat-sheet is rendered as a
which-key popup (scoped to the current buffer's keys). Without it, the same keys
are shown via a plain `vim.notify` list — nothing breaks either way. To opt in,
just install which-key normally; no extra pinpad configuration is needed.

## Installation

### lazy.nvim
```lua
{
  "you/pinpad.nvim",
  opts = {},             -- calls require("pinpad").setup(opts)
}
```

### packer.nvim
```lua
use({
  "you/pinpad.nvim",
  config = function()
    require("pinpad").setup()
  end,
})
```

## Configuration

Defaults shown below; pass any subset to `setup()`.

```lua
require("pinpad").setup({
  persist = true,                 -- save/load JSON across sessions
  path = nil,                     -- nil => stdpath("data").."/pinpad.json"
  default_priority = "medium",    -- "low" | "medium" | "high"
  add_priority = "low",           -- priority for :TodoAdd / <leader>ta quick-capture:
                                  -- "low" | "medium" | "high" | "ask" (prompt) | nil
  show_icons = true,              -- colored dots + checkboxes (needs Nerd Font)
  sort = true,                    -- auto-sort: pending first, then high→medium→low
                                  -- (display-only, stable; insertion order kept on disk)
  sort_by_due = true,             -- within equal priority, sort by due date (earliest first)
  open_on_add = false,            -- open the pad after :TodoAdd (false => quick-capture)
  notify_on_add = true,           -- notify "Task added" when capturing from elsewhere

  window = {
    width = 0.5,                  -- ratio (0-1) of editor, or absolute columns (> 1)
    height = 0.6,
    border = "rounded",
    title = " PinPad ",
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
    set_due = "D",                -- set/clear a due date (prompts; ISO or +Nd/today/...)
    filter_today = "T",           -- toggle today/overdue filter view
    clear_done = "Z",             -- remove all completed tasks (undoable with u)
    undo = "u",                   -- restore the most recently deleted task(s)
    quit = "q",
    help = "g?",                  -- show a cheat-sheet (which-key or notification)
  },

  -- global keymaps (set to false to disable)
  keymaps = {
    add = "<leader>ta",           -- :TodoAdd
    toggle = "<leader>tp",        -- :PinPad (toggle the pad)
  },
})
```

## Commands

| Command | Description |
|---|---|
| `:PinPad` | Toggle the floating window |
| `:TodoList` | Open the window |
| `:TodoAdd [text]` | Add a task (prompts when no text is given). Quick-capture: uses `add_priority` (default `low`, or `"ask"` to choose) and notifies instead of opening the pad (configurable) |
| `:TodoToggle` | Toggle done state of the task under the cursor |
| `:TodoDelete` | Delete the task under the cursor |
| `:TodoPriority {low\|medium\|high}` | Set priority of the task under the cursor |
| `:TodoDue [date]` | Set/clear the due date of the task under the cursor (in the pad). Accepts an ISO date, `today`/`tomorrow`, `+Nd`/`+Nw`, or `clear`; prompts when omitted |
| `:TodoToday` | Open the pad filtered to tasks due today or overdue |
| `:TodoClearDone` | Remove all completed tasks (undoable with `u` in the pad) |

## In-window mappings

| Key | Action |
|---|---|
| `x` | Toggle done |
| `<CR>` | Edit task text in a floating editor (`<CR>` saves & closes, `<Esc>` cancels) |
| `dd` | Delete task |
| `u` | Undo the most recent delete (restores task(s) to their original spot) |
| `Z` | Clear all completed tasks (undoable with `u`) |
| `V` then `d` | Select multiple tasks (visual line mode) and delete them in bulk |
| `V` then `x` | Toggle done on all selected tasks (completes all, or un-completes if all already done) |
| `o` / `O` | Add task below / above (prompts for text) |
| `p` | Rotate priority `low → medium → high → low` |
| `>` / `<` | Raise / lower priority |
| `D` | Set/clear due date (prompts; accepts ISO date, `today`, `+3d`, `+2w`, or blank to clear) |
| `T` | Toggle today/overdue filter (title shows `(today)` while active) |
| `q` / `<Esc>` | Close window |
| `g?` / `<C-w>` | Show a cheat-sheet of this buffer's keys (which-key when installed) |
| `j` / `k` | Move between tasks |

Both `g?` and `<C-w>` show only the current buffer's bindings (the pad's or the
modal's). If [which-key.nvim](https://github.com/folke/which-key.nvim) is
installed it renders the popup (buffer-local keys only); otherwise it falls back
to a notification. `<C-w>` is repurposed here so it shows these bindings instead
of which-key's window menu.

All in-window mappings are buffer-local, and the buffer is non-modifiable, so
your global `p`, `dd`, `<`, `>` behavior is never affected elsewhere.

## Development

Tests use a tiny, dependency-free harness that runs under headless Neovim
(no plenary/busted needed). From the project root:

```bash
make test        # or: nvim -l tests/run.lua
```

Specs live in `tests/*_spec.lua` and use the globals `describe` / `it` / `eq` /
`ok` defined by `tests/run.lua`. The runner exits non-zero on any failure, so
it drops straight into CI.

## Persistence format

```json
[
  { "id": "1", "text": "Revisar PR #42", "done": true, "priority": "high" },
  { "id": "2", "text": "Implementar función X", "done": false, "priority": "medium" }
]
```

A missing or corrupt file starts you with an empty list (with a one-time warning).
