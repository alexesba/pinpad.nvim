# pinpad.nvim — Specification

A floating todo-list inside Neovim, written in Lua, with Vim-style navigation,
priority levels, and JSON persistence across sessions.

> Status: design spec (pre-implementation). Decisions below are locked unless noted.

---

## 1. Goals & non-goals

### Goals
- A single floating window that lists tasks and lets you manage them with Vim keys.
- Each task has: text, done state, priority (`low | medium | high`), optional due date.
- Optional persistence to JSON across sessions.
- Idiomatic `setup()` config; works with `lazy.nvim` / `packer` / native packages.
- Sensible defaults; zero config required to be useful.

### Non-goals (v1)
- No sync across machines, no remote backends.
- No tags, sub-tasks, or recurring tasks (candidates for later).
- No Telescope/fzf integration (later).

---

## 2. Locked design decisions

| Decision | Choice |
|---|---|
| Persistence path | `vim.fn.stdpath("data") .. "/pinpad.json"` (i.e. `~/.local/share/nvim/`) |
| Priority keys | Keep **both**: `p` rotates `low→medium→high→low`, and `>` / `<` raise/lower |
| Buffer mode | **Managed / non-editable**: user acts on lines via mappings, not free text edit |
| Default priority | `medium` |
| Icons | On by default; plain-text fallback when disabled or no Nerd Font |

---

## 3. Configuration API

```lua
require("pinpad").setup({
  persist = true,                 -- save/load JSON across sessions
  path = nil,                     -- nil => stdpath("data").."/pinpad.json"
  default_priority = "medium",    -- "low" | "medium" | "high"
  show_icons = true,              -- colored priority dots + checkboxes

  window = {
    width = 0.5,                  -- ratio (0-1) of editor width, or absolute int > 1
    height = 0.6,                 -- ratio (0-1) of editor height, or absolute int > 1
    border = "rounded",          -- any nvim border style
    title = " PinPad ",
  },

  icons = {
    done = "☑",                  -- shown for completed
    todo = "☐",                  -- shown for pending
    high = "●",                  -- colored red via PinPadHigh
    medium = "●",                -- colored amber via PinPadMedium
    low = "●",                   -- colored green via PinPadLow
  },

  -- buffer-local mappings (set to false to disable a binding)
  mappings = {
    toggle   = "x",
    edit     = "<CR>",
    help     = "g?",
    delete   = "dd",
    add_below = "o",
    add_above = "O",
    rotate_priority = "p",
    priority_up = ">",
    priority_down = "<",
    quit = "q",
  },
})
```

When `show_icons = false`, the renderer falls back to text markers:
`[x]`/`[ ]` for done state and `[H]`/`[M]`/`[L]` for priority.

---

## 4. Commands

| Command | Behavior |
|---|---|
| `:PinPad` | Toggle the floating window open/closed |
| `:TodoAdd <text>` | Add a task; if no text, prompt via `vim.ui.input`. Priority comes from `add_priority` (default `low`; `"ask"` prompts via `vim.ui.select`). Quick-capture: if the pad is closed, shows a "Task added" notification rather than opening it (`open_on_add`/`notify_on_add`) |
| `:TodoToggle` | Toggle done state of task under cursor |
| `:TodoDelete` | Delete task under cursor |
| `:TodoList` | Open the window (alias of opening `:PinPad`) |
| `:TodoPriority <low\|medium\|high>` | Set priority of task under cursor |
| `:TodoDue [date]` | Set/clear due date of task under cursor. Accepts ISO `YYYY-MM-DD`, `today`/`tomorrow`/`yesterday`, `+Nd`/`+Nw` (and `-`), or `clear`/blank; prompts via `vim.ui.input` when no arg |
| `:TodoToday` | Open the pad filtered to tasks due today or overdue |

All cursor-based commands operate on the task mapped to the current buffer line.

---

## 5. In-buffer mappings (buffer-local)

| Key | Action |
|---|---|
| `<CR>` | Edit task text in a floating editor (insert mode; `<CR>` saves & closes, `<Esc>`/`<C-c>` cancels & closes) |
| `x` | Toggle done |
| `dd` | Delete task |
| `u` | Undo the most recent delete (single or bulk); restores task(s) to their recorded positions. Bounded stack (25 deep), in-memory only |
| `V` + `d` | Visual line mode: delete all selected tasks in bulk (resolves selected display lines → task ids, removes them, notifies count) |
| `V` + `x` | Visual line mode: toggle done on all selected (smart — completes all, or un-completes if every selected is already done) |
| `o` | Add new task below (prompt for text, default priority) |
| `O` | Add new task above |
| `p` | Rotate priority `low→medium→high→low` |
| `>` | Raise priority |
| `<` | Lower priority |
| `D` | Set/clear due date (prompts via `vim.ui.input`; parses ISO + relative input via `date.parse`; blank/`clear` removes it) |
| `T` | Toggle today/overdue filter (shows only tasks with `due` today or in the past; title appends `(today)`) |
| `q` / `<Esc>` | Close window |
| `g?` / `<C-w>` | Cheat-sheet of buffer-local keys (which-key `show({ global = false })`, else notification fallback) |
| `j` / `k` | Move between tasks (native) |

