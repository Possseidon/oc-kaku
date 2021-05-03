local class = require "class"

local Command = class("Command")

function Command:create(caption, execute, canExecute)
  self._caption = assert(caption, "caption expected")
  self._execute = assert(execute, "execute function expected")
  self._canExecute = canExecute
end

function Command:caption()
  return self._caption
end

function Command:try(user)
  if self:canExecute(user) then
    self._execute(user)
    return true
  else
    return false
  end
end

function Command:canExecute(user)
  local canExecute = self._canExecute
  return not canExecute or canExecute(user)
end

function Command.metatable:__call(user)
  assert(self:try(user), ("cannot execute %q"):format(self._caption))
end

function Command.metatable:__tostring()
  return ("Command %q"):format(self._caption)
end

return Command
