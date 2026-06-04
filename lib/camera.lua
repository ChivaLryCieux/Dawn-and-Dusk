-- camera.lua — OpenCV camera capture via LuaJIT FFI
local ffi = require("ffi")

ffi.cdef[[
typedef unsigned char uint8_t;

void* cvw_open(int device_id);
int   cvw_read(void* handle, uint8_t** out_data, int* out_w, int* out_h, int* out_stride);
void  cvw_free_frame(uint8_t* data);
float cvw_motion(void* handle);
void  cvw_close(void* handle);
]]

-- Resolve library path relative to project root
local lib_path
if love and love.filesystem then
    local src = love.filesystem.getSource()
    if src then
        lib_path = src .. "/libcv_wrap.so"
    end
end
if not lib_path then
    lib_path = "./libcv_wrap.so"
end

local ok, cv = pcall(ffi.load, lib_path)
if not ok then
    -- Fallback: try absolute path from debug info
    local info = debug.getinfo(1, "S")
    local src = info.source:match("^@(.+)$") or ""
    local abs_dir = src:match("^(/.+/)[^/]+$")
    if abs_dir then
        ok, cv = pcall(ffi.load, abs_dir .. "../libcv_wrap.so")
    end
end
if not ok then
    error("Cannot load libcv_wrap.so — run: cd native && ./build.sh\n  " .. tostring(cv))
end
if not ok then
    error("Cannot load libcv_wrap.so — run: cd native && ./build.sh\n  " .. tostring(cv))
end

local M = {}

local handle = nil
local frameData = nil
local image = nil
local imageData = nil
local currentW, currentH = 0, 0

-- Output parameters for cvw_read
local out_data = ffi.new("uint8_t*[1]")
local out_w = ffi.new("int[1]")
local out_h = ffi.new("int[1]")
local out_stride = ffi.new("int[1]")

function M.open(device_id)
    device_id = device_id or 0
    handle = cv.cvw_open(device_id)
    if handle == nil then
        error("Failed to open camera device " .. device_id)
    end
    return true
end

function M.read()
    if handle == nil then return nil end

    local ok = cv.cvw_read(handle, out_data, out_w, out_h, out_stride)
    if ok == 0 then return nil end

    local w = out_w[0]
    local h = out_h[0]

    -- Reallocate ImageData if dimensions changed
    if w ~= currentW or h ~= currentH then
        imageData = love.image.newImageData(w, h)
        image = love.graphics.newImage(imageData)
        image:setFilter("linear", "linear")
        currentW, currentH = w, h
    end

    -- Copy RGBA pixels into LÖVE ImageData
    local idPtr = ffi.cast("uint8_t*", imageData:getPointer())
    local srcPtr = out_data[0]
    local srcStride = out_stride[0]
    local dstStride = w * 4

    for y = 0, h - 1 do
        ffi.copy(idPtr + y * dstStride, srcPtr + y * srcStride, dstStride)
    end

    -- Free the buffer allocated by cvw_read
    cv.cvw_free_frame(out_data[0])

    -- Upload pixels to GPU texture
    image:replacePixels(imageData)

    return image
end

function M.getImage()
    return image
end

function M.getDimensions()
    return currentW, currentH
end

function M.close()
    if handle ~= nil then
        cv.cvw_close(handle)
        handle = nil
    end
    frameData = nil
    image = nil
    imageData = nil
    currentW, currentH = 0, 0
end

function M.isOpen()
    return handle ~= nil
end

function M.motion()
    if handle == nil then return 0 end
    local m = cv.cvw_motion(handle)
    if m < 0 then return 0 end
    return tonumber(m)
end

return M
