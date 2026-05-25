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
local flowTarget = false
local flowAmount = 0
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

local function smoothstep(x)
  local t = clamp(x, 0, 1)
  return t * t * (3 - 2 * t)
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
  local cornerAX = 2
  local cornerAY = 2
  local cornerBX = 2
  local cornerBY = -4
  local cornerCX = -4
  local cornerCY = 2
  local centerX = -2
  local centerY = -2
  local boxW = 4
  local boxD = 4
  local roomH = 6
  local highOffset = 2
  local lowOffset = 0
  local midOffset = 1
  local gap = 3
  local bottomZ = 0
  local middleZ = bottomZ + roomH + highOffset + gap
  local upperZ = middleZ + roomH + highOffset + gap

  addBlock(-1, -1, 0, 2, 2, upperZ + 9, "core")
  addBlock(0, -1, 5, 1, 2, upperZ + 4, "core")

  addBlock(cornerAX, cornerAY, bottomZ + lowOffset, boxW, boxD, roomH, "base")
  addBlock(cornerBX, cornerBY, bottomZ + midOffset, boxW, boxD, roomH, "base")
  addBlock(cornerCX, cornerCY, bottomZ + highOffset, boxW, boxD, roomH, "base")

  addBlock(cornerAX, cornerAY, middleZ + lowOffset, boxW, boxD, roomH, "cantilever")
  addBlock(cornerBX, cornerBY, middleZ + midOffset, boxW, boxD, roomH, "shaft")
  addBlock(cornerCX, cornerCY, middleZ + highOffset, boxW, boxD, roomH, "cantilever")

  addBlock(centerX, centerY, upperZ, boxW, boxD, roomH, "crown")
  addBlock(-1, -1, upperZ + roomH, 2, 2, 7, "spire")
  addBlock(-1, -1, upperZ + roomH + 7, 2, 2, 1, "cap")

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

local function updateFlow(dt)
  local target = flowTarget and 1 or 0
  local speed = flowTarget and 0.55 or 0.75
  flowAmount = lerp(flowAmount, target, 1 - math.exp(-speed * dt * 5))
  if math.abs(flowAmount - target) < 0.001 then
    flowAmount = target
  end
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

local function drawFunctionalRing(cx, cy, baseSize, ring, temperature, humidity, sound, front)
  local flowBoost = flowAmount * 1.75
  local phase = ring.phase + elapsed * (ring.speed + flowBoost + sound * ring.soundSpeed)
  local radius = baseSize * (ring.radius + humidity * ring.humidityScale + temperature * ring.temperatureScale)
  local rx = radius
  local ry = radius * ring.flatness
  local y = cy + radius * ring.drop
  local alpha = front and ring.frontAlpha or ring.backAlpha
  if flowAmount > 0.01 then
    alpha = alpha * 1.18
  end
  local start = front and 0 or math.pi
  local stop = front and math.pi or TAU
  local baseColor = ring.baseColor
  local accent = ring.accentColor

  lg.setLineWidth(ring.ghostWidth)
  lg.setColor(0.74, 0.77, 0.78, alpha * ring.ghostAlpha)
  lineArc(cx, y, rx * ring.ghostScale, ry * ring.ghostScale, start, stop, 96)

  lg.setLineWidth(ring.width + sound * ring.soundWidth)
  lg.setColor(baseColor[1], baseColor[2], baseColor[3], alpha * baseColor[4])
  lineArc(cx, y, rx, ry, phase + ring.arcA[1], phase + ring.arcA[2], ring.segments)

  lg.setLineWidth(math.max(1, ring.width * 0.72))
  lg.setColor(accent[1], accent[2], accent[3], alpha * accent[4])
  lineArc(cx, y, rx * ring.accentScale, ry * ring.accentScale, phase + ring.arcB[1], phase + ring.arcB[2], ring.segments)

  if ring.arcC then
    lg.setLineWidth(math.max(1, ring.width * 0.5))
    lg.setColor(ring.thirdColor[1], ring.thirdColor[2], ring.thirdColor[3], alpha * ring.thirdColor[4])
    lineArc(cx, y, rx * ring.thirdScale, ry * ring.thirdScale, phase + ring.arcC[1], phase + ring.arcC[2], ring.segments)
  end

  lg.setLineWidth(1)
