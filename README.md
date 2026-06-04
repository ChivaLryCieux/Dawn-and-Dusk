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
Python (OpenCV + MediaPipe)
  ├── /tmp/blue_hours_hand.txt   gesture + motion + hand landmarks
  └── /tmp/blue_hours_frame.bin  raw RGBA camera frame
         ↓
LÖVE (LuaJIT FFI) reads and renders
```

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

```bash
# Install OpenCV (C++ wrapper for camera + motion)
sudo apt install libopencv-dev

# Build the C++ wrapper
cd native && ./build.sh

# Install MediaPipe (Python venv)
cd native && python3.12 -m venv mpenv && mpenv/bin/pip install mediapipe

# Download gesture model
wget -O native/models/gesture_recognizer.task \
  https://storage.googleapis.com/mediapipe-models/gesture_recognizer/gesture_recognizer/float16/1/gesture_recognizer.task
```

Run:

```bash
love .
```

When real sensor data is available, replace `updateSensors(dt)` in `main.lua` with serial, socket, or OSC input and keep the `sensors.temperature`, `sensors.humidity`, and `sensors.sound` fields normalized through `normalizeSensor`.
