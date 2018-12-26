require "util/binary"
require "util/str"

function load_exs(path)
  local fh = io.open(path, "rb")
  if fh == nil then
    return false
  end

  fh:seek("set", 16)
  local magic = fh:read(4)

  if magic ~= "SOBT" and magic ~= "SOBJ" and magic ~= "TBOS" and magic ~= "JBOS" then
    return false
  end

  local big_endian = false
  if magic == "SOBT" or magic == "SOBJ" then
    big_endian = true
  end

  local is_size_expanded = false
  fh:seek("set", 4)
  local header_size = read_dword(fh, big_endian)
  if header_size > 0x8000 then
    is_size_expanded = true
  end

  local exs = {zones = {}, samples = {}}
  local i = 0
  local data_size = fh:seek("end")

  while (i + 84 < data_size) do
    fh:seek("set", i)
    local sig = read_dword(fh, big_endian)

    fh:seek("set", i + 4)
    local size = read_dword(fh, big_endian)

    fh:seek("set", i + 16)
    local magic = fh:read(4)

    if is_size_expanded and size > 0x8000 then
      size = size - 0x8000
    end

    local chunk_type = bit.rshift(bit.band(sig, 0x0F000000), 24)

    if chunk_type == 0x01 then
      if size < 104 then
        return false
      end
      table.insert(exs.zones, create_zone(fh, i, size + 84, big_endian))
    elseif chunk_type == 0x03 then
      if size ~= 336 and size ~= 592 then
        return false
      end
      table.insert(exs.samples, create_sample(fh, i, size + 84, big_endian))
    end
    i = i + size + 84
  end

  return exs
end

function create_zone(fh, i, size, big_endian)
  local zone = {}

  fh:seek("set", i + 8)
  zone.id  = read_dword(fh, big_endian)

  fh:seek("set", i + 20)
  zone.name = rtrim(fh:read(64))

  fh:seek("set", i + 84)
  local zone_opts = string.byte(fh:read(1))
  zone.pitch = bit.band(zone_opts, bit.lshift(1, 1)) == 0
  zone.oneshot = bit.band(zone_opts, bit.lshift(1, 0)) ~= 0
  zone.reverse = bit.band(zone_opts, bit.lshift(1, 2)) ~= 0

  fh:seek("set", i + 85)
  zone.key = string.byte(fh:read(1))

  fh:seek("set", i + 86)
  zone.fine_tuning = twos_complement(string.byte(fh:read(1)), 8)

  fh:seek("set", i + 87)
  zone.pan = twos_complement(string.byte(fh:read(1)), 8)

  fh:seek("set", i + 88)
  zone.volume = twos_complement(string.byte(fh:read(1)), 8)
  fh:seek("set", i + 164)
  zone.coarse_tuning = twos_complement(string.byte(fh:read(1)), 8)

  fh:seek("set", i + 90)
  zone.key_low = string.byte(fh:read(1))

  fh:seek("set", i + 91)
  zone.key_high = string.byte(fh:read(1))

  zone.velocity_range_on = bit.band(zone_opts, bit.lshift(1, 3)) ~= 0

  fh:seek("set", i + 93)
  zone.velocity_low = string.byte(fh:read(1))

  fh:seek("set", i + 94)
  zone.velocity_high = string.byte(fh:read(1))

  fh:seek("set", i + 96)
  zone.sample_start = read_dword(fh, big_endian)

  fh:seek("set", i + 100)
  zone.sample_end = read_dword(fh, big_endian)

  fh:seek("set", i + 104)
  zone.loop_start = read_dword(fh, big_endian)

  fh:seek("set", i + 108)
  zone.loop_end = read_dword(fh, big_endian)

  fh:seek("set", i + 112)
  zone.loop_crossfade = read_dword(fh, big_endian)

  fh:seek("set", i + 117)
  local loop_opts = string.byte(fh:read(1))
  zone.loop_on = bit.band(loop_opts, bit.lshift(1, 0)) ~= 0
  zone.loop_equal_power = bit.band(loop_opts, bit.lshift(1, 1)) ~= 0

  if bit.band(zone_opts, bit.lshift(1, 6)) == 0 then
    zone.output = -1
  else
    fh:seek("set", i + 166)
    zone.output = string.byte(fh:read(1))
  end

  fh:seek("set", i + 172)
  zone.group_index = read_dword(fh, big_endian)

  fh:seek("set", i + 176)
  zone.sample_index = read_dword(fh, big_endian)

  zone.sample_fade = 0
  if size > 188 then
    fh:seek("set", i + 188)
    zone.sample_fade = read_dword(fh, big_endian)
  end

  zone.offset = 0
  if size > 192 then
    fh:seek("set", i + 192)
    zone.offset = read_dword(fh, big_endian)
  end
  return zone
end

function create_sample(fh, i, size, big_endian)
  local sample = {}

  fh:seek("set", i + 8)
  sample.id  = read_dword(fh, big_endian)

  fh:seek("set", i + 20)
  sample.name = rtrim(fh:read(64))

  fh:seek("set", i + 88)
  sample.length = read_dword(fh, big_endian)

  fh:seek("set", i + 92)
  sample.sample_rate = read_dword(fh, big_endian)

  fh:seek("set", i + 96)
  sample.bit_depth = string.byte(fh:read(1))

  fh:seek("set", i + 112)
  sample.type = read_dword(fh, big_endian)

  fh:seek("set", i + 164)
  sample.file_path = rtrim(fh:read(256))

  if size > 420 then
    fh:seek("set", i + 420)
    sample.file_name = rtrim(fh:read(256))
  else
    fh:seek("set", i + 20)
    sample.file_name = rtrim(fh:read(64))
  end

  return sample
end