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

  return tower
end

return M
