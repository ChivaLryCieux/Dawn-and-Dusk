# Guiyang Bamboo Tower Visualizer

LOVE2D realtime projection sketch for a Guiyang bamboo-fungus-inspired tower made from cube modules.

Current input mode uses `love.math.noise` to simulate three sensor channels:

- Temperature: acid color heat, vertical deformation, halo intensity
- Humidity: mist density, drip length, background diffusion
- Sound: pulse size, glitch rings, cube tremor

Run:

```bash
love .
```

Controls:

- `space`: pause or resume simulated sensor input
- `r`: reseed the simulated input
- `f`: toggle fullscreen
- `escape`: quit

When real sensor data is available, replace `updateSensors(dt)` in `main.lua` with serial, socket, or OSC input and keep the `sensors.temperature`, `sensors.humidity`, and `sensors.sound` fields normalized through `normalizeSensor`.
