-- Your own profiles. Several per account; each character wears one. What goes out is the worn profile as MSP fields,
-- written the way Total RP 3, MyRolePlay and XRP write them (msp.lua). LibMSP keeps the versions (checksums).

local G = Guise
local MSP, Text = G.MSP, G.Text
local Profile = {}
G.Profile = Profile

Profile.STATUSES = { "ic", "ooc", "lfc", "st" }
Profile.STATUS_LABEL = { ic = "In character", ooc = "Out of character", lfc = "Looking for contact", st = "Storyteller" }
Profile.STATUS_HELP = { ic = "Playing your character now", ooc = "Not playing right now",
  lfc = "Open to a walk-up or a new story", st = "Running a story others can join" }
Profile.STATUS_COLOR = { ic = "7fd18b", ooc = "9aa7b8", lfc = "f2c45a", st = "e98fd0" }

-- boundaries, in Guise's order. `msp` names the field Total RP 3 also uses; walk-ups and combat travel only in XB.
Profile.BOUNDS = {
  { "walkups", "Walk-ups" }, { "combat", "Combat" }, { "injury", "Injury", "RI" }, { "death", "Death", "RD" },
  { "romance", "Romance", "RR" }, { "crime", "Crime", "RM" }, { "control", "Loss of control", "RO" },
}
Profile.BOUND_WORD = { y = "welcome", a = "ask first", n = "not for me", ["-"] = "not shown" }
Profile.EXPERIENCE = { "New", "Casual", "Veteran", "Guide" }
Profile.EXPERIENCE_HELP = { New = "New to roleplay", Casual = "Roleplays now and then", Veteran = "Experienced roleplayer",
  Guide = "Happy to help new roleplayers" }
Profile.MAX_GLANCES = 5

