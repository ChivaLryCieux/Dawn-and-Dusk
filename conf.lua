function love.conf(t)
  t.identity = "Lincheng"
  t.version = "11.5"
  t.window.title = "Lincheng"
  -- Fullscreen by default; falls back to windowed if display doesn't support it.
  t.window.fullscreen = true
  t.window.fullscreentype = "desktop"
  t.window.resizable = true
  t.window.highdpi = true
  t.window.usedpiscale = true
  t.modules.physics = false
end
