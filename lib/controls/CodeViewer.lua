local class = require "class"
local Event = require "Event"
local unicode = require "unicode"

local Canvas = require "kaku.Canvas"
local highlight = require "kaku.controls.CodeViewer.highlight"
local Point = require "kaku.Point"
local Rect = require "kaku.Rect"
local SizeControl = require "kaku.controls.SizeControl"
local unistr = require "kaku.utils.unistr"

local CodeViewer, super = class("CodeViewer", SizeControl)

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
  local tokenize = tokenizer.tokenize

  state = state and state:copy() or tokenizer.newState()

  for i = firstLine + 1, lineIndex do
    for _ in tokenize(lines[i], state, i) do
      -- nothing
    end
    lineStates[i] = state:copy()
  end

  return state
end

function CodeViewer:create(parent)
  super.create(self, parent)
  self._scroll = Point()
  self._lines = {}
  self._lineStates = {}
  self._multipleLinesChanged = true
  self._tokenizer = nil
  self._style = nil
  self._fullyInvalidated = true

  self._onScrollChange = Event()
  self._onTokenizerChange = Event()
  self._onStyleChange = Event()

  self._onScrollChange = self.invalidateScroll
  self._onTokenizerChange = self.invalidate
  self._onStyleChange = self.invalidate
end

CodeViewer:addEvent("onScrollChange")
CodeViewer:addProperty("scroll")

CodeViewer:addEvent("onTokenizerChange")
CodeViewer:addProperty("tokenizer")

CodeViewer:addEvent("onStyleChange")
CodeViewer:addProperty("style")

function CodeViewer:invalidateScroll()
  super.invalidate(self)
  self._firstInvalidLine = nil
  self._multipleLinesChanged = true
end

function CodeViewer:invalidateLine(lineIndex, invalidateRest)
  super.invalidate(self)
  local firstInvalidLine = self._firstInvalidLine
  if firstInvalidLine then
    self._firstInvalidLine = math.min(firstInvalidLine, lineIndex)
    if invalidateRest or firstInvalidLine ~= math.huge and firstInvalidLine ~= lineIndex then
      self._multipleLinesChanged = true
      for i = lineIndex, #self._lineStates do
        self._lineStates[i] = nil
      end
    end
  end
  self._lastScroll = nil
end

function CodeViewer:invalidate()
  super.invalidate(self)
  self._fullyInvalidated = true
  self._lastScroll = nil
  self._firstInvalidLine = nil
  self._multipleLinesChanged = true
  self._lineStates = {}
end

function CodeViewer:customizeToken(token, kind, subkind, fg, bg, pos)
  return token, fg, bg
end

function CodeViewer:draw(gpu, bounds, offset)
  local canvas = Canvas(gpu, bounds, offset)
  local scroll = self._scroll

  local firstLine, lastLine = 1, bounds.size.y
  local leftChanged = self._fullyInvalidated

  if self._lastScroll then
    local scrollChange = scroll - self._lastScroll
    if scrollChange.x == 0 then
      if scrollChange.y == 0 then
        return
      end
      canvas:copy(Rect(Point(1), self.size), Point(1) - scrollChange)
      if scrollChange.y > 0 then
        firstLine = lastLine - scrollChange.y + 1
      else
        lastLine = firstLine - scrollChange.y - 1
      end
    elseif scroll.x < 0 then
      leftChanged = true
    end
  end
  self._lastScroll = scroll

  local lineStates = self._lineStates

  local multipleLinesChanged = self._multipleLinesChanged
  local firstInvalidLine = self._firstInvalidLine
  if firstInvalidLine then
    firstLine = math.max(firstLine, firstInvalidLine - offset.y - scroll.y)
    if firstInvalidLine < firstLine + offset.y + scroll.y then
      for i = firstInvalidLine, #lineStates do
        lineStates[i] = nil
      end
      multipleLinesChanged = true
    end
  end

  local lines = self._lines
  local tokenizer = self._tokenizer
  local tokenize = tokenizer and tokenizer.tokenize
  local customizeToken = self.customizeToken
  local style = self._style or { default = { 0xFFFFFF, 0x000000 } }
  if leftChanged then
    local leftFg, leftBg = highlight(style, " ", "whitespace", "left")
    canvas:setColors(leftFg, leftBg)
    canvas:fill(Rect(Point(1), Point(-scroll.x, math.huge)), " ")
  end

  for displayLineIndex = firstLine, lastLine do
    local actualLineIndex = displayLineIndex + offset.y + scroll.y
    local line = lines[actualLineIndex] or ""
    local displayColumn = 1 - scroll.x
    local state, oldState

    local function drawTokens(displayToken, fg, bg, ...)
      if not displayToken then
        return
      end

      local tokenWidth = unicode.wlen(displayToken)
      local displayColumnEnd = displayColumn + tokenWidth
      canvas:setColors(fg, bg)
      canvas:set(Point(displayColumn, displayLineIndex + offset.y), displayToken)
      displayColumn = displayColumnEnd

      return drawTokens(...)
    end

    if tokenize then
      state = lineState(self, actualLineIndex - 1)
      if state then
        state = state:copy()
      end
      for token, kind, subkind in tokenize(line, state, actualLineIndex) do
        local fg, bg = highlight(style, token, kind, subkind)
        local pos = Point(displayColumn + scroll.x, actualLineIndex)
        drawTokens(customizeToken(self, token, kind, subkind, fg, bg, pos))
      end
      displayColumn = math.max(displayColumn, 1)
      oldState = lineStates[actualLineIndex]
      lineStates[actualLineIndex] = state
    else
      local fg, bg = highlight(style)
      local pos = Point(displayColumn + scroll.x, actualLineIndex)
      drawTokens(customizeToken(self, line, nil, nil, fg, bg, pos))
    end
    local pad = (" "):rep(bounds.size.x - displayColumn + offset.x + 1)
    local padPos = Point(displayColumn + scroll.x, actualLineIndex)
    local fg, bg = highlight(style, pad, "whitespace", "eol")
    drawTokens(customizeToken(self, pad, "whitespace", "eol", fg, bg, padPos))

    if not multipleLinesChanged and (not state or oldState == state) then
      break
    end
  end

  self._firstInvalidLine = math.huge
  self._multipleLinesChanged = false
  self._fullyInvalidated = false
