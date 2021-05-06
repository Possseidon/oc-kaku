local class = require "class"
local Event = require "Event"
local unicode = require "unicode"

local Canvas = require "kaku.Canvas"
local Control = require "kaku.controls.Control"
local highlight = require "kaku.controls.Editor.highlight"
local Point = require "kaku.Point"
local Rect = require "kaku.Rect"

local Editor, super = class("Editor", Control)

local function lineState(self, lineIndex)
  local lines = self._lines

  if not lines[lineIndex] then
    return nil
  end

  local lineStates = self._lineStates
  local state
  local firstLine = 0

  for i = lineIndex, 1, -1 do
    state = lineStates[i]
    if state then
      firstLine = i
      break
    end
  end

  local tokenizer = self._tokenizer
  local copyState = tokenizer.copyState
  local tokenize = tokenizer.tokenize

  state = state and copyState(state) or {}

  for i = firstLine + 1, lineIndex do
    for _ in tokenize(lines[i], state) do
      -- nothing
    end
    lineStates[i] = copyState(state)
  end

  return state
end

function Editor:create(parent)
  super.create(self, parent)
  self._size = Point(30, 10)
  self._scroll = Point()
  self._lines = {}
  self._lineStates = {}
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
  self._firstInvalidLine = nil
end

function Editor:invalidateLine(lineIndex)
  super.invalidate(self)
  local lineStates = self._lineStates
  for i = lineIndex, #lineStates do
    lineStates[i] = nil
  end
  local firstInvalidLine = self._firstInvalidLine
  if firstInvalidLine then
    self._firstInvalidLine = math.min(firstInvalidLine, lineIndex)
  end
  self._lastScroll = nil
end

function Editor:invalidate()
  super.invalidate(self)
  self._lastScroll = nil
  self._firstInvalidLine = nil
  self._lineStates = {}
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

  if self._firstInvalidLine then
    firstLine = math.max(firstLine, self._firstInvalidLine - offset.y - scroll.y)
  end

  local lines = self._lines
  local tokenize = self._tokenizer.tokenize
  local style = self._style or { default = { 0xFFFFFF, 0x000000 } }
  local defaultFg, defaultBg = highlight(style)
  canvas:setColors(defaultFg, defaultBg)
  canvas:fill(Rect(Point(1), Point(-scroll.x, math.huge)), " ")
  for displayLineIndex = firstLine, lastLine do
    local actualLineIndex = displayLineIndex + offset.y + scroll.y
    local line = lines[actualLineIndex] or ""
    local displayColumn = 1 - scroll.x
    if tokenize then
      for token, kind, subkind in tokenize(line, lineState(self, actualLineIndex - 1)) do
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

  self._firstInvalidLine = math.huge
end

function Editor:lineCount()
  return #self._lines
end

function Editor:getLine(lineIndex)
  assert(lineIndex >= 1, "line index must be at least one")
  return self._lines[lineIndex] or ""
end

function Editor:setLine(lineIndex, text)
  assert(lineIndex >= 1, "line index must be at least one")
  local lines = self._lines
  if text ~= "" then
    for i = #lines + 1, lineIndex - 1 do
      lines[i] = ""
    end
  end
  local oldText = lines[lineIndex] or ""
  if oldText ~= text then
    lines[lineIndex] = text
    self:invalidateLine(lineIndex)
  end
end

function Editor:insertLine(lineIndex, text)
  assert(lineIndex >= 1, "line index must be at least one")
  local lines = self._lines
  if lineIndex > #lines then
    self:setLine(lineIndex, text)
  else
    table.insert(lines, lineIndex, text)
    self:invalidateLine(lineIndex)
  end
end

function Editor:removeLine(lineIndex)
  assert(lineIndex >= 1, "line index must be at least one")
  local lines = self._lines
  if lineIndex > #lines then
    return
  end
  table.remove(self._lines, lineIndex)
  self:invalidateLine(lineIndex)
end

function Editor:loadFromStream(stream)
  local lines = {}
  for line in stream:lines("l") do
    table.insert(lines, line)
  end
  self._lines = lines
  self._lineStates = {}
  self:invalidate()
end

function Editor:saveToStream(stream)
  for _, line in ipairs(self._lines) do
    stream:write(line, "\n")
  end
end

return Editor
