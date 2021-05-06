local class = require "class"
local Event = require "Event"

local Box = require "kaku.Box"
local Canvas = require "kaku.Canvas"
local ContainerControl = require "kaku.controls.ContainerControl"
local Point = require "kaku.Point"
local Rect = require "kaku.Rect"

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

function Frame:drawContainer(gpu, bounds, offset)
  local style = self._style
  if style then
    local canvas = Canvas(gpu, bounds, offset)
    canvas:fill(Rect(Point(2), self._size - Point(2)), " ")

    local box = Box(style)
    box:addBox(Rect(Point(1), self._size))
    box:draw(gpu, bounds, offset)
  else
    super.drawContainer(self, gpu, bounds, offset)
  end
end

return Frame
