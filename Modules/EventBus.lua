-- GroupGuard LFG — Runtime / Event Bus
local addonName, addon = ...

local eventFrame = CreateFrame("Frame")
local wasInGroup = false
local C_Timer = C_Timer

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("GROUP_JOINED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
eventFrame:RegisterEvent("LFG_LIST_APPLICANT_UPDATED")
eventFrame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
eventFrame:RegisterEvent("UNIT_CONNECTION")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
pcall(eventFrame.RegisterEvent, eventFrame, "GUILD_RANKS_UPDATE")
pcall(eventFrame.RegisterEvent, eventFrame, "FRIENDLIST_UPDATE")
pcall(eventFrame.RegisterEvent, eventFrame, "BN_FRIEND_ACCOUNT_ONLINE")
pcall(eventFrame.RegisterEvent, eventFrame, "BN_FRIEND_ACCOUNT_OFFLINE")
pcall(eventFrame.RegisterEvent, eventFrame, "BN_FRIEND_INFO_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "BN_CONNECTED")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_GUILD_UPDATE")
pcall(eventFrame.RegisterEvent, eventFrame, "RAID_ROSTER_UPDATE")
pcall(eventFrame.RegisterEvent, eventFrame, "PARTY_LEADER_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_FLAGS_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS")
pcall(eventFrame.RegisterEvent, eventFrame, "LFG_LIST_ENTRY_EXPIRED_TIMEOUT")
pcall(eventFrame.RegisterEvent, eventFrame, "LFG_LIST_SEARCH_RESULTS_RECEIVED")
pcall(eventFrame.RegisterEvent, eventFrame, "LFG_LIST_SEARCH_RESULT_UPDATED")


-- Group state evaluation / event scheduler
--------------------------------------------------

local function CleanupRuntimeState()
  if addon.ClearFrameMarkers then addon:ClearFrameMarkers() end
  if addon and addon.ClearAlert then addon:ClearAlert() end
  if addon.kickButton then addon.kickButton:Hide() end
  if addon.lfgButton then addon.lfgButton:Hide() end
  addon._groupOffenders = {}
  addon._groupOffenderKeys = {}
  addon._groupOffenderTargets = {}
  addon._groupSocialKeys = {}
  addon._lfgFlagged = {}
  addon._lfgAutoDeclined = {}
  addon._lfgManualDeclined = {}
  addon._lfgDeclineInFlight = {}
end

local function EvaluateGroupState()
  if addon.IsDisabledNow and addon:IsDisabledNow() then
    CleanupRuntimeState()
    return
  end

  if not (IsInGroup() or IsInRaid()) then
    CleanupRuntimeState()
    if addon.LFG_UpdateButton then addon:LFG_UpdateButton() end
    return
  end

  local detected, name, reasonKey, guild = addon:CheckGroup()
  if addon._needsRecheck then
    addon:ScheduleNeedsRecheck(10, 0.45)
  end

  if detected then
    if not addon._alertActive then
      addon:NotifyGroupDetected(name, guild)
      if addon.db and addon.db.auto_leave and not (addon.ShouldSuppressAlerts and addon:ShouldSuppressAlerts("auto_leave")) then
        addon:ConfirmAndLeave()
      end
    end
  elseif addon._alertActive and not addon._needsRecheck then
    addon._alertActive = false
    addon._placeholderShown = false
  end
end

function addon:RequestGroupRefresh(delay)
  if not self.db then return end
  delay = tonumber(delay) or tonumber(self.db.scan_debounce) or 0.03
  if self._groupRefreshPending and delay > 0.01 then return end

  local function run()
    addon._groupRefreshPending = false
    if not addon.db then return end
    EvaluateGroupState()
    if addon.ScanGroupOffenders then addon:ScanGroupOffenders() end
    if addon.ScheduleFrameMarkerUpdate then addon:ScheduleFrameMarkerUpdate(0.01) end
  end

  if delay <= 0.01 then
    run()
    return
  end

  self._groupRefreshPending = true
  if self.RunDebounced then
    return self:RunDebounced("group_refresh", delay, run)
  end
  C_Timer.After(delay, run)
end

function addon:RequestLFGRefresh(delay, scanApplicants, refreshResults)
  if not self.db then return end
  if self.IsDisabledNow and self:IsDisabledNow() then
    if self.lfgButton then self.lfgButton:Hide() end
    if self.LFG_ClearVisibleHighlights then self:LFG_ClearVisibleHighlights() end
    return
  end

  delay = tonumber(delay) or tonumber(self.db.lfg_debounce) or 0.02
  if self._lfgRefreshPending and delay > 0.01 then
    self._lfgRefreshApplicants = self._lfgRefreshApplicants or scanApplicants
    self._lfgRefreshResults = self._lfgRefreshResults or refreshResults
    return
  end

  self._lfgRefreshApplicants = scanApplicants
  self._lfgRefreshResults = refreshResults

  local function run()
    addon._lfgRefreshPending = false
    if addon.IsDisabledNow and addon:IsDisabledNow() then
      if addon.LFG_ClearVisibleHighlights then addon:LFG_ClearVisibleHighlights() end
      if addon.lfgButton then addon.lfgButton:Hide() end
      return
    end

    if addon.LFG_CreateButton then addon:LFG_CreateButton() end
    if addon.LFG_HookViewer then addon:LFG_HookViewer() end
    if addon.LFG_HookSearchPanel then addon:LFG_HookSearchPanel() end
    if addon.InitPGFIntegration then addon:InitPGFIntegration() end

    if addon._lfgRefreshApplicants and addon.LFG_ScanApplicants then addon:LFG_ScanApplicants() end
    if addon.LFG_UpdateButton then addon:LFG_UpdateButton() end
    if addon.LFG_DebouncedHighlight then addon:LFG_DebouncedHighlight(0) end
    if addon._lfgRefreshResults and addon.LFG_DebouncedHighlightResults then addon:LFG_DebouncedHighlightResults(0) end

    addon._lfgRefreshApplicants = false
    addon._lfgRefreshResults = false
  end

  if delay <= 0.01 then
    run()
    return
  end

  self._lfgRefreshPending = true
  if self.RunDebounced then
    return self:RunDebounced("lfg_refresh", delay, run)
  end
  C_Timer.After(delay, run)
end


--------------------------------------------------

function addon:SyncSettingsState(reason)
  if not self.db then return end

  if self.RebuildCaches then self:RebuildCaches() end
  if self.RebuildFriendCache then self:RebuildFriendCache(true) end
  if self.RebuildGuildCache then self:RebuildGuildCache(true) end

  self._lfgFlagCache = {}
  self._lfgFlagReasons = {}
  self._lfgSocialCache = {}
  self._lfgSocialReasons = {}
  self._lfgResultFlagCache = {}
  self._lfgResultFlagReasons = {}
  self._lfgResultSocialCache = {}
  self._lfgResultSocialReasons = {}

  if self.RequestGroupRefresh then self:RequestGroupRefresh(0) end
  if self.RequestLFGRefresh then self:RequestLFGRefresh(0, true, true) end
  if self.LFG_UpdateButton then self:LFG_UpdateButton() end
  if self.LFG_DebouncedHighlight then self:LFG_DebouncedHighlight(0) end
  if self.LFG_DebouncedHighlightResults then self:LFG_DebouncedHighlightResults(0) end
  if self.UpdateFrameMarkers then self:UpdateFrameMarkers() end
  if self.ScheduleRaidAssist then self:ScheduleRaidAssist(0, reason or "settings") end
end

local function OnEvent(self, event, arg1, ...)
  if event == "ADDON_LOADED" then
    if arg1 == addonName then
      addon:EnsureDB()
      if addon.EnterStartupQuiet then addon:EnterStartupQuiet(addon.db and addon.db.startup_silent_seconds or 3.0, "addon_loaded") end
      if not addon.configFrame then addon:InitSettingsPages() end
      if Settings and addon.settingsRoot then addon.settingsCategory = addon.settingsRoot end
      addon:CreateKickButton()
      wasInGroup = IsInGroup() or IsInRaid()
      addon:RequestGroupRefresh(0)
      if addon.ScheduleFrameMarkerUpdate then addon:ScheduleFrameMarkerUpdate(0.01) end
      addon:RequestLFGRefresh(0, true, true)
      if addon.ScheduleRaidAssist then addon:ScheduleRaidAssist(0.05, "addon_loaded") end
    elseif arg1 == "Blizzard_LookingForGroupUI" then
      addon:RequestLFGRefresh(0, true, true)
    elseif arg1 == "PremadeGroupsFilter" then
      if addon.InitPGFIntegration then addon:InitPGFIntegration() end
      addon:RequestLFGRefresh(0, false, true)
    end
    return
  end

  if not addon.db then addon:EnsureDB() end

  if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    if addon.EnterInstanceLockout then addon:EnterInstanceLockout(1.5) end
    if addon.EnterStartupQuiet then addon:EnterStartupQuiet(addon.db and addon.db.startup_silent_seconds or 3.0, event) end
    addon:RebuildCaches()
    wasInGroup = IsInGroup() or IsInRaid()
    -- Immediate UI refresh, plus a delayed pass after Blizzard finishes rebuilding frames.
    addon:RequestGroupRefresh(0)
    if addon.ScheduleFrameMarkerUpdate then addon:ScheduleFrameMarkerUpdate(0.01) end
    addon:RequestLFGRefresh(0, true, true)
    if addon.ScheduleRaidAssist then addon:ScheduleRaidAssist(0.05, event) end
    C_Timer.After(1.75, function()
      addon:RequestGroupRefresh(0)
      if addon.ScheduleFrameMarkerUpdate then addon:ScheduleFrameMarkerUpdate(0.01) end
      addon:RequestLFGRefresh(0, false, true)
      if addon.ScheduleRaidAssist then addon:ScheduleRaidAssist(0, "delayed_world") end
    end)
    return
  end

  if addon.IsDisabledNow and addon:IsDisabledNow() then
    CleanupRuntimeState()
    return
  end

  if event == "GROUP_ROSTER_UPDATE" or event == "GROUP_JOINED" or event == "RAID_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" or event == "PLAYER_FLAGS_CHANGED" then
    local inGroup = IsInGroup() or IsInRaid()
    if wasInGroup and not inGroup then
      CleanupRuntimeState()
      addon._alertedNames = {}
      addon._needsRecheck = false
    end
    wasInGroup = inGroup
    if addon.LFG_ClearApplicantCaches then addon:LFG_ClearApplicantCaches() else addon._lfgFlagCache = {} end
    if addon.LFG_ClearSearchCaches then addon:LFG_ClearSearchCaches() end
    addon:RequestGroupRefresh(0)
    addon:RequestLFGRefresh(0, true, true)
    if addon.ScheduleRaidAssist then addon:ScheduleRaidAssist(0.03, event) end

  elseif event == "PLAYER_REGEN_ENABLED" then
    addon:ProcessKickQueue()
    if addon._raidAssistQueued and addon.ScheduleRaidAssist then
      addon._raidAssistQueued = false
      addon:ScheduleRaidAssist(0, "combat_end")
    end
    addon:RequestGroupRefresh(0)
    addon:RequestLFGRefresh(0, true, true)

  elseif event == "LFG_LIST_APPLICANT_LIST_UPDATED"
      or event == "LFG_LIST_APPLICANT_UPDATED"
      or event == "LFG_LIST_ACTIVE_ENTRY_UPDATE"
      or event == "LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS"
      or event == "LFG_LIST_ENTRY_EXPIRED_TIMEOUT" then
    if addon.LFG_ClearApplicantCaches then addon:LFG_ClearApplicantCaches() else addon._lfgFlagCache = {}; addon._lfgFlagReasons = {} end
    addon:RequestLFGRefresh(0, true, true)

  elseif event == "LFG_LIST_SEARCH_RESULTS_RECEIVED"
      or event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
    if addon.LFG_ClearSearchCaches then addon:LFG_ClearSearchCaches() else addon._lfgResultFlagCache = {}; addon._lfgResultFlagReasons = {} end
    addon:RequestLFGRefresh(0, false, true)

  elseif event == "UNIT_NAME_UPDATE"
      or event == "UNIT_CONNECTION"
      or event == "GUILD_ROSTER_UPDATE"
      or event == "GUILD_RANKS_UPDATE"
      or event == "PLAYER_GUILD_UPDATE"
      or event == "FRIENDLIST_UPDATE"
      or event == "BN_FRIEND_ACCOUNT_ONLINE"
      or event == "BN_FRIEND_ACCOUNT_OFFLINE"
      or event == "BN_FRIEND_INFO_CHANGED"
      or event == "BN_CONNECTED" then
    if addon.RebuildFriendCache then addon:RebuildFriendCache(true) end
    if addon.RebuildGuildCache then addon:RebuildGuildCache(true) end
    if addon.LFG_ClearApplicantCaches then addon:LFG_ClearApplicantCaches() else addon._lfgFlagCache = {} end
    if addon.LFG_ClearSearchCaches then addon:LFG_ClearSearchCaches() else addon._lfgResultFlagCache = {} end
    addon:RequestGroupRefresh(0)
    addon:RequestLFGRefresh(0, true, true)
    if addon.ScheduleRaidAssist then addon:ScheduleRaidAssist(0.03, event) end
  end
end

eventFrame:SetScript("OnEvent", OnEvent)
