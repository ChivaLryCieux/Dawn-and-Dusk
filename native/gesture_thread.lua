-- gesture_thread.lua — runs in LÖVE thread, launches Python detector subprocess.
-- Python writes all diagnostics / data to files (blue_hours_*.txt/.bin) so we
-- do NOT need to pipe its stdout back to Lua.  On Windows we use CreateProcessW
-- with CREATE_NO_WINDOW to avoid spawning a visible cmd.exe / console window.
-- On Linux io.popen is fine because it doesn't create visible windows.

local rawSrc = ...  -- passed as argument from main thread (love.filesystem.getSource())

-- Detect OS
local isWindows = package.config:sub(1, 1) == "\\"
local sep = isWindows and "\\" or "/"

-- love.filesystem.getSource() can return either a directory path (love .)
-- or the .exe file path (fused build).  We always want the directory.
local function toDir(p)
    if not p then return "." end
    p = tostring(p)
    -- If it points to an existing file (not a directory), strip the filename
    local asDir = p:gsub("[/\\]+$", "")
    local f = io.open(p, "rb")
    if f then
        -- It's a file path, not a directory — strip the last component
        f.close(f)
        asDir = p:match("^(.*)[/\\][^/\\]*$") or "."
    end
    return asDir
end

local src = toDir(rawSrc)

-- Cross-platform temp dir
local tmpDir = os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or (isWindows and "C:\\Windows\\Temp" or "/tmp")
local DIAG_FILE = tmpDir .. sep .. "blue_hours_diag.txt"

-- Ring-buffer diagnostic writer (writes to a file, no pipe needed)
local MAX_DIAG_LINES = 40
local diagLines = {}
local function d(...)
    local args = {...}
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(args[i])
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
        f.write(f, ln, "\n")
    end
    f.close(f)
end

d("=== gesture_thread start ===")
d("os:", isWindows and "windows" or "unix")
d("raw_src:", tostring(rawSrc))
d("resolved_src:", tostring(src))
flushDiag()

-- Build script path
local script = isWindows and (src .. "\\native\\gesture_detector.py") or (src .. "/native/gesture_detector.py")

local function fileExists(path)
    local f = io.open(path, "rb")
    if f then f.close(f); return true end
    return false
end

-- ---------------------------------------------------------------------------
-- 1) Find the Python interpreter.  On Windows we prefer pythonw.exe
--    (GUI-subsystem Python, no console) because it doesn't need a console
--    and won't accidentally create a visible window.  We fall back to
--    python.exe if pythonw isn't found (e.g. Linux venv with only python3).
-- ---------------------------------------------------------------------------
local python = nil
if isWindows then
    local candidates = {
        src .. "\\native\\mpenv\\Scripts\\pythonw.exe",
        src .. "/native/mpenv/Scripts/pythonw.exe",
        src .. "\\native\\mpenv\\Scripts\\python.exe",
        src .. "/native/mpenv/Scripts/python.exe",
    }
    for _, p in ipairs(candidates) do
        d("try_venv:", p, "->", fileExists(p) and "OK" or "missing")
        if fileExists(p) then
            python = p
            break
        end
    end
    -- Fall back to system pythonw / python
    if not python then
        for _, c in ipairs({"pythonw", "python"}) do
            local probe = io.popen("where " .. c .. " 2>nul", "r")
            if probe then
                local out = probe.read(probe, "*l")
                probe.close(probe)
                if out and out ~= "" then
                    python = out
                    d("system python found:", out)
                    break
                end
            end
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
            python = p
            break
        end
    end
    if not python then
        for _, c in ipairs({"python3", "python3.12", "python"}) do
            local probe = io.popen(c .. " --version 2>&1", "r")
            if probe then
                local out = probe.read(probe, "*l")
                probe.close(probe)
                if out then
                    python = c
                    d("system python found:", out)
                    break
                end
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

