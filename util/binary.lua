function twos_complement(value, bits)
  -- if sign bit is set (128 - 255 for 8 bit)
  if bit.band(value, bit.lshift(1, (bits - 1))) ~= 0 then
    return value - bit.lshift(1, bits)
  end
  return value
end

-- copied from Files&Bits.lua
function read_word(fh, big_endian)
  local bytes = fh:read(2)
  if (not bytes or #bytes < 2) then
    return nil
  else
    local word = bit.bor(bytes:byte(1),
      bit.lshift(bytes:byte(2), 8))
    if big_endian then
      word = bit.bswap(word)
    end
    return word
  end
end

function read_dword(fh, big_endian)
  local bytes = fh:read(4)
  if (not bytes or #bytes < 4) then
    return nil
  else
    local dword = bit.bor(bytes:byte(1),
      bit.lshift(bytes:byte(2), 8),
      bit.lshift(bytes:byte(3), 16),
      bit.lshift(bytes:byte(4), 24))
    if big_endian then
      dword = bit.bswap(dword)
    end
    return dword
  end
end

