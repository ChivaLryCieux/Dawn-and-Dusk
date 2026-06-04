local sensors = require("lib.sensor_sim")
local motion = require("render.motion")
local towerModel = require("models.tower_model")
local rings = require("render.rings")
local buildingRenderer = require("render.building_renderer")
local camera = require("lib.camera")

local elapsed = 0
local tower = {}
local canvas
local gradientShader
local cameraEnabled = false
local cameraImage = nil

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

  -- Back rings (behind tower)
  rings.draw(originX, originY, baseSize, sensorValues, spinPhase, ringAmount, false, textAmount)

  -- Tower → canvas with gradient shader
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

  -- Front rings (in front of tower)
  rings.draw(originX, originY, baseSize, sensorValues, spinPhase, ringAmount, true, textAmount)
end

function love.load()
  love.math.setRandomSeed(os.time())
  love.graphics.setDefaultFilter("linear", "linear")
  motion.load()
  tower = towerModel.build()
  gradientShader = love.graphics.newShader("shaders/gradient.glsl")

  local ok, err = pcall(camera.open, 0)
  if ok then
    cameraEnabled = true
  else
    print("Camera not available: " .. tostring(err))
  end
end

function love.update(dt)
  dt = math.min(dt, 1 / 30)
  elapsed = elapsed + dt
  motion.update(dt)
  sensors.update(dt, elapsed)

  if cameraEnabled then
    local ok, img = pcall(camera.read)
    if ok then cameraImage = img end
    local ok2, m = pcall(camera.motion)
    if ok2 and m then motion.setCameraMotion(m) end
  end
end

function love.draw()
  local w, h = love.graphics.getDimensions()
  love.graphics.clear(1, 1, 1, 1)
  love.graphics.setBlendMode("alpha")
  drawScene(w, h)

  -- Debug: camera feed in bottom-right corner
  if cameraEnabled and cameraImage then
    local cw, ch = cameraImage:getDimensions()
    local scale = math.min(w * 0.25 / cw, h * 0.25 / ch)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.draw(cameraImage, w - cw * scale - 10, h - ch * scale - 10, 0, scale, scale)
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
  elseif key == "c" then
    if cameraEnabled then
      camera.close()
      cameraEnabled = false
      cameraImage = nil
    else
      local ok, err = pcall(camera.open, 0)
      if ok then cameraEnabled = true
      else print("Camera: " .. tostring(err)) end
    end
  end
end

function love.mousepressed()
  motion.advanceState()
end
