local util = require("util")
local palette = require("palette")

local M = {}

local ISO_YAW = -math.atan(0.5)
local drawList = {}
local paletteScratch = {
  dark = {0, 0, 0, 1},
  mid = {0, 0, 0, 1},
  top = {0, 0, 0, 1},
  brightness = 1
}

local function drawCube(cx, cy, size, lift, colors, brightness, alpha, accent)
  local hw = size * 0.5
  local hh = size * 0.27
  local h = size * (0.58 + lift)
  local lg = love.graphics

  lg.setColor(util.shadeColor(colors.dark, brightness * 0.88, alpha * 0.96))
  lg.polygon("fill", cx - hw, cy, cx, cy + hh, cx, cy + hh + h, cx - hw, cy + h)

  lg.setColor(util.shadeColor(colors.mid, brightness * 0.98, alpha * 0.94))
  lg.polygon("fill", cx + hw, cy, cx, cy + hh, cx, cy + hh + h, cx + hw, cy + h)

  lg.setColor(util.shadeColor(colors.top, brightness * 1.06, alpha))
  lg.polygon("fill", cx, cy - hh, cx + hw, cy, cx, cy + hh, cx - hw, cy)

  if accent then
    lg.setColor(accent[1], accent[2], accent[3], accent[4] * alpha)
    lg.polygon("fill", cx - hw * 0.72, cy - hh * 0.1, cx - hw * 0.2, cy + hh * 0.18, cx - hw * 0.2, cy + h * 0.18, cx - hw * 0.72, cy + h * 0.04)
  end
end

function M.draw(tower, elapsed, baseSize, originX, originY, sensors, flowAmount, textAmount, spinPhase, textYaw, textPitch)
  local cubeW = baseSize
  local cubeH = baseSize * 0.5
  local pulse = 0.5 + math.sin(elapsed * (3.5 + sensors.sound * 8)) * 0.5
  local useTransformSort = flowAmount > 0.002 or textAmount > 0.002
  local renderCount = #tower
  local yaw = (ISO_YAW + (textYaw or 0)) * util.smoothstep(textAmount)
  local pitch = (textPitch or 0) * util.smoothstep(textAmount)
  local cosYaw, sinYaw = math.cos(yaw), math.sin(yaw)
  local cosPitch, sinPitch = math.cos(pitch), math.sin(pitch)
  local textCenterZ = 15.0

  if useTransformSort then
    for i = 1, renderCount do
      local cube = tower[i]
      local pull = util.smoothstep((flowAmount - cube.delay) / 0.58)
      local textPull = util.smoothstep((textAmount - cube.textDelay) / 0.5)
      local orbit = -spinPhase * 1.1 + cube.orbitPhase
      local targetX = math.cos(orbit) * cube.orbitRadius
      local targetY = math.sin(orbit) * cube.orbitRadius + cube.ringBias
      local targetZ = cube.z + math.sin(orbit * 1.4 + cube.seed) * 1.1
      local flowX = util.lerp(cube.x, targetX, pull)
      local flowY = util.lerp(cube.y, targetY, pull)
      local flowZ = util.lerp(cube.z, targetZ, pull)
      local textX = cube.textX * cosYaw - cube.textY * sinYaw
      local textY = cube.textX * sinYaw + cube.textY * cosYaw
      local textZ = cube.textZ - textCenterZ
      local pitchedY = textY * cosPitch - textZ * sinPitch
      local pitchedZ = textY * sinPitch + textZ * cosPitch + textCenterZ
      local item = drawList[i]
      if not item then
        item = {}
        drawList[i] = item
      end
      item.cube = cube
      item.x = util.lerp(flowX, textX, textPull)
      item.y = util.lerp(flowY, pitchedY, textPull)
      item.z = util.lerp(flowZ, pitchedZ, textPull)
    end
    for i = renderCount + 1, #drawList do
      drawList[i] = nil
    end
    table.sort(drawList, function(a, b)
      return a.x + a.y + a.z * 0.08 + a.cube.coreSortBias < b.x + b.y + b.z * 0.08 + b.cube.coreSortBias
    end)
  end

  for i = 1, renderCount do
    local item = useTransformSort and drawList[i] or tower[i]
    local cube = item.cube or item
    local drawX = useTransformSort and item.x or cube.x
    local drawY = useTransformSort and item.y or cube.y
    local drawZ = useTransformSort and item.z or cube.z
    local tremor = math.sin(elapsed * 0.8 + cube.seed) * sensors.sound * baseSize * 0.025
    local grow = sensors.temperature * 0.08 + pulse * sensors.sound * 0.05
    local kindBoost = cube.kind == "spire" and 1.16 or cube.kind == "crown" and 1.07 or 1
    local flow = math.sin(elapsed * 0.48 + drawZ * 0.16 + (drawX - drawY) * 0.08) * 0.5 + 0.5
    local colors = palette.get(elapsed, drawX, drawY, drawZ, paletteScratch)
    local textBoost = textAmount * 0.18
    local brightness = kindBoost * colors.brightness * (0.9 + cube.z * 0.006 + sensors.temperature * 0.02 + textBoost + flow * (0.012 + flowAmount * 0.012))
    local accent

    if cube.parentZ % 12 == 0 and cube.kind ~= "base" and cube.subIndex % 5 == 0 then
      accent = {0.92, 0.08, 0.18, 0.07 + sensors.temperature * 0.03}
    elseif math.floor((cube.x + cube.y + cube.z) * 3) % 17 == 0 then
      accent = {0.0, 0.72, 0.78, 0.05 + sensors.humidity * 0.025}
    end

    local px, py = util.isoProject(drawX, drawY, drawZ * (1 + grow * 0.035), cubeW, cubeH)
    drawCube(
      originX + px + tremor,
      originY + py - tremor * 0.4,
      baseSize * cube.size * (1.08 + grow * 0.025 + textAmount * 0.28),
      sensors.temperature * 0.02,
      colors,
      brightness,
      1,
      accent
    )
  end
end

return M
