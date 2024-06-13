---A minimal test framework.
---
---Standalone usage:
---
---```lua
---local t = require "test"
---local assert = require "assert"
---
---t.test("sum", function () 
---  assert.equal(4, 2+2)
---end)
---os.exit(t.run())
---```
---@type table
local t = {
  active_suite = "default",
  tests = {
    default = {},
  },
}

function t.suite(suite_name)
  t.active_suite = suite_name
  t.tests[suite_name] = {}
end

function t.test(name, callback)
  t.tests[t.active_suite][name] = callback
end

function t.only(name, callback)
  t.tests[t.active_suite] = {
    [name] = callback
  }
end

function t.skip(name, callback)
  t.tests[t.active_suite][name] = nil
end

function t.run()
  local failed = false

  if t.active_suite ~= "default" then
    print("running 1 test from " .. t.active_suite)
  end
  for name,cb in pairs(t.tests[t.active_suite]) do
    io.write("test " .. name .. " ... ")

    local cb_type = type(cb)

    local pass, err = true, nil

    if cb_type == "thread" then
      while coroutine.status(cb) ~= "dead" do
        pass, err = coroutine.resume(cb)
      end
      if pass then err = nil end
    elseif cb_type == "function" then
      pass, err = pcall(cb)
    else
      error("invalid test callback type" .. cb_type)
    end

    io.write((pass and "ok" or "FAILED") .. "\n")

    if not pass then
      print(err)
      if cb_type == "thread" then
        print(debug.traceback(cb))
      else
        print(debug.traceback())
      end
    end

    failed = failed or not pass
  end

  print(failed and "FAILED" or "ok")
  return failed and 1 or 0
end

return t