#!/usr/bin/env bash
# Setup Python venv for gesture recognition (Linux/macOS)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/mpenv"
MODEL_DIR="$SCRIPT_DIR/models"
MODEL_FILE="$MODEL_DIR/gesture_recognizer.task"
MODEL_URL="https://storage.googleapis.com/mediapipe-models/gesture_recognizer/gesture_recognizer/float16/1/gesture_recognizer.task"

echo "=== Gesture Recognition Setup ==="

# Create venv
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating Python venv..."
    python3.12 -m venv "$VENV_DIR" 2>/dev/null || python3 -m venv "$VENV_DIR"
fi

# Install dependencies
echo "Installing MediaPipe + OpenCV..."
"$VENV_DIR/bin/pip" install --upgrade pip -q
"$VENV_DIR/bin/pip" install mediapipe opencv-python-headless -q

# Download model
if [ ! -f "$MODEL_FILE" ]; then
    echo "Downloading gesture recognition model..."
    mkdir -p "$MODEL_DIR"
    wget -q --show-progress -O "$MODEL_FILE" "$MODEL_URL"
fi

echo "Done! Run 'love .' from the project root to start."
