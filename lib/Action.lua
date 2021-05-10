local class = require "class"

local Action = class("Action")

function Action:perform()
  error("action perform not implemented")
end

function Action:revert()
  error("action revert not implemented")
end

return Action
