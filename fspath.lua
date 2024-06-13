local SEP = package.config:sub(1,1)
local SEPB = string.byte(SEP)
local DOT = string.byte(".")

local fspath = {
  sep = SEP,
}

---Split a string on the last occurence of the given character code.
---@param s string
---@param c integer
---@return string, string
local function rsplit(s, c)
  local len = #s
  for i = len,1, -1 do
    if string.byte(s, i) == c then
      return string.sub(s, 1, i-1), string.sub(s, i+1)
    end
  end

  return s, ""
end

function fspath.split(p)
  return rsplit(p, SEPB)
end

function fspath.dirname(p)
  local dirname, _= rsplit(p, SEPB)

  return dirname
end

function fspath.basename(p, suffix)
  local _, basename = rsplit(p, SEPB)

  if suffix and string.sub(basename, -#suffix) == suffix then
    return string.sub(basename, 1, -#suffix -1)
  end

  return basename
end

function fspath.extname(p)
  local _, ext = rsplit(p, DOT)

  return ext
end

function fspath.join(p, ...)
  for _,s in ipairs({...}) do
    if string.byte(p, -1) ~= SEPB then
      p = p .. SEP
    end
    p = p .. s
  end

  return p
end

return fspath