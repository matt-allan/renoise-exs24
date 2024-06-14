local exs = require "exs"
local fspath = require "fspath"
local bit = require "bit"

local tool = {
  app = renoise.app(),
}

function tool:boot()
  if renoise.tool():has_file_import_hook("instrument", {"exs"}) == false then
    renoise.tool():add_file_import_hook({
      category = "instrument",
      extensions = {"exs"},
      invoke = function (filepath)
        return self:import_exs_file(filepath)
      end,
    })
  end
end

function tool:import_exs_file(filepath)
  self.app:show_status("Importing EXS24 instrument...")

  local fh = io.open(filepath, "rb")

  if fh == nil then
    self.app:show_error("The EXS file could not be loaded")
    return false
  end

  local buf = fh:read("*a")
  if buf == nil then
    self.app:show_error("The EXS file could not be read")
    return false
  end

  local ok, status = pcall(exs.parse, buf)

  if not ok then
    self.app:show_error("The EXS24 instrument could not be loaded")
    print(string.format("[ERROR] %s", status))
    print(debug.traceback())
    return false
  end
  -- @type ExsFile
  local exs_file = status

  if #exs_file.zones == 0 then
    self.app:show_status("The EXS24 instrument did not contain any zones")
    return true
  end

  if #exs_file.samples == 0 then
    self.app:show_status("The EXS24 instrument did not contain any samples")
    return true
  end

  self:import_samples(filepath, exs_file)

  return true
end

---Insert a sample into the given renoise instrument.
---@param instrument renoise.Instrument
---@param zone Zone
---@param sample Sample
---@return boolean
function tool:insert_sample(instrument, zone, sample, samples_path)
  local filename = sample.file_name or sample.header.name
  local sample_path = fspath.join(samples_path, filename)

  if not io.exists(sample_path) then
    return false
  end

  local rns_sample = instrument:insert_sample_at(#instrument.samples + 1)
  if not rns_sample.sample_buffer:load_from(sample_path) then
    return false
  end
  rns_sample.name = sample.header.name
  print(zone.volume, math.db2lin(zone.volume))
  rns_sample.volume = math.db2lin(zone.volume)
  rns_sample.fine_tune = zone.fine_tuning
  rns_sample.panning = math.max(math.min((zone.pan / 200) + .5, 1.0), 0.0)
  rns_sample.oneshot = zone.zone_flags.oneshot
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

  if zone.loop_flags.loop_on then
    if zone.play_mode == exs.PLAY_MODE_REVERSE then
      rns_sample.loop_mode = rns_sample.LOOP_MODE_REVERSE
    elseif zone.play_mode == exs.PLAY_MODE_ALTERNATE then
      rns_sample.loop_mode = rns_sample.LOOP_MODE_PING_PONG
    else
      rns_sample.loop_mode = rns_sample.LOOP_MODE_FORWARD
    end
  end

  return true
end

---Import the samples from the Exs file.
---@param filepath string
---@param exs_file ExsFile
function tool:import_samples(filepath, exs_file)
  local _dirname, basename = fspath.split(filepath)
  local filename = string.sub(basename, 1, -#".exs"-1)

  local instrument = renoise.song().selected_instrument
  instrument:clear()

  -- Use the instrument name if possible, which is always first
  local exs_name = (exs_file.headers[1] or {}).name or filename
  instrument.name = exs_name

  local samples_path = tool:find_samples(filepath, exs_file)
  if not samples_path then
    self.app:show_error("The EXS24 sample path could not be found")
    return
  end

  local missing_samples = 0

  for k,zone in ipairs(exs_file.zones) do
    local sample = exs_file.samples[zone.sample_index + 1]

    if not sample or not self:insert_sample(instrument, zone, sample, samples_path) then
      missing_samples = missing_samples + 1
    end

    self.app:show_status(string.format("Importing EXS24 instrument (%d%%)...",((k/#exs_file.zones))*100))
  end

  self.app:show_status("Importing EXS24 instrument complete")

  if missing_samples ~= 0 then
    self.app:show_warning(string.format("%d samples could not be found", missing_samples))
  end
end

---Try to find the samples folder.
---@param filepath string
---@param exs_file ExsFile
---@return string?
function tool:find_samples(filepath, exs_file)
  -- Just check the first sample since they are all in the same folder
  local zone = exs_file.zones[1]
  if not zone then error("no zones") end
  local sample = exs_file.samples[zone.sample_index + 1]
  if not sample then error("missing sample") end

  local dirname, basename = fspath.split(filepath)

  -- Is the embedded file path actually correct?
  if sample.file_path and io.exists(sample.file_path) then
    return sample.file_path
  end

  -- Are they in the same directory as the exs file?
  local sample_filename = sample.file_name or sample.header.name
  if io.exists(fspath.join(dirname, sample_filename)) then
    return dirname
  end

  -- Try rebasing the paths a few times
  for i = 1,3, 1 do
    local rebased_path = fspath.rebase(filepath, sample.file_path, i)
    if rebased_path and io.exists(fspath.join(rebased_path, sample_filename)) then
      return rebased_path
    end
  end

  -- If nothing works, ask the user for the path
  return self.app:prompt_for_path("Samples folder for " .. basename .. ":")
end

return tool