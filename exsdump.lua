bit = bit or require "bit"
local exs = require "exs"

local filename = _G.arg[1]
if not filename then
  print("Usage: lua exsdump.lua <filename>")
  os.exit(1)
end

local fh = io.open(filename, "rb")
if fh == nil then error("failed opening file") end
local buf = fh:read("*a")

local exs_file = exs.parse(buf)

for _,chunk in ipairs(exs_file.chunks) do
  print(string.format("%s @ %s", chunk.kind, chunk.offset))

  for k,v in pairs(chunk) do
    if k ~= "header" then
      print(string.format("  %s = %s", k, v))
    end
  end
end