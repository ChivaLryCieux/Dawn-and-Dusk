local sensors = require("sensor_sim")
local motion = require("motion")
local towerModel = require("tower_model")
local rings = require("rings")
local buildingRenderer = require("building_renderer")

local elapsed = 0
local tower = {}

local function drawScene(w, h)
  local baseSize = math.min(w, h) * 0.033
  local originX = w * 0.5
  local originY = h * 0.74
  local sensorValues = sensors.get()
  local flowAmount = motion.flowAmount()
  local spinPhase = motion.spinPhase()

  rings.draw(originX, originY, baseSize, sensorValues, spinPhase, flowAmount, false)
  buildingRenderer.draw(tower, elapsed, baseSize, originX, originY, sensorValues, flowAmount, spinPhase)
  rings.draw(originX, originY, baseSize, sensorValues, spinPhase, flowAmount, true)
end

function love.load()
  love.math.setRandomSeed(os.time())
  love.graphics.setDefaultFilter("linear", "linear")
  motion.load()
  tower = towerModel.build()
end

function love.update(dt)
  dt = math.min(dt, 1 / 30)
  elapsed = elapsed + dt
  motion.update(dt)
  sensors.update(dt, elapsed)
end

function love.draw()
  local w, h = love.graphics.getDimensions()
  love.graphics.clear(1, 1, 1, 1)
  love.graphics.setBlendMode("alpha")
  drawScene(w, h)
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
  motion.toggleFlow()
end
