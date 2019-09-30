require "exs24"
require "util/process_slicer"

local function sample_path(instrument_path, instrument_filename, sample_filename)
  -- Samples in the current path
  if io.exists(instrument_path .. sample_filename) then
    return instrument_path
  end

  -- GarageBand instrument
  -- i.e. "Sampler/Sampler Instruments/Puremagnetik/Eight Bit/" ->
  -- "Sampler/Sampler Files/Puremagnetik Samples/Eight Bit"
  if instrument_path:find("Sampler Instruments") then
    local garageband_path = instrument_path:gsub(
      "(%w+)/Sampler Instruments/(%w+)/(%w+)",
      "%1/Sampler Files/%2 Samples/%3"
    )
    if io.exists(garageband_path .. sample_filename) then
      return garageband_path
    end
  end

  -- Logic instrument
  -- i.e. "Logic/Sampler Instruments/Puremagnetik/alphaSynth" ->
  -- "GarageBand/Instrument Library/Sampler/Sampler Files/Puremagnetik Samples/alphaSynth"
  if instrument_path:find("Logic") then
    local logic_path = instrument_path:gsub(
      "(%w*)Logic/Sampler Instruments/(%w+)/(%w+)",
      "%1/GarageBand/Instrument Library/Sampler/Sampler Files/%2 Samples/%3"
    )
    if io.exists(logic_path .. sample_filename) then
      return logic_path
    end
  end

  -- Sample From Mars
  -- i.e. "DX100 From Mars/Logic EXS/DX100 From Mars/Leads/Box Cello.exs" ->
  -- "DX100 From Mars/WAV/Box Cello"
  if instrument_path:find("Logic EXS") then
    local mars_path = instrument_path:gsub(
      "(%w+)/Logic EXS/.+",
      "%1/WAV/"
    ) .. instrument_filename:gsub("(.+)\.exs", "%1/")
    if io.exists(mars_path .. sample_filename) then
      return mars_path
    end
  end

  return renoise.app():prompt_for_path("Sample files for " .. instrument_filename .. ":")
end

local function import_samples(instrument, exs, sample_path)
  local missing_samples = 0

  for k,zone in pairs(exs.zones) do
    if exs.samples[zone.sample_index + 1] then
      local exs_sample = exs.samples[zone.sample_index + 1]

      if io.exists(sample_path .. exs_sample.file_name) then
        local sample = instrument:insert_sample_at(#instrument.samples + 1)
        if sample.sample_buffer:load_from(sample_path .. exs_sample.file_name) == true then
          sample.name = exs_sample.name
          -- todo: volume must be 0 - 4, what range is the exs using?
          -- exs is using a twos complement byte so it has to be within  -128 -127?
          sample.volume = 1
          sample.fine_tune = math.max(math.min(zone.fine_tuning, 127), -127)
          sample.panning = math.max(math.min((zone.pan / 200) + .5, 1.0), 0.0)
          sample.oneshot = zone.oneshot
          sample.sample_mapping.base_note = math.max(math.min(zone.key, 119), 0)
          sample.sample_mapping.note_range = {
            math.max(math.min(zone.key_low, 119), 0),
            math.min(119, zone.key_high)
          }
          sample.sample_mapping.velocity_range = {zone.velocity_low, zone.velocity_high}
          sample.loop_start = zone.loop_start + 1
          sample.loop_end = zone.loop_end - 1
          if zone.reverse then
            sample.loop_mode = sample.LOOP_MODE_REVERSE
          end
        end
      else
        missing_samples = missing_samples + 1
      end
    else
      missing_samples = missing_samples + 1
    end
    renoise.app():show_status(string.format("Importing EXS24 instrument (%d%%)...",((k/#exs.zones))*100))
    coroutine.yield()
  end

  renoise.app():show_status("Importing Logic EXS24 instrument complete")
  if missing_samples ~= 0 then
    renoise.app():show_warning(string.format("%d samples could not be found", missing_samples))
  end
end

local function import_exs(path)
  renoise.app():show_status("Importing EXS24 instrument...")

  local exs = load_exs(path)

  if exs == false then
    renoise.app():show_error("The EXS24 instrument could not be loaded")
    table.clear(exs)
    return false
  end

  if #exs.zones == 0 then
    renoise.app():show_status("The EXS24 instrument did not contain any zones")
    table.clear(exs)
    return true
  end

  if #exs.samples == 0 then
    renoise.app():show_status("The EXS24 instrument did not contain any samples")
    table.clear(exs)
    return true
  end

  if os.platform() == "WINDOWS" then
    local last_slash_pos = path:match"^.*()\\"
  else
    local last_slash_pos = path:match"^.*()/"
  end
  if last_slash_pos == nil then
    renoise.app():show_error("The EXS24 sample path could not be found")
  end
  local instrument_filename = path:sub(last_slash_pos + 1)
  local instrument_path = path:sub(1, last_slash_pos)

  local instrument = renoise.song().selected_instrument
  instrument:clear()
  instrument.name = instrument_filename:sub(1, -5)

  local sample_path = sample_path(instrument_path, instrument_filename, exs.samples[1].file_name)

  if not sample_path then
    renoise.app():show_error("The EXS24 sample path could not be found")
  end

  local process = ProcessSlicer(import_samples, instrument, exs, sample_path)
  process:start()

  return true
end

if renoise.tool():has_file_import_hook("instrument", {"exs"}) == false then
  renoise.tool():add_file_import_hook({
    category = "instrument",
    extensions = {"exs"},
    invoke = import_exs
  })
end