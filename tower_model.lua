local M = {}

local tower = {}

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

local function addRect(points, x0, y0, w, h)
  for y = y0, y0 + h - 1 do
    for x = x0, x0 + w - 1 do
      points[#points + 1] = {x = x, y = y}
    end
  end
end

local function addStroke(points, x0, y0, x1, y1, thickness)
  local steps = math.max(math.abs(x1 - x0), math.abs(y1 - y0))
  for i = 0, steps do
    local t = steps == 0 and 0 or i / steps
    local x = math.floor(x0 + (x1 - x0) * t + 0.5)
    local y = math.floor(y0 + (y1 - y0) * t + 0.5)
    addRect(points, x, y, thickness, thickness)
  end
end

local function buildGuiyangPoints()
  local points = {}

  addRect(points, 8, 3, 3, 11)
  addRect(points, 4, 4, 11, 2)
  addRect(points, 4, 4, 2, 8)
  addRect(points, 13, 4, 2, 8)
  addRect(points, 4, 10, 11, 2)
  addRect(points, 1, 13, 17, 2)
  addRect(points, 5, 16, 10, 2)
  addRect(points, 5, 16, 2, 8)
  addRect(points, 13, 16, 2, 8)
  addStroke(points, 9, 20, 5, 27, 2)
  addStroke(points, 9, 23, 14, 27, 2)

  local ox = 24
  addRect(points, ox + 0, 2, 3, 25)
  addRect(points, ox + 2, 2, 6, 2)
  addRect(points, ox + 6, 3, 2, 8)
  addRect(points, ox + 2, 10, 5, 2)
  addRect(points, ox + 5, 12, 2, 9)
  addRect(points, ox + 2, 20, 5, 2)
  addRect(points, ox + 9, 4, 10, 2)
  addRect(points, ox + 9, 4, 2, 20)
  addRect(points, ox + 17, 4, 2, 20)
  addRect(points, ox + 9, 13, 10, 2)
  addRect(points, ox + 9, 22, 10, 2)

  return points
end

local function assignTextTargets()
  local points = buildGuiyangPoints()
  local scaleX = 0.54
  local scaleZ = 0.64
  local layerDepth = 0.09
  local minX, maxX = points[1].x, points[1].x
  local minY, maxY = points[1].y, points[1].y

  for _, point in ipairs(points) do
    minX = math.min(minX, point.x)
    maxX = math.max(maxX, point.x)
    minY = math.min(minY, point.y)
    maxY = math.max(maxY, point.y)
  end

  local centerX = (minX + maxX) * 0.5
  local centerY = (minY + maxY) * 0.5
  local centerZ = 15.0

  for i, cube in ipairs(tower) do
    local point = points[((i - 1) % #points) + 1]
    local layer = math.floor((i - 1) / #points) % 7
    local jitterX = (love.math.noise(cube.seed, 12.1) - 0.5) * 0.06
    local jitterZ = (love.math.noise(19.7, cube.seed) - 0.5) * 0.06
    local x = (point.x - centerX) * scaleX + jitterX
    local z = (centerY - point.y) * scaleZ + centerZ + jitterZ

    cube.textX = x
    cube.textY = -x + (layer - 3) * layerDepth
    cube.textZ = z
    cube.textDelay = love.math.noise(cube.seed, 28.4) * 0.32
  end
end

function M.build()
  tower = {}

  local cornerAX, cornerAY = 2, 2
  local cornerBX, cornerBY = 2, -4
  local cornerCX, cornerCY = -4, 2
  local centerX, centerY = -2, -2
  local boxW, boxD = 4, 4
  local roomH = 6
  local highOffset, lowOffset, midOffset = 2, 0, 1
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
    return a.x + a.y + a.z * 0.08 + a.coreSortBias < b.x + b.y + b.z * 0.08 + b.coreSortBias
  end)
  assignTextTargets()

  return tower
end

return M
