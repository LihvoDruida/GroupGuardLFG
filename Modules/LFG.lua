-- GroupGuard LFG — Modules / LFG
local addonName, addon = ...

local C_Timer = C_Timer

-- кеші/таймери LFG; сумісно з Premade Groups Filter через post-update hooks
addon._lfgFlagCache = addon._lfgFlagCache or {}
addon._lfgDebounceTimer = addon._lfgDebounceTimer or nil
addon._lfgResultFlagCache = addon._lfgResultFlagCache or {}
addon._lfgResultDebounce = addon._lfgResultDebounce or nil
addon._lfgResultRetryToken = addon._lfgResultRetryToken or 0
addon._lfgFlagReasons = addon._lfgFlagReasons or {}
addon._lfgResultFlagReasons = addon._lfgResultFlagReasons or {}

function addon:IsPremadeGroupsFilterLoaded()
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "PremadeGroupsFilter")
    return ok and loaded and true or false
  end
  if IsAddOnLoaded then
    local ok, loaded = pcall(IsAddOnLoaded, "PremadeGroupsFilter")
    return ok and loaded and true or false
  end
  return false
end

-- LFG helpers (TWW ScrollBox)
--------------------------------------------------

function addon:LFG_HasActiveListing()
  if not C_LFGList then return false end
  if C_LFGList.GetActiveEntryInfo then
    local okCall, info = pcall(C_LFGList.GetActiveEntryInfo)
    if okCall then
      if type(info) == "table" then return true end
      if type(info) == "boolean" then return info and true or false end
    end
  end
  if C_LFGList.HasActiveEntryInfo then
    local okCall, has = pcall(C_LFGList.HasActiveEntryInfo)
    return okCall and has and true or false
  end
  return false
end

function addon:LFG_CanManageApplicants()
  if self.IsDisabledNow and self:IsDisabledNow() then return false end
  if not self:LFG_HasActiveListing() then return false end

  local inGroup = false
  if IsInGroup then local ok, v = pcall(IsInGroup); inGroup = ok and v and true or false end
  if not inGroup and IsInRaid then local ok, v = pcall(IsInRaid); inGroup = ok and v and true or false end
  if not inGroup then return true end

  if self.PlayerCanManageGroup then return self:PlayerCanManageGroup() end
  return false
end

