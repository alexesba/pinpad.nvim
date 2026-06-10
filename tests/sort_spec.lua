-- Tests for display sort/filter helpers.

local sort = require("pinpad.sort")

local function entry(text, priority, due, idx, done)
  return {
    task = { id = tostring(idx), text = text, done = done or false, priority = priority, due = due },
    idx = idx,
  }
end

describe("sort.compare", function()
  it("ranks pending above done", function()
    local pending = entry("A", "low", nil, 1)
    local done = entry("B", "high", nil, 2, true)
    ok(sort.compare(pending, done, false))
    ok(not sort.compare(done, pending, false))
  end)

  it("ranks higher priority first among pending", function()
    local high = entry("H", "high", nil, 1)
    local low = entry("L", "low", nil, 2)
    ok(sort.compare(high, low, false))
  end)

  it("sorts by due date ascending when sort_by_due is on", function()
    local soon = entry("soon", "medium", "2026-06-10", 1)
    local overdue = entry("late", "medium", "2026-06-01", 2)
    ok(sort.compare(overdue, soon, true))
  end)

  it("puts undated tasks after dated ones at equal priority", function()
    local dated = entry("dated", "medium", "2026-06-15", 1)
    local undated = entry("none", "medium", nil, 2)
    ok(sort.compare(dated, undated, true))
  end)

  it("falls back to insertion index as final tiebreak", function()
    local first = entry("A", "medium", "2026-06-09", 1)
    local second = entry("B", "medium", "2026-06-09", 2)
    ok(sort.compare(first, second, true))
  end)
end)

describe("sort.passes_filter", function()
  it("passes everything under all", function()
    local t = entry("A", "low", nil, 1).task
    eq(true, sort.passes_filter(t, "all"))
    eq(true, sort.passes_filter(t, nil))
  end)

  it("today filter keeps only due today or overdue", function()
    local ref = "2026-06-09"
    -- Monkey-patch today for deterministic filter tests via date module.
    local date = require("pinpad.date")
    local orig = date.today
    date.today = function()
      return ref
    end

    eq(true, sort.passes_filter(entry("overdue", "low", "2026-06-01", 1).task, "today"))
    eq(true, sort.passes_filter(entry("today", "low", "2026-06-09", 2).task, "today"))
    eq(false, sort.passes_filter(entry("future", "low", "2026-06-15", 3).task, "today"))
    eq(false, sort.passes_filter(entry("nodue", "low", nil, 4).task, "today"))

    date.today = orig
  end)
end)