end

local function drawFunctionalRings(cx, originY, baseSize, temperature, humidity, sound, front)
  local rings = {
    {
      z = 4.2, radius = 8.0, width = 4.8, ghostWidth = 1.8, soundWidth = 1.8,
      flatness = 0.24, drop = 0.08, speed = 0.28, soundSpeed = 0.35,
      phase = 0.1, humidityScale = 0.7, temperatureScale = 0.1,
      frontAlpha = 0.42, backAlpha = 0.16, ghostAlpha = 0.42, ghostScale = 1.08,
      baseColor = {0.08, 0.095, 0.1, 0.62}, accentColor = {0.0, 0.72, 0.78, 0.78},
      accentScale = 1.17, arcA = {0.2, 0.95}, arcB = {3.58, 4.4}, segments = 26
    },
    {
      z = 8.2, radius = 5.8, width = 2.2, ghostWidth = 1.2, soundWidth = 0.8,
      flatness = 0.21, drop = 0.06, speed = -0.16, soundSpeed = 0.12,
      phase = 1.4, humidityScale = 0.25, temperatureScale = 0.2,
      frontAlpha = 0.3, backAlpha = 0.12, ghostAlpha = 0.32, ghostScale = 1.02,
      baseColor = {0.82, 0.84, 0.84, 0.44}, accentColor = {0.92, 0.08, 0.18, 0.7},
      accentScale = 1.08, arcA = {2.72, 3.48}, arcB = {5.0, 5.62}, segments = 24
    },
    {
      z = 12.3, radius = 9.2, width = 5.4, ghostWidth = 1.6, soundWidth = 2.4,
      flatness = 0.25, drop = 0.085, speed = 0.44, soundSpeed = 0.55,
      phase = 2.2, humidityScale = 0.8, temperatureScale = 0.05,
      frontAlpha = 0.38, backAlpha = 0.14, ghostAlpha = 0.3, ghostScale = 1.12,
      baseColor = {0.05, 0.06, 0.065, 0.58}, accentColor = {0.0, 0.72, 0.78, 0.82},
      accentScale = 1.23, arcA = {0.1, 0.72}, arcB = {3.35, 4.28}, segments = 24,
      arcC = {5.05, 5.52}, thirdColor = {0.92, 0.08, 0.18, 0.72}, thirdScale = 1.32
    },
    {
      z = 17.0, radius = 6.9, width = 3.0, ghostWidth = 1.3, soundWidth = 1.1,
      flatness = 0.22, drop = 0.07, speed = -0.32, soundSpeed = 0.25,
      phase = 0.8, humidityScale = 0.2, temperatureScale = 0.65,
      frontAlpha = 0.34, backAlpha = 0.13, ghostAlpha = 0.36, ghostScale = 1.14,
      baseColor = {0.92, 0.08, 0.18, 0.62}, accentColor = {0.08, 0.095, 0.1, 0.68},
      accentScale = 0.98, arcA = {5.05, 5.75}, arcB = {2.6, 3.28}, segments = 22
    },
    {
      z = 24.0, radius = 4.6, width = 2.0, ghostWidth = 1.0, soundWidth = 0.6,
      flatness = 0.2, drop = 0.055, speed = 0.12, soundSpeed = 0.15,
      phase = 3.1, humidityScale = 0.18, temperatureScale = 0.32,
      frontAlpha = 0.28, backAlpha = 0.1, ghostAlpha = 0.34, ghostScale = 1.18,
      baseColor = {0.0, 0.72, 0.78, 0.54}, accentColor = {0.86, 0.88, 0.88, 0.42},
      accentScale = 0.92, arcA = {3.78, 4.56}, arcB = {0.18, 0.82}, segments = 20
    }
  }

  for _, ring in ipairs(rings) do
    drawFunctionalRing(cx, originY - baseSize * ring.z, baseSize, ring, temperature, humidity, sound, front)
  end
end

