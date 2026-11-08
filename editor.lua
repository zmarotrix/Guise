-- Your profile: Identity, Glances, Description, Boundaries, Settings, with your tooltip drawn live on the right.
-- Everything saves as you type; what changed goes out the next time someone asks.

local G = Guise
local UI, Profile, Cache, Tooltip, Text = G.UI, G.Profile, G.Cache, G.Tooltip, G.Text
local Editor = {}
G.Editor = Editor

local W, H, PREVIEW = 1000, 690, 330
local win, tabs, panes, preview, profileRow
local tab = "identity"

-------------------------------------------------------------------------------------------
-- Live preview: the same lines the tooltip gets
-------------------------------------------------------------------------------------------

local function buildPreview()
  preview = CreateFrame("Frame", nil, win, "BackdropTemplate")
  UI.Panel(preview, UI.hex("000000", 0.18), UI.C.line)
  preview:SetPoint("TOPRIGHT", -12, -132)
  preview:SetPoint("BOTTOMRIGHT", -12, 44)
  preview:SetWidth(PREVIEW)
  local label = UI.Text(preview, "body", 12, UI.C.faint)
  label:SetPoint("TOPLEFT", 14, -12)
  label:SetText("Your tooltip, live")
  preview.box = CreateFrame("Frame", nil, preview, "BackdropTemplate")
  UI.Panel(preview.box, UI.hex("0c0a10", 0.96), UI.C.line2)
  preview.box:SetPoint("TOPLEFT", 12, -32)
  preview.box:SetPoint("RIGHT", -12, 0)
  preview.first = UI.Text(preview.box, "title", 19)
  preview.first:SetPoint("TOPLEFT", 10, -10)
  preview.first:SetPoint("RIGHT", -10, 0)
  preview.lines = {}
  preview.game = UI.Text(preview.box, "body", 12, UI.C.faint)
  local glabel = UI.Text(preview, "body", 12, UI.C.faint)
  glabel:SetPoint("TOPLEFT", preview.box, "BOTTOMLEFT", 2, -16)
  glabel:SetText("Glance strip")
  preview.icons = {}
  for i = 1, Profile.MAX_GLANCES do
    local t = preview:CreateTexture(nil, "ARTWORK")
    t:SetSize(30, 30)
    t:SetPoint("TOPLEFT", glabel, "BOTTOMLEFT", (i - 1) * 36, -6)
    preview.icons[i] = t
  end
end

function Editor:RefreshPreview()
  if not preview then return end
  local view = Cache:View(nil, true)
  local lines = Tooltip.Lines(view)
  preview.first:SetText(lines.first)
  local y = preview.first:GetStringHeight() + 14
  for i, line in ipairs(lines.lines) do
    local fs = preview.lines[i]
    if not fs then fs = UI.Text(preview.box, "body", 13) preview.lines[i] = fs end
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", 10, -y)
    fs:SetPoint("RIGHT", -10, 0)
    fs:SetText(line[1])
    fs:Show()
    y = y + fs:GetStringHeight() + 4
  end
  for i = #lines.lines + 1, #preview.lines do preview.lines[i]:Hide() end
  local level = G.Call("UnitLevel", "player") or ""
  local race, class = G.Call("UnitRace", "player") or "", G.Call("UnitClass", "player") or ""
  preview.game:ClearAllPoints()
  preview.game:SetPoint("TOPLEFT", 10, -y - 4)
  preview.game:SetPoint("RIGHT", -10, 0)
  preview.game:SetText((G.Call("GetUnitName", "player", true) or "") .. " · Level " .. level .. " " .. race .. " " .. class)
  preview.box:SetHeight(y + preview.game:GetStringHeight() + 16)
  for i, t in ipairs(preview.icons) do
    local g = view.glances[i]
    if g then UI.SetIcon(t, g.icon) t:Show() else t:Hide() end
  end
end

-------------------------------------------------------------------------------------------
-- Icon picker, shared by the glances
-------------------------------------------------------------------------------------------

