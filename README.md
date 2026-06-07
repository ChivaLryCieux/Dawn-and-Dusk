# Guiyang Bamboo Tower Visualizer

LOVE2D realtime projection sketch for a Guiyang bamboo-fungus-inspired tower made from cube modules.

The visual system is built from two basic geometric elements:

- 2D rectangles: rotating color blocks that form the surrounding spiral bands.
- 3D cubes: modular building units that transform between the tower, cube flow, and "Guiyang" text.

Current input mode uses `love.math.noise` to simulate three sensor channels:

- Temperature: red accent intensity, vertical deformation, upper ring scale
- Humidity: cyan translucency, glass-like face tint, lower ring scale
- Sound: structural tremor, broken-ring motion, functional band drift

Run:

```bash
love .
```

Controls:

- mouse click: cycle building -> cube flow -> Guiyang text -> cube flow -> building
- `space`: pause or resume simulated sensor input
- `r`: reseed the simulated input
- `f`: toggle fullscreen
- `escape`: quit

## Gesture Recognition

The system uses MediaPipe GestureRecognizer via a Python subprocess to perform real-time hand gesture recognition from the webcam. The camera feed, motion detection, and gesture results are all handled by a single Python process (`native/gesture_detector.py`), which writes results to a shared file that LÖVE reads each frame.

### Architecture

```
LÖVE main thread
  └─ love.thread → gesture_thread.lua
       └─ io.popen("python3 gesture_detector.py")
            └─ Python process (long-running)
                 ├── /tmp/blue_hours_hand.txt   gesture + motion + landmarks
                 └── /tmp/blue_hours_frame.bin  raw RGBA camera frame
                        ↓
                 LÖVE reads each frame via io.open + FFI
```

### Lua-Python Communication

Lua and Python communicate through **file IPC** — no sockets, no pipes, no shared memory.

**Why files:** `io.popen:read("*l")` would block the Lua thread. File-based polling is non-blocking and dead simple.

**Protocol:**

- `hand.txt` — plain text, 3+ lines: fist flag (`0`/`1`), gesture name, motion value, then one line per hand landmark (`index x y z`)
- `frame.bin` — binary: 12-byte header (`w:u32 h:u32 stride:u32`) followed by raw RGBA pixels

Python writes both files atomically via `os.replace(tmp, final)` — Lua never reads a half-written file.

**Lua side:** `gesture.update()` calls `io.open` to read the text file and parses it line by line. For the camera frame, it reads the binary file and uses `ffi.copy` to write pixels directly into a LÖVE `ImageData` pointer — zero conversion overhead, straight to GPU via `image:replacePixels()`.

### Supported Gestures

| Gesture | Action |
|---------|--------|
| ✊ Closed Fist | Cycle states (spiral → text → tower) |
| 👍 Thumbs Up | Jump to Guiyang text state |
| ✌️ Victory | Activate ASCII mode for 5 seconds |

In ASCII mode, the scene transitions to black background with colored ASCII characters. Ring panels use camera feed colors; tower cubes use inverted camera colors.

### Camera Motion

Hand movement speed is computed via frame differencing (grayscale, downsampled to 160×120). Motion magnitude drives the rotation speed of the surrounding spiral bands — move your hand faster to spin the rings faster.

### Setup

Run the setup script to create a Python venv with MediaPipe + OpenCV and download the gesture model:

```bash
# Linux / macOS
cd native && bash setup.sh

# Windows
cd native && setup.bat
```

This installs everything into `native/mpenv/` (git-ignored). Then run:

```bash
love .
```

When real sensor data is available, replace `updateSensors(dt)` in `main.lua` with serial, socket, or OSC input and keep the `sensors.temperature`, `sensors.humidity`, and `sensors.sound` fields normalized through `normalizeSensor`.

## Packaging (Windows)

The `LOVE/` folder contains the LÖVE 11.5 Windows runtime. To build a standalone .exe:

```bash
# Create .love archive
zip -r blue-hours.love main.lua conf.lua lib/ models/ render/ shaders/ \
  native/gesture_detector.py native/gesture_thread.lua native/models/ \
  native/setup.bat native/setup.sh

# Concatenate with LÖVE runtime → standalone .exe
cat LOVE/love.exe blue-hours.love > blue-hours.exe
```

Copy `blue-hours.exe` and all DLLs from `LOVE/` into a `dist/` folder.

### Gesture Recognition on Windows

The gesture system requires Python + MediaPipe. Users must run `native/setup.bat` once to create a venv and download the model. The game auto-detects `native/mpenv/` at runtime.

```
dist/
├── blue-hours.exe
├── *.dll
└── native/
    ├── setup.bat          ← run once to install
    ├── gesture_detector.py
    ├── gesture_thread.lua
    └── models/
        └── gesture_recognizer.task  ← downloaded by setup.bat
```
