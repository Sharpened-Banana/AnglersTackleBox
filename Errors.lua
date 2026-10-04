-- Error catcher. Addons can't send anything over the network, so TackleBox keeps its own recent
-- Lua errors, with stacks and versions, in saved variables; /tb errors shows a report to paste into
-- a GitHub issue. Nothing is swallowed: each error is passed on to the game's handler (and BugSack).
local ADDON, ns = ...
local L = ns.L

local Errors = {}
ns.Errors = Errors

local unpack = unpack or table.unpack -- luacheck: ignore 143 (WoW has unpack; the headless tests run a newer Lua)
local KEPT = 10        -- unique errors kept, newest first
local STACK_LINES = 8  -- stack lines kept per error

local pending = {}     -- errors caught before saved variables load
local forwarding       -- set while handing an error on, so BugGrabber's copy isn't counted twice
local noticed          -- the one chat line a session

local function Store()
  return ns.db and ns.db.errors or pending
end

-- The stack lines from this addon, trimmed, so reports stay short and name our files.
local function OurStack(stack)
  if type(stack) ~= "string" then return "" end
  local lines = {}
  for line in stack:gmatch("[^\n]+") do
    if line:find(ADDON, 1, true) and #lines < STACK_LINES then
      lines[#lines + 1] = line:gsub("^%s+", "")
    end
  end
  return table.concat(lines, "\n")
end

-- Masks changing numbers (IDs, counts, timestamps) but keeps line numbers after ".lua:", which
-- tell bugs apart.
local function MaskNumbers(text)
  return (text:gsub("()(%d+)", function(at, digits)
    if text:sub(math.max(1, at - 5), at - 1) == ".lua:" then return digits end
    return "N"
  end))
end

-- Two errors count as the same bug when this returns the same string: the failing file and line,
-- plus the message's wording with its changing numbers masked. The stack is left out, since one
-- bug can be reached by different routes (an event, the ticker, a click).
function Errors.Key(message, stack)
  message = tostring(message)
  local where, rest = message:match("([%w_]+%.lua:%d+):?%s*(.*)")
  if not where then return MaskNumbers(message) end
  return where .. " " .. MaskNumbers(rest)
end

function Errors:Record(message, stack)
  message = tostring(message)
  local store = Store()
  local key = Errors.Key(message, stack)
  local now = time()
  for index, entry in ipairs(store) do
    if entry.key == key then
      entry.count, entry.last = entry.count + 1, now
      table.insert(store, 1, table.remove(store, index))
      return entry
    end
  end
  local entry = {
    key = key, message = message, stack = OurStack(stack), count = 1, first = now, last = now,
    version = ns.Version and ns.Version() or "?",
  }
  table.insert(store, 1, entry)
  store[KEPT + 1] = nil
  if not noticed and ns.Print and not (ns.db and ns.db.errorNotice == false) then
    noticed = true
    ns:Print(L["TackleBox hit a Lua error. /tb errors shows a report you can send to the author."])
  end
  return entry
end

-- Runs fn(...), recording an error with its stack and passing it on to the game's handler. The
-- addon keeps going either way, so one failing handler doesn't stop the others.
local caughtStack
local function Catch(message)
  caughtStack = debugstack and debugstack(2) or ""
  return message
end

function ns.Safe(fn, ...)
  local count, args = select("#", ...), { ... }
  local ok, err = xpcall(function() return fn(unpack(args, 1, count)) end, Catch)
  if ok then return end
  Errors:Record(err, caughtStack)
  forwarding = true
  local handler = geterrorhandler and geterrorhandler()
  if handler then pcall(handler, err) end
  forwarding = nil
end

-- Errors thrown outside our dispatch (a button's OnClick, say) reach BugGrabber when it's installed.
local function Listen()
  if not (BugGrabber and BugGrabber.RegisterCallback) or Errors.listening then return end
  Errors.listening = true
  BugGrabber.RegisterCallback(Errors, "BugGrabber_BugGrabbed", function(_, bug)
    if forwarding or type(bug) ~= "table" then return end
    local where = tostring(bug.message) .. "\n" .. tostring(bug.stack)
    if where:find(ADDON, 1, true) then Errors:Record(bug.message, bug.stack) end
  end)
end

-- Called once saved variables exist: errors from the loading screen join the saved list.
function Errors:Init()
  for index = #pending, 1, -1 do
    local entry = pending[index]
    for _ = 1, entry.count do self:Record(entry.message, entry.stack) end
  end
  pending = {}
  Listen()
end

function Errors:Count()
  return #Store()
end

function Errors:Clear()
  local store = Store()
  for index = #store, 1, -1 do store[index] = nil end
  noticed = nil
end

-- The text a player pastes into an issue: versions first, then each error with its count and stack.
function Errors:Report()
  local version, build, _, toc = "?", "?", nil, "?"
  if GetBuildInfo then version, build, _, toc = GetBuildInfo() end
  local lines = {
    string.format("Angler's TackleBox %s | WoW %s (%s, interface %s) | %s", ns.Version(), tostring(version),
      tostring(build), tostring(toc), GetLocale and GetLocale() or "?"),
    "",
  }
  for _, entry in ipairs(Store()) do
    lines[#lines + 1] = string.format("[%dx, version %s, last %s] %s", entry.count, entry.version,
      date("%Y-%m-%d %H:%M", entry.last), entry.message)
    if entry.stack ~= "" then lines[#lines + 1] = entry.stack end
    lines[#lines + 1] = ""
  end
  return table.concat(lines, "\n")
end

function Errors:Show()
  if self:Count() == 0 then
    ns:Print(L["No TackleBox errors caught. Thanks for checking!"])
    return
  end
  ns.ShowCopyText(string.format(L["%d TackleBox errors - copy (Ctrl+C) into a GitHub issue"], self:Count()),
    self:Report())
end
