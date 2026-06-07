local util = require("lib.util")

local M = {}

local states = {
  {name = "spiral", flow = 1, text = 0},
  {name = "text",   flow = 0, text = 1},
  {name = "tower",  flow = 0, text = 0},
}

local currentIndex = 1
local flowAmount = 0
local textAmount = 0

local function current()
  return states[currentIndex]
end

function M.advance()
  currentIndex = currentIndex % #states + 1
end

function M.setState(index)
  if index >= 1 and index <= #states then
    currentIndex = index
  end
end

function M.update(dt)
  local state = current()
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
end

function M.flowAmount()
  return flowAmount
end

function M.textAmount()
  return textAmount
end

function M.stateName()
  return current().name
end

function M.stateIndex()
  return currentIndex
end

return M