local picker
local function icons()
  local list = {}
  local get = rawget(_G, "GetMacroIcons")
  if get then pcall(get, list) end
  local loose = rawget(_G, "GetLooseMacroIcons")
  if loose then pcall(loose, list) end
  if #list == 0 then
    for _, name in ipairs({ "INV_Misc_Book_09", "INV_Misc_QuestionMark", "INV_Sword_04", "INV_Misc_Bag_10", "Spell_Holy_Heal",
      "INV_Misc_Gem_Pearl_04", "INV_Jewelry_Ring_03", "INV_Misc_Coin_01", "Ability_Rogue_Disguise", "Spell_Shadow_Charm" }) do
      list[#list + 1] = name
    end
  end
  return list
end

local function openPicker(anchor, onPick)
  if not picker then
    picker = CreateFrame("Frame", "GuiseIconPicker", UIParent, "BackdropTemplate")
    UI.Panel(picker, UI.C.ink, UI.C.line2)
    picker:SetSize(8 * 38 + 20, 6 * 38 + 76)
    picker:SetFrameStrata("DIALOG")
    picker:EnableMouse(true)
    picker:EnableMouseWheel(true)
    table.insert(UISpecialFrames, "GuiseIconPicker")
    picker.offset, picker.buttons = 0, {}
    for i = 1, 48 do
      local b = UI.IconButton(picker, 34)
      b:SetPoint("TOPLEFT", 10 + ((i - 1) % 8) * 38, -10 - math.floor((i - 1) / 8) * 38)
      b:SetScript("OnClick", function(self) if self.value and picker.onPick then picker.onPick(self.value) picker:Hide() end end)
      picker.buttons[i] = b
    end
    picker.name = UI.Input(picker, "Or type an icon's name", 60)
    picker.name:SetPoint("BOTTOMLEFT", 10, 8)
    picker.name:SetPoint("BOTTOMRIGHT", -80, 8)
    picker.use = UI.Button(picker, "Use", "primary", function()
      local v = (picker.name:GetText() or ""):gsub("[^%w_]", "")
      if v ~= "" and picker.onPick then picker.onPick(v) picker:Hide() end
    end)
    picker.use:SetPoint("BOTTOMRIGHT", -10, 10)
    function picker:Fill()
      for i, b in ipairs(self.buttons) do
        local v = self.list[self.offset + i]
        b.value = v
        if v then UI.SetIcon(b.icon, v) b:Show() else b:Hide() end
      end
    end
    picker:SetScript("OnMouseWheel", function(self, d)
      self.offset = math.max(0, math.min(self.offset - d * 8, #self.list - 48))
      self:Fill()
    end)
  end
  picker.list = picker.list or icons()
  picker.onPick = onPick
  picker:ClearAllPoints()
  picker:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0)
  picker:Show()
  picker:Fill()
end

-------------------------------------------------------------------------------------------
-- Panes
-------------------------------------------------------------------------------------------

local function pane()
  local f = CreateFrame("Frame", nil, win)
  f:SetPoint("TOPLEFT", 18, -144)
  f:SetPoint("BOTTOMRIGHT", -(PREVIEW + 30), 44)
  f:Hide()
  return f
end

-- a grid of labelled inputs: items = { {field, label, where} }, where 1 = left half, 2 = right half, 0 = full width
local function inputGrid(f, items, top)
  f.inputs = f.inputs or {}
  local y, col = top or 0, 0
  for _, item in ipairs(items) do
    local field, label, where = item[1], item[2], item[3]
    local input = UI.Input(f, label, Profile.FIELDS[field], function(text) Profile:Set(field, text) end)
    if where == 0 then
      if col ~= 0 then y = y + 52 col = 0 end
      input:SetPoint("TOPLEFT", 0, -y)
      input:SetPoint("RIGHT", 0, 0)
      y = y + 52
    elseif where == 1 then
      input:SetPoint("TOPLEFT", 0, -y)
      input:SetPoint("RIGHT", f, "CENTER", -8, 0)
      col = 1
    else
      input:SetPoint("TOPLEFT", f, "TOP", 8, -y)
      input:SetPoint("RIGHT", 0, 0)
      y = y + 52
      col = 0
    end
    f.inputs[field] = input
  end
  if col ~= 0 then y = y + 52 end
  return y
end

local function fillInputs(f)
  local p = Profile:Current()
  for field, input in pairs(f.inputs) do
    if not input.box:HasFocus() then input:SetText(p.fields[field] or "") end
  end
end

local function identityPane()
  local f = pane()
  local y = inputGrid(f, {
    { "NA", "Name (starts as your Forever name)", 1 }, { "PX", "Prefix (Lady, Sergeant...)", 2 },
    { "NT", "Title", 0 },
    { "PN", "Pronouns (IC)", 1 }, { "XP", "Pronouns (OOC, optional)", 2 },
    { "CU", "Currently: what you're doing right now", 0 }, { "CO", "OOC note", 0 },
  })
  f.statusLabel = UI.Text(f, "body", 12, UI.C.muted)
  f.statusLabel:SetPoint("TOPLEFT", 0, -y - 2)
  f.statusLabel:SetText("Status")
  local items = {}
  for _, s in ipairs(Profile.STATUSES) do items[#items + 1] = { s, Profile.STATUS_LABEL[s], Profile.STATUS_HELP[s] } end
  f.status = UI.Segmented(f, items, function(s) Profile:SetStatus(s) end)
  f.status:SetPoint("TOPLEFT", f.statusLabel, "BOTTOMLEFT", 0, -6)
  -- profile icon and name colour, side by side
  f.iconLabel = UI.Text(f, "body", 12, UI.C.muted)
  f.iconLabel:SetPoint("TOPLEFT", f.status, "BOTTOMLEFT", 0, -14)
  f.iconLabel:SetText("Profile icon")
  f.icon = UI.IconButton(f, 40)
  f.icon:SetPoint("TOPLEFT", f.iconLabel, "BOTTOMLEFT", 0, -6)
  f.icon.onEnter = function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:SetText("Choose your profile's icon", 1, 1, 1) GameTooltip:Show() end
  f.icon:SetScript("OnClick", function(self) openPicker(self, function(v) Profile:SetOption("icon", v) end) end)
  f.colorLabel = UI.Text(f, "body", 12, UI.C.muted)
  f.colorLabel:SetPoint("TOPLEFT", f.iconLabel, "TOPLEFT", 120, 0)
  f.colorLabel:SetText("Name colour")
  f.swatch = UI.Button(f, "Choose", nil, function()
    local p = Profile:Current()
    local c = UI.hex(p.color or Profile.ClassColor())
    local picker = rawget(_G, "ColorPickerFrame")
    if not picker or not picker.SetupColorPickerAndShow then return end
    local before = p.color
    local function apply()
      local r, g, b = picker:GetColorRGB()
      Profile:SetOption("color", string.format("%02x%02x%02x", r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5))
    end
    picker:SetupColorPickerAndShow({ r = c.r, g = c.g, b = c.b, swatchFunc = apply,
      cancelFunc = function() Profile:SetOption("color", before) end })
  end)
  f.swatch:SetPoint("TOPLEFT", f.colorLabel, "BOTTOMLEFT", 0, -8)
  f.swatchDot = f.swatch:CreateTexture(nil, "OVERLAY")
  f.swatchDot:SetTexture(UI.WHITE)
  f.swatchDot:SetSize(14, 14)
  f.swatchDot:SetPoint("LEFT", f.swatch, "RIGHT", 8, 0)
  f.classColor = UI.Button(f, "Class colour", "quiet", function() Profile:SetOption("color", nil) end)
  f.classColor:SetPoint("LEFT", f.swatchDot, "RIGHT", 8, 0)
  f.matureLabel = UI.Text(f, "body", 12, UI.C.muted)
  f.matureLabel:SetPoint("TOPLEFT", f.icon, "BOTTOMLEFT", 0, -14)
  f.matureLabel:SetPoint("RIGHT")
  f.matureLabel:SetText("Mature profile: others see only your name and a \"mature\" pill until they choose to show mature profiles.")
  f.mature = UI.Segmented(f, { { false, "No" }, { true, "Yes, mature" } }, function(v) Profile:SetOption("mature", v) end)
  f.mature:SetPoint("TOPLEFT", f.matureLabel, "BOTTOMLEFT", 0, -6)
  function f:Fill()
    local p = Profile:Current()
    fillInputs(self)
    UI.SetIcon(self.icon.icon, p.icon or "INV_Misc_QuestionMark")
    local c = UI.hex(p.color or Profile.ClassColor())
    self.swatchDot:SetVertexColor(c.r, c.g, c.b)
    self.classColor:SetShown(p.color ~= nil)
    self.status:Select(Profile:Status(), true)
    self.mature:Select(p.mature and true or false, true)
  end
  return f
end

local function detailsPane()
  local f = pane()
  local y = inputGrid(f, {
    { "AG", "Age", 1 }, { "RA", "Race (if not the game's)", 2 },
    { "AH", "Height", 1 }, { "AW", "Weight or build", 2 },
    { "AE", "Eyes", 1 }, { "RC", "Class (if not the game's)", 2 },
    { "NI", "Nickname", 1 }, { "NH", "House or family", 2 },
    { "HH", "Home", 1 }, { "HB", "Birthplace", 2 },
    { "MO", "Motto", 0 },
  })
  f.relLabel = UI.Text(f, "body", 12, UI.C.muted)
  f.relLabel:SetPoint("TOPLEFT", 0, -y - 2)
  f.relLabel:SetText("Relationship status")
  local items = { { 0, "Not shown" } }
  for i, r in ipairs(G.MSP.RELATIONSHIP) do items[#items + 1] = { i, r } end
  f.rel = UI.Segmented(f, items, function(v) Profile:SetOption("relationship", v) end)
  f.rel:SetPoint("TOPLEFT", f.relLabel, "BOTTOMLEFT", 0, -6)
  function f:Fill()
    fillInputs(self)
    self.rel:Select(Profile:Current().relationship or 0, true)
  end
  return f
end

local function textPane(field, lead)
  local f = pane()
  f.lead = UI.Text(f, "body", 12.5, UI.C.faint)
  f.lead:SetPoint("TOPLEFT")
  f.lead:SetPoint("RIGHT")
  f.lead:SetText(lead)
  f.area = UI.TextArea(f, Profile.FIELDS[field], function(text) Profile:Set(field, text) end)
  f.area:SetPoint("TOPLEFT", 0, -38)
  f.area:SetPoint("BOTTOMRIGHT", 0, 20)
  f.count = UI.Text(f, "body", 11, UI.C.faint)
  f.count:SetPoint("BOTTOMRIGHT", 0, 0)
  f.area.count = f.count
  function f:Fill()
    if not self.area.box:HasFocus() then self.area:SetText(Profile:Get(field)) end
    self.count:SetText(#Profile:Get(field) .. "/" .. Profile.FIELDS[field])
  end
  return f
end

local function descriptionPane()
  return textPane("DE", "What people see when they look at you. # Heading   *emphasis*   **strong**   > quote   ---   {icon:INV_Misc_Book_09}. "
    .. "A blank line starts a new paragraph.")
end

local function historyPane()
  return textPane("HI", "Your character's past: what people might know or find out. The same markup as the description.")
end

local function boundsPane()
  local f = pane()
  f.lead = UI.Text(f, "body", 12.5, UI.C.faint)
  f.lead:SetPoint("TOPLEFT")
  f.lead:SetPoint("RIGHT")
  f.lead:SetText("Tell people what's welcome before they walk up. Shown as small marks on your sheet. "
    .. "Injury, death, romance, crime and loss of control are the ones Total RP 3 shows too.")
  f.rows = {}
  local items = { { "y", "welcome" }, { "a", "ask first" }, { "n", "not for me" }, { "-", "not shown" } }
  for i, b in ipairs(Profile.BOUNDS) do
    local label = UI.Text(f, "body", 14)
    label:SetPoint("TOPLEFT", 0, -40 - (i - 1) * 34)
    label:SetText(b[2])
    local seg = UI.Segmented(f, items, function(v) Profile:SetBound(i, v) end)
    seg:SetPoint("TOPLEFT", 160, -36 - (i - 1) * 34)
    f.rows[i] = seg
  end
  local top = -40 - #Profile.BOUNDS * 34 - 10
  local label = UI.Text(f, "body", 14)
  label:SetPoint("TOPLEFT", 0, top)
  label:SetText("Experience")
  local exp = {}
  for _, e in ipairs(Profile.EXPERIENCE) do exp[#exp + 1] = { e, e, Profile.EXPERIENCE_HELP[e] } end
  f.exp = UI.Segmented(f, exp, function(v) Profile:SetOption("experience", v) end)
  f.exp:SetPoint("TOPLEFT", 160, top + 4)
  function f:Fill()
    local p = Profile:Current()
    local bounds = p.bounds or ""
    for i, seg in ipairs(self.rows) do
      local v = bounds:sub(i, i)
      seg:Select(Profile.BOUND_WORD[v] and v or "-", true)
    end
    self.exp:Select(p.experience or "Casual", true)
  end
  return f
end

local function glancesPane()
  local f = pane()
  f.lead = UI.Text(f, "body", 12.5, UI.C.faint)
  f.lead:SetPoint("TOPLEFT")
  f.lead:SetText("Up to five. They show under your target frame, as icons on your tooltip, and on your sheet.")
  f.rows = {}
  for i = 1, Profile.MAX_GLANCES do
    local row = CreateFrame("Frame", nil, f)
    row:SetPoint("TOPLEFT", 0, -22 - (i - 1) * 92)
    row:SetPoint("RIGHT")
    row:SetHeight(86)
    row.icon = UI.IconButton(row, 40)
    row.icon:SetPoint("TOPLEFT", 0, -4)
    row.icon.tip = "Choose an icon"
    row.icon.onEnter = function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:SetText("Choose an icon", 1, 1, 1) GameTooltip:Show() end
    local function save()
      local p = Profile:Current()
      local g = p.glances[i] or {}
      Profile:SetGlance(i, row.value or g.icon, row.title:GetText(), row.text:GetText())
    end
    row.icon:SetScript("OnClick", function(self) openPicker(self, function(v) row.value = v save() f:Fill() end) end)
    row.title = UI.Input(row, "Title", Profile.GLANCE_TITLE, save)
    row.title:SetPoint("TOPLEFT", 50, 0)
    row.title:SetPoint("RIGHT", -70, 0)
    row.text = UI.TextArea(row, Profile.GLANCE_TEXT, save)
    row.text:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
    row.text:SetPoint("RIGHT", -70, 0)
    row.text:SetHeight(36)
    row.remove = UI.Button(row, "Remove", "quiet", function() Profile:SetGlance(i) f:Fill() end)
    row.remove:SetPoint("TOPRIGHT", 0, -16)
    f.rows[i] = row
  end
  f.add = UI.Button(f, "+ Add a glance", nil, function()
    local p = Profile:Current()
    if #p.glances < Profile.MAX_GLANCES then
      Profile:SetGlance(#p.glances + 1, "INV_Misc_QuestionMark", "", "")
      f:Fill()
    end
  end)
  function f:Fill()
    local p = Profile:Current()
    for i, row in ipairs(self.rows) do
      local g = p.glances[i]
      row.value = g and g.icon
      if g then
        UI.SetIcon(row.icon.icon, g.icon)
        if not row.title.box:HasFocus() then row.title:SetText(g.title) end
        if not row.text.box:HasFocus() then row.text:SetText(g.text) end
        row:Show()
      else
        row:Hide()
      end
    end
    self.add:ClearAllPoints()
    self.add:SetPoint("TOPLEFT", 0, -26 - #p.glances * 92)
    self.add:SetShown(#p.glances < Profile.MAX_GLANCES)
  end
  return f
end


local function settingsPane()
  local f = pane()
  f.list = G.Settings:Build(f)
  f.list:SetAllPoints()
  function f:Fill() f.list:Refresh() end
  return f
end

-------------------------------------------------------------------------------------------
-- Profiles row: wear, new, rename, delete
-------------------------------------------------------------------------------------------

local function profileMenu(owner, id)
  local menu = rawget(_G, "MenuUtil")
  if not menu or not menu.CreateContextMenu then return end
  menu.CreateContextMenu(owner, function(_, root)
    root:CreateTitle(G.db.profiles[id] and G.db.profiles[id].label or id)
    root:CreateButton("Copy to a new profile", function()
      local new = Profile:Create((G.db.profiles[id].label or id) .. " copy", id)
      Profile:Wear(new)
      Editor:Refresh()
    end)
    if id ~= G.char.profile then
      root:CreateButton("Delete", function() Profile:Delete(id) Editor:Refresh() end)
    end
  end)
end

local function fillProfiles()
  for _, b in ipairs(profileRow.buttons) do b:Hide() end
  local _, wearing = Profile:Current()
  local x = 0
  for i, item in ipairs(Profile:List()) do
    local b = profileRow.buttons[i]
    if not b then
      b = UI.Button(profileRow, "", nil, nil)
      b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      profileRow.buttons[i] = b
    end
    b:SetLabel(item.label)
    b:SetScript("OnClick", function(self, button)
      if button == "RightButton" then profileMenu(self, item.id) else Profile:Wear(item.id) Editor:Refresh() end
    end)
    local on = item.id == wearing
    b:SetBackdropBorderColor(on and UI.C.accent.r or UI.C.line2.r, on and UI.C.accent.g or UI.C.line2.g, on and UI.C.accent.b or UI.C.line2.b)
    b.tip = on and "Wearing this one. Right-click for more." or "Wear this profile. Right-click for more."
    b:ClearAllPoints()
    b:SetPoint("LEFT", x, 0)
    x = x + b:GetWidth() + 6
    b:Show()
  end
  profileRow.new:ClearAllPoints()
  profileRow.new:SetPoint("LEFT", x, 0)
end

-------------------------------------------------------------------------------------------

local function build()
  win = UI.Window("GuiseEditor", "Your profile", W, H)
  local lead = UI.Text(win, "body", 13, UI.C.muted)
  lead:SetPoint("TOPLEFT", 16, -44)
  lead:SetText("What others see when they meet you. Changes save as you type.")
  profileRow = CreateFrame("Frame", nil, win)
  profileRow:SetPoint("TOPLEFT", 16, -70)
  profileRow:SetSize(W - 32, 26)
  profileRow.buttons = {}
  profileRow.new = UI.Button(profileRow, "+ New", "quiet", function()
    local id = Profile:Create("Profile")
    Profile:Wear(id)
    Editor:Refresh()
  end)
  tabs = UI.Tabs(win, { { "identity", "Identity" }, { "details", "Details" }, { "glances", "Glances" },
    { "desc", "Description" }, { "history", "History" }, { "bounds", "Boundaries" }, { "settings", "Settings" } },
    function(key) tab = key Editor:Refresh() end)
  tabs:SetPoint("TOPLEFT", 12, -100)
  tabs:SetPoint("TOPRIGHT", -12, -100)
  panes = { identity = identityPane(), details = detailsPane(), glances = glancesPane(), desc = descriptionPane(),
    history = historyPane(), bounds = boundsPane(), settings = settingsPane() }
  buildPreview()
  local foot = UI.Text(win, "body", 12, UI.C.faint)
  foot:SetPoint("BOTTOMLEFT", 16, 14)
  foot:SetPoint("RIGHT", -150, 0)
  foot:SetWordWrap(false)
  foot:SetText("Total RP 3, MyRolePlay and XRP users see this profile too, and you see theirs.")
  local rule = UI.Rule(win)
  rule:SetPoint("BOTTOMLEFT", 0, 38)
  rule:SetPoint("BOTTOMRIGHT", 0, 38)
  local sheet = UI.Button(win, "See your sheet", nil, function() G.Sheet:Open("self") end)
  sheet:SetPoint("BOTTOMRIGHT", -12, 10)
end

function Editor:Refresh()
  if not win or not win:IsShown() then return end
  fillProfiles()
  tabs:Select(tab, true)
  for key, p in pairs(panes) do p:SetShown(key == tab) end
  panes[tab]:Fill()
  self:RefreshPreview()
end

function Editor:Open(tabKey)
  if not win then build() end
  if tabKey then tab = tabKey end
  win:Show()
  self:Refresh()
end

function Editor:Toggle()
  if win and win:IsShown() then win:Hide() else self:Open() end
end

G:Listen("GUISE_PROFILE_CHANGED", function() Editor:Refresh() end)
G:Listen("GUISE_SETTINGS_CHANGED", function() if tab == "settings" then Editor:Refresh() end end)

G.commands.edit = function() Editor:Open() end
G.commands.settings = function() Editor:Open("settings") end
