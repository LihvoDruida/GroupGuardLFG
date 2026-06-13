-- GroupGuard LFG — Core / Social
local addonName, addon = ...

local function GGNameKey(name)
  if type(name) ~= "string" or name == "" then return nil end
  local base = name:match("^([^-]+)") or name
  return string.lower(base)
end

function addon:NormalizeNameKey(name)
  return GGNameKey(name)
end

local function AddFriendName(cache, name)
  local key = GGNameKey(name)
  if key then cache[key] = true end
end

function addon:RebuildFriendCache(force)
  local now = GetTime and GetTime() or 0
  if not force and self._friendCache and (self._friendCacheBuiltAt or 0) + 15 > now then return end

  local cache = {}

  if C_FriendList then
    if C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
      local okN, n = pcall(C_FriendList.GetNumFriends)
      n = okN and tonumber(n) or 0
      for i = 1, n do
        local ok, info = pcall(C_FriendList.GetFriendInfoByIndex, i)
        if ok then
          if type(info) == "table" then
            AddFriendName(cache, info.name)
          elseif type(info) == "string" then
            AddFriendName(cache, info)
          end
        end
      end
    end
  end

  if GetNumFriends and GetFriendInfo then
    local okN, n = pcall(GetNumFriends)
    n = okN and tonumber(n) or 0
    for i = 1, n do
      local ok, name = pcall(GetFriendInfo, i)
      if ok then AddFriendName(cache, name) end
    end
  end

  if C_BattleNet and C_BattleNet.GetFriendNumGameAccounts and C_BattleNet.GetFriendGameAccountInfo and C_BattleNet.GetNumFriends then
    local okN, n = pcall(C_BattleNet.GetNumFriends)
    n = okN and tonumber(n) or 0
    for i = 1, n do
      local okG, gameAccounts = pcall(C_BattleNet.GetFriendNumGameAccounts, i)
      gameAccounts = okG and tonumber(gameAccounts) or 0
      for j = 1, gameAccounts do
        local ok, info = pcall(C_BattleNet.GetFriendGameAccountInfo, i, j)
        if ok and type(info) == "table" then
          AddFriendName(cache, info.characterName)
        end
      end
    end
  end

  if BNGetNumFriends and BNGetNumFriendGameAccounts and BNGetFriendGameAccountInfo then
    local okN, n = pcall(BNGetNumFriends)
    n = okN and tonumber(n) or 0
    for i = 1, n do
      local okG, gameAccounts = pcall(BNGetNumFriendGameAccounts, i)
      gameAccounts = okG and tonumber(gameAccounts) or 0
      for j = 1, gameAccounts do
        local ok, _, _, _, characterName = pcall(BNGetFriendGameAccountInfo, i, j)
        if ok then AddFriendName(cache, characterName) end
      end
    end
  end

  self._friendCache = cache
  self._friendCacheBuiltAt = now
end

function addon:RebuildGuildCache(force)
  local now = GetTime and GetTime() or 0
  if not force and self._guildCache and (self._guildCacheBuiltAt or 0) + 30 > now then return end

  local cache = {}
  local rankIndexCache = {}
  local rankNameCache = {}
  local rankNameByIndex = {}

  if IsInGuild and IsInGuild() and GuildRoster then
    pcall(GuildRoster)
  end

  if GetNumGuildMembers and GetGuildRosterInfo then
    local okN, n = pcall(GetNumGuildMembers)
    n = okN and tonumber(n) or 0
    for i = 1, n do
      local ok, fullName, rankName, rankIndex = pcall(GetGuildRosterInfo, i)
      if ok then
        local key = GGNameKey(fullName)
        if key then
          cache[key] = true
          rankIndex = tonumber(rankIndex)
          rankIndexCache[key] = rankIndex
          rankNameCache[key] = type(rankName) == "string" and rankName or ""
          if rankIndex ~= nil and type(rankName) == "string" and rankName ~= "" then
            rankNameByIndex[rankIndex] = rankName
          end
        end
      end
    end
  end

  self._guildCache = cache
  self._guildRankIndexCache = rankIndexCache
  self._guildRankNameCache = rankNameCache
  self._guildRankNameByIndex = rankNameByIndex
  self._guildCacheBuiltAt = now
