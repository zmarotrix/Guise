-- Your own profiles. Several per account; each character wears one. What goes out is the worn profile as MSP fields.
--
-- Versions belong to the character, not the profile: other players cache by character, so switching costume must look
-- like a change to them. Every field remembers what was last served and its version, which rises whenever it differs.

local G = Guise
local MSP, Text = G.MSP, G.Text
local Profile = {}
G.Profile = Profile

Profile.STATUSES = { "ic", "ooc", "lfc", "st" }
Profile.STATUS_LABEL = { ic = "In character", ooc = "Out of character", lfc = "Looking for contact", st = "Storyteller" }
Profile.STATUS_HELP = { ic = "Playing your character now", ooc = "Not playing right now",
  lfc = "Open to a walk-up or a new story", st = "Running a story others can join" }
Profile.STATUS_COLOR = { ic = "7fd18b", ooc = "9aa7b8", lfc = "f2c45a", st = "e98fd0" }

Profile.BOUNDS = { { "walkups", "Walk-ups" }, { "combat", "Combat" }, { "injury", "Injury" }, { "romance", "Romance" }, { "death", "Death" } }
Profile.BOUND_WORD = { y = "welcome", a = "ask first", n = "not for me" }
Profile.EXPERIENCE = { "New", "Casual", "Regular", "Veteran" }
Profile.MAX_GLANCES = 5

-- what the editor offers, with limits (MSP field, label, limit)
Profile.FIELDS = {
  NA = 60, NT = 60, PN = 30, XP = 30, AG = 30, AH = 40, AE = 40, RA = 40, RC = 40, CU = 160, CO = 160, DE = 8000,
}
Profile.GLANCE_TITLE, Profile.GLANCE_TEXT = 40, 300

local function me() return G.Call("GetUnitName", "player", true) or G.Call("UnitName", "player") or "?" end

local function classColor()
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
    fields = { NA = me(), FC = "2", PN = "" },
    color = classColor(),
    glances = {},
    bounds = "aaaaa",
    experience = "Casual",
    mature = false,
  }
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
  return db.profiles[id], id
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
      icon = Text.Own(tostring(icon or "INV_Misc_QuestionMark"), 60):gsub("[^%w_]", ""),
      title = Text.Own(title or "", Profile.GLANCE_TITLE):gsub("\n", " "),
      text = Text.Own(text or "", Profile.GLANCE_TEXT):gsub("\n%-%-%-+\n", "\n"),
    }
  end
  self:Changed()
end

function Profile:SetBound(index, value)
  local p = self:Current()
  if not Profile.BOUND_WORD[value] then return end
  local b = (p.bounds or "aaaaa") .. string.rep("a", 5)
  p.bounds = b:sub(1, index - 1) .. value .. b:sub(index + 1, 5)
  self:Changed()
end

function Profile:Changed()
  G:Soon("profile-changed", function() G:Fire("GUISE_PROFILE_CHANGED") end)
end

-------------------------------------------------------------------------------------------
-- Glances travel in PE: "icon\ntitle\ntext" per glance, joined by "\n\n---\n\n"
-------------------------------------------------------------------------------------------

function Profile.EncodeGlances(glances)
  local parts = {}
  for _, g in ipairs(glances or {}) do
    parts[#parts + 1] = (g.icon or "") .. "\n" .. (g.title or "") .. "\n" .. (g.text or "")
  end
  return table.concat(parts, "\n\n---\n\n")
end

---Reads PE from anyone. A PE that isn't in Guise's shape shows as one glance, so nothing is lost.
function Profile.DecodeGlances(pe)
  local out = {}
  if type(pe) ~= "string" or pe == "" then return out end
  for block in (pe .. "\n\n---\n\n"):gmatch("(.-)\n\n%-%-%-\n\n") do
    local icon, title, text = block:match("^([%w_]*)\n([^\n]*)\n(.*)$")
    if icon then
      out[#out + 1] = { icon = icon ~= "" and icon or "INV_Misc_QuestionMark", title = title, text = text }
    elseif block ~= "" then
      out[#out + 1] = { icon = "INV_Misc_QuestionMark", title = "At a glance", text = block }
    end
    if #out >= Profile.MAX_GLANCES then break end
  end
  return out
end

-------------------------------------------------------------------------------------------
-- The worn profile as MSP fields, with versions
-------------------------------------------------------------------------------------------

local function gameFields(out)
  local guid = G.Call("UnitGUID", "player")
  if guid then out.GU = guid end
  local sex = G.Call("UnitSex", "player")
  if sex then out.GS = tostring(sex) end
  local _, class = G.Call("UnitClass", "player")
  if class then out.GC = class end
  local _, race = G.Call("UnitRace", "player")
  if race then out.GR = race end
end

function Profile:Fields()
  local p = self:Current()
  local out = {}
  for k, v in pairs(p.fields) do out[k] = v end
  out.FR = MSP.STYLE_CODE[p.experience] or p.experience or ""
  out.PE = Profile.EncodeGlances(p.glances)
  out.XB = p.bounds or ""
  out.XM = p.mature and "1" or ""
  out.XC = p.color or ""
  out.VA = "Guise/" .. G.version
  out.VP = MSP.PROTOCOL
  gameFields(out)
  return out
end

---Brings versions up to date with what the worn profile says now. Returns { fields, versions, tt } for MSP.Answer.
function Profile:Served()
  local char = G.char
  char.served = char.served or {}
  char.versions = char.versions or {}
  char.tt = char.tt or 1
  local fields = self:Fields()
  local ttChanged = false
  local all = {}
  for k in pairs(fields) do all[k] = true end
  for k in pairs(char.served) do all[k] = true end
  for field in pairs(all) do
    local now = fields[field] or ""
    if char.served[field] ~= now then
      char.served[field] = now
      char.versions[field] = (char.versions[field] or 0) + 1
      if MSP.IN_TT[field] then ttChanged = true end
    end
  end
  if ttChanged then char.tt = char.tt + 1 end
  return { fields = fields, versions = char.versions, tt = char.tt }
end
