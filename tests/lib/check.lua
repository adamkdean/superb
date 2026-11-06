-- Tiny assertion helper for the mock tests. Each test file ends with check.done(), which exits 1 on failure.
local check = { failures = 0, passes = 0 }
-- io.write, not print: the game mock replaces print to capture chat output.
local function say(s) io.write(s, "\n") end

function check.eq(name, got, want)
  if got == want then
    check.passes = check.passes + 1
  else
    check.failures = check.failures + 1
    say(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
  end
end

function check.ok(name, cond) check.eq(name, cond and true or false, true) end

function check.near(name, got, want, tol)
  check.ok(("%s (got %s, want %s)"):format(name, tostring(got), tostring(want)),
    type(got) == "number" and math.abs(got - want) <= (tol or 1e-6))
end

function check.done()
  say(("%d passed, %d failed"):format(check.passes, check.failures))
  if check.failures > 0 then os.exit(1) end
end

return check
