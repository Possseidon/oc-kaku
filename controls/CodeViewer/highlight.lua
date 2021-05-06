local function fg(style)
  local default = style.default
  return (assert(default and default[1], "style does not have a forgeground color"))
end

local function bg(style)
  local default = style.default
  return (assert(default and default[2], "style does not have a background color"))
end

local function defaults(style)
  return fg(style), bg(style)
end

local function unpack(style, colors)
  return colors[1] or fg(style), colors[2] or bg(style)
end

local function highlight(style, token, kind, subkind)
  if token then
    local matchers = style.matchers
    if matchers then
      for pattern, colors in pairs(matchers) do
        if token:find(pattern) then
          return unpack(style, colors)
        end
      end
    end
  end

  if kind then
    local styleKinds = style.kinds
    local styleKind = styleKinds[kind]
    if type(styleKind) == "number" then
      return styleKind, bg(style)
    elseif type(styleKind) == "table" then
      local styleSubkind = styleKind[subkind]
      if type(styleSubkind) == "number" then
        return styleSubkind, bg(style)
      elseif type(styleSubkind) == "table" then
        return unpack(style, styleSubkind)
      elseif not styleSubkind then
        return unpack(style, styleKind)
      else
        error(("invalid value %q for kind %s.%s"):format(tostring(styleSubkind), kind, subkind))
      end
    elseif styleKind then
      error(("invalid value %q for kind %s"):format(tostring(styleKind), kind))
    end
  end

  return defaults(style)
end

return highlight
