local bytes = require "bytes"

local HEADER_SIZE = 84

---Exs24 file format definitions and codec.
---This module does not depend on renoise APIs.
local exs = {}

exs.PLAY_MODE_FORWARD = 0
exs.PLAY_MODE_REVERSE = 1
exs.PLAY_MODE_ALTERNATE = 2

---@alias PlayMode
---| 0 # forward
---| 1 # reverse
---| 2 # alternate

---@alias bytes string
---@alias byte integer

---@class Header
---@field kind "header"
---@field offset integer
---@field signature bytes
---@field marker byte
---@field size integer
---@field index integer
---@field chunk_id string
---@field name string
exs.Header = {}

---@class Instrument 
---@field kind "instrument"
---@field offset integer
---@field header Header
---@field num_zones integer
---@field num_groups integer
---@field num_samples integer
exs.Instrument = {}

---@class ZoneFlags
---@field oneshot boolean
---@field pitch boolean
---@field reverse boolean
---@field has_velocity_range boolean
---@field has_output boolean

---@class LoopFlags
---@field loop_on boolean
---@field equal_power boolean
---@field end_release boolean

---@class Zone
---@field kind "zone"
---@field offset integer
---@field header Header
---@field zone_flags ZoneFlags
---@field key integer
---@field fine_tuning integer [-99, 99]
---@field pan integer [-100, 100]
---@field volume integer volume in decibels, [-12, - 12]
---@field key_low integer
---@field key_high integer
---@field velocity_low integer
---@field velocity_high integer
---@field sample_start integer
---@field sample_end integer
---@field loop_start integer
---@field loop_end integer
---@field loop_crossfade integer
---@field loop_flags LoopFlags
---@field play_mode PlayMode
---@field output byte
---@field group_index integer
---@field sample_index integer
---@field sample_fade integer?
---@field zone_offset integer?
exs.Zone = {}

---@class Sample
---@field kind "sample"
---@field offset integer
---@field header Header
---@field sample_length integer
---@field sample_rate integer
---@field bit_depth integer
---@field sample_type integer
---@field file_path string
---@field file_name string?
exs.Sample = {}

---@alias Chunk
---| Header
---| Instrument
---| Zone
---| Sample

---@class ExsFile 
---@field chunks Chunk[]
---@field headers Header[]
---@field instruments Instrument[]
---@field zones Zone[]
---@field samples Sample[]
exs.ExsFile = {}

---@param data string
---@return ExsFile
function exs.parse(data)
  local buf = bytes.Buffer.new(data)

  -- The chunk ID starts at 16 and is normally "TBOS" or "JBOS", so for a big
  -- endian file it's swapped and the first letter is always "S".
  if buf:peek("set",16) == "S" then buf:endian(">") else buf:endian("<") end

  ---@type ExsFile
  local exs_file = {
    chunks = {},
    headers = {},
    instruments = {},
    zones = {},
    samples = {},
  }

  while buf:seek() + HEADER_SIZE < buf.size do
    local header = exs.parse_header(buf)

    local chunk_id = header.chunk_id
    if chunk_id ~= "TBOS" and chunk_id ~= "JBOS"
      and chunk_id ~= "SOBT" and chunk_id ~= "SOBJ" then
      error("bad header")
    end

    table.insert(exs_file.chunks, header)
    table.insert(exs_file.headers, header)

    local size = header.size

    if size > buf:remaining() then
      print(size, buf:remaining())
      error("unexpected end of data")
    end

    local chunk_type = bytes.low_byte(header.marker)
    if chunk_type == 0 then
      local instrument = exs.parse_instrument(buf, size)
      instrument.header = header
      table.insert(exs_file.chunks, instrument)
      table.insert(exs_file.instruments, instrument)
    elseif chunk_type == 1 then
      local zone = exs.parse_zone(buf, size)
      zone.header = header
      table.insert(exs_file.chunks, zone)
      table.insert(exs_file.zones, zone)
    elseif chunk_type == 2 then
      -- group
    elseif chunk_type == 3 then
      local sample = exs.parse_sample(buf, size)
      sample.header = header
      table.insert(exs_file.chunks, sample)
      table.insert(exs_file.samples, sample)
    elseif chunk_type == 4 then
      -- param
    elseif chunk_type == 0xB then
      -- binary plist
    end

    -- Seek to the start of the next header
    buf:seek("set", header.offset + HEADER_SIZE + size)
  end

  return exs_file
end

local function decode_size(buf)
  local b1, b2 = string.byte(buf, 1, 2)

  -- The size for older files is a single byte. In newer files the second byte
  -- has a high bit set and the rest of the value is ORd with the first. In many
  -- cases the second byte is 0x80 so it does nothing. It seems like files old
  -- enough to be big endian don't support this so the conversion is probably
  -- not needed for those.
  return bit.bor(
    b1,
    bit.lshift(bit.band(0x7F, b2), 8)
  )
