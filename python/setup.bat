@echo off
setlocal enabledelayedexpansion

echo ============================================
echo  Blue Hours - Python Environment Setup
echo ============================================
echo.

set PYTHON_VER=3.12.10
set PYTHON_DIR=%~dp0%PYTHON_VER%
set PYTHON_ZIP=python-%PYTHON_VER%-embed-amd64.zip
set PYTHON_URL=https://www.python.org/ftp/python/%PYTHON_VER%/%PYTHON_ZIP%

REM Check if already installed
if exist "%PYTHON_DIR%\python.exe" (
    echo Python already installed at %PYTHON_DIR%
    goto :install_deps
)

echo [1/4] Downloading Python %PYTHON_VER%...
powershell -Command "Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%~dp0%PYTHON_ZIP%'"
if errorlevel 1 (
    echo ERROR: Download failed. Check your internet connection.
    pause
    exit /b 1
)

echo [2/4] Extracting...
powershell -Command "Expand-Archive -Path '%~dp0%PYTHON_ZIP%' -DestinationPath '%PYTHON_DIR%' -Force"
del "%~dp0%PYTHON_ZIP%"

REM Enable site-packages (comment out the disable line)
echo [3/4] Configuring Python...
for %%f in ("%PYTHON_DIR%\python*._pth") do (
    powershell -Command "(Get-Content '%%f') -replace '#import site','import site' | Set-Content '%%f'"
)

REM Install pip
echo [4/4] Installing pip...
powershell -Command "Invoke-WebRequest -Uri 'https://bootstrap.pypa.io/get-pip.py' -OutFile '%PYTHON_DIR%\get-pip.py'"
"%PYTHON_DIR%\python.exe" "%PYTHON_DIR%\get-pip.py" --no-warn-script-location
del "%PYTHON_DIR%\get-pip.py"

:install_deps
echo.
echo [5/5] Installing mediapipe (this may take a few minutes)...
"%PYTHON_DIR%\python.exe" -m pip install mediapipe --no-warn-script-location
if errorlevel 1 (
    echo ERROR: Failed to install mediapipe.
    pause
    exit /b 1
)

echo.
echo ============================================
echo  Setup complete!
echo  Python: %PYTHON_DIR%\python.exe
echo ============================================
pause
