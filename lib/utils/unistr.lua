local unicode = require "unicode"

local function wsub(text, first, last, pad)
  pad = pad or " "
  if first > unicode.wlen(text) then
    return ""
  end
  local left = unicode.wtrunc(text, first)
  local leftDif = first - unicode.wlen(left)
  local right = unicode.sub(string.sub(text, #left + 1), leftDif)
  local padded = string.rep(pad, leftDif - 1) .. right
  if last then
    local maxWidth = last - first + 1
    if unicode.wlen(padded) > maxWidth then
      local truncated = unicode.wtrunc(padded, maxWidth + 1)
      return truncated .. string.rep(pad, maxWidth - unicode.wlen(truncated))
    end
  end
  return padded
end

return {
  wsub = wsub
}
