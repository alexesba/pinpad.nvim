-- Tests for the undo stack (delete + restore). Persistence is disabled so the
-- suite never touches disk; we reset in-memory state before each case.

local config = require("pinpad.config")
local store = require("pinpad.store")

config.setup({ persist = false, default_priority = "medium" })

local function reset()
  store.tasks = {}
  store._undo = {}
end

---@return string[]
local function texts()
  local out = {}
  for _, t in ipairs(store.tasks) do
    out[#out + 1] = t.text
  end
  return out
end

describe("undo: single delete", function()
  it("restores a deleted task to its original position", function()
    reset()
    store.add("A")
    store.add("B")
    store.add("C")
    store.delete(2)
    eq({ "A", "C" }, texts())
    eq(1, store.undo())
    eq({ "A", "B", "C" }, texts())
  end)

  it("returns 0 when there is nothing to undo", function()
    reset()
    eq(0, store.undo())
  end)

  it("caps the undo history depth", function()
    reset()
    for i = 1, 40 do
      store.add("t" .. i)
    end
    for _ = 1, 40 do
      store.delete(1)
    end
    local restored = 0
    while store.undo() > 0 do
      restored = restored + 1
    end
    eq(25, restored)
  end)
end)

describe("undo: bulk delete", function()
  it("restores all removed tasks to their original order", function()
    reset()
    store.add("A")
    store.add("B")
    store.add("C")
    store.add("D")
    store.add("E")
    store.delete_ids({ store.tasks[2].id, store.tasks[4].id })
    eq({ "A", "C", "E" }, texts())
    eq(2, store.undo())
    eq({ "A", "B", "C", "D", "E" }, texts())
  end)

  it("undoes deletes one transaction at a time", function()
    reset()
    store.add("A")
    store.add("B")
    store.add("C")
    store.delete(1) -- remove A
    store.delete(1) -- remove B (now first)
    eq({ "C" }, texts())
    eq(1, store.undo()) -- restores B
    eq({ "B", "C" }, texts())
    eq(1, store.undo()) -- restores A
    eq({ "A", "B", "C" }, texts())
  end)
end)
