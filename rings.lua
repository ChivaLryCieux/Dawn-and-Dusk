local util = require("util")

local M = {}
local TAU = math.pi * 2

local rings = {
  {
    z = 2, radius = 8.0, width = 4.8, height = 18, soundWidth = 1.8,
    flatness = 0.24, drop = 0.08, speedScale = 1.0,
    phase = 0.1, humidityScale = 0.7, temperatureScale = 0.1,
    frontAlpha = 1, backAlpha = 1,
    baseColor = {0.08, 0.095, 0.1, 1}, accentColor = {0.0, 0.72, 0.78, 1},
    accentScale = 1.17, arcA = {0.2, 0.95}, arcB = {3.58, 4.4}, segments = 26
  },
  {
    z = 5, radius = 15, width = 2.2, height = 100, soundWidth = 0.8,
    flatness = 0.21, drop = 0.06, speedScale = 0.58,
    phase = 1.4, humidityScale = 0.25, temperatureScale = 0.2,
    frontAlpha = 1, backAlpha = 1,
    baseColor = {0.82, 0.84, 0.84, 1}, accentColor = {0.92, 0.08, 0.18, 1},
    accentScale = 1.08, arcA = {2.72, 3.48}, arcB = {5.0, 5.62}, segments = 24
  },
  {
    z = 12, radius = 9.2, width = 5.4, height = 22, soundWidth = 2.4,
    flatness = 0.25, drop = 0.085, speedScale = 1.28,
    phase = 2.2, humidityScale = 0.8, temperatureScale = 0.05,
    frontAlpha = 1, backAlpha = 1,
    baseColor = {0.05, 0.06, 0.065, 1}, accentColor = {0.0, 0.72, 0.78, 1},
    accentScale = 1.23, arcA = {0.1, 0.72}, arcB = {3.35, 4.28}, segments = 24,
    arcC = {5.05, 5.52}, thirdColor = {0.92, 0.08, 0.18, 1}, thirdScale = 1.32
  },
  {
    z = 16.0, radius = 6.9, width = 3.0, height = 13, soundWidth = 1.1,
    flatness = 0.22, drop = 0.07, speedScale = 0.82,
    phase = 0.8, humidityScale = 0.2, temperatureScale = 0.65,
    frontAlpha = 1, backAlpha = 1,
    baseColor = {0.92, 0.08, 0.18, 1}, accentColor = {0.08, 0.095, 0.1, 1},
    accentScale = 0.98, arcA = {5.05, 5.75}, arcB = {2.6, 3.28}, segments = 22
  },
  {
    z = 24.0, radius = 4.6, width = 2.0, height = 8, soundWidth = 0.6,
    flatness = 0.2, drop = 0.055, speedScale = 0.38,
    phase = 3.1, humidityScale = 0.18, temperatureScale = 0.32,
    frontAlpha = 1, backAlpha = 1,
    baseColor = {0.0, 0.72, 0.78, 1}, accentColor = {0.86, 0.88, 0.88, 1},
    accentScale = 0.92, arcA = {3.78, 4.56}, arcB = {0.18, 0.82}, segments = 20
  }
}

local function isFrontAngle(angle)
  local t = angle % TAU
  return t >= 0 and t <= math.pi
end

local function drawArcSurface(cx, cy, rx, ry, a0, a1, height, color, alpha, segments, front)
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

      love.graphics.setColor(color[1] * shimmer, color[2] * shimmer, color[3] * shimmer, alpha * color[4])
      love.graphics.polygon(
        "fill",
        x0, y0 + topOffset,
        x1, y1 + topOffset,
        x1, y1 + bottomOffset,
        x0, y0 + bottomOffset
      )
    end
  end
end

local function drawRing(cx, cy, baseSize, ring, sensors, spinPhase, flowAmount, front)
  local phase = ring.phase - spinPhase * ring.speedScale
  local radius = baseSize * (ring.radius + sensors.humidity * ring.humidityScale + sensors.temperature * ring.temperatureScale)
  local rx = radius
  local ry = radius * ring.flatness
  local y = cy + radius * ring.drop
  local alpha = front and ring.frontAlpha or ring.backAlpha
  if flowAmount > 0.01 then
    alpha = alpha * 1.18
  end
  alpha = util.clamp(alpha, 0, 1)

  drawArcSurface(
    cx, y, rx, ry,
    phase + ring.arcA[1], phase + ring.arcA[2],
    ring.height, ring.baseColor, alpha, ring.segments, front
  )

  drawArcSurface(
    cx, y, rx * ring.accentScale, ry * ring.accentScale,
    phase + ring.arcB[1], phase + ring.arcB[2],
    ring.height * 0.78, ring.accentColor, alpha, ring.segments, front
  )

  if ring.arcC then
    drawArcSurface(
      cx, y, rx * ring.thirdScale, ry * ring.thirdScale,
      phase + ring.arcC[1], phase + ring.arcC[2],
      ring.height * 0.62, ring.thirdColor, alpha, ring.segments, front
    )
  end
end

function M.draw(cx, originY, baseSize, sensors, spinPhase, flowAmount, front)
  for _, ring in ipairs(rings) do
    drawRing(cx, originY - baseSize * ring.z, baseSize, ring, sensors, spinPhase, flowAmount, front)
  end
end

return M
