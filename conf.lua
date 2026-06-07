function love.conf(t)
  t.identity = "guiyang-bamboo-tower-visualizer"
  t.version = "11.5"
  t.window.title = "Guiyang Bamboo Tower Visualizer"
  -- Use a conservative default that fits on most laptops; main.lua will
  -- auto-scale to ~85% of the actual desktop size at startup.
  t.window.width = 1280
  t.window.height = 720
  t.window.resizable = true
  t.window.minwidth = 800
  t.window.minheight = 600
  t.window.highdpi = true
  t.window.usedpiscale = true
  t.modules.physics = false
end
