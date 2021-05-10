local class = require "class"
local Event = require "Event"

local Box = require "kaku.Box"
local Canvas = require "kaku.Canvas"
local SizeContainerControl = require "kaku.controls.SizeContainerControl"
local Point = require "kaku.Point"
local Rect = require "kaku.Rect"

local Frame, super = class("Frame", SizeContainerControl)

function Frame:create(parent)
  super.create(self, parent)
  self._style = "light"
  self._onStyleChange = Event()
  self._onStyleChange = self.invalidate
end

Frame:addEvent("onStyleChange")
Frame:addProperty("style")

function Frame:drawContainer(gpu, bounds, offset)
  local style = self._style
  if style then
    local canvas = Canvas(gpu, bounds, offset)
    canvas:fill(Rect(Point(2), self.size - Point(2)), " ")

    local box = Box(style)
    box:addBox(Rect(Point(1), self.size))
    box:draw(gpu, bounds, offset)
  else
    super.drawContainer(self, gpu, bounds, offset)
  end
end

return Frame
