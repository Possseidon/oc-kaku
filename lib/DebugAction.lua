local class = require "class"

local Action = require "kaku.Action"

local DebugAction = class("DebugAction", Action)

function DebugAction:create(message)
  self._message = message
  print("create " .. message)
end

function DebugAction:perform()
  print("do " .. self._message)
end

function DebugAction:revert()
  print("undo " .. self._message)
end

return DebugAction
