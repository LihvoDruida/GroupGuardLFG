-- GroupGuard LFG — Runtime / Event Bus
local addonName, addon = ...

local eventFrame = CreateFrame("Frame")
local wasInGroup = false
local C_Timer = C_Timer

local function SafeRegisterEvent(event)
  if eventFrame and eventFrame.RegisterEvent then
    pcall(eventFrame.RegisterEvent, eventFrame, event)
  end
end

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

local function SafeInGroupOrRaid()
  return SafeIsInGroup() or SafeIsInRaid()
end

SafeRegisterEvent("ADDON_LOADED")
SafeRegisterEvent("GROUP_ROSTER_UPDATE")
SafeRegisterEvent("GROUP_JOINED")
SafeRegisterEvent("PLAYER_ENTERING_WORLD")
SafeRegisterEvent("PLAYER_REGEN_ENABLED")
SafeRegisterEvent("PLAYER_REGEN_DISABLED")
SafeRegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
SafeRegisterEvent("LFG_LIST_APPLICANT_UPDATED")
SafeRegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
SafeRegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
SafeRegisterEvent("UNIT_NAME_UPDATE")
SafeRegisterEvent("UNIT_CONNECTION")
SafeRegisterEvent("ZONE_CHANGED_NEW_AREA")
SafeRegisterEvent("GUILD_ROSTER_UPDATE")
SafeRegisterEvent("GUILD_RANKS_UPDATE")
SafeRegisterEvent("FRIENDLIST_UPDATE")
SafeRegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
SafeRegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
SafeRegisterEvent("BN_FRIEND_INFO_CHANGED")
SafeRegisterEvent("BN_CONNECTED")
SafeRegisterEvent("PLAYER_GUILD_UPDATE")
SafeRegisterEvent("RAID_ROSTER_UPDATE")
SafeRegisterEvent("PARTY_LEADER_CHANGED")
SafeRegisterEvent("PLAYER_FLAGS_CHANGED")
SafeRegisterEvent("LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS")
SafeRegisterEvent("LFG_LIST_ENTRY_EXPIRED_TIMEOUT")
SafeRegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
SafeRegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
-- 12.1 (Curse of Ula'tek): censorship state of the player's own listing.
-- Missing on older clients, which is why registration is wrapped in pcall.
SafeRegisterEvent("LFG_LIST_CENSORED_ACTIVE_ENTRY_UPDATE")
SafeRegisterEvent("LFG_LIST_REVEALED_CENSORED_ACTIVE_ENTRY")


-- Group state evaluation / event scheduler
--------------------------------------------------

local function CleanupRuntimeState()
  if addon.ClearFrameMarkers then addon:ClearFrameMarkers() end
  if addon and addon.ClearAlert then addon:ClearAlert() end
  if addon.kickButton then addon.kickButton:Hide() end
  if addon.leaveButton then addon.leaveButton:Hide() end
  if addon.LayoutBannerActionButtons then addon:LayoutBannerActionButtons() end
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

  if not SafeInGroupOrRaid() then
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
  delay = tonumber(delay) or tonumber(self.db.scan_debounce) or 0.05
  if delay > 0 and delay < 0.04 then delay = 0.04 end
  if self._groupRefreshPending and delay > 0.01 then return end

  local function run()
    addon._groupRefreshPending = false
    if not addon.db then return end
    EvaluateGroupState()
    if addon.ScanGroupOffenders then addon:ScanGroupOffenders() end
    if addon.ScheduleFrameMarkerUpdate then addon:ScheduleFrameMarkerUpdate(0.05) end
  end

  if delay <= 0.01 then
    -- An immediate refresh supersedes any older delayed refresh. Without
    -- cancelling it the same roster is scanned twice: once now and once when
    -- the stale debounce fires.
    if self.CancelDebounce then self:CancelDebounce("group_refresh") end
    self._groupRefreshPending = false
    run()
    return
  end

  self._groupRefreshPending = true
  if self.RunDebounced then
    return self:RunDebounced("group_refresh", delay, run)
  end
  if C_Timer and C_Timer.After then C_Timer.After(delay, run) else run() end
end

function addon:RequestLFGRefresh(delay, scanApplicants, refreshResults)
  if not self.db then return end
  if self.IsDisabledNow and self:IsDisabledNow() then
    if self.lfgButton then self.lfgButton:Hide() end
    if self.LFG_ClearVisibleHighlights then self:LFG_ClearVisibleHighlights() end
    return
  end

  delay = tonumber(delay) or tonumber(self.db.lfg_debounce) or 0.08
  if delay < 0.05 then delay = 0.05 end
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

    local applicantUI = not addon.SupportsLFGApplicantUI or addon:SupportsLFGApplicantUI()
    if applicantUI and addon.LFG_CreateButton then addon:LFG_CreateButton() end
    if applicantUI and addon.LFG_HookViewer then addon:LFG_HookViewer() end
    if addon.LFG_HookSearchPanel then addon:LFG_HookSearchPanel() end
    if addon.LFGFilters_HookFrames then addon:LFGFilters_HookFrames() end
    if addon.InitPGFIntegration then addon:InitPGFIntegration() end
    if addon.LFG_InitEnhancements then addon:LFG_InitEnhancements() end
    if addon.LFG_InitRealmInsights then addon:LFG_InitRealmInsights() end
    if applicantUI and addon.LFG_InitApplicantEnhancements then addon:LFG_InitApplicantEnhancements() end

    if applicantUI and addon._lfgRefreshApplicants and addon.LFG_ScanApplicants then addon:LFG_ScanApplicants() end
    if applicantUI and addon.LFG_UpdateButton then addon:LFG_UpdateButton() end
    if applicantUI and addon.LFG_DebouncedHighlight then addon:LFG_DebouncedHighlight(nil) end
    if addon._lfgRefreshResults and addon.LFGFilters_HasActiveFilters and addon:LFGFilters_HasActiveFilters() and addon.LFGFilters_RefreshCurrentResults then
      addon:LFGFilters_RefreshCurrentResults()
    end
    if addon._lfgRefreshResults and addon.LFG_DebouncedHighlightResults then addon:LFG_DebouncedHighlightResults(nil) end
    if applicantUI and addon.LFG_RefreshApplicantChips then addon:LFG_RefreshApplicantChips() end

    addon._lfgRefreshApplicants = false
    addon._lfgRefreshResults = false
  end

  self._lfgRefreshPending = true
  if self.RunDebounced then
    return self:RunDebounced("lfg_refresh", delay, run)
  end
  if C_Timer and C_Timer.After then C_Timer.After(delay, run) else run() end
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
  self._lfgResultCensored = {}

  if self.RequestGroupRefresh then self:RequestGroupRefresh(0) end
  if self.RequestLFGRefresh then self:RequestLFGRefresh(nil, true, true) end
  if self.LFG_UpdateButton then self:LFG_UpdateButton() end
  if self.LFG_DebouncedHighlight then self:LFG_DebouncedHighlight(nil) end
  if self.LFG_DebouncedHighlightResults then self:LFG_DebouncedHighlightResults(nil) end
  if self.UpdateFrameMarkers then self:UpdateFrameMarkers() end
  if self.ScheduleRaidAssist then self:ScheduleRaidAssist(0, reason or "settings") end
end

-- Startup steps used to run as one unbroken chain: a Lua error in any of them
-- (most often the settings pages, which touch the most Blizzard UI) silently
-- killed every step after it, so buttons, LFG hooks and the applicant column
-- simply never appeared. Each step is isolated now.
local function SafeInit(label, method, ...)
  if type(addon[method]) ~= "function" then return true end
  local ok, err = pcall(addon[method], addon, ...)
  if not ok then
    addon._initFailures = addon._initFailures or {}
    addon._initFailures[label] = tostring(err)
    if addon.debug then
      print(addon.printPrefix, "init failed:", label, tostring(err))
    end
  end
  return ok
end

addon.SafeInitStep = SafeInit

local function OnEvent(self, event, arg1, ...)
  if event == "ADDON_LOADED" then
    if arg1 == addonName then
      addon:EnsureDB()
      SafeInit("client_capabilities", "RefreshClientCapabilities")
      SafeInit("lfg_filters", "LFGFilters_Init")
      if addon.EnterStartupQuiet then addon:EnterStartupQuiet(addon.db and addon.db.startup_silent_seconds or 3.0, "addon_loaded") end
      if not addon.configFrame then SafeInit("settings", "InitSettingsPages") end
      if Settings and addon.settingsRoot then addon.settingsCategory = addon.settingsRoot end
      SafeInit("kick_button", "CreateKickButton")
      wasInGroup = SafeInGroupOrRaid()
      SafeInit("group_refresh", "RequestGroupRefresh", 0)
      SafeInit("frame_markers", "ScheduleFrameMarkerUpdate", 0.05)
      SafeInit("lfg_refresh", "RequestLFGRefresh", nil, true, true)
      SafeInit("lfg_enhancements", "LFG_InitEnhancements")
      SafeInit("realm_insights", "LFG_InitRealmInsights")
      SafeInit("applicant_enhancements", "LFG_InitApplicantEnhancements")
      SafeInit("raid_assist", "ScheduleRaidAssist", 0.05, "addon_loaded")
    elseif arg1 == "Blizzard_GroupFinder" or arg1 == "Blizzard_LookingForGroupUI" or arg1 == "Blizzard_GroupFinder_VanillaStyle" then
      if arg1 == "Blizzard_GroupFinder_VanillaStyle" and addon.ForeverLoadGuard_RebindWhoListFrame then
        pcall(addon.ForeverLoadGuard_RebindWhoListFrame, addon)
      end
      -- Mainline and Forever group finders are load-on-demand and use different
      -- frame implementations. Re-probe capabilities after Blizzard creates them.
      SafeInit("client_capabilities", "RefreshClientCapabilities")
      SafeInit("lfg_filters", "LFGFilters_Init")
      SafeInit("lfg_enhancements", "LFG_InitEnhancements")
      SafeInit("realm_insights", "LFG_InitRealmInsights")
      SafeInit("applicant_enhancements", "LFG_InitApplicantEnhancements")
      SafeInit("lfg_refresh", "RequestLFGRefresh", nil, true, true)
    elseif arg1 == "PremadeGroupsFilter" then
      SafeInit("pgf", "InitPGFIntegration")
      SafeInit("lfg_refresh", "RequestLFGRefresh", nil, false, true)
    end
    return
  end

  if not addon.db then addon:EnsureDB() end

  if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    if addon.EnterInstanceLockout then addon:EnterInstanceLockout(1.5) end
    if addon.EnterStartupQuiet then addon:EnterStartupQuiet(addon.db and addon.db.startup_silent_seconds or 3.0, event) end
    addon:RebuildCaches()
    wasInGroup = SafeInGroupOrRaid()
    -- Immediate UI refresh, plus a delayed pass after Blizzard finishes rebuilding frames.
    addon:RequestGroupRefresh(0)
    if addon.ScheduleFrameMarkerUpdate then addon:ScheduleFrameMarkerUpdate(0.05) end
    addon:RequestLFGRefresh(nil, true, true)
    if addon.ScheduleRaidAssist then addon:ScheduleRaidAssist(0.05, event) end
    local function delayedWorldRefresh()
      addon:RequestGroupRefresh(0)
      if addon.ScheduleFrameMarkerUpdate then addon:ScheduleFrameMarkerUpdate(0.05) end
      addon:RequestLFGRefresh(nil, false, true)
      if addon.ScheduleRaidAssist then addon:ScheduleRaidAssist(0, "delayed_world") end
    end
    if C_Timer and C_Timer.After then C_Timer.After(1.75, delayedWorldRefresh) else delayedWorldRefresh() end
    return
  end

  if addon.IsDisabledNow and addon:IsDisabledNow() then
    CleanupRuntimeState()
    return
  end

  if event == "GROUP_ROSTER_UPDATE" or event == "GROUP_JOINED" or event == "RAID_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" or event == "PLAYER_FLAGS_CHANGED" then
    local inGroup = SafeInGroupOrRaid()
    if wasInGroup and not inGroup then
      CleanupRuntimeState()
      addon._alertedNames = {}
      addon._needsRecheck = false
    end
    wasInGroup = inGroup
    if addon.LFG_ClearApplicantCaches then addon:LFG_ClearApplicantCaches() else addon._lfgFlagCache = {} end
    if addon.LFG_ClearSearchCaches then addon:LFG_ClearSearchCaches() end
    addon:RequestGroupRefresh(0)
    addon:RequestLFGRefresh(nil, true, true)
    if addon.PugWindow and addon.PugWindow:IsShown() and addon.RefreshPugWindow then addon:RefreshPugWindow() end
    if addon.ScheduleRaidAssist then addon:ScheduleRaidAssist(0.03, event) end

  elseif event == "PLAYER_REGEN_DISABLED" then
    if addon.ClearFrameMarkers then addon:ClearFrameMarkers() end

  elseif event == "PLAYER_REGEN_ENABLED" then
    if addon.ProcessKickQueue then addon:ProcessKickQueue() end
    if addon._raidAssistQueued and addon.ScheduleRaidAssist then
      addon._raidAssistQueued = false
      addon:ScheduleRaidAssist(0, "combat_end")
    end
    addon:RequestGroupRefresh(0)
    if addon.ScheduleFrameMarkerUpdate then addon:ScheduleFrameMarkerUpdate(0.06) end
    addon:RequestLFGRefresh(nil, true, true)
    if addon.PugWindow and addon.PugWindow:IsShown() and addon.RefreshPugWindow then addon:RefreshPugWindow() end

  elseif event == "LFG_LIST_APPLICANT_LIST_UPDATED"
      or event == "LFG_LIST_APPLICANT_UPDATED"
      or event == "LFG_LIST_APPLICATION_STATUS_UPDATED"
      or event == "LFG_LIST_ACTIVE_ENTRY_UPDATE"
      or event == "LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS"
      or event == "LFG_LIST_ENTRY_EXPIRED_TIMEOUT" then
    if (event == "LFG_LIST_APPLICANT_UPDATED" or event == "LFG_LIST_APPLICATION_STATUS_UPDATED") and addon.LFG_RefreshApplicantsAfterDone then
      addon:LFG_RefreshApplicantsAfterDone(arg1)
    end
    if addon.LFG_ClearApplicantCaches then addon:LFG_ClearApplicantCaches() else addon._lfgFlagCache = {}; addon._lfgFlagReasons = {} end
    addon:RequestLFGRefresh(nil, true, true)

  elseif event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
    if addon.LFG_ClearSearchCaches then addon:LFG_ClearSearchCaches() else addon._lfgResultFlagCache = {}; addon._lfgResultFlagReasons = {} end
    -- Blizzard_GroupFinder_VanillaStyle handles this event itself and calls
    -- UpdateResultList(). Our secure hook filters that pass. Scheduling another
    -- UpdateResults immediately afterward caused a visible jump to the top.
    addon:RequestLFGRefresh(nil, false, false)

  elseif event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
    if addon.LFG_ClearSearchCaches then addon:LFG_ClearSearchCaches() else addon._lfgResultFlagCache = {}; addon._lfgResultFlagReasons = {} end
    -- Forever does not rebuild the whole browse list for every per-result update,
    -- so re-evaluate local class/role filters here. Scroll position is preserved.
    addon:RequestLFGRefresh(nil, false, true)

  -- 12.1: the player's own listing was censored, or they just revealed it.
  -- Either way the cached title/description verdict is stale.
  elseif event == "LFG_LIST_CENSORED_ACTIVE_ENTRY_UPDATE"
      or event == "LFG_LIST_REVEALED_CENSORED_ACTIVE_ENTRY" then
    if addon.LFG_API_ClearCaches then addon:LFG_API_ClearCaches("activity") end
    if addon.LFG_ClearApplicantCaches then addon:LFG_ClearApplicantCaches() end
    if event == "LFG_LIST_CENSORED_ACTIVE_ENTRY_UPDATE" and arg1 == true then
      if addon.NotifyCensoredActiveEntry then addon:NotifyCensoredActiveEntry() end
    elseif addon.ClearCensoredEntryNotice then
      addon:ClearCensoredEntryNotice()
    end
    addon:RequestLFGRefresh(nil, true, true)

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
    -- Marked stale rather than rebuilt: these events arrive in bursts, and the
    -- caches rebuild themselves on the next lookup.
    if addon.InvalidateSocialCaches then
      addon:InvalidateSocialCaches()
    else
      if addon.RebuildFriendCache then addon:RebuildFriendCache(true) end
      if addon.RebuildGuildCache then addon:RebuildGuildCache(true) end
    end
    if addon.LFG_ClearApplicantCaches then addon:LFG_ClearApplicantCaches() else addon._lfgFlagCache = {} end
    if addon.LFG_ClearSearchCaches then addon:LFG_ClearSearchCaches() else addon._lfgResultFlagCache = {} end
    addon:RequestGroupRefresh(0)
    addon:RequestLFGRefresh(nil, true, true)
    if addon.PugWindow and addon.PugWindow:IsShown() and addon.RefreshPugWindow then addon:RefreshPugWindow() end
    if addon.ScheduleRaidAssist then addon:ScheduleRaidAssist(0.03, event) end
  end
end

eventFrame:SetScript("OnEvent", OnEvent)
