-- GuiseAPI: a small, stable way for other add-ons (unit frames, nameplates, chat, immersion add-ons) to show Guise
-- profiles without knowing how Guise works.
--
-- Add-ons that already read LibMSP's shared `msp` table (msp.char[name].field, msp.my) get Guise profiles with no
-- change: Guise talks through LibMSP. This API adds what LibMSP doesn't have: safe, ready-to-show text, colours split
-- out, glances decoded, and the player's choices respected (hidden profiles, mature profiles).
--
--   GuiseAPI.version                       -> 1
--   GuiseAPI.IsActive()                    -> true unless Guise stepped aside for another profile add-on
--   GuiseAPI.NameForUnit(unit)             -> "First Last" (the name LibMSP and Guise use), or nil (also for secret values)
--   GuiseAPI.GetProfile(nameOrUnit)        -> a table (below), or nil if nothing is known
--   GuiseAPI.Request(nameOrUnit, "tooltip" | "full")  -> asks the player for their profile; true if a request went out
--   GuiseAPI.RegisterCallback(owner, fn)   -> fn(name) whenever someone's profile changes (including yours: name = your own)
--   GuiseAPI.UnregisterCallback(owner)
--
-- GetProfile returns a fresh copy; every string is safe to put in a FontString as is:
--   name, prefix, title, color ("rrggbb" or nil), status ("ic" | "ooc" | "lfc" | "st" | nil), statusText, pronouns,
--   currently, ooc, race, class, age, height, weight, eyes, home, birthplace, nickname, house, motto, relationship,
--   experience, icon, addon ("TotalRP3/3.5.3" ...), glances = { {icon, title, text} }, mature, hidden, restricted
-- When the player hid that profile, or it's mature and they haven't chosen to see mature profiles, only name, color,
-- status, mature and hidden are filled, and `restricted` is true.

local G = Guise
local Cache, Comms, Names = G.Cache, G.Comms, G.Names

local API = { version = 1 }
GuiseAPI = API

local FIELDS = { "prefix", "title", "status", "statusText", "pronouns", "currently", "ooc", "race", "class", "age", "height",
  "weight", "eyes", "home", "birthplace", "nickname", "house", "motto", "relationship", "experience", "icon", "addon" }

local function resolve(nameOrUnit)
  if type(nameOrUnit) ~= "string" or G.IsSecret(nameOrUnit) then return nil end
  if G.Call("UnitExists", nameOrUnit) then
    if G.Call("UnitIsUnit", nameOrUnit, "player") then return Comms:Me(), true end
    return Names:ForUnit(nameOrUnit), false
  end
  return nameOrUnit, nameOrUnit == Comms:Me()
end

function API.IsActive()
  return G.ready == true and not Comms.standby
end

function API.NameForUnit(unit)
  local name = resolve(unit)
  return name
end

function API.GetProfile(nameOrUnit)
  if not API.IsActive() then return nil end
  local name, own = resolve(nameOrUnit)
  if not name then return nil end
  if not own and not Cache:HasProfile(name) then return nil end
  local view = Cache:View(not own and name or nil, own)
  if not view then return nil end
  local out = { name = view.rpName, color = view.color, status = view.status, mature = view.mature, hidden = view.hidden == true }
  if not Cache.Visible(view) then
    out.restricted = true
    return out
  end
  for _, key in ipairs(FIELDS) do out[key] = view[key] end
  out.glances = {}
  for i, g in ipairs(view.glances) do out.glances[i] = { icon = g.icon, title = g.title, text = g.text } end
  return out
end

function API.Request(nameOrUnit, what)
  local name, own = resolve(nameOrUnit)
  if not name or own then return false end
  if what == "full" then return Comms:ForSheet(name) == true end
  return Comms:ForHover(name) == true
end

local callbacks = {}

function API.RegisterCallback(owner, fn)
  if owner == nil or type(fn) ~= "function" then error("GuiseAPI.RegisterCallback(owner, fn)", 2) end
  callbacks[owner] = fn
end

function API.UnregisterCallback(owner)
  callbacks[owner] = nil
end

local function notify(name)
  for _, fn in pairs(callbacks) do
    local ok, err = pcall(fn, name)
    if not ok then G.Error(err) end
  end
end

G:Listen("GUISE_PROFILE_UPDATED", function(name) notify(name) end)
G:Listen("GUISE_PERSON_CHANGED", function(name) if name then notify(name) end end)
G:Listen("GUISE_PROFILE_CHANGED", function() notify(Comms:Me()) end)
