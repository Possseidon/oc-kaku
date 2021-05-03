local class = require "class"
local Event = require "Event"
local unicode = require "unicode"

local Control = require "kaku.controls.Control"
local highlight = require "kaku.controls.Editor.highlight"
local Point = require "kaku.Point"
local Rect = require "kaku.Rect"
local unistr = require "kaku.utils.unistr"

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
  self._onScrollChange = self.invalidate
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

function Editor:draw(gpu, offset)
  local lines = self._lines
  local scroll = self._scroll
  local tokenizer = self._tokenizer
  local style = self._style or { default = { 0xFFFFFF, 0x000000 } }
  local x, y = (self._pos + offset):unpack()
  local w, h = self._size:unpack()
  local state = {}
  local defaultFg, defaultBg = highlight(style)
  gpu.setForeground(defaultFg)
  gpu.setBackground(defaultBg)
  if scroll.x < 0 then
    gpu.fill(x, y, -scroll.x, h, " ")
  end
  for displayLineIndex = 1, h do
    local actualLineIndex = displayLineIndex + scroll.y
    local line = lines[actualLineIndex] or ""
    if tokenizer then
      local displayColumn = 1 - scroll.x
      for token, kind, subkind in tokenizer(line, state) do
        local tokenWidth = unicode.wlen(token)
        local displayColumnEnd = displayColumn + tokenWidth
        if displayColumn <= w and displayColumnEnd >= 1 then
          local leftExcess = math.max(1 - displayColumn, 0)
          local rightExcess = math.max(displayColumnEnd - w, 0)
          if leftExcess > 0 or rightExcess > 0 then
            token = unistr.wsub(token, 1 + leftExcess, 1 + tokenWidth - rightExcess)
          end
          local fg, bg = highlight(style, token, kind, subkind)
          gpu.setForeground(fg)
          gpu.setBackground(bg)
          gpu.set(x + displayColumn - 1 + leftExcess, y + displayLineIndex - 1, token)
        end
        displayColumn = displayColumnEnd
      end
      displayColumn = math.max(displayColumn, 1)
      gpu.setForeground(defaultFg)
      gpu.setBackground(defaultBg)
      gpu.set(x + displayColumn - 1, y + displayLineIndex - 1, (" "):rep(w - displayColumn + 1))
    else
      gpu.set(x, y + displayLineIndex - 1, line)
    end
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