-- editable text fields and their limits
Profile.FIELDS = {
  NA = 60, PX = 30, NT = 80, NI = 40, NH = 60, MO = 120, PN = 30, XP = 30, AG = 30, AH = 40, AW = 40, AE = 40,
  RA = 40, RC = 40, HH = 60, HB = 60, CU = 160, CO = 160, DE = 8000, HI = 8000, PG = 60, PR = 40, PV = 60,
}
Profile.GLANCE_TITLE, Profile.GLANCE_TEXT = 40, 300
local NO_BOUNDS = string.rep("-", #Profile.BOUNDS)

local function me() return G.Call("GetUnitName", "player", true) or G.Call("UnitName", "player") or "?" end

function Profile.ClassColor()
  local _, token = G.Call("UnitClass", "player")
  local colors = rawget(_G, "RAID_CLASS_COLORS")
  local c = colors and token and colors[token]
  if c and type(c.colorStr) == "string" and #c.colorStr == 8 then return c.colorStr:sub(3):lower() end
  if c and c.r then return string.format("%02x%02x%02x", c.r * 255 + 0.5, c.g * 255 + 0.5, c.b * 255 + 0.5) end
  return "c9a0ff"
end

function Profile.New(label)
  return {
    label = label or me(),
    fields = { NA = me(), FC = "2" },
    color = nil,                -- nil: class colour, not sent
    icon = nil,
    glances = {},
    bounds = NO_BOUNDS,
    experience = "Casual",
    relationship = 0,
    mature = false,
  }
end

-- profiles saved by 0.1 had five boundaries in another order, and a "Regular" experience
local function upgrade(p)
  if p.bounds and #p.bounds == 5 then
    local b = p.bounds
    p.bounds = b:sub(1, 1) .. b:sub(2, 2) .. b:sub(3, 3) .. b:sub(5, 5) .. b:sub(4, 4) .. "--"
  end
  if p.experience == "Regular" then p.experience = "Casual" end
  p.bounds = ((p.bounds or "") .. NO_BOUNDS):sub(1, #Profile.BOUNDS)
  p.glances = p.glances or {}
  p.fields = p.fields or {}
  p.relationship = p.relationship or 0
end

---The profile this character wears, made on first use.
function Profile:Current()
  local db = G.db
  local id = G.char.profile
  if not id or not db.profiles[id] then
    id = me()
    if not db.profiles[id] then db.profiles[id] = Profile.New(Text.Short(id) or id) end
    G.char.profile = id
  end
  local p = db.profiles[id]
  if not p.upgraded then upgrade(p) p.upgraded = 2 end
  return p, id
end

function Profile:List()
  local out = {}
  for id, p in pairs(G.db.profiles) do out[#out + 1] = { id = id, label = p.label or id } end
  table.sort(out, function(a, b) return a.label:lower() < b.label:lower() end)
  return out
end

function Profile:Wear(id)
  if not G.db.profiles[id] then return false end
  G.char.profile = id
  self:Changed()
  return true
end

function Profile:Create(label, copyFrom)
  local id = label
  local n = 2
  while G.db.profiles[id] do id = label .. " " .. n n = n + 1 end
  local p
  if copyFrom and G.db.profiles[copyFrom] then
    p = G.CopyTable(G.db.profiles[copyFrom])
    p.label = id
  else
    p = Profile.New(id)
  end
  G.db.profiles[id] = p
  return id
end

function Profile:Delete(id)
  if id == G.char.profile then return false end
  G.db.profiles[id] = nil
  return true
end

function G.CopyTable(t)
  local out = {}
  for k, v in pairs(t) do out[k] = type(v) == "table" and G.CopyTable(v) or v end
  return out
end

-------------------------------------------------------------------------------------------
-- Editing
-------------------------------------------------------------------------------------------

function Profile:Get(field)
  local p = self:Current()
  return p.fields[field] or ""
end

function Profile:Set(field, value)
  local p = self:Current()
  local limit = Profile.FIELDS[field] or Text.DEFAULT_LIMIT
  p.fields[field] = Text.Own(value or "", limit)
  self:Changed()
end

function Profile:Status()
  return MSP.STATUS[self:Get("FC")] or "ic"
end

function Profile:SetStatus(status)
  if not MSP.STATUS_CODE[status] then return end
  local p = self:Current()
  p.fields.FC = MSP.STATUS_CODE[status]
  self:Changed()
  G:Fire("GUISE_STATUS_CHANGED", status)
end

function Profile:SetOption(key, value)
  local p = self:Current()
  p[key] = value
  self:Changed()
end

function Profile:SetGlance(i, icon, title, text)
  local p = self:Current()
  if i < 1 or i > Profile.MAX_GLANCES then return end
  if not icon and not title and not text then
    table.remove(p.glances, i)
  else
    p.glances[i] = {
      icon = (Text.Own(tostring(icon or "INV_Misc_QuestionMark"), 60):gsub("[^%w_]", "")),
      title = (Text.Own(title or "", Profile.GLANCE_TITLE):gsub("[\n#|]", " ")),
      text = (Text.Own(text or "", Profile.GLANCE_TEXT):gsub("\n%-%-%-+\n", "\n")),
    }
  end
  self:Changed()
end

function Profile:SetBound(index, value)
  local p = self:Current()
  if not Profile.BOUND_WORD[value] then return end
  local b = p.bounds or NO_BOUNDS
  p.bounds = b:sub(1, index - 1) .. value .. b:sub(index + 1)
  self:Changed()
end

function Profile:Changed()
  G:Soon("profile-changed", function() G:Fire("GUISE_PROFILE_CHANGED") end)
end

-------------------------------------------------------------------------------------------
-- The worn profile as MSP fields (what goes into LibMSP's msp.my)
-------------------------------------------------------------------------------------------

function Profile:Fields()
  local p = self:Current()
  local f = p.fields
  local out = {}
  for k, v in pairs(f) do
    if v ~= "" then out[k] = v end
  end
  -- colours travel inside the text, as the other add-ons do it
  out.NA = MSP.WithColor(f.NA ~= "" and f.NA or me(), p.color)
  if f.RC and f.RC ~= "" then out.RC = MSP.WithColor(f.RC, p.color) end
  out.FR = MSP.EXPERIENCE_CODE[p.experience] or "2"
  out.FC = f.FC or "2"
  out.PE = MSP.EncodeGlances(p.glances)
  out.IC = p.icon and tostring(p.icon) or nil
  out.RS = tostring(p.relationship or 0)
  local bounds = p.bounds or NO_BOUNDS
  out.XB = bounds
  for i, b in ipairs(Profile.BOUNDS) do
    if b[3] then out[b[3]] = MSP.BOUND_CODE[bounds:sub(i, i)] or "0" end
  end
  out.XM = p.mature and "1" or nil
  out.VA = "Guise/" .. G.version
  for k, v in pairs(out) do if v == "" then out[k] = nil end end
  return out
end
