-- Who a unit is, by the name a whisper can reach. On Forever that's "First Last": UnitName gives only "First", and a
-- whisper to a first name fails ("No player named ..."). Guise tries, in order:
--   1. GetUnitName(unit, true), which gives "Tyrant Kuma" for the player (Muster's /rprobe) and probably for others;
--   2. the unit's GUID, matched to names chat and add-on messages arrived under (they carry the full name and GUID);
--   3. the first name, if exactly one full name with it has been seen.
-- Anything secret ends the search: Guise then does nothing for that unit.

local G = Guise
local Text = G.Text
local Names = { byGuid = {}, byFirst = {} }
G.Names = Names

function Names:Learn(full, guid)
  if G.IsSecret(full) or G.IsSecret(guid) or not Text.IsFull(full) then return end
  if guid and guid ~= "" then self.byGuid[guid] = full end
  local first = Text.Short(full)
  local known = self.byFirst[first]
  if known == nil then
    self.byFirst[first] = full
  elseif known ~= full then
    self.byFirst[first] = false     -- two people share this first name: it can't tell them apart
  end
end

---The name LibMSP knows a unit by ("First Last" on Forever), or nil. Never raises on a secret value.
function Names:ForUnit(unit)
  if not unit or G.IsSecret(unit) then return nil end
  local guid = G.Call("UnitGUID", unit)
  -- what Total RP 3 and XRP use: UnitFullName, merged the way Chomp merges names
  -- On Forever a name without a surname would be merged with the realm into a name nobody has, so it isn't used
  local name, realm = G.Call("UnitFullName", unit)
  local regional = G.Call("RegionalUniqueNamesEnabled")
  local key = name and (not regional or Text.IsFull(name)) and G.Comms and G.Comms.Key(name, realm)
  if key then
    if guid then self.byGuid[guid] = key end
    return key
  end
  local full = G.Call("GetUnitName", unit, true)
  if Text.IsFull(full) then
    if guid then self.byGuid[guid] = full end
    return full
  end
  if guid and self.byGuid[guid] then return self.byGuid[guid] end
  local first = Text.Short(full or G.Call("UnitName", unit))
  local known = first and self.byFirst[first]
  if known then return known end
  return nil
end

function Names:IsMe(name)
  return name ~= nil and G.Comms ~= nil and name == G.Comms:Me()
end

-- every chat line names its sender in full, with a GUID: the cheapest way to learn who's who
local CHAT = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_WHISPER",
  "CHAT_MSG_CHANNEL", "CHAT_MSG_GUILD", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER" }
for _, event in ipairs(CHAT) do
  G:On(event, function(_, _, sender, _, _, _, _, _, _, _, _, _, guid)
    Names:Learn(sender, guid)
  end)
end
