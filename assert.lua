local assert = {}
setmetatable(assert, assert)

function assert.__call(expr, msg)
  if expr then
    return
  end

  msg = msg or "assertion failed"
  error(msg, 2)
end

function assert.equal(a, b, msg)
  if a == b then
    return
  end

  msg = msg or ("not equal: " .. tostring(a) .. ", " .. tostring(b))
  error(msg, 2)
end

function assert.not_equal(a, b, msg)
  if a ~= b then
    return
  end

  msg = msg or ("equal: " .. tostring(a) .. ", " .. tostring(b))
  error(msg, 2)
end

local function deep_equal(a, b)
  if a == b then return true end

  if type(a) ~= "table" or type(b) ~= "table" then return false end 

  -- Iterate over the longest table to ensure we check all keys
  if #a < #b then
    a, b = b, a
  end

  for k,v in pairs(a) do
    local v2 = b[k]
    if v2 == nil or not deep_equal(v, v2) then return false end
  end

  return true
end

function assert.deep_equal(a, b, msg)
  if deep_equal(a, b) then
    return
  end

  msg = msg or ("not deep equal: " .. tostring(a) .. ", " .. tostring(b))
  error(msg, 2)
end

return assert