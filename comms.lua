-- Talking to every MSP add-on through LibMSP, the library Total RP 3, MyRolePlay and XRP share (embedded unchanged with
-- Chomp, its transport). LibMSP answers requests by itself from msp.my; Guise fills msp.my, asks for others' fields, and
-- keeps what arrives in its own cache, which it hands back to LibMSP at the next login so only changes travel.
--
-- One MSP add-on per character: like XRP, if another profile add-on is running, Guise steps aside (it would otherwise
-- answer every request twice) and says so.
--
-- Pacing: LibMSP asks for a field at most every 30 s and leaves people who never answer alone for 5 minutes. Guise adds:
-- nothing is asked during chat lockdown or an encounter, Mythic+ or PvP match restriction, or in battlegrounds unless allowed.

local G = Guise
local MSP, Text, Cache, Names, Profile = G.MSP, G.Text, G.Cache, G.Names, G.Profile
local Comms = { stats = { requests = 0, blocked = 0, received = 0 } }
G.Comms = Comms

-- other profile add-ons, by folder, and the name they give themselves
Comms.OTHERS = { totalRP3 = "Total RP 3", MyRolePlay = "MyRolePlay", xrp = "XRP", totalRP2 = "Total RP 2", GnomTEC_Badge = "GnomTEC Badge" }

local function lib() return rawget(_G, "msp") end
local function chomp() return rawget(_G, "AddOn_Chomp") end

local function enabled(folder)
  local api = rawget(_G, "C_AddOns")
  if api and api.IsAddOnLoaded and api.IsAddOnLoaded(folder) then return true end
  -- not loaded yet (it may load after Guise): is it turned on for this character? Missing add-ons answer 0.
  if api and api.GetAddOnEnableState then
    local ok, state = pcall(api.GetAddOnEnableState, folder, G.Call("UnitName", "player"))
    return ok and type(state) == "number" and state > 0
  end
  return false
end

---The other profile add-on running for this character, if any.
function Comms:OtherAddon()
  local owner = rawget(_G, "msp_RPAddOn")
  if owner and owner ~= "Guise" then return owner end
  for folder, label in pairs(self.OTHERS) do
    if enabled(folder) then return label end
  end
  return nil
end

---The name LibMSP uses for a player ("First Last" on Forever), or nil.
function Comms.Key(name, realm)
  if type(name) ~= "string" or name == "" or G.IsSecret(name) or G.IsSecret(realm) then return nil end
  local c = chomp()
  if c and c.NameMergedRealm then
    local ok, key = pcall(c.NameMergedRealm, name, realm)
    if ok and type(key) == "string" then return key end
    return nil
  end
  return Text.IsFull(name) and name or nil
end

function Comms:Me()
  if not self.me then
    local name, realm = G.Call("UnitFullName", "player")
    self.me = Comms.Key(name, realm) or G.Call("GetUnitName", "player", true)
  end
  return self.me
end

-------------------------------------------------------------------------------------------
-- Our profile out
-------------------------------------------------------------------------------------------

local published = {}

function Comms:Publish()
  local m = lib()
  if self.standby or not m or not G.loggedIn then return end
  local fields = Profile:Fields()
  local internal = m.INTERNAL_FIELDS or {}
  for field in pairs(published) do
    if fields[field] == nil and not internal[field] then m.my[field] = nil end
  end
  published = {}
  for field, value in pairs(fields) do
    if not internal[field] then
      m.my[field] = value
      published[field] = true
    end
  end
  local ok, err = pcall(m.Update, m)
  if not ok then G.Error(err) end
end

-------------------------------------------------------------------------------------------
-- Asking
-------------------------------------------------------------------------------------------

local function ignored(name)
  return G.In("C_FriendList", "IsIgnored", name) == true
end

function Comms:CanSend()
  if not G.ready or not G.loggedIn then return false, "loading" end
  if self.standby then return false, "standby" end
  if not lib() then return false, "no library" end
  if G.Quiet() then return false, "pvp" end
  local blocked = G.SendBlocked()
  if blocked then return false, blocked end
  return true
end

---Asks `name` for fields. Returns true if LibMSP sent a request (it skips fields asked in the last 30 s).
function Comms:Request(name, fields)
  if not name or name == self:Me() or ignored(name) then return false end
  local ok, why = self:CanSend()
  if not ok then self.stats.blocked = self.stats.blocked + 1 return false, why end
  local m = lib()
  local sent, result = pcall(m.Request, m, name, fields)
  if not sent then return false, "error" end
  if result then
    self.stats.requests = self.stats.requests + 1
    Cache:Ensure(name).asked = G.Now()
  end
  return result == true
end

function Comms:ForHover(name) return self:Request(name, { "TT" }) end
function Comms:ForTarget(name) return self:Request(name, MSP.FOR_TARGET) end
function Comms:ForSheet(name) return self:Request(name, MSP.FOR_SHEET) end

-------------------------------------------------------------------------------------------
-- Their profiles in
-------------------------------------------------------------------------------------------

local changed = {}

local function onUpdated(name, field, contents, version)
  if type(name) ~= "string" or type(field) ~= "string" or name == Comms:Me() then return end
  if ignored(name) then return end
  if Cache:Set(name, field, version, contents) then
    changed[name] = changed[name] or {}
    changed[name][field] = true
    G:Soon("received:" .. name, function()
      local fields = changed[name]
      changed[name] = nil
      if fields then G:Fire("GUISE_PROFILE_UPDATED", name, fields) end
    end)
  end
end

local function onReceived(name)
  if type(name) ~= "string" or name == Comms:Me() then return end
  Comms.stats.received = Comms.stats.received + 1
  local p = Cache:Get(name)
  if p then
    p.answered = G.Now()
    p.seen = p.seen or G.Now()
  end
end

-- LibMSP asks, the first time it meets a name in a session, what we already know: hand it the cache, so it asks only
-- for what changed since
local function onDataLoad(name, char)
  local p = Cache:Get(name)
  if not p or type(char) ~= "table" then return end
  for field, value in pairs(p.f) do char.field[field] = value end
  for field, ver in pairs(p.v) do char.ver[field] = ver end
  if p.tt then char.ver.TT = p.tt end
end

G:Listen("GUISE_LOADED", function()
  local other = Comms:OtherAddon()
  local m = lib()
  if other then
    Comms.standby = other
    return
  end
  if not m then return end
  msp_RPAddOn = "Guise"
  m:AddFieldsToTooltip(MSP.TOOLTIP)
  table.insert(m.callback.updated, onUpdated)
  table.insert(m.callback.received, onReceived)
  table.insert(m.callback.dataload, onDataLoad)
end)

G:Listen("GUISE_LOGIN", function()
  if Comms.standby then
    G.Print(Comms.standby .. " is running, so Guise is paused: two profile add-ons would answer every request twice. " ..
      "Turn one of them off in the AddOns list to use the other.")
    return
  end
  Comms:Publish()
end)

G:Listen("GUISE_PROFILE_CHANGED", function() Comms:Publish() end)
