-- The character sheet: one window for anyone, yourself included. Header (name, title, status, facts, boundaries), then
-- tabs: At a glance, Description, Your notes (not for yourself).

local G = Guise
local UI, Cache, Comms, Profile, Text = G.UI, G.Cache, G.Comms, G.Profile, G.Text
local Sheet = {}
G.Sheet = Sheet

local W, H = 700, 600
local win, header, tabs, panes, foot, hideBtn
local current, tab = nil, "glances"

local function bound(parent)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  UI.Panel(f, UI.hex("ffffff", 0.04), UI.C.line2)
  f.text = UI.Text(f, "body", 12)
  f.text:SetPoint("CENTER")
  f.text:SetWordWrap(false)
  f:EnableMouse(true)
  f:SetScript("OnEnter", function(self) if self.tip then GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:SetText(self.tip, 1, 1, 1) GameTooltip:Show() end end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return f
end

-- plain characters every font has: welcome, ask first, not for me
local MARK = { y = "|cff7fd18b+|r ", a = "|cfff2c45a?|r ", n = "|cffe0716b-|r " }

local function buildHeader()
  header = CreateFrame("Frame", nil, win)
  header:SetPoint("TOPLEFT", 16, -14)
  header:SetPoint("TOPRIGHT", -40, -14)
  header:SetHeight(120)
  header.portrait = CreateFrame("Frame", nil, header, "BackdropTemplate")
  UI.Panel(header.portrait, UI.hex("2c2437"), UI.C.line2)
  header.portrait:SetSize(74, 74)
  header.portrait:SetPoint("TOPLEFT")
  header.initial = UI.Text(header.portrait, "title", 34)
  header.initial:SetPoint("CENTER")
  header.name = UI.Text(header, "title", 28)
  header.name:SetPoint("TOPLEFT", header.portrait, "TOPRIGHT", 14, 0)
  header.name:SetPoint("RIGHT")
  header.name:SetWordWrap(false)
  header.title = UI.Text(header, "body", 15, UI.C.muted)
  header.title:SetPoint("TOPLEFT", header.name, "BOTTOMLEFT", 0, -3)
  header.title:SetPoint("RIGHT")
  header.pill = UI.StatusPill(header)
  header.pill:SetPoint("TOPLEFT", header.title, "BOTTOMLEFT", 0, -6)
  header.pronouns = UI.Text(header, "body", 13, UI.C.muted)
  header.pronouns:SetPoint("LEFT", header.pill, "RIGHT", 8, 0)
  header.mature = UI.Pill(header)
  header.mature:SetPoint("LEFT", header.pronouns, "RIGHT", 8, 0)
  header.facts = UI.Text(header, "body", 12.5, UI.C.muted)
  header.facts:SetPoint("TOPLEFT", header.pill, "BOTTOMLEFT", 0, -6)
  header.facts:SetPoint("RIGHT")
  header.bounds = {}
  for i = 1, 6 do header.bounds[i] = bound(header) end
end

local function fact(label, value)
  return value and ("|cff7d7465" .. label .. "|r |cffece3d3" .. value .. "|r") or nil
end

local function fillHeader(view)
  local color = view.color and UI.hex(view.color) or UI.C.text
  header.initial:SetText(view.rpName:match("^[%z\1-\127\194-\244][\128-\191]*") or "?")
  UI.Color(header.initial, color)
  header.name:SetText(view.rpName)
  UI.Color(header.name, color)
  header.title:SetText(view.title or "")
  header.pill:SetStatus(view)
  header.pronouns:SetText(view.pronouns or "")
  header.mature:Set(view.mature and "Mature" or nil, UI.C.no)
  local visible = Cache.Visible(view)
  local facts = {}
  if visible then
    for _, f in ipairs({ fact("Age", view.age), fact("Build", view.height), fact("Eyes", view.eyes), fact("Race", view.race),
      fact("Class", view.class), fact("Style", view.style) }) do facts[#facts + 1] = f end
  end
  header.facts:SetText(table.concat(facts, "    "))
  local x = 0
  for i, b in ipairs(header.bounds) do
    local item = visible and view.bounds and view.bounds[i]
    if item then
      b.text:SetText(MARK[item.value] .. item.label)
      b.tip = item.label .. ": " .. Profile.BOUND_WORD[item.value]
      b:SetSize(b.text:GetStringWidth() + 16, 20)
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", header.facts, "BOTTOMLEFT", x, -8)
      x = x + b:GetWidth() + 6
      b:Show()
    else
      b:Hide()
    end
  end
end

-------------------------------------------------------------------------------------------
-- Panes
-------------------------------------------------------------------------------------------

local function glancePane()
  local scroll = UI.ScrollArea(win)
  local c = scroll.content
  scroll.currently = UI.Text(c, "body", 15)
  scroll.currently:SetPoint("TOPLEFT", 0, 0)
  scroll.currently:SetPoint("RIGHT", -10, 0)
  scroll.cards = {}
  for i = 1, Profile.MAX_GLANCES do
    local card = CreateFrame("Frame", nil, c, "BackdropTemplate")
    UI.Panel(card, UI.hex("ffffff", 0.02), UI.C.line)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(34, 34)
    card.icon:SetPoint("TOPLEFT", 10, -10)
    card.title = UI.Text(card, "title", 16, UI.C.accent)
    card.title:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, 0)
    card.title:SetPoint("RIGHT", -10, 0)
    card.text = UI.Text(card, "body", 13)
    card.text:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -3)
    card.text:SetPoint("RIGHT", -10, 0)
    scroll.cards[i] = card
  end
  scroll.ooc = UI.Text(c, "body", 13, UI.C.muted)
  function scroll:Fill(view)
    local y = 0
    if view.currently then
      self.currently:SetText("|cff7d7465Currently|r\n" .. view.currently)
      y = self.currently:GetStringHeight() + 14
    else
      self.currently:SetText("")
    end
    local colW = (self:GetWidth() - 10) / 2
    local rowH = 0
    for i, card in ipairs(self.cards) do
      local g = view.glances[i]
      if g then
        UI.SetIcon(card.icon, g.icon)
        card.title:SetText(g.title ~= "" and g.title or "At a glance")
        card.text:SetText(g.text)
        card:SetWidth(colW - 5)
        local h = math.max(56, card.title:GetStringHeight() + card.text:GetStringHeight() + 26)
        card:SetHeight(h)
        card:ClearAllPoints()
        local col = (i - 1) % 2
        card:SetPoint("TOPLEFT", col * colW, -y)
        rowH = math.max(rowH, h)
        if col == 1 or i == #view.glances then y = y + rowH + 10 rowH = 0 end
        card:Show()
      else
        card:Hide()
      end
    end
    if #view.glances == 0 and not view.currently then
      self.currently:SetText("|cff7d7465No glances yet.|r")
      y = 24
    end
    self.ooc:ClearAllPoints()
    self.ooc:SetPoint("TOPLEFT", 0, -y - 4)
    self.ooc:SetPoint("RIGHT", -10, 0)
    self.ooc:SetText(view.ooc and ("|cff9aa7b8OOC:|r " .. view.ooc) or "")
    self.content:SetHeight(y + 40)
  end
  return scroll