end

function addon:BuildNameSet(text)
  local set = {}
  if type(text) ~= "string" then return set end
  for raw in string.gmatch(text, "[^,;\n\r]+") do
    local name = string.gsub(raw or "", "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    local key = GGNameKey(name)
    if key then set[key] = true end
  end
  return set
end

function addon:GetRaidAssistSelectedRankSet()
  local text = self.db and self.db.raid_assist_selected_ranks or ""
  if self._raidAssistRankSet and self._raidAssistRankSetText == text then return self._raidAssistRankSet end

  local set = {}
  for part in string.gmatch(tostring(text or ""), "([^,]+)") do
    local n = tonumber((part or ""):match("^%s*(.-)%s*$"))
    if n ~= nil then set[n] = true end
  end

  self._raidAssistRankSet = set
  self._raidAssistRankSetText = text
  return set
end

function addon:GetRaidAssistSelectedRankText()
  local set = self:GetRaidAssistSelectedRankSet()
  local names = {}
  local opts = self:GetGuildRankOptions()
  for _, opt in ipairs(opts or {}) do
    if set[opt.index] then names[#names + 1] = opt.name end
  end
  if #names == 0 then return self:Tr("NONE_SELECTED") end
  return table.concat(names, ", ")
end

function addon:SetRaidAssistRankSelected(rankIndex, selected)
  rankIndex = tonumber(rankIndex)
  if rankIndex == nil then return end

  local set = self:GetRaidAssistSelectedRankSet()
  set[rankIndex] = selected and true or nil

  local keys = {}
  for idx in pairs(set) do keys[#keys + 1] = tonumber(idx) end
  table.sort(keys)

  local parts = {}
  for _, idx in ipairs(keys) do parts[#parts + 1] = tostring(idx) end

  self.db.raid_assist_selected_ranks = table.concat(parts, ",")
  self._raidAssistRankSetText = nil
  self._raidAssistRankSet = nil
end

function addon:GetGuildRankOptions()
  if IsInGuild and IsInGuild() and GuildRoster then pcall(GuildRoster) end
  if self.RebuildGuildCache then self:RebuildGuildCache(false) end

  local byIndex = {}

  if type(self._guildRankNameByIndex) == "table" then
    for idx, name in pairs(self._guildRankNameByIndex) do
      if tonumber(idx) ~= nil and type(name) == "string" and name ~= "" then
        byIndex[tonumber(idx)] = name
      end
    end
  end

  if GuildControlGetNumRanks and GuildControlGetRankName then
    local okN, n = pcall(GuildControlGetNumRanks)
    n = okN and tonumber(n) or 0
    for i = 1, n do
      local okName, rName = pcall(GuildControlGetRankName, i)
      -- GuildControlGetRankName can be 1-based while roster rankIndex is 0-based.
      local idx = i - 1
      if okName and type(rName) == "string" and rName ~= "" then
        byIndex[idx] = byIndex[idx] or rName
      end
    end
  end

  local result = {}
  for idx, name in pairs(byIndex) do
    result[#result + 1] = { index = tonumber(idx), name = tostring(name) }
  end
  table.sort(result, function(a, b) return (a.index or 0) < (b.index or 0) end)
  return result
end

function addon:IsSelectedRaidAssistRankIndex(rankIndex)
  rankIndex = tonumber(rankIndex)
  if rankIndex == nil then return false end
  local set = self:GetRaidAssistSelectedRankSet()
  return set and set[rankIndex] and true or false
end

function addon:IsManualRaidAssistName(name)
  local key = GGNameKey(name)
  if not key then return false end
  self._raidAssistManualSetText = self._raidAssistManualSetText or nil
  local text = self.db and self.db.raid_assist_manual_names or ""
  if not self._raidAssistManualSet or self._raidAssistManualSetText ~= text then
    self._raidAssistManualSet = self:BuildNameSet(text)
    self._raidAssistManualSetText = text
  end
  return self._raidAssistManualSet and self._raidAssistManualSet[key] and true or false
end

function addon:IsGuildOfficerName(name)
  local key = GGNameKey(name)
  if not key then return false end
  self:RebuildGuildCache(false)

  local rankIndex = self._guildRankIndexCache and self._guildRankIndexCache[key]
  local selectedText = self.db and tostring(self.db.raid_assist_selected_ranks or "") or ""
  if selectedText ~= "" then
    return self:IsSelectedRaidAssistRankIndex(rankIndex)
  end

  local maxRank = tonumber(self.db and self.db.raid_assist_officer_rank_max) or 2
  if maxRank < 0 then maxRank = 0 elseif maxRank > 9 then maxRank = 9 end
  if rankIndex ~= nil and tonumber(rankIndex) ~= nil and tonumber(rankIndex) <= maxRank then
    return true
  end

  local rankName = self._guildRankNameCache and self._guildRankNameCache[key]
  if type(rankName) == "string" and rankName ~= "" then
    local lowered = string.lower(rankName)
    local keywords = self.db and self.db.raid_assist_officer_keywords or ""
    for raw in string.gmatch(keywords, "[^,;\n\r]+") do
      local kw = string.gsub(raw or "", "^%s+", "")
      kw = string.gsub(kw, "%s+$", "")
      local kwLower = string.lower(kw)
      if kw ~= "" and (string.find(rankName, kw, 1, true) or string.find(lowered, kwLower, 1, true)) then return true end
    end
  end
  return false
end

function addon:ShouldGiveRaidAssist(name)
  if not (self.db and self.db.raid_assist_enabled) then return false, nil end
  if self:IsManualRaidAssistName(name) then return true, "manual" end
  if self.db.raid_assist_guild_officers and self:IsGuildOfficerName(name) then return true, "officer" end
  return false, nil
end
function addon:IsGuildMemberName(name)
  local key = GGNameKey(name)
  if not key then return false end
  self:RebuildGuildCache(false)
  return self._guildCache and self._guildCache[key] and true or false
end

function addon:IsFriendName(name)
  local key = GGNameKey(name)
  if not key then return false end
  self:RebuildFriendCache(false)
  return self._friendCache and self._friendCache[key] and true or false
end

function addon:IsGuildUnit(unit, guildName)
  if unit and UnitIsInMyGuild then
    local ok, v = pcall(UnitIsInMyGuild, unit)
    if ok and v then return true end
  end

  if guildName and GetGuildInfo then
    local ok, myGuild = pcall(GetGuildInfo, "player")
    if ok and type(myGuild) == "string" and myGuild ~= "" and guildName == myGuild then
      return true
    end
  end

  return false
end

function addon:GetUnitSocialStatus(unit, name, guildName)
  if unit and UnitIsUnit then
    local ok, same = pcall(UnitIsUnit, unit, "player")
    if ok and same then return nil end
  end

  if name and self:IsFriendName(name) then
    return "FRIEND"
  end
  if self:IsGuildUnit(unit, guildName) or self:IsGuildMemberName(name) then
    return "GUILD"
  end
  return nil
end

function addon:ShouldIgnoreFilteredUnit(unit, name, guildName)
  local isFriend = name and self:IsFriendName(name) or false
  local isGuild = self:IsGuildUnit(unit, guildName) or (name and self:IsGuildMemberName(name) or false)

  if isFriend and self.db and self.db.social_ignore_friends then
    return true, "FRIEND"
  end
  if isGuild and self.db and self.db.social_ignore_guild then
    return true, "GUILD"
  end
  if isFriend then return false, "FRIEND" end
  if isGuild then return false, "GUILD" end
  return false, nil
end

function addon:ShouldIgnoreFilteredName(name)
  if self.db and self.db.social_ignore_friends and self:IsFriendName(name) then
    return true, "FRIEND"
  end
  if self.db and self.db.social_ignore_guild and self:IsGuildMemberName(name) then
    return true, "GUILD"
  end
  if self:IsFriendName(name) then return false, "FRIEND" end
  if self:IsGuildMemberName(name) then return false, "GUILD" end
  return false, nil
end

