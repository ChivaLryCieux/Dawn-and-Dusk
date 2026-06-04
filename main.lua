local ffi = require("ffi")
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
local asciiMode = false
local asciiTimer = 0
local asciiBlend = 0  -- 0=normal, 1=full ASCII (lerped)
local ASCII_DENSITY = ".,:-=+*#%@"
local ASCII_CELL = 14
local asciiGridW, asciiGridH = 0, 0
local asciiChars = {}
local asciiR, asciiG, asciiB = {}, {}, {}

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

  local gw = math.ceil(w / ASCII_CELL)
  local gh = math.ceil(h / ASCII_CELL)

  if gw ~= asciiGridW or gh ~= asciiGridH then
    asciiGridW, asciiGridH = gw, gh
  end

  local ptr = ffi.cast("uint8_t*", imgData:getPointer())
  local stride = cw * 4
  local densityLen = #ASCII_DENSITY

  for gy = 0, gh - 1 do
    local row = gy + 1
    if not asciiChars[row] then asciiChars[row] = {} end
    if not asciiR[row] then asciiR[row] = {} end
    if not asciiG[row] then asciiG[row] = {} end
    if not asciiB[row] then asciiB[row] = {} end

    for gx = 0, gw - 1 do
      local col = gx + 1
      local sx = math.floor((gx * ASCII_CELL + ASCII_CELL * 0.5) / w * cw)
      local sy = math.floor((gy * ASCII_CELL + ASCII_CELL * 0.5) / h * ch)
      sx = math.min(math.max(sx, 0), cw - 1)
      sy = math.min(math.max(sy, 0), ch - 1)

      local offset = sy * stride + sx * 4
      local r = ptr[offset] / 255
      local g = ptr[offset + 1] / 255
      local b = ptr[offset + 2] / 255

      local gray = r * 0.299 + g * 0.587 + b * 0.114
      local idx = math.floor(gray * (densityLen - 1)) + 1
      idx = math.min(math.max(idx, 1), densityLen)

      asciiChars[row][col] = ASCII_DENSITY:sub(idx, idx)
      asciiR[row][col] = r
      asciiG[row][col] = g
      asciiB[row][col] = b
    end
  end
end

-- Get ASCII char + color at screen position
local function getAsciiAt(sx, sy)
  local gx = math.floor(sx / ASCII_CELL) + 1
  local gy = math.floor(sy / ASCII_CELL) + 1
  if gx < 1 or gx > asciiGridW or gy < 1 or gy > asciiGridH then
    return nil
  end
  return asciiChars[gy][gx], asciiR[gy][gx], asciiG[gy][gx], asciiB[gy][gx]
end

local function drawScene(w, h)
  local baseSize = math.min(w, h) * 0.033
  local originX = w * 0.5
  local originY = h * 0.8
  local sensorValues = sensors.get()
  local flowAmount = motion.flowAmount()
  local textAmount = motion.textAmount()
  local ringAmount = math.max(flowAmount, 0.55)
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
  gradientShader = love.graphics.newShader("shaders/gradient.glsl")
  gesture.start()
end

function love.update(dt)
  dt = math.min(dt, 1 / 30)
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
  asciiBlend = asciiBlend + (target - asciiBlend) * (1 - math.exp(-dt * 4))
  if math.abs(asciiBlend - target) < 0.002 then
    asciiBlend = target
  end
end

function love.draw()
  local w, h = love.graphics.getDimensions()

  if asciiBlend > 0.01 then
    buildAsciiGrid(w, h)
  end

  love.graphics.clear(1, 1, 1, 1)
  love.graphics.setBlendMode("alpha")
  drawScene(w, h)

  -- Camera feed + hand landmarks (bottom-right)
  local camImg = gesture.getImage()
  if camImg then
    local cw, ch = gesture.getDimensions()
    local scale = math.min(w * 0.25 / cw, h * 0.25 / ch)
    local ox = w - cw * scale - 10
    local oy = h - ch * scale - 10
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.draw(camImg, ox, oy, 0, scale, scale)

    local lm = gesture.getLandmarks()
    if lm then
      for _, pt in ipairs(lm) do
        love.graphics.setColor(0, 1, 0.5, 0.9)
        love.graphics.circle("fill", ox + pt.x * cw * scale, oy + pt.y * ch * scale, 3)
      end
    end

    if gesture.isFist() then
      love.graphics.setColor(1, 0.3, 0.3, 0.9)
      love.graphics.circle("fill", ox + 15, oy + 15, 10)
    end
    love.graphics.setColor(1, 1, 1, 1)
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
  end
end

function love.mousepressed()
  motion.advanceState()
end

function love.quit()
  gesture.stop()
end
