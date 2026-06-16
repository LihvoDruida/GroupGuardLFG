-- GroupGuard LFG — Modules / Applicant Enhancements
-- Compact applicant summaries inspired by GroupFinderRio's applicant/spec workflow.
-- This module only reads Blizzard-provided LFG data; it does not require or emulate Raider.IO.
local addonName, addon = ...

local C_Timer = C_Timer
local string_format = string.format
local table_concat = table.concat

local ROLE_SHORT = { TANK = "T", HEALER = "H", DAMAGER = "D", NONE = "-" }
local APPLICATION_DONE = {
  cancelled = true,
  timedout = true,
  inviteaccepted = true,
  invitedeclined = true,
  declined = true,
  declined_full = true,
}

local function CanReadValue(value)
  if value == nil then return false end
  if type(canaccessvalue) == "function" then
    local ok, allowed = pcall(canaccessvalue, value)
    if not ok or not allowed then return false end
  end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if ok and secret then return false end
  end
  return true
end

local function SafeNumber(value, fallback)
  if fallback == nil then fallback = nil end
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

local function SafeBool(value)
  if value == nil or not CanReadValue(value) then return false end
  return value == true
end

local function GetApplicantIDFromRow(frame)
  if not frame then return nil end
  if frame.GetElementData then
    local ok, ed = pcall(frame.GetElementData, frame)
    if ok and type(ed) == "table" then return ed.applicantID or ed.applicantId or ed.ApplicantID or ed.id or ed.ID end
  end
  return frame.applicantID or frame.applicantId or frame.ApplicantID or frame.id or frame.ID
end

local function GetApplicantInfoSafe(applicantID)
  if not (C_LFGList and C_LFGList.GetApplicantInfo and applicantID) then return nil end
  local values = { pcall(C_LFGList.GetApplicantInfo, applicantID) }
  if not values[1] then return nil end
  if type(values[2]) == "table" then return values[2] end

  -- Compatibility fallback for older clients where GetApplicantInfo returned multiple values.
  local info = {}
  for i = 2, #values do
    local v = values[i]
    if type(v) == "string" and v ~= "" then
      if not info.name and not v:find(" ") and #v <= 64 then
        info.name = v
      elseif not info.applicationStatus and (v == "applied" or v == "invited" or v == "inviteaccepted" or v == "invitedeclined" or v == "cancelled" or v == "declined" or v == "timedout") then
        info.applicationStatus = v
      elseif not info.comment then
        info.comment = v
      end
    elseif type(v) == "number" then
      if not info.numMembers and v >= 0 and v <= 5 then info.numMembers = v end
    end
  end
  return info
end

local function NormalizeRole(role, tank, healer, damage)
  role = SafeText(role)
  if role then role = role:upper() end
  if role == "DAMAGE" then role = "DAMAGER" end
  if role == "TANK" or role == "HEALER" or role == "DAMAGER" then return role end
  if SafeBool(tank) then return "TANK" end
  if SafeBool(healer) then return "HEALER" end
  if SafeBool(damage) then return "DAMAGER" end
  return "NONE"
end

local function GetSpecName(specID)
  specID = SafeNumber(specID, nil)
  if not specID or specID <= 0 or not GetSpecializationInfoByID then return nil end
  local values = { pcall(GetSpecializationInfoByID, specID) }
  if not values[1] then return nil end
  local name = SafeText(values[3]) or SafeText(values[2])
  return name
end

local function ColorizeClass(classFile, text)
  text = text or classFile or "?"
  classFile = SafeText(classFile)
  if not classFile then return text end
  classFile = classFile:upper()
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if not c then return text end
  local r = math.floor(((c.r or 1) * 255) + 0.5)
  local g = math.floor(((c.g or 1) * 255) + 0.5)
  local b = math.floor(((c.b or 1) * 255) + 0.5)
  return string_format("|cff%02x%02x%02x%s|r", r, g, b, text)
end

