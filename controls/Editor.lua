local class = require "class"
local Event = require "Event"
local unicode = require "unicode"

local Canvas = require "kaku.Canvas"
local Control = require "kaku.controls.Control"
local highlight = require "kaku.controls.Editor.highlight"
local Point = require "kaku.Point"
local Rect = require "kaku.Rect"

local Editor, super = class("Editor", Control)

function Editor:create(parent)
  super.create(self, parent)
  self._size = Point(30, 10)
  self._scroll = Point()
  self._lines = {}
  self._tokenizer = nil
  self._style = nil

  self._onSizeChange = Event()
  self._onScrollChange = Event()
  self._onTokenizerChange = Event()
  self._onStyleChange = Event()

  self._onSizeChange = self.invalidateParent
  self._onScrollChange = self.invalidateScroll
  self._onTokenizerChange = self.invalidate
  self._onStyleChange = self.invalidate
end

Editor:addEvent("onSizeChange")
Editor:addProperty("size")

Editor:addEvent("onScrollChange")
Editor:addProperty("scroll")

Editor:addEvent("onTokenizerChange")
Editor:addProperty("tokenizer")

Editor:addEvent("onStyleChange")
Editor:addProperty("style")

function Editor.properties.bounds:get()
  return Rect(self._pos, self._size)
end

function Editor:invalidateScroll()
  super.invalidate(self)
end

function Editor:invalidate()
  super.invalidate(self)
  self._lastScroll = nil
end

function Editor:draw(gpu, bounds, offset)
  local canvas = Canvas(gpu, bounds, offset)
  local scroll = self._scroll

  local firstLine, lastLine = 1, bounds.size.y

  if self._lastScroll then
    local scrollChange = scroll - self._lastScroll
    if scrollChange.x == 0 then
      if scrollChange.y == 0 then
        return
      end
      canvas:copy(Rect(Point(1), self._size), Point(1) - scrollChange)
      if scrollChange.y > 0 then
        firstLine = lastLine - scrollChange.y + 1
      else
        lastLine = firstLine - scrollChange.y - 1
      end
    end
  end
  self._lastScroll = scroll

  local lines = self._lines
  local tokenizer = self._tokenizer
  local style = self._style or { default = { 0xFFFFFF, 0x000000 } }
  local state = {}
  local defaultFg, defaultBg = highlight(style)
  canvas:setColors(defaultFg, defaultBg)
  canvas:fill(Rect(Point(1), Point(-scroll.x, math.huge)), " ")
  for displayLineIndex = firstLine, lastLine do
    local actualLineIndex = displayLineIndex + offset.y + scroll.y
    local line = lines[actualLineIndex] or ""
    local displayColumn = 1 - scroll.x
    if tokenizer then
      for token, kind, subkind in tokenizer(line, state) do
        local tokenWidth = unicode.wlen(token)
        local displayColumnEnd = displayColumn + tokenWidth
        canvas:setColors(highlight(style, token, kind, subkind))
        canvas:set(Point(displayColumn, displayLineIndex + offset.y), token)
        displayColumn = displayColumnEnd
      end
      displayColumn = math.max(displayColumn, 1)
    else
      canvas:set(Point(displayColumn, displayLineIndex + offset.y), line)
      displayColumn = displayColumn + unicode.wlen(line)
    end
    canvas:setColors(defaultFg, defaultBg)
    canvas:fill(Rect(Point(displayColumn, displayLineIndex + offset.y), Point(math.huge, 1)), " ")
  end
end

function Editor:loadFromStream(stream)
  local lines = {}
  for line in stream:lines("l") do
    table.insert(lines, line)
  end
  self._lines = lines
  self:invalidate()
end

return Editor
