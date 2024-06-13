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
  local dirname, _ = rsplit(p, SEPB)

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

-- Join two path segments with a director separator
function fspath.join(p, ...)
  for _,s in ipairs({...}) do
    if string.byte(p, -1) ~= SEPB then
      p = p .. SEP
    end
    p = p .. s
  end

  return p
end

-- Iterate over the segments of a path
function fspath.parts(p)
  local pos = 1
  local len = #p

  -- Skip the leading /
  if string.byte(p, pos) == SEPB then
    pos = pos + 1
  end

  return function ()
    local i = pos + 1
    while string.byte(p, i) ~= SEPB and i < len do
      i = i + 1
    end

    if i > len then return nil end

    local start_index = pos
    local part = string.sub(
      p,
      pos,
      string.byte(p, i) == SEPB and i-1 or i
    )

    pos = i+1

    return part, start_index
  end
end

-- Iterate over the segments of a path in reverse
function fspath.rparts(p)
  local pos = #p

  -- Skip the trailing /
  if string.byte(p, pos) == SEPB then
    pos = pos - 1
  end

  return function ()
    local i = pos - 1
    while string.byte(p, i) ~= SEPB and i > 0 do
      i = i - 1
    end

    if i <= 0 then return nil end

    local start_index = string.byte(p, i) == SEPB and i+1 or i
    local part = string.sub(
      p,
      start_index,
      pos
    )

    pos = i-1

    return part, start_index
  end
end

---Given two absolute paths a and b, rebase b on to a's root path.
---If the path cannot be rebased (because there is no common segment) rebase returns nil.
---The optional parameter n specifies the number of common segments to skip.
---@param root_path string
---@param path string
---@param n integer?
---@return string?
function fspath.rebase(root_path, path, n)
  n = n or 1
  for root_part, i in fspath.parts(root_path) do
    for part, j in fspath.rparts(path) do
      if root_part == part then
        n = n - 1
        if n == 0 then
          return fspath.join(string.sub(root_path, 1, i-1), string.sub(path, j))
        end
      end
    end
  end

  return nil
end

return fspath