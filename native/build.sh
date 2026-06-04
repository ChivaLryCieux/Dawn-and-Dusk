#!/bin/bash
# Build libcv_wrap.so — OpenCV camera wrapper for LuaJIT FFI
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Compiling cv_wrap.cpp..."
g++ -shared -fPIC -O2 -std=c++17 \
    -o "$OUT_DIR/libcv_wrap.so" \
    "$SCRIPT_DIR/cv_wrap.cpp" \
    $(pkg-config --cflags --libs opencv4 2>/dev/null || pkg-config --cflags --libs opencv) \
    -lopencv_videoio -lopencv_core -lopencv_imgproc

echo "Done → $OUT_DIR/libcv_wrap.so"
