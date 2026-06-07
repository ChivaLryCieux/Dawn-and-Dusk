local ffi = require("ffi")
local math_ceil, math_floor, math_min, math_max = math.ceil, math.floor, math.min, math.max
local math_abs, math_exp, math_sin = math.abs, math.exp, math.sin
love.filesystem.setRequirePath("?.lua;?/init.lua;src-lua/?.lua;src-lua/?/init.lua")
local sensors = require("lib.sensor_sim")
local motion = require("render.motion")
local towerModel = require("models.tower_model")
local rings = require("render.rings")
local buildingRenderer = require("render.building_renderer")
local gesture = require("lib.gesture")

local elapsed = 0
local tower = {}
local canvas
local gradientShader

-- ASCII mode state
-- Toggle the top-left status badge.  Press 'd' at runtime to show/hide it.
local SHOW_STATUS_BADGE = false
local asciiMode = false
local asciiTimer = 0
local asciiBlend = 0  -- 0=normal, 1=full ASCII (lerped)
local ASCII_DENSITY = ".,:-=+*#%@"
local ASCII_CELL = 20
local asciiGridW, asciiGridH = 0, 0
local asciiChars = {}
local asciiR, asciiG, asciiB = {}, {}, {}
local asciiSampleMap = nil

local function ensureCanvas(w, h)
  if not canvas or canvas:getWidth() ~= w or canvas:getHeight() ~= h then
    canvas = love.graphics.newCanvas(w, h)
  end
end

-- Pre-compute ASCII grid from camera image
local function buildAsciiGrid(w, h)
  local imgData = gesture.getImageData()
  if not imgData then return end
  local cw, ch = gesture.getDimensions()
  if cw == 0 or ch == 0 then return end

  local gw = math_ceil(w / ASCII_CELL)
  local gh = math_ceil(h / ASCII_CELL)

  -- Rebuild sample coordinate map only when grid dimensions change
  if gw ~= asciiGridW or gh ~= asciiGridH then
    asciiGridW, asciiGridH = gw, gh
    asciiSampleMap = {}
    for gy = 0, gh - 1 do
      for gx = 0, gw - 1 do
        local sx = math_floor((gx * ASCII_CELL + ASCII_CELL * 0.5) / w * cw)
        local sy = math_floor((gy * ASCII_CELL + ASCII_CELL * 0.5) / h * ch)
        sx = math_min(math_max(sx, 0), cw - 1)
        sy = math_min(math_max(sy, 0), ch - 1)
        asciiSampleMap[gy * gw + gx] = sy * cw * 4 + sx * 4
      end
    end
  end

  local ptr = ffi.cast("uint8_t*", imgData:getPointer())
  local densityLen = #ASCII_DENSITY

  for gy = 0, gh - 1 do
    local row = gy + 1
    if not asciiChars[row] then asciiChars[row] = {} end
    if not asciiR[row] then asciiR[row] = {} end
    if not asciiG[row] then asciiG[row] = {} end
    if not asciiB[row] then asciiB[row] = {} end

    for gx = 0, gw - 1 do
      local col = gx + 1
      local offset = asciiSampleMap[gy * gw + gx]

      local r = ptr[offset] / 255
      local g = ptr[offset + 1] / 255
      local b = ptr[offset + 2] / 255

      local gray = r * 0.299 + g * 0.587 + b * 0.114
      local idx = math_floor(gray * (densityLen - 1)) + 1
      idx = math_min(math_max(idx, 1), densityLen)

      asciiChars[row][col] = ASCII_DENSITY:sub(idx, idx)
      -- Brightness floor: avoid invisible dark characters
      local minB = 0.18
      asciiR[row][col] = math_max(r, minB)
      asciiG[row][col] = math_max(g, minB)
      asciiB[row][col] = math_max(b, minB)
    end
  end
end

-- Get ASCII char + color at screen position
local function getAsciiAt(sx, sy)
  local gx = math_floor(sx / ASCII_CELL) + 1
  local gy = math_floor(sy / ASCII_CELL) + 1
  if gx < 1 or gx > asciiGridW or gy < 1 or gy > asciiGridH then
    return nil
  end
  return asciiChars[gy][gx], asciiR[gy][gx], asciiG[gy][gx], asciiB[gy][gx]
end