end

local function descriptionPane()
  local scroll = UI.ScrollArea(win)
  local html = CreateFrame("SimpleHTML", nil, scroll.content)
  html:SetPoint("TOPLEFT")
  html:SetPoint("RIGHT", -10, 0)
  html:SetHeight(10)
  html:SetFontObject("p", UI.Font("body", 15))
  html:SetFontObject("h1", UI.Font("title", 22))
  html:SetFontObject("h2", UI.Font("title", 18))
  html:SetTextColor("h1", UI.C.accent.r, UI.C.accent.g, UI.C.accent.b)
  html:SetTextColor("h2", UI.C.accent.r, UI.C.accent.g, UI.C.accent.b)
  html:SetSpacing("p", 3)
  function scroll:Fill(view)
    local text = view.description
    if view.history and view.history ~= "" then text = (text or "") .. "\n\n# History\n" .. view.history end
    if not text or text == "" then
      html:SetText("<html><body><p>|cff7d7465No description" .. (view.own and "" or " yet. It's asked for when you open this") .. ".|r</p></body></html>")
    else
      html:SetText(Text.Html(text, 16000))
    end
    html:SetWidth(math.max(100, self:GetWidth() - 10))
    local h = (html.GetContentHeight and html:GetContentHeight()) or 2000
    html:SetHeight(h)
    self.content:SetHeight(h + 20)
  end
  return scroll
