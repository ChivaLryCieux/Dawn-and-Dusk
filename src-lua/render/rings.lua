local math_sin, math_cos, math_sqrt, math_floor, math_abs = math.sin, math.cos, math.sqrt, math.floor, math.abs
local math_pi = math.pi
local util = require("lib.util")

local M = {}
local TAU = math_pi * 2

local palette = {
  blue = {0.0, 0.04, 0.95, 1},
  deepBlue = {0.0, 0.02, 0.46, 1},
  cyan = {0.0, 0.78, 0.88, 1},
  yellow = {1.0, 0.9, 0.02, 1},
  black = {0.02, 0.025, 0.026, 1},
  graphite = {0.28, 0.3, 0.3, 1},
  silver = {0.78, 0.8, 0.8, 1},
  white = {0.97, 0.98, 0.96, 1},
  pale = {0.78, 0.8, 1.0, 0.72},
  pink = {1.0, 0.62, 0.86, 0.62}
}

local streams = {
  {
    radius = 13.4, width = 0.9, z0 = -3.2, z1 = 34.0, turns = 1.22,
    phase = 0.18, speed = 0.86, flatness = 0.235, direction = 1
  },
  {
    radius = 15.2, width = 0.42, z0 = -4.5, z1 = 35.4, turns = 1.15,
    phase = 0.74, speed = 0.62, flatness = 0.22, direction = 1
  },
  {
    radius = 11.4, width = 0.62, z0 = -1.5, z1 = 31.0, turns = 1.32,
    phase = 2.45, speed = 1.08, flatness = 0.255, direction = -1
  },
  {
    radius = 16.5, width = 0.52, z0 = -5.6, z1 = 29.8, turns = 1.05,
    phase = 3.1, speed = 0.48, flatness = 0.2, direction = -1
  },
  {
    radius = 9.3, width = 0.28, z0 = 2.8, z1 = 28.0, turns = 1.52,
    phase = 5.15, speed = 1.36, flatness = 0.28, direction = 1
  },
  {
    radius = 12.6, width = 0.34, z0 = -5.0, z1 = 32.5, turns = 1.72,
    phase = 4.2, speed = 1.52, flatness = 0.245, direction = -1
  },
  {
    radius = 17.7, width = 0.32, z0 = -7.2, z1 = 27.5, turns = 0.98,
    phase = 1.92, speed = 0.74, flatness = 0.19, direction = 1
  }
}

local blockColors = {
  palette.blue,
  palette.white,
  palette.silver,
  palette.graphite,
  palette.yellow,
  palette.cyan,
  palette.black,
  palette.pale,
  palette.pink
}

local function isFrontAngle(angle)
  local t = angle % TAU
  return t >= 0 and t <= math_pi
end

local function setColor(color, shade)
  love.graphics.setColor(
    color[1] * shade,
    color[2] * shade,
    color[3] * shade,
    1
  )
end

local function helixPoint(cx, originY, baseSize, stream, phase, u, radiusOffset, textAmount)
  local sway = math_sin(u * math_pi * 3.0 + stream.phase) * 0.46
  local textClearance = util.smoothstep(textAmount or 0) * 5.4
  local radius = baseSize * (stream.radius + textClearance + radiusOffset + sway * 0.14)
  local angle = phase + stream.direction * (u * stream.turns * TAU)
  local z = stream.z0 + (stream.z1 - stream.z0) * u
  local x = cx + math_cos(angle) * radius
  local y = originY - baseSize * z + math_sin(angle) * radius * stream.flatness
  return x, y, angle
end

local function drawPanel(cx, originY, baseSize, stream, phase, index, sensors, flowAmount, front, textAmount, asciiFn, blend)
  local group = math_floor(index / 3)
  local u = ((index * 0.137 + stream.phase * 0.07 + flowAmount * 0.08) % 1)
  local span = 0.018 + (index % 5) * 0.006 + sensors.sound * 0.012
  local u0 = util.clamp(u - span * 0.5, 0, 1)
  local u1 = util.clamp(u + span * 0.5, 0, 1)
  local side = ((index % 4) - 1.5) * (0.58 + sensors.humidity * 0.4)
  local x0, y0, a0 = helixPoint(cx, originY, baseSize, stream, phase, u0, side, textAmount)
  local x1, y1, a1 = helixPoint(cx, originY, baseSize, stream, phase, u1, side, textAmount)
  local midAngle = (a0 + a1) * 0.5

  if isFrontAngle(midAngle) ~= front then
    return
  end

  local dx, dy = x1 - x0, y1 - y0
  local length = math_sqrt(dx * dx + dy * dy)
  if length < 0.001 then
    return
  end

  local nx, ny = -dy / length, dx / length
  local panelWidth = baseSize * (0.5 + (index % 4) * 0.2 + sensors.temperature * 0.24)
  local jitter = math_sin(index * 7.13 + phase * 1.7) * sensors.sound * baseSize * 0.42
  local color = blockColors[(group % #blockColors) + 1]
  local shade = 0.84 + math_sin(midAngle) * 0.12

  if asciiFn and blend > ((index * 137 % 1000) / 1000) then
    local midX = (x0 + x1) * 0.5 + jitter
    local midY = (y0 + y1) * 0.5
    local ch, cr, cg, cb = asciiFn(midX, midY)
    if ch then
      love.graphics.setColor(cr, cg, cb, 1)
      love.graphics.print(ch, midX - 6, midY - 10, 0, 1.2, 1.2)
    end
    return
  end

  setColor(color, shade)
  love.graphics.polygon(
    "fill",
    x0 + nx * panelWidth + jitter, y0 + ny * panelWidth,
    x1 + nx * panelWidth + jitter, y1 + ny * panelWidth,
    x1 - nx * panelWidth * 0.35 + jitter, y1 - ny * panelWidth * 0.35,
    x0 - nx * panelWidth * 0.35 + jitter, y0 - ny * panelWidth * 0.35
  )
end

local function drawStream(cx, originY, baseSize, stream, sensors, spinPhase, flowAmount, front, textAmount, asciiFn, blend)
  local phase = stream.phase - spinPhase * stream.speed

  local panelCount = 42 + math_floor(flowAmount * 22)
  for i = 1, panelCount do
    drawPanel(cx, originY, baseSize, stream, phase, i, sensors, flowAmount, front, textAmount, asciiFn, blend)
  end
end

function M.draw(cx, originY, baseSize, sensors, spinPhase, flowAmount, front, textAmount, asciiFn, blend)
  love.graphics.setBlendMode("alpha")
  local shiftedOriginY = originY + baseSize * 3.2

  for _, stream in ipairs(streams) do
    drawStream(cx, shiftedOriginY, baseSize, stream, sensors, spinPhase, flowAmount, front, textAmount, asciiFn, blend)
  end
end

return M
