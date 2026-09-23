-- GroupGuard LFG — Modules / Group Actions
local addonName, addon = ...

local C_Timer = C_Timer

local function SafeIsInRaid()
  if addon and addon.Safe and addon.Safe.IsInRaid then return addon.Safe.IsInRaid() end
  if not IsInRaid then return false end
  local ok, value = pcall(IsInRaid)
  return ok and value == true or false
end

local function SafeIsInGroup()
  if addon and addon.Safe and addon.Safe.IsInGroup then return addon.Safe.IsInGroup() end
  if not IsInGroup then return false end
  local ok, value = pcall(IsInGroup)
  return ok and value == true or false
end

local function SafeGroupCount()
  if addon and addon.GetGroupMemberCount then return addon:GetGroupMemberCount() end
  if not GetNumGroupMembers then return 0 end
  local ok, value = pcall(GetNumGroupMembers)
  return ok and tonumber(value) or 0
end

local function CanReadValue(value)
  if addon and addon.Safe and addon.Safe.CanReadValue then return addon.Safe.CanReadValue(value) end
  if type(canaccessvalue) == "function" then
    local ok, allowed = pcall(canaccessvalue, value)
    if not ok or allowed ~= true then return false end
  end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret == true then return false end
  end
  return value ~= nil
end

local function SafeNumber(value, fallback)
  fallback = fallback or 0
  if not CanReadValue(value) then return fallback end
  local valueType = type(value)
  if valueType == "number" then return value end
  if valueType == "string" then return tonumber(value) or fallback end
  local ok, n = pcall(tonumber, value)
  if ok and type(n) == "number" then return n end
  return fallback
end

local function NameKey(name)
  if type(name) ~= "string" or name == "" then return nil end
  return (name:match("^([^-]+)") or name)
end


local function NormalizeUnitName(name)
  if type(name) ~= "string" or name == "" then return nil end
  return string.lower(name:gsub("%s+", ""):gsub("^([^-]+)$", "%1"))
end

local function ShortName(name)
  if type(name) ~= "string" then return nil end
  return name:match("^([^-]+)") or name
end

local function FullNameFromUnit(unit, fallbackName, fallbackRealm)
  local name, realm
  local Safe = addon and addon.Safe
  if Safe and Safe.UnitFullName then
    local _, shortName, unitRealm = Safe.UnitFullName(unit)
    name, realm = shortName, unitRealm
  end

  fallbackName = addon and addon.SafeText and addon:SafeText(fallbackName) or (type(fallbackName) == "string" and fallbackName or nil)
  fallbackRealm = addon and addon.SafeText and addon:SafeText(fallbackRealm) or (type(fallbackRealm) == "string" and fallbackRealm or nil)
  name = name or fallbackName
  if addon and addon.NormalizePlayerNameForClient then
    name = addon:NormalizePlayerNameForClient(name) or name
  end

  local foreverClient = addon and addon.IsForeverClient and addon:IsForeverClient() or false
  if not foreverClient then
    realm = realm or fallbackRealm
  else
    realm = nil
  end

  if type(name) ~= "string" or name == "" then return nil end
  if type(realm) == "string" and realm ~= "" then
    return name .. "-" .. realm
  end
  return name
end

local function BuildUnitTarget(unit, fallbackName, fallbackRealm)
  if not unit then return nil end
  local full = FullNameFromUnit(unit, fallbackName, fallbackRealm)
  if not full then return nil end
  return {
    unit = unit,
    name = ShortName(full) or full,
    fullName = full,
    key = NormalizeUnitName(full),
    shortKey = NormalizeUnitName(ShortName(full)),
  }
end