-- ---------------------------------------------------------------------------
-- 2) Launch the Python subprocess.
--    Windows: use FFI CreateProcessW(CREATE_NO_WINDOW) -> zero visible windows
--    Linux:   use io.popen to launch (no visible windows on Linux)
-- ---------------------------------------------------------------------------
local pythonExited = false
if isWindows then
    -- ------- Windows: CreateProcessW with CREATE_NO_WINDOW -------
    local ffi = require("ffi")
    ffi.cdef[[
        typedef int BOOL;
        typedef unsigned long DWORD;
        typedef void *HANDLE;
        typedef struct _PROCESS_INFORMATION {
            HANDLE hProcess;
            HANDLE hThread;
            DWORD dwProcessId;
            DWORD dwThreadId;
        } PROCESS_INFORMATION;
        typedef struct _STARTUPINFOW {
            DWORD cb;
            wchar_t *lpReserved;
            wchar_t *lpDesktop;
            wchar_t *lpTitle;
            DWORD dwX;
            DWORD dwY;
            DWORD dwXSize;
            DWORD dwYSize;
            DWORD dwXCountChars;
            DWORD dwYCountChars;
            DWORD dwFillAttribute;
            DWORD dwFlags;
            unsigned short wShowWindow;
            unsigned short cbReserved2;
            unsigned short *lpReserved2;
            HANDLE hStdInput;
            HANDLE hStdOutput;
            HANDLE hStdError;
        } STARTUPINFOW;
        BOOL CreateProcessW(
            const wchar_t *lpApplicationName,
            wchar_t *lpCommandLine,
            void *lpProcessAttributes,
            void *lpThreadAttributes,
            BOOL bInheritHandles,
            DWORD dwCreationFlags,
            void *lpEnvironment,
            const wchar_t *lpCurrentDirectory,
            STARTUPINFOW *lpStartupInfo,
            PROCESS_INFORMATION *lpProcessInformation
        );
        DWORD WaitForSingleObject(HANDLE hHandle, DWORD dwMilliseconds);
        BOOL GetExitCodeProcess(HANDLE hProcess, DWORD *lpExitCode);
        BOOL CloseHandle(HANDLE hObject);
    ]]

    -- Build command line: "pythonw.exe" -u "script.py"
    -- Need to convert to wide-character string for CreateProcessW
    local function toWchar(s)
        local n = #s + 1
        local w = ffi.new("wchar_t[?]", n)
        for i = 1, #s do
            local b = s:byte(i)
            w[i - 1] = b
        end
        w[#s] = 0
        return w
    end

    local cmdLine = '"' .. python .. '" -u "' .. script .. '"'
    d("launch_cmd:", cmdLine)
    d("flags: CREATE_NO_WINDOW")
    flushDiag()

    local CREATE_NO_WINDOW = 0x08000000
    local INFINITE = 0xFFFFFFFF

    local si = ffi.new("STARTUPINFOW")
    si.cb = ffi.sizeof("STARTUPINFOW")
    local pi = ffi.new("PROCESS_INFORMATION")

    local cmdW = toWchar(cmdLine)
    local okFFI = ffi.C.CreateProcessW(
        nil, cmdW, nil, nil, 0, CREATE_NO_WINDOW, nil, nil, si, pi
    )

    if okFFI == 0 then
        d("FATAL: CreateProcessW failed (could not launch python)")
        flushDiag()
        return
    end

    d("python launched, pid=" .. tostring(tonumber(pi.dwProcessId)))
    d("process running (thread will sleep and check status)")
    flushDiag()

    -- Wait for process to exit (blocks this thread until Python ends)
    ffi.C.WaitForSingleObject(pi.hProcess, INFINITE)
    pythonExited = true
    d("=== python exited ===")

    -- Cleanup handles
    ffi.C.CloseHandle(pi.hProcess)
    ffi.C.CloseHandle(pi.hThread)
    flushDiag()
else
    -- ------- Linux: io.popen (no visible windows on Linux) -------
    local cmd = python .. ' -u "' .. script .. '" 2>&1'
    d("launch_cmd:", cmd)
    flushDiag()

    local pipe = io.popen(cmd, "r")
    if not pipe then
        d("FATAL: io.popen returned nil")
        flushDiag()
        return
    end

    d("python subprocess running")
    flushDiag()

    while true do
        local line = pipe.read(pipe, "*l")
        if not line then break end
        d("[py]", line)
        flushDiag()
    end

    pipe.close(pipe)
    pythonExited = true
    d("=== python exited ===")
    flushDiag()
end
