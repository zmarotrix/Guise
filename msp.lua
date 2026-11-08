-- MSP field conventions: how Guise's profile maps onto the fields Total RP 3, MyRolePlay and XRP send, so each can read the
-- others. The wire format itself (MSP2 over Chomp, checksum versions) belongs to LibMSP, embedded unchanged in libs/.
--
-- Where the 2011 spec and today's add-ons disagree, Guise follows the add-ons (Total RP 3's RegisterMSP and XRP agree):
--   FC  status:      "1" out of character, "2" in character, "3" looking for contact, "4" storyteller
--   FR  experience:  "1" new, "2" casual, "3" veteran, "4" guide for new roleplayers (anything else is free text)
--   NA, RC, AE       may carry a |cffrrggbb colour around the text: that's how name, class and eye colours travel
--   PE  glances:     "|TInterface\Icons\name:32:32|t\n#Title\n\nText", glances joined by "\n\n---\n\n"
--   RI RD RR RM RO   accept injury, death, romance, crime, loss of control: "0" not shown, "1" yes, "2" no, "3" ask first
--   RS  relationship "0" not shown, 1 single, 2 taken, 3 married, 4 divorced, 5 widowed
--   PS  personality  [trait value="0.75" id="3"] or [trait value=".." left-name=".." right-name=".." ...]
--   AH, AW           bare numbers are centimetres and kilograms
-- Guise's own extras (other add-ons ignore them): XB boundaries in Guise's order, including walk-ups and combat; XM mature;
-- XP OOC pronouns.

local G = Guise
local MSP = {}
G.MSP = MSP

MSP.STATUS = { ["1"] = "ooc", ["2"] = "ic", ["3"] = "lfc", ["4"] = "st" }
MSP.STATUS_CODE = { ooc = "1", ic = "2", lfc = "3", st = "4" }
MSP.EXPERIENCE = { ["1"] = "New", ["2"] = "Casual", ["3"] = "Veteran", ["4"] = "Guide" }
MSP.EXPERIENCE_CODE = { New = "1", Casual = "2", Veteran = "3", Guide = "4" }

-- boundary letter <-> Total RP 3's style code
MSP.BOUND_CODE = { y = "1", n = "2", a = "3", ["-"] = "0" }
MSP.BOUND_FROM = { ["1"] = "y", ["2"] = "n", ["3"] = "a" }

MSP.RELATIONSHIP = { "Single", "Taken", "Married", "Divorced", "Widowed" }

-- Total RP 3's built-in personality traits, by id: { left, right }. "value" leans to the left one (1 = fully left).
MSP.TRAITS = {
  { "Chaotic", "Lawful" }, { "Chaste", "Lustful" }, { "Forgiving", "Vindictive" }, { "Altruistic", "Selfish" },
  { "Truthful", "Deceitful" }, { "Gentle", "Brutal" }, { "Superstitious", "Rational" }, { "Renegade", "Paragon" },
  { "Cautious", "Impulsive" }, { "Ascetic", "Bon vivant" }, { "Valorous", "Spineless" },
}

-- The tooltip bundle. LibMSP folds a request for any field in someone's bundle into one "TT" request, and answers it with
-- *its own* bundle, so Guise's must hold every field the others put in theirs, or they never get it: Total RP 3 adds
-- CO, IC, PX, RC, RS, TR and PN; XRP adds PX, RC and CO. Guise's own (XM, XP) ride along.
MSP.TOOLTIP = { "PX", "RC", "CO", "IC", "PN", "RS", "TR", "XM", "XP" }
-- what a target or a sheet asks for, beyond the tooltip
MSP.FOR_TARGET = { "TT", "PE", "XB", "RI", "RD", "RR", "RM", "RO" }
MSP.FOR_SHEET = { "TT", "PE", "XB", "RI", "RD", "RR", "RM", "RO", "DE", "HI", "AG", "AH", "AW", "AE", "MO", "HH", "HB",
  "NH", "NI", "RS", "PS", "PG", "PR", "PV", "MU" }