local function drawScene(w, h)
  local baseSize = math_min(w, h) * 0.033
  local originX = w * 0.5
  local originY = h * 0.8
  local sensorValues = sensors.get()
  local flowAmount = motion.flowAmount()
  local textAmount = motion.textAmount()
  local ringAmount = math_max(flowAmount, 0.55)
  local spinPhase = motion.spinPhase()
  local textYaw, textPitch = motion.textLook()

  local useAscii = asciiBlend > 0.01
  local asciiFn = useAscii and getAsciiAt or nil

  rings.draw(originX, originY, baseSize, sensorValues, spinPhase, ringAmount, false, textAmount, asciiFn, asciiBlend)

  ensureCanvas(w, h)
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  buildingRenderer.draw(tower, elapsed, baseSize, originX, originY, sensorValues, flowAmount, textAmount, spinPhase, textYaw, textPitch, asciiFn, asciiBlend)
  love.graphics.setCanvas()

  gradientShader:send("elapsed", elapsed)
  gradientShader:send("screenSize", {w, h})
  love.graphics.setShader(gradientShader)
  love.graphics.draw(canvas, 0, 0)
  love.graphics.setShader()

  rings.draw(originX, originY, baseSize, sensorValues, spinPhase, ringAmount, true, textAmount, asciiFn, asciiBlend)
end

function love.load()
  love.math.setRandomSeed(os.time())
  love.graphics.setDefaultFilter("linear", "linear")

  motion.load()
  tower = towerModel.build()
  gradientShader = love.graphics.newShader("src-lua/shaders/gradient.glsl")
  gesture.start()
end

function love.update(dt)
  dt = math_min(dt, 1 / 30)
  elapsed = elapsed + dt
  motion.update(dt)
  sensors.update(dt, elapsed)

  gesture.update()
  motion.setCameraMotion(gesture.getMotion())

  -- Victory gesture triggers ASCII mode for 5 seconds
  if gesture.getGestureName() == "Victory" then
    asciiMode = true
    asciiTimer = 5.0
  end

  -- Fist gesture switches state
  if gesture.fistJustClosed() then
    motion.advanceState()
  end

  -- Thumbs up → switch to text (贵阳) state
  if gesture.thumbUpJustRaised() then
    motion.setState(2)
  end

  if asciiMode then
    asciiTimer = asciiTimer - dt
    if asciiTimer <= 0 then
      asciiMode = false
      asciiTimer = 0
    end
  end

  -- Smooth lerp: blend toward target
  local target = asciiMode and 1 or 0
  asciiBlend = asciiBlend + (target - asciiBlend) * (1 - math_exp(-dt * 4))
  if math_abs(asciiBlend - target) < 0.002 then
    asciiBlend = target
  end
end

