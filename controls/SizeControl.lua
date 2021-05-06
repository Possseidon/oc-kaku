local class = require "class"
local Event = require "Event"

local Control = require "kaku.controls.Control"
local Rect = require "kaku.Rect"
local Point = require "kaku.Point"

local SizeControl, super = class("SizeControl", Control)

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

return SizeControl
