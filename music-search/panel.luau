--!nonstrict

local snapshot = noctalia.state.get("music_snapshot")
local position = noctalia.state.get("music_position")

local CACHE_DIR = (noctalia.getenv("XDG_CACHE_HOME") or ((noctalia.getenv("HOME") or "") .. "/.cache"))
  .. "/noctalia/plugins/music-search/thumbs"
local thumbPath = nil
local thumbForId = ""
local thumbPending = false

local trCache = {}

local function tr(key)
  local cached = trCache[key]
  if cached ~= nil then
    return cached
  end
  local value = noctalia.tr(key)
  trCache[key] = value
  return value
end

local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function dispatch(message)
  noctalia.state.set("music_command", message)
end

local function formatDuration(totalSeconds)
  local total = math.max(0, math.floor(tonumber(totalSeconds) or 0))
  local hours = math.floor(total / 3600)
  local minutes = math.floor((total % 3600) / 60)
  local seconds = total % 60
  if hours > 0 then
    return string.format("%d:%02d:%02d", hours, minutes, seconds)
  end
  return string.format("%d:%02d", minutes, seconds)
end

local render

local function ensureThumbnail(id, url)
  if thumbPending or id == "" or url == "" then return end
  if thumbPath ~= nil and thumbForId == id then return end
  thumbPending = true
  thumbForId = id
  local dest = CACHE_DIR .. "/" .. id .. ".jpg"
  noctalia.download(url, dest, function(ok)
    thumbPending = false
    if ok then
      thumbPath = dest
    else
      thumbPath = nil
      thumbForId = ""
    end
    render()
  end)
end

local render

render = function()
  local current = (snapshot or {}).current or {}
  local playing = (snapshot or {}).playing == true
  local paused = (snapshot or {}).paused == true
  local title = current.title or ""

  local header = ui.row({ gap = 8, align = "center" }, {
    ui.glyph({ name = "music", size = 16 }),
    ui.label({
      text = title ~= "" and title or tr("panel.no_track"),
      flexGrow = 1,
      maxLines = 1,
    }),
    ui.button({ glyph = "close", onClick = function()
      panel.close()
    end }),
  })

  local children = {}
  if thumbPath then
    children[#children + 1] = ui.image({
      path = thumbPath,
      width = 320,
      height = 180,
      fit = "cover",
      radius = 12,
    })
  end
  if playing or title ~= "" then
    local pos = math.max(0, math.floor(tonumber((position or {}).position) or 0))
    local duration = math.max(0, math.floor(tonumber(current.duration) or 0))
    children[#children + 1] = ui.row({ gap = 8, align = "center" }, {
      ui.label({ text = formatDuration(pos), width = 44 }),
      ui.slider({
        min = 0,
        max = math.max(1, duration),
        step = 1,
        value = pos,
        flexGrow = 1,
        onChange = function(value)
          dispatch({ action = "seek", position = value })
        end,
      }),
      ui.label({ text = formatDuration(duration), width = 44 }),
    })
    children[#children + 1] = ui.row({ gap = 8, align = "center" }, {
      ui.button({ glyph = "stop", onClick = function()
        dispatch({ action = "stop" })
      end }),
      ui.button({ glyph = paused and "play" or "pause", onClick = function()
        dispatch({ action = "toggle" })
      end }),
    })
  else
    children[#children + 1] = ui.label({ text = tr("panel.no_track") })
  end

  panel.render(ui.column({ flexGrow = 1, gap = 16, padding = 16 }, {
    header,
    ui.column({ flexGrow = 1, gap = 12, align = "center" }, children),
  }))
end

noctalia.state.watch("music_snapshot", function(value)
  snapshot = value
  local current = (snapshot or {}).current or {}
  ensureThumbnail(current.id or "", current.thumbnail or "")
  render()
end)

noctalia.state.watch("music_position", function(value)
  position = value
  render()
end)

noctalia.runAsync("mkdir -p " .. shellQuote(CACHE_DIR), function()
  render()
end)

render()
