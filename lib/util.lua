local M = {}
local math_max, math_min = math.max, math.min

function M.clamp(value, low, high)
  return math_max(low, math_min(high, value))
end

function M.lerp(a, b, t)
  return a + (b - a) * t
end

function M.smoothstep(x)
  local t = M.clamp(x, 0, 1)
  return t * t * (3 - 2 * t)
end

function M.normalizeSensor(value, minValue, maxValue)
  return M.clamp((value - minValue) / (maxValue - minValue), 0, 1)
end

function M.isoProject(x, y, z, cubeW, cubeH)
  return (x - y) * cubeW * 0.5, (x + y) * cubeH * 0.5 - z * cubeH
end

function M.shadeColor(color, factor, alpha)
  return color[1] * factor, color[2] * factor, color[3] * factor, alpha or color[4] or 1
end

function M.mixComponents(ar, ag, ab, aa, br, bg, bb, ba, t)
  return M.lerp(ar, br, t), M.lerp(ag, bg, t), M.lerp(ab, bb, t), M.lerp(aa, ba, t)
end

return M
