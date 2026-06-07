local util = require("lib.util")

local M = {}

local sensors = {
  temperature = 0.52,
  humidity = 0.55,
  sound = 0.2
}

local targets = {
  temperature = sensors.temperature,
  humidity = sensors.humidity,
  sound = sensors.sound
}

local seed = 37.219
local paused = false

function M.update(dt, elapsed)
  if paused then
    return
  end

  local t = elapsed + seed
  local rawTemperature = 18 + love.math.noise(t * 0.035, 1.7) * 18
  local rawHumidity = 38 + love.math.noise(8.1, t * 0.025) * 56
  local rawSound = love.math.noise(t * 0.16, 18.4)
  rawSound = rawSound * rawSound

  targets.temperature = util.normalizeSensor(rawTemperature, 16, 36)
  targets.humidity = util.normalizeSensor(rawHumidity, 35, 95)
  targets.sound = util.normalizeSensor(rawSound, 0.04, 0.82)

  local response = 1 - math.pow(0.001, dt)
  sensors.temperature = util.lerp(sensors.temperature, targets.temperature, response * 0.28)
  sensors.humidity = util.lerp(sensors.humidity, targets.humidity, response * 0.22)
  sensors.sound = util.lerp(sensors.sound, targets.sound, response * 0.45)
end

function M.get()
  return sensors
end

function M.togglePaused()
  paused = not paused
end

function M.reseed()
  seed = love.math.random() * 1000
end

return M
