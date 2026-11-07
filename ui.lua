-- Guise's own look (design/guise/index.html): dark ink panels, warm parchment text, a lavender accent, a serif for names.
-- Small widgets on plain frames: no Blizzard templates beyond BackdropTemplate, so nothing here can taint.

local G = Guise
local UI = {}
G.UI = UI

local function hex(s, a)
  return { r = tonumber(s:sub(1, 2), 16) / 255, g = tonumber(s:sub(3, 4), 16) / 255, b = tonumber(s:sub(5, 6), 16) / 255, a = a or 1 }
end
UI.hex = hex
UI.C = {
  ink = hex("15121a", 0.97), ink2 = hex("1d1924", 0.97), ink3 = hex("262130"), line = hex("3a3346"), line2 = hex("4c4359"),
  text = hex("ece3d3"), muted = hex("b3a892"), faint = hex("7d7465"), accent = hex("c9a0ff"), accentSoft = hex("c9a0ff", 0.14),
  field = hex("0f0d13"), yes = hex("7fd18b"), ask = hex("f2c45a"), no = hex("e0716b"), note = hex("d9c37a"),
}
UI.STATUS_COLOR = {}
for k, v in pairs(G.Profile.STATUS_COLOR) do UI.STATUS_COLOR[k] = hex(v) end

local MEDIA = "Interface\\AddOns\\" .. G.name .. "\\media\\"
local FONTS = { title = MEDIA .. "fonts\\Marcellus-Regular.ttf", body = MEDIA .. "fonts\\AlegreyaSans-Regular.ttf",
  bold = MEDIA .. "fonts\\AlegreyaSans-Bold.ttf" }
local WHITE = "Interface\\Buttons\\WHITE8x8"
UI.WHITE = WHITE

-- Alegreya and Marcellus have Latin and Cyrillic only; other locales keep the game's font
local locale = G.Call("GetLocale") or "enUS"
local LATIN = not (locale == "zhCN" or locale == "zhTW" or locale == "koKR")

local fonts = {}
function UI.Font(role, size, flags)
  local key = role .. size .. (flags or "")
  if fonts[key] then return fonts[key] end
  local f = CreateFont("GuiseFont_" .. key:gsub("[^%w]", ""))
  local path = LATIN and FONTS[role] or (rawget(_G, "STANDARD_TEXT_FONT") or "Fonts\\FRIZQT__.TTF")
  f:SetFont(path, size, flags or "")
  f:SetTextColor(UI.C.text.r, UI.C.text.g, UI.C.text.b)
  fonts[key] = f
  return f
end

function UI.Text(parent, role, size, color, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  fs:SetFontObject(UI.Font(role or "body", size or 13))
  local c = color or UI.C.text
  fs:SetTextColor(c.r, c.g, c.b, c.a or 1)
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(true)
  return fs
end

function UI.Color(fs, c) fs:SetTextColor(c.r, c.g, c.b, c.a or 1) end

function UI.Code(c)
  if type(c) == "string" then return "|cff" .. c end
  return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
end

---A filled box with a 1 px border.
function UI.Panel(frame, fill, edge)
  if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
  frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  local f, e = fill or UI.C.ink, edge or UI.C.line
  frame:SetBackdropColor(f.r, f.g, f.b, f.a or 1)
  frame:SetBackdropBorderColor(e.r, e.g, e.b, e.a or 1)
  return frame
end

function UI.Rule(parent, color)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetTexture(WHITE)
  local c = color or UI.C.line
  t:SetVertexColor(c.r, c.g, c.b, c.a or 1)
  t:SetHeight(1)
  return t
end

---An icon texture from a name ("INV_Misc_Book_09"), a full path or a file id.
function UI.SetIcon(tex, icon)
  if type(icon) == "number" or (type(icon) == "string" and icon:match("^%d+$")) then
    tex:SetTexture(tonumber(icon))
  elseif type(icon) == "string" and icon:find("\\", 1, true) then
    tex:SetTexture(icon)
  else
    tex:SetTexture("Interface\\Icons\\" .. (icon and icon ~= "" and icon or "INV_Misc_QuestionMark"))
  end
  tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
end

function UI.IconButton(parent, size)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(size, size)
  UI.Panel(b, UI.C.ink3, UI.C.line2)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 1, -1)
  b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(UI.C.accent.r, UI.C.accent.g, UI.C.accent.b) if self.onEnter then self.onEnter(self) end end)
  b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(UI.C.line2.r, UI.C.line2.g, UI.C.line2.b) GameTooltip:Hide() end)
  return b
