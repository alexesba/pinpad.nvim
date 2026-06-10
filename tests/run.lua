-- Minimal, dependency-free test runner for pinpad.nvim.
--
-- Run from the project root with:
--   nvim -l tests/run.lua
--
-- Defines small global helpers (describe/it/eq/ok) used by *_spec.lua files in
-- tests/, runs them all, prints a summary, and exits non-zero on failure (so it
-- is CI-friendly).

vim.opt.runtimepath:append(vim.fn.getcwd())

local passed, failed = 0, 0
local failures = {}
local current = "(top level)"

---@param name string
---@param fn fun()
function describe(name, fn)
  local prev = current
  current = name
  local ok_, e = pcall(fn)
  current = prev
  if not ok_ then
    failed = failed + 1
    failures[#failures + 1] = string.format("%s (describe block crashed)\n    %s", name, e)
  end
end

---@param name string
---@param fn fun()
function it(name, fn)
  local ok_, e = pcall(fn)
  if ok_ then
    passed = passed + 1
    io.write(".")
  else
    failed = failed + 1
    failures[#failures + 1] = string.format("%s > %s\n    %s", current, name, e)
    io.write("F")
  end
end

---Assert deep equality.
function eq(expected, got, msg)
  if not vim.deep_equal(expected, got) then
    error(
      (msg and (msg .. "\n") or "")
        .. "  expected: "
        .. vim.inspect(expected)
        .. "\n       got: "
        .. vim.inspect(got),
      2
    )
  end
end

---Assert a truthy value.
function ok(cond, msg)
  if not cond then
    error(msg or "expected a truthy value", 2)
  end
end

local specs = vim.fn.glob(vim.fs.joinpath(vim.fn.getcwd(), "tests", "*_spec.lua"), false, true)
table.sort(specs)
for _, file in ipairs(specs) do
  dofile(file)
end

io.write("\n")
for _, f in ipairs(failures) do
  io.write("\nFAIL: " .. f .. "\n")
end
io.write(string.format("\n%d passed, %d failed\n", passed, failed))

if failed > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("quitall!")
end
