-- Tests for the pinpad store (pure data layer). Persistence is disabled so the
-- suite never touches disk; we reset in-memory state before each case.

local config = require("pinpad.config")
local store = require("pinpad.store")

config.setup({ persist = false, default_priority = "medium" })

local function reset()
  store.tasks = {}
end

---@return string[]
local function texts()
  local out = {}
  for _, t in ipairs(store.tasks) do
    out[#out + 1] = t.text
  end
  return out
end

describe("store.add", function()
  it("appends tasks in order", function()
    reset()
    store.add("A")
    store.add("B")
    eq({ "A", "B" }, texts())
  end)

  it("inserts at an explicit index", function()
    reset()
    store.add("A")
    store.add("C")
    store.add("B", "low", 2)
    eq({ "A", "B", "C" }, texts())
  end)

  it("ignores empty text", function()
    reset()
    eq(nil, store.add("   "))
    eq({}, texts())
  end)

  it("uses default priority when none is valid", function()
    reset()
    local t = store.add("A", "bogus")
    eq("medium", t.priority)
  end)
end)

describe("store.toggle / set_text", function()
  it("toggles done state", function()
    reset()
    store.add("A")
    store.toggle(1)
    eq(true, store.tasks[1].done)
    store.toggle(1)
    eq(false, store.tasks[1].done)
  end)

  it("updates text but ignores empty", function()
    reset()
    store.add("A")
    store.set_text(1, "B")
    eq("B", store.tasks[1].text)
    store.set_text(1, "   ")
    eq("B", store.tasks[1].text)
  end)
end)

describe("store.delete / delete_ids", function()
  it("removes the task at an index", function()
    reset()
    store.add("A")
    store.add("B")
    store.add("C")
    store.delete(2)
    eq({ "A", "C" }, texts())
  end)

  it("removes by id and reports the count", function()
    reset()
    store.add("A")
    store.add("B")
    store.add("C")
    store.add("D")
    local ids = { store.tasks[2].id, store.tasks[4].id }
    eq(2, store.delete_ids(ids))
    eq({ "A", "C" }, texts())
  end)
end)

describe("store.set_done_ids", function()
  it("sets done for matching ids and returns count changed", function()
    reset()
    store.add("A")
    store.add("B")
    store.add("C")
    local changed = store.set_done_ids({ store.tasks[1].id, store.tasks[3].id }, true)
    eq(2, changed)
    eq(true, store.tasks[1].done)
    eq(false, store.tasks[2].done)
    eq(true, store.tasks[3].done)
    -- Re-applying the same state changes nothing.
    eq(0, store.set_done_ids({ store.tasks[1].id }, true))
  end)
end)

describe("store priority shifts", function()
  it("rotate wraps low -> medium -> high -> low", function()
    reset()
    store.add("A", "low")
    store.rotate_priority(1)
    eq("medium", store.tasks[1].priority)
    store.rotate_priority(1)
    eq("high", store.tasks[1].priority)
    store.rotate_priority(1)
    eq("low", store.tasks[1].priority)
  end)

  it("priority_up / priority_down clamp at the ends", function()
    reset()
    store.add("A", "high")
    store.priority_up(1)
    eq("high", store.tasks[1].priority)
    store.set_priority(1, "low")
    store.priority_down(1)
    eq("low", store.tasks[1].priority)
  end)

  it("set_priority ignores invalid values", function()
    reset()
    store.add("A", "low")
    store.set_priority(1, "bogus")
    eq("low", store.tasks[1].priority)
  end)
end)

describe("store.is_valid_priority", function()
  it("accepts only the three levels", function()
    eq(true, store.is_valid_priority("low"))
    eq(true, store.is_valid_priority("medium"))
    eq(true, store.is_valid_priority("high"))
    eq(false, store.is_valid_priority("urgent"))
    eq(false, store.is_valid_priority(nil))
  end)
end)