end

local function notesPane()
  local f = CreateFrame("Frame", nil, win)
  f.lead = UI.Text(f, "body", 12.5, UI.C.faint)
  f.lead:SetPoint("TOPLEFT")
  f.lead:SetText("Only you see this. The first line shows on their tooltip.")
  f.area = UI.TextArea(f, 2000, function(text) if current and current ~= "self" then Cache:SetNote(current, text) end end)
  f.area:SetPoint("TOPLEFT", 0, -20)
  f.area:SetPoint("RIGHT")
  f.area:SetHeight(170)
  f.relLabel = UI.Text(f, "body", 12.5, UI.C.faint)
  f.relLabel:SetPoint("TOPLEFT", f.area, "BOTTOMLEFT", 0, -14)
  f.relLabel:SetText("Relation")
  local items = { { "", "none" } }
  for _, r in ipairs(Cache.RELATIONS) do items[#items + 1] = { r, r } end
  f.rel = UI.Segmented(f, items, function(r) if current and current ~= "self" then Cache:SetRelation(current, r) end end)
  f.rel:SetPoint("TOPLEFT", f.relLabel, "BOTTOMLEFT", 0, -6)
  function f:Fill(view)
    self.area:SetText(view.note or "")
    self.rel:Select(view.rel or "", true)
  end
  return f
end

local function matureCover()
  local f = CreateFrame("Frame", nil, win, "BackdropTemplate")
  UI.Panel(f, UI.hex("000000", 0), UI.C.line2)
  f.text = UI.Text(f, "body", 14, UI.C.muted)
  f.text:SetPoint("TOP", 0, -20)
  f.text:SetJustifyH("CENTER")
  f.text:SetText("This is a mature profile.")
  f.button = UI.Button(f, "Show mature profiles", nil, function()
    G.db.settings.showMature = true
    G:Fire("GUISE_SETTINGS_CHANGED")
    Sheet:Refresh()
  end)
  f.button:SetPoint("TOP", f.text, "BOTTOM", 0, -14)
  f.hint = UI.Text(f, "body", 12, UI.C.faint)
  f.hint:SetPoint("TOP", f.button, "BOTTOM", 0, -8)
  f.hint:SetText("Turns it on for every profile. Change it in /guise settings.")
  return f
end

-------------------------------------------------------------------------------------------

local function build()
  win = UI.Window("GuiseSheet", "", W, H)
  buildHeader()
  tabs = UI.Tabs(win, { { "glances", "At a glance" }, { "desc", "Description" }, { "notes", "Your notes" } }, function(key)
    tab = key
    Sheet:Refresh()
  end)
  tabs:SetPoint("TOPLEFT", 12, -150)
  tabs:SetPoint("TOPRIGHT", -12, -150)
  panes = { glances = glancePane(), desc = descriptionPane(), notes = notesPane(), mature = matureCover() }
  for _, p in pairs(panes) do
    p:SetPoint("TOPLEFT", 18, -194)
    p:SetPoint("BOTTOMRIGHT", -18, 44)
    p:Hide()
  end
  foot = UI.Text(win, "body", 12, UI.C.faint)
  foot:SetPoint("BOTTOMLEFT", 16, 14)
  foot:SetPoint("RIGHT", -170, 0)
  foot:SetWordWrap(false)
  hideBtn = UI.Button(win, "Hide this profile", nil, function()
    if current and current ~= "self" then
      local p = Cache:Get(current)
      Cache:SetHidden(current, not (p and p.hidden))
      Sheet:Refresh()
    end
  end)
  hideBtn:SetPoint("BOTTOMRIGHT", -12, 10)
  local rule = UI.Rule(win)
  rule:SetPoint("BOTTOMLEFT", 0, 38)
  rule:SetPoint("BOTTOMRIGHT", 0, 38)
end

local function ago(t)
  if not t then return "never" end
  local s = G.Now() - t
  if s < 60 then return "just now" end
  if s < 3600 then return math.floor(s / 60) .. " min ago" end
  if s < 86400 then return math.floor(s / 3600) .. " h ago" end
  return math.floor(s / 86400) .. " d ago"
end

function Sheet:Refresh()
  if not win or not win:IsShown() or not current then return end
  local own = current == "self"
  local view = Cache:View(not own and current or nil, own)
  if not view then
    view = { rpName = current, glances = {}, own = false }
  end
  fillHeader(view)
  tabs:SetShownKey("notes", not own)
  if own and tab == "notes" then tab = "glances" end
  tabs:Select(tab, true)
  for _, p in pairs(panes) do p:Hide() end
  local pane
  if not own and view.hidden and tab ~= "notes" then
    pane = panes.mature
    pane.text:SetText("You hid this profile.")
    pane.button:Hide() pane.hint:Hide()
  elseif not Cache.Visible(view) and tab ~= "notes" then
    pane = panes.mature
    pane.text:SetText("This is a mature profile.")
    pane.button:Show() pane.hint:Show()
  else
    pane = panes[tab]
  end
  pane:Show()
  pane:Fill(view)
  if own then
    foot:SetText("This is what others see.")
    hideBtn:Hide()
  else
    local p = Cache:Get(current)
    local parts = { current, "updated " .. ago(p and p.answered) }
    if view.addon and not view.guise then parts[#parts + 1] = "via " .. view.addon:match("^[^;/]+") end
    if not Cache:HasProfile(current) then parts = { current, "asking for their profile..." } end
    foot:SetText(table.concat(parts, "  ·  "))
    hideBtn:SetLabel(p and p.hidden and "Unhide" or "Hide this profile")
    hideBtn:Show()
  end
end

---Opens the sheet for a name, or "self". tabKey optional.
function Sheet:Open(name, tabKey)
  if not name then return end
  if not win then build() end
  if name ~= current then tab = "glances" end
  current = name
  if tabKey then tab = tabKey end
  if name ~= "self" then
    local p = Cache:Ensure(name)
    p.opened = G.Now()
    Comms:ForSheet(name)
  end
  win:Show()
  self:Refresh()
end

function Sheet:Toggle(name)
  if win and win:IsShown() and current == name then win:Hide() else self:Open(name) end
end

function Sheet:Current() return win and win:IsShown() and current or nil end

G:Listen("GUISE_PROFILE_UPDATED", function(name) if name == current then Sheet:Refresh() end end)
G:Listen("GUISE_PROFILE_CHANGED", function() if current == "self" then Sheet:Refresh() end end)
G:Listen("GUISE_SETTINGS_CHANGED", function() Sheet:Refresh() end)

G.commands.sheet = function(rest)
  if rest and rest ~= "" then Sheet:Open(rest) return end
  local name = G.Call("UnitIsPlayer", "target") and not G.Call("UnitIsUnit", "target", "player") and G.Names:ForUnit("target")
  Sheet:Open(name or "self")
end
