local lg = love.graphics
local TAU = math.pi * 2

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

local function lineArc(cx, cy, rx, ry, a0, a1, segments)
  local points = {}
  for i = 0, segments do
    local t = a0 + (a1 - a0) * i / segments
    points[#points + 1] = cx + math.cos(t) * rx
    points[#points + 1] = cy + math.sin(t) * ry
  end
  lg.line(points)
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

local function addBlock(x0, y0, z0, width, depth, height, kind)
  for x = x0, x0 + width - 1 do
    for y = y0, y0 + depth - 1 do
      addCube(x, y, z0, height, kind)
    end
  end
end

local function buildTower()
  tower = {}

  -- Voxel silhouette of Guiyang Eco Conference Center. The visible space boxes
  -- share one envelope and extend the same distance from the central axis.
  local leftX = -6
  local centerX = -2
  local rightX = 2
  local boxY = -2
  local boxW = 4
  local boxD = 4
  local high = 7
  local low = 5
  local mid = 6
  local gap = 3
  local bottomZ = 0
  local middleZ = bottomZ + high + gap
  local upperZ = middleZ + high + gap

  addBlock(-1, -1, 0, 2, 2, upperZ + 9, "core")
  addBlock(0, -1, 5, 1, 2, upperZ + 4, "core")

  addBlock(leftX, boxY, bottomZ, boxW, boxD, high, "base")
  addBlock(centerX, boxY, bottomZ, boxW, boxD, low, "base")
  addBlock(rightX, boxY, bottomZ, boxW, boxD, mid, "base")

  addBlock(leftX, boxY, middleZ, boxW, boxD, high, "cantilever")
  addBlock(centerX, boxY, middleZ, boxW, boxD, low, "shaft")
  addBlock(rightX, boxY, middleZ, boxW, boxD, mid, "cantilever")

  addBlock(centerX, boxY, upperZ, boxW, boxD, low, "crown")
  addBlock(-1, -1, upperZ + low, 2, 2, 7, "spire")
  addBlock(-1, -1, upperZ + low + 7, 2, 2, 1, "cap")

  -- Rear volumes imply the hidden spaces from this viewing angle without
  -- exceeding the shared outer envelope.
  addBlock(leftX, 0, middleZ - 1, boxW, 2, low, "crown")
  addBlock(rightX, 0, bottomZ + 1, boxW, 2, low, "crown")

  table.sort(tower, function(a, b)
    local ka = a.kind == "core" and 0.18 or 0
    local kb = b.kind == "core" and 0.18 or 0
    local da = a.x + a.y + a.z * 0.08 + ka
    local db = b.x + b.y + b.z * 0.08 + kb
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

local function drawCube(cx, cy, size, lift, palette, brightness, alpha, accent)
  local hw = size * 0.5
  local hh = size * 0.27
  local h = size * (0.58 + lift)

  lg.setColor(shadeColor(palette.dark, brightness * 0.88, alpha * 0.96))
  lg.polygon("fill", cx - hw, cy, cx, cy + hh, cx, cy + hh + h, cx - hw, cy + h)

  lg.setColor(shadeColor(palette.mid, brightness * 0.98, alpha * 0.94))
  lg.polygon("fill", cx + hw, cy, cx, cy + hh, cx, cy + hh + h, cx + hw, cy + h)

  lg.setColor(shadeColor(palette.top, brightness * 1.06, alpha))
  lg.polygon("fill", cx, cy - hh, cx + hw, cy, cx, cy + hh, cx - hw, cy)

  if accent then
    lg.setColor(accent[1], accent[2], accent[3], accent[4] * alpha)
    lg.polygon("fill", cx - hw * 0.72, cy - hh * 0.1, cx - hw * 0.2, cy + hh * 0.18, cx - hw * 0.2, cy + h * 0.18, cx - hw * 0.72, cy + h * 0.04)
  end

end

local function drawFunctionalRing(cx, cy, radius, humidity, sound, phase, front)
  local rx = radius
  local ry = radius * 0.23
  local y = cy + radius * 0.08
  local alpha = front and 0.5 or 0.22

  lg.setLineWidth(2)
  lg.setColor(0.68, 0.7, 0.7, alpha * 0.38)
  lineArc(cx, y, rx * 1.08, ry * 1.08, front and 0 or math.pi, front and math.pi or TAU, 80)

  lg.setLineWidth(4 + sound * 3)
  lg.setColor(0.02, 0.035, 0.04, alpha * (0.42 + sound * 0.32))
  lineArc(cx, y, rx, ry, phase + 0.15, phase + 0.92, 24)
  lineArc(cx, y, rx, ry, phase + 2.7, phase + 3.34, 20)

  lg.setLineWidth(3)
  lg.setColor(0.0, 0.72, 0.78, alpha * (0.55 + humidity * 0.28))
  lineArc(cx, y, rx * 1.2, ry * 1.2, phase + 3.55, phase + 4.4, 24)

  lg.setLineWidth(3)
  lg.setColor(0.92, 0.08, 0.18, alpha * 0.82)
  lineArc(cx, y, rx * 1.28, ry * 1.28, phase + 5.1, phase + 5.72, 20)

  lg.setLineWidth(1)
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
    dark = {0.73 - humidity * 0.05, 0.75 + humidity * 0.04, 0.75 + humidity * 0.03, 1},
    mid = {0.84 + temperature * 0.03, 0.87 + humidity * 0.04, 0.88 + humidity * 0.04, 1},
    top = {0.96, 0.97 + humidity * 0.02, 0.97 + humidity * 0.02, 1}
  }

  drawFunctionalRing(originX, originY - baseSize * 5.1, baseSize * (4.6 + humidity * 1.2), humidity, sound, elapsed * (0.22 + sound * 0.55), false)
  drawFunctionalRing(originX, originY - baseSize * 10.4, baseSize * (3.2 + temperature * 0.9), humidity, sound, -elapsed * (0.16 + sound * 0.38), false)

  for _, cube in ipairs(tower) do
    local noise = love.math.noise(cube.seed, elapsed * 0.8)
    local tremor = (noise - 0.5) * sound * baseSize * 0.08
    local grow = temperature * 0.08 + pulse * sound * 0.05
    local px, py = isoProject(cube.x, cube.y, cube.z * (1 + grow * 0.035), cubeW, cubeH)
    local kindBoost = cube.kind == "spire" and 1.16 or cube.kind == "crown" and 1.07 or 1
    local flow = math.sin(elapsed * 0.7 + cube.z * 0.37 + cube.x * 0.21) * 0.5 + 0.5
    local brightness = kindBoost * (0.86 + cube.z * 0.01 + temperature * 0.025 + flow * 0.025)
    local alpha = 0.82 + humidity * 0.08
    local accent

    if cube.z % 12 == 0 and cube.kind ~= "base" then
      accent = {0.92, 0.08, 0.18, 0.18 + temperature * 0.08}
    elseif (cube.x + cube.y + cube.z) % 17 == 0 then
      accent = {0.0, 0.72, 0.78, 0.14 + humidity * 0.08}
    end

    drawCube(originX + px + tremor, originY + py - tremor * 0.4, baseSize * (0.98 + grow * 0.04), temperature * 0.06, palette, brightness, alpha, accent)
  end

  drawFunctionalRing(originX, originY - baseSize * 5.1, baseSize * (4.6 + humidity * 1.2), humidity, sound, elapsed * (0.22 + sound * 0.55), true)
  drawFunctionalRing(originX, originY - baseSize * 10.4, baseSize * (3.2 + temperature * 0.9), humidity, sound, -elapsed * (0.16 + sound * 0.38), true)
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
  lg.setBlendMode("alpha")
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
