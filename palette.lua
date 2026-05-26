local util = require("util")

local M = {}

function M.get(elapsed, x, y, z, out)
  local segmentDuration = 10
  local cycle = (elapsed % (segmentDuration * 4)) / segmentDuration
  local segment = math.floor(cycle)
  local localT = util.smoothstep(cycle - segment)
  local tiltedAxis = x * 0.062 - y * 0.034 + z * 0.021
  local crossFlow = x * 0.018 + y * 0.026 - z * 0.006
  local sweep = util.clamp(0.48 + tiltedAxis + math.sin(elapsed * 0.12 + crossFlow) * 0.16, 0, 1)
  local band = util.smoothstep(sweep)
  local rybR, rybG, rybB, rybA

  if band < 0.82 then
    local t = util.smoothstep(band / 0.82)
    rybR, rybG, rybB, rybA = util.mixComponents(0.82, 0.05, 0.08, 0.92, 1, 0.76, 0.08, 0.92, t)
  else
    local t = util.smoothstep((band - 0.82) / 0.18)
    rybR, rybG, rybB, rybA = util.mixComponents(1, 0.76, 0.08, 0.92, 0.08, 0.2, 0.68, 0.92, t)
  end

  local blueLift = util.smoothstep(util.clamp(0.12 + x * 0.014 - y * 0.008 + z * 0.004, 0, 1))
  local blueR, blueG, blueB, blueA = util.mixComponents(0.02, 0.26, 0.52, 0.94, 0, 0.52, 0.76, 0.95, blueLift)
  local r, g, b, a

  if segment == 0 then
    r, g, b, a = util.mixComponents(0.015, 0.018, 0.02, 0.94, rybR, rybG, rybB, rybA, localT)
  elseif segment == 1 then
    r, g, b, a = util.mixComponents(rybR, rybG, rybB, rybA, blueR, blueG, blueB, blueA, localT)
  elseif segment == 2 then
    r, g, b, a = util.mixComponents(blueR, blueG, blueB, blueA, 0.015, 0.018, 0.02, 0.94, localT)
  else
    r, g, b, a = 0.015, 0.018, 0.02, 0.94
  end

  out.dark[1], out.dark[2], out.dark[3], out.dark[4] = r * 0.7, g * 0.76, b * 0.82, a
  out.mid[1], out.mid[2], out.mid[3], out.mid[4] = r * 0.88, g * 0.94, b, a
  out.top[1], out.top[2], out.top[3], out.top[4] = math.min(r * 1.16, 1), math.min(g * 1.16, 1), math.min(b * 1.18, 1), a
  out.brightness = 0.9 + band * 0.1
  return out
end

return M
