local bytes = {}

---@class Buffer
---@field private buf string
---@field private pos integer
---@field public size integer
local Buffer = {}
Buffer.__index = Buffer
bytes.Buffer = Buffer

---Create a new Buffer from a byte string.
---@param buf string
---@return Buffer
function Buffer.new(buf)
  local b = {
    buf = buf or "",
    pos = 1,
    size = #buf,
    e = bytes.le,
  }
  setmetatable(b, Buffer)
  return b
end

---
---Sets and gets the buffer position, measured from the beginning of the buffer.
---
---@param whence? seekwhence
---@param offset? integer
---@return integer offset
function Buffer:seek(whence, offset)
  whence = whence or "cur"
  offset = offset or 0

  if whence == "cur" then
    self.pos = self.pos + offset
  elseif whence == "set" then
    self.pos = offset + 1
  elseif whence == "end" then
    self.pos = self.size
  else
    error("bad argument #1 to 'seek' (invalid option 'foo'")
  end

  assert(self.pos >= 1)

  return self.pos - 1
end

---Read a single byte from the buffer.
---@return integer
function Buffer:read_byte()
  if self.pos > self.size then error("end of buffer") end

  local b = string.byte(self.buf, self.pos)

  self.pos = self.pos + 1

  return b
end

---Get a byte from the buffer without advancing the cursor.
---@param whence? seekwhence
---@param offset? integer
---@return integer?
function Buffer:peek(whence, offset)
  whence = whence or "cur"
  offset = offset or 0
  local pos = 1

  if whence == "cur" then
    pos = self.pos + offset
  elseif whence == "set" then
    pos = offset + 1
  elseif whence == "end" then
    pos = self.size
  else
    error("bad argument #1 to 'seek' (invalid option 'foo'")
  end

  assert(pos >= 1)

  return string.byte(self.buf, pos)
end

---Read up to n bytes from the buffer.
---@param n integer
---@return string
function Buffer:read(n)
  if self.pos > self.size then error("end of buffer") end

  local b = string.sub(self.buf, self.pos, self.pos + (n-1))
  self.pos = self.pos + #b
  return b
end

---Skip forward N bytes
---@param n integer?
---@return integer
function Buffer:skip(n)
  self.pos = self.pos + (n or 1)

  return self.pos
end

---Get the underlying bytes backing the buffer.
---@return string
function Buffer:bytes()
  return self.buf
end

---@return Buffer
function Buffer:slice(i, j)
  i = i or 0
  j = j or self.size

  return Buffer.new(self.buf:sub(i, j))
end

---Get the number of bytes remaining to be read, based on the current position.
---@return integer
function Buffer:remaining()
  return self.size - (self.pos - 1)
end

---Set the default endianness.
function Buffer:endian(byte_order)
  if byte_order == "<" then
      self.e = bytes.le
  elseif byte_order == ">" then
      self.e = bytes.be
  else
    error(string.format("unknown byte order '%s'", byte_order))
  end
end

---@return integer
function Buffer:u8()
  return self:read_byte()
end

---@return integer
function Buffer:i8()
  return bytes.tosigned(self:read_byte(), 8)
end

---@return integer
function Buffer:u16()
  return self.e.u16(self:read(2))
end

---@return integer
function Buffer:i16()
  return self.e.i16(self:read(2))
end

---@return integer
function Buffer:u32()
  return self.e.u32(self:read(4))
end

---@return integer
function Buffer:i32()
  return self.e.i32(self:read(4))
end

---@return integer
function Buffer:u64()
  return self.e.u64(self:read(2))
end

---@return integer
function Buffer:i64()
  return self.e.i64(self:read(2))
end

---@param n integer
---@return string
function Buffer:cstr(n)
  local str = self:read(n)

  local i = str:find("\00", 1, true)

  if i then return str:sub(1, i - 1) else return str end
end

---Converts an integer to signed using twos complement.
---@param x integer the unsigned integer
---@param n integer the number of bits
---@return integer
function bytes.tosigned(x, n)
  n = n or 8
  -- if sign bit is set (128 - 255 for 8 bit)
  if bit.band(x, bit.lshift(1, (n - 1))) ~= 0 then
    return x - bit.lshift(1, n)
  end

  return x
end

---@param x integer
---@return integer
function bytes.low_byte(x)
  return bit.band(x, 0xF)
end

---@param x integer
---@return integer
function bytes.high_byte(x)
  return bit.rshift(x, 8)
end

---Little endian binary encoding.
---@type table
local le = {}
bytes.le = le

---@param buf string
---@return integer
function le.u16(buf)
  local b1, b2 = string.byte(buf, 1, 2)

  return bit.bor(
    b1,
    bit.lshift(b2, 8)
  )
end

---@param buf string
---@return integer
function le.i16(buf)
  return bytes.tosigned(le.u16(buf), 16)
end

---@param buf string
---@return integer
function le.u32(buf)
  local b1, b2, b3, b4 = string.byte(buf, 1, 4)

  return bit.bor(
    b1,
    bit.lshift(b2, 8),
    bit.lshift(b3, 16),
    bit.lshift(b4, 24)
  )
end

---@param buf string
---@return integer
function le.i32(buf)
  return bytes.tosigned(le.u32(buf), 32)
end

---@param buf string
---@return integer
function le.u64(buf)
  local b1, b2, b3, b4, b5, b6, b7, b8 = string.byte(buf, 1, 8)

  return bit.bor(
    b1,
    bit.lshift(b2, 8),
    bit.lshift(b3, 16),
    bit.lshift(b4, 24),
    bit.lshift(b5, 32),
    bit.lshift(b6, 40),
    bit.lshift(b7, 48),
    bit.lshift(b8, 56)
  )
end

---@param buf string
---@return integer
function le.i64(buf)
  return bytes.tosigned(le.u32(buf), 64)
end

---Big endian binary encoding.
---@type table
local be = {}
bytes.be = be

---@param buf string
---@return integer
function be.u16(buf)
  return bit.bswap(le.u16(buf))
end

---@param buf string
---@return integer
function be.i16(buf)
  return bytes.tosigned(le.i16(buf), 16)
end

---@param buf string
---@return integer
function be.u32(buf)
  return bit.bswap(le.u32(buf))
end

---@param buf string
---@return integer
function be.i32(buf)
  return bytes.tosigned(le.i32(buf), 32)
end

---@param buf string
---@return integer
function be.u64(buf)
  return bit.bswap(le.u64(buf))
end

---@param buf string
---@return integer
function be.i64(buf)
  return bytes.tosigned(le.i64(buf), 64)
end


return bytes