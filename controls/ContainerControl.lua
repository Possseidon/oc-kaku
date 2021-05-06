local class = require "class"

local Canvas = require "kaku.Canvas"
local Control = require "kaku.controls.Control"
local Point = require "kaku.Point"
local Rect = require "kaku.Rect"

local ContainerControl, super = class("ContainerControl", Control)

function ContainerControl:create(parent)
  super.create(self, parent)
  self._controls = {}
  self._size = Point(12)
end

ContainerControl:addReadonly("size")

function ContainerControl.properties.bounds:get()
  return Rect(self._pos, self._size)
end

function ContainerControl:drawContainer(gpu, bounds, offset)
  local canvas = Canvas(gpu, bounds)
  canvas:clear()
end

function ContainerControl:draw(gpu, bounds, offset)
  self:drawContainer(gpu, bounds, offset)

  for _, control in ipairs(self._controls) do
    control:draw(gpu, control:clipWithOffset(bounds, offset))
  end

  self._changed = false
end

function ContainerControl:drawIfChanged(gpu, bounds, offset)
  if self._changed then
    self:draw(gpu, bounds, offset)
  else
    for _, control in ipairs(self._controls) do
      control:drawIfChanged(gpu, control:clipWithOffset(bounds, offset))
    end
  end
end

function ContainerControl:findControl(pos)
  local offsetPos = pos - self._pos + Point(1)
  for _, control in ipairs(self._controls) do
    if control.bounds:contains(offsetPos) then
      local child = control:findControl(offsetPos)
      if child then
        return child
      end
      return control
    end
  end
  return self
end

return ContainerControl
