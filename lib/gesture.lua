-- gesture.lua — MediaPipe gesture + motion + camera via Python subprocess
local ffi = require("ffi")
local M = {}

local SHARED_FILE = "/tmp/blue_hours_hand.txt"
local FRAME_FILE = "/tmp/blue_hours_frame.bin"
local thread = nil
local lastFist = false
local fistEdge = false
local landmarks = nil
local gestureName = "none"
local motionValue = 0
local cameraImage = nil
local cameraImageData = nil
local frameW, frameH = 0, 0

ffi.cdef[[
typedef struct { unsigned int w, h, stride; } FrameHeader;
]]

function M.start()
    thread = love.thread.newThread("native/gesture_thread.lua")
    thread:start(love.filesystem.getSource())
end

function M.stop()
    os.execute("pkill -f gesture_detector.py 2>/dev/null")
    os.execute("rm -f " .. SHARED_FILE .. " " .. FRAME_FILE)
end

function M.update()
    -- Read gesture data
    local f = io.open(SHARED_FILE, "r")
    if f then
        local line1 = f:read("*l")
        if line1 then
            local newFist = (line1 == "1")
            fistEdge = (newFist and not lastFist)
            lastFist = newFist

            local line2 = f:read("*l")
            gestureName = line2 or "none"

            local line3 = f:read("*l")
            motionValue = tonumber(line3) or 0

            local lm = {}
            while true do
                local line = f:read("*l")
                if not line then break end
                local idx, x, y, z = line:match("^(%d+) ([%d%.%-]+) ([%d%.%-]+) ([%d%.%-]+)$")
                if idx then
                    lm[tonumber(idx) + 1] = {x = tonumber(x), y = tonumber(y), z = tonumber(z)}
                end
            end
            landmarks = #lm > 0 and lm or nil
        end
        f:close()
    end

    -- Read camera frame
    local ff = io.open(FRAME_FILE, "rb")
    if ff then
        local header = ff:read(12)
        if header and #header == 12 then
            local w, h, stride = ffi.cast("FrameHeader*", header).w, ffi.cast("FrameHeader*", header).h, ffi.cast("FrameHeader*", header).stride
            local pixelData = ff:read(w * h * 4)
            ff:close()

            if pixelData and #pixelData == w * h * 4 then
                if w ~= frameW or h ~= frameH then
                    cameraImageData = love.image.newImageData(w, h)
                    cameraImage = love.graphics.newImage(cameraImageData)
                    cameraImage:setFilter("linear", "linear")
                    frameW, frameH = w, h
                end
                ffi.copy(ffi.cast("uint8_t*", cameraImageData:getPointer()), pixelData, w * h * 4)
                cameraImage:replacePixels(cameraImageData)
            end
        else
            ff:close()
        end
    end
end

function M.isFist() return lastFist end
function M.fistJustClosed() return fistEdge end
function M.hasHands() return landmarks ~= nil end
function M.getLandmarks() return landmarks end
function M.getGestureName() return gestureName end
function M.getMotion() return motionValue end
function M.getImage() return cameraImage end
function M.getImageData() return cameraImageData end
function M.getDimensions() return frameW, frameH end
function M.isThreadAlive() return thread ~= nil and thread:isRunning() end

return M
