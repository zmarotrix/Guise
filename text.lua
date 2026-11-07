-- Text from other players: made safe to show, capped, and the description markup turned into SimpleHTML.
-- A stranger's text never reaches the screen with its own escape codes: no links, textures, colours or atlas icons.

local G = Guise
local Text = {}
G.Text = Text

-- the most Guise keeps of any field, from anyone (characters, not bytes)
Text.LIMITS = {
  NA = 60, NT = 60, NI = 40, NH = 60, PN = 30, XP = 30, AG = 30, AH = 40, AE = 40, AW = 40, RA = 40, RC = 40,
  CU = 200, CO = 200, MO = 120, HH = 60, HB = 60, DE = 8000, HI = 8000, PE = 2000, XB = 10, XM = 1, XC = 6,
  FR = 30, FC = 30, VA = 120, VP = 4, GU = 40, GS = 2, GC = 20, GR = 30, TT = 0,
}
Text.DEFAULT_LIMIT = 200

---Removes control characters except line breaks, and caps the length (at a UTF-8 boundary).
function Text.Cap(s, limit)
  if type(s) ~= "string" then return "" end
  s = s:gsub("\r\n", "\n"):gsub("[%z\1-\9\11-\31]", "")
  if limit and #s > limit then
    s = s:sub(1, limit)
    -- don't leave half a character behind
    s = s:gsub("[\192-\255][\128-\191]*$", "")
  end
  return s
end

---Plain text from a stranger, safe for a FontString: every "|" shows as itself, so no escape code can run.
function Text.Plain(s, limit)
  s = Text.Cap(s, limit or Text.DEFAULT_LIMIT)
  return (s:gsub("|", "||"))
end

---A single line: line breaks become spaces.
function Text.Line(s, limit)
  return (Text.Plain(s, limit):gsub("\n+", " "))
end

---MSP add-ons often colour the name with a leading |cffrrggbb. Returns the bare name and the colour, if any.
function Text.SplitNameColor(s)
  if type(s) ~= "string" then return "", nil end
  local color, rest = s:match("^|c%x%x(%x%x%x%x%x%x)(.*)$")
  if color then s = rest:gsub("|r$", "") return s, color:lower() end
  return s, nil
end

function Text.Hex(s)
  if type(s) == "string" and s:match("^%x%x%x%x%x%x$") then return s:lower() end
  return nil
end

---Text Guise itself stores for the player: no "\1" (MSP's separator) or "\0"; other text is kept as typed.
function Text.Own(s, limit)
  s = Text.Cap(s, limit)
  return (s:gsub("[%z\1]", ""))
end

-------------------------------------------------------------------------------------------
-- Names. Forever characters have a first and a last name; chat gives both, UnitName only the first.
-------------------------------------------------------------------------------------------

---The first name from any form: "Tyrant Kuma", "Tyrant-Realm" and "Tyrant" are all "Tyrant".
function Text.Short(name)
  if type(name) ~= "string" or G.IsSecret(name) then return nil end
  return name:match("^([^%s%-]+)")
end

function Text.IsFull(name)
  return type(name) == "string" and not G.IsSecret(name) and name:find(" ", 1, true) ~= nil
end

-------------------------------------------------------------------------------------------
-- Description markup -> SimpleHTML
--   # Heading, ## Smaller heading, > quote, blank line = new paragraph, *emphasis*, **strong**, {icon:name}
-- Total RP 3's own tags ({h1}..{/h1}, {h2}, {h3}, {p:c}, {col:rrggbb}, {img:...}, {link*...}) are understood or dropped.
-------------------------------------------------------------------------------------------

local function escapeHtml(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local EMPHASIS, STRONG, QUOTE = "e8dcc6", "ffffff", "b3a892"

local function inline(s)
  s = s:gsub("%*%*(.-)%*%*", function(t) return "|cff" .. STRONG .. t .. "|r" end)
  s = s:gsub("%*(.-)%*", function(t) return "|cff" .. EMPHASIS .. t .. "|r" end)
  s = s:gsub("{icon:([%w_]+)}", function(name) return "|TInterface\\Icons\\" .. name .. ":16:16|t" end)
  return s
end

local function fromTRP3(s)
  s = s:gsub("{h([123])[^}]*}(.-){/h%1}", function(level, t) return "\n" .. string.rep("#", tonumber(level)) .. " " .. t .. "\n" end)
  s = s:gsub("{icon:([%w_]+):?%d*}", "{icon:%1}")
  s = s:gsub("{col:%x+}", ""):gsub("{/col}", "")
  s = s:gsub("{/?p[^}]*}", "\n")
  s = s:gsub("{img:[^}]*}", ""):gsub("{link%*[^}]*}", ""):gsub("{twitter%*[^}]*}", "")
  return s
end

---Markup -> a SimpleHTML document. Anything a stranger wrote is escaped first; only Guise's own codes are added.
function Text.Html(src, limit)
  src = Text.Cap(src, limit or Text.LIMITS.DE)
  src = fromTRP3(src)
  src = src:gsub("|", "||")
  local out, para = { "<html><body>" }, {}
  local function flush()
    if #para > 0 then
      out[#out + 1] = "<p>" .. inline(escapeHtml(table.concat(para, " "))) .. "</p><br/>"
      para = {}
    end
  end
  for line in (src .. "\n"):gmatch("([^\n]*)\n") do
    local trimmed = line:match("^%s*(.-)%s*$")
    local level, heading = trimmed:match("^(#+)%s+(.+)$")
    local quote = trimmed:match("^>%s?(.*)$")
    if level then
      flush()
      local tag = #level == 1 and "h1" or "h2"
      out[#out + 1] = "<" .. tag .. ">" .. inline(escapeHtml(heading)) .. "</" .. tag .. ">"
    elseif quote then
      flush()
      out[#out + 1] = "<p>|cff" .. QUOTE .. "    " .. inline(escapeHtml(quote)) .. "|r</p>"
    elseif trimmed == "" then
      flush()
    else
      para[#para + 1] = trimmed
    end
  end
  flush()
  out[#out + 1] = "</body></html>"
  return table.concat(out)
end
