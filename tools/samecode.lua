-- Usage: lua tools/samecode.lua OLD.lua NEW.lua
-- Exits 0 when both files have the same code tokens, ignoring comments,
-- whitespace and line breaks: proof that an edit touched comments only.
local function tokens(path)
  local f = assert(io.open(path, "rb")); local s = f:read("a"); f:close()
  local out, i, n = {}, 1, #s
  local function longBracket(at)
    local eq = s:match("^%[(=*)%[", at)
    if not eq then return nil end
    local close = "]" .. eq .. "]"
    local stop = s:find(close, at + #eq + 2, true)
    assert(stop, "unclosed long bracket in " .. path)
    return stop + #close - 1
  end
  while i <= n do
    local c = s:sub(i, i)
    if c:match("%s") then
      i = i + 1
    elseif s:sub(i, i + 1) == "--" then
      local stop = longBracket(i + 2)
      if stop then i = stop + 1 else i = (s:find("\n", i, true) or n) + 1 end
    elseif c == "[" and longBracket(i) then
      local stop = longBracket(i); out[#out + 1] = s:sub(i, stop); i = stop + 1
    elseif c == '"' or c == "'" then
      local j = i + 1
      while j <= n do
        local d = s:sub(j, j)
        if d == "\\" then j = j + 2 elseif d == c then break else j = j + 1 end
      end
      out[#out + 1] = s:sub(i, j); i = j + 1
    elseif c:match("[%a_]") then
      local w = s:match("^[%w_]+", i); out[#out + 1] = w; i = i + #w
    elseif c:match("%d") or (c == "." and s:sub(i + 1, i + 1):match("%d")) then
      local num = s:match("^0[xX][%x%.]+[pP][%+%-]?%d+", i) or s:match("^0[xX][%x%.]+", i)
        or s:match("^[%d%.]+[eE][%+%-]?%d+", i) or s:match("^[%d%.]+", i)
      out[#out + 1] = num; i = i + #num
    else
      local op = s:match("^%.%.%.", i) or s:match("^%.%.", i) or s:match("^::", i) or s:match("^<<", i)
        or s:match("^>>", i) or s:match("^//", i) or s:match("^[=~<>]=", i) or c
      out[#out + 1] = op; i = i + #op
    end
  end
  return out
end
local a, b = tokens(arg[1]), tokens(arg[2])
for k = 1, math.max(#a, #b) do
  if a[k] ~= b[k] then
    io.stderr:write(string.format("code differs at token %d: %s vs %s\n", k, tostring(a[k]), tostring(b[k])))
    os.exit(1)
  end
end
print(string.format("same code (%d tokens)", #a))
