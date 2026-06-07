-- gesture_thread.lua — runs in LÖVE thread, launches Python
local src = ...  -- passed as argument from main thread

local script = src .. "/native/gesture_detector.py"
local python

-- Detect OS: Windows uses backslashes in paths and different venv layout
local isWindows = package.config:sub(1, 1) == "\\"

-- 1. Try project-local venv
local venvPaths
if isWindows then
    venvPaths = {
        src .. "/native/mpenv/Scripts/python.exe",
        src .. "\\native\\mpenv\\Scripts\\python.exe",
    }
else
    venvPaths = {
        src .. "/native/mpenv/bin/python3",
    }
end

for _, path in ipairs(venvPaths) do
    local f = io.open(path, "r")
    if f then
        f:close()
        python = '"' .. path .. '"'
        break
    end
end

-- 2. Fallback to system python
if not python then
    python = isWindows and "python" or "python3.12"
end

local cmd = python .. " " .. script .. " 2>&1"

local pipe = io.popen(cmd, "r")
if not pipe then
    print("[gesture_thread] ERROR: io.popen failed for: " .. cmd)
    return
end

print("[gesture_thread] started: " .. cmd)

-- Read and print all output from Python (for debugging)
while true do
    local line = pipe:read("*l")
    if not line then break end
    print("[gesture] " .. line)
end

local ok, reason, code = pipe:close()
print("[gesture_thread] python exited: ok=" .. tostring(ok) .. " reason=" .. tostring(reason) .. " code=" .. tostring(code))
