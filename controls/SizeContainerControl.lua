local class = require "class"
local Event = require "Event"

local ContainerControl = require "kaku.controls.ContainerControl"
local Rect = require "kaku.Rect"
local Point = require "kaku.Point"

local SizeContainerControl, super = class("SizeContainerControl", ContainerControl)

function SizeContainerControl:create(parent)
  super.create(self, parent)
  self._size = Point(30, 10)
  self._onSizeChange = Event()
  self.onSizeChange = self.invalidateParent
end

SizeContainerControl:addEvent("onSizeChange")
SizeContainerControl:addProperty("size")

function SizeContainerControl.properties.bounds:get()
  return Rect(self._pos, self._size)
end

return SizeContainerControl