local function FindGroupMemberTarget(target)
  local wantedName, wantedFull, wantedKey, wantedShortKey

  if type(target) == "table" then
    wantedName = target.name or target.fullName
    wantedFull = target.fullName or target.name
    wantedKey = NormalizeUnitName(wantedFull)
    wantedShortKey = NormalizeUnitName(wantedName)
    local Safe = addon and addon.Safe
    if target.unit and Safe and Safe.UnitExists and Safe.UnitExists(target.unit) then
      local t = BuildUnitTarget(target.unit)
      if t and ((wantedKey and (t.key == wantedKey or t.shortKey == wantedKey))
          or (wantedShortKey and (t.shortKey == wantedShortKey or t.key == wantedShortKey))) then
        return t
      end
    end
  else
    wantedName = target
    wantedFull = target
    wantedKey = NormalizeUnitName(target)
    wantedShortKey = NormalizeUnitName(ShortName(target))
  end

  if not wantedKey and not wantedShortKey then return nil end

  local function checkUnit(unit)
    local Safe = addon and addon.Safe
    if not unit or (Safe and Safe.UnitExists and not Safe.UnitExists(unit)) then return nil end
    local t = BuildUnitTarget(unit)
    if not t then return nil end
    if (wantedKey and t.key == wantedKey)
        or (wantedKey and t.shortKey == wantedKey)
        or (wantedShortKey and t.shortKey == wantedShortKey)
        or (wantedShortKey and t.key == wantedShortKey) then
      return t
    end
    return nil
  end

  local num = SafeGroupCount()

  if SafeIsInRaid() then
    for i = 1, num do
      local found = checkUnit("raid" .. i)
      if found then return found end
    end
  elseif SafeIsInGroup() then
    for i = 1, math.min(num, 4) do
      local found = checkUnit("party" .. i)
      if found then return found end
    end
  end

  return checkUnit("player")
end

local function IsTargetInGroup(target)
  return FindGroupMemberTarget(target) ~= nil
end

local function PlayerCanManageGroup()
  if addon and addon.PlayerCanManageGroup then
    return addon:PlayerCanManageGroup()
  end
  local Safe = addon and addon.Safe
  if Safe and Safe.IsGroupLeader then
    if Safe.IsGroupLeader("player") then return true end
    if Safe.IsInRaid and Safe.IsInRaid() and Safe.IsGroupAssistant("player") then return true end
  end
  return false
end

local function PartyInfoCall(methodName, legacyFn, name, exactNameMatch)
  local api = type(C_PartyInfo) == "table" and C_PartyInfo[methodName] or nil
  if type(api) == "function" then
    return pcall(api, name, exactNameMatch)
  end
  if type(legacyFn) == "function" then
    return pcall(legacyFn, name, exactNameMatch)
  end
  return false, "missing_" .. tostring(methodName)
end

local function TryDemoteIfNeeded(target)
  if not (target and target.unit) then return end
  local Safe = addon and addon.Safe
  if not (Safe and Safe.IsGroupLeader and Safe.IsGroupLeader("player")) then return end
  if Safe.IsGroupAssistant(target.unit) then
    -- PartyInfo APIs use player names, not unit tokens.
    PartyInfoCall("DemoteAssistant", DemoteAssistant, target.fullName or target.name, true)
  end
end

