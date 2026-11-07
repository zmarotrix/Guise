-- Other people's profiles, as received, plus what you keep about them (notes, relation, hidden). Account-wide.
--
-- people[name] = {
--   f = { NA = "...", ... }, v = { NA = 3, ... }, tt = n,   -- fields and versions as the owner sent them (raw, unsanitised)
--   seen, zone, opened, answered, asked, quietUntil,        -- times (server seconds) and the zone you last saw them in
--   note, rel, hidden, guid,                                -- yours
-- }
-- Raw text is kept as sent, so versions stay true; everything shown goes through G.Text first.

local G = Guise
local MSP, Text, Profile = G.MSP, G.Text, G.Profile
local Cache = {}
G.Cache = Cache

Cache.KEEP_BIG = 300          -- descriptions kept for the people you opened most recently
Cache.MAX_PEOPLE = 4000
Cache.FORGET_DAYS = 90
Cache.BIG = { DE = true, HI = true, PE = true }
Cache.RELATIONS = { "friend", "ally", "family", "rival", "enemy" }

function Cache:Get(name)
  return name and G.db.people[name]
end

function Cache:Ensure(name)
  local p = G.db.people[name]
  if not p then
    p = { f = {}, v = {} }
    G.db.people[name] = p
  end
  return p
end

---Stores one received field. Returns true if it changed.
function Cache:Set(name, field, ver, value)
  local p = self:Ensure(name)
  local limit = Text.LIMITS[field] or Text.DEFAULT_LIMIT
  value = Text.Cap(value or "", limit)
  local changed = p.f[field] ~= value or (p.v[field] or 0) ~= ver
  p.f[field] = value ~= "" and value or nil
  p.v[field] = ver > 0 and ver or nil
  if field == "TT" then p.tt = ver > 0 and ver or nil end
  return changed
end

function Cache:HasProfile(name)
  local p = self:Get(name)
  return p ~= nil and (p.f.VA ~= nil or p.f.NA ~= nil)
end

function Cache:Seen(name, zone)
  local p = self:Ensure(name)
  p.seen = G.Now()
  if zone and zone ~= "" then p.zone = zone end
end

function Cache:SetNote(name, note)
  local p = self:Ensure(name)
  note = Text.Own(note or "", 2000)
  p.note = note ~= "" and note or nil
  G:Fire("GUISE_PERSON_CHANGED", name)
end

function Cache:SetRelation(name, rel)
  local p = self:Ensure(name)
  p.rel = rel ~= "" and rel or nil
  G:Fire("GUISE_PERSON_CHANGED", name)
end

function Cache:SetHidden(name, hidden)
  local p = self:Ensure(name)
  p.hidden = hidden and true or nil
  G:Fire("GUISE_PERSON_CHANGED", name)
end

function Cache:Forget(name)
  G.db.people[name] = nil
  G:Fire("GUISE_PERSON_CHANGED", name)
end

---Forgets everyone not seen for `days`, except people you wrote a note about or marked.
function Cache:ForgetOld(days)
  local cutoff = G.Now() - (days or Cache.FORGET_DAYS) * 86400
  local n = 0
  for name, p in pairs(G.db.people) do
    if (p.seen or 0) < cutoff and not p.note and not p.rel then
      G.db.people[name] = nil
      n = n + 1
    end
  end
  if n > 0 then G:Fire("GUISE_PERSON_CHANGED") end
  return n
end

---Keeps the saved file small: descriptions only for the people opened most recently, and a cap on people overall.
function Cache:Trim()
  local withBig = {}
  for name, p in pairs(G.db.people) do
    for field in pairs(Cache.BIG) do
      if p.f[field] then withBig[#withBig + 1] = { name, p.opened or 0 } break end
    end
  end
  table.sort(withBig, function(a, b) return a[2] > b[2] end)
  for i = Cache.KEEP_BIG + 1, #withBig do
    local p = G.db.people[withBig[i][1]]
    for field in pairs(Cache.BIG) do p.f[field], p.v[field] = nil, nil end
  end
  local all = {}
  for name, p in pairs(G.db.people) do all[#all + 1] = { name, p.seen or 0, p.note or p.rel } end
  if #all > Cache.MAX_PEOPLE then
    table.sort(all, function(a, b) return a[2] > b[2] end)
    for i = Cache.MAX_PEOPLE + 1, #all do
      if not all[i][3] then G.db.people[all[i][1]] = nil end
    end
  end
end

G:Listen("GUISE_LOGIN", function() Cache:Trim() end)

-------------------------------------------------------------------------------------------
-- A profile, ready to show: every string made safe. Used by the tooltip, the strip, the sheet and the directory.
-------------------------------------------------------------------------------------------

local function plain(f, field, line)
  local s = f[field]
  if not s or s == "" then return nil end
  local limit = Text.LIMITS[field]
  local out = line and Text.Line(s, limit) or Text.Plain(s, limit)
  return out ~= "" and out or nil
end

---View of a person's profile. For yourself, pass name = nil and own = true.
function Cache:View(name, own)
  local f, person
  if own then
    f = Profile:Fields()
    person = {}
  else
    person = self:Get(name)
    if not person then return nil end
    f = person.f
  end
  local rawName, color = Text.SplitNameColor(f.NA or "")
  local view = {
    name = name, own = own,
    rpName = Text.Line(rawName, 60),
    color = Text.Hex(f.XC) or color or nil,
    title = plain(f, "NT", true),
    house = plain(f, "NH", true),
    nickname = plain(f, "NI", true),
    pronouns = plain(f, "PN", true),
    oocPronouns = plain(f, "XP", true),
    race = plain(f, "RA", true),
    class = plain(f, "RC", true),
    age = plain(f, "AG", true), height = plain(f, "AH", true), eyes = plain(f, "AE", true), weight = plain(f, "AW", true),
    motto = plain(f, "MO", true), home = plain(f, "HH", true), birthplace = plain(f, "HB", true),
    currently = plain(f, "CU", true),
    ooc = plain(f, "CO", true),
    status = MSP.STATUS[f.FC or ""],
    statusText = (not MSP.STATUS[f.FC or ""] and f.FC and f.FC ~= "0") and Text.Line(f.FC, 30) or nil,
    style = MSP.STYLE[f.FR or ""] or ((f.FR and f.FR ~= "" and f.FR ~= "0") and Text.Line(f.FR, 30) or nil),
    mature = f.XM == "1",
    addon = f.VA and Text.Line(f.VA, 120) or nil,
    description = f.DE, history = f.HI,
    glances = {},
    note = person.note, rel = person.rel, hidden = person.hidden,
    seen = person.seen, zone = person.zone,
    guise = f.VA ~= nil and f.VA:find("Guise/", 1, true) ~= nil,
  }
  if view.rpName == "" then view.rpName = name and Text.Line(name, 60) or "" end
  for _, g in ipairs(Profile.DecodeGlances(f.PE)) do
    view.glances[#view.glances + 1] = {
      icon = g.icon:gsub("[^%w_]", ""), title = Text.Line(g.title, 40), text = Text.Plain(g.text, 300),
    }
  end
  local bounds = f.XB
  if type(bounds) == "string" and bounds:match("^[yan]+$") then
    view.bounds = {}
    for i, b in ipairs(Profile.BOUNDS) do view.bounds[i] = { key = b[1], label = b[2], value = bounds:sub(i, i) } end
  end
  return view
end

---Should this person's profile be shown in full? (Hidden profiles never; mature ones only if you chose to.)
function Cache.Visible(view)
  if not view then return false end
  if view.hidden then return false end
  if view.mature and not view.own and not G.db.settings.showMature then return false end
  return true
end
