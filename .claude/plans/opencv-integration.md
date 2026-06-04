# Plan: OpenCV Camera Integration via LuaJIT FFI

## Context
The project uses LÖVE 11.5 (LuaJIT). The goal is to use LuaJIT FFI to call an OpenCV C wrapper DLL, capture webcam frames, and use the input to drive visual parameters.

## Prerequisites
- Install OpenCV dev libraries: `sudo apt install libopencv-dev`
- This provides `libopencv_videoio`, `libopencv_core`, `libopencv_imgproc` (OpenCV 4.6.0)

## Architecture

```
┌──────────────┐     FFI      ┌──────────────┐     C++ API    ┌──────────┐
│ lib/camera.lua│ ──────────→ │ native/       │ ─────────────→ │ OpenCV   │
│ (Lua FFI)    │              │ cv_wrap.cpp   │                │ 4.6.0    │
│              │ ←────────── │ (libcv_wrap.so)│ ←───────────── │          │
└──────────────┘   raw pixels └──────────────┘   cv::Mat       └──────────┘
       │
       ▼
  love.graphics.newImageData → love.graphics.newImage
```

## Files to Create

### 1. `native/cv_wrap.cpp` — C++ wrapper with extern "C" API
```c
extern "C" {
    void* cvw_open(int device_id);           // cv::VideoCapture
    int   cvw_read(void* cap, uint8_t** out, int* w, int* h, int* stride);
    void  cvw_free_frame(uint8_t* data);     // free copy
    void  cvw_close(void* cap);              // release capture
}
```
- `cvw_read` copies frame data to a malloc'd RGBA buffer (LÖVE-compatible)
- Converts BGR→RGBA internally via `cv::cvtColor`
- Returns 1 on success, 0 on failure

### 2. `native/build.sh` — compile script
```bash
g++ -shared -fPIC -O2 -o libcv_wrap.so cv_wrap.cpp \
  $(pkg-config --cflags --libs opencv4)
```

### 3. `lib/camera.lua` — Lua FFI module
- Loads `libcv_wrap.so` via `ffi.load()`
- Declares C function signatures
- Wraps `cvw_open/cvw_read/cvw_close` in a Lua module
- Converts raw RGBA buffer → LÖVE `ImageData` → `Image`
- Exposes: `camera.open()`, `camera.read() → Image|nil`, `camera.close()`

### 4. `main.lua` — integration
- `require("lib.camera")`
- In `love.load()`: `camera.open(0)`
- In `love.update()`: `camera.read()` → update texture
- Expose camera texture or derived data to visual system

## Files to Modify
- `main.lua` — add camera require, load, update, draw

## Build Steps
```bash
cd native
chmod +x build.sh
./build.sh   # produces libcv_wrap.so in project root
```

## Verification
1. `sudo apt install libopencv-dev` succeeds
2. `cd native && ./build.sh` compiles without errors
3. `love .` starts without crash, camera opens
4. Camera frame visible on screen (debug draw)
