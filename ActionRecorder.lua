local class = require "class"

local ActionRecorder = class("ActionRecorder")

function ActionRecorder:create()
  self._actions = {}
  self._currentAction = 0
end

local function redo(self)
  self._currentAction = self._currentAction + 1
  self._actions[self._currentAction]:perform()
end

local function undo(self)
  self._actions[self._currentAction]:revert()
  self._currentAction = self._currentAction - 1
end

function ActionRecorder:perform(action)
  local actions = self._actions
  local currentAction = self._currentAction
  for i = #actions, currentAction + 2, -1 do
    actions[i] = nil
  end
  actions[currentAction + 1] = action
  redo(self)
end

function ActionRecorder:canUndo()
  return self._currentAction > 0
end

function ActionRecorder:undo()
  assert(self:canUndo(), "nothing to undo")
  undo(self)
end

function ActionRecorder:canRedo()
  return self._currentAction < #self._actions
end

function ActionRecorder:redo()
  assert(self:canRedo(), "nothing to redo")
  redo(self)
end

return ActionRecorder