-------------------------------------------------------------------------------------------
-- Glances (PE)
-------------------------------------------------------------------------------------------

local PEEK_SEP = "\n\n---\n\n"

local function iconCode(icon)
  icon = tostring(icon or "")
  if icon:match("^%d+$") then return "|T" .. icon .. ":32:32|t" end
  if icon == "" then icon = "INV_Misc_QuestionMark" end
  return "|TInterface\\Icons\\" .. icon .. ":32:32|t"
end

function MSP.EncodeGlances(glances)
  local out = {}
  for _, g in ipairs(glances or {}) do
    local parts = { iconCode(g.icon), "\n" }
    if g.title and g.title ~= "" then parts[#parts + 1] = "#" .. g.title .. "\n\n" end
    parts[#parts + 1] = g.text or ""
    out[#out + 1] = table.concat(parts)
  end
  return table.concat(out, PEEK_SEP)
end

local function iconOf(str)
  local icon = str:match("|TInterface\\Icons\\([^:|]+)[^|]*|t") or str:match("|T[Ii]nterface/[Ii]cons/([^:|]+)[^|]*|t")
  if icon then return icon end
  local id = str:match("|T(%d+)[^|]*|t")
  if id then return id end
  local path = str:match("|T([^:|]+)[^|]*|t")
  if path then return path:match("([^\\/]+)$") end
  return nil
end

---Reads PE as Total RP 3, MyRolePlay and XRP write it. Up to five glances.
function MSP.DecodeGlances(pe)
  local out = {}
  if type(pe) ~= "string" or pe == "" then return out end
  local index = 1
  while index and #out < 5 do
    local split, nextIndex = pe:find(PEEK_SEP, index, true)
    local block = pe:sub(index, split and split - 1 or #pe)
    index = nextIndex and nextIndex + 1 or nil
    local icon = iconOf(block)
    local title = block:match("%f[^\n%z]#+ *(.-) *%f[\n%z]")
    local text = block:match("%f[^\n%z] *([^|#\n].-)%s*$") or ""
    if icon or title or text ~= "" then
      out[#out + 1] = { icon = icon or "INV_Misc_QuestionMark", title = title or "", text = text }
    end
  end
  return out
end

-------------------------------------------------------------------------------------------
-- Personality traits (PS), read only
-------------------------------------------------------------------------------------------

function MSP.DecodeTraits(ps)
  local out = {}
  if type(ps) ~= "string" then return out end
  for trait in ps:gmatch("%[trait [^%]]-%]") do
    local t = {}
    for key, value in trait:gmatch('([%w_-]+)="([^"]*)"') do t[key] = value end
    local value = tonumber(t.value)
    local id = tonumber(t.id)
    local left, right
    if id and MSP.TRAITS[id] then
      left, right = MSP.TRAITS[id][1], MSP.TRAITS[id][2]
    else
      left, right = t["left-name"], t["right-name"]
    end
    if value and left and right then
      out[#out + 1] = { left = left, right = right, value = math.max(0, math.min(1, value)) }
    end
    if #out >= 20 then break end
  end
  return out
end

-------------------------------------------------------------------------------------------
-- Colours carried in text
-------------------------------------------------------------------------------------------

---"|cffrrggbbName|r" -> "Name", "rrggbb"
function MSP.SplitColor(s)
  if type(s) ~= "string" then return "", nil end
  local color = s:match("|c%x%x(%x%x%x%x%x%x)")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return s, color and color:lower() or nil
end

function MSP.WithColor(text, color)
  if not text or text == "" then return text end
  if color and color:match("^%x%x%x%x%x%x$") then return "|cff" .. color .. text .. "|r" end
  return text
end

---Bare numbers in AH and AW are centimetres and kilograms.
function MSP.Units(field, value)
  if value and tonumber(value) then
    if field == "AH" then return value .. " cm" end
    if field == "AW" then return value .. " kg" end
  end
  return value
end
