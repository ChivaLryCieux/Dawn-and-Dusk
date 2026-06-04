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

local function ensureCanvas(w, h)
  if not canvas or canvas:getWidth() ~= w or canvas:getHeight() ~= h then
    canvas = love.graphics.newCanvas(w, h)
  end
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

  rings.draw(originX, originY, baseSize, sensorValues, spinPhase, ringAmount, false, textAmount)

  ensureCanvas(w, h)
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  buildingRenderer.draw(tower, elapsed, baseSize, originX, originY, sensorValues, flowAmount, textAmount, spinPhase, textYaw, textPitch)
  love.graphics.setCanvas()

  gradientShader:send("elapsed", elapsed)
  gradientShader:send("screenSize", {w, h})
  love.graphics.setShader(gradientShader)
  love.graphics.draw(canvas, 0, 0)
  love.graphics.setShader()

  rings.draw(originX, originY, baseSize, sensorValues, spinPhase, ringAmount, true, textAmount)
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

  -- Camera motion drives spin speed
  motion.setCameraMotion(gesture.getMotion())

  -- Fist gesture switches state
  if gesture.fistJustClosed() then
    motion.advanceState()
  end
end

function love.draw()
  local w, h = love.graphics.getDimensions()
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
