-- The Mary Sue Protocol (MSP), written for Guise from the public spec (moonshyne.org/msp, CC0). It's the profile protocol
-- Total RP 3, MyRolePlay and XRP share, so their users and Guise's see each other's profiles.
--
-- Wire format, all add-on whispers:
--   prefix "MSP" for a one-part message; "MSP\1" first part, "MSP\2" middle parts, "MSP\3" last part of a longer one.
--   A message is chunks joined by "\1":
--     "?NA" or "?NA3"     request field NA (conditionally: only if my version isn't 3)
--     "NA3=Mira"          field NA is "Mira", version 3 ("NA3" alone: empty; "NA=Mira": unversioned)
--     "!NA3"              NA is still version 3: nothing changed
--   "?TT" asks for the tooltip bundle: VP, VA, NA, NH, NI, NT, RA, FR, FC, CU and TT itself.
--
-- This file is pure: it builds and reads text. comms.lua sends it.

local G = Guise
local MSP = {}
G.MSP = MSP

MSP.PREFIX = "MSP"
MSP.PREFIXES = { "MSP", "MSP\1", "MSP\2", "MSP\3" }
MSP.PART = 255                  -- bytes per add-on message
MSP.SEP = "\1"
MSP.PROTOCOL = "1"

-- the bundle the spec names, plus the fields Guise's tooltip shows (other add-ons ignore the ones they don't know)
MSP.TT = { "VP", "VA", "NA", "NH", "NI", "NT", "RA", "FR", "FC", "CU" }
MSP.TT_EXTRA = { "PN", "CO", "RC", "XC", "XM", "XB", "XP" }
MSP.IN_TT = {}
for _, f in ipairs(MSP.TT) do MSP.IN_TT[f] = true end
for _, f in ipairs(MSP.TT_EXTRA) do MSP.IN_TT[f] = true end

-- what each kind of look asks for, beyond TT
MSP.FOR_TARGET = { "PE" }
MSP.FOR_SHEET = { "PE", "DE", "HI", "AG", "AH", "AE", "AW", "MO", "HH", "HB" }

-- MSP's status (FC) and style (FR) codes
MSP.STATUS = { ["1"] = "ooc", ["2"] = "ic", ["3"] = "lfc", ["4"] = "st" }
MSP.STATUS_CODE = { ooc = "1", ic = "2", lfc = "3", st = "4" }
MSP.STYLE = { ["1"] = "Regular", ["2"] = "Casual", ["3"] = "Full-time", ["4"] = "New" }
MSP.STYLE_CODE = { Regular = "1", Casual = "2", New = "4" }   -- Veteran has no code: it travels as text

---"?FIELDver" for each field; ver from the versions we hold (0 or nil: ask for it outright).
function MSP.Requests(fields, versions)
  local out = {}
  for _, field in ipairs(fields) do
    local ver = versions and versions[field]
    out[#out + 1] = "?" .. field .. ((ver and ver > 0) and tostring(ver) or "")
  end
  return out
end

---One field's answer: "FIELDver=value", "FIELDver" when empty.
function MSP.Field(field, ver, value)
  local v = (ver and ver > 0) and tostring(ver) or ""
  if value == nil or value == "" then return field .. v end
  return field .. v .. "=" .. value
end

---Reads one chunk. Returns kind ("?", "!" or "="), field, version (number, 0 if none), value (for "=").
function MSP.ParseChunk(chunk)
  if type(chunk) ~= "string" then return nil end
  local first = chunk:sub(1, 1)
  if first == "?" or first == "!" then
    local field, ver = chunk:match("^.(%u%u)(%d*)$")
    if not field then return nil end
    return first, field, tonumber(ver) or 0
  end
  local field, ver, rest = chunk:match("^(%u%u)(%d*)(.*)$")
  if not field then return nil end
  if rest ~= "" and rest:sub(1, 1) ~= "=" then return nil end
  return "=", field, tonumber(ver) or 0, rest:sub(2)
end

function MSP.Split(text)
  local chunks = {}
  for chunk in (text .. MSP.SEP):gmatch("(.-)" .. MSP.SEP) do
    if chunk ~= "" then chunks[#chunks + 1] = chunk end
  end
  return chunks
end

---Chunks -> the messages to send: { {prefix, text}, ... }. One part uses "MSP"; more use MSP\1, \2..., \3.
function MSP.Pack(chunks)
  local text = table.concat(chunks, MSP.SEP)
  if #text <= MSP.PART then return { { MSP.PREFIX, text } } end
  local parts = {}
  local i = 1
  while i <= #text do
    local j = i + MSP.PART - 1
    -- don't split a UTF-8 character across parts: receivers join them back, but some show parts as they come
    while j < #text and j > i and text:byte(j + 1) and text:byte(j + 1) >= 128 and text:byte(j + 1) < 192 do j = j - 1 end
    parts[#parts + 1] = text:sub(i, j)
    i = j + 1
  end
  local out = {}
  for n, part in ipairs(parts) do
    local prefix = n == 1 and "MSP\1" or (n == #parts and "MSP\3" or "MSP\2")
    out[#out + 1] = { prefix, part }
  end
  return out
end

-------------------------------------------------------------------------------------------
-- Answering requests from our own fields
-------------------------------------------------------------------------------------------

---Builds the reply to a list of request chunks.
---own = { fields = {NA = "..."}, versions = {NA = 3}, tt = ttVersion }
---Returns the reply chunks, and whether it holds a big field (DE, HI, PE), which callers pace.
function MSP.Answer(requests, own)
  local out, seen, big = {}, {}, false
  local function add(field, asked)
    if seen[field] then return end
    seen[field] = true
    local ver = own.versions[field] or 0
    if asked and asked > 0 and asked == ver then
      out[#out + 1] = "!" .. field .. ver
    else
      out[#out + 1] = MSP.Field(field, ver, own.fields[field])
      if field == "DE" or field == "HI" or field == "PE" then big = true end
    end
  end
  for _, chunk in ipairs(requests) do
    local kind, field, ver = MSP.ParseChunk(chunk)
    if kind == "?" then
      if field == "TT" then
        if ver > 0 and ver == own.tt then
          if not seen.TT then seen.TT = true out[#out + 1] = "!TT" .. own.tt end
        else
          for _, f in ipairs(MSP.TT) do add(f) end
          for _, f in ipairs(MSP.TT_EXTRA) do add(f) end
          if not seen.TT then seen.TT = true out[#out + 1] = MSP.Field("TT", own.tt) end
        end
      else
        add(field, ver)
      end
    end
  end
  return out, big
end
