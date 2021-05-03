local class = require "class"
local component = require "component"
local Object = require "Object"

local Point = require "kaku.Point"
local Rect = require "kaku.Rect"

local Pixler = class("Pixler", Object)

function Pixler:create(bounds, gpu)
  gpu = gpu or component.gpu
  self._bounds = bounds or Rect(Point(1), Point(gpu.getViewport()))
  self._gpu = gpu
end

Pixler:addReadonly("bounds")
Pixler:addReadonly("gpu")

local function toLine(y)
  local top = y & 1 ~= 0
  return (y + 1) >> 1, top
end

local function localToGlobal(self, x, y)
  local pos = self._bounds.pos
  return pos.x + x - 1, pos.y * 2 + y - 2
end

local function limitLowHigh(self, x1, y1, x2, y2)
  local c1, c2 = self._bounds:corners()
  local lx, ly = c1:unpack()
  local hx, hy = c2:unpack()
  return math.max(x1, lx), math.max(y1, ly * 2 - 1), math.min(x2, hx), math.min(y2, hy * 2)
end

local function getBothPixels(self, x, line)
  assert(self._bounds:containsXY(x, line), "pixel coordinates out of bounds")
  local gpu = self._gpu
  local char, fg, bg = gpu.get(x, line)
  if char == "▀" then
    return fg, bg
  else
    return bg, bg
  end
end

local function setPixel(self, x, y, color)
  local line, top = toLine(y)
  local topColor, bottomColor = getBothPixels(self, x, line)
  local fg = top and topColor or bottomColor
  if fg == color then
    return
  end
  local bg = top and bottomColor or topColor
  local gpu = self._gpu
  if bg == color then
    gpu.setBackground(color)
    gpu.set(x, line, " ")
  else
    gpu.setBackground(top and bg or color)
    gpu.setForeground(top and color or bg)
    gpu.set(x, line, "▀")
  end
end

local function drawRectFilled(self, x1, y1, x2, y2, brush)
  x1, y1, x2, y2 = limitLowHigh(self, x1, y1, x2, y2)
  if x1 > x2 or y1 > y2 then
    return
  end
  local line1, top1 = toLine(y1)
  local line2, top2 = toLine(y2)
  if not top1 then
    line1 = line1 + 1
  end
  if top2 then
    line2 = line2 - 1
  end

  if not top1 then
    for x = x1, x2 do
      setPixel(self, x, y1, brush)
    end
  end
  if line1 <= line2 then
    local gpu = self._gpu
    gpu.setBackground(brush)
    gpu.fill(x1, line1, x2 - x1 + 1, line2 - line1 + 1, " ")
  end
  if top2 then
    for x = x1, x2 do
      setPixel(self, x, y2, brush)
    end
  end
end

local function drawBars(self, x1, x2, y1, color1, y2, ...)
  x1, y1, x2, y2 = limitLowHigh(self, x1, y1, x2, y2)
  local line2, top2 = toLine(y2)
  local color2 = ...

  local y3 = y2
  if top2 and color2 then
    local gpu = self._gpu
    gpu.setForeground(color1)
    gpu.setBackground(color2)
    gpu.fill(x1, line2, x2 - x1 + 1, 1, "▀")
    y3 = y3 - 1
    y2 = y2 + 1
  end

  drawRectFilled(self, x1, y1, x2, y3, color1)

  if ... then
    return drawBars(self, x1, x2, y2 + 1, ...)
  end
end

local function drawRectOutlined(self, x1, y1, x2, y2, pen, tx1, ty1, tx2, ty2)
  local ix1 = x1 + tx1 - 1
  local ix2 = x2 - tx2 + 1
  local iy1 = y1 + ty1 - 1
  local iy2 = y2 - ty2 + 1
  drawRectFilled(self, x1, y1, ix1, y2, pen)
  drawRectFilled(self, ix2, y1, x2, y2, pen)
  drawRectFilled(self, ix1, y1, ix2, iy1, pen)
  drawRectFilled(self, ix1, iy2, ix2, y2, pen)
end

local function drawRectFilledOutlined(self, x1, y1, x2, y2, brush, pen, tx1, ty1, tx2, ty2)
  local ix1 = x1 + tx1 - 1
  local ix2 = x2 - tx2 + 1
  drawRectFilled(self, x1, y1, ix1, y2, pen)
  drawRectFilled(self, ix2, y1, x2, y2, pen)
  drawBars(self, ix1 + 1, ix2 - 1, y1, pen, y1 + ty1 - 1, brush, y2 - ty2, pen, y2)
end

