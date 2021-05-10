local tokens = {
  comment = {
    content = true;
    longbracket = true;
  };
  identifier = true;
  invalid = true;
  keyword = {
    flow = true;
    operator = true;
    value = true;
  };
  number = true;
  operator = true;
  string = {
    content = true;
    escape = true;
    longbracket = true;
    quote = true;
  };
  whitespace = true;
}

local newState

local stateMetatable = {
  __index = {
    copy = function(state)
      local result = newState()
      for k, v in pairs(state) do
        result[k] = v
      end
      return result
    end
  },
  __eq = function(lhs, rhs)
    return lhs.kind == rhs.kind and lhs.level == rhs.level and lhs.quote == rhs.quote
  end
}

function newState()
  return setmetatable({}, stateMetatable)
end

local function tokenize(code, state, line)
  local keywords = {
    ["and"] = "operator",
    ["break"] = "flow",
    ["do"] = "flow",
    ["else"] = "flow",
    ["elseif"] = "flow",
    ["end"] = "flow",
    ["false"] = "value",
    ["for"] = "flow",
    ["function"] = "flow",
    ["goto"] = "flow",
    ["if"] = "flow",
    ["in"] = "flow",
    ["local"] = "value",
    ["nil"] = "value",
    ["not"] = "operator",
    ["or"] = "operator",
    ["repeat"] = "flow",
    ["return"] = "flow",
    ["then"] = "flow",
    ["true"] = "value",
    ["until"] = "flow",
    ["while"] = "flow"
  }

  local pos = 1

  local function yield(token, kind, subkind)
    coroutine.yield(token, kind, subkind)
    pos = pos + #token
  end

  local function processWhitespace(whitespace)
    yield(whitespace, "whitespace")
  end

  local function processIdentifier(identifier)
    local keyword = keywords[identifier]
    if keyword then
      yield(identifier, "keyword", keyword)
    else
      yield(identifier, "identifier")
    end
  end

  local function processNumber()
    local number =
      code:match("^0[xX]%x*%.%x+[pP][+%-]?%d+", pos) or
      code:match("^0[xX]%x+[pP][+%-]?%d+", pos) or
      code:match("^0[xX]%x*%.%x+", pos) or
      code:match("^0[xX]%x+", pos) or
      code:match("^%d*%.%d+[eE][+%-]?%d+", pos) or
      code:match("^%d+%.?[eE][+%-]?%d+", pos) or
      code:match("^%d*%.%d+", pos) or
      code:match("^%d+%.?", pos)
    if number then
      yield(number, "number")
    end
  end

  local function continueMultiline(kind, level)
    local finalQuote = "]" .. ("="):rep(level) .. "]"
    local content = code:match("^(.-)" .. finalQuote, pos)
    if content then
      yield(content, kind, "content")
      yield(finalQuote, kind, "longbracket")
      state.kind = nil
      state.level = nil
    else
      yield(code:sub(pos), kind, "content")
      state.kind = kind
      state.level = level
    end
  end

  local function processMultiline(kind, startQuote)
    yield(startQuote, kind, "longbracket")
    continueMultiline(kind, #startQuote - 2)
  end

  local function processComment()
    yield("--", "comment")
    local quote = code:match("^%[=*%[", pos)
    if quote then
      processMultiline("comment", quote)
    else
      local content = code:match("^[^\r\n]+", pos)
      if content then
        yield(content, "comment", "content")
      end
    end
  end

  -- allowed only as the first character in a chunk
  local function processHashComment()
    yield("#", "comment")
    local content = code:match("^[^\r\n]+", pos)
    if content then
      yield(content, "comment", "content")
    end
  end

  local function processMultilineString(quote)
    processMultiline("string", quote)
  end

  local function continueString(quote)
    local quotePattern = "^" .. quote
    local contentPattern = "^[^\\\r\n" .. quote .. "]+"
    while not code:find(quotePattern, pos) do
      local content = code:match(contentPattern, pos)
      if content then
        yield(content, "string", "content")
      else
        local escape = code:match("^\\%d%d?%d?", pos) or
          code:match("^\\x%x%x", pos) or
          code:match("^\\u{%x+}", pos) or
          code:match("^\\\r\n", pos) or
          code:match("^\\.?", pos)
        if escape then
          yield(escape, "string", "escape")
          if #escape == 1 or escape == "\\\r" or escape == "\\\n" or escape == "\\\r\n" then
            state.kind = "string"
            state.quote = quote
            return
          end
        else
          return
        end
      end
    end
    yield(quote, "string", "quote")
  end

  local function processString(quote)
    yield(quote, "string", "quote")
    continueString(quote)
  end

  local function processOperator(operator)
    yield(operator, "operator")
  end

  local function processInvalid(chars)
    yield(chars, "invalid")
  end

  local processors = {
    {"^%s+", processWhitespace},

    {"^[%a_][%w_]*", processIdentifier},

    {"^%d", processNumber},

    {"^%-%-", processComment},

    {"^[\"']", processString},

    {"^%[=*%[", processMultilineString},

    {"^%.%.%.", processOperator},
    {"^%.%.", processOperator},
    {"^%.%d", processNumber},

    {"^::", processOperator},
    {"^~=", processOperator},
    {"^>>", processOperator},
    {"^>=", processOperator},
    {"^==", processOperator},
    {"^<=", processOperator},
    {"^<<", processOperator},
    {"^//", processOperator},

    {"^[%-,;:.()%[%]{}*/&#%^+<=>|~%%]", processOperator},

    {"^[^%w%s_\"'%-,;:.()%[%]{}*/&#%^+<=>|~%%]+", processInvalid},
    {"^.", processInvalid}
  }

  state = state or {}

  local firstToken = line == 1
  if firstToken then
    table.insert(processors, 1, {"^#", processHashComment})
  end

  return coroutine.wrap(function()
    local len = #code
    while pos <= len do
      local kind = state.kind
      if kind then
        local level = state.level
        if level then
          assert(kind == "string" or kind == "comment")
          assert(type(level) == "number")
          continueMultiline(kind, level)
        else
          assert(kind == "string")
          local quote = state.quote
          state.kind = nil
          state.quote = nil
          continueString(quote)
        end
      else
        for i = 1, #processors do
          local match = code:match(processors[i][1], pos)
          if match then
            processors[i][2](match)
            break
          end
        end
      end

      if firstToken then
        table.remove(processors, 1)
        firstToken = false
      end
    end
  end)
end

return {
  tokenize = tokenize,
  tokens = tokens,
  newState = newState
}
