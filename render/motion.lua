local util = require("lib.util")
local sm = require("lib.state_machine")

local M = {}

local mouseX = 0
local mouseY = 0
local mouseSpeed = 0
local spinPhase = 0
local spinSpeed = 0.28
local spinTargetSpeed = 0.28
local textYaw = 0
local textPitch = 0

function M.load()
  mouseX, mouseY = love.mouse.getPosition()
end

function M.update(dt)
  sm.update(dt)

  local x, y = love.mouse.getPosition()
  local distance = math.sqrt((x - mouseX) * (x - mouseX) + (y - mouseY) * (y - mouseY))
  mouseX, mouseY = x, y

  local instantSpeed = util.clamp(distance / math.max(dt, 0.001) / 2200, 0, 1)
  mouseSpeed = util.lerp(mouseSpeed, instantSpeed, 1 - math.exp(-dt * 5))
  spinTargetSpeed = 0.28 + mouseSpeed * 1.65
  spinSpeed = util.lerp(spinSpeed, spinTargetSpeed, 1 - math.exp(-dt * 4))
  spinPhase = spinPhase + spinSpeed * dt

  local w, h = love.graphics.getDimensions()
  local targetYaw = util.clamp((x / w - 0.5) * 1.25, -0.72, 0.72)
  local verticalLook = 0.5 - y / h
  local targetPitch
  if verticalLook > 0 then
    targetPitch = util.clamp(verticalLook * 1.25, 0, 0.62)
  else
    targetPitch = util.clamp(verticalLook * 0.55, -0.28, 0)
  end
  local lookResponse = 1 - math.exp(-dt * 6)
  textYaw = util.lerp(textYaw, targetYaw, lookResponse)
  textPitch = util.lerp(textPitch, targetPitch, lookResponse)
end

function M.advanceState()
  sm.advance()
end

function M.flowAmount()
  return sm.flowAmount()
end

function M.textAmount()
  return sm.textAmount()
end

function M.spinPhase()
  return spinPhase
end

function M.textLook()
  return textYaw, textPitch
end

return M
