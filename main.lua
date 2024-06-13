_AUTO_RELOAD_DEBUG = true

local exs = require "exs"
local fspath = require "fspath"
local bit = require "bit"

---@param instrument renoise.Instrument
---@param zone Zone
---@param sample Sample
local function insert_sample(instrument, zone, sample, samples_path)
  local filename = sample.file_name or sample.header.name
  local sample_path = fspath.join(samples_path, filename)

  if not io.exists(sample_path) then
    return false
  end

  local rns_sample = instrument:insert_sample_at(#instrument.samples + 1)
  rns_sample.sample_buffer:load_from(sample_path) -- todo: handle error
  rns_sample.name = sample.header.name
  -- todo: volume must be 0 - 4, what range is the exs using?
  rns_sample.volume = 1
  rns_sample.fine_tune = zone.fine_tuning
  rns_sample.panning = math.max(math.min((zone.pan / 200) + .5, 1.0), 0.0)
  rns_sample.oneshot = bit.band(zone.zone_flags, bit.lshift(1, 0)) ~= 0
  rns_sample.sample_mapping.base_note = math.max(math.min(zone.key, 119), 0)
  rns_sample.sample_mapping.note_range = {
    math.max(math.min(zone.key_low, 119), 0),
    math.min(119, zone.key_high)
  }
  rns_sample.sample_mapping.velocity_range = {
    zone.velocity_low,
    zone.velocity_high
  }
  rns_sample.loop_start = zone.loop_start + 1
  rns_sample.loop_end = zone.loop_end - 1
  local reverse = bit.band(zone.zone_flags, bit.lshift(1, 2)) ~= 0
  if reverse then
    rns_sample.loop_mode = rns_sample.LOOP_MODE_REVERSE
  end

  return true
end

---@param filepath string
---@param exs_file ExsFile
local function import_samples(filepath, exs_file)
  local dirname, basename = fspath.split(filepath)
  local filename = string.sub(basename, 1, -#".exs"-1)

  local instrument = renoise.song().selected_instrument
  instrument:clear()

  -- Use the instrument name if possible, which is always first
  local exs_name = (exs_file.headers[1] or {}).name or filename
  instrument.name = exs_name

  local samples_path = nil

  local missing_samples = 0

  for k,zone in ipairs(exs_file.zones) do
    local sample = exs_file.samples[zone.sample_index + 1]

    -- Try to find the samples folder automatically. This is how Apple does it:
    -- https://developer.apple.com/library/archive/technotes/tn2283/_index.html#//apple_ref/doc/uid/DTS40011217-CH1-TNTAG7
    if not samples_path then
      -- If the path is actually correct, we can just use that. It's not always
      -- correct because it's an absolute path which may be from another machine.
      if sample.file_path and io.exists(sample.file_path) then
        samples_path = sample.file_path
      end

      -- Are they in the same directory as the exs file?
      local sample_filename = sample.file_name or sample.header.name
      if io.exists(fspath.join(dirname, sample_filename)) then
        samples_path = dirname
      end

      -- TODO: See if we can use common paths to find the folder.
      -- Example with the real exs path vs the file_path from the sample:
      -- The only thing in common here is "909 From Mars" and we have to walk up to find it
      -- /Users/BEN/Desktop/In Progress/909 From Mars/WAV/Kits/01. Clean Kit 
      -- /Users/matt/Samples/909 From Mars/Logic EXS/909 From Mars/02. Kits/
      -- Another idea is letting the use specify path patterns

      samples_path = renoise.app():prompt_for_path("Sample files for " .. filename .. ":")

      -- TODO: consider tracking sample paths in a doc so we don't have to do this each time

      if not samples_path then
        renoise.app():show_error("The EXS24 sample path could not be found")
        return
      end
    end

    if not sample or not insert_sample(instrument, zone, sample, samples_path) then
      missing_samples = missing_samples + 1
    end

    renoise.app():show_status(string.format("Importing EXS24 instrument (%d%%)...",((k/#exs_file.zones))*100))
  end

  renoise.app():show_status("Importing EXS24 instrument complete")

  if missing_samples ~= 0 then
    renoise.app():show_warning(string.format("%d samples could not be found", missing_samples))
  end
end

local function import_exs_file(filepath)
  renoise.app():show_status("Importing EXS24 instrument...")

  local fh = io.open(filepath, "rb")
  if fh == nil then
    renoise.app():show_error("The EXS file could not be loaded")
    return false
  end

  local buf = fh:read("*a")
  if buf == nil then
    renoise.app():show_error("The EXS file could not be read")
    return false
  end

  local ok, status = pcall(exs.parse, buf)

  if not ok then
    renoise.app():show_error("The EXS24 instrument could not be loaded")
    print(string.format("[ERROR] %s", status))
    print(debug.traceback())
    return false
  end
  -- @type ExsFile
  local exs_file = status

  if #exs_file.zones == 0 then
    renoise.app():show_status("The EXS24 instrument did not contain any zones")
    return true
  end

  if #exs_file.samples == 0 then
    renoise.app():show_status("The EXS24 instrument did not contain any samples")
    return true
  end

  import_samples(filepath, exs_file)

  return true
end

if renoise.tool():has_file_import_hook("instrument", {"exs"}) == false then
  renoise.tool():add_file_import_hook({
    category = "instrument",
    extensions = {"exs"},
    invoke = import_exs_file,
  })
end