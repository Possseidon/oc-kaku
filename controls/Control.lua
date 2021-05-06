local class = require "class"
local Event = require "Event"
local Object = require "Object"

local Point = require "kaku.Point"

local Control = class("Control", Object)

function Control:create(parent)
  self._parent = parent
  self._app = parent.app or parent
  table.insert(parent._controls, self)

  self._changed = false
  self._pos = Point(1, 1)

  self._onRemove = Event()
  self._onPosChange = Event()
  self._onFocus = Event()
  self._onUnfocus = Event()

  self.onRemove = self.invalidateParent
  self.onPosChange = self.invalidateParent
end

Control:addReadonly("app")
Control:addReadonly("parent")

Control:addProperty("pos")

Control:addEvent("onRemove")
Control:addEvent("onPosChange")
Control:addEvent("onFocus")
Control:addEvent("onUnfocus")

function Control.metatable:__call(properties)
  for key, value in pairs(properties) do
    self[key] = value
  end
  return self
end

function Control:remove()
  self:onRemove()
  local controls = self._parent._controls
  for i = 1, #controls do
    local control = controls[i]
    if control == self then
      table.remove(controls, i)
      return
    end
  end
  error("control already removed", 2)
end

function Control:tryFocus(playerName)
  if not self:canFocus() then
    return false
  end
  playerName = playerName or ""
  local focus = self._app._focus
  local oldFocus = focus[playerName]
  if oldFocus then
    oldFocus:_onUnfocus(playerName)
  end
  focus[playerName] = self
  self:_onFocus(playerName)
  return true
end

function Control:focus(playerName)
  if not self:tryFocus(playerName) then
    error(self.classname .. " cannot focus")
  end
end

function Control:tryUnfocus(playerName)
  playerName = playerName or ""
  if not self:focused(playerName) then
    return false
  end
  self:_onUnfocus(playerName)
  self._app._focus[playerName] = nil
  return true
end

function Control:unfocus(playerName)
  if not self:tryUnfocus(playerName) then
    error(("%s is not focused by %q'"):format(self.classname, playerName))
  end
end

function Control:focused(playerName)
  local focus = self._app._focus
  if playerName then
    return focus[playerName] == self
  else
    for _, control in next, focus do
      if control == self then
        return true
      end
    end
    return false
  end
end

function Control:canFocus()
  return false
end

function Control:invalidate()
  self._changed = true
end

function Control:invalidateParent()
  self.parent:invalidate()
end

function Control:clipWithOffset(parentBounds, offset)
  local bounds = self.bounds + parentBounds.pos - Point(1)
  local clippedBounds = parentBounds:clip(bounds - offset)
  return clippedBounds, offset - bounds.pos + clippedBounds.pos
end

function Control:draw(gpu, bounds, offset)
  self:abstract()
end

function Control:forceDraw(gpu, bounds, offset)
  self:draw(gpu, bounds, offset)
  self._changed = false
end

function Control:drawIfChanged(gpu, bounds, offset)
  if self._changed then
    self:forceDraw(gpu, bounds, offset)
  end
end

function Control:findControl(pos)
  return nil
end

function Control:keyDown(charCode, keyCode, playerName)
  -- nothing
end

function Control:keyUp(charCode, keyCode, playerName)
  -- nothing
end

function Control:clipboard(value, playerName)
  -- nothing
end

function Control:touch(pos, playerName)
  -- nothing
end

return Control
