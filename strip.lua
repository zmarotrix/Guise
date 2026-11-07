-- The glance strip: your target's glances as icons under the target frame. Hover one to read it; the last button opens
-- their sheet. It's Guise's own frame, only anchored to the target frame, and it hides in combat.

local G = Guise
local UI, Cache, Comms, Names = G.UI, G.Cache, G.Comms, G.Names
local Strip = {}
G.Strip = Strip

local SIZE, GAP = 34, 6
local frame, buttons, open
local current       -- name, or "self"

local function anchor()
  frame:ClearAllPoints()
  local target = rawget(_G, "TargetFrame")
  if target and not target:IsForbidden() then
    frame:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 24, 4)
  else
    frame:SetPoint("TOP", UIParent, "TOP", 0, -140)
  end
end

local function build()
  frame = CreateFrame("Frame", "GuiseGlanceStrip", UIParent)
  frame:SetSize(SIZE, SIZE)
  frame:SetFrameStrata("MEDIUM")
  frame:Hide()
  buttons = {}
  for i = 1, G.Profile.MAX_GLANCES do
    local b = UI.IconButton(frame, SIZE)
    b:SetPoint("LEFT", (i - 1) * (SIZE + GAP), 0)
    b.onEnter = function(self)
      if not self.glance then return end
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
      GameTooltip:AddLine(self.glance.title ~= "" and self.glance.title or "At a glance", UI.C.accent.r, UI.C.accent.g, UI.C.accent.b)
      GameTooltip:AddLine(self.glance.text, UI.C.text.r, UI.C.text.g, UI.C.text.b, true)
      GameTooltip:Show()
    end
    b:SetScript("OnClick", function() if G.Sheet then G.Sheet:Open(current, "glances") end end)
    buttons[i] = b
  end
  open = UI.Button(frame, "Sheet", nil, function() if G.Sheet then G.Sheet:Open(current) end end)
  open.tip = "Open their character sheet"
  anchor()
end

function Strip:Update()
  if not frame then return end
  frame:Hide()
  if not G.db.settings.strip or InCombatLockdown() or G.Quiet() or not current then return end
  local view = Cache:View(current ~= "self" and current or nil, current == "self")
  if not view or not Cache.Visible(view) or #view.glances == 0 then return end
  for i, b in ipairs(buttons) do
    local g = view.glances[i]
    b.glance = g
    if g then UI.SetIcon(b.icon, g.icon) b:Show() else b:Hide() end
  end
  open:ClearAllPoints()
  open:SetPoint("LEFT", buttons[#view.glances], "RIGHT", GAP + 2, 0)
  frame:SetWidth(#view.glances * (SIZE + GAP) + open:GetWidth())
  frame:Show()
end

function Strip:OnTarget()
  current = nil
  if G.Call("UnitIsPlayer", "target") then
    if G.Call("UnitIsUnit", "target", "player") then
      current = "self"
    else
      current = Names:ForUnit("target")
      if current then
        Cache:Seen(current, G.Zone())
        if G.db.settings.strip then Comms:ForTarget(current) else Comms:ForHover(current) end
      end
    end
  end
  self:Update()
end

G:Listen("GUISE_LOGIN", function()
  build()
  G:On("PLAYER_TARGET_CHANGED", function() Strip:OnTarget() end)
  G:On("PLAYER_REGEN_DISABLED", function() if frame then frame:Hide() end end)
  G:On("PLAYER_REGEN_ENABLED", function() Strip:Update() end)
end)
G:Listen("GUISE_PROFILE_UPDATED", function(name) if name == current then Strip:Update() end end)
G:Listen("GUISE_PROFILE_CHANGED", function() if current == "self" then Strip:Update() end end)
G:Listen("GUISE_PERSON_CHANGED", function() Strip:Update() end)
G:Listen("GUISE_SETTINGS_CHANGED", function() Strip:Update() end)
