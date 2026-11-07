-- Settings: one list, shown in the editor's Settings tab and on Options > AddOns > Guise.

local G = Guise
local UI = G.UI
local Settings = {}
G.Settings = Settings

Settings.ROWS = {
  { "tooltip", "Profiles on tooltips", "RP name, title, status and more when you hover a player." },
  { "strip", "Glance strip", "Your target's glances under the target frame. Hidden in combat." },
  { "notesOnTooltip", "Your notes on tooltips", "The first line of your private note about someone." },
  { "showMature", "Show mature profiles", "Off: mature profiles show only a name, status and a \"mature\" pill." },
  { "inPvP", "In battlegrounds and arenas", "Off: Guise stays quiet there, as players expect." },
  { "bar", "Guise bar", "Status, sheet, editor and directory. /guise bar puts it back if it's lost." },
  { "minimap", "Minimap button", "Left-click: your profile. Right-click: directory." },
}

---A list of setting rows on `parent`, with :Refresh().
function Settings:Build(parent)
  local scroll = UI.ScrollArea(parent)
  local rows = {}
  local y = 0
  for _, s in ipairs(self.ROWS) do
    local key = s[1]
    local row = UI.Toggle(scroll.content, s[2], s[3], function() return G.db.settings[key] end, function(v)
      G.db.settings[key] = v
      G:Fire("GUISE_SETTINGS_CHANGED")
    end)
    row:SetPoint("TOPLEFT", 0, -y)
    row:SetPoint("RIGHT", -10, 0)
    y = y + row:GetHeight() + 10
    rows[#rows + 1] = row
  end
  scroll.content:SetHeight(y)
  function scroll:Refresh() for _, r in ipairs(rows) do r:Refresh() end end
  return scroll
end

G:Listen("GUISE_LOGIN", function()
  local api = rawget(_G, "Settings")
  if not (api and api.RegisterCanvasLayoutCategory) then return end
  local panel = CreateFrame("Frame")
  panel:Hide()
  local title = UI.Text(panel, "title", 22)
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Guise")
  local list = Settings:Build(panel)
  list:SetPoint("TOPLEFT", 16, -56)
  list:SetPoint("BOTTOMRIGHT", -16, 16)
  local edit = UI.Button(panel, "Edit your profile", "primary", function() G.Editor:Open() end)
  edit:SetPoint("TOPRIGHT", -16, -16)
  panel.OnRefresh = function() list:Refresh() end
  panel:SetScript("OnShow", function() list:Refresh() end)
  local category = api.RegisterCanvasLayoutCategory(panel, "Guise")
  api.RegisterAddOnCategory(category)
  Settings.category = category
end)

G:Listen("GUISE_SETTINGS_CHANGED", function() G:Fire("GUISE_PERSON_CHANGED") end)
