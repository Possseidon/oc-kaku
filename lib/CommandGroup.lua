local class = require "class"

local Command = require "kaku.Command"

local CommandGroup = class("CommandGroup")

function CommandGroup:create(info)
  self._commands = {}
  if info then
    self:add(info)
  end
end

function CommandGroup.metatable:index(name)
  return self._commands[name]
end

function CommandGroup.metatable:__pairs()
  return pairs(self._commands)
end

function CommandGroup:add(info)
  local commands = self._commands
  for name, data in pairs(info) do
    local group = commands[name]
    if #data == 0 then
      if group then
        if not group:inherits(CommandGroup) then
          error(("%q exists already, but is not a group"):format(name))
        end
        group:add(data)
      else
        commands[name] = CommandGroup(data)
      end
    else
      if group then
        error(("%q exists already"):format(name))
      end
      commands[name] = Command(table.unpack(data))
    end
  end
end

return CommandGroup
