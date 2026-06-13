-- GroupGuard LFG — Modules / Raid Assist
local addonName, addon = ...

local C_Timer = C_Timer

-- Raid assistant auto-assign
--------------------------------------------------

local function RaidAssistNameKey(name)
  if addon and addon.NormalizeNameKey then return addon:NormalizeNameKey(name) end
  if type(name) ~= "string" or name == "" then return nil end
  local base = name:match("^([^-]+)") or name
  return string.lower(base)
end

local function UnitIsAssistantOrLeader(unit)
  if not unit then return false end
  if UnitIsGroupLeader then
    local ok, v = pcall(UnitIsGroupLeader, unit)
    if ok and v then return true end
  end
  if UnitIsGroupAssistant then
    local ok, v = pcall(UnitIsGroupAssistant, unit)
    if ok and v then return true end
  end
  return false
end

function addon:CanAutoRaidAssist()
  if not (self.db and self.db.raid_assist_enabled) then return false end
  if not IsInRaid or not IsInRaid() then return false end
  if UnitIsGroupLeader then
    local ok, leader = pcall(UnitIsGroupLeader, "player")
    if not ok or not leader then return false end
  else
    return false
  end
  return true
end

function addon:ApplyRaidAssistNow(reason)
  if not self:CanAutoRaidAssist() then return 0 end

  if UnitAffectingCombat and UnitAffectingCombat("player") then
    self._raidAssistQueued = true
    return 0
  end

  if IsInGuild and IsInGuild() and GuildRoster then pcall(GuildRoster) end
  if self.RebuildGuildCache then self:RebuildGuildCache(false) end

  local num = GetNumGroupMembers and (GetNumGroupMembers() or 0) or 0
  local promoted = 0
  local promotedNames = {}
  self._raidAssistLastPromoted = self._raidAssistLastPromoted or {}

  for i = 1, num do
    local unit = "raid" .. i
    local okName, name = pcall(UnitName, unit)
    if okName and type(name) == "string" and name ~= "" then
      local isPlayer = false
      if UnitIsUnit then
        local okSame, same = pcall(UnitIsUnit, unit, "player")
        isPlayer = okSame and same and true or false
      end
      if not isPlayer and not UnitIsAssistantOrLeader(unit) then
        local okGive, give, why = pcall(function() return self:ShouldGiveRaidAssist(name) end)
        if okGive and give then
          local okPromote = false
          if PromoteToAssistant then
            local okUnit = pcall(PromoteToAssistant, unit)
            okPromote = okUnit and true or false
            if not okPromote then
              local okName = pcall(PromoteToAssistant, name)
              okPromote = okName and true or false
            end
          end
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
  if delay <= 0.01 then run() else C_Timer.After(delay, run) end
end

