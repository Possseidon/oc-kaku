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

function Rect:clampXY(x, y)
  local c1, c2 = self:corners()
  local x1, y1 = c1:unpack()
  local x2, y2 = c2:unpack()
  return math.min(math.max(x, x1), x2), math.min(math.max(y, y1), y2)
end

function Rect:clamp(pos)
  return Point(self:clampXY(pos:unpack()))
end

function Rect:encloses(other)
  local c1, c2 = other:corners()
  return self:contains(c1) and self:contains(c2)
end

function Rect:overlaps(other)
  local s1, s2 = self:corners()
  local c1, c2 = other:corners()
  return c1.x <= s2.x and c2.x >= s1.x and c1.y <= s2.y and c2.y >= s1.y
end

function Rect:clip(other)
  local s1, s2 = self:corners()
  local c1, c2 = other:corners()
  local r1 = Point(math.max(s1.x, c1.x), math.max(s1.y, c1.y))
  local r2 = Point(math.min(s2.x, c2.x), math.min(s2.y, c2.y))
  return Rect(r1, r2 - r1 + Point(1))
end

function Rect:inset(amount)
  return Rect(self._pos + amount, self._size - amount - amount)
end

function Rect.metatable:__add(offset)
  return Rect(self._pos + offset, self._size)
end

function Rect.metatable:__sub(offset)
  return Rect(self._pos - offset, self._size)
end

function Rect.metatable.__eq(a, b)
  return a._pos == b._pos and a._size == b._size
end

return Rect
