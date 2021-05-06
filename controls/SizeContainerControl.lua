local ContainerControl = require "kaku.controls.ContainerControl"
local createSizeControlClass = require "kaku.controls.helper.createSizeControlClass"

local SizeControl, super = createSizeControlClass("SizeContainerControl", ContainerControl)

return SizeControl
