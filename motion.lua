local util = require("util")

local M = {}

local flowTarget = false
local flowAmount = 0
local mouseX = 0
local mouseY = 0
local mouseSpeed = 0
local spinPhase = 0
local spinSpeed = 0.28
local spinTargetSpeed = 0.28

function M.load()
  mouseX, mouseY = love.mouse.getPosition()
end

function M.update(dt)
  local target = flowTarget and 1 or 0
  local speed = flowTarget and 0.55 or 0.75
  flowAmount = util.lerp(flowAmount, target, 1 - math.exp(-speed * dt * 5))
  if math.abs(flowAmount - target) < 0.001 then
    flowAmount = target
  end

  local x, y = love.mouse.getPosition()
  local distance = math.sqrt((x - mouseX) * (x - mouseX) + (y - mouseY) * (y - mouseY))
  mouseX, mouseY = x, y

  local instantSpeed = util.clamp(distance / math.max(dt, 0.001) / 2200, 0, 1)
  mouseSpeed = util.lerp(mouseSpeed, instantSpeed, 1 - math.exp(-dt * 5))
  spinTargetSpeed = 0.28 + mouseSpeed * 1.65
  spinSpeed = util.lerp(spinSpeed, spinTargetSpeed, 1 - math.exp(-dt * 4))
  spinPhase = spinPhase + spinSpeed * dt
end

function M.toggleFlow()
  flowTarget = not flowTarget
end

function M.flowAmount()
  return flowAmount
end

function M.spinPhase()
  return spinPhase
end

return M
