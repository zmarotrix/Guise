-- The directory: everyone you've seen with a profile, stored on this computer only. Search, filter, sort; click to open
-- a sheet, right-click to hide or forget.

local G = Guise
local UI, Cache, Profile, Text = G.UI, G.Cache, G.Profile, G.Text
local Directory = {}
G.Directory = Directory

local W, H, ROW = 820, 620, 44
local win, search, list, count, chips
local filter, sortKey = "all", "seen"

local FILTERS = { { "all", "All" }, { "near", "In your zone" }, { "lfc", "Looking for contact" }, { "rel", "Relations" }, { "hidden", "Hidden" } }

local function ago(t)
  if not t then return "" end
  local s = G.Now() - t
  if s < 300 then return "here now" end
  if s < 3600 then return math.floor(s / 60) .. " min ago" end
  if s < 86400 then return math.floor(s / 3600) .. " h ago" end
  return math.floor(s / 86400) .. " d ago"
end

function Directory:Items()
  local q = (search and search:GetText() or ""):lower()
  local zone = G.Zone()
  local items = {}
  for name in pairs(G.db.people) do
    if Cache:HasProfile(name) then
      local view = Cache:View(name)
      local keep = true
      if filter == "hidden" then keep = view.hidden == true
      elseif view.hidden then keep = false
      elseif filter == "near" then keep = view.zone ~= nil and view.zone == zone
      elseif filter == "lfc" then keep = view.status == "lfc"
      elseif filter == "rel" then keep = view.rel ~= nil end
      if keep and q ~= "" then
        local hay = (view.rpName .. " " .. name .. " " .. (view.title or "") .. " " .. (view.zone or "")):lower()
        keep = hay:find(q, 1, true) ~= nil
      end
      if keep then items[#items + 1] = view end
    end
  end
  table.sort(items, function(a, b)
    if sortKey == "name" then return a.rpName:lower() < b.rpName:lower() end
    if sortKey == "zone" then
      if (a.zone or "") ~= (b.zone or "") then return (a.zone or "~") < (b.zone or "~") end
      return a.rpName:lower() < b.rpName:lower()
    end
    return (a.seen or 0) > (b.seen or 0)
  end)
  return items
end

local function rowMenu(owner, view)
  local menu = rawget(_G, "MenuUtil")
  if not menu or not menu.CreateContextMenu then return end
  menu.CreateContextMenu(owner, function(_, root)
    root:CreateTitle(view.rpName)
    root:CreateButton("Open sheet", function() G.Sheet:Open(view.name) end)
    root:CreateButton(view.hidden and "Unhide" or "Hide this profile", function() Cache:SetHidden(view.name, not view.hidden) end)
    root:CreateButton("Forget", function() Cache:Forget(view.name) end)
  end)
end

local function build()
  win = UI.Window("GuiseDirectory", "Directory", W, H)
  local lead = UI.Text(win, "body", 13, UI.C.muted)
  lead:SetPoint("LEFT", win.title, "RIGHT", 12, -2)
  lead:SetText("Everyone you've seen with a profile. Stored on this computer only.")
  search = UI.Input(win, "", 60, function() Directory:Refresh() end)
  search.label:Hide() search.count:Hide()
  search:SetPoint("TOPLEFT", 16, -36)
  search:SetWidth(280)
  search.box:SetScript("OnEditFocusGained", nil)
  chips = UI.Segmented(win, FILTERS, function(key) filter = key Directory:Refresh() end)
  chips:SetPoint("LEFT", search.box, "RIGHT", 10, 0)
  local head = CreateFrame("Frame", nil, win)
  head:SetPoint("TOPLEFT", 16, -88)
  head:SetPoint("TOPRIGHT", -16, -88)
  head:SetHeight(18)
  local function headLabel(text, x, key)
    local b = CreateFrame("Button", nil, head)
    b.text = UI.Text(b, "body", 12, UI.C.faint)
    b.text:SetPoint("LEFT")
    b.text:SetText(text)
    b:SetSize(b.text:GetStringWidth() + 4, 18)
    b:SetPoint("LEFT", x, 0)
    if key then b:SetScript("OnClick", function() sortKey = key Directory:Refresh() end) end
  end
  headLabel("Character", 44, "name")
  headLabel("Status", 360)
  headLabel("Zone", 520, "zone")
  headLabel("Last seen", 680, "seen")
  list = UI.List(win, {
    rowHeight = ROW,
    create = function(row)
      row.icon = CreateFrame("Frame", nil, row, "BackdropTemplate")
      UI.Panel(row.icon, UI.hex("2c2437"), UI.C.line2)
      row.icon:SetSize(30, 30)
      row.icon:SetPoint("LEFT", 4, 0)
      row.initial = UI.Text(row.icon, "title", 15)
      row.initial:SetPoint("CENTER")
      row.name = UI.Text(row, "title", 16)
      row.name:SetPoint("TOPLEFT", 44, -5)
      row.name:SetWidth(300)
      row.name:SetWordWrap(false)
      row.sub = UI.Text(row, "body", 12, UI.C.faint)
      row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -1)
      row.sub:SetWidth(300)
      row.sub:SetWordWrap(false)
      row.pill = UI.StatusPill(row)
      row.pill:SetPoint("LEFT", 360, 0)
      row.zone = UI.Text(row, "body", 13, UI.C.muted)
      row.zone:SetPoint("LEFT", 520, 0)
      row.zone:SetWidth(150)
      row.zone:SetWordWrap(false)
      row.seen = UI.Text(row, "body", 12, UI.C.faint)
      row.seen:SetPoint("LEFT", 680, 0)
    end,
    update = function(row, view)
      local color = view.color and UI.hex(view.color) or UI.C.text
      row.initial:SetText(view.rpName:match("^[%z\1-\127\194-\244][\128-\191]*") or "?")
      UI.Color(row.initial, color)
      local visible = Cache.Visible(view)
      row.name:SetText(view.rpName .. (view.rel and ("|cff7d7465  · " .. view.rel .. "|r") or ""))
      UI.Color(row.name, color)
      row.sub:SetText(visible and view.title or (view.mature and "Mature profile" or view.name))
      row.pill:SetStatus(view)
      row.zone:SetText(view.zone or "")
      row.seen:SetText(ago(view.seen))
    end,
    click = function(view, button, row)
      if button == "RightButton" then rowMenu(row, view) else G.Sheet:Open(view.name) end
    end,
  })
  list:SetPoint("TOPLEFT", 16, -110)
  list:SetPoint("BOTTOMRIGHT", -16, 44)
  local rule = UI.Rule(win)
  rule:SetPoint("BOTTOMLEFT", 0, 38)
  rule:SetPoint("BOTTOMRIGHT", 0, 38)
  count = UI.Text(win, "body", 12, UI.C.faint)
  count:SetPoint("BOTTOMLEFT", 16, 14)
  local forget = UI.Button(win, "Forget people not seen for 90 days", nil, function()
    local n = Cache:ForgetOld(Cache.FORGET_DAYS)
    G.Print(n == 1 and "forgot 1 person." or ("forgot " .. n .. " people."))
  end)
  forget.tip = "People you wrote a note about or marked with a relation are kept."
  forget:SetPoint("BOTTOMRIGHT", -12, 10)
end

function Directory:Refresh()
  if not win or not win:IsShown() then return end
  chips:Select(filter, true)
  local items = self:Items()
  list:SetItems(items)
  local total = 0
  for name in pairs(G.db.people) do if Cache:HasProfile(name) then total = total + 1 end end
  count:SetText(#items .. " of " .. total .. (total == 1 and " person" or " people"))
end

function Directory:Open()
  if not win then build() end
  win:Show()
  self:Refresh()
end

function Directory:Toggle()
  if win and win:IsShown() then win:Hide() else self:Open() end
end

G:Listen("GUISE_PROFILE_UPDATED", function() G:Soon("directory", function() Directory:Refresh() end) end)
G:Listen("GUISE_PERSON_CHANGED", function() G:Soon("directory", function() Directory:Refresh() end) end)

G.commands.dir = function() Directory:Open() end
G.commands.directory = G.commands.dir
G.commands.forget = function(name)
  if name and G.db.people[name] then Cache:Forget(name) G.Print("forgot " .. name .. ".")
  else G.Print("no one called \"" .. tostring(name) .. "\" in the directory. Use their full name, as in chat.") end
end
