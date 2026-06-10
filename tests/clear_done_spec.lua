-- Tests for bulk-clearing completed tasks.

local config = require("pinpad.config")
local store = require("pinpad.store")

config.setup({ persist = false })

local function reset()
  store.tasks = {}
  store._undo = {}
end

describe("store.clear_done", function()
  it("removes only completed tasks", function()
    reset()
    store.add("Pending")
    store.add("Done A")
    store.add("Done B")
    store.set_done_ids({ store.tasks[2].id, store.tasks[3].id }, true)
    eq(2, store.clear_done())
    eq(1, #store.tasks)
    eq("Pending", store.tasks[1].text)
    eq(false, store.tasks[1].done)
  end)

  it("returns 0 when nothing is completed", function()
    reset()
    store.add("A")
    store.add("B")
    eq(0, store.clear_done())
    eq(2, #store.tasks)
  end)

  it("is undoable as one bulk delete", function()
    reset()
    store.add("Done")
    store.toggle(1)
    store.clear_done()
    eq(0, #store.tasks)
    eq(1, store.undo())
    eq(1, #store.tasks)
    eq(true, store.tasks[1].done)
  end)
end)
