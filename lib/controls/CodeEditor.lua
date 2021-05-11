local class = require "class"
local keyboard = require "keyboard"
local unicode = require "unicode"

local CodeViewer = require "kaku.controls.CodeViewer"
local Point = require "kaku.Point"
local unistr = require "kaku.utils.unistr"

local CodeEditor, super = class("CodeEditor", CodeViewer)

local ctrlFlag = 0x1
local shiftFlag = 0x2
local altFlag = 0x4

-- Actions

local function cursorLeft(self)
  self.cursor = Point(self:previousColumn(self.cursor), self.cursor.y)
end

local function cursorRight(self)
  self.cursor = Point(self:nextColumn(self.cursor), self.cursor.y)
end

local function cursorUp(self)
  self.cursor = self.cursor - Point(0, 1)
end

local function cursorDown(self)
  self.cursor = self.cursor + Point(0, 1)
end

local function cursorHome(self)
  self.cursor = Point(1, self.cursor.y)
end

local function cursorEnd(self)
  self.cursor = Point(self:getLineWidth(self.cursor.y) + 1, self.cursor.y)
end

local function cursorPageUp(self)
  self.cursor = self.cursor - Point(0, self.bounds.size.y - 1)
end

local function cursorPageDown(self)
  self.cursor = self.cursor + Point(0, self.bounds.size.y - 1)
end

local function cursorWordLeft(self)
  self.cursor = self.cursor - Point(5, 0)
end

local function cursorWordRight(self)
  self.cursor = self.cursor + Point(5, 0)
end

CodeEditor.actions = {
  cursor = {
    left = cursorLeft,
    right = cursorRight,
    up = cursorUp,
    down = cursorDown,
    home = cursorHome,
    ["end"] = cursorEnd,
    pageUp = cursorPageUp,
    pageDown = cursorPageDown
  }
}

function CodeEditor:create(parent)
  super.create(self, parent)
  self._cursor = Point(1, 1)
  self._selectionBegin = nil
  self._selectionEnd = nil
  self._virtualWhitespace = true
  self._keymap = {
    -- K
    [self.modFlags()] = {
      [keyboard.keys.left] = cursorLeft,
      [keyboard.keys.right] = cursorRight,
      [keyboard.keys.up] = cursorUp,
      [keyboard.keys.down] = cursorDown,
      [keyboard.keys.home] = cursorHome,
      [keyboard.keys["end"]] = cursorEnd,
      [keyboard.keys.pageUp] = cursorPageUp,
      [keyboard.keys.pageDown] = cursorPageDown
    },

    -- ctrl + K
    [self.modFlags(true)] = {
      [keyboard.keys.left] = cursorWordLeft,
      [keyboard.keys.right] = cursorWordRight
    }
  }
end

function CodeEditor.modFlags(ctrl, shift, alt)
  return (ctrl and ctrlFlag or 0) | (shift and shiftFlag or 0) | (alt and altFlag or 0)
end

function CodeEditor.modFlagsFromString(flags)
  local result = 0
  if flags then
    for flag in flags:gmatch("%a+") do
      result = result | (flag == "ctrl" and ctrlFlag)
      result = result | (flag == "shift" and shiftFlag)
      result = result | (flag == "alt" and altFlag)
    end
  end
  return result
end

function CodeEditor.properties.cursor:get()
  return self._cursor
end

function CodeEditor.properties.cursor:set(pos)
  if pos ~= self._cursor then
    self:invalidateLine(self._cursor.y)
    local clamped = self:clampCursor(pos)
    self._cursor = Point(self:normalizeColumn(clamped), clamped.y)
    self:invalidateLine(self._cursor.y)
    self:makePosVisible(self._cursor)
  end
end

function CodeEditor:getLineWidth(lineIndex)
  return unicode.wlen(self:getLine(lineIndex))
end

function CodeEditor:clampCursor(pos)
  local col, lineIndex = pos:unpack()
  local lineCount = self:lineCount()
  lineIndex = math.min(math.max(lineIndex, 1), lineCount + 1)
  col = math.max(col, 1)
  if not self._virtualWhitespace then
    col = math.min(col, self:getLineWidth(lineIndex) + 1)
  end
  return Point(col, lineIndex)
end

function CodeEditor:canFocus()
  return true
end

function CodeEditor:customizeToken(token, kind, subkind, fg, bg, pos)
  local cx, cy = self._cursor:unpack()
  local tx, ty = pos:unpack()
  if cy == ty and cx >= tx and cx < tx + unicode.wlen(token) then
    local offset = cx - tx + 1
    local width = unicode.charWidth(unistr.wsub(token, offset, offset + 1))
    local left = unistr.wsub(token, 1, offset - 1)
    local mid = unistr.wsub(token, offset, offset + width - 1)
    local right = unistr.wsub(token, offset + width)
    return left, fg, bg, mid, bg, fg, right, fg, bg
  end
  return token, fg, bg
end

function CodeEditor:keyDown(charCode, keyCode, playerName)
  local ctrl = keyboard.isControlDown()
  local shift = keyboard.isShiftDown()
  local alt = keyboard.isAltDown()

  local mods = self.modFlags(ctrl, shift, alt)
  local modKeyMap = self._keymap[mods]
  local action = modKeyMap and modKeyMap[keyCode] or self._keymap[0][keyCode]
  if action then
    action(self)
  else
    local char = string.char(charCode)
    if char:find("%C") then
      self:insertText(self.cursor, char)
      self.cursor = self.cursor + Point(unicode.charWidth(char), 0)
    end
  end
end

function CodeEditor:clipboard(text, playerName)
  self:insertText(self.cursor, text)
end

return CodeEditor
