-- Tests for due-date support in the store: set/clear, validation, and
-- persistence round-trip (load drops invalid dates).

local config = require("pinpad.config")
local store = require("pinpad.store")

local function write_file(path, contents)
  local fd = assert(io.open(path, "w"))
  fd:write(contents)
  fd:close()
end

describe("store.set_due", function()
  it("sets and clears a due date", function()
    config.setup({ persist = false })
    store.tasks = {}
    store.add("A")
    store.set_due(1, "2026-06-12")
    eq("2026-06-12", store.tasks[1].due)
    store.set_due(1, nil)
    eq(nil, store.tasks[1].due)
  end)

  it("clears when given an empty string", function()
    config.setup({ persist = false })
    store.tasks = {}
    store.add("A")
    store.set_due(1, "2026-06-12")
    store.set_due(1, "")
    eq(nil, store.tasks[1].due)
  end)

  it("ignores invalid dates", function()
    config.setup({ persist = false })
    store.tasks = {}
    store.add("A")
    store.set_due(1, "2026-13-40")
    eq(nil, store.tasks[1].due)
  end)
end)

describe("store due persistence", function()
  it("round-trips a due date through save/load", function()
    local path = vim.fn.tempname()
    config.setup({ persist = true, path = path })
    store.tasks = {}
    store.add("A")
    store.set_due(1, "2026-06-12") -- set_due saves
    store.tasks = {}
    store.load()
    eq("2026-06-12", store.tasks[1].due)
    os.remove(path)
  end)

  it("drops an invalid due date on load", function()
    local path = vim.fn.tempname()
    write_file(path, '[{"id":"1","text":"A","done":false,"priority":"low","due":"2026-99-99"}]')
    config.setup({ persist = true, path = path })
    store.tasks = {}
    store.load()
    eq(1, #store.tasks)
    eq(nil, store.tasks[1].due)
    os.remove(path)
  end)
end)
