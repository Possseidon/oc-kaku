local class = require "class"
local component = require "component"
local Object = require "Object"

local boxchars = require "kaku.resources.boxchars"

local Box = class("Box", Object)

function Box:create(horizontalDefaultStyle, verticalDefaultStyle)
  self._pixels = {}
  self.horizontalDefaultStyle = horizontalDefaultStyle or "light"
  self.verticalDefaultStyle = verticalDefaultStyle or horizontalDefaultStyle or "light"
end

local function coordsToIndex(x, y)
  return x | (y << 32)
end

local function indexToCoords(index)
  return index & (~0 >> 32), index >> 32
end

local function pixelToChar(pixel)
  local a = pixel and boxchars[pixel[1]]
  local b = a and a[pixel[2]]
  local c = b and b[pixel[3]]
  return c and c[pixel[4]]
end

function Box:addPixel(x, y, left, right, up, down)
  local pixels = self._pixels
  local index = coordsToIndex(x, y)
  local pixel = pixels[index]
  if pixel then
    pixel[1] = left or pixel[1]
    pixel[2] = right or pixel[2]
    pixel[3] = up or pixel[3]
    pixel[4] = down or pixel[4]
  else
    pixel = {
      left or "none",
      right or "none",
      up or "none",
      down or "none"
    }
    pixels[index] = pixel
  end
end

function Box:addHorizontal(y, x1, x2, style)
  if x1 >= x2 then
    return
  end
  assert(y >= 1, "y must be at least 1")
  assert(x1 >= 1, "x1 must be at least 1")
  assert(x2 >= 1, "x2 must be at least 1")
  style = style or self.horizontalDefaultStyle
  self:addPixel(x1, y, nil, style, nil, nil)
  for x = x1 + 1, x2 - 1 do
    self:addPixel(x, y, style, style, nil, nil)
  end
  self:addPixel(x2, y, style, nil, nil, nil)
end

function Box:addVertical(x, y1, y2, style)
  if y1 >= y2 then
    return
  end
  assert(x >= 1, "x must be at least 1")
  assert(y1 >= 1, "y1 must be at least 1")
  assert(y2 >= 1, "y2 must be at least 1")
  style = style or self.verticalDefaultStyle
  self:addPixel(x, y1, nil, nil, nil, style)
  for y = y1 + 1, y2 - 1 do
    self:addPixel(x, y, nil, nil, style, style)
  end
  self:addPixel(x, y2, nil, nil, style, nil)
end

function Box:addBox(bounds, style)
  local pos1, pos2 = bounds:corners()
  local x1, y1 = pos1:unpack()
  local x2, y2 = pos2:unpack()
  self:addHorizontal(y1, x1, x2, style)
  self:addHorizontal(y2, x1, x2, style)
  self:addVertical(x1, y1, y2, style)
  self:addVertical(x2, y1, y2, style)
end

function Box:draw(pos, gpu)
  local dx, dy = 0, 0
  if pos then
    dx, dy = pos:unpack()
    dx, dy = dx - 1, dy - 1
  end
  gpu = gpu or component.gpu
  local drawn = {}
  local pixels = self._pixels
  for index, pixel in pairs(pixels) do
    if not drawn[index] then

      local function fixPixel(pattern, style)
        for i = 1, 4 do
          if pixel[i] and pixel[i]:match(pattern) then
            pixel[i] = style
          end
        end
        return pixelToChar(pixel)
      end

      assert(pixelToChar(pixel)
        or fixPixel("^light[2-4]$", "light")
        or fixPixel("^heavy[2-4]$", "heavy")
        or fixPixel("^arc$", "light"),
        "invalid style [" .. table.concat(pixel, "|") .. "]")

      local x, y = indexToCoords(index)
      local x1, x2 = x, x
      local y1, y2 = y, y
      local char = pixelToChar(pixel)
      while pixelToChar(pixels[coordsToIndex(x1 - 1, y)]) == char do
        x1 = x1 - 1
      end
      while pixelToChar(pixels[coordsToIndex(x2 + 1, y)]) == char do
        x2 = x2 + 1
      end
      while pixelToChar(pixels[coordsToIndex(x, y1 - 1)]) == char do
        y1 = y1 - 1
      end
      while pixelToChar(pixels[coordsToIndex(x, y2 + 1)]) == char do
        y2 = y2 + 1
      end
      if x2 - x1 > y2 - y1 then
        gpu.fill(dx + x1, dy + y, x2 - x1 + 1, 1, char)
        for ix = x1, x2 do
          drawn[coordsToIndex(ix, y)] = true
        end
      elseif y2 - y1 ~= 0 then
        gpu.fill(dx + x, dy + y1, 1, y2 - y1 + 1, char)
        for iy = y1, y2 do
          drawn[coordsToIndex(x, iy)] = true
        end
      else
        gpu.set(dx + x, dy + y, char)
        drawn[index] = true
      end
    end
  end
end

return Box
