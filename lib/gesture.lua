-- gesture.lua — MediaPipe gesture + motion + camera via Python subprocess
local ffi = require("ffi")
local M = {}

local IS_WINDOWS = package.config:sub(1, 1) == "\\"
local TMP_DIR = os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
local SEP = IS_WINDOWS and "\\" or "/"
local SHARED_FILE = TMP_DIR .. SEP .. "blue_hours_hand.txt"
local FRAME_FILE = TMP_DIR .. SEP .. "blue_hours_frame.bin"
local STATUS_FILE = TMP_DIR .. SEP .. "blue_hours_status.txt"
local DIAG_FILE = TMP_DIR .. SEP .. "blue_hours_diag.txt"

local thread = nil
local lastFist = false
local fistEdge = false
local lastThumbUp = false
local thumbUpEdge = false
local landmarks = nil
local gestureName = "none"
local motionValue = 0
local cameraImage = nil
local cameraImageData = nil
local frameW, frameH = 0, 0

-- Python process status tracking (from blue_hours_status.txt)
local pyPhase = "unknown"   -- init | camera_ok | mediapipe_ok | running | camera_only | error
local pyMessage = ""        -- human-readable status / error detail
local pyLastTime = 0        -- the "time" field from the latest status file (unix seconds)
local pyLastSeen = 0        -- love.timer.getTime() at which we last saw a fresh status

ffi.cdef[[
typedef struct { unsigned int w, h, stride; } FrameHeader;
]]

function M.start()
    thread = love.thread.newThread("native/gesture_thread.lua")
    thread:start(love.filesystem.getSource())
end

function M.stop()
    -- Read PID from the file the Python subprocess writes on startup
    -- and kill it by PID.  More reliable than matching window titles.
    local pidFile = TMP_DIR .. SEP .. "blue_hours_pid.txt"
    local pid = nil
    local pf = io.open(pidFile, "r")
    if pf then
        local p = pf.read(pf, "*n")
        pf.close(pf)
        if p and p > 0 then pid = p end
    end

    if IS_WINDOWS then
        -- Kill by PID (pythonw.exe has no console window to match by title)
        if pid then
            os.execute('taskkill /F /PID ' .. tostring(pid) .. ' >nul 2>&1')
        end
        -- Also try process-name based kill as a safety net
        os.execute('taskkill /F /IM pythonw.exe /FI "WINDOWTITLE eq *gesture*" >nul 2>&1')
        os.execute('taskkill /F /IM python.exe /FI "WINDOWTITLE eq *gesture*" >nul 2>&1')
        -- Cleanup shared files
        os.execute('del /Q "' .. SHARED_FILE .. '" "' .. FRAME_FILE .. '" "' ..
                   (TMP_DIR .. SEP .. 'blue_hours_status.txt') .. '" "' ..
                   pidFile .. '" >nul 2>&1')
    else
        if pid then
            os.execute("kill -9 " .. tostring(pid) .. " 2>/dev/null")
        end
        os.execute("pkill -f gesture_detector.py 2>/dev/null")
        os.execute("rm -f " .. SHARED_FILE .. " " .. FRAME_FILE .. " " ..
                   TMP_DIR .. "/blue_hours_status.txt " .. pidFile)
    end
end

-- Strip non-ASCII bytes from strings read from external files. Python
-- subprocess output on Windows may use a system code page (e.g. GBK/CP936)
-- which is not valid UTF-8, and passing those to love.graphics.print /
-- love.timer / etc would trigger a decode error.
local function clean(s)
    if not s then return s end
    return (tostring(s):gsub("[\128-\255]", "?"))
end

function M.update()
    -- --- 1) Read Python STATUS file (heartbeat) ---
    local sf = io.open(STATUS_FILE, "r")
    if sf then
        local gotPhase, gotTime, gotMsg
        for line in sf:lines() do
            local k, v = line:match("^([%w_]+):%s*(.*)$")
            if k == "phase" then gotPhase = clean(v)
            elseif k == "time" then gotTime = tonumber(v)
            elseif k == "msg" then gotMsg = clean(v)
            end
        end
        sf:close()
        if gotPhase and gotTime and gotTime > pyLastTime then
            pyPhase = gotPhase
            pyLastTime = gotTime
            pyLastSeen = love.timer and love.timer.getTime() or 0
            if gotMsg and gotMsg ~= "" then pyMessage = gotMsg end
        elseif gotPhase then
            pyPhase = gotPhase
        end
    end

    -- --- 2) Read gesture data ---
    local f = io.open(SHARED_FILE, "r")
    if f then
        local line1 = f:read("*l")
        if line1 then
            local newFist = (line1 == "1")
            fistEdge = (newFist and not lastFist)
            lastFist = newFist

            local line2 = f:read("*l")
            gestureName = clean(line2) or "none"

            local newThumbUp = (gestureName == "Thumb_Up")
            thumbUpEdge = (newThumbUp and not lastThumbUp)
            lastThumbUp = newThumbUp

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

    -- --- 3) Read camera frame ---
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
function M.thumbUpJustRaised() return thumbUpEdge end
function M.hasHands() return landmarks ~= nil end
function M.getLandmarks() return landmarks end
function M.getGestureName() return gestureName end
function M.getMotion() return motionValue end
function M.getImage() return cameraImage end
function M.getImageData() return cameraImageData end
function M.getDimensions() return frameW, frameH end
function M.isThreadAlive() return thread ~= nil and thread:isRunning() end

-- Python process / frame freshness helpers
function M.getPhase() return pyPhase end
function M.getPhaseMessage() return pyMessage end
function M.getFrameAge()
    if love.timer and pyLastSeen > 0 then
        return love.timer.getTime() - pyLastSeen
    end
    return -1  -- never seen any status update
end
function M.isPythonAlive()
    local age = M.getFrameAge()
    return age >= 0 and age < 3.0
end
function M.hasFreshFrame()
    local age = M.getFrameAge()
    return age >= 0 and age < 1.5
end

-- Diagnostic file from gesture_thread.lua (shows python path probing, etc.)
function M.getDiagLines()
    local f = io.open(DIAG_FILE, "r")
    if not f then return nil end
    local lines = {}
    for ln in f:lines() do
        table.insert(lines, clean(ln))
    end
    f:close()
    return lines
end

return M