local function ReadApplicantMember(applicantID, index)
  if not (C_LFGList and C_LFGList.GetApplicantMemberInfo and applicantID and index) then return nil end
  local values = { pcall(C_LFGList.GetApplicantMemberInfo, applicantID, index) }
  if not values[1] then return nil end

  local m
  if type(values[2]) == "table" then
    local t = values[2]
    m = {
      name = t.name or t.memberName or t.playerName or t.fullName,
      classFilename = t.classFilename or t.classFileName or t.classFile or t.class,
      localizedClass = t.localizedClass or t.className,
      level = t.level,
      itemLevel = t.itemLevel or t.ilvl,
      honorLevel = t.honorLevel,
      tank = t.tank,
      healer = t.healer,
      damage = t.damage or t.damager,
      assignedRole = t.assignedRole or t.role or t.lfgRole,
      relationship = t.relationship,
      dungeonScore = t.dungeonScore or t.mythicPlusScore or t.mplusScore,
      pvpItemLevel = t.pvpItemLevel,
      factionGroup = t.factionGroup or t.faction,
      raceID = t.raceID or t.raceId,
      specID = t.specID or t.specId,
      isLeaver = t.isLeaver,
    }
  else
    -- Retail commonly returns:
    -- name, class, localizedClass, level, itemLevel, honorLevel,
    -- tank, healer, damage, assignedRole, relationship, dungeonScore,
    -- pvpItemLevel, factionGroup, raceID, specID, isLeaver
    m = {
      name = values[2],
      classFilename = values[3],
      localizedClass = values[4],
      level = values[5],
      itemLevel = values[6],
      honorLevel = values[7],
      tank = values[8],
      healer = values[9],
      damage = values[10],
      assignedRole = values[11],
      relationship = values[12],
      dungeonScore = values[13],
      pvpItemLevel = values[14],
      factionGroup = values[15],
      raceID = values[16],
      specID = values[17],
      isLeaver = values[18],
    }
  end

  m.name = SafeText(m.name)
  m.classFilename = SafeText(m.classFilename)
  m.localizedClass = SafeText(m.localizedClass)
  m.level = SafeNumber(m.level, nil)
  m.itemLevel = SafeNumber(m.itemLevel, nil)
  m.honorLevel = SafeNumber(m.honorLevel, nil)
  m.assignedRole = NormalizeRole(m.assignedRole, m.tank, m.healer, m.damage)
  m.relationship = SafeText(m.relationship)
  m.dungeonScore = SafeNumber(m.dungeonScore, nil)
  m.pvpItemLevel = SafeNumber(m.pvpItemLevel, nil)
  m.factionGroup = SafeText(m.factionGroup)
  m.raceID = SafeNumber(m.raceID, nil)
  m.specID = SafeNumber(m.specID, nil)
  m.specName = GetSpecName(m.specID)
  m.isLeaver = SafeBool(m.isLeaver)
  return m
end

