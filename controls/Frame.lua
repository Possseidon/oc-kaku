local class = require "class"
local Event = require "Event"

local ContainerControl = require "kaku.controls.ContainerControl"
local Box = require "kaku.Box"
local Point = require "kaku.Point"

local Frame, super = class("Frame", ContainerControl)

function Frame:create(parent)
  super.create(self, parent)

  self._style = "light"

  self._onSizeChange = Event()
  self._onStyleChange = Event()

  self._onSizeChange = self.invalidateParent
  self._onStyleChange = self.invalidate
end

Frame:addEvent("onSizeChange")
Frame:addProperty("size")

Frame:addEvent("onStyleChange")
Frame:addProperty("style")

function Frame:drawContainer(gpu, offset)
  local style = self._style
  if style then
    local box = Box(self._style)
    box:addBox(self.bounds)
    box:draw(Point(1) + offset, gpu)
  end
end

return Frame