The edit modal binds the same help keys. which-key integration is optional and
dependency-free: `require("which-key").show({ global = false })` is called under
`pcall`, so it degrades gracefully to a `vim.notify` cheat-sheet. `<C-w>` is
remapped buffer-locally so it shows these bindings rather than which-key's
window menu (the buffer-local map shadows the global window trigger).

All mappings are `<buffer>` local and the buffer is `nomodifiable` + `buftype=nofile`,
so global `p`, `<`, `>`, `dd` semantics are never disturbed outside the window.

---

## 6. Data model & persistence

### Task
```lua
{
  id = "uuid-or-counter",   -- stable id, survives reordering
  text = "Implementar función X",
  done = false,
  priority = "medium",      -- "low" | "medium" | "high"
  due = "2026-06-12",       -- optional ISO date; nil/absent when unset
}
```

### On-disk JSON
```json
[
  { "id": "1", "text": "Revisar PR #42", "done": true,  "priority": "high" },
  { "id": "2", "text": "Implementar función X", "done": false, "priority": "medium", "due": "2026-06-12" },
  { "id": "3", "text": "Escribir documentación", "done": false, "priority": "low" }
]
```

- `due` is validated on load (`date.is_valid`); malformed values are dropped.

- Encode/decode via `vim.json.encode` / `vim.json.decode`.
- Save on every mutation when `persist = true` (debounced is a later optimization).
- Load on first window open / on `setup()`.
- Corrupt/missing file => start with an empty list (warn once, don't crash).

---

## 7. Rendering

Each task line:
```
<checkbox> <priority-dot> <text>
```
Example (icons on):
```
☐ 🔴 Revisar PR #42
☑ 🟡 Implementar función X
☐ 🟢 Escribir documentación
```

- Highlight groups: `PinPadHigh`, `PinPadMedium`, `PinPadLow`,
  `PinPadDone` (dimmed/strikethrough for completed text), `PinPadOverdue`
  (red/bold) and `PinPadDueSoon` (orange) for due-date hints.
- Pending tasks with a `due` date get a relative suffix, e.g. `(today)`,
  `(in 3d)`, `(overdue (2d))`, colored by `date.status` (overdue/soon/later →
  overdue/due-soon/hint). Completed tasks keep the strikethrough over the suffix.
- A line→task index map is rebuilt on every render so mappings/commands can
  resolve the task under the cursor.
- Auto-sort (`sort = true`, default on): pending tasks first, then by priority
  `high → medium → low`; within equal priority, by due date ascending (earliest
  first, undated last) when `sort_by_due = true`. Done items sink to the bottom.
  Stable tiebreak on insertion order. Display-only — on-disk order is the raw
  insertion order. The cursor follows a task when its priority/done changes.
- Filter (`filter = "today"`): display-only subset — tasks whose `due` is today
  or overdue. Toggled with `T`; reset to `all` when the window closes.

---

## 8. Module structure

```
pinpad.nvim/
├── lua/pinpad/
│   ├── init.lua        -- setup(), public API, command/keymap wiring
│   ├── config.lua      -- defaults + deep-merge user opts
│   ├── store.lua       -- task model, ids, JSON load/save, undo
│   ├── date.lua        -- pure ISO-date helpers (parse/offset/diff/labels)
│   ├── sort.lua        -- display sort compare + filter helpers
│   ├── ui.lua          -- float window lifecycle + render + line map
│   ├── actions.lua     -- add/toggle/delete/priority/due mutations
│   └── highlights.lua  -- highlight groups + icon resolution
├── plugin/pinpad.lua  -- declares :PinPad, :TodoAdd, ... (lazy-safe)
├── README.md
└── SPEC.md (this file)
```

Responsibility split:
- `store` owns state and disk I/O; never touches UI.
- `ui` owns the window/buffer and rendering; reads from `store`.
- `actions` mutate `store` then ask `ui` to re-render and `store` to save.
- `init` wires public functions, user config, commands, and global keymaps.

---

## 9. Edge cases

- Empty list => show a placeholder hint line ("No tasks — press o to add").
- Cursor on placeholder/blank line => mutation commands no-op gracefully.
- `:TodoPriority` with invalid arg => error message, no change.
- `:TodoDue` / `D` with an unparseable date => error message, no change; blank/`clear` removes the date.
- Window already open => `:PinPad` closes it (toggle).
- Multiple instances/tabs => single shared buffer reused.
- Concurrent external edits to JSON => last-write-wins (documented limitation).

---

## 10. Implementation milestones

1. **Scaffold** — repo layout, `config.lua` defaults + merge, `init.setup()`.
2. **Store** — in-memory tasks, id generation, JSON load/save.
3. **UI** — float window open/close, render with line→task map.
4. **Actions + mappings** — toggle/delete/add/priority wired to buffer keys.
5. **Commands** — `:PinPad`, `:TodoAdd`, `:TodoToggle`, `:TodoDelete`, `:TodoList`, `:TodoPriority`, `:TodoDue`.
6. **Highlights + icons** — colored dots, done styling, text fallback.
7. **Polish** — README, edge cases, optional sort flag.

---

## 11. Open questions (for later)

- Should `:TodoAdd` append at top or bottom? (proposed: bottom)
- Per-project vs global list toggle?
- Sort-on-render default on or off?
