-- GroupGuard LFG — Modules / LFG Enhancements
-- Lightweight ideas adapted from LFG quality-of-life addons without replacing Blizzard/PGF/Oak UI.
local addonName, addon = ...

local C_Timer = C_Timer
local math_floor = math.floor
local string_format = string.format
local table_sort = table.sort
local table_concat = table.concat

local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }
local ROLE_SHORT = { TANK = "T", HEALER = "H", DAMAGER = "DPS" }
local CLASS_ORDER = {
  "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}
local CLASS_SET = {}
for _, classFile in ipairs(CLASS_ORDER) do CLASS_SET[classFile] = true end

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
  if type(value) == "number" then return value end
  if type(value) == "string" then return tonumber(value) or fallback end
  local ok, n = pcall(tonumber, value)
  return (ok and type(n) == "number") and n or fallback
end

local function SafeText(value)
  if value == nil or not CanReadValue(value) then return nil end
  if type(value) == "string" then return value end
  local ok, result = pcall(tostring, value)
  if ok then return result end
  return nil
end

local function GetResultIDFromRow(frame)
  if not frame then return nil end
  if addon and addon.SafeGetElementData then
    local ed = addon:SafeGetElementData(frame)
    if type(ed) == "table" then
      return ed.resultID or ed.resultId or ed.searchResultID or ed.searchResultId or ed.id or ed.ID
    end
  elseif frame.GetElementData then
    local ok, ed = pcall(frame.GetElementData, frame)
    if ok and type(ed) == "table" then
      return ed.resultID or ed.resultId or ed.searchResultID or ed.searchResultId or ed.id or ed.ID
    end
  end
  return frame.resultID or frame.resultId or frame.id or frame.ID
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

local function ColorizeClass(classFile, text)
  text = text or classFile or "?"
  if type(classFile) ~= "string" then return text end
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if not c then return text end
  local r = math_floor(((c.r or 1) * 255) + 0.5)
  local g = math_floor(((c.g or 1) * 255) + 0.5)
  local b = math_floor(((c.b or 1) * 255) + 0.5)
  return string_format("|cff%02x%02x%02x%s|r", r, g, b, text)
end

local function FormatAge(seconds)
  seconds = math_floor(SafeNumber(seconds, 0))
  if seconds <= 0 then return nil end
  local days = math_floor(seconds / 86400)
  seconds = seconds - days * 86400
  local hours = math_floor(seconds / 3600)
  seconds = seconds - hours * 3600
  local minutes = math_floor(seconds / 60)
  seconds = seconds - minutes * 60
  if days > 0 then return string_format("%dd %dh", days, hours) end
  if hours > 0 then return string_format("%dh %dm", hours, minutes) end
  if minutes > 0 then return string_format("%dm %02ds", minutes, seconds) end
  return string_format("%ds", seconds)
end

local function AddClassCount(classCounts, classFile, count)
  classFile = SafeText(classFile)
  if not classFile or classFile == "" then return end
  classFile = classFile:upper()
  if not CLASS_SET[classFile] then return end
  classCounts[classFile] = (classCounts[classFile] or 0) + (tonumber(count) or 1)
end

local function AddRoleCount(roleCounts, role, count)
  role = SafeText(role)
  if not role or role == "" then return end
  role = role:upper()
  if role == "DAMAGE" then role = "DAMAGER" end
  if not roleCounts[role] then return end
  roleCounts[role] = roleCounts[role] + (tonumber(count) or 1)
end

local function ReadMemberCountsFromAPI(resultID, roleCounts, classCounts)
  if not (C_LFGList and C_LFGList.GetSearchResultMemberCounts) then return false end
  local ok, counts = pcall(C_LFGList.GetSearchResultMemberCounts, resultID)
  if not ok or type(counts) ~= "table" then return false end

  local readAny = false
  for _, role in ipairs(ROLE_ORDER) do
    local n = counts[role] or counts[role:lower()] or counts[ROLE_SHORT[role]]
    n = SafeNumber(n, nil)
    if n ~= nil and n > 0 then
      roleCounts[role] = math.max(roleCounts[role], n)
      readAny = true
    end
  end

  -- Some clients expose classesByRole, others expose class totals directly.
  if type(counts.classesByRole) == "table" then
    for role, classMap in pairs(counts.classesByRole) do
      if type(classMap) == "table" then
        local roleTotal = 0
        for classFile, n in pairs(classMap) do
          n = SafeNumber(n, 0)
          if n > 0 then
            roleTotal = roleTotal + n
            AddClassCount(classCounts, classFile, n)
            readAny = true
          end
        end
        role = SafeText(role)
        if role then
          role = role:upper()
          if role == "DAMAGE" then role = "DAMAGER" end
          if roleCounts[role] then roleCounts[role] = math.max(roleCounts[role], roleTotal) end
        end
      end
    end
  end

  for classFile, n in pairs(counts) do
    if type(n) == "number" and CLASS_SET[tostring(classFile):upper()] then
      AddClassCount(classCounts, classFile, n)
      readAny = true
    end
  end

  return readAny
end

local function ReadMemberCountsFromPlayers(resultID, info, roleCounts, classCounts)
  if not (C_LFGList and C_LFGList.GetSearchResultPlayerInfo) then return 0 end
  local numMembers = SafeNumber(info and info.numMembers, 0)
  local loaded = 0
  local playerRoleCounts = { TANK = 0, HEALER = 0, DAMAGER = 0 }
  for i = 1, numMembers do
    local playerInfo = addon and addon.LFG_API_GetSearchResultPlayerInfo and addon:LFG_API_GetSearchResultPlayerInfo(resultID, i) or nil
    if type(playerInfo) == "table" then
      loaded = loaded + 1
      AddRoleCount(playerRoleCounts, playerInfo.assignedRole or playerInfo.role or playerInfo.lfgRole, 1)
      AddClassCount(classCounts, playerInfo.classFilename or playerInfo.classFileName or playerInfo.className or playerInfo.class, 1)
    end
  end
  for _, role in ipairs(ROLE_ORDER) do
    roleCounts[role] = math.max(roleCounts[role] or 0, playerRoleCounts[role] or 0)
  end
  return loaded
end

function addon:LFG_BuildSearchInsight(resultID)
  if not (C_LFGList and C_LFGList.GetSearchResultInfo and resultID) then return nil end

  local info = addon and addon.LFG_API_GetSearchResultInfo and addon:LFG_API_GetSearchResultInfo(resultID) or nil
  if type(info) ~= "table" then return nil end

  local roleCounts = { TANK = 0, HEALER = 0, DAMAGER = 0 }
  local classCounts = {}
  local usedCountsAPI = ReadMemberCountsFromAPI(resultID, roleCounts, classCounts)
  local loadedPlayers = ReadMemberCountsFromPlayers(resultID, info, roleCounts, classCounts)

  local socialTotal = SafeNumber(info.numBNetFriends, 0) + SafeNumber(info.numCharFriends, 0) + SafeNumber(info.numGuildMates, 0)

  local insight = {
    resultID = resultID,
    ageText = FormatAge(info.age),
    numMembers = SafeNumber(info.numMembers, 0),
    roleCounts = roleCounts,
    classCounts = classCounts,
    loadedPlayers = loadedPlayers,
    usedCountsAPI = usedCountsAPI,
    socialTotal = socialTotal,
    bnetFriends = SafeNumber(info.numBNetFriends, 0),
    charFriends = SafeNumber(info.numCharFriends, 0),
    guildMates = SafeNumber(info.numGuildMates, 0),
  }

  return insight
end

local function HasAnyRoleCounts(roleCounts)
  for _, role in ipairs(ROLE_ORDER) do
    if (roleCounts[role] or 0) > 0 then return true end
  end
  return false
end

local function BuildClassBreakdown(classCounts)
  local entries = {}
  for classFile, n in pairs(classCounts or {}) do
    if n and n > 0 then
      entries[#entries + 1] = { classFile = classFile, count = n }
    end
  end
  table_sort(entries, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.classFile < b.classFile
  end)

  local parts = {}
  for i = 1, math.min(#entries, 8) do
    local e = entries[i]
    local label = ColorizeClass(e.classFile, e.classFile)
    parts[#parts + 1] = (e.count > 1) and (label .. " x" .. e.count) or label
  end
  if #entries > 8 then parts[#parts + 1] = "+" .. tostring(#entries - 8) end
  return parts
end

function addon:LFG_AppendSearchInsightTooltip(tooltip, resultID)
  if not (self.db and self.db.lfg_tooltips and self.db.lfg_tooltip_details) then return end
  if self.IsDisabledNow and self:IsDisabledNow() then return end
  if not tooltip or not resultID then return end

  local now = GetTime and GetTime() or 0
  local shiftDown = IsShiftKeyDown and IsShiftKeyDown()
  if tooltip._ggInsightResultID == resultID and tooltip._ggInsightShift == shiftDown and (tooltip._ggInsightAddedAt or 0) + 0.05 > now then
    return
  end
  tooltip._ggInsightResultID = resultID
  tooltip._ggInsightShift = shiftDown
  tooltip._ggInsightAddedAt = now

  local insight = self:LFG_BuildSearchInsight(resultID)
  if not insight then return end

  local added = false
  local function ensureHeader()
    if added then return end
    tooltip:AddLine(" ")
    tooltip:AddLine("|cffd33b2f" .. self:Tr("LFG_INSIGHTS_TITLE") .. "|r")
    added = true
  end

  if insight.ageText then
    ensureHeader()
    tooltip:AddLine("• " .. self:Tr("LFG_INSIGHTS_CREATED", insight.ageText), 0.82, 0.82, 0.82, true)
  end

  if HasAnyRoleCounts(insight.roleCounts) then
    ensureHeader()
    tooltip:AddLine("• " .. self:Tr("LFG_INSIGHTS_COMP", insight.roleCounts.TANK or 0, insight.roleCounts.HEALER or 0, insight.roleCounts.DAMAGER or 0), 0.95, 0.88, 0.62, true)
  elseif insight.numMembers and insight.numMembers > 0 then
    ensureHeader()
    tooltip:AddLine("• " .. self:Tr("LFG_INSIGHTS_MEMBERS", insight.numMembers), 0.82, 0.82, 0.82, true)
  end

  if self.LFG_AppendAdvisorTooltipLines then
    self:LFG_AppendAdvisorTooltipLines(tooltip, resultID, insight, ensureHeader)
  end

  if insight.socialTotal and insight.socialTotal > 0 then
    ensureHeader()
    tooltip:AddLine("• " .. self:Tr("LFG_INSIGHTS_SOCIAL", insight.bnetFriends, insight.charFriends, insight.guildMates), 0.35, 0.90, 1.0, true)
  end

  local classParts = BuildClassBreakdown(insight.classCounts)
  if #classParts > 0 then
    ensureHeader()
    if shiftDown then
      tooltip:AddLine("• " .. self:Tr("LFG_INSIGHTS_CLASSES") .. ": " .. table_concat(classParts, ", "), 0.78, 0.90, 1.0, true)
    else
      tooltip:AddLine("• " .. self:Tr("LFG_INSIGHTS_SHIFT"), 0.58, 0.58, 0.58, true)
    end
  end

  if added then
    addon._lfgCurrentSearchTooltip = tooltip
    addon._lfgCurrentSearchResultID = resultID
    tooltip:Show()
  end
end

function addon:LFG_HookEnhancedSearchTooltip()
  if self._ggEnhancedTooltipHooked then return end
  if type(hooksecurefunc) ~= "function" then return end
  if type(LFGListUtil_SetSearchEntryTooltip) ~= "function" then return end
  self._ggEnhancedTooltipHooked = true
  hooksecurefunc("LFGListUtil_SetSearchEntryTooltip", function(tooltip, resultID)
    if addon and addon.LFG_AppendSearchInsightTooltip then
      addon:LFG_AppendSearchInsightTooltip(tooltip, resultID)
    end
  end)
end

function addon:LFG_SetupTooltipModifierRefresh()
  if self._ggTooltipModifierFrame then return end
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("MODIFIER_STATE_CHANGED")
  frame:SetScript("OnEvent", function(_, _, key)
    if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
    local tooltip = addon and addon._lfgCurrentSearchTooltip
    local resultID = addon and addon._lfgCurrentSearchResultID
    if not tooltip or not resultID or not tooltip:IsShown() then return end
    if type(LFGListUtil_SetSearchEntryTooltip) ~= "function" then return end
    tooltip:ClearLines()
    pcall(LFGListUtil_SetSearchEntryTooltip, tooltip, resultID)
  end)
  self._ggTooltipModifierFrame = frame
end

function addon:LFG_ShouldMuteApplicantPing()
  if not (self.db and self.db.lfg_mute_applicant_ping) then return false end
  if self._lfgAutoDeclineRunning then return true end
  if self.IsActionSequenceActive and self:IsActionSequenceActive("lfg_auto_decline") then return true end
  return false
end

function addon:LFG_SetupApplicantPingMute()
  if self._ggApplicantPingHooked then return end
  local anim = QueueStatusButton and QueueStatusButton.EyeHighlightAnim
  if not anim or not anim.GetScript or not anim.SetScript then return end

  self._ggApplicantPingHooked = true
  local originalOnPlay = anim:GetScript("OnPlay")
  local originalOnLoop = anim:GetScript("OnLoop")

  local function wrap(original)
    return function(...)
      if addon and addon.LFG_ShouldMuteApplicantPing and addon:LFG_ShouldMuteApplicantPing() then
        return
      end
      if original then return original(...) end
    end
  end

  anim:SetScript("OnPlay", wrap(originalOnPlay))
  anim:SetScript("OnLoop", wrap(originalOnLoop))
end

function addon:LFG_InitEnhancements()
  if self.LFG_HookEnhancedSearchTooltip then self:LFG_HookEnhancedSearchTooltip() end
  if self.LFG_SetupTooltipModifierRefresh then self:LFG_SetupTooltipModifierRefresh() end
  if self.LFG_SetupApplicantPingMute then self:LFG_SetupApplicantPingMute() end

  local needsRetry = (not self._ggEnhancedTooltipHooked) or (not self._ggApplicantPingHooked)
  if needsRetry and C_Timer and C_Timer.After and not self._ggEnhancementRetryScheduled and (self._ggEnhancementRetryCount or 0) < 8 then
    self._ggEnhancementRetryScheduled = true
    self._ggEnhancementRetryCount = (self._ggEnhancementRetryCount or 0) + 1
    C_Timer.After(1.0, function()
      if addon then
        addon._ggEnhancementRetryScheduled = false
        if addon.LFG_InitEnhancements then addon:LFG_InitEnhancements() end
      end
    end)
  end
end

function addon:LFG_PrintVisibleSearchStats()
  local sp = LFGListFrame and LFGListFrame.SearchPanel
  local sb = sp and sp.ScrollBox
  local frames = EnumerateScrollBoxFrames(sb)
  if not frames then
    print((self.printPrefix or "GroupGuard LFG:"), self:Tr("LFG_STATS_NO_RESULTS"))
    return
  end

  local total, flagged, friend, guild = 0, 0, 0, 0
  for _, row in ipairs(frames) do
    local rid = GetResultIDFromRow(row)
    if rid then
      total = total + 1
      local isFlagged = self.EvaluateSearchResultFlag and self:EvaluateSearchResultFlag(rid)
      if isFlagged then
        flagged = flagged + 1
      elseif self.LFG_EvaluateSearchResultSocial then
        local mode = self:LFG_EvaluateSearchResultSocial(rid)
        if mode == "FRIEND" then friend = friend + 1 elseif mode == "GUILD" then guild = guild + 1 end
      end
    end
  end

  print((self.printPrefix or "GroupGuard LFG:"), self:Tr("LFG_STATS_FMT", total, flagged, friend, guild))
end

SLASH_GROUPGUARDLFGSTATS1 = "/gglfgstats"
SlashCmdList.GROUPGUARDLFGSTATS = function()
  if addon and addon.LFG_PrintVisibleSearchStats then addon:LFG_PrintVisibleSearchStats() end
end