end

---@param buf Buffer
---@return Header
function exs.parse_header(buf)
  return {
    ---@diagnostic disable: duplicate-index
    kind = "header",
    offset = buf:seek(),
    -- {0x01, 0x01} always. Maybe used to detect if it's a record or a header?
    signature = buf:read(2),
    _ = buf:skip() and nil, -- padding
    -- Marker for the chunk's data type, with some extra bitflags
    marker = buf:read_byte(),
    -- The size of the chunk in bytes
    size = decode_size(buf:read(2)),
    _ = buf:skip(2) and nil, -- padding?
    -- A 0-based index used to order data
    index = buf:u32(),
    -- Not sure what these are. Values are commonly 0x00, 0x20, 0x40
    _ = buf:skip(4) and nil,
    -- An ASCII ID for the chunk format. Always "TBOS" or "JBOS"
    chunk_id = buf:read(4),
    --A null terminated string containing the filename
    name = buf:cstr(64),
    ---@diagnostic enable: duplicate-index
  }
end

---@param buf Buffer
---@return table
function exs.parse_instrument(buf, _size)
  return {
    ---@diagnostic disable: duplicate-index
    kind = "instrument",
    offset = buf:seek(),
    ---Not sure, but always 0s
    _ = buf:skip(4) and nil,
    num_zones = buf:u32(),
    num_groups = buf:u32(),
    num_samples = buf:u32(),
    -- Mostly zeros with 0x01 on an aligned offset
    -- _ = buf:skip(size - 16) and nil,
    ---@diagnostic enable: duplicate-index
  }
end

---@param buf Buffer
---@return table
local function parse_zone_flags(buf)
  local flags = buf:u8()

  return {
    oneshot = bit.band(flags, 1) ~= 0,
    pitch = bit.band(flags, 2) == 0,
    reverse = bit.band(flags, 4) ~= 0,
    has_velocity_range = bit.band(flags, 8) ~= 0, -- true if velocity range is not default [0, 127]
    -- unknown_bit_5 = bit.band(flags, 16) ~= 0,
    -- unknown_bit_6 = bit.band(flags, 32) ~= 0,
    has_output = bit.band(flags, 64) ~= 0, -- true if output is routed somewhere
    -- unknown_bit_8 = bit.band(flags, 128) ~= 0,
  }
end

---@param buf Buffer
---@return table
local function parse_loop_flags(buf)
  local flags = buf:u8()

  return {
    loop_on = bit.band(flags, 1) ~= 0,
    equal_power = bit.band(flags, 2) ~= 0,
    end_release = bit.band(flags, 4) ~= 0,
  }
end

---@param buf Buffer
---@return table
function exs.parse_zone(buf, size)
  local offset = buf:seek()

  return {
    ---@diagnostic disable: duplicate-index
    kind = "zone",
    offset = buf:seek(),
    zone_flags = parse_zone_flags(buf),
    key = buf:u8(),
    fine_tuning = buf:i8(),
    pan = buf:i8(), -- 4
    volume = buf:i8(),
    _ = buf:skip() and nil,
    key_low = buf:u8(),
    key_high = buf:u8(), -- 8
    _ = buf:skip() and nil,
    velocity_low = buf:u8(),
    velocity_high = buf:u8(),
    _ = buf:skip() and nil, -- 12
    sample_start = buf:u32(), -- 16
    sample_end = buf:u32(), -- 20
    loop_start = buf:u32(), -- 24
    loop_end = buf:u32(), -- 28
    loop_crossfade = buf:u32(), -- 32
    _ = buf:skip() and nil,
    loop_flags = parse_loop_flags(buf), -- 34
    play_mode = buf:u8(),
    _ = buf:skip(47) and nil,
    -- _ = buf:skip(48) and nil,
    output = buf:read_byte(), -- 83
    _ = buf:skip(5) and nil, -- 88
    group_index = buf:u32(), -- 92
    sample_index = buf:u32(), -- 96
    _ = buf:skip(4) and nil, -- 100
    sample_fade = size >= 104 and buf:u32() or nil, -- 104
    zone_offset = size >= 108 and buf:u32() or nil, -- 108
    ---@diagnostic enable: duplicate-index
  }
end

function exs.parse_sample(buf, size)
  return {
    ---@diagnostic disable: duplicate-index
    kind = "sample",
    offset = buf:seek(),
    _ = buf:skip(4) and nil,
    sample_length = buf:u32(), -- 8
    sample_rate = buf:u32(), -- 12
    bit_depth = buf:u8(), -- 13
    _ = buf:skip(15) and nil, -- 28
    sample_type = buf:u32(), -- 32
    _ = buf:skip(48) and nil, -- 80
    file_path = buf:cstr(256), -- 336
    file_name = size >= 676 and buf:cstr(256) or nil,
    ---@diagnostic enable: duplicate-index
  }
end

return exs