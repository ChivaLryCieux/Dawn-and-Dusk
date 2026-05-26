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
local mouseX = 0
local mouseY = 0
local mouseSpeed = 0
local spinPhase = 0
local spinSpeed = 0.28
local spinTargetSpeed = 0.28
local elapsed = 0
local tower = {}
local drawList = {}
local paletteScratch = {
  dark = {0, 0, 0, 1},
  mid = {0, 0, 0, 1},
  top = {0, 0, 0, 1},
  brightness = 1
}

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

local function mixComponents(ar, ag, ab, aa, br, bg, bb, ba, t)
  return lerp(ar, br, t), lerp(ag, bg, t), lerp(ab, bb, t), lerp(aa, ba, t)
end

local function getColorCyclePalette(x, y, z, out)
  local segmentDuration = 10
  local cycle = (elapsed % (segmentDuration * 4)) / segmentDuration
  local segment = math.floor(cycle)
  local localT = smoothstep(cycle - segment)
  local tiltedAxis = x * 0.062 - y * 0.034 + z * 0.021
  local crossFlow = x * 0.018 + y * 0.026 - z * 0.006
  local sweep = clamp(0.48 + tiltedAxis + math.sin(elapsed * 0.12 + crossFlow) * 0.16, 0, 1)
  local band = smoothstep(sweep)
  local rybR, rybG, rybB, rybA

  if band < 0.82 then
    local t = smoothstep(band / 0.82)
    rybR, rybG, rybB, rybA = mixComponents(0.82, 0.05, 0.08, 0.92, 1, 0.76, 0.08, 0.92, t)
  else
    local t = smoothstep((band - 0.82) / 0.18)
    rybR, rybG, rybB, rybA = mixComponents(1, 0.76, 0.08, 0.92, 0.08, 0.2, 0.68, 0.92, t)
  end

  local blueLift = smoothstep(clamp(0.12 + x * 0.014 - y * 0.008 + z * 0.004, 0, 1))
  local blueR, blueG, blueB, blueA = mixComponents(0.02, 0.26, 0.52, 0.94, 0, 0.52, 0.76, 0.95, blueLift)
  local r, g, b, a

  if segment == 0 then
    r, g, b, a = mixComponents(0.015, 0.018, 0.02, 0.94, rybR, rybG, rybB, rybA, localT)
  elseif segment == 1 then
    r, g, b, a = mixComponents(rybR, rybG, rybB, rybA, blueR, blueG, blueB, blueA, localT)
  elseif segment == 2 then
    r, g, b, a = mixComponents(blueR, blueG, blueB, blueA, 0.015, 0.018, 0.02, 0.94, localT)
  else
    r, g, b, a = 0.015, 0.018, 0.02, 0.94
  end

  out.dark[1], out.dark[2], out.dark[3], out.dark[4] = r * 0.7, g * 0.76, b * 0.82, a
  out.mid[1], out.mid[2], out.mid[3], out.mid[4] = r * 0.88, g * 0.94, b, a
  out.top[1], out.top[2], out.top[3], out.top[4] = math.min(r * 1.16, 1), math.min(g * 1.16, 1), math.min(b * 1.18, 1), a
  out.brightness = 0.9 + band * 0.1
  return out
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

local function isFrontAngle(angle)
  local t = angle % TAU
  return t >= 0 and t <= math.pi
end

local function drawArcSurface(cx, cy, rx, ry, a0, a1, thickness, height, color, alpha, segments, front)
  local topOffset = -height * 0.5
  local bottomOffset = height * 0.5

  for i = 0, segments - 1 do
    local t0 = a0 + (a1 - a0) * i / segments
    local t1 = a0 + (a1 - a0) * (i + 1) / segments
    local tm = (t0 + t1) * 0.5
    local visible = front == nil or isFrontAngle(tm) == front

    if visible then
      local x0 = cx + math.cos(t0) * rx
      local y0 = cy + math.sin(t0) * ry
      local x1 = cx + math.cos(t1) * rx
      local y1 = cy + math.sin(t1) * ry
      local shimmer = 0.82 + 0.18 * i / segments

      lg.setColor(color[1] * shimmer, color[2] * shimmer, color[3] * shimmer, alpha * color[4])
      lg.polygon(
        "fill",
        x0, y0 + topOffset,
        x1, y1 + topOffset,
        x1, y1 + bottomOffset,
        x0, y0 + bottomOffset
      )

    end
  end
end

local function addCube(x, y, z, height, kind)
  for level = 0, height - 1 do
    for sx = 0, 2 do
      for sy = 0, 2 do
        for sz = 0, 2 do
          tower[#tower + 1] = {
            x = x + sx / 3,
            y = y + sy / 3,
            z = z + level + sz / 3,
            ix = x * 3 + sx,
            iy = y * 3 + sy,
            iz = (z + level) * 3 + sz,
            size = 1 / 3,
            kind = kind or "mass",
            seed = love.math.random() * 1000,
            parentZ = z + level,
            subIndex = sx + sy * 3 + sz * 9
          }
          local cube = tower[#tower]
          cube.delay = love.math.noise(cube.seed, cube.z * 0.17) * 0.42
          cube.orbitRadius = 5.8 + (cube.z % 9) * 0.42 + love.math.noise(cube.seed, 4.1) * 3.8
          cube.orbitPhase = cube.seed * 0.021 + cube.z * 0.16
          cube.ringBias = math.sin(cube.z * 0.31 + cube.seed) * 0.9
          cube.coreSortBias = cube.kind == "core" and 0.18 or 0
        end
      end
    end
  end
end

local function addBlock(x0, y0, z0, width, depth, height, kind)
  for x = x0, x0 + width - 1 do
    for y = y0, y0 + depth - 1 do
      addCube(x, y, z0, height, kind)
    end
  end
end

local function voxelKey(ix, iy, iz)
  return ix .. ":" .. iy .. ":" .. iz
end

local function cullInteriorVoxels()
  local occupied = {}
  for _, cube in ipairs(tower) do
    occupied[voxelKey(cube.ix, cube.iy, cube.iz)] = true
  end

  local visible = {}
  for _, cube in ipairs(tower) do
    local ix, iy, iz = cube.ix, cube.iy, cube.iz
    local exposed =
      not occupied[voxelKey(ix + 1, iy, iz)] or
      not occupied[voxelKey(ix - 1, iy, iz)] or
      not occupied[voxelKey(ix, iy + 1, iz)] or
      not occupied[voxelKey(ix, iy - 1, iz)] or
      not occupied[voxelKey(ix, iy, iz + 1)] or
      not occupied[voxelKey(ix, iy, iz - 1)]

    if exposed then
      visible[#visible + 1] = cube
    end
  end

  tower = visible
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

  cullInteriorVoxels()

  table.sort(tower, function(a, b)
    local da = a.x + a.y + a.z * 0.08 + a.coreSortBias
    local db = b.x + b.y + b.z * 0.08 + b.coreSortBias
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

local function updateMouseSpin(dt)
  local x, y = love.mouse.getPosition()
  local distance = math.sqrt((x - mouseX) * (x - mouseX) + (y - mouseY) * (y - mouseY))
  mouseX, mouseY = x, y

  local instantSpeed = clamp(distance / math.max(dt, 0.001) / 2200, 0, 1)
  mouseSpeed = lerp(mouseSpeed, instantSpeed, 1 - math.exp(-dt * 5))
  spinTargetSpeed = 0.28 + mouseSpeed * 1.65
  spinSpeed = lerp(spinSpeed, spinTargetSpeed, 1 - math.exp(-dt * 4))
  spinPhase = spinPhase + spinSpeed * dt
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
  local phase = ring.phase - spinPhase * ring.speedScale
  local radius = baseSize * (ring.radius + humidity * ring.humidityScale + temperature * ring.temperatureScale)
  local rx = radius
  local ry = radius * ring.flatness
  local y = cy + radius * ring.drop
  local alpha = front and ring.frontAlpha or ring.backAlpha
  if flowAmount > 0.01 then
    alpha = alpha * 1.18
  end
  alpha = clamp(alpha, 0, 1)
  local start = front and 0 or math.pi
  local stop = front and math.pi or TAU
  local baseColor = ring.baseColor
  local accent = ring.accentColor

  drawArcSurface(
    cx,
    y,
    rx,
    ry,
    phase + ring.arcA[1],
    phase + ring.arcA[2],
    (ring.width + sound * ring.soundWidth) * 3.4,
    ring.height,
    baseColor,
    alpha,
    ring.segments,
    front
  )

  drawArcSurface(
    cx,
    y,
    rx * ring.accentScale,
    ry * ring.accentScale,
    phase + ring.arcB[1],
    phase + ring.arcB[2],
    math.max(2, ring.width * 2.4),
    ring.height * 0.78,
    accent,
    alpha,
    ring.segments,
    front
  )

  if ring.arcC then
    drawArcSurface(
      cx,
      y,
      rx * ring.thirdScale,
      ry * ring.thirdScale,
      phase + ring.arcC[1],
      phase + ring.arcC[2],
      math.max(2, ring.width * 1.7),
      ring.height * 0.62,
      ring.thirdColor,
      alpha,
      ring.segments,
      front
    )
  end

  lg.setLineWidth(1)
end

local function drawFunctionalRings(cx, originY, baseSize, temperature, humidity, sound, front)
  local rings = {
    {
      z = 2, radius = 8.0, width = 4.8, height = 18, ghostWidth = 1.8, soundWidth = 1.8,
      flatness = 0.24, drop = 0.08, speedScale = 1.0, soundSpeed = 0.35,
      phase = 0.1, humidityScale = 0.7, temperatureScale = 0.1,
      frontAlpha = 1, backAlpha = 1, ghostAlpha = 1, ghostScale = 1.08,
      baseColor = {0.08, 0.095, 0.1, 1}, accentColor = {0.0, 0.72, 0.78, 1},
      accentScale = 1.17, arcA = {0.2, 0.95}, arcB = {3.58, 4.4}, segments = 26
    },
    {
      z = 5, radius = 15, width = 2.2, height = 100, ghostWidth = 1.2, soundWidth = 0.8,
      flatness = 0.21, drop = 0.06, speedScale = 0.58, soundSpeed = 0.12,
      phase = 1.4, humidityScale = 0.25, temperatureScale = 0.2,
      frontAlpha = 1, backAlpha = 1, ghostAlpha = 1, ghostScale = 1.02,
      baseColor = {0.82, 0.84, 0.84, 1}, accentColor = {0.92, 0.08, 0.18, 1},
      accentScale = 1.08, arcA = {2.72, 3.48}, arcB = {5.0, 5.62}, segments = 24
    },
    {
      z = 12, radius = 9.2, width = 5.4, height = 22, ghostWidth = 1.6, soundWidth = 2.4,
      flatness = 0.25, drop = 0.085, speedScale = 1.28, soundSpeed = 0.55,
      phase = 2.2, humidityScale = 0.8, temperatureScale = 0.05,
      frontAlpha = 1, backAlpha = 1, ghostAlpha = 1, ghostScale = 1.12,
      baseColor = {0.05, 0.06, 0.065, 1}, accentColor = {0.0, 0.72, 0.78, 1},
      accentScale = 1.23, arcA = {0.1, 0.72}, arcB = {3.35, 4.28}, segments = 24,
      arcC = {5.05, 5.52}, thirdColor = {0.92, 0.08, 0.18, 1}, thirdScale = 1.32
    },
    {
      z = 16.0, radius = 6.9, width = 3.0, height = 13, ghostWidth = 1.3, soundWidth = 1.1,
      flatness = 0.22, drop = 0.07, speedScale = 0.82, soundSpeed = 0.25,
      phase = 0.8, humidityScale = 0.2, temperatureScale = 0.65,
      frontAlpha = 1, backAlpha = 1, ghostAlpha = 1, ghostScale = 1.14,
      baseColor = {0.92, 0.08, 0.18, 1}, accentColor = {0.08, 0.095, 0.1, 1},
      accentScale = 0.98, arcA = {5.05, 5.75}, arcB = {2.6, 3.28}, segments = 22
    },
    {
      z = 24.0, radius = 4.6, width = 2.0, height = 8, ghostWidth = 1.0, soundWidth = 0.6,
      flatness = 0.2, drop = 0.055, speedScale = 0.38, soundSpeed = 0.15,
      phase = 3.1, humidityScale = 0.18, temperatureScale = 0.32,
      frontAlpha = 1, backAlpha = 1, ghostAlpha = 1, ghostScale = 1.18,
      baseColor = {0.0, 0.72, 0.78, 1}, accentColor = {0.86, 0.88, 0.88, 1},
      accentScale = 0.92, arcA = {3.78, 4.56}, arcB = {0.18, 0.82}, segments = 20
    }
  }

  for _, ring in ipairs(rings) do
    drawFunctionalRing(cx, originY - baseSize * ring.z, baseSize, ring, temperature, humidity, sound, front)
  end
end

local function drawTower(w, h)
  local baseSize = math.min(w, h) * 0.033
  local cubeW = baseSize
  local cubeH = baseSize * 0.5
  local originX = w * 0.5
  local originY = h * 0.74
  local temperature = sensors.temperature
  local humidity = sensors.humidity
  local sound = sensors.sound
  local pulse = 0.5 + math.sin(elapsed * (3.5 + sound * 8)) * 0.5

  drawFunctionalRings(originX, originY, baseSize, temperature, humidity, sound, false)

  local useFlowSort = flowAmount > 0.002
  local renderCount = #tower
  if useFlowSort then
    for i = 1, renderCount do
      local cube = tower[i]
      local pull = smoothstep((flowAmount - cube.delay) / 0.58)
      local orbit = -spinPhase * 1.1 + cube.orbitPhase
      local targetX = math.cos(orbit) * cube.orbitRadius
      local targetY = math.sin(orbit) * cube.orbitRadius + cube.ringBias
      local targetZ = cube.z + math.sin(orbit * 1.4 + cube.seed) * 1.1
      local item = drawList[i]
      if not item then
        item = {}
        drawList[i] = item
      end
      item.cube = cube
      item.x = lerp(cube.x, targetX, pull)
      item.y = lerp(cube.y, targetY, pull)
      item.z = lerp(cube.z, targetZ, pull)
    end
    for i = renderCount + 1, #drawList do
      drawList[i] = nil
    end
    table.sort(drawList, function(a, b)
      return a.x + a.y + a.z * 0.08 + a.cube.coreSortBias < b.x + b.y + b.z * 0.08 + b.cube.coreSortBias
    end)
  end

  for i = 1, renderCount do
    local item = useFlowSort and drawList[i] or tower[i]
    local cube = item.cube
    if not cube then
      cube = item
    end
    local drawX = useFlowSort and item.x or cube.x
    local drawY = useFlowSort and item.y or cube.y
    local drawZ = useFlowSort and item.z or cube.z
    local tremor = math.sin(elapsed * 0.8 + cube.seed) * sound * baseSize * 0.025
    local grow = temperature * 0.08 + pulse * sound * 0.05
    local kindBoost = cube.kind == "spire" and 1.16 or cube.kind == "crown" and 1.07 or 1
    local flow = math.sin(elapsed * 0.48 + drawZ * 0.16 + (drawX - drawY) * 0.08) * 0.5 + 0.5
    local palette = getColorCyclePalette(drawX, drawY, drawZ, paletteScratch)
    local brightness = kindBoost * palette.brightness * (0.9 + cube.z * 0.006 + temperature * 0.02 + flow * (0.012 + flowAmount * 0.012))
    local alpha = 1
    local accent

    if cube.parentZ % 12 == 0 and cube.kind ~= "base" and cube.subIndex % 5 == 0 then
      accent = {0.92, 0.08, 0.18, 0.07 + temperature * 0.03}
    elseif math.floor((cube.x + cube.y + cube.z) * 3) % 17 == 0 then
      accent = {0.0, 0.72, 0.78, 0.05 + humidity * 0.025}
    end

    local px, py = isoProject(drawX, drawY, drawZ * (1 + grow * 0.035), cubeW, cubeH)
    drawCube(
      originX + px + tremor,
      originY + py - tremor * 0.4,
      baseSize * cube.size * (1.08 + grow * 0.025),
      temperature * 0.02,
      palette,
      brightness,
      alpha,
      accent
    )
  end

  drawFunctionalRings(originX, originY, baseSize, temperature, humidity, sound, true)
end

function love.load()
  love.math.setRandomSeed(os.time())
  lg.setDefaultFilter("linear", "linear")
  mouseX, mouseY = love.mouse.getPosition()
  buildTower()
end

function love.update(dt)
  dt = math.min(dt, 1 / 30)
  elapsed = elapsed + dt
  updateFlow(dt)
  updateMouseSpin(dt)
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
