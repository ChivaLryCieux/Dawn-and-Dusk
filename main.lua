local lg = love.graphics

local sensors = {
  temperature = 0.52,
  humidity = 0.55,
  sound = 0.2
}

local sensorTargets = {
  temperature = sensors.temperature,
  humidity = sensors.humidity,
  sound = sensors.sound
}

local sensorSeed = 37.219
local paused = false
local elapsed = 0
local tower = {}

local function clamp(value, low, high)
  return math.max(low, math.min(high, value))
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function normalizeSensor(value, minValue, maxValue)
  return clamp((value - minValue) / (maxValue - minValue), 0, 1)
end

local function isoProject(x, y, z, cubeW, cubeH)
  return (x - y) * cubeW * 0.5, (x + y) * cubeH * 0.5 - z * cubeH
end

local function shadeColor(color, factor, alpha)
  return color[1] * factor, color[2] * factor, color[3] * factor, alpha or color[4] or 1
end

local function addCube(x, y, z, height, kind)
  for level = 0, height - 1 do
    tower[#tower + 1] = {
      x = x,
      y = y,
      z = z + level,
      kind = kind or "mass",
      seed = love.math.random() * 1000
    }
  end
end

local function buildTower()
  tower = {}

  -- A modular silhouette based on grouped cube shafts: wide base, tapered body,
  -- offset crowns, and a hollowed central light well.
  for x = -4, 4 do
    for y = -3, 3 do
      local edge = math.max(math.abs(x) / 4, math.abs(y) / 3)
      local height = math.floor(lerp(7, 3, edge))
      if math.abs(x) < 2 and math.abs(y) < 1 then
        height = height - 2
      end
      addCube(x, y, 0, math.max(1, height), "base")
    end
  end

  local shafts = {
    {-2, -1, 7, 10}, {0, -1, 6, 13}, {2, -1, 7, 11},
    {-2, 1, 6, 9}, {0, 1, 7, 14}, {2, 1, 6, 10},
    {-3, 0, 5, 8}, {3, 0, 5, 8}
  }

  for _, shaft in ipairs(shafts) do
    addCube(shaft[1], shaft[2], shaft[3], shaft[4], "shaft")
  end

  for x = -3, 3 do
    addCube(x, -2, 15 + math.abs(x % 2), 2, "crown")
    addCube(x, 2, 14 + math.abs(x % 2), 2, "crown")
  end

  addCube(-1, 0, 18, 5, "spire")
  addCube(0, 0, 19, 7, "spire")
  addCube(1, 0, 18, 5, "spire")

  table.sort(tower, function(a, b)
    local da = a.x + a.y + a.z * 0.08
    local db = b.x + b.y + b.z * 0.08
    return da < db
  end)
end

local function updateSensors(dt)
  if paused then
    return
  end

  local t = elapsed + sensorSeed
  local rawTemperature = 18 + love.math.noise(t * 0.035, 1.7) * 18
  local rawHumidity = 38 + love.math.noise(8.1, t * 0.025) * 56
  local rawSound = love.math.noise(t * 0.16, 18.4)
  rawSound = rawSound * rawSound

  sensorTargets.temperature = normalizeSensor(rawTemperature, 16, 36)
  sensorTargets.humidity = normalizeSensor(rawHumidity, 35, 95)
  sensorTargets.sound = normalizeSensor(rawSound, 0.04, 0.82)

  local response = 1 - math.pow(0.001, dt)
  sensors.temperature = lerp(sensors.temperature, sensorTargets.temperature, response * 0.28)
  sensors.humidity = lerp(sensors.humidity, sensorTargets.humidity, response * 0.22)
  sensors.sound = lerp(sensors.sound, sensorTargets.sound, response * 0.45)
end

local function drawCube(cx, cy, size, lift, palette, brightness, alpha)
  local hw = size * 0.5
  local hh = size * 0.27
  local h = size * (0.58 + lift)

  lg.setColor(shadeColor(palette.dark, brightness * 0.78, alpha))
  lg.polygon("fill", cx - hw, cy, cx, cy + hh, cx, cy + hh + h, cx - hw, cy + h)

  lg.setColor(shadeColor(palette.mid, brightness * 0.95, alpha))
  lg.polygon("fill", cx + hw, cy, cx, cy + hh, cx, cy + hh + h, cx + hw, cy + h)

  lg.setColor(shadeColor(palette.top, brightness * 1.14, alpha))
  lg.polygon("fill", cx, cy - hh, cx + hw, cy, cx, cy + hh, cx - hw, cy)

  lg.setColor(0.18, 0.42, 0.18, 0.16 * alpha)
  lg.polygon("line", cx, cy - hh, cx + hw, cy, cx + hw, cy + h, cx, cy + hh + h, cx - hw, cy + h, cx - hw, cy)
end

local function drawTower(w, h)
  local baseSize = math.min(w, h) * 0.046
  local cubeW = baseSize
  local cubeH = baseSize * 0.5
  local originX = w * 0.5
  local originY = h * 0.71
  local temperature = sensors.temperature
  local humidity = sensors.humidity
  local sound = sensors.sound
  local pulse = 0.5 + math.sin(elapsed * (3.5 + sound * 8)) * 0.5

  local palette = {
    dark = {0.68 - humidity * 0.08, 0.76 + humidity * 0.08, 0.64, 1},
    mid = {0.78 + temperature * 0.08, 0.9, 0.7 + humidity * 0.06, 1},
    top = {0.92 + temperature * 0.04, 0.98, 0.82 + humidity * 0.05, 1}
  }

  for _, cube in ipairs(tower) do
    local noise = love.math.noise(cube.seed, elapsed * 0.8)
    local tremor = (noise - 0.5) * sound * baseSize * 0.28
    local grow = temperature * 0.2 + pulse * sound * 0.2
    local px, py = isoProject(cube.x, cube.y, cube.z * (1 + grow * 0.035), cubeW, cubeH)
    local kindBoost = cube.kind == "spire" and 1.18 or cube.kind == "crown" and 1.08 or 1
    local brightness = kindBoost * (0.74 + cube.z * 0.018 + temperature * 0.2 + noise * 0.09)
    local alpha = 0.9 + humidity * 0.08

    drawCube(originX + px + tremor, originY + py - tremor * 0.4, baseSize * (0.98 + grow * 0.08), temperature * 0.16, palette, brightness, alpha)
  end

end

function love.load()
  love.math.setRandomSeed(os.time())
  lg.setDefaultFilter("linear", "linear")
  buildTower()
end

function love.update(dt)
  dt = math.min(dt, 1 / 30)
  elapsed = elapsed + dt
  updateSensors(dt)
end

function love.draw()
  local w, h = lg.getDimensions()
  lg.clear(1, 1, 1, 1)
  drawTower(w, h)
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif key == "space" then
    paused = not paused
  elseif key == "r" then
    sensorSeed = love.math.random() * 1000
  elseif key == "f" then
    love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
  end
end