end

---style: nil (plain), "primary" (filled accent), "quiet" (text only)
function UI.Button(parent, label, style, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  local primary = style == "primary"
  UI.Panel(b, primary and UI.C.accent or UI.C.ink3, primary and UI.C.accent or UI.C.line2)
  if style == "quiet" then b:SetBackdropColor(0, 0, 0, 0) b:SetBackdropBorderColor(0, 0, 0, 0) end
  b.label = UI.Text(b, "bold", 13, primary and hex("1b1324") or UI.C.text)
  b.label:SetPoint("CENTER")
  b.label:SetWordWrap(false)
  function b:SetLabel(text)
    self.label:SetText(text)
    self:SetSize(math.max(self.label:GetStringWidth() + 22, 40), 24)
  end
  b:SetLabel(label)
  b:SetScript("OnClick", function(self, button) if onClick then onClick(self, button) end end)
  b:SetScript("OnEnter", function(self)
    if not primary then self:SetBackdropBorderColor(UI.C.accent.r, UI.C.accent.g, UI.C.accent.b) end
    if self.tip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(self)
    if style == "quiet" then self:SetBackdropBorderColor(0, 0, 0, 0)
    elseif not primary then self:SetBackdropBorderColor(UI.C.line2.r, UI.C.line2.g, UI.C.line2.b) end
    GameTooltip:Hide()
  end)
  return b
end

---A pill: "● In character" in the status colour.
function UI.Pill(parent)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  UI.Panel(f, hex("000000", 0), UI.C.line2)
  f.dot = f:CreateTexture(nil, "ARTWORK")
  f.dot:SetTexture(WHITE)
  f.dot:SetSize(6, 6)
  f.dot:SetPoint("LEFT", 7, 0)
  f.text = UI.Text(f, "body", 12)
  f.text:SetPoint("LEFT", f.dot, "RIGHT", 5, 0)
  f.text:SetWordWrap(false)
  function f:Set(text, color)
    color = color or UI.C.muted
    self.text:SetText(text)
    UI.Color(self.text, color)
    self.dot:SetVertexColor(color.r, color.g, color.b)
    self:SetBackdropBorderColor(color.r, color.g, color.b, 0.8)
    self:SetSize(self.text:GetStringWidth() + 24, 18)
    self:SetShown(text ~= nil and text ~= "")
  end
  return f
end

function UI.StatusPill(parent)
  local p = UI.Pill(parent)
  function p:SetStatus(view)
    if view and view.status then
      self:Set(G.Profile.STATUS_LABEL[view.status], UI.STATUS_COLOR[view.status])
    elseif view and view.statusText then
      self:Set(view.statusText, UI.C.muted)
    else
      self:Set(nil)
    end
  end
  return p
end

---A movable window that remembers where it was, closes on Esc, and has a title and a close button.
function UI.Window(name, title, width, height)
  local w = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  UI.Panel(w, UI.C.ink, UI.C.line)
  w:SetSize(width, height)
  w:SetFrameStrata("HIGH")
  w:SetToplevel(true)
  w:SetClampedToScreen(true)
  w:EnableMouse(true)
  w:SetMovable(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function(self) self:StartMoving() end)
  w:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint()
    G.db.ui[name] = { point, rel, x, y }
  end)
  w:Hide()
  table.insert(UISpecialFrames, name)
  w.title = UI.Text(w, "title", 22)
  w.title:SetPoint("TOPLEFT", 16, -14)
  w.title:SetText(title or "")
  w.close = UI.Button(w, "x", "quiet", function() w:Hide() end)
  w.close:SetSize(24, 24)
  w.close:SetPoint("TOPRIGHT", -8, -8)
  function w:Place()
    self:ClearAllPoints()
    local pos = G.db and G.db.ui[name]
    if pos and pos[1] then self:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
    else self:SetPoint("CENTER") end
  end
  w:SetScript("OnShow", function(self) if not self.placed then self.placed = true self:Place() end end)
  return w
end