function addon:LFG_BuildApplicantSummary(applicantID)
  if not applicantID then return nil end
  local info = GetApplicantInfoSafe(applicantID)
  if not info then return nil end
  local num = SafeNumber(info.numMembers, 1) or 1
  if num < 1 then num = 1 elseif num > 5 then num = 5 end

  local roles = { TANK = 0, HEALER = 0, DAMAGER = 0, NONE = 0 }
  local bestScore, bestItemLevel, bestPvpItemLevel = 0, 0, 0
  local itemLevelTotal, itemLevelCount = 0, 0
  local leavers = 0
  local minLevel, maxLevel = nil, nil
  local names, specIDs, members = {}, {}, {}
  local relationships = {}

  for i = 1, num do
    local m = ReadApplicantMember(applicantID, i)
    if type(m) == "table" then
      members[#members + 1] = m
      local role = m.assignedRole or "NONE"
      if roles[role] == nil then role = "NONE" end
      roles[role] = roles[role] + 1

      local score = SafeNumber(m.dungeonScore, 0) or 0
      if score > bestScore then bestScore = score end
      local ilvl = SafeNumber(m.itemLevel, 0) or 0
      if ilvl > 0 then
        if ilvl > bestItemLevel then bestItemLevel = ilvl end
        itemLevelTotal = itemLevelTotal + ilvl
        itemLevelCount = itemLevelCount + 1
      end
      local pvp = SafeNumber(m.pvpItemLevel, 0) or 0
      if pvp > bestPvpItemLevel then bestPvpItemLevel = pvp end
      local lvl = SafeNumber(m.level, nil)
      if lvl then
        minLevel = (not minLevel or lvl < minLevel) and lvl or minLevel
        maxLevel = (not maxLevel or lvl > maxLevel) and lvl or maxLevel
      end
      if m.isLeaver == true then leavers = leavers + 1 end
      if m.name and m.name ~= "" then names[#names + 1] = m.name end
      if m.specID and m.specID > 0 then specIDs[#specIDs + 1] = m.specID end
      if m.relationship and m.relationship ~= "" then relationships[m.relationship] = (relationships[m.relationship] or 0) + 1 end
    end
  end

  local avgItemLevel = itemLevelCount > 0 and (itemLevelTotal / itemLevelCount) or 0
  return {
    applicantID = applicantID,
    numMembers = num,
    loadedMembers = #members,
    roles = roles,
    bestScore = bestScore,
    bestItemLevel = bestItemLevel,
    avgItemLevel = avgItemLevel,
    bestPvpItemLevel = bestPvpItemLevel,
    itemLevelCount = itemLevelCount,
    leavers = leavers,
    minLevel = minLevel,
    maxLevel = maxLevel,
    names = names,
    specIDs = specIDs,
    members = members,
    relationships = relationships,
    comment = SafeText(info.comment),
    status = SafeText(info.applicationStatus or info.status),
  }
end

local function FormatApplicantChip(self, summary)
  if not summary then return "" end
  local text = self:Tr("APPLICANT_CHIP_ROLES", summary.numMembers or 0, summary.roles.TANK or 0, summary.roles.HEALER or 0, summary.roles.DAMAGER or 0)
  if summary.bestItemLevel and summary.bestItemLevel > 0 then
    text = text .. "  " .. self:Tr("APPLICANT_CHIP_ILVL", summary.bestItemLevel, summary.avgItemLevel or 0)
  end
  if summary.bestPvpItemLevel and summary.bestPvpItemLevel > 0 then
    text = text .. "  " .. self:Tr("APPLICANT_CHIP_PVP_ILVL", summary.bestPvpItemLevel)
  end
  if summary.bestScore and summary.bestScore > 0 then
    text = text .. "  " .. self:Tr("APPLICANT_CHIP_SCORE", summary.bestScore)
  end
  if summary.leavers and summary.leavers > 0 then
    text = text .. "  " .. self:Tr("APPLICANT_CHIP_LEAVER", summary.leavers)
  end
  return text
end

local function HideApplicantChip(row)
  if row and row._ggApplicantChip then
    row._ggApplicantChip:SetText("")
    row._ggApplicantChip._ggOwnerApplicantID = nil
    row._ggApplicantChip:Hide()
  end
end

local function EnsureApplicantChip(row)
  if not row or not row.CreateFontString then return nil end
  if not row._ggApplicantChip then
    local chip = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    chip:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -10, 5)
    chip:SetJustifyH("RIGHT")
    chip:SetTextColor(0.82, 0.82, 0.82, 0.95)
    if chip.SetWordWrap then chip:SetWordWrap(false) end
    if chip.SetNonSpaceWrap then chip:SetNonSpaceWrap(false) end
    row._ggApplicantChip = chip
  end
  return row._ggApplicantChip
end

local function ScheduleRowRefresh(row, delay)
  if not row then return end
  if C_Timer and C_Timer.After then
    C_Timer.After(delay or 0, function()
      if addon and addon.LFG_UpdateApplicantChip then addon:LFG_UpdateApplicantChip(row) end
    end)
  elseif addon and addon.LFG_UpdateApplicantChip then
    addon:LFG_UpdateApplicantChip(row)
  end
end

local function HookApplicantRow(row)
  if not row or row._ggApplicantEnhancementRowHooked then return end
  row._ggApplicantEnhancementRowHooked = true
  if row.HookScript then
    row:HookScript("OnHide", HideApplicantChip)
    row:HookScript("OnShow", function(frame)
      HideApplicantChip(frame)
      ScheduleRowRefresh(frame, 0)
    end)
  end
  if row.SetElementData and type(hooksecurefunc) == "function" then
    hooksecurefunc(row, "SetElementData", function(frame)
      HideApplicantChip(frame)
      ScheduleRowRefresh(frame, 0)
    end)
  end
end

function addon:LFG_UpdateApplicantChip(row)
  if not row then return end
  HideApplicantChip(row)
  if not (self.db and self.db.applicant_summary_chips) then return end
  if row.IsShown and not row:IsShown() then return end
  local appID = GetApplicantIDFromRow(row)
  if not appID then return end
  local summary = self:LFG_BuildApplicantSummary(appID)
  if not summary then return end
  local chip = EnsureApplicantChip(row)
  if not chip then return end
  chip._ggOwnerApplicantID = appID
  chip:SetText(FormatApplicantChip(self, summary))
  if summary.leavers and summary.leavers > 0 then
    chip:SetTextColor(1.0, 0.46, 0.30, 0.95)
  else
    chip:SetTextColor(0.82, 0.82, 0.82, 0.95)
  end
  chip:Show()
end

local function MemberDisplayLine(self, m)
  local name = ColorizeClass(m.classFilename, m.name or "?")
  local parts = {}
  if m.specName then parts[#parts + 1] = m.specName end
  if m.localizedClass then parts[#parts + 1] = m.localizedClass end
  local roleKey = "ROLE_" .. tostring(m.assignedRole or "NONE")
  local roleText = self:Tr(roleKey)
  if roleText == roleKey then roleText = m.assignedRole or "-" end
  parts[#parts + 1] = roleText
  if m.level and m.level > 0 then parts[#parts + 1] = self:Tr("APPLICANT_MEMBER_LEVEL", m.level) end
  if m.itemLevel and m.itemLevel > 0 then parts[#parts + 1] = self:Tr("APPLICANT_MEMBER_ILVL", m.itemLevel) end
  if m.pvpItemLevel and m.pvpItemLevel > 0 then parts[#parts + 1] = self:Tr("APPLICANT_MEMBER_PVP_ILVL", m.pvpItemLevel) end
  if m.dungeonScore and m.dungeonScore > 0 then parts[#parts + 1] = self:Tr("APPLICANT_MEMBER_SCORE", m.dungeonScore) end
  if m.honorLevel and m.honorLevel > 0 then parts[#parts + 1] = self:Tr("APPLICANT_MEMBER_HONOR", m.honorLevel) end
  if m.raceID and m.raceID > 0 then parts[#parts + 1] = self:Tr("APPLICANT_MEMBER_RACE", m.raceID) end
  if m.relationship and m.relationship ~= "" then parts[#parts + 1] = self:Tr("APPLICANT_MEMBER_RELATION", m.relationship) end
  if m.factionGroup and m.factionGroup ~= "" then parts[#parts + 1] = self:Tr("APPLICANT_MEMBER_FACTION", m.factionGroup) end
  if m.isLeaver then parts[#parts + 1] = self:Tr("APPLICANT_MEMBER_LEAVER") end
  return name .. " — " .. table_concat(parts, " • ")
end

local function FormatRelationships(summary)
  local out = {}
  for relation, count in pairs(summary.relationships or {}) do
    out[#out + 1] = tostring(relation) .. " x" .. tostring(count)
  end
  return #out > 0 and table_concat(out, ", ") or nil
end

function addon:LFG_AppendApplicantSummaryTooltip(row)
  if not (self.db and self.db.lfg_tooltips and self.db.applicant_summary_tooltips) then return end
  if not row or not GameTooltip then return end
  local appID = GetApplicantIDFromRow(row)
  if not appID then return end
  local now = GetTime and GetTime() or 0
  if GameTooltip._ggApplicantSummaryAppID == appID and (GameTooltip._ggApplicantSummaryAt or 0) + 0.05 > now then return end
  GameTooltip._ggApplicantSummaryAppID = appID
  GameTooltip._ggApplicantSummaryAt = now

  local summary = self:LFG_BuildApplicantSummary(appID)
  if not summary then return end

  if GameTooltip:GetOwner() ~= row then GameTooltip:SetOwner(row, "ANCHOR_RIGHT") end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("|cffd33b2f" .. self:Tr("APPLICANT_SUMMARY_TITLE") .. "|r")
  if summary.status and summary.status ~= "" then
    GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_STATUS", summary.status), 0.82, 0.82, 0.82, true)
  end
  GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_COMP", summary.roles.TANK or 0, summary.roles.HEALER or 0, summary.roles.DAMAGER or 0), 0.95, 0.88, 0.62, true)
  GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_MEMBERS", summary.loadedMembers or 0, summary.numMembers or 0), 0.82, 0.82, 0.82, true)
  if summary.bestItemLevel and summary.bestItemLevel > 0 then
    GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_ILVL", summary.bestItemLevel, summary.avgItemLevel or 0), 0.82, 0.82, 0.82, true)
  end
  if summary.bestPvpItemLevel and summary.bestPvpItemLevel > 0 then
    GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_PVP_ILVL", summary.bestPvpItemLevel), 0.82, 0.82, 0.82, true)
  end
  if summary.bestScore and summary.bestScore > 0 then
    GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_SCORE", summary.bestScore), 0.35, 0.90, 1.0, true)
  end
  if summary.minLevel and summary.maxLevel then
    if summary.minLevel == summary.maxLevel then
      GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_LEVEL", summary.maxLevel), 0.82, 0.82, 0.82, true)
    else
      GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_LEVEL_RANGE", summary.minLevel, summary.maxLevel), 0.82, 0.82, 0.82, true)
    end
  end
  if summary.leavers and summary.leavers > 0 then
    GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_LEAVER", summary.leavers), 1.0, 0.46, 0.30, true)
  end
  local rel = FormatRelationships(summary)
  if rel then
    GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_RELATIONSHIPS", rel), 0.56, 0.86, 1.0, true)
  end
  if summary.comment and summary.comment ~= "" then
    GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_COMMENT", summary.comment), 0.86, 0.82, 0.72, true)
  end
  if type(summary.members) == "table" and #summary.members > 0 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(self:Tr("APPLICANT_SUMMARY_MEMBERS_TITLE"), 1.0, 0.82, 0.36, true)
    for i = 1, #summary.members do
      GameTooltip:AddLine("• " .. MemberDisplayLine(self, summary.members[i]), 0.78, 0.90, 1.0, true)
    end
  elseif type(summary.specIDs) == "table" and #summary.specIDs > 0 then
    GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_SPECS") .. ": " .. table_concat(summary.specIDs, ", "), 0.78, 0.90, 1.0, true)
  end
  GameTooltip:Show()
end

local function EnumerateApplicantRows()
  local viewer = LFGListFrame and LFGListFrame.ApplicationViewer
  local sb = viewer and viewer.ScrollBox
  if not sb then return nil end
  if sb.GetFrames then return sb:GetFrames() end
  if sb.EnumerateFrames then
    local frames = {}
    for f in sb:EnumerateFrames() do frames[#frames + 1] = f end
    return frames
  end
  return nil
end

function addon:LFG_RefreshApplicantChips()
  local rows = EnumerateApplicantRows()
  if not rows then return end
  self._ggApplicantRows = self._ggApplicantRows or {}
  for _, row in ipairs(rows) do
    self._ggApplicantRows[row] = true
    HookApplicantRow(row)
    if self.LFG_UpdateApplicantChip then self:LFG_UpdateApplicantChip(row) end
    if row and not row._ggApplicantSummaryTooltipHooked and row.HookScript then
      row._ggApplicantSummaryTooltipHooked = true
      row:HookScript("OnEnter", function(frame)
        if addon and addon.LFG_AppendApplicantSummaryTooltip then addon:LFG_AppendApplicantSummaryTooltip(frame) end
      end)
      row:HookScript("OnLeave", function(frame)
        if GameTooltip and GameTooltip:GetOwner() == frame then GameTooltip:Hide() end
      end)
    end
  end
end

function addon:LFG_HideApplicantDecorations()
  if not self._ggApplicantRows then return end
  for row in pairs(self._ggApplicantRows) do HideApplicantChip(row) end
end

function addon:LFG_RefreshApplicantsAfterDone(applicantID)
  if not (self.db and self.db.applicant_auto_refresh_done) then return end
  if not applicantID or not (C_LFGList and C_LFGList.GetApplicantInfo and C_LFGList.RefreshApplicants) then return end
  local info = GetApplicantInfoSafe(applicantID)
  local status = info and SafeText(info.applicationStatus)
  if status and APPLICATION_DONE[status] then
    if C_Timer and C_Timer.After then
      C_Timer.After(0.08, function()
        if C_LFGList and C_LFGList.RefreshApplicants then pcall(C_LFGList.RefreshApplicants) end
      end)
    else
      pcall(C_LFGList.RefreshApplicants)
    end
  end
end

function addon:LFG_PrintApplicantStats()
  local rows = EnumerateApplicantRows()
  if not rows then
    print((self.printPrefix or "GroupGuard LFG:"), self:Tr("APPLICANT_STATS_NO_ROWS"))
    return
  end
  local total, members, tanks, heals, dps, leavers, bestIlvl, bestScore = 0, 0, 0, 0, 0, 0, 0, 0
  for _, row in ipairs(rows) do
    local appID = GetApplicantIDFromRow(row)
    if appID then
      local s = self:LFG_BuildApplicantSummary(appID)
      if s then
        total = total + 1
        members = members + (s.numMembers or 0)
        tanks = tanks + (s.roles.TANK or 0)
        heals = heals + (s.roles.HEALER or 0)
        dps = dps + (s.roles.DAMAGER or 0)
        leavers = leavers + (s.leavers or 0)
        if (s.bestItemLevel or 0) > bestIlvl then bestIlvl = s.bestItemLevel end
        if (s.bestScore or 0) > bestScore then bestScore = s.bestScore end
      end
    end
  end
  print((self.printPrefix or "GroupGuard LFG:"), self:Tr("APPLICANT_STATS_FMT", total, members, tanks, heals, dps, leavers, bestIlvl, bestScore))
end

function addon:LFG_InitApplicantEnhancements()
  if self._ggApplicantEnhancementsHooked then return end
  self._ggApplicantEnhancementsHooked = true
  local function schedule()
    if addon and addon.RunDebounced then
      addon:RunDebounced("applicant_chips", 0.01, function() if addon.LFG_RefreshApplicantChips then addon:LFG_RefreshApplicantChips() end end)
    elseif C_Timer and C_Timer.After then
      C_Timer.After(0.01, function() if addon and addon.LFG_RefreshApplicantChips then addon:LFG_RefreshApplicantChips() end end)
    elseif addon and addon.LFG_RefreshApplicantChips then
      addon:LFG_RefreshApplicantChips()
    end
  end
  local function hideThenSchedule()
    if addon and addon.LFG_HideApplicantDecorations then addon:LFG_HideApplicantDecorations() end
    schedule()
  end

  local viewer = LFGListFrame and LFGListFrame.ApplicationViewer
  local sb = viewer and viewer.ScrollBox
  if sb and not sb._ggApplicantEnhancementHooked then
    sb._ggApplicantEnhancementHooked = true
    if sb.HookScript then sb:HookScript("OnMouseWheel", hideThenSchedule) end
    if sb.FullUpdate then hooksecurefunc(sb, "FullUpdate", hideThenSchedule) end
    if sb.Update then hooksecurefunc(sb, "Update", hideThenSchedule) end
    if sb.Refresh then hooksecurefunc(sb, "Refresh", hideThenSchedule) end
  end
  if type(LFGListApplicationViewer_UpdateApplicants) == "function" then hooksecurefunc("LFGListApplicationViewer_UpdateApplicants", hideThenSchedule) end
  if type(LFGListApplicationViewer_UpdateInfo) == "function" then hooksecurefunc("LFGListApplicationViewer_UpdateInfo", hideThenSchedule) end
  if type(LFGListApplicationViewer_UpdateResults) == "function" then hooksecurefunc("LFGListApplicationViewer_UpdateResults", hideThenSchedule) end
  schedule()
end

SLASH_GROUPGUARDLFGAPPS1 = "/ggapps"
SlashCmdList.GROUPGUARDLFGAPPS = function()
  if addon and addon.LFG_PrintApplicantStats then addon:LFG_PrintApplicantStats() end
end
