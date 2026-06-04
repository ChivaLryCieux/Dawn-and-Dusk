-- gesture_thread.lua — runs in LÖVE thread, launches Python
local src = ...  -- passed as argument from main thread

-- Try venv python first, then system
local python = src .. "/native/mpenv/bin/python3"
local f = io.open(python, "r")
if f then
    f:close()
else
    python = "python3.12"
end

local script = src .. "/native/gesture_detector.py"
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
