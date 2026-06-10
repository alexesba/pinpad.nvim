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
  local function task(text, priority, due, done)
    return entry(text, priority, due, 1, done).task
  end

  it("passes everything under default filter", function()
    local t = task("A", "low", nil)
    eq(true, sort.passes_filter(t, sort.default_filter()))
    eq(true, sort.passes_filter(t, "all"))
    eq(true, sort.passes_filter(t, nil))
  end)

  it("today filter keeps only due today or overdue", function()
    local ref = "2026-06-09"
    local date = require("pinpad.date")
    local orig = date.today
    date.today = function()
      return ref
    end

    local f = sort.default_filter()
    f.today = true
    eq(true, sort.passes_filter(task("overdue", "low", "2026-06-01"), f))
    eq(true, sort.passes_filter(task("today", "low", "2026-06-09"), f))
    eq(false, sort.passes_filter(task("future", "low", "2026-06-15"), f))
    eq(false, sort.passes_filter(task("nodue", "low", nil), f))

    date.today = orig
  end)

  it("filters by case-insensitive text query", function()
    local f = sort.default_filter()
    f.query = "FIX"
    eq(true, sort.passes_filter(task("Fix the bug", "low", nil), f))
    eq(false, sort.passes_filter(task("Add feature", "low", nil), f))
  end)

  it("filters by pending / done state", function()
    local pending_only = sort.default_filter()
    pending_only.done = "pending"
    eq(true, sort.passes_filter(task("A", "low", nil, false), pending_only))
    eq(false, sort.passes_filter(task("B", "low", nil, true), pending_only))

    local done_only = sort.default_filter()
    done_only.done = "done"
    eq(false, sort.passes_filter(task("A", "low", nil, false), done_only))
    eq(true, sort.passes_filter(task("B", "low", nil, true), done_only))
  end)

  it("filters by priority", function()
    local f = sort.default_filter()
    f.priority = "high"
    eq(true, sort.passes_filter(task("A", "high", nil), f))
    eq(false, sort.passes_filter(task("B", "low", nil), f))
  end)
end)

describe("sort.cycle_done / cycle_priority", function()
  it("cycles done filter all → pending → done → all", function()
    eq("pending", sort.cycle_done("all"))
    eq("done", sort.cycle_done("pending"))
    eq("all", sort.cycle_done("done"))
  end)

  it("cycles priority filter all → high → medium → low → all", function()
    eq("high", sort.cycle_priority(nil))
    eq("medium", sort.cycle_priority("high"))
    eq("low", sort.cycle_priority("medium"))
    eq(nil, sort.cycle_priority("low"))
  end)
end)

describe("sort.filter_title_suffix", function()
  it("returns nil when no filters are active", function()
    eq(nil, sort.filter_title_suffix(sort.default_filter()))
  end)

  it("joins active filter parts", function()
    local f = sort.default_filter()
    f.today = true
    f.done = "pending"
    f.query = "fix"
    eq('today, pending, "fix"', sort.filter_title_suffix(f))
  end)
end)
