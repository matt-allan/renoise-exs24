-- trim zero bytes from the end of a string
function rtrim(str)
  return str:sub(1, str:find("\000") - 1)
end