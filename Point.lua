local class = require "class"
local Object = require "Object"

local Point = class("Point", Object)

local sqrt = math.sqrt

function Point:create(x, y)
  self._x = x or 0
  self._y = y or x or 0
end

Point:addReadonly("x")
Point:addReadonly("y")

function Point.metatable:__tostring()
  return ("Point(%s, %s)"):format(self._x, self._y)
end

function Point.metatable.__add(a, b)
  return Point(a._x + b._x, a._y + b._y)
end

function Point.metatable.__sub(a, b)
  return Point(a._x - b._x, a._y - b._y)
end

function Point.metatable.__mul(a, b)
  return Point(a._x * b._x, a._y * b._y)
end

function Point.metatable.__div(a, b)
  return Point(a._x / b._x, a._y / b._y)
end

function Point.metatable.__idiv(a, b)
  return Point(a._x // b._x, a._y // b._y)
end

function Point.metatable:__len()
  local x, y = self._x, self._y
  return sqrt(x * x + y * y)
end

function Point.metatable:__unm()
  return Point(-self._x, -self._y)
end

function Point.metatable.__eq(a, b)
  return a._x == b._x and a._y == b._y
end

function Point.metatable.__lt(a, b)
  return a._x < b._x or a._x == b._x and a._y < b._y
end

function Point.metatable.__le(a, b)
  return a._x < b._x or a._x == b._x and a._y <= b._y
end

function Point.dot(a, b)
  return a._x * b._x + a._y * b._y
end

function Point:sqrdot()
  return self:dot(self)
end

function Point:normalize()
  local len = #self
  return Point(self._x / len, self._y / len)
end

function Point:unpack()
  return self._x, self._y
end

function Point:max(other)
  return Point(math.max(self.x, other.x), math.max(self.y, other.y))
end

function Point:min(other)
  return Point(math.min(self.x, other.x), math.min(self.y, other.y))
end

return Point
