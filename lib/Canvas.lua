local class = require "class"
local Object = require "Object"
local unicode = require "unicode"

local Point = require "kaku.Point"
local Rect = require "kaku.Rect"
local unistr = require "kaku.utils.unistr"

local Canvas = class("Canvas", Object)

function Canvas:create(gpu, bounds, offset)
  self.gpu = gpu or require "component" .gpu
  self.bounds = bounds or Rect(Point(1), Point(gpu.getViewport()))
  self.offset = offset or Point()
  self.fg = 0xFFFFFF
  self.bg = 0x000000
end

function Canvas:invalidateColors()
  self._fgLast = nil
  self._bgLast = nil
end

function Canvas:updateColors()
  local gpu = self.gpu
  local fg = self.fg
  if fg ~= self._fgLast then
    gpu.setForeground(fg)
    self._fgLast = fg
  end
  local bg = self.bg
  if bg ~= self._bgLast then
    gpu.setBackground(bg)
    self._bgLast = bg
  end
end

function Canvas:setColors(fg, bg)
  self.fg = fg or 0xFFFFFF
  self.bg = bg or 0x000000
end

function Canvas:set(pos, text)
  local bounds = self.bounds
  pos = pos - self.offset
  if pos.y < 1 or pos.y > bounds.size.y then
    return
  end

  local leftCutoff = math.max(1 - pos.x, 0)
  local rightCutoff = bounds.size.x - pos.x + 1
  pos = pos + bounds.pos - Point(1)

  text = unistr.wsub(text, leftCutoff + 1, rightCutoff)

  if text ~= "" then
    self:updateColors()
    self.gpu.set(pos.x + leftCutoff, pos.y, text)
  end
end

-- TODO: setVertical

function Canvas:fill(rect, char)
  local bounds = self.bounds
  local clippedRect = bounds:clip(rect + bounds.pos - self.offset - Point(1))
  local pos, size = clippedRect:unpack()
  if size.x > 0 and size.y > 0 then
    self:updateColors()
    self.gpu.fill(pos.x, pos.y, size.x, size.y, char)
  end
end

function Canvas:clear(char)
  local rect = self.bounds
  local pos, size = rect:unpack()
  if size.x > 0 and size.y > 0 then
    self:updateColors()
    self.gpu.fill(pos.x, pos.y, size.x, size.y, char or " ")
  end
end

function Canvas:copy(rect, target)
  local bounds = self.bounds
  local offset = bounds.pos - self.offset - Point(1)
  target = target + offset
  rect = rect + offset

  -- clip source rect
  local clippedRect = bounds:clip(rect)

  -- clip for destination
  local clipOffset = target - rect.pos
  clippedRect = bounds:clip(clippedRect + clipOffset) - clipOffset

  local pos, size = clippedRect:unpack()
  if size.x > 0 and size.y > 0 then
    self.gpu.copy(pos.x, pos.y, size.x, size.y, (target - rect.pos):unpack())
  end
end

return Canvas