local function EnumerateScrollBoxFrames(sb)
  if not sb then return nil end
  if sb.GetFrames then
    return sb:GetFrames()
  elseif sb.EnumerateFrames then
    local frames = {}
    for f in sb:EnumerateFrames() do frames[#frames + 1] = f end
    return frames
  end
  return nil
end

local function GetApplicantIDFromRow(frame)
  if not frame then return nil end
  if frame.GetElementData then
    local ed = frame:GetElementData()
    if type(ed) == "table" then
      return ed.applicantID or ed.applicantId or ed.ApplicantID or ed.id or ed.ID
    end
  end
  return frame.applicantID or frame.applicantId or frame.ApplicantID or frame.id or frame.ID
end

local function GetResultIDFromRow(frame)
  if not frame then return nil end
  if frame.GetElementData then
    local ed = frame:GetElementData()
    if type(ed) == "table" then
      return ed.resultID or ed.resultId or ed.id or ed.ID
    end
  end
  return frame.resultID or frame.resultId or frame.id or frame.ID
end

local function CanReadValue(value)
  if value == nil then return false end
  if type(canaccessvalue) == "function" then
    local ok, allowed = pcall(canaccessvalue, value)
    if not ok or not allowed then return false end
  end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret then return false end
  end
  return true
end

local function SafeNumber(value, fallback)
  fallback = fallback or 0
  if value == nil or not CanReadValue(value) then return fallback end

  local valueType = type(value)
  if valueType == "number" then return value end
  if valueType == "string" then return tonumber(value) or fallback end

  local ok, n = pcall(tonumber, value)
  if ok and type(n) == "number" then return n end
  return fallback
end

local function GetApplicantInfoSafe(applicantID)
  if not (C_LFGList and C_LFGList.GetApplicantInfo and applicantID) then return nil end
  local values = { pcall(C_LFGList.GetApplicantInfo, applicantID) }
  if not values[1] then return nil end

  local first = values[2]
  if type(first) == "table" then return first end

  -- Compatibility fallback for clients where GetApplicantInfo returns multiple values.
  -- Known variants expose applicant/status/numMembers/comment in different slots, so use names conservatively.
  local info = {}
  for i = 2, #values do
    local v = values[i]
    if type(v) == "number" and (not info.numMembers) and v >= 0 and v <= 5 then
      info.numMembers = v
    elseif type(v) == "string" and v ~= "" then
      if not info.name and not v:find(" ") and #v <= 64 then
        info.name = v
      elseif not info.comment then
        info.comment = v
      end
    end
  end
  return info
end

local function GetApplicantMemberNameSafe(applicantID, memberIndex)
  if not (C_LFGList and C_LFGList.GetApplicantMemberInfo and applicantID and memberIndex) then return nil end
  local values = { pcall(C_LFGList.GetApplicantMemberInfo, applicantID, memberIndex) }
  if not values[1] then return nil end

  local first = values[2]
  if type(first) == "table" then
    return first.name or first.memberName or first.playerName or first.fullName
  end
  if type(first) == "string" then return first end
  return nil
end

--------------------------------------------------

local function GetSocialStatusForName(name)
  if not addon or not addon.ShouldIgnoreFilteredName then return nil, false end
  local ok, ignored, status = pcall(function() return addon:ShouldIgnoreFilteredName(name) end)
  if ok then return status, ignored and true or false end
  return nil, false
end

local function IsLFGSocialModeAllowed(status)
  if not (addon and addon.db and addon.db.social_mark_lfg) then return false end
  if status == "FRIEND" then return addon.db.social_mark_friends ~= false end
  if status == "GUILD" then return addon.db.social_mark_guild ~= false end
  return false
end


-- highlight overlay that is safe even if Background is a Texture
local LFG_HIGHLIGHT_COLORS = {
  FLAG = { 0.95, 0.16, 0.08, 0.34 },
  FRIEND = { 0.12, 0.48, 1.00, 0.30 },
  GUILD = { 0.08, 0.85, 0.24, 0.30 },
}

local function EnsureGGHighlight(host)
  if not host then return nil end

  -- If it's not a Frame/doesn't have CreateTexture, try parent
  if not host.CreateTexture and host.GetParent then
    host = host:GetParent()
  end
  if not host or not host.CreateTexture then return nil end

  if not host._ggHL then
    local t = host:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints(true)
    t:SetColorTexture(0.95, 0.16, 0.08, 0.34)
    host._ggHL = t
  end
  return host._ggHL
end

local function PaintGGHighlight(rowFrame, mode)
  if not rowFrame then return end
  local candidate = rowFrame.Contents or rowFrame.Button or rowFrame.Background or rowFrame
  local t = EnsureGGHighlight(candidate) or EnsureGGHighlight(rowFrame)
  if not t then return end

  if not mode or mode == false then
    t:Hide()
    return
  end

  local c = LFG_HIGHLIGHT_COLORS[mode] or LFG_HIGHLIGHT_COLORS.FLAG
  t:SetColorTexture(c[1], c[2], c[3], c[4])
  t:Show()
end

local function HideRowDecorations(row)
  if not row then return end
  PaintGGHighlight(row, false)
  if row._ggApplicantChip then row._ggApplicantChip:SetText(""); row._ggApplicantChip:Hide() end
  if row._ggRealmBadge then row._ggRealmBadge:SetText(""); row._ggRealmBadge:Hide() end
end

local function HookRecycledLFGRow(row)
  if not row or row._ggRecycleSafeHooked then return end
  row._ggRecycleSafeHooked = true
  if row.HookScript then
    row:HookScript("OnHide", HideRowDecorations)
    row:HookScript("OnShow", HideRowDecorations)
  end
  if row.SetElementData and type(hooksecurefunc) == "function" then
    hooksecurefunc(row, "SetElementData", HideRowDecorations)
  end
end

local function ClearGGHighlightsInScrollBox(sb)
  local frames = EnumerateScrollBoxFrames(sb)
  if not frames then return end

  for _, row in ipairs(frames) do
    HideRowDecorations(row)
  end
end

--------------------------------------------------
-- LFG logic
--------------------------------------------------

function addon:EvaluateApplicantFlag(id)
  if not id or not C_LFGList or not C_LFGList.GetApplicantInfo then return false end
  self._lfgFlagCache = self._lfgFlagCache or {}
  self._lfgFlagReasons = self._lfgFlagReasons or {}

  if self._lfgFlagCache[id] ~= nil then
    return self._lfgFlagCache[id]
  end

  local info = GetApplicantInfoSafe(id)
  local num = info and SafeNumber(info.numMembers, 0) or 0

  local function isIgnoredSocialName(name)
    if type(name) ~= "string" or name == "" or not self.ShouldIgnoreFilteredName then return false end
    local okIgnore, isIgnored = pcall(function() return self:ShouldIgnoreFilteredName(name) end)
    return okIgnore and isIgnored and true or false
  end

  -- If a friend/guild member is in the applicant composition and ignore is enabled,
  -- the whole applicant is treated as safe for filter actions.
  if type(info) == "table" and isIgnoredSocialName(info.name) then
    self._lfgFlagCache[id] = false
    self._lfgFlagReasons[id] = {}
    return false
  end
  if C_LFGList.GetApplicantMemberInfo then
    for memberIndex = 1, num do
      local memberName = GetApplicantMemberNameSafe(id, memberIndex)
      if isIgnoredSocialName(memberName) then
        self._lfgFlagCache[id] = false
        self._lfgFlagReasons[id] = {}
        return false
      end
    end
  end

  local flagged = false
  local reasons = {}

  local function testField(label, value)
    if type(value) ~= "string" or value == "" or not CanReadValue(value) then return false end
    local ok, reason = self:GetFlagReason(value)
    if ok then
      flagged = true
      reasons[#reasons + 1] = label .. " — " .. (reason or addon:Tr("LABEL_MARKED"))
      return true
    end
    return false
  end

  if type(info) == "table" then
    testField(addon:Tr("LABEL_COMMENT"), info.comment)
    testField(addon:Tr("LABEL_NAME"), info.name)
  end

  if self.db and self.db.lfg_highlight_search_members and C_LFGList.GetApplicantMemberInfo then
    for memberIndex = 1, num do
      local name = GetApplicantMemberNameSafe(id, memberIndex)
      local ignored = false
      if type(name) == "string" and self.ShouldIgnoreFilteredName then
        local okIgnore, isIgnored = pcall(function() return self:ShouldIgnoreFilteredName(name) end)
        ignored = okIgnore and isIgnored and true or false
      end
      if not ignored and testField(addon:Tr("LABEL_MEMBER"), name) then break end
    end
  end

  self._lfgFlagCache[id] = flagged
  self._lfgFlagReasons[id] = reasons
  return flagged
end

function addon:LFG_EvaluateApplicantSocial(id)
  if not (self.db and self.db.social_mark_lfg) then return nil end
  if not id or not C_LFGList or not C_LFGList.GetApplicantInfo then return nil end

  self._lfgSocialCache = self._lfgSocialCache or {}
  self._lfgSocialReasons = self._lfgSocialReasons or {}
  if self._lfgSocialCache[id] ~= nil then return self._lfgSocialCache[id] end

  local info = GetApplicantInfoSafe(id)
  local num = info and SafeNumber(info.numMembers, 0) or 0
  local mode = nil
  local reasons = {}

  local function testName(label, name)
    if type(name) ~= "string" or name == "" or not CanReadValue(name) then return nil end
    local status = GetSocialStatusForName(name)
    if status == "FRIEND" and IsLFGSocialModeAllowed("FRIEND") then
      mode = mode or "FRIEND"
      reasons[#reasons + 1] = label .. " — " .. addon:Tr("LABEL_FRIEND") .. ": " .. name
      return "FRIEND"
    elseif status == "GUILD" and IsLFGSocialModeAllowed("GUILD") then
      if mode ~= "FRIEND" then mode = "GUILD" end
      reasons[#reasons + 1] = label .. " — " .. addon:Tr("LABEL_GUILD") .. ": " .. name
      return "GUILD"
    end
    return nil
  end

  if type(info) == "table" then
    testName(addon:Tr("LABEL_NAME"), info.name)
  end

  if self.db and self.db.lfg_highlight_search_members and C_LFGList.GetApplicantMemberInfo then
    for memberIndex = 1, num do
      local name = GetApplicantMemberNameSafe(id, memberIndex)
      testName(addon:Tr("LABEL_MEMBER"), name)
    end
  end

  self._lfgSocialCache[id] = mode or false
  self._lfgSocialReasons[id] = reasons
  return mode
end


function addon:LFG_ClearApplicantCaches()
  self._lfgFlagCache = {}
  self._lfgFlagReasons = {}
  self._lfgSocialCache = {}
  self._lfgSocialReasons = {}
end

function addon:LFG_ClearSearchCaches()
  self._lfgResultFlagCache = {}
  self._lfgResultFlagReasons = {}
  self._lfgResultSocialCache = {}
  self._lfgResultSocialReasons = {}
end

function addon:LFG_ClearVisibleHighlights()
  local viewer = LFGListFrame and LFGListFrame.ApplicationViewer
  local vSB = viewer and viewer.ScrollBox
  if vSB then ClearGGHighlightsInScrollBox(vSB) end
  local sp = LFGListFrame and LFGListFrame.SearchPanel
  local sSB = sp and sp.ScrollBox
  if sSB then ClearGGHighlightsInScrollBox(sSB) end
end

function addon:LFG_DebouncedHighlight(delay)
  delay = tonumber(delay)
  if delay and delay <= 0.01 then
    addon._lfgDebounceTimer = nil
    addon:LFG_HighlightRows()
    return
  end

  delay = delay or tonumber(addon.db and addon.db.lfg_debounce) or 0.02
  if addon.RunDebounced then
    return addon:RunDebounced("lfg_applicant_highlight", delay, function()
      if addon.LFG_HighlightRows then addon:LFG_HighlightRows() end
    end)
  end

  if addon._lfgDebounceTimer then return end
  addon._lfgDebounceTimer = true
  local function run()
    addon._lfgDebounceTimer = nil
    addon:LFG_HighlightRows()
  end
  if C_Timer and C_Timer.After then C_Timer.After(delay, run) else run() end
end

function addon:LFG_HighlightRows()
  local viewer = LFGListFrame and LFGListFrame.ApplicationViewer
  local sb = viewer and viewer.ScrollBox
  if not sb then return end

  if not self.db or not self.db.lfg_highlight then
    ClearGGHighlightsInScrollBox(sb)
    return
  end

  local frames = EnumerateScrollBoxFrames(sb)
  if not frames then return end

  local flaggedMap = {}
  for _, row in ipairs(frames) do
    HookRecycledLFGRow(row)
    local applicantID = GetApplicantIDFromRow(row)
    local mode = nil
    if applicantID then
      if self.LFG_HookApplicantTooltip then self:LFG_HookApplicantTooltip(row) end
      local flagged = self:EvaluateApplicantFlag(applicantID) and true or false
      if flagged then
        flaggedMap[applicantID] = true
        mode = "FLAG"
      elseif self.db.social_mark_lfg and self.LFG_EvaluateApplicantSocial then
        mode = self:LFG_EvaluateApplicantSocial(applicantID)
      end
    end
    PaintGGHighlight(row, mode)
  end

  self._lfgFlagged = flaggedMap
  if self.LFG_UpdateButton then self:LFG_UpdateButton() end
end

function addon:LFG_DebouncedHighlightResults(delay)
  delay = tonumber(delay)
  if delay and delay <= 0.01 then
    addon._lfgResultDebounce = nil
    if addon.LFG_HighlightSearchResults then addon:LFG_HighlightSearchResults() end
    if addon.LFG_RetryHighlightSearchResults then addon:LFG_RetryHighlightSearchResults(true) end
    return
  end

  delay = delay or tonumber(addon.db and addon.db.lfg_debounce) or 0.02
  if addon.RunDebounced then
    return addon:RunDebounced("lfg_search_highlight", delay, function()
      if addon.LFG_RetryHighlightSearchResults then addon:LFG_RetryHighlightSearchResults() end
    end)
  end

  if addon._lfgResultDebounce then return end
  addon._lfgResultDebounce = true
  local function run()
    addon._lfgResultDebounce = nil
    addon:LFG_RetryHighlightSearchResults()
  end
  if C_Timer and C_Timer.After then C_Timer.After(delay, run) else run() end
end

function addon:EvaluateSearchResultFlag(resultID)
  if not resultID or not C_LFGList or not C_LFGList.GetSearchResultInfo then return false, false end

  self._lfgResultFlagCache = self._lfgResultFlagCache or {}
  self._lfgResultFlagReasons = self._lfgResultFlagReasons or {}
  if self._lfgResultFlagCache[resultID] ~= nil then
    return self._lfgResultFlagCache[resultID], false
  end

  local okInfo, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
  if not okInfo or not info then return false, true end

  local function isIgnoredSocialName(name)
    if type(name) ~= "string" or name == "" or not self.ShouldIgnoreFilteredName then return false end
    local okIgnore, isIgnored = pcall(function() return self:ShouldIgnoreFilteredName(name) end)
    return okIgnore and isIgnored and true or false
  end

  if isIgnoredSocialName(info.leaderName) then
    self._lfgResultFlagCache[resultID] = false
    self._lfgResultFlagReasons[resultID] = {}
    return false, false
  end

  local preNumMembers = info.numMembers
  local preNumKnown = CanReadValue(preNumMembers)
  local preNum = preNumKnown and SafeNumber(preNumMembers, 0) or 0
  if C_LFGList.GetSearchResultPlayerInfo then
    for memberIndex = 1, preNum do
      local ok, playerInfo = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, memberIndex)
      if ok and type(playerInfo) == "table" and isIgnoredSocialName(playerInfo.name) then
        self._lfgResultFlagCache[resultID] = false
        self._lfgResultFlagReasons[resultID] = {}
        return false, false
      end
    end
  end

  local flagged = false
  local reasons = {}
  local function testField(label, value)
    if type(value) ~= "string" or value == "" or not CanReadValue(value) then return false end
    local ok, reason = self:GetFlagReason(value)
    if ok then
      flagged = true
      reasons[#reasons + 1] = label .. " — " .. (reason or addon:Tr("LABEL_MARKED"))
      return true
    end
    return false
  end

  testField(addon:Tr("LABEL_TITLE"), info.name)
  testField(addon:Tr("LABEL_COMMENT"), info.comment)
  testField("Voice", info.voiceChat)
  testField(addon:Tr("LABEL_LEADER"), info.leaderName)

  if flagged then
    self._lfgResultFlagCache[resultID] = true
    self._lfgResultFlagReasons[resultID] = reasons
    return true, false
  end

  if not (self.db and self.db.lfg_highlight_search_members) then
    self._lfgResultFlagCache[resultID] = false
    self._lfgResultFlagReasons[resultID] = reasons
    return false, false
  end
  if not C_LFGList.GetSearchResultPlayerInfo then
    self._lfgResultFlagCache[resultID] = false
    self._lfgResultFlagReasons[resultID] = reasons
    return false, false
  end

  local numMembers = info.numMembers
  local numKnown = CanReadValue(numMembers)
  local num = numKnown and SafeNumber(numMembers, 0) or 0
  local loaded = 0
  for memberIndex = 1, num do
    local ok, playerInfo = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, memberIndex)
    if ok and type(playerInfo) == "table" then
      local name = playerInfo.name
      local ignored = false
      if type(name) == "string" and self.ShouldIgnoreFilteredName then
        local okIgnore, isIgnored = pcall(function() return self:ShouldIgnoreFilteredName(name) end)
        ignored = okIgnore and isIgnored and true or false
      end
      if not ignored and testField(addon:Tr("LABEL_MEMBER"), name) then
        self._lfgResultFlagCache[resultID] = true
        self._lfgResultFlagReasons[resultID] = reasons
        return true, false
      end
      if type(name) == "string" and name ~= "" and CanReadValue(name) then
        loaded = loaded + 1
      end
    end
  end

  local pending = (not numKnown) or loaded < num
  if not pending then
    self._lfgResultFlagCache[resultID] = false
    self._lfgResultFlagReasons[resultID] = reasons
  end
  return false, pending
end

function addon:LFG_EvaluateSearchResultSocial(resultID)
  if not (self.db and self.db.social_mark_lfg) then return nil, false end
  if not resultID or not C_LFGList or not C_LFGList.GetSearchResultInfo then return nil, false end

  self._lfgResultSocialCache = self._lfgResultSocialCache or {}
  self._lfgResultSocialReasons = self._lfgResultSocialReasons or {}
  if self._lfgResultSocialCache[resultID] ~= nil then
    return self._lfgResultSocialCache[resultID], false
  end

  local okInfo, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
  if not okInfo or not info then return nil, true end

  local mode = nil
  local reasons = {}
  local loaded = 0

  local function testName(label, name)
    if type(name) ~= "string" or name == "" or not CanReadValue(name) then return nil end
    local status = GetSocialStatusForName(name)
    if status == "FRIEND" and IsLFGSocialModeAllowed("FRIEND") then
      mode = mode or "FRIEND"
      reasons[#reasons + 1] = label .. " — " .. addon:Tr("LABEL_FRIEND") .. ": " .. name
      return "FRIEND"
    elseif status == "GUILD" and IsLFGSocialModeAllowed("GUILD") then
      if mode ~= "FRIEND" then mode = "GUILD" end
      reasons[#reasons + 1] = label .. " — " .. addon:Tr("LABEL_GUILD") .. ": " .. name
      return "GUILD"
    end
    return nil
  end

  testName(addon:Tr("LABEL_LEADER"), info.leaderName)

  local numMembers = info.numMembers
  local numKnown = CanReadValue(numMembers)
  local num = numKnown and SafeNumber(numMembers, 0) or 0

  if self.db and self.db.lfg_highlight_search_members and C_LFGList.GetSearchResultPlayerInfo then
    for memberIndex = 1, num do
      local ok, playerInfo = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, memberIndex)
      if ok and type(playerInfo) == "table" then
        local name = playerInfo.name
        testName(addon:Tr("LABEL_MEMBER"), name)
        if type(name) == "string" and name ~= "" and CanReadValue(name) then
          loaded = loaded + 1
        end
      end
    end
  end

  local pending = (not numKnown) or loaded < num
  if not pending then
    self._lfgResultSocialCache[resultID] = mode or false
    self._lfgResultSocialReasons[resultID] = reasons
  end

  return mode, pending
end

function addon:LFG_AddSearchTooltip(tooltip, resultID)
  if not (self.db and self.db.lfg_tooltips) then return end
  if self.IsDisabledNow and self:IsDisabledNow() then return end
  if not tooltip or not resultID then return end

  local flagged = self:EvaluateSearchResultFlag(resultID)
  local mode = flagged and "FLAG" or nil
  if not mode and self.LFG_EvaluateSearchResultSocial then
    mode = self:LFG_EvaluateSearchResultSocial(resultID)
  end
  if not mode then return end

  local now = GetTime and GetTime() or 0
  if tooltip._ggLastResultID == resultID and tooltip._ggLastMode == mode and (tooltip._ggLastAddedAt or 0) + 0.05 > now then return end
  tooltip._ggLastResultID = resultID
  tooltip._ggLastMode = mode
  tooltip._ggLastAddedAt = now

  tooltip:AddLine(" ")
  if mode == "FRIEND" then
    tooltip:AddLine("|cff44aaff" .. addon:Tr("TOOLTIP_FRIEND_GROUP") .. "|r")
  elseif mode == "GUILD" then
    tooltip:AddLine("|cff44ff77" .. addon:Tr("TOOLTIP_GUILD_GROUP") .. "|r")
  else
    tooltip:AddLine("|cffff5544GroupGuard LFG|r")
  end

  if self.db.lfg_tooltip_reasons then
    local reasons = nil
    if mode == "FLAG" then
      reasons = self._lfgResultFlagReasons and self._lfgResultFlagReasons[resultID]
    else
      reasons = self._lfgResultSocialReasons and self._lfgResultSocialReasons[resultID]
    end

    if type(reasons) == "table" and #reasons > 0 then
      for i = 1, math.min(#reasons, 4) do
        if mode == "FRIEND" then
          tooltip:AddLine("• " .. tostring(reasons[i]), 0.35, 0.72, 1.00, true)
        elseif mode == "GUILD" then
          tooltip:AddLine("• " .. tostring(reasons[i]), 0.35, 1.00, 0.48, true)
        else
          tooltip:AddLine("• " .. tostring(reasons[i]), 1, 0.78, 0.38, true)
        end
      end
    else
      tooltip:AddLine("• " .. addon:Tr("TOOLTIP_MARKED"), 1, 0.78, 0.38, true)
    end
  else
    tooltip:AddLine("• " .. addon:Tr("TOOLTIP_MARKED"), 1, 0.78, 0.38, true)
  end
  tooltip:Show()
end

function addon:LFG_AddApplicantTooltip(row)
  if not (self.db and self.db.lfg_tooltips) then return end
  if self.IsDisabledNow and self:IsDisabledNow() then return end
  if not row or not GameTooltip then return end

  local applicantID = GetApplicantIDFromRow(row)
  if not applicantID then return end

  local flagged = self:EvaluateApplicantFlag(applicantID)
  local mode = flagged and "FLAG" or nil
  if not mode and self.LFG_EvaluateApplicantSocial then
    mode = self:LFG_EvaluateApplicantSocial(applicantID)
  end
  if not mode then return end

  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  if mode == "FRIEND" then
    GameTooltip:AddLine("|cff44aaff" .. addon:Tr("TOOLTIP_FRIEND_APP") .. "|r")
  elseif mode == "GUILD" then
    GameTooltip:AddLine("|cff44ff77" .. addon:Tr("TOOLTIP_GUILD_APP") .. "|r")
  else
    GameTooltip:AddLine("|cffffaa44GroupGuard LFG|r")
  end

  if self.db.lfg_tooltip_reasons then
    local reasons = nil
    if mode == "FLAG" then
      reasons = self._lfgFlagReasons and self._lfgFlagReasons[applicantID]
    else
      reasons = self._lfgSocialReasons and self._lfgSocialReasons[applicantID]
    end

    if type(reasons) == "table" and #reasons > 0 then
      for i = 1, math.min(#reasons, 4) do
        if mode == "FRIEND" then
          GameTooltip:AddLine("• " .. tostring(reasons[i]), 0.35, 0.72, 1.00, true)
        elseif mode == "GUILD" then
          GameTooltip:AddLine("• " .. tostring(reasons[i]), 0.35, 1.00, 0.48, true)
        else
          GameTooltip:AddLine("• " .. tostring(reasons[i]), 1, 0.78, 0.38, true)
        end
      end
    else
      GameTooltip:AddLine("• " .. addon:Tr("TOOLTIP_MARKED"), 1, 0.78, 0.38, true)
    end
  else
    GameTooltip:AddLine("• " .. addon:Tr("TOOLTIP_MARKED"), 1, 0.78, 0.38, true)
  end
  GameTooltip:Show()
end

function addon:LFG_HookApplicantTooltip(row)
  if not row or row._ggApplicantTooltipHooked or not row.HookScript then return end
  row._ggApplicantTooltipHooked = true
  row:HookScript("OnEnter", function(frame)
    if addon and addon.LFG_AddApplicantTooltip then addon:LFG_AddApplicantTooltip(frame) end
  end)
  row:HookScript("OnLeave", function(frame)
    if GameTooltip and GameTooltip:GetOwner() == frame then GameTooltip:Hide() end
  end)
end

function addon:InitPGFIntegration()
  if self._pgfIntegrated then return end
  if self.db and self.db.pgf_integration == false then return end
  if not self:IsPremadeGroupsFilterLoaded() then return end

  local PGF = PremadeGroupsFilter and PremadeGroupsFilter.Debug
  if type(PGF) ~= "table" then return end
  self._pgfIntegrated = true

  local function refreshResults(delay)
    if addon and addon.db and addon.db.pgf_integration ~= false and addon.LFG_DebouncedHighlightResults then
      addon:LFG_DebouncedHighlightResults(delay or 0.05)
    end
  end

  if type(PGF.FilterSearchResults) == "function" then
    hooksecurefunc(PGF, "FilterSearchResults", function() refreshResults(0.05) end)
  end
  if type(PGF.DoFilterSearchResults) == "function" then
    hooksecurefunc(PGF, "DoFilterSearchResults", function() refreshResults(0.08) end)
  end
  if type(PGF.OnLFGListSearchPanelUpdateResultList) == "function" then
    hooksecurefunc(PGF, "OnLFGListSearchPanelUpdateResultList", function() refreshResults(0.08) end)
  end
  if type(PGF.OnLFGListSearchEntryUpdate) == "function" then
    hooksecurefunc(PGF, "OnLFGListSearchEntryUpdate", function() refreshResults(0.04) end)
  end
  if type(PGF.ResetSearchEntries) == "function" then
    hooksecurefunc(PGF, "ResetSearchEntries", function()
      addon._lfgResultFlagCache = {}
      addon._lfgResultFlagReasons = {}
      addon._lfgResultSocialCache = {}
      addon._lfgResultSocialReasons = {}
      refreshResults(0.08)
    end)
  end
end

function addon:LFG_RetryHighlightSearchResults(force)
  local sp = LFGListFrame and LFGListFrame.SearchPanel
  if not (sp and sp.IsVisible and sp:IsVisible()) then return end
  if self._lfgResultRetryScheduled and not force then return end
  if force then self._lfgResultRetryScheduled = false end

  self._lfgResultRetryScheduled = true
  self._lfgResultRetryToken = (self._lfgResultRetryToken or 0) + 1
  local token = self._lfgResultRetryToken
  self._lfgResultFlagCache = {}
  self._lfgResultFlagReasons = {}
  self._lfgResultSocialCache = {}
  self._lfgResultSocialReasons = {}

  local delays = { 0.03, 0.18, 0.55, 1.10 }
  if not (C_Timer and C_Timer.After) then
    addon:LFG_HighlightSearchResults()
    addon._lfgResultRetryScheduled = false
    return
  end
  for index, delay in ipairs(delays) do
    C_Timer.After(delay, function()
      if addon._lfgResultRetryToken ~= token then return end
      addon:LFG_HighlightSearchResults()
      if index == #delays then addon._lfgResultRetryScheduled = false end
    end)
  end
end

function addon:LFG_HighlightSearchResults()
  local sp = LFGListFrame and LFGListFrame.SearchPanel
  local sb = sp and sp.ScrollBox
  if not sb then return end
  if sp.IsVisible and not sp:IsVisible() then return end

  if not self.db or not self.db.lfg_highlight then
    ClearGGHighlightsInScrollBox(sb)
    return
  end

  local frames = EnumerateScrollBoxFrames(sb)
  if not frames then return end

  for _, row in ipairs(frames) do
    HookRecycledLFGRow(row)
    local rid = GetResultIDFromRow(row)
    local mode = nil
    if rid then
      local flagged = self:EvaluateSearchResultFlag(rid)
      if flagged then
        mode = "FLAG"
      elseif self.db.social_mark_lfg and self.LFG_EvaluateSearchResultSocial then
        mode = self:LFG_EvaluateSearchResultSocial(rid)
      end
    end
    PaintGGHighlight(row, mode)
  end
end

function addon:LFG_HookViewer()
  local viewer = LFGListFrame and LFGListFrame.ApplicationViewer
  if not viewer then return end

  local sb = viewer.ScrollBox
  if sb and not sb._ggHooked then
    sb._ggHooked = true

    if sb.HookScript then sb:HookScript("OnMouseWheel", function() ClearGGHighlightsInScrollBox(sb); addon:LFG_DebouncedHighlight(0.01) end) end
    if sb.FullUpdate and type(sb.FullUpdate) == "function" then
      hooksecurefunc(sb, "FullUpdate", function() addon:LFG_DebouncedHighlight() end)
    end
    if sb.Update and type(sb.Update) == "function" then
      hooksecurefunc(sb, "Update", function() addon:LFG_DebouncedHighlight() end)
    end
    if sb.Refresh and type(sb.Refresh) == "function" then
      hooksecurefunc(sb, "Refresh", function() addon:LFG_DebouncedHighlight() end)
    end
  end

  if not addon._hookedViewerUpdate then
    addon._hookedViewerUpdate = true
    if type(LFGListApplicationViewer_UpdateApplicants) == "function" then
      hooksecurefunc("LFGListApplicationViewer_UpdateApplicants", function()
        addon:LFG_DebouncedHighlight()
      end)
    end
    if type(LFGListApplicationViewer_UpdateInfo) == "function" then
      hooksecurefunc("LFGListApplicationViewer_UpdateInfo", function()
        addon:LFG_DebouncedHighlight()
      end)
    end
    if type(LFGListApplicationViewer_UpdateResults) == "function" then
      hooksecurefunc("LFGListApplicationViewer_UpdateResults", function()
        addon:LFG_DebouncedHighlight()
      end)
    end
  end
end

function addon:LFG_HookSearchPanel()
  local sp = LFGListFrame and LFGListFrame.SearchPanel
  local sb = sp and sp.ScrollBox
  if sb and not sb._ggHooked then
    sb._ggHooked = true

    if sb.HookScript then sb:HookScript("OnMouseWheel", function() ClearGGHighlightsInScrollBox(sb); addon:LFG_DebouncedHighlightResults(0.01) end) end
    if sb.FullUpdate and type(sb.FullUpdate) == "function" then
      hooksecurefunc(sb, "FullUpdate", function() addon:LFG_DebouncedHighlightResults(0.05) end)
    end
    if sb.Update and type(sb.Update) == "function" then
      hooksecurefunc(sb, "Update", function() addon:LFG_DebouncedHighlightResults(0.05) end)
    end
    if sb.Refresh and type(sb.Refresh) == "function" then
      hooksecurefunc(sb, "Refresh", function() addon:LFG_DebouncedHighlightResults(0.05) end)
    end
  end


  if not addon._ggTooltipHooked and type(LFGListUtil_SetSearchEntryTooltip) == "function" then
    addon._ggTooltipHooked = true
    hooksecurefunc("LFGListUtil_SetSearchEntryTooltip", function(tooltip, resultID)
      if addon and addon.LFG_AddSearchTooltip then addon:LFG_AddSearchTooltip(tooltip, resultID) end
    end)
  end
  if addon.InitPGFIntegration then addon:InitPGFIntegration() end

  if addon._ggHookedSearchPanel then return end
  addon._ggHookedSearchPanel = true

  if type(LFGListSearchPanel_UpdateResults) == "function" then
    hooksecurefunc("LFGListSearchPanel_UpdateResults", function()
      addon:LFG_RetryHighlightSearchResults()
    end)
  end
  if type(LFGListSearchPanel_UpdateResultList) == "function" then
    hooksecurefunc("LFGListSearchPanel_UpdateResultList", function()
      addon:LFG_RetryHighlightSearchResults()
    end)
  end
  if type(LFGListSearchEntry_Update) == "function" then
    hooksecurefunc("LFGListSearchEntry_Update", function()
      addon:LFG_DebouncedHighlightResults(0.03)
    end)
  end
end

function addon:LFG_LayoutButton()
  local btn = self.lfgButton
  local parent = LFGListFrame and LFGListFrame.ApplicationViewer
  if not btn or not parent then return end

  btn:ClearAllPoints()
  btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -28)
end

function addon:LFG_CreateButton()
  if self.lfgButton then
    self:LFG_HookViewer()
    self:LFG_LayoutButton()
    return
  end

  local parent = LFGListFrame and LFGListFrame.ApplicationViewer
  if not parent then return end

  local btn = CreateFrame("Button", "GroupGuardLFGDeclineBtn", parent, "UIPanelButtonTemplate")
  btn:SetSize(172, 20)
  btn:SetText(addon:Tr("LFG_DECLINE_BUTTON_FMT", 0))
  btn:SetFrameStrata("DIALOG")
  btn:SetFrameLevel(parent:GetFrameLevel() + 10)
  if btn.SetNormalFontObject then btn:SetNormalFontObject(GameFontNormalSmall) end
  if btn.SetHighlightFontObject then btn:SetHighlightFontObject(GameFontHighlightSmall) end
  btn:SetHitRectInsets(0, 0, 0, 0)
  btn:SetScript("OnClick", function()
    if addon and addon.LFG_DeclineFlagged then addon:LFG_DeclineFlagged("manual") end
  end)
  btn:HookScript("OnShow", function() addon:LFG_LayoutButton() end)
  btn:Hide()
  self.lfgButton = btn

  self:LFG_LayoutButton()
  parent:HookScript("OnShow", function() addon:LFG_LayoutButton() end)
  parent:HookScript("OnSizeChanged", function() addon:LFG_LayoutButton() end)
  self:LFG_HookViewer()
end

function addon:LFG_GetFlaggedCount(flagged)
  local count = 0
  for _ in pairs(flagged or {}) do count = count + 1 end
  return count
end

function addon:LFG_BuildFlaggedList(flagged, skipKnown)
  local list = {}
  self._lfgAutoDeclined = self._lfgAutoDeclined or {}
  for id in pairs(flagged or {}) do
    if not skipKnown or not self._lfgAutoDeclined[id] then
      list[#list + 1] = id
    end
  end
  table.sort(list)
  return list
end

function addon:LFG_DeclineApplicants(appIDs, source)
  if type(appIDs) ~= "table" or #appIDs == 0 then return 0 end
  if not C_LFGList or not C_LFGList.DeclineApplicant then return 0 end
  if not self:LFG_CanManageApplicants() then return 0 end

  source = source or "manual"
  self._lfgAutoDeclined = self._lfgAutoDeclined or {}
  self._lfgManualDeclined = self._lfgManualDeclined or {}
  self._lfgDeclineInFlight = self._lfgDeclineInFlight or {}

  local sourceCache = (source == "auto") and self._lfgAutoDeclined or self._lfgManualDeclined
  local maxCount = #appIDs
  if source == "auto" then
    if self._lfgAutoDeclineRunning then return 0 end
    maxCount = math.max(1, tonumber(self.db and self.db.lfg_auto_decline_batch_limit) or 5)
    if maxCount > #appIDs then maxCount = #appIDs end
  end

  local delayStep = tonumber(self.db and self.db.lfg_auto_decline_delay) or 0.12
  if delayStep < 0.03 then delayStep = 0.03 end
  if delayStep > 1.0 then delayStep = 1.0 end

  local scheduled = 0
  local declined = 0
  local failed = 0
  local details = {}

  local function noteReason(id)
    local reasons = self._lfgFlagReasons and self._lfgFlagReasons[id]
    if type(reasons) == "table" and #reasons > 0 and #details < 2 then
      details[#details + 1] = tostring(reasons[1])
    end
  end

  local function markLocal(id, kind)
    sourceCache[id] = true
    self._lfgDeclineInFlight[id] = kind or source
  end

  local function clearFlagged(id)
    if self._lfgFlagged then self._lfgFlagged[id] = nil end
  end

  local function unmarkLocal(id)
    sourceCache[id] = nil
    if self._lfgDeclineInFlight then self._lfgDeclineInFlight[id] = nil end
  end

  if source == "manual" then
    -- Manual decline must run directly from the user's click.
    for i = 1, maxCount do
      local id = appIDs[i]
      if id and not sourceCache[id] and not self._lfgDeclineInFlight[id] then
        noteReason(id)
        local ok = pcall(C_LFGList.DeclineApplicant, id)
        if ok then
          declined = declined + 1
          markLocal(id, "manual")
          clearFlagged(id)
        else
          failed = failed + 1
        end
      end
    end

    self._lfgDeclineInFlight = {}
    if self.LFG_UpdateButton then self:LFG_UpdateButton() end
    if self.LFG_DebouncedHighlight then self:LFG_DebouncedHighlight(0) end
    local function rescan()
      if addon and addon.LFG_ScanApplicants then addon:LFG_ScanApplicants() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.05, rescan) else rescan() end

    if declined > 0 or failed > 0 then
      if failed > 0 then
        print((self.printPrefix or "GroupGuard LFG:"), addon:Tr("LFG_DECLINE_SUMMARY", declined, failed))
      else
        print((self.printPrefix or "GroupGuard LFG:"), addon:Tr("LFG_DECLINE_DONE"))
      end
    end
    return declined
  end

  self._lfgAutoDeclineRunning = true
  if self.BeginActionSequence then
    self:BeginActionSequence("lfg_auto_decline", delayStep * maxCount + 0.8)
  end

  local function finishAuto()
    if addon then
      addon._lfgDeclineInFlight = {}
      addon._lfgAutoDeclineRunning = false
    end
    if addon and addon.LFG_ScanApplicants then addon:LFG_ScanApplicants() end
    if addon and addon.EndActionSequence then addon:EndActionSequence("lfg_auto_decline") end

    if declined > 0 then
      local detailText = table.concat(details, " • ")
      if detailText == "" then detailText = addon:Tr("LFG_MARKED_RULES") end
      if addon.NotifyLFGAutoDeclined then addon:NotifyLFGAutoDeclined(declined, detailText) end
    elseif failed > 0 then
      print((addon.printPrefix or "GroupGuard LFG:"), addon:Tr("LFG_DECLINE_SUMMARY", 0, failed))
    end
  end

  for i = 1, maxCount do
    local id = appIDs[i]
    if id and not sourceCache[id] and not self._lfgDeclineInFlight[id] then
      scheduled = scheduled + 1
      markLocal(id, "auto")
      noteReason(id)
      local function attempt()
        if not addon or not C_LFGList or not C_LFGList.DeclineApplicant then unmarkLocal(id); failed = failed + 1; return end
        if not (addon.db and addon.db.lfg_auto_decline) then unmarkLocal(id); return end
        if addon.LFG_CanManageApplicants and not addon:LFG_CanManageApplicants() then unmarkLocal(id); failed = failed + 1; return end
        local ok = pcall(C_LFGList.DeclineApplicant, id)
        if ok then
          declined = declined + 1
          clearFlagged(id)
        else
          failed = failed + 1
          unmarkLocal(id)
        end
      end
      if C_Timer and C_Timer.After then C_Timer.After(delayStep * (scheduled - 1), attempt) else attempt() end
    end
  end

  if scheduled > 0 then
    if self.LFG_UpdateButton then self:LFG_UpdateButton() end
    if self.LFG_DebouncedHighlight then self:LFG_DebouncedHighlight(0) end
    if C_Timer and C_Timer.After then C_Timer.After(delayStep * scheduled + 0.18, finishAuto) else finishAuto() end
  else
    self._lfgAutoDeclineRunning = false
    if self.EndActionSequence then self:EndActionSequence("lfg_auto_decline") end
  end
  return scheduled
end

function addon:LFG_DeclineFlagged(source)
  source = source or "manual"
  if source == "manual" and C_LFGList and C_LFGList.GetApplicants then
    self._lfgFlagCache = {}
    self._lfgFlagReasons = {}
    self._lfgSocialCache = {}
    self._lfgSocialReasons = {}

    local fresh = {}
    local okApps, apps = pcall(C_LFGList.GetApplicants)
    apps = okApps and apps or {}
    for _, appID in ipairs(apps or {}) do
      if self:EvaluateApplicantFlag(appID) then
        fresh[appID] = true
      end
    end
    self._lfgFlagged = fresh
  end

  if not self._lfgFlagged then return 0 end
  local list = self:LFG_BuildFlaggedList(self._lfgFlagged, source == "auto")
  return self:LFG_DeclineApplicants(list, source)
end

function addon:LFG_AutoDeclineFlagged(flagged)
  if not (self.db and self.db.lfg_auto_decline) then return 0 end
  if not self:LFG_CanManageApplicants() then return 0 end
  local list = self:LFG_BuildFlaggedList(flagged, true)
  return self:LFG_DeclineApplicants(list, "auto")
end

function addon:LFG_UpdateButton()
  -- Do not hide the manual button just because auto-decline is enabled.
  -- Auto-decline can be blocked by Blizzard protected UI rules or by changing LFG rights;
  -- the button is the safe fallback for any marked applicants that remain.
  if not self.db or not self.db.lfg_show_button then
    if self.lfgButton then self.lfgButton:Hide() end
    return
  end
  if not self.lfgButton then self:LFG_CreateButton() end
  if not self.lfgButton then return end

  local count = 0
  if self._lfgFlagged then
    for _ in pairs(self._lfgFlagged) do count = count + 1 end
  end

  if not self:LFG_CanManageApplicants() or count <= 0 then
    self.lfgButton:Hide()
    return
  end

  local template = (self.db.lfg_button_text and tostring(self.db.lfg_button_text)) or addon:Tr("LFG_DECLINE_BUTTON_FMT")
  local okText
  if string.find(template, "%%d") then
    local ok, formatted = pcall(string.format, template, count)
    okText = ok and formatted or addon:Tr("LFG_DECLINE_BUTTON_FMT", count)
  else
    okText = template .. " (" .. tostring(count) .. ")"
  end
  self.lfgButton:SetText(okText)
  local fontString = self.lfgButton.Text or _G[self.lfgButton:GetName() .. "Text"]
  local textWidth = fontString and fontString:GetUnboundedStringWidth() or 120
  local width = math.max(132, math.min(182, math.ceil(textWidth) + 28))
  self.lfgButton:SetSize(width, 20)
  if self.LFG_LayoutButton then self:LFG_LayoutButton() end
  self.lfgButton:Show()
end

function addon:LFG_ScanApplicants()
  if not C_LFGList or not C_LFGList.GetApplicants then
    self._lfgFlagged = {}
    self._lfgFlagCache = {}
    self._lfgFlagReasons = {}
    self._lfgSocialCache = {}
    self._lfgSocialReasons = {}
    self._lfgAutoDeclined = {}
    self._lfgManualDeclined = {}
    self._lfgDeclineInFlight = {}
    self:LFG_UpdateButton()
    self:LFG_DebouncedHighlight()
    return
  end

  local active = self:LFG_HasActiveListing()
  if not active then
    self._lfgFlagged = {}
    self._lfgFlagCache = {}
    self._lfgFlagReasons = {}
    self._lfgSocialCache = {}
    self._lfgSocialReasons = {}
    self._lfgAutoDeclined = {}
    self._lfgManualDeclined = {}
    self._lfgDeclineInFlight = {}
    self:LFG_UpdateButton()
    self:LFG_DebouncedHighlight()
    return
  end

  self._lfgFlagCache = {}
  self._lfgFlagReasons = {}
  self._lfgSocialCache = {}
  self._lfgSocialReasons = {}

  local okApps, apps = pcall(C_LFGList.GetApplicants)
  if not okApps or type(apps) ~= "table" then apps = {} end
  local flagged = {}
  for _, appID in ipairs(apps) do
    if self:EvaluateApplicantFlag(appID) then
      flagged[appID] = true
    end
  end

  self._lfgFlagged = flagged
  if self.LFG_AutoDeclineFlagged then self:LFG_AutoDeclineFlagged(flagged) end
  self:LFG_UpdateButton()
  self:LFG_DebouncedHighlight()
end

--------------------------------------------------
