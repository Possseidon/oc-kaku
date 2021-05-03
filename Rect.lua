local class = require "class"
local Object = require "Object"

local Point = require "kaku.Point"

local Rect = class("Rect", Object)

function Rect:create(pos, size)
  self._pos = pos
  self._size = size
end

Rect:addReadonly("pos")
Rect:addReadonly("size")

function Rect.metatable:__tostring()
  return ("Rect(%s, %s)"):format(self._pos, self._size)
end

function Rect:corners()
  local pos = self._pos
  return pos, pos + self._size - Point(1)
end

function Rect:unpack()
  return self._pos, self._size
end

function Rect:containsXY(x, y)
  local c1, c2 = self:corners()
  local x1, y1 = c1:unpack()
  local x2, y2 = c2:unpack()
  return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

function Rect:contains(pos)
  return self:containsXY(pos:unpack())
end

return Rect
