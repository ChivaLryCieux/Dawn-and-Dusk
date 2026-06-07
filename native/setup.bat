@echo off
REM Setup Python venv for gesture recognition (Windows)
setlocal

set SCRIPT_DIR=%~dp0
set VENV_DIR=%SCRIPT_DIR%mpenv
set MODEL_DIR=%SCRIPT_DIR%models
set MODEL_FILE=%MODEL_DIR%\gesture_recognizer.task
set MODEL_URL=https://storage.googleapis.com/mediapipe-models/gesture_recognizer/gesture_recognizer/float16/1/gesture_recognizer.task

echo === Gesture Recognition Setup ===

REM Create venv
if not exist "%VENV_DIR%" (
    echo Creating Python venv...
    python -m venv "%VENV_DIR%"
)

REM Install dependencies
echo Installing MediaPipe + OpenCV...
"%VENV_DIR%\Scripts\pip.exe" install --upgrade pip -q
"%VENV_DIR%\Scripts\pip.exe" install mediapipe opencv-python-headless -q

REM Download model
if not exist "%MODEL_FILE%" (
    echo Downloading gesture recognition model...
    mkdir "%MODEL_DIR%" 2>nul
    powershell -Command "Invoke-WebRequest -Uri '%MODEL_URL%' -OutFile '%MODEL_FILE%'"
)

echo Done! Run the game to start.
pause
