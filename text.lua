-- Text from other players: made safe to show, capped, and the description markup turned into SimpleHTML.
-- A stranger's text never reaches the screen with its own escape codes: no links, textures, colours or atlas icons.

local G = Guise
local Text = {}
G.Text = Text

-- the most Guise keeps of any field, from anyone (characters, not bytes)
Text.LIMITS = {
  NA = 100, PX = 40, NT = 120, NI = 60, NH = 80, MO = 200, PN = 40, XP = 40, AG = 40, AH = 60, AE = 60, AW = 60,
  RA = 60, RC = 80, HH = 80, HB = 80, PG = 80, PR = 60, PV = 80, CU = 300, CO = 300,
  DE = 16000, HI = 16000, PE = 4000, PS = 4000, MU = 120, IC = 120,
  XB = 7, XM = 1, RS = 2, RI = 2, RD = 2, RR = 2, RM = 2, RO = 2, TR = 2,
  FR = 40, FC = 40, VA = 200, VP = 4, GU = 40, GS = 2, GC = 20, GR = 30, GF = 20,
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
-- Rich text from other players: the safe subset other RP add-ons use in descriptions and glances.
-- Colour codes (|cffrrggbb ... |r) and game icons (|TInterface\Icons\name:..|t or |T<file id>:..|t) are kept; every other
-- escape code (links, atlases, keybind and protected text) shows as plain text.
-------------------------------------------------------------------------------------------

local function texture(spec)
  local path = spec:match("^([^:]+)")
  if not path then return "" end
  local icon = path:match("^[Ii]nterface[\\/][Ii]cons[\\/]([%w_]+)$")
  if icon then return "|TInterface\\Icons\\" .. icon .. ":18:18|t" end
  if path:match("^%d+$") then return "|T" .. path .. ":18:18|t" end
  return ""
end

function Text.Rich(s, limit)
  s = Text.Plain(s, limit or Text.DEFAULT_LIMIT)
  s = s:gsub("||c(%x%x%x%x%x%x%x%x)", "|c%1"):gsub("||r", "|r")
  s = s:gsub("||T([^|]-)||t", texture)
  return s .. "|r"
end

-------------------------------------------------------------------------------------------
-- Description markup -> SimpleHTML
--   #Heading or # Heading, ## Smaller heading, > quote, --- (a divider), a blank line starts a paragraph and a single line
--   break stays one; *emphasis*, **strong**, {icon:name}.
-- Total RP 3 sends "#Physical Description" headings and "---" between sections; MyRolePlay sends plain text with line
-- breaks; Total RP 3's own tags ({h1}..{/h1}, {col:rrggbb}, {img:...}, {link*...}) are understood or dropped.
-------------------------------------------------------------------------------------------

local function escapeHtml(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local EMPHASIS, STRONG, QUOTE, RULE = "e8dcc6", "ffffff", "b3a892", "4c4359"
local BREAK = "\2"      -- a line break inside a paragraph, until it becomes <br/>

local function inline(s)
  s = s:gsub("%*%*(.-)%*%*", function(t) return "|cff" .. STRONG .. t .. "|r" end)
  s = s:gsub("%*([^%*\2]-)%*", function(t) return "|cff" .. EMPHASIS .. t .. "|r" end)
  s = s:gsub("{icon:([%w_]+)}", function(name) return "|TInterface\\Icons\\" .. name .. ":16:16|t" end)
  return s
end

local function fromTRP3(s)
  s = s:gsub("{h([123])[^}]*}(.-){/h%1}", function(level, t) return "\n" .. string.rep("#", tonumber(level)) .. " " .. t .. "\n" end)
  s = s:gsub("{icon:([%w_]+):?%d*}", "{icon:%1}")
  s = s:gsub("{col:(%x%x%x%x%x%x)}", "|cff%1"):gsub("{/col}", "|r")
  s = s:gsub("{/?p[^}]*}", "\n")
  s = s:gsub("{img:[^}]*}", ""):gsub("{link%*[^}]*}", ""):gsub("{twitter%*[^}]*}", "")
  return s
end

---Markup -> a SimpleHTML document. A stranger's text is escaped first; only safe colour and icon codes survive.
function Text.Html(src, limit)
  src = Text.Cap(src, limit or Text.LIMITS.DE)
  src = fromTRP3(src)
  src = Text.Rich(src, limit or Text.LIMITS.DE):gsub("|r$", "")
  src = src:gsub(BREAK, "")
  local out, para = { "<html><body>" }, {}
  local function flush()
    if #para > 0 then
      local body = inline(escapeHtml(table.concat(para, BREAK))):gsub(BREAK, "<br/>")
      out[#out + 1] = "<p>" .. body .. "|r</p><br/>"
      para = {}
    end
  end
  for line in (src .. "\n"):gmatch("([^\n]*)\n") do
    local trimmed = line:match("^%s*(.-)%s*$")
    local level, heading = trimmed:match("^(#+)%s*(.+)$")
    local quote = trimmed:match("^>%s?(.*)$")
    if level then
      flush()
      local tag = #level == 1 and "h1" or "h2"
      out[#out + 1] = "<" .. tag .. ">" .. inline(escapeHtml(heading)) .. "|r</" .. tag .. ">"
    elseif trimmed:match("^%-%-%-+$") then
      flush()
      out[#out + 1] = "<p align=\"center\">|cff" .. RULE .. "~  ~  ~|r</p><br/>"
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