local function drawTower(w, h)
  local baseSize = math.min(w, h) * 0.046
  local cubeW = baseSize
  local cubeH = baseSize * 0.5
  local originX = w * 0.5
  local originY = h * 0.83
  local temperature = sensors.temperature
  local humidity = sensors.humidity
  local sound = sensors.sound
  local pulse = 0.5 + math.sin(elapsed * (3.5 + sound * 8)) * 0.5

  local palette = {
    dark = {0.73 - humidity * 0.05, 0.75 + humidity * 0.04, 0.75 + humidity * 0.03, 1},
    mid = {0.84 + temperature * 0.03, 0.87 + humidity * 0.04, 0.88 + humidity * 0.04, 1},
    top = {0.96, 0.97 + humidity * 0.02, 0.97 + humidity * 0.02, 1}
  }

  drawFunctionalRings(originX, originY, baseSize, temperature, humidity, sound, false)

  local drawList = {}

  for _, cube in ipairs(tower) do
    local delay = love.math.noise(cube.seed, cube.z * 0.17) * 0.42
    local pull = smoothstep((flowAmount - delay) / 0.58)
    local orbit = elapsed * (0.75 + sound * 1.35) + cube.seed * 0.021 + cube.z * 0.16
    local radius = 5.8 + (cube.z % 9) * 0.42 + love.math.noise(cube.seed, 4.1) * 3.8
    local ringBias = math.sin(cube.z * 0.31 + cube.seed) * 0.9
    local targetX = math.cos(orbit) * radius
    local targetY = math.sin(orbit) * radius + ringBias
    local targetZ = cube.z + math.sin(orbit * 1.4 + cube.seed) * 1.1
    local x, y = cube.x, cube.y
    local z = lerp(cube.z, targetZ, pull)
    x = lerp(cube.x, targetX, pull)
    y = lerp(cube.y, targetY, pull)
    drawList[#drawList + 1] = {
      cube = cube,
      x = x,
      y = y,
      z = z
    }
  end

  table.sort(drawList, function(a, b)
    local ka = a.cube.kind == "core" and 0.18 or 0
    local kb = b.cube.kind == "core" and 0.18 or 0
    return a.x + a.y + a.z * 0.08 + ka < b.x + b.y + b.z * 0.08 + kb
  end)

  for _, item in ipairs(drawList) do
    local cube = item.cube
    local noise = love.math.noise(cube.seed, elapsed * 0.8)
    local tremor = (noise - 0.5) * sound * baseSize * 0.08
    local grow = temperature * 0.08 + pulse * sound * 0.05
    local px, py = isoProject(item.x, item.y, item.z * (1 + grow * 0.035), cubeW, cubeH)
    local kindBoost = cube.kind == "spire" and 1.16 or cube.kind == "crown" and 1.07 or 1
    local flow = math.sin(elapsed * 0.7 + cube.z * 0.37 + cube.x * 0.21) * 0.5 + 0.5
    local brightness = kindBoost * (0.86 + cube.z * 0.01 + temperature * 0.025 + flow * (0.025 + flowAmount * 0.02))
    local alpha = 0.82 + humidity * 0.08
    local accent

    if cube.z % 12 == 0 and cube.kind ~= "base" then
      accent = {0.92, 0.08, 0.18, 0.18 + temperature * 0.08}
    elseif (cube.x + cube.y + cube.z) % 17 == 0 then
      accent = {0.0, 0.72, 0.78, 0.14 + humidity * 0.08}
    end

    drawCube(originX + px + tremor, originY + py - tremor * 0.4, baseSize * (0.98 + grow * 0.04), temperature * 0.06, palette, brightness, alpha, accent)
  end

  drawFunctionalRings(originX, originY, baseSize, temperature, humidity, sound, true)
end

function love.load()
  love.math.setRandomSeed(os.time())
  lg.setDefaultFilter("linear", "linear")
  buildTower()
end

function love.update(dt)
  dt = math.min(dt, 1 / 30)
  elapsed = elapsed + dt
  updateFlow(dt)
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

function love.mousepressed()
  flowTarget = not flowTarget
end