---Tabs along a line. items = { {key, label} }. onSelect(key).
function UI.Tabs(parent, items, onSelect)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetHeight(30)
  bar.buttons = {}
  local x = 0
  for _, item in ipairs(items) do
    local b = CreateFrame("Button", nil, bar)
    b.key = item[1]
    b.text = UI.Text(b, "body", 14, UI.C.muted)
    b.text:SetPoint("CENTER")
    b.text:SetText(item[2])
    b.text:SetWordWrap(false)
    b:SetSize(b.text:GetStringWidth() + 24, 30)
    b:SetPoint("BOTTOMLEFT", x, 0)
    x = x + b:GetWidth()
    b.line = b:CreateTexture(nil, "ARTWORK")
    b.line:SetTexture(WHITE)
    b.line:SetHeight(2)
    b.line:SetPoint("BOTTOMLEFT")
    b.line:SetPoint("BOTTOMRIGHT")
    b:SetScript("OnClick", function() bar:Select(item[1]) end)
    bar.buttons[#bar.buttons + 1] = b
  end
  local rule = UI.Rule(bar)
  rule:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  rule:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  function bar:Select(key, silent)
    self.selected = key
    for _, b in ipairs(self.buttons) do
      local on = b.key == key
      UI.Color(b.text, on and UI.C.accent or UI.C.muted)
      b.line:SetVertexColor(UI.C.accent.r, UI.C.accent.g, UI.C.accent.b, on and 1 or 0)
    end
    if not silent and onSelect then onSelect(key) end
  end
  function bar:SetShownKey(key, shown)
    for _, b in ipairs(self.buttons) do if b.key == key then b:SetShown(shown) end end
  end
  return bar
end

---A one-of-several picker. items = { {key, label, tip} }.
function UI.Segmented(parent, items, onSelect)
  local seg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  UI.Panel(seg, hex("000000", 0), UI.C.line2)
  seg.buttons = {}
  local x = 1
  for _, item in ipairs(items) do
    local b = CreateFrame("Button", nil, seg, "BackdropTemplate")
    UI.Panel(b, hex("000000", 0), hex("000000", 0))
    b.key = item[1]
    b.text = UI.Text(b, "body", 13, UI.C.muted)
    b.text:SetPoint("CENTER")
    b.text:SetText(item[2])
    b.text:SetWordWrap(false)
    b:SetSize(b.text:GetStringWidth() + 20, 22)
    b:SetPoint("LEFT", x, 0)
    x = x + b:GetWidth()
    b:SetScript("OnClick", function() seg:Select(item[1]) end)
    if item[3] then
      b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:SetText(item[3], 1, 1, 1, 1, true) GameTooltip:Show() end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    seg.buttons[#seg.buttons + 1] = b
  end
  seg:SetSize(x + 1, 24)
  function seg:Select(key, silent)
    self.selected = key
    for _, b in ipairs(self.buttons) do
      local on = b.key == key
      b:SetBackdropColor(UI.C.accent.r, UI.C.accent.g, UI.C.accent.b, on and 0.18 or 0)
      UI.Color(b.text, on and UI.C.text or UI.C.muted)
    end
    if not silent and onSelect then onSelect(key) end
  end
  return seg
end

---A labelled single-line input with a character count. onChange(text) as you type.
function UI.Input(parent, label, limit, onChange)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(46)
  f.label = UI.Text(f, "body", 12, UI.C.muted)
  f.label:SetPoint("TOPLEFT")
  f.label:SetText(label)
  f.count = UI.Text(f, "body", 11, UI.C.faint)
  f.count:SetPoint("TOPRIGHT")
  local box = CreateFrame("EditBox", nil, f, "BackdropTemplate")
  UI.Panel(box, UI.C.field, UI.C.line2)
  box:SetPoint("TOPLEFT", 0, -16)
  box:SetPoint("TOPRIGHT", 0, -16)
  box:SetHeight(28)
  box:SetAutoFocus(false)
  box:SetFontObject(UI.Font("body", 14))
  box:SetTextInsets(8, 8, 0, 0)
  if limit then box:SetMaxLetters(limit) end
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  box:SetScript("OnTextChanged", function(self, user)
    local text = self:GetText() or ""
    if limit then f.count:SetText(#text .. "/" .. limit) end
    if user and onChange then onChange(text) end
  end)
  f.box = box
  function f:SetText(text) box:SetText(text or "") end
  function f:GetText() return box:GetText() end
  return f
end

---A scrolling multi-line input. onChange(text).
function UI.TextArea(parent, limit, onChange)
  local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  UI.Panel(frame, UI.C.field, UI.C.line2)
  local scroll = CreateFrame("ScrollFrame", nil, frame)
  scroll:SetPoint("TOPLEFT", 8, -6)
  scroll:SetPoint("BOTTOMRIGHT", -8, 6)
  local box = CreateFrame("EditBox", nil, scroll)
  box:SetMultiLine(true)
  box:SetAutoFocus(false)
  box:SetFontObject(UI.Font("body", 14))
  box:SetWidth(300)
  if limit then box:SetMaxLetters(limit) end
  scroll:SetScrollChild(box)
  scroll:SetScript("OnSizeChanged", function(self, w) box:SetWidth(w) end)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local max = math.max(0, box:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 30)))
  end)
  box:SetScript("OnCursorChanged", function(_, _, y, _, h)
    local top = scroll:GetVerticalScroll()
    if -y < top then scroll:SetVerticalScroll(-y)
    elseif -y + h > top + scroll:GetHeight() then scroll:SetVerticalScroll(-y + h - scroll:GetHeight()) end
  end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnTextChanged", function(self, user)
    if frame.count and limit then frame.count:SetText(#(self:GetText() or "") .. "/" .. limit) end
    if user and onChange then onChange(self:GetText() or "") end
  end)
  frame:EnableMouse(true)
  frame:SetScript("OnMouseDown", function() box:SetFocus() end)
  frame.box = box
  function frame:SetText(text) box:SetText(text or "") end
  function frame:GetText() return box:GetText() end
  return frame
end

---A scrolling area for read-only content; .content is the child to build on.
function UI.ScrollArea(parent)
  local scroll = CreateFrame("ScrollFrame", nil, parent)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(10, 10)
  scroll:SetScrollChild(content)
  scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local max = math.max(0, content:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 40)))
  end)
  scroll.content = content
  return scroll