function love.draw()
  local w, h = love.graphics.getDimensions()

  -- 1. Clear screen FIRST so everything below renders on a clean slate
  local bg = 1 - asciiBlend * 0.95
  love.graphics.clear(bg, bg, bg, 1)
  love.graphics.setBlendMode("alpha")

  -- 2. ASCII grid (built into drawScene, but we need the data first)
  if asciiBlend > 0.01 then
    buildAsciiGrid(w, h)
  end

  -- 3. Scene (rings + building) -- applies transforms internally
  drawScene(w, h)

  -- 4. Camera feed + hand landmarks (bottom-right, ON TOP of scene).
  --    push()/origin()/pop() resets any transforms left over by drawScene.
  love.graphics.push()
  love.graphics.origin()
  local camImg = gesture.getImage()
  if camImg then
    local cw, ch = gesture.getDimensions()
    if cw > 0 and ch > 0 then
      local scale = math_min(w * 0.25 / cw, h * 0.25 / ch)
      local ox = w - cw * scale - 10
      local oy = h - ch * scale - 10
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(camImg, ox, oy, 0, scale, scale)

      local lm = gesture.getLandmarks()
      if lm then
        for _, pt in ipairs(lm) do
          love.graphics.setColor(0, 1, 0.5, 1)
          love.graphics.circle("fill", ox + pt.x * cw * scale,
                               oy + pt.y * ch * scale, 3)
        end
      end

      if gesture.isFist() then
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.circle("fill", ox + 15, oy + 15, 10)
      end
    end
  end
  love.graphics.pop()

  -- 5. Status badge (top-left, absolute top layer).  Shows whether the
  --    gesture/camera subsystem is actually running.  Uses push/origin to
  --    reset any transform left over by the scene drawing.
  if SHOW_STATUS_BADGE then
    love.graphics.push()
    love.graphics.origin()

    -- Gather diagnostic data
    local phase = gesture.getPhase()
    local phaseMsg = gesture.getPhaseMessage()
    local frameAge = gesture.getFrameAge()
    local pyAlive = gesture.isPythonAlive()
    local pyFresh = gesture.hasFreshFrame()
    local threadAlive = gesture.isThreadAlive()
    local gname = gesture.getGestureName()
    local mot = gesture.getMotion()
    local diag = gesture.getDiagLines()

    -- Build the status lines
    local lines = {}
    local colors = {}

    -- Sanitize: replace any non-ASCII bytes (common on Windows, e.g. GBK
    -- pathnames or non-UTF-8 console output from python subprocess) so
    -- love.graphics.print() doesn't throw a UTF-8 decode error.
    local function u(s)
      s = tostring(s or "")
      return (s:gsub("[\128-\255]", "?"))
    end

    lines[1] = "=== gesture status ==="
    colors[1] = {0.95, 0.95, 0.2, 1}

    if threadAlive then
      lines[2] = "thread (lua side): alive"
      colors[2] = {0.3, 1.0, 0.4, 1}
    else
      lines[2] = "thread (lua side): DEAD - see diag below"
      colors[2] = {1.0, 0.3, 0.3, 1}
    end

    if phase == "unknown" or phase == "" then
      lines[3] = "python: waiting for first heartbeat..."
      colors[3] = {0.8, 0.8, 0.8, 1}
    elseif phase == "error" then
      lines[3] = "python: ERROR - " .. u(phaseMsg)
      colors[3] = {1.0, 0.3, 0.3, 1}
    elseif phase == "camera_only" then
      lines[3] = "python: camera working (no gesture: " .. u(phaseMsg) .. ")"
      colors[3] = {1.0, 0.6, 0.2, 1}
    elseif phase == "running" or phase == "mediapipe_ok" then
      lines[3] = "python: RUNNING - mediapipe active"
      colors[3] = {0.3, 1.0, 0.4, 1}
    else
      lines[3] = "python: " .. u(phase)
      colors[3] = {1.0, 1.0, 0.5, 1}
    end

    if frameAge < 0 then
      lines[4] = "camera: no frame received yet"
      colors[4] = {1.0, 0.4, 0.2, 1}
    elseif pyFresh then
      lines[4] = string.format("camera: live  (last frame %.1fs ago)", frameAge)
      colors[4] = {0.3, 1.0, 0.4, 1}
    else
      lines[4] = string.format("camera: STALE  (last frame %.1fs ago)", frameAge)
      colors[4] = {1.0, 0.5, 0.2, 1}
    end

    lines[5] = string.format("gesture: %s   motion: %.2f", u(gname or "none"), mot or 0)
    colors[5] = {0.8, 0.9, 1.0, 1}

    -- Show diag file contents (most useful when things are broken)
    if diag and #diag > 0 then
      lines[#lines + 1] = "--- diag from thread ---"
      colors[#lines] = {0.7, 0.7, 0.3, 1}
      for i = 1, math.min(#diag, 10) do
        lines[#lines + 1] = u(diag[i])
        colors[#lines] = {0.75, 0.75, 0.75, 1}
      end
    end

    -- Render box
    local pad = 8
    local lineH = 14
    local boxW = 0
    for _, ln in ipairs(lines) do
      local w_l = #ln * 8
      if w_l > boxW then boxW = w_l end
    end
    boxW = math.max(boxW + pad * 2, 380)

    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 8, 8, boxW, #lines * lineH + pad * 2)
    love.graphics.setColor(0.9, 0.85, 0.2, 1)
    love.graphics.rectangle("line", 8, 8, boxW, #lines * lineH + pad * 2)

    for i, ln in ipairs(lines) do
      love.graphics.setColor(colors[i])
      love.graphics.print(ln, 16, 12 + (i - 1) * lineH)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
  end
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif key == "space" then
    sensors.togglePaused()
  elseif key == "r" then
    sensors.reseed()
  elseif key == "f" then
    love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
  elseif key == "d" then
    SHOW_STATUS_BADGE = not SHOW_STATUS_BADGE
  end
end

function love.mousepressed()
  motion.advanceState()
end

function love.quit()
  gesture.stop()
end

function love.resize(w, h)
  -- Invalidate the scene canvas so it gets recreated at the new size on
  -- the next draw(). Also clear ASCII state so the grid rebuilds.
  canvas = nil
  asciiGridW, asciiGridH = 0, 0
  asciiSampleMap = nil
end
