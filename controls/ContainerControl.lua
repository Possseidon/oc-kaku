local class = require "class"

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

function ContainerControl:drawContainer(gpu, offset)
  -- nothing
end

function ContainerControl:draw(gpu, offset)
  local pos, size = self.bounds:unpack()
  local x, y = (pos + offset):unpack()
  local w, h = size:unpack()
  gpu.fill(x, y, w, h, " ")

  self:drawContainer(gpu, offset)

  local controls = self._controls
  local totalOffset = offset + self._pos - Point(1)
  for i = 1, #controls do
    controls[i]:draw(gpu, totalOffset)
  end

  self._changed = false
end

function ContainerControl:drawIfChanged(gpu, offset)
  local totalOffset = offset + self._pos - Point(1)
  local controls = self._controls
  if self._changed then
    self:draw(gpu, offset)
  else
    for i = 1, #controls do
      controls[i]:drawIfChanged(gpu, totalOffset)
    end
  end
end

function ContainerControl:findControl(pos)
  local controls = self._controls
  local offsetPos = pos - self._pos + Point(1)
  for i = 1, #controls do
    local child = controls[i]
    if child.bounds:contains(offsetPos) then
      local childOfChild = child:findControl(offsetPos)
      if childOfChild then
        return childOfChild
      end
      return child
    end
  end
  return self
end

return ContainerControl
