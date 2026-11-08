-- Guise: roleplay profiles for WoW Forever. Plan and client findings: docs/guise-v1.md; the look: design/guise/index.html.
--
-- Two rules run through every file:
--   1. When anything Guise would read is a secret value, it leaves the game's own frames alone. It never compares a secret,
--      turns one into text, or stores one.
--   2. Guise only ever sends add-on messages, never chat text, and only when the game isn't restricting add-on chat.

local ADDON, G = ...
G = G or {}
Guise = G
G.name = ADDON or "Guise"
G.version = "0.2.0"
G.ACCENT = "c9a0ff"

-------------------------------------------------------------------------------------------
-- Calling the client safely. Anything may be missing, raise an error, or answer in secret values.
-------------------------------------------------------------------------------------------

function G.IsSecret(v)
  local check = rawget(_G, "issecretvalue")
  return check ~= nil and check(v) == true
end

---v, or fallback when v is secret or nil.
function G.Safe(v, fallback)
  if v == nil or G.IsSecret(v) then return fallback end
  return v
end

local function clean(ok, ...)
  if not ok then return nil end
  local n = select("#", ...)
  if n == 0 then return nil end
  local out = { ... }
  for i = 1, n do
    if G.IsSecret(out[i]) then out[i] = nil end
  end
  return unpack(out, 1, n)
end

---The global function name(...), with errors and secret values turned into nil.
function G.Call(name, ...)
  local fn = rawget(_G, name)
  if type(fn) ~= "function" then return nil end
  return clean(pcall(fn, ...))
end

---The namespaced function ns.name(...), the same way.
function G.In(ns, name, ...)
  local t = rawget(_G, ns)
  local fn = type(t) == "table" and t[name]
  if type(fn) ~= "function" then return nil end
  return clean(pcall(fn, ...))
end

function G.Now() return G.Call("GetServerTime") or time() end
function G.Clock() return GetTime() end

function G.Print(msg)
  local frame = rawget(_G, "DEFAULT_CHAT_FRAME")
  if frame then frame:AddMessage("|cff" .. G.ACCENT .. "Guise|r " .. tostring(msg)) end
end

-------------------------------------------------------------------------------------------
-- Events and messages between Guise's own files
-------------------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local handlers, listeners = {}, {}

---G:On(event, fn): fn(event, ...) for a game event. Returns false if the client doesn't know the event.
function G:On(event, fn)
  if not handlers[event] then
    local valid = rawget(_G, "C_EventUtils") and C_EventUtils.IsEventValid
    if valid and not valid(event) then return false end
    local ok = pcall(frame.RegisterEvent, frame, event)
    if not ok then return false end
    handlers[event] = {}
  end
  table.insert(handlers[event], fn)
  return true
end

frame:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(handlers[event] or {}) do
    local ok, err = pcall(fn, event, ...)
    if not ok then G.Error(err) end
  end
end)

function G:Listen(msg, fn)
  listeners[msg] = listeners[msg] or {}
  table.insert(listeners[msg], fn)
end

function G:Fire(msg, ...)
  for _, fn in ipairs(listeners[msg] or {}) do
    local ok, err = pcall(fn, ...)
    if not ok then G.Error(err) end
  end
end

function G.Error(err)
  local handler = rawget(_G, "geterrorhandler")
  if handler then handler()(err) end
end

---Runs fn on the next frame; a repeated key coalesces a burst into one call.
local pending = {}
function G:Soon(key, fn)
  if key and pending[key] then pending[key] = fn return end
  if key then pending[key] = fn end
  C_Timer.After(0, function()
    local run = key and pending[key] or fn
    if key then pending[key] = nil end
    local ok, err = pcall(run)
    if not ok then G.Error(err) end
  end)
end

function G:Later(seconds, fn)
  C_Timer.After(seconds, function()
    local ok, err = pcall(fn)
    if not ok then G.Error(err) end
  end)
end

---Runs fn now, or once combat ends. A repeated key replaces the queued call.
local afterCombat, afterOrder = {}, {}
function G:AfterCombat(fn, key)
  if not InCombatLockdown() then fn() return end
  key = key or fn
  if not afterCombat[key] then table.insert(afterOrder, key) end
  afterCombat[key] = fn
end

G:On("PLAYER_REGEN_ENABLED", function()
  local order = afterOrder
  afterOrder = {}
  for _, key in ipairs(order) do
    local fn = afterCombat[key]
    afterCombat[key] = nil
    if fn then
      local ok, err = pcall(fn)
      if not ok then G.Error(err) end
    end
  end
end)

-------------------------------------------------------------------------------------------
-- When Guise may talk, and when it should stay out of the way
-------------------------------------------------------------------------------------------

local function restrictionActive(name)
  local types = rawget(_G, "Enum") and Enum.AddOnRestrictionType
  local value = types and types[name]
  if value == nil then return false end
  return G.In("C_RestrictedActions", "IsAddOnRestrictionActive", value) == true
end

---Why add-on messages can't go out now, or nil when they can.
function G.SendBlocked()
  if G.In("C_ChatInfo", "InChatMessagingLockdown") then return "lockdown" end
  for _, name in ipairs({ "Chat", "Encounter", "ChallengeMode", "PvPMatch" }) do
    if restrictionActive(name) then return name end
  end
  return nil
end

---true in battlegrounds and arenas, where Guise is off unless the player turned it on.
function G.InPvP()
  local _, kind = G.Call("IsInInstance")
  return kind == "pvp" or kind == "arena"
end

function G.Quiet()
  return G.InPvP() and not G.db.settings.inPvP
end

-------------------------------------------------------------------------------------------
-- Saved data
-------------------------------------------------------------------------------------------

G.DEFAULTS = {
  settings = {
    showMature = false,
    inPvP = false,
    tooltip = true,
    strip = true,
    minimap = true,
    bar = true,
    notesOnTooltip = true,
  },
}

local function fill(t, defaults)
  for k, v in pairs(defaults) do
    if t[k] == nil then
      if type(v) == "table" then t[k] = {} fill(t[k], v) else t[k] = v end
    elseif type(v) == "table" and type(t[k]) == "table" then
      fill(t[k], v)
    end
  end
end

G:On("ADDON_LOADED", function(_, name)
  if name ~= G.name then return end
  GuiseDB = type(GuiseDB) == "table" and GuiseDB or {}
  GuiseCharDB = type(GuiseCharDB) == "table" and GuiseCharDB or {}
  G.db, G.char = GuiseDB, GuiseCharDB
  fill(G.db, G.DEFAULTS)
  G.db.people = G.db.people or {}
  G.db.profiles = G.db.profiles or {}
  G.db.ui = G.db.ui or {}
  G.ready = true
  G:Fire("GUISE_LOADED")
end)

G:On("PLAYER_LOGIN", function()
  if not G.ready then return end
  G.loggedIn = true
  G:Fire("GUISE_LOGIN")
end)

-------------------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------------------

G.commands = {}

local function slash(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  local fn = G.commands[cmd]
  if fn then fn(rest) return end
  if cmd == "" and G.commands.sheet then G.commands.sheet("") return end
  G.Print("/guise [sheet | edit | dir | ic | ooc | lfc | st | bar | settings | forget Name]")
end

SLASH_GUISE1 = "/guise"
SlashCmdList.GUISE = slash
-- /rp only when no other add-on has it
if not rawget(_G, "SLASH_RP1") then
  SLASH_GUISERP1 = "/rp"
  SlashCmdList.GUISERP = slash
end
