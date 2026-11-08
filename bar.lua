-- The Guise bar: your status in one click, your sheet, the editor and the directory. Movable (drag it), and it can be
-- hidden. Plus a minimap button that opens the editor (left) or the directory (right).

local G = Guise
local UI, Profile = G.UI, G.Profile
local Bar = {}
G.Bar = Bar

local bar, status, minimap

local function statusMenu(owner)
  local menu = rawget(_G, "MenuUtil")
  if not menu or not menu.CreateContextMenu then
    -- no menu API: cycle through the statuses instead
    local order = Profile.STATUSES
    local now = Profile:Status()
    for i, s in ipairs(order) do if s == now then Profile:SetStatus(order[i % #order + 1]) return end end
    return
  end
  menu.CreateContextMenu(owner, function(_, root)
    root:CreateTitle("Your status")
    for _, s in ipairs(Profile.STATUSES) do
      root:CreateRadio("|cff" .. Profile.STATUS_COLOR[s] .. Profile.STATUS_LABEL[s] .. "|r",
        function() return Profile:Status() == s end, function() Profile:SetStatus(s) end)
    end
  end)
end

local function iconButton(parent, icon, tip, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(28, 28)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 4, -4)
  b.icon:SetPoint("BOTTOMRIGHT", -4, 4)
  UI.SetIcon(b.icon, icon)
  b.hl = b:CreateTexture(nil, "HIGHLIGHT")
  b.hl:SetTexture(UI.WHITE)
  b.hl:SetAllPoints()
  b.hl:SetVertexColor(UI.C.accent.r, UI.C.accent.g, UI.C.accent.b, 0.18)
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOM") GameTooltip:SetText(tip, 1, 1, 1) GameTooltip:Show() end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

local function build()
  bar = CreateFrame("Frame", "GuiseBar", UIParent, "BackdropTemplate")
  UI.Panel(bar, UI.C.ink2, UI.C.line)
  bar:SetHeight(36)
  bar:SetClampedToScreen(true)
  bar:SetMovable(true)
  bar:EnableMouse(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function(self) self:StartMoving() end)
  bar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint()
    G.db.ui.bar = { point, rel, x, y }
  end)
  status = CreateFrame("Button", nil, bar)
  status:SetHeight(28)
  status:SetPoint("LEFT", 4, 0)
  status.dot = status:CreateTexture(nil, "ARTWORK")
  status.dot:SetTexture(UI.WHITE)
  status.dot:SetSize(9, 9)
  status.dot:SetPoint("LEFT", 8, 0)
  status.text = UI.Text(status, "body", 13)
  status.text:SetPoint("LEFT", status.dot, "RIGHT", 6, 0)
  status.text:SetWordWrap(false)
  status:SetScript("OnClick", function(self) statusMenu(self) end)
  status:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Your status: click to change", 1, 1, 1)
    GameTooltip:Show()
  end)
  status:SetScript("OnLeave", function() GameTooltip:Hide() end)
  bar.sheet = iconButton(bar, "INV_Misc_Book_09", "Your sheet", function() G.Sheet:Toggle("self") end)
  bar.edit = iconButton(bar, "INV_Feather_05", "Edit your profile", function() G.Editor:Toggle() end)
  bar.dir = iconButton(bar, "INV_Misc_Book_11", "Directory", function() G.Directory:Toggle() end)
  local pos = G.db.ui.bar
  if pos and pos[1] then bar:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
  else bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -150) end
end

function Bar:Update()
  if not bar then return end
  local s = Profile:Status()
  local c = UI.STATUS_COLOR[s]
  status.text:SetText(Profile.STATUS_LABEL[s])
  UI.Color(status.text, c)
  status.dot:SetVertexColor(c.r, c.g, c.b)
  status:SetWidth(status.text:GetStringWidth() + 30)
  bar.sheet:SetPoint("LEFT", status, "RIGHT", 4, 0)
  bar.edit:SetPoint("LEFT", bar.sheet, "RIGHT", 2, 0)
  bar.dir:SetPoint("LEFT", bar.edit, "RIGHT", 2, 0)
  bar:SetWidth(status:GetWidth() + 3 * 30 + 16)
  bar:SetShown(G.db.settings.bar and not G.Quiet() and not G.Comms.standby)
  if minimap then minimap:SetShown(G.db.settings.minimap) end
end

-------------------------------------------------------------------------------------------
-- Minimap button: dragged around the minimap's edge, saved as an angle
-------------------------------------------------------------------------------------------

local function placeMinimap()
  local angle = math.rad(G.db.ui.minimapAngle or 200)
  local r = (Minimap:GetWidth() or 140) / 2 + 6
  minimap:ClearAllPoints()
  minimap:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function buildMinimap()
  minimap = CreateFrame("Button", "GuiseMinimapButton", Minimap)
  minimap:SetSize(32, 32)
  minimap:SetFrameStrata("MEDIUM")
  minimap:SetFrameLevel(8)
  minimap:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  minimap:RegisterForDrag("LeftButton")
  local bg = minimap:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetSize(24, 24)
  bg:SetPoint("CENTER")
  local icon = minimap:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER")
  UI.SetIcon(icon, "INV_Misc_Book_09")
  local border = minimap:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(54, 54)
  border:SetPoint("TOPLEFT")
  minimap:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  minimap:SetScript("OnClick", function(_, button)
    if button == "RightButton" then G.Directory:Toggle() else G.Editor:Toggle() end
  end)
  minimap:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      G.db.ui.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
      placeMinimap()
    end)
  end)
  minimap:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  minimap:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Guise", UI.C.accent.r, UI.C.accent.g, UI.C.accent.b)
    GameTooltip:AddLine("Left-click: your profile", 1, 1, 1)
    GameTooltip:AddLine("Right-click: directory", 1, 1, 1)
    GameTooltip:AddLine("Status: " .. Profile.STATUS_LABEL[Profile:Status()], 0.7, 0.66, 0.57)
    if G.Comms.standby then
      GameTooltip:AddLine("Paused: " .. G.Comms.standby .. " is handling profiles.", 0.88, 0.44, 0.42, true)
    end
    GameTooltip:Show()
  end)
  minimap:SetScript("OnLeave", function() GameTooltip:Hide() end)
  placeMinimap()
end

G:Listen("GUISE_LOGIN", function()
  build()
  buildMinimap()
  Bar:Update()
  G:On("ZONE_CHANGED_NEW_AREA", function() Bar:Update() end)
end)
G:Listen("GUISE_PROFILE_CHANGED", function() Bar:Update() end)
G:Listen("GUISE_STATUS_CHANGED", function() Bar:Update() end)
G:Listen("GUISE_SETTINGS_CHANGED", function() Bar:Update() end)

local function setStatus(s) return function()
  Profile:SetStatus(s)
  G.Print("you're now |cff" .. Profile.STATUS_COLOR[s] .. Profile.STATUS_LABEL[s] .. "|r.")
end end
G.commands.ic, G.commands.ooc, G.commands.lfc, G.commands.st = setStatus("ic"), setStatus("ooc"), setStatus("lfc"), setStatus("st")
G.commands.bar = function()
  G.db.settings.bar = true
  G.db.ui.bar = nil
  if bar then bar:ClearAllPoints() bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -150) end
  G:Fire("GUISE_SETTINGS_CHANGED")
end
