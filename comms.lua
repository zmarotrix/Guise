-- Talking MSP: asking people for their profile and answering when they ask for yours. Add-on whispers only.
--
-- Pacing, from the spec and Retail's limits:
--   - the same field from the same person at most once every 15 s;
--   - someone who never answers isn't asked again for 5 minutes (they probably run no RP add-on);
--   - a description goes to the same person at most once every 30 s, however often they ask;
--   - nothing goes out in chat lockdown or an encounter, Mythic+ or PvP match restriction, or in battlegrounds unless allowed.
-- ChatThrottleLib paces the bytes.

local G = Guise
local MSP, Text, Cache, Names, Profile = G.MSP, G.Text, G.Cache, G.Names, G.Profile
local Comms = { asked = {}, servedBig = {}, buffers = {}, waiting = {} }
G.Comms = Comms

Comms.FIELD_GAP = 15
Comms.NO_ANSWER_WAIT = 60
Comms.QUIET_FOR = 300
Comms.BIG_GAP = 30
Comms.MAX_BUFFER = 24000
Comms.stats = { sent = 0, received = 0, blocked = 0 }

local PREFIX_SET = {}
for _, p in ipairs(MSP.PREFIXES) do PREFIX_SET[p] = true end

for _, prefix in ipairs(MSP.PREFIXES) do
  G.In("C_ChatInfo", "RegisterAddonMessagePrefix", prefix)
end

local function ignored(name)
  return G.In("C_FriendList", "IsIgnored", name) == true or G.Call("IsIgnored", name) == true
end

local function deliver(messages, target, priority)
  local ctl = rawget(_G, "ChatThrottleLib")
  for _, m in ipairs(messages) do
    if ctl then
      ctl:SendAddonMessage(priority or "NORMAL", m[1], m[2], "WHISPER", target, "Guise:" .. target)
    else
      G.In("C_ChatInfo", "SendAddonMessage", m[1], m[2], "WHISPER", target)
    end
    Comms.stats.sent = Comms.stats.sent + 1
  end
end

---Can Guise send now? Returns false and a reason when it shouldn't.
function Comms:CanSend()
  if not G.ready then return false, "loading" end
  if G.Quiet() then return false, "pvp" end
  local blocked = G.SendBlocked()
  if blocked then return false, blocked end
  return true
end

---Asks `name` for fields. Skips what was asked recently. Returns true if a request went out.
function Comms:Request(name, fields)
  if not name or not Text.IsFull(name) or Names:IsMe(name) or ignored(name) then return false end
  local ok, why = self:CanSend()
  if not ok then self.stats.blocked = self.stats.blocked + 1 return false, why end
  local person = Cache:Ensure(name)
  local now = G.Now()
  if person.quietUntil and now < person.quietUntil then return false, "quiet" end
  local asked = self.asked[name] or {}
  self.asked[name] = asked
  local clock = G.Clock()
  local want = {}
  for _, field in ipairs(fields) do
    if not asked[field] or clock - asked[field] >= self.FIELD_GAP then
      want[#want + 1] = field
      asked[field] = clock
    end
  end
  if #want == 0 then return false, "recent" end
  local versions = {}
  for k, v in pairs(person.v) do versions[k] = v end
  versions.TT = person.tt
  deliver(MSP.Pack(MSP.Requests(want, versions)), name, "ALERT")
  person.asked = now
  if not self.waiting[name] then
    self.waiting[name] = clock
    G:Later(self.NO_ANSWER_WAIT, function()
      if self.waiting[name] then
        self.waiting[name] = nil
        local p = Cache:Get(name)
        if p and not Cache:HasProfile(name) then p.quietUntil = G.Now() + self.QUIET_FOR end
      end
    end)
  end
  return true
end

-- what to ask for, by how closely you're looking
function Comms:ForHover(name) return self:Request(name, { "TT", unpack(MSP.TT_EXTRA) }) end
function Comms:ForTarget(name) return self:Request(name, { "TT", "PE", unpack(MSP.TT_EXTRA) }) end
function Comms:ForSheet(name)
  local fields = { "TT" }
  for _, f in ipairs(MSP.TT_EXTRA) do fields[#fields + 1] = f end
  for _, f in ipairs(MSP.FOR_SHEET) do fields[#fields + 1] = f end
  return self:Request(name, fields)
end

-------------------------------------------------------------------------------------------
-- Receiving
-------------------------------------------------------------------------------------------

local function answer(name, requests)
  if not Comms:CanSend() then Comms.stats.blocked = Comms.stats.blocked + 1 return end
  local own = Profile:Served()
  local chunks, big = MSP.Answer(requests, own)
  if big then
    local last = Comms.servedBig[name]
    if last and G.Clock() - last < Comms.BIG_GAP then
      -- they asked again too soon: answer the small fields, and say the big ones haven't changed for them
      local kept = {}
      for _, chunk in ipairs(chunks) do
        local _, field = MSP.ParseChunk(chunk)
        if not Cache.BIG[field] then kept[#kept + 1] = chunk end
      end
      chunks, big = kept, false
    else
      Comms.servedBig[name] = G.Clock()
    end
  end
  if #chunks > 0 then deliver(MSP.Pack(chunks), name, big and "BULK" or "NORMAL") end
end

function Comms:Handle(name, text)
  local requests, changed, any = {}, {}, false
  for _, chunk in ipairs(MSP.Split(text)) do
    local kind, field, ver, value = MSP.ParseChunk(chunk)
    if kind == "?" then
      requests[#requests + 1] = chunk
    elseif kind == "=" then
      any = true
      if Cache:Set(name, field, ver, value) then changed[field] = true end
      if field == "GU" and value and value ~= "" then Names:Learn(name, value) end
    elseif kind == "!" then
      any = true
    end
  end
  if any then
    self.waiting[name] = nil
    local p = Cache:Ensure(name)
    p.answered, p.quietUntil = G.Now(), nil
    p.seen = p.seen or G.Now()
    if next(changed) then G:Fire("GUISE_PROFILE_UPDATED", name, changed) end
  end
  if #requests > 0 then answer(name, requests) end
end

function Comms:OnMessage(prefix, text, channel, sender)
  if not PREFIX_SET[prefix] then return end
  if G.IsSecret(text) or G.IsSecret(sender) or G.IsSecret(channel) then return end
  if channel ~= "WHISPER" or type(sender) ~= "string" or type(text) ~= "string" then return end
  if Names:IsMe(sender) or ignored(sender) then return end
  self.stats.received = self.stats.received + 1
  Names:Learn(sender)
  if prefix == "MSP" then
    self:Handle(sender, text)
  elseif prefix == "MSP\1" then
    self.buffers[sender] = { text }
  else
    local buf = self.buffers[sender]
    if not buf then return end      -- a middle or last part without its first: drop it
    buf[#buf + 1] = text
    local size = 0
    for _, part in ipairs(buf) do size = size + #part end
    if size > self.MAX_BUFFER then self.buffers[sender] = nil return end
    if prefix == "MSP\3" then
      self.buffers[sender] = nil
      self:Handle(sender, table.concat(buf))
    end
  end
end

G:On("CHAT_MSG_ADDON", function(_, prefix, text, channel, sender)
  Comms:OnMessage(prefix, text, channel, sender)
end)
