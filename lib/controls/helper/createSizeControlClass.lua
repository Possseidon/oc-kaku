local class = require "class"
local Event = require "Event"

local Rect = require "kaku.Rect"
local Point = require "kaku.Point"

local function createSizeableControlClass(name, base)
  local SizeControl, super = class(name, base)

  function SizeControl:create(parent)
    super.create(self, parent)
    self._size = Point(30, 10)
    self._onSizeChange = Event()
    self.onSizeChange = self.invalidateParent
  end

  SizeControl:addEvent("onSizeChange")
  SizeControl:addProperty("size")

  function SizeControl.properties.bounds:get()
    return Rect(self._pos, self._size)
  end

  return SizeControl, super
end

return createSizeableControlClass
