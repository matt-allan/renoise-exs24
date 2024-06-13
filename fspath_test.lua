local t = require "test"
local assert = require "assert"
local fspath = require "fspath"

t.test("rebase", function ()
  -- path to the .exs file
  local exs_path = "/Users/Matt/Samples/909 From Mars/Logic EXS/909 From Mars/02. Kits/Clean Kit.exs"
  -- filepath from the exs sample
  local filepath = "/Users/BEN/Desktop/In Progress/909 From Mars/WAV/Kits/01. Clean Kit"
  -- the re-rooted path
  local want = "/Users/Matt/Samples/909 From Mars/WAV/Kits/01. Clean Kit"

  local rebased_path = fspath.rebase(exs_path, filepath, 2)

  assert.equal(want, rebased_path)
end)

os.exit(t.run())