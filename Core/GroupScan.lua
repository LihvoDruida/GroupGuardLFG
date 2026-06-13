-- GroupGuard LFG — Core / Group Scan
local addonName, addon = ...

local function SafeIsInRaid()
  if not IsInRaid then return false end
  local ok, value = pcall(IsInRaid)
  return ok and value and true or false
end

local function SafeIsInGroup()
  if not IsInGroup then return false end
  local ok, value = pcall(IsInGroup)
  return ok and value and true or false
end

local function SafeGroupCount()
  if addon and addon.GetGroupMemberCount then return addon:GetGroupMemberCount() end
  if not GetNumGroupMembers then return 0 end
  local ok, value = pcall(GetNumGroupMembers)
  return ok and tonumber(value) or 0
end

function addon:ShouldShowAlertsNow()
  if self:IsDisabledNow() then return false end
  if not (SafeIsInGroup() or SafeIsInRaid()) then return false end
  return true
end

function addon:NotifyGroupDetected(name, guild)
  if self:IsDisabledNow() then return end
  if self._alertActive then return end

  self._alertedNames = self._alertedNames or {}
  local key = name or ""

  -- During startup/reload and active actions we only update silent pending state.
  -- Do NOT mark _alertActive or _alertedNames here; otherwise the alert can be swallowed
  -- forever after ReloadUI if the offender is still present.
  if self.ShouldSuppressAlerts and self:ShouldSuppressAlerts("group_detected") then
    self._suppressedGroupAlert = { name = name, guild = guild, at = GetTime and GetTime() or 0 }
    return
  end

  -- If we already alerted for this name, restore active state without repeating sound/banner.
  if self._alertedNames[key] then
    self._alertActive = true
    return
  end

  self._alertedNames[key] = true
  self._alertActive = true
  self:PlayAlertSound()
  self:FlashScreen()
  self:ShowBanner(name or self:Tr("DETECTED_MATCH"), guild or "", false, "DETECTED", self:Tr("DEFAULT_DETAIL"))
end

function addon:CheckGroup()
  if self:IsDisabledNow() then
    return false
  end

  if SafeIsInRaid() then
    if not (self.db and self.db.show_in_raid) then return false end
  elseif SafeIsInGroup() then
    if not (self.db and self.db.show_in_party) then return false end
  else
    return false
  end

  local unitPrefix = SafeIsInRaid() and "raid" or "party"
  local num = SafeGroupCount()
  local sawNil = false

  for i = 1, num do
    local unit = unitPrefix .. i
    local okName, name, server = pcall(UnitName, unit)
    if not okName or (self.CanAccess and not self:CanAccess(name)) then name = nil end
    if not name then
      sawNil = true
    else
      local guild_name = nil
      if GetGuildInfo then
        local okGuild, g = pcall(GetGuildInfo, unit)
        if okGuild and (not self.CanAccess or self:CanAccess(g)) then guild_name = g end
      end
      local realmForExempt = server or self.realm_name
      local ignoreSocial = self:ShouldIgnoreFilteredUnit(unit, name, guild_name)
      if not ignoreSocial and not self:IsExemptUnit(name, realmForExempt, guild_name) then
        if self.db.scan_group_names and self:IsFlaggedText(name) then
          return true, name, "name", nil
        end
        if self.db.scan_group_guilds and guild_name and self:IsFlaggedText(guild_name) then
          return true, name, "guild", guild_name
        end
      end
    end
  end

  if sawNil then
    self._needsRecheck = true
  end

  return false
end
