# Guiyang Bamboo Tower Visualizer

LOVE2D realtime projection sketch for a Guiyang bamboo-fungus-inspired tower made from cube modules.

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

When real sensor data is available, replace `updateSensors(dt)` in `main.lua` with serial, socket, or OSC input and keep the `sensors.temperature`, `sensors.humidity`, and `sensors.sound` fields normalized through `normalizeSensor`.
