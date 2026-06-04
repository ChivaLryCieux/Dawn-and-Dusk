-- gesture_thread.lua — runs in LÖVE thread, launches Python
local src = ...  -- passed as argument from main thread

-- Find Python: bundled (Windows) → venv (Linux) → system
local python
local script = src .. "/native/gesture_detector.py"

-- Check for bundled Windows Python
local bundled = src .. "/python/3.12/python.exe"
local f = io.open(bundled, "r")
if f then
    f:close()
    python = '"' .. bundled .. '"'
else
    -- Check for Linux venv
    local venv = src .. "/native/mpenv/bin/python3"
    f = io.open(venv, "r")
    if f then
        f:close()
        python = venv
    else
        python = "python3.12"
    end
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
