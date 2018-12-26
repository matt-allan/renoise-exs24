-- A simple utility for viewing the parsed contents of an EXS24 file.
bit = require "bit"
require "exs24"

local filename = _G.arg[1]
if not filename then
  print("Usage: lua view_exs.lua <filename>")
  os.exit(1)
end

local exs = load_exs(filename)

if not exs then
  print("Invalid EXS")
  os.exit(1)
end


print("---------------------------------")
print("Zones:")
print("---------------------------------")
for _,zone in pairs(exs.zones) do
  for k,v in pairs(zone) do
    print(k .. ": ", v)
  end
  print("---------------------------------")
end

print("Samples:")
print("---------------------------------")
for k,sample in pairs(exs.samples) do
  print("index: " .. k - 1)
  for k,v in pairs(sample) do
    print(k .. ": ", v)
  end
  print("---------------------------------")
end