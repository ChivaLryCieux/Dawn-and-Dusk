-- gesture_thread.lua — runs in LÖVE thread, launches Python detector subprocess.
-- Diagnostics are written to blue_hours_diag.txt so the main thread can show
-- them on screen even if the LOVE console is hidden.

local src = ...  -- passed as argument from main thread

-- Detect OS
local isWindows = package.config:sub(1, 1) == "\\"
local sep = isWindows and "\\" or "/"

-- Cross-platform temp dir (same one Python uses)
local tmpDir = os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or (isWindows and "C:\\Windows\\Temp" or "/tmp")
local DIAG_FILE = tmpDir .. sep .. "blue_hours_diag.txt"

-- Strip non-ASCII bytes from strings (e.g. python subprocess output on
-- Windows with a non-UTF-8 code page) to avoid "Invalid UTF-8" errors
-- when the main thread reads this file and passes text to LOVE.
local function clean(s)
    if not s then return s end
    return (tostring(s):gsub("[\128-\255]", "?"))
end

-- -- -- Diagnostic writer (ring buffer: only last MAX_DIAG_LINES so we
-- don't grow memory unbounded while python runs the main loop) -- -- --
local MAX_DIAG_LINES = 40
local diagLines = {}
local function d(...)
    local args = {...}
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = clean(args[i])
    end
    local line = table.concat(parts, " ")
    if #diagLines >= MAX_DIAG_LINES then
        table.remove(diagLines, 1)
    end
    table.insert(diagLines, line)
end
local function flushDiag()
    local f = io.open(DIAG_FILE, "w")
    if not f then return end
    for _, ln in ipairs(diagLines) do
        f:write(ln, "\n")
    end
    f:close()
end

d("=== gesture_thread start ===")
d("os:", isWindows and "windows" or "unix")
d("src:", tostring(src))
flushDiag()

-- Build script path
local script
if isWindows then
    script = src .. "\\native\\gesture_detector.py"
else
    script = src .. "/native/gesture_detector.py"
end

local function fileExists(path)
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end

-- 1. Try project-local venv first
local python
if isWindows then
    local candidates = {
        src .. "\\native\\mpenv\\Scripts\\python.exe",
        src .. "/native/mpenv/Scripts/python.exe",
    }
    for _, p in ipairs(candidates) do
        d("try_venv:", p, "->", fileExists(p) and "OK" or "missing")
        if fileExists(p) then
            python = '"' .. p .. '"'
            break
        end
    end
else
    local candidates = {
        src .. "/native/mpenv/bin/python3",
        src .. "/native/mpenv/bin/python",
    }
    for _, p in ipairs(candidates) do
        d("try_venv:", p, "->", fileExists(p) and "OK" or "missing")
        if fileExists(p) then
            python = '"' .. p .. '"'
            break
        end
    end
end

-- 2. Fallback to system python / python3
if not python then
    local candidates = isWindows
        and {"python", "py -3", "python3"}
        or  {"python3", "python3.12", "python"}

    for _, c in ipairs(candidates) do
        d("try_system:", c)
        local probe = io.popen(c .. (isWindows and " --version 2>&1" or " --version 2>&1"))
        if probe then
            local out = probe:read("*l")
            local ok2, reason2, code2 = probe:close()
            if ok2 and out then
                python = c
                d("  system python found:", out)
                break
            else
                d("  -> failed (code=" .. tostring(code2) .. ")")
            end
        end
    end
end

if not python then
    d("FATAL: no python interpreter found")
    d("Please run native/setup.bat (Windows) or native/setup.sh (Linux/Mac)")
    flushDiag()
    return
end

d("script_path:", script, "exists=", fileExists(script) and "yes" or "NO")
flushDiag()

-- Build final command — force UTF-8 output and unbuffered I/O so Lua can
-- reliably read lines even on non-ASCII Windows locales.  On Windows we
-- deliberately do NOT use "cmd /c" because io.popen on Windows already wraps
-- with cmd.exe internally; double-wrapping breaks stderr redirection and
-- quoting.
local cmd
if isWindows then
    cmd = 'set PYTHONIOENCODING=utf-8 & set PYTHONUNBUFFERED=1 & ' .. python .. ' -u "' .. script .. '" 2>&1'
else
    cmd = 'PYTHONIOENCODING=utf-8 PYTHONUNBUFFERED=1 ' .. python .. ' -u "' .. script .. '" 2>&1'
end

d("launch_cmd:", cmd)
flushDiag()

local pipe = io.popen(cmd, "r")
if not pipe then
    d("FATAL: io.popen() returned nil (command failed to launch)")
    flushDiag()
    return
end

d("python subprocess running, streaming output...")
flushDiag()

local outputCount = 0
while true do
    local line = pipe:read("*l")
    if not line then break end
    d("[py]", line)
    outputCount = outputCount + 1
    if outputCount % 5 == 0 then flushDiag() end
end

local ok, reason, code = pipe:close()
d("=== python exited ===")
d("  ok=", tostring(ok), "reason=", tostring(reason), "code=", tostring(code))
flushDiag()
