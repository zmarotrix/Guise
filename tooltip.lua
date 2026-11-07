-- The unit tooltip: RP name in its colour on the first line, then title, status and pronouns, what they're doing, their
-- OOC note, glance icons and your own note. The game's lines (level, race, guild) stay as they are.
-- If the game hands Guise a secret unit or name, the tooltip is left exactly as the game drew it.

local G = Guise
local UI, Cache, Comms, Names, Profile, Text = G.UI, G.Cache, G.Comms, G.Names, G.Profile, G.Text
local Tooltip = {}
G.Tooltip = Tooltip

local MUTED, FAINT, TEXT, OOC, NOTE, ACCENT = "b3a892", "7d7465", "ece3d3", "9aa7b8", "d9c37a", G.ACCENT

function G.Zone()
  return G.Call("GetRealZoneText") or G.Call("GetZoneText")
end

local function nameColor(view)
  return view.color or MUTED
end

---The lines Guise adds, for the tooltip and for the editor's preview. Returns { first = "...", lines = { {text, wrap} } }.
function Tooltip.Lines(view)
  local out = { first = "|cff" .. nameColor(view) .. view.rpName .. "|r", lines = {} }
  local function add(text, wrap) out.lines[#out.lines + 1] = { text, wrap } end
  if not Cache.Visible(view) then
    local status = view.status and Profile.STATUS_LABEL[view.status]
    add((status and ("|cff" .. Profile.STATUS_COLOR[view.status] .. status .. "|r  ") or "") .. "|cffe0716bMature profile|r")
    add("|cff" .. FAINT .. "Shown in full if you turn on mature profiles (/guise settings).|r", true)
    return out
  end
  if view.title then add("|cff" .. MUTED .. view.title .. "|r", true) end
  local status
  if view.status then
    status = "|cff" .. Profile.STATUS_COLOR[view.status] .. Profile.STATUS_LABEL[view.status] .. "|r"
  elseif view.statusText then
    status = "|cff" .. MUTED .. view.statusText .. "|r"
  end
  local pronouns = view.pronouns and ("|cff" .. MUTED .. view.pronouns .. (view.oocPronouns and (" · OOC " .. view.oocPronouns) or "") .. "|r")
  if status or pronouns then add(table.concat({ status, pronouns }, "   ")) end
  if view.currently then add("|cff" .. ACCENT .. "Currently:|r |cff" .. TEXT .. view.currently .. "|r", true) end
  if view.ooc then add("|cff" .. OOC .. "OOC: " .. view.ooc .. "|r", true) end
  if #view.glances > 0 then
    local icons = {}
    for _, g in ipairs(view.glances) do
      local path = g.icon:match("^%d+$") and g.icon or ("Interface\\Icons\\" .. g.icon)
      icons[#icons + 1] = "|T" .. path .. ":18:18:0:0:64:64:5:59:5:59|t"
    end
    add(table.concat(icons, " "))
  end
  if not view.own and view.note and G.db.settings.notesOnTooltip then
    add("|cff" .. NOTE .. (view.note:match("^[^\n]*"):gsub("|", "||")) .. "|r", true)
  end
  if view.rel then add("|cff" .. MUTED .. view.rel:gsub("^%l", string.upper) .. "|r") end
  return out
end

local shown            -- the name on the tooltip now

local function decorate(tip, view)
  local lines = Tooltip.Lines(view)
  local left1 = _G[(tip:GetName() or "GameTooltip") .. "TextLeft1"]
  if left1 then
    local text = left1:GetText()
    if not G.IsSecret(text) then left1:SetText(lines.first) end
  end
  for _, line in ipairs(lines.lines) do tip:AddLine(line[1], 1, 1, 1, line[2]) end
end

function Tooltip.OnUnit(tip)
  if tip ~= GameTooltip or not G.ready or not G.db.settings.tooltip or G.Quiet() then return end
  local ok, _, unit = pcall(tip.GetUnit, tip)
  if not ok or not unit or G.IsSecret(unit) then return end
  if not G.Call("UnitIsPlayer", unit) then return end
  local own = G.Call("UnitIsUnit", unit, "player") == true
  local name
  if not own then
    name = Names:ForUnit(unit)
    if not name then return end
    Cache:Seen(name, G.Zone())
    Comms:ForHover(name)
    shown = name
    if not Cache:HasProfile(name) then return end
  end
  local view = Cache:View(name, own)
  if not view or view.hidden then return end
  local ok2, err = pcall(decorate, tip, view)
  if not ok2 then G.Error(err) end
end

G:Listen("GUISE_LOGIN", function()
  local proc = rawget(_G, "TooltipDataProcessor")
  if proc and proc.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    proc.AddTooltipPostCall(Enum.TooltipDataType.Unit, Tooltip.OnUnit)
  elseif GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipSetUnit", Tooltip.OnUnit)
  end
end)

-- an answer arrived while the tooltip is up: draw it again
G:Listen("GUISE_PROFILE_UPDATED", function(name)
  if name ~= shown or not GameTooltip:IsShown() then return end
  if Names:ForUnit("mouseover") ~= name then return end
  pcall(GameTooltip.SetUnit, GameTooltip, "mouseover")
end)
