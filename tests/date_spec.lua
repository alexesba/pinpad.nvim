-- Tests for the pure date module. Relative cases are checked against the
-- module's own today()/offset() so they stay deterministic regardless of when
-- the suite runs.

local date = require("pinpad.date")

describe("date.is_valid", function()
  it("accepts real ISO dates", function()
    eq(true, date.is_valid("2026-06-09"))
    eq(true, date.is_valid("2024-02-29")) -- leap day
  end)

  it("rejects malformed or impossible dates", function()
    eq(false, date.is_valid("2026-13-01"))
    eq(false, date.is_valid("2026-02-30"))
    eq(false, date.is_valid("2026-6-9"))
    eq(false, date.is_valid("nope"))
    eq(false, date.is_valid(nil))
  end)
end)

describe("date.offset / diff_days", function()
  it("shifts by days and back", function()
    eq("2026-06-12", date.offset("2026-06-09", 3))
    eq("2026-06-06", date.offset("2026-06-09", -3))
  end)

  it("crosses month and year boundaries", function()
    eq("2026-07-01", date.offset("2026-06-30", 1))
    eq("2027-01-01", date.offset("2026-12-31", 1))
  end)

  it("computes whole-day differences", function()
    eq(3, date.diff_days("2026-06-09", "2026-06-12"))
    eq(-1, date.diff_days("2026-06-09", "2026-06-08"))
    eq(0, date.diff_days("2026-06-09", "2026-06-09"))
    eq(nil, date.diff_days("bad", "2026-06-09"))
  end)
end)

describe("date.parse", function()
  it("parses absolute ISO dates", function()
    eq("2026-06-09", date.parse("2026-06-09"))
  end)

  it("parses today / tomorrow / yesterday", function()
    eq(date.today(), date.parse("today"))
    eq(date.offset(date.today(), 1), date.parse("tomorrow"))
    eq(date.offset(date.today(), -1), date.parse("yesterday"))
  end)

  it("parses relative day and week offsets", function()
    eq(date.offset(date.today(), 3), date.parse("+3d"))
    eq(date.offset(date.today(), -2), date.parse("-2d"))
    eq(date.offset(date.today(), 14), date.parse("+2w"))
  end)

  it("is case-insensitive and trims whitespace", function()
    eq(date.today(), date.parse("  TODAY "))
  end)

  it("returns nil for empty or invalid input", function()
    eq(nil, date.parse(""))
    eq(nil, date.parse("someday"))
    eq(nil, date.parse(nil))
  end)
end)

describe("date.relative_label", function()
  it("labels relative to a reference day", function()
    local ref = "2026-06-09"
    eq("today", date.relative_label("2026-06-09", ref))
    eq("tomorrow", date.relative_label("2026-06-10", ref))
    eq("in 5d", date.relative_label("2026-06-14", ref))
    eq("overdue (2d)", date.relative_label("2026-06-07", ref))
  end)
end)

describe("date.status", function()
  it("classifies overdue / soon / later", function()
    local ref = "2026-06-09"
    eq("overdue", date.status("2026-06-08", ref))
    eq("soon", date.status("2026-06-09", ref)) -- today
    eq("soon", date.status("2026-06-10", ref)) -- tomorrow
    eq("later", date.status("2026-06-15", ref))
    eq(nil, date.status("bad", ref))
  end)
end)

describe("date.sort_key", function()
  it("orders earlier dates before later ones", function()
    ok(date.sort_key("2026-06-01") < date.sort_key("2026-06-09"))
    ok(date.sort_key("2026-06-09") < date.sort_key("2026-06-15"))
  end)

  it("sorts undated tasks last", function()
    ok(date.sort_key("2026-06-15") < date.sort_key(nil))
    ok(date.sort_key(nil) == date.sort_key("bad"))
  end)
end)

describe("date.is_due_today_or_overdue", function()
  it("matches today and past due dates only", function()
    local ref = "2026-06-09"
    eq(true, date.is_due_today_or_overdue("2026-06-09", ref))
    eq(true, date.is_due_today_or_overdue("2026-06-01", ref))
    eq(false, date.is_due_today_or_overdue("2026-06-10", ref))
    eq(false, date.is_due_today_or_overdue("2026-06-15", ref))
  end)
end)
