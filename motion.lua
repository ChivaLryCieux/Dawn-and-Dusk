local util = require("util")

local M = {}

local states = {
  {flow = 0, text = 0},
  {flow = 1, text = 0},
  {flow = 0, text = 1},
  {flow = 1, text = 0}
}
local stateIndex = 1
local flowAmount = 0
local textAmount = 0
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
  local state = states[stateIndex]
  local flowSpeed = state.flow == 1 and 0.55 or 0.75
  local textSpeed = state.text == 1 and 0.58 or 0.72
  flowAmount = util.lerp(flowAmount, state.flow, 1 - math.exp(-flowSpeed * dt * 5))
  textAmount = util.lerp(textAmount, state.text, 1 - math.exp(-textSpeed * dt * 5))
  if math.abs(flowAmount - state.flow) < 0.001 then
    flowAmount = state.flow
  end
  if math.abs(textAmount - state.text) < 0.001 then
    textAmount = state.text
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

function M.advanceState()
  stateIndex = stateIndex % #states + 1
end

function M.toggleFlow()
  M.advanceState()
end

function M.flowAmount()
  return flowAmount
end

function M.textAmount()
  return textAmount
end

function M.spinPhase()
  return spinPhase
end

return M