local function TryUninviteTarget(target)
  local modernUninvite = type(C_PartyInfo) == "table" and type(C_PartyInfo.UninviteUnit) == "function"
  if not modernUninvite and type(UninviteUnit) ~= "function" then return false, "missing_uninvite_api", nil end
  local resolved = FindGroupMemberTarget(target)
  if not resolved then return false, "not_found", nil end

  local Safe = addon and addon.Safe
  if Safe and Safe.UnitIsUnit and resolved.unit and Safe.UnitIsUnit(resolved.unit, "player") then
    return false, "self", resolved
  end

  TryDemoteIfNeeded(resolved)

  local identifiers = {}
  -- Since 3.0.8 uninvite takes a player name. Prefer full realm-qualified name
  -- for cross-realm groups and keep short name only as a compatibility fallback.
  if resolved.fullName then identifiers[#identifiers + 1] = resolved.fullName end
  if resolved.name and resolved.name ~= resolved.fullName then identifiers[#identifiers + 1] = resolved.name end

  local attempted = false
  local anyOk = false
  local lastErr = nil
  local used = {}

  for _, id in ipairs(identifiers) do
    if id and not used[id] then
      used[id] = true
      attempted = true
      local ok, err
      if modernUninvite then
        ok, err = pcall(C_PartyInfo.UninviteUnit, id, nil, true)
      else
        ok, err = pcall(UninviteUnit, id)
      end
      if ok then
        anyOk = true
      else
        lastErr = err
      end
    end
  end

  if not attempted then return false, "no_identifier", resolved end
  if not anyOk then return false, tostring(lastErr or "uninvite_failed"), resolved end
  return true, nil, resolved
end

local function TargetDisplayName(target)
  if type(target) == "table" then
    return target.fullName or target.name or target.unit or "?"
  end
  return tostring(target or "?")
end

function addon:KickNamesSequential(targets, delayStep)
  if type(targets) ~= "table" or #targets == 0 then return end
  delayStep = tonumber(delayStep) or 0.15

  local Safe = addon and addon.Safe
  if Safe and Safe.UnitAffectingCombat and Safe.UnitAffectingCombat("player") then
    self._kickQueue = self._kickQueue or {}
    for _, n in ipairs(targets) do table.insert(self._kickQueue, n) end
    self._kickQueueNeedsClick = true
    print((addon.printPrefix or "GroupGuard LFG:"), addon:Tr("REMOVE_QUEUE_COMBAT"))
    return
  end

  if not PlayerCanManageGroup() then
    print((addon.printPrefix or "GroupGuard LFG:"), addon:Tr("NO_REMOVE_RIGHTS"))
    return
  end

  -- Important: C_PartyInfo.UninviteUnit / legacy UninviteUnit are sensitive to protected execution.
  -- Run all remove attempts synchronously from the user's button click.
  self:BeginActionSequence("group_remove", 1.4)

  local attemptedTargets = {}
  local skipped = 0
  local initialFailed = 0

  for _, target in ipairs(targets) do
    local ok, reason, resolved = TryUninviteTarget(target)

    if ok and resolved then
      attemptedTargets[#attemptedTargets + 1] = resolved
    elseif reason == "not_found" or reason == "self" then
      skipped = skipped + 1
    else
      initialFailed = initialFailed + 1
    end
  end

  local verifyDelay = 0.75
  local function verifyRemoval()
    local removed, failed = 0, initialFailed

    for _, resolved in ipairs(attemptedTargets) do
      if IsTargetInGroup(resolved) then
        failed = failed + 1
      else
        removed = removed + 1
      end
    end

    if addon and addon.ScanGroupOffenders then addon:ScanGroupOffenders() end
    if addon and addon.RequestGroupRefresh then addon:RequestGroupRefresh(0) end
    if addon and addon.ScheduleFrameMarkerUpdate then addon:ScheduleFrameMarkerUpdate(0.01) end
    if addon and addon.EndActionSequence then addon:EndActionSequence("group_remove") end

    local now = GetTime and GetTime() or 0
    local last = addon._lastRemoveSummaryAt or 0
    local sameAsLast = addon._lastRemoveSummaryRemoved == removed
      and addon._lastRemoveSummaryFailed == failed
      and addon._lastRemoveSummarySkipped == skipped

    -- Avoid chat flood if protected removal fails and the user presses the button repeatedly.
    if sameAsLast and (now - last) < 2.0 then return end
    addon._lastRemoveSummaryAt = now
    addon._lastRemoveSummaryRemoved = removed
    addon._lastRemoveSummaryFailed = failed
    addon._lastRemoveSummarySkipped = skipped

    if failed > 0 or skipped > 0 then
      print((addon.printPrefix or "GroupGuard LFG:"), addon:Tr("GROUP_REMOVE_SUMMARY", removed, failed, skipped))
    elseif removed > 0 then
      print((addon.printPrefix or "GroupGuard LFG:"), addon:Tr("GROUP_REMOVE_DONE"))
    end
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(verifyDelay, verifyRemoval)
  else
    verifyRemoval()
  end
end

function addon:ProcessKickQueue()
  -- Protected group removal must not be executed automatically from events such
  -- as PLAYER_REGEN_ENABLED. Keep the queue and ask the raid leader to click a
  -- real button or run /ggremove after combat.
  if not self._kickQueue or #self._kickQueue == 0 then return end
  local Safe = addon and addon.Safe
  if Safe and Safe.UnitAffectingCombat and Safe.UnitAffectingCombat("player") then return end
  self._kickQueueNeedsClick = true
  local now = GetTime and GetTime() or 0
  if (self._lastKickQueueNoticeAt or 0) + 4 <= now then
    self._lastKickQueueNoticeAt = now
    print((addon.printPrefix or "GroupGuard LFG:"), addon:Tr("REMOVE_QUEUE_NEEDS_CLICK"))
  end
end

function addon:RunQueuedKicksFromUserAction()
  if not self._kickQueue or #self._kickQueue == 0 then return false end
  local Safe = addon and addon.Safe
  if Safe and Safe.UnitAffectingCombat and Safe.UnitAffectingCombat("player") then
    print((addon.printPrefix or "GroupGuard LFG:"), addon:Tr("REMOVE_QUEUE_COMBAT"))
    return false
  end
  if not PlayerCanManageGroup() then
    print((addon.printPrefix or "GroupGuard LFG:"), addon:Tr("NO_QUEUE_RIGHTS"))
    self._kickQueue = nil
    self._kickQueueNeedsClick = false
    return false
  end
  local q = self._kickQueue
  self._kickQueue = nil
  self._kickQueueNeedsClick = false
  self:KickNamesSequential(q, 0.15)
  return true
end

local function CountGroupOffenders()
  local count = 0
  for _ in pairs(addon._groupOffenders or {}) do count = count + 1 end
  return count
end

function addon:CreateLeaveButton()
  if self.leaveButton then
    return
  end

  local parent = self.Banner or UIParent
  local btn = CreateFrame("Button", "GroupGuardLFGLeaveBtn", parent, "UIPanelButtonTemplate")
  btn:SetSize(138, 22)
  btn:SetFrameStrata("DIALOG")
  btn:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 260) + 12)
  btn:SetText(self.GetLeaveActionLabel and self:GetLeaveActionLabel() or self:Tr("LEAVE_GROUP_BUTTON"))
  btn:Hide()
  btn:SetScript("OnClick", function()
    if addon.UpdateBanner then
      addon:UpdateBanner(addon:GetLeaveActionLabel(), "", false, "ACTION", addon:Tr("LEAVING_GROUP"))
    end
    addon:ConfirmAndLeave()
  end)

  self.leaveButton = btn
  if self.LayoutBannerActionButtons then self:LayoutBannerActionButtons() end
end

function addon:UpdateBannerGroupButtons()
  if not self.Banner then return end
  if not self.kickButton then self:CreateKickButton() end
  if not self.leaveButton then self:CreateLeaveButton() end

  local inGroup = SafeIsInGroup() or SafeIsInRaid()
  local offenderCount = CountGroupOffenders()
  local showLeave = inGroup and (offenderCount > 0 or self._alertActive or self._needsRecheck)
  local showKick = offenderCount > 0 and self.db and self.db.kick_button_enabled and PlayerCanManageGroup()

  if self.leaveButton then
    self.leaveButton:SetText(self:GetLeaveActionLabel())
    if showLeave then self.leaveButton:Show() else self.leaveButton:Hide() end
  end

  if self.kickButton then
    self.kickButton:SetText(offenderCount > 0 and addon:Tr("KICK_BUTTON_FMT", offenderCount) or addon:Tr("KICK_BUTTON"))
    if showKick then self.kickButton:Show() else self.kickButton:Hide() end
  end

  if self.LayoutBannerActionButtons then self:LayoutBannerActionButtons() end
end

-- Kick button + group scan
--------------------------------------------------

function addon:CreateKickButton()
  if self.kickButton then
    if self.LayoutBannerActionButton then self:LayoutBannerActionButton() end
    return
  end
  local parent = self.Banner or UIParent
  local btn = CreateFrame("Button", "GroupGuardLFGKickBtn", parent, "UIPanelButtonTemplate")
  btn:SetSize(150, 22)
  btn:SetFrameStrata("DIALOG")
  btn:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 260) + 12)
  btn:SetText(addon:Tr("KICK_BUTTON"))
  btn:Hide()
  btn:SetScript("OnClick", function()
    if not addon._groupOffenders or next(addon._groupOffenders) == nil then return end

    local toKick = {}
    for name in pairs(addon._groupOffenders) do
      local target = addon._groupOffenderTargets and addon._groupOffenderTargets[name]
      toKick[#toKick + 1] = target or name
    end
    if #toKick == 0 then return end

    local Safe = addon and addon.Safe
    if Safe and Safe.UnitAffectingCombat and Safe.UnitAffectingCombat("player") then
      addon._kickQueue = addon._kickQueue or {}
      for _, n in ipairs(toKick) do table.insert(addon._kickQueue, n) end
      print((addon.printPrefix or "GroupGuard LFG:"), addon:Tr("REMOVE_QUEUE_COMBAT"))
      return
    end

    if not PlayerCanManageGroup() then
      print((addon.printPrefix or "GroupGuard LFG:"), addon:Tr("NO_REMOVE_PERMISSION"))
      return
    end

    if addon.UpdateBanner then
      addon:UpdateBanner(addon:Tr("REMOVING_FROM_GROUP"), tostring(#toKick), false, "ACTION", "")
    end
    if addon.BeginActionSequence then addon:BeginActionSequence("group_remove", 2.0) end

    addon:KickNamesSequential(toKick, 0.15)
  end)
  self.kickButton = btn
  if self.LayoutBannerActionButtons then self:LayoutBannerActionButtons() end
end

function addon:ScanGroupOffenders()
  if not self.db then
    self._groupOffenders = {}
    self._groupOffenderKeys = {}
    self._groupSocialKeys = {}
    self._groupOffenderTargets = {}
    if self.kickButton then self.kickButton:Hide() end
    if self.leaveButton then self.leaveButton:Hide() end
    if self.LayoutBannerActionButtons then self:LayoutBannerActionButtons() end
    if self.UpdateFrameMarkers then self:UpdateFrameMarkers() end
    return
  end
  if addon:IsInRestrictedInstance() then
    self._groupOffenders = {}
    self._groupOffenderKeys = {}
    self._groupSocialKeys = {}
    self._groupOffenderTargets = {}
    if self.kickButton then self.kickButton:Hide() end
    if self.leaveButton then self.leaveButton:Hide() end
    if self.LayoutBannerActionButtons then self:LayoutBannerActionButtons() end
    if self.UpdateFrameMarkers then self:UpdateFrameMarkers() end
    return
  end
  if not (SafeIsInGroup() or SafeIsInRaid()) then
    self._groupOffenders = {}
    self._groupOffenderKeys = {}
    self._groupSocialKeys = {}
    self._groupOffenderTargets = {}
    if self.kickButton then self.kickButton:Hide() end
    if self.leaveButton then self.leaveButton:Hide() end
    if self.LayoutBannerActionButtons then self:LayoutBannerActionButtons() end
    if self.UpdateFrameMarkers then self:UpdateFrameMarkers() end
    return
  end

  local unitPrefix = SafeIsInRaid() and "raid" or "party"
  local num = SafeGroupCount()
  local offenders = {}
  local offenderKeys = {}
  local offenderTargets = {}
  local socialKeys = {}

  for i = 1, num do
    local unit = unitPrefix .. i
    local Safe = self.Safe
    local fullName, name, server
    if Safe and Safe.UnitFullName then fullName, name, server = Safe.UnitFullName(unit) end
    if name then
      local guildName = nil
      if self.Safe and self.Safe.GuildName then
        guildName = self.Safe.GuildName(unit)
      end

      local key = NameKey(name)
      local ignoreSocial, socialStatus = false, nil
      if self.ShouldIgnoreFilteredUnit then
        local okSocial, ignored, status = pcall(function() return self:ShouldIgnoreFilteredUnit(unit, name, guildName) end)
        if okSocial then
          ignoreSocial = ignored and true or false
          socialStatus = status
        end
      elseif self.GetUnitSocialStatus then
        local okStatus, status = pcall(function() return self:GetUnitSocialStatus(unit, name, guildName) end)
        if okStatus then socialStatus = status end
      end

      if key and socialStatus then
        socialKeys[key] = socialStatus
      end

      local realm = nil
      if not (self.IsForeverClient and self:IsForeverClient()) then
        realm = server or (self.SafeText and self:SafeText(self.realm_name) or self.realm_name)
      end
      local exempt = self:IsExemptUnit(name, realm, guildName)
      local nameFlag = self.db.scan_group_names and self:IsFlaggedText(name)
      local guildFlag = self.db.scan_group_guilds and guildName and self:IsFlaggedText(guildName)

      if not ignoreSocial and not exempt and (nameFlag or guildFlag) then
        local target = BuildUnitTarget(unit, name, server)
        local displayName = (target and target.fullName) or fullName or name
        offenders[displayName] = true
        offenderTargets[displayName] = target or { name = name, fullName = displayName, unit = unit }
        if key then offenderKeys[key] = true end
        if target and target.key then offenderKeys[target.key] = true end
        if target and target.shortKey then offenderKeys[target.shortKey] = true end
      end
    end
  end

  self._groupOffenders = offenders
  self._groupOffenderKeys = offenderKeys
  self._groupOffenderTargets = offenderTargets
  self._groupSocialKeys = socialKeys
  if self.ScheduleFrameMarkerUpdate then self:ScheduleFrameMarkerUpdate(0.02) end

  -- Sync alertedNames: remove entries for players no longer among offenders,
  -- so they can be re-alerted if they leave and rejoin the group.
  self._alertedNames = self._alertedNames or {}
  for n in pairs(self._alertedNames) do
    if not offenders[n] then
      self._alertedNames[n] = nil
    end
  end

  if not self.kickButton then self:CreateKickButton() end

  local count = 0
  for _ in pairs(offenders) do count = count + 1 end

  if count == 0 then
    self._alertActive = false
    self._placeholderShown = false
    self._needsRecheck = false
  end

  self:UpdateBannerGroupButtons()
end

function addon:ScheduleGroupRescan(delay)
  delay = tonumber(delay) or 0.15
  if self._groupRescanTimer then return end
  self._groupRescanTimer = true
  local function run()
    addon._groupRescanTimer = nil
    if addon and addon.ScanGroupOffenders then addon:ScanGroupOffenders() end
  end
  if C_Timer and C_Timer.After then C_Timer.After(delay, run) else run() end
end



function addon:ScheduleNeedsRecheck(maxAttempts, interval)
  if not self._needsRecheck then return end
  if self._needsRecheckTimer then return end

  maxAttempts = tonumber(maxAttempts) or 10
  interval = tonumber(interval) or 0.45

  if not (C_Timer and C_Timer.NewTicker) then
    self._needsRecheck = false
    self._needsRecheckTimer = nil
    return
  end

  local attempts = 0
  self._needsRecheckTimer = C_Timer.NewTicker(interval, function(t)
    attempts = attempts + 1

    -- stop conditions
    if not addon._needsRecheck or addon:IsInRestrictedInstance() or not (SafeIsInGroup() or SafeIsInRaid()) then
      t:Cancel()
      addon._needsRecheckTimer = nil
      addon._needsRecheck = false
      return
    end

    local detected, name, reasonKey, guild = addon:CheckGroup()
    if detected then
      addon._needsRecheck = false
      t:Cancel()
      addon._needsRecheckTimer = nil

      -- show/update alert consistently, unless startup/action suppression is active
      if not (addon.ShouldSuppressAlerts and addon:ShouldSuppressAlerts("needs_recheck")) then
        if addon._alertActive then
          addon:UpdateBanner(name or addon:Tr("DETECTED_MATCH"), guild or "", false, "DETECTED", addon:Tr("DEFAULT_DETAIL"))
        else
          addon:NotifyGroupDetected(name, guild)
        end

        if addon.db and addon.db.auto_leave then
          addon:ConfirmAndLeave()
        end
      end
      return
    end

    -- if no longer seeing "secret"/nil, CheckGroup() will stop setting _needsRecheck
    if not addon._needsRecheck then
      t:Cancel()
      addon._needsRecheckTimer = nil
      return
    end

    if attempts >= maxAttempts then
      t:Cancel()
      addon._needsRecheckTimer = nil
      -- leave _needsRecheck as false to avoid infinite loop
      addon._needsRecheck = false
    end
  end)
end


--------------------------------------------------