end

function CodeViewer:lineCount()
  return #self._lines
end

function CodeViewer:getLine(lineIndex)
  assert(lineIndex >= 1, "line index must be at least one")
  return self._lines[lineIndex] or ""
end

function CodeViewer:getChar(pos)
  local line = self:getLine(pos.y)
  line = unistr.wsub(line, pos.x)
  local char = unicode.sub(line, 1, 1)
  return char ~= "" and char or " "
end

function CodeViewer:normalizeColumn(pos)
  if pos.x == 1 then
    return 1
  end
  local char = self:getChar(Point(pos.x - 1, pos.y))
  return pos.x - unicode.charWidth(char) + 1
end

function CodeViewer:nextColumn(pos)
  local char = self:getChar(pos)
  return pos.x + unicode.charWidth(char)
end

function CodeViewer:previousColumn(pos)
  if pos.x == 1 then
    return 1
  end
  local char = self:getChar(Point(pos.x - 2, pos.y))
  return pos.x - unicode.charWidth(char)
end

local function splitLines(text)
  return text:gmatch("[^\n]*")
end

function CodeViewer:setLine(lineIndex, text)
  assert(lineIndex >= 1, "line index must be at least one")
  local lines = self._lines
  for i = #lines + 1, lineIndex - 1 do
    lines[i] = ""
  end
  local lineGenerator = splitLines(text)
  local oldText = lines[lineIndex] or ""
  local firstLine = lineGenerator()
  local lineChanged = oldText ~= firstLine
  if lineChanged then
    lines[lineIndex] = firstLine
  end
  local invalidateRest = false
  local insertPos = lineIndex
  for line in lineGenerator do
    insertPos = insertPos + 1
    table.insert(lines, insertPos, line)
    invalidateRest = true
  end
  if lineChanged then
    self:invalidateLine(lineIndex, invalidateRest)
  elseif invalidateRest then
    self:invalidateLine(lineIndex + 1, true)
  end
end

function CodeViewer:insertLine(lineIndex, text)
  assert(lineIndex >= 1, "line index must be at least one")
  text = text or ""
  local lines = self._lines
  if lineIndex > #lines then
    self:setLine(lineIndex, text)
  else
    self:invalidateLine(lineIndex, true)
    for line in splitLines(text) do
      table.insert(lines, lineIndex, line)
      lineIndex = lineIndex + 1
    end
  end
end

function CodeViewer:removeLine(lineIndex, lastLineIndex)
  assert(lineIndex >= 1, "line index must be at least one")
  local lines = self._lines
  if lineIndex > #lines then
    return
  end
  lastLineIndex = lastLineIndex or lineIndex
  for i = lineIndex, lastLineIndex do
    table.remove(self._lines, lineIndex)
  end
  if lastLineIndex >= lineIndex then
    self:invalidateLine(lineIndex, true)
  end
end

function CodeViewer:insertText(pos, text)
  local line = self:getLine(pos.y)
  local pad = pos.x - unicode.wlen(line) - 1
  if pad > 0 then
    line = unistr.wsub(line, 1, pos.x - 1) .. (" "):rep(pad) .. text
  else
    line = unistr.wsub(line, 1, pos.x - 1) .. text .. unistr.wsub(line, pos.x)
  end
  self:setLine(pos.y, line)
  -- TODO: return the end position
end

function CodeViewer:makePosVisible(pos)
  local sx, sy = self._scroll:unpack()
  local px, py = pos:unpack()
  local w, h = self._size:unpack()
  sx = math.min(math.max(sx, px - w), px - 1)
  sy = math.min(math.max(sy, py - h), py - 1)
  self.scroll = Point(sx, sy)
end

function CodeViewer:clear()
  self._lines = {}
  self:invalidate()
end

function CodeViewer:loadFromStream(stream)
  local lines = {}
  for line in stream:lines("l") do
    table.insert(lines, line)
  end
  self._lines = lines
  self:invalidate()
end

function CodeViewer:saveToStream(stream)
  for _, line in ipairs(self._lines) do
    stream:write(line, "\n")
  end
end

return CodeViewer
