local class = require "class"
local Object = require "Object"
local png = require "png"

local Point = require "kaku.Point"

local Image = class("Image", Object)

function Image:create(path, loadAlpha)
  local data = {}

  local function readLine(y, total, pixels)
    for i = 1, #pixels do
      local p = pixels[i]
      table.insert(data, (loadAlpha and p.A << 24 or 0) | p.R << 16 | p.G << 8 | p.B)
    end
  end

  local info = png(path, readLine, false, true)

  self._size = Point(info.width, info.height)
  self._data = data
end

Image:addReadonly("size")

local function posToIndex(self, x, y)
  return x + (y - 1) * self._size.x
end

function Image:getPixel(pos)
  return self._data[posToIndex(self, pos:unpack())]
end

function Image:getPixelXY(x, y)
  return self._data[posToIndex(self, x, y)]
end

function Image:setPixel(pos, color)
  self._data[posToIndex(self, pos:unpack())] = color
end

function Image:setPixelXY(x, y, color)
  self._data[posToIndex(self, x, y)] = color
end

return Image
