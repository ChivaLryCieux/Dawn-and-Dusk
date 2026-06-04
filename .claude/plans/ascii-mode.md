# Plan: ASCII Mode triggered by Victory gesture

## Context
After a Victory (✌️) gesture, enter a 5-second ASCII visual mode where:
- Ring panels draw as colored ASCII characters with camera feed colors
- Tower/text cubes draw as colored ASCII characters with inverted camera colors
- Background remains dark

## Architecture

### ASCII Grid (pre-computed per frame in main.lua)
- Grid: ~120×67 cells (for 1920×1080, cell size 16×16)
- Sample camera ImageData at each cell center via FFI `getPointer` + pixel math
- Map grayscale brightness to ASCII density: `".,:-=+*#%@"`
- Store char + color in 2D arrays: `asciiChars[y][x]`, `asciiR/G/B[y][x]`
- Helper: `getAsciiAt(screenX, screenY)` → `char, r, g, b`

### State (main.lua)
- `asciiMode = false`, `asciiTimer = 0`
- On Victory gesture: set `asciiMode = true`, `asciiTimer = 5.0`
- In `love.update`: countdown timer, deactivate at 0
- Pass `asciiMode` + `getAsciiAt` to renderers

### Rings (`render/rings.lua`)
- `drawPanel` gets optional `asciiFn` parameter
- If `asciiFn` is set: call `asciiFn(midX, midY)` for panel center, draw 3 chars wide with `love.graphics.print`
- Skip normal polygon drawing

### Building (`render/building_renderer.lua`)
- `drawCube` gets optional `asciiFn` parameter
- If `asciiFn` is set: call `asciiFn(cx, cy)` for cube center, draw single char
- Invert the sampled RGB: `1-r, 1-g, 1-b`
- Skip normal polygon drawing

### Performance
- FFI pixel access: `ffi.cast("uint8_t*", imageData:getPointer())` + stride math
- Pre-compute grid once per frame, not per-element
- `getAsciiAt` is just array lookup + table return

## Files to Modify
1. `main.lua` — ASCII state, grid computation, pass to renderers
2. `render/rings.lua` — ASCII branch in drawPanel/drawStream
3. `render/building_renderer.lua` — ASCII branch in drawCube

## Verification
1. Show ✌️ to camera → ASCII mode activates for 5 seconds
2. Ring panels appear as colored ASCII characters from camera feed
3. Tower cubes appear as inverted-color ASCII characters
4. After 5 seconds, normal rendering resumes
5. Can re-trigger by showing ✌️ again