local function drawLine(self, x1, y1, x2, y2, color)
  local c1, c2 = self._bounds:corners()
  local bx1, by1 = c1:unpack()
  local bx2, by2 = c2:unpack()
  by1 = by1 * 2 - 1
  by2 = by2 * 2

  local width = x2 - x1
  local height = y2 - y1
  if math.abs(width) >= math.abs(height) then
    if width < 0 then
      x1, y1, x2, y2 = x2, y2, x1, y1
      width = -width
      height = -height
    end
    if width == 0 then
      if x1 >= bx1 and x1 <= bx2 and y1 >= by1 and y1 <= by2 then
        setPixel(self, x1, y1, color)
      end
    else
      for x = math.max(x1, bx1), math.min(x2, bx2) do
        local y = y1 + ((x - x1) * height + (width >> 1)) // width
        if y >= by1 and y <= by2 then
          setPixel(self, x, y, color)
        end
      end
    end
  else
    if height < 0 then
      x1, y1, x2, y2 = x2, y2, x1, y1
      width = -width
      height = -height
    end
    if width == 0 then
      drawRectFilled(self, x1, y1, x1, y2, color)
    else
      local last_x, last_y = x1, y1
      for y = math.max(y1, by1), math.min(y2, by2) do
        local x = x1 + ((y - y1) * width + (height >> 1)) // height
        if x ~= last_x then
          drawRectFilled(self, last_x, last_y, last_x, y - 1, color)
          last_x = x
          last_y = y
        end
      end
      drawRectFilled(self, last_x, last_y, last_x, y2, color)
    end
  end
end

function Pixler:getPixel(pos)
  local x, y = localToGlobal(self, pos:unpack())
  local line, top = toLine(y)
  local topColor, bottomColor = getBothPixels(self, x, line)
  return top and topColor or bottomColor
end

function Pixler:setPixel(pos, color)
  local x, y = localToGlobal(self, pos:unpack())
  setPixel(self, x, y, color)
end

function Pixler:clear(color)
  color = color or 0x000000
  local gpu = self._gpu
  local pos, size = self._bounds:unpack()
  local x, y = pos:unpack()
  local w, h = size:unpack()
  gpu.setBackground(color)
  gpu.fill(x, y, w, h, " ")
end

function Pixler:drawRect(bounds, brush, pen, thickness1, thickness2)
  local pos1, pos2 = bounds:corners()
  local x1, y1 = localToGlobal(self, pos1:unpack())
  local x2, y2 = localToGlobal(self, pos2:unpack())

  if pen then
    local tx1, ty1, tx2, ty2 = 1, 1, 1, 1
    local t = tonumber(thickness1)
    if t then
      tx1, ty1, tx2, ty2 = t, t, t, t
    elseif thickness1 then
      tx1, ty1 = thickness1:unpack()
      thickness2 = thickness2 or thickness1
      tx2, ty2 = thickness2:unpack()
    end

    if brush then
      drawRectFilledOutlined(self, x1, y1, x2, y2, brush, pen, tx1, ty1, tx2, ty2)
    else
      drawRectOutlined(self, x1, y1, x2, y2, pen, tx1, ty1, tx2, ty2)
    end
  elseif brush then
    drawRectFilled(self, x1, y1, x2, y2, brush)
  end
end

function Pixler:drawBars(x1, x2, y1, color1, y2, ...)
  x1, y1 = localToGlobal(self, x1, y1)
  x2, y2 = localToGlobal(self, x2, y2)
  local function convert(color, y, ...)
    y = self._bounds.pos.y + y - 1
    if ... then
      return color, y, convert(...)
    else
      return color, y
    end
  end
  drawBars(self, x1, x2, y1, color1, y2, convert(...))
end

function Pixler:drawLine(pos1, pos2, color)
  local x1, y1 = localToGlobal(self, pos1:unpack())
  local x2, y2 = localToGlobal(self, pos2:unpack())
  drawLine(self, x1, y1, x2, y2, color)
end

function Pixler:drawImage(pos, image)
  local x1, y1 = localToGlobal(self, pos:unpack())
  local width, height = image.size:unpack()
  local bx1, by1, bx2, by2 = limitLowHigh(self, x1, y1, x1 + width - 1, y1 + height - 1)

  local first_y = by1
  local last_y = by2
  local gpu = self._gpu

  local y2 = y1 + height - 1
  local line1, top1 = toLine(y1)
  local line2, top2 = toLine(y2)

  if not top1 then
    first_y = by1 + 1
  end

  if top2 then
    last_y = by2 - 1
  end

  if not top1 and y1 >= by1 and y1 <= by2 then
    for x = bx1, bx2 do
      setPixel(self, x, y1, image:getPixelXY(x - x1 + 1, 1))
    end
  end

  for y = first_y, last_y, 2 do
    for x = bx1, bx2 do
      gpu.setForeground(image:getPixelXY(x - x1 + 1, y - y1 + 1))
      gpu.setBackground(image:getPixelXY(x - x1 + 1, y - y1 + 2))
      local line, top = toLine(y)
      gpu.set(x, line, "▀")
    end
  end

  if top2 and y2 >= by1 and y2 <= by2 then
    for x = bx1, bx2 do
      setPixel(self, x, y2, image:getPixelXY(x - x1 + 1, height))
    end
  end
end

return Pixler