end

---A virtual list with fixed-height rows. opts = { rowHeight, create(row), update(row, item), click(item, button) }
function UI.List(parent, opts)
  local list = CreateFrame("Frame", nil, parent)
  list.rows, list.items, list.offset = {}, {}, 0
  local h = opts.rowHeight
  list:EnableMouseWheel(true)
  local function visible() return math.max(1, math.floor((list:GetHeight() or 0) / h)) end
  function list:Refresh()
    local n = visible()
    for i = 1, n do
      local row = self.rows[i]
      if not row then
        row = CreateFrame("Button", nil, self)
        row:SetHeight(h)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.hl = row:CreateTexture(nil, "BACKGROUND")
        row.hl:SetTexture(WHITE)
        row.hl:SetAllPoints()
        row.hl:SetVertexColor(UI.C.accent.r, UI.C.accent.g, UI.C.accent.b, 0)
        row:SetScript("OnEnter", function(r) r.hl:SetVertexColor(UI.C.accent.r, UI.C.accent.g, UI.C.accent.b, 0.1) end)
        row:SetScript("OnLeave", function(r) r.hl:SetVertexColor(UI.C.accent.r, UI.C.accent.g, UI.C.accent.b, 0) end)
        row:SetScript("OnClick", function(r, button) if r.item and opts.click then opts.click(r.item, button, r) end end)
        local rule = UI.Rule(row)
        rule:SetPoint("BOTTOMLEFT")
        rule:SetPoint("BOTTOMRIGHT")
        opts.create(row)
        self.rows[i] = row
      end
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 0, -(i - 1) * h)
      row:SetPoint("TOPRIGHT", 0, -(i - 1) * h)
      local item = self.items[self.offset + i]
      row.item = item
      if item then opts.update(row, item) row:Show() else row:Hide() end
    end
    for i = n + 1, #self.rows do self.rows[i]:Hide() end
  end
  function list:SetItems(items)
    self.items = items
    self.offset = math.max(0, math.min(self.offset, #items - visible()))
    self:Refresh()
  end
  list:SetScript("OnMouseWheel", function(self, delta)
    self.offset = math.max(0, math.min(self.offset - delta * 3, #self.items - visible()))
    self:Refresh()
  end)
  list:SetScript("OnSizeChanged", function(self) self:Refresh() end)
  return list
end

---A settings row: label, description, and a two-way switch.
function UI.Toggle(parent, label, desc, get, set)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(desc and 44 or 30)
  row.label = UI.Text(row, "body", 14)
  row.label:SetPoint("TOPLEFT", 0, -4)
  row.label:SetText(label)
  if desc then
    row.desc = UI.Text(row, "body", 12, UI.C.faint)
    row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
    row.desc:SetPoint("RIGHT", -120, 0)
    row.desc:SetText(desc)
  end
  row.seg = UI.Segmented(row, { { false, "Off" }, { true, "On" } }, function(v) set(v) end)
  row.seg:SetPoint("TOPRIGHT", 0, -2)
  function row:Refresh() self.seg:Select(get() and true or false, true) end
  row:Refresh()
  return row
end
