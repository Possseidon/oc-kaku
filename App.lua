local class = require "class"
local event = require "event"
local Event = require "Event"
local Object = require "Object"
local term = require "term"

local Point = require "kaku.Point"

local App = class("App", Object)

-- Event Handlers

local function interrupted(app)
  app:_onInterrupted()
  if app.interruptible then
    app:stop()
  end
end

local function keyDown(app, keyboardAddress, charCode, keyCode, playerName)
  playerName = playerName or ""
  local control = app._focus[playerName]
  if control then
    control:keyDown(charCode, keyCode, playerName)
  else
    app:_onKeyDown(charCode, keyCode, playerName)
  end
end

local function keyUp(app, keyboardAddress, charCode, keyCode, playerName)
  playerName = playerName or ""
  local control = app._focus[playerName]
  if control then
    control:keyUp(charCode, keyCode, playerName)
  else
    app:_onKeyUp(charCode, keyCode, playerName)
  end
end

local function clipboard(app, keyboardAddress, value, playerName)
  playerName = playerName or ""
  local control = app._focus[playerName]
  if control then
    control:clipboard(value, playerName)
  else
    app:_clipboard(value, playerName)
  end
end

local function touch(app, screenAddress, x, y, button, playerName)
  playerName = playerName or ""
  local pos = Point(x, y)
  local control = app:findControl(pos)
  local foundFocus = false
  if control then
    foundFocus = control:tryFocus(playerName)
    control:touch(pos, playerName)
  end
  if not foundFocus then
    control = app._focus[playerName]
    if control then
      control:unfocus(playerName)
    end
    app:_onTouch(pos, playerName)
  end
end

-- App

function App:create()
  self._running = false
  self._controls = {}
  self._eventHandlers = {
    interrupted = interrupted,
    key_down = keyDown,
    key_up = keyUp,
    clipboard = clipboard,
    touch = touch
  }
  self._onInterrupted = Event()
  self._onKeyDown = Event()
  self._onKeyUp = Event()
  self._onClipboard = Event()
  self._onTouch = Event()
  self._focus = {} -- playerName = control
  self._clearNext = true
  self._oldClearValue, self._oldClearIsPalette = term.gpu().getBackground()
  self._clearColor = 0
  self._onClearColorChange = Event()
  function self:onClearColorChange()
    self._clearNext = true
  end

  self.interruptible = true
end

function App:run()
  self._running = true
  repeat
    self:draw()
    self:processAllEvents()
  until not self._running
  term.gpu().setBackground(self._oldClearValue, self._oldClearIsPalette)
  term.clear()
end

function App:stop()
  self._running = false
end

function App:processEvent(name, ...)
  if not name then
    return false
  end
  local handler = self._eventHandlers[name]
  if handler then
    handler(self, ...)
  else
    -- print("skip", name)
  end
  return true
end

function App:invalidate()
  self._clearNext = true
end

function App:processNextEvent(timeout)
  return self:processEvent(event.pull(timeout))
end

function App:processAllEvents()
  self:processNextEvent()
  while self:processNextEvent(0) do end
end

function App:draw()
  local gpu = term.gpu()

  local controls = self._controls
  if self._clearNext then
    gpu.setBackground(self._clearColor)
    term.clear()
    self._clearNext = false
    for i = 1, #controls do
      controls[i]:forceDraw(gpu, Point())
    end
  else
    for i = 1, #controls do
      controls[i]:drawIfChanged(gpu, Point())
    end
  end
end

function App:findControl(pos)
  local controls = self._controls
  for i = #controls, 1, -1 do
    local control = controls[i]
    local bounds = control.bounds
    if bounds and bounds:contains(pos) then
      return control:findControl(pos) or control
    end
  end
end

App:addEvent("onInterrupted")
App:addEvent("onKeyDown")
App:addEvent("onKeyUp")
App:addEvent("onClipboard")
App:addEvent("onTouch")

App:addEvent("onClearColorChange")
App:addProperty("clearColor")

return App
