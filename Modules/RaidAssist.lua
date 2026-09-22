-- GroupGuard LFG — Modules / Raid Assist
local addonName, addon = ...

local C_Timer = C_Timer

-- Raid assistant auto-assign
--------------------------------------------------

local function PromoteAssistantCompat(fullName, shortName)
  local name = fullName or shortName
  if type(name) ~= "string" or name == "" then return false end

  if type(C_PartyInfo) == "table" and type(C_PartyInfo.PromoteToAssistant) == "function" then
    local ok = pcall(C_PartyInfo.PromoteToAssistant, name, true)
    if ok then return true end
    if shortName and shortName ~= name then
      ok = pcall(C_PartyInfo.PromoteToAssistant, shortName)
      if ok then return true end
    end
  end

  if type(PromoteToAssistant) == "function" then
    local ok = pcall(PromoteToAssistant, name)
    if ok then return true end
    if shortName and shortName ~= name then
      ok = pcall(PromoteToAssistant, shortName)
      if ok then return true end
    end
  end

  return false
end

local function RaidAssistNameKey(name)
  if addon and addon.NormalizeNameKey then return addon:NormalizeNameKey(name) end
  if type(name) ~= "string" or name == "" then return nil end
  local base = name:match("^([^-]+)") or name
  return string.lower(base)
end

local function UnitIsAssistantOrLeader(unit)
  if not unit then return false end
  -- 12.1: these return secrets for units with a secret identity.
  local Safe = addon.Safe
  if Safe and Safe.IsAssistantOrLeader then return Safe.IsAssistantOrLeader(unit) end
  return false
end

local function SafeIsInRaid()
  if addon and addon.Safe and addon.Safe.IsInRaid then return addon.Safe.IsInRaid() end
  if not IsInRaid then return false end
  local ok, value = pcall(IsInRaid)
  return ok and value == true or false
end

function addon:CanAutoRaidAssist()
  if self.SupportsRaidAssistActions and not self:SupportsRaidAssistActions() then return false end
  if not (self.db and self.db.raid_assist_enabled) then return false end
  if not SafeIsInRaid() then return false end
  local Safe = addon.Safe
  if not (Safe and Safe.IsGroupLeader and Safe.IsGroupLeader("player")) then return false end
  return true
end

function addon:ApplyRaidAssistNow(reason)
  if not self:CanAutoRaidAssist() then return 0 end

  local Safe = self.Safe
  if Safe and Safe.UnitAffectingCombat and Safe.UnitAffectingCombat("player") then
    self._raidAssistQueued = true
    return 0
  end

  local inGuild = Safe and Safe.IsInGuild and Safe.IsInGuild() or false
  if inGuild and GuildRoster then pcall(GuildRoster) end
  if self.RebuildGuildCache then self:RebuildGuildCache(false) end

  local num = self.GetGroupMemberCount and self:GetGroupMemberCount() or (GetNumGroupMembers and (GetNumGroupMembers() or 0) or 0)
  local promoted = 0
  local promotedNames = {}
  self._raidAssistLastPromoted = self._raidAssistLastPromoted or {}

  for i = 1, num do
    local unit = "raid" .. i
    local fullName, name
    if Safe and Safe.UnitFullName then fullName, name = Safe.UnitFullName(unit) end
    if name then
      local isPlayer = Safe and Safe.UnitIsUnit and Safe.UnitIsUnit(unit, "player") or false
      if not isPlayer and not UnitIsAssistantOrLeader(unit) then
        local okGive, give, why = pcall(function() return self:ShouldGiveRaidAssist(name) end)
        if okGive and give then
          local okPromote = PromoteAssistantCompat(fullName, name)
          if okPromote then
            promoted = promoted + 1
            promotedNames[#promotedNames + 1] = name
            self._raidAssistLastPromoted[RaidAssistNameKey(name) or name] = GetTime and GetTime() or 0
          end
        end
      end
    end
  end

  if promoted > 0 and self.db and self.db.raid_assist_notify then
    local list = table.concat(promotedNames, ", ")
    print((self.printPrefix or "GroupGuard LFG:"), addon:Tr("RAID_ASSIST_GRANTED", list))
  end
  return promoted
end

function addon:ScheduleRaidAssist(delay, reason)
  if not (self.db and self.db.raid_assist_enabled) then return end
  delay = tonumber(delay) or 0.05
  if self._raidAssistPending then return end
  self._raidAssistPending = true
  local function run()
    addon._raidAssistPending = false
    if addon.ApplyRaidAssistNow then addon:ApplyRaidAssistNow(reason or "schedule") end
  end
  if delay <= 0.01 then run() elseif C_Timer and C_Timer.After then C_Timer.After(delay, run) else run() end
end

