bit = bit or require "bit"
local exs = require "exs"

local filename = _G.arg[1]
if not filename then
  print("Usage: lua exsdump.lua <filename>")
  os.exit(1)
end

local function print_table(t, n)
  n = n or 0

  for k,v in pairs(t) do
    if k ~= "header" then
      if (type(v) == "table") then
        print(string.rep(" ", n) .. string.format("  %s:", k))
        print_table(v, n + 2)
      else
      print(string.rep(" ", n) .. string.format("  %s = %s", k, tostring(v)))
      end
    end
  end
end

local fh = io.open(filename, "rb")
if fh == nil then error("failed opening file") end
local buf = fh:read("*a")

local exs_file = exs.parse(buf)

for _,chunk in ipairs(exs_file.chunks) do
  print(string.format("%s @ %s", chunk.kind, chunk.offset))

  print_table(chunk)
end