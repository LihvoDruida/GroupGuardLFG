-- GroupGuard LFG — Modules / Applicant Enhancements
-- Compact applicant summaries inspired by GroupFinderRio's applicant/spec workflow.
local addonName, addon = ...

local C_Timer = C_Timer

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

local function GetApplicantIDFromRow(frame)
  if not frame then return nil end
  if frame.GetElementData then
    local ed = frame:GetElementData()
    if type(ed) == "table" then return ed.applicantID or ed.applicantId or ed.ApplicantID or ed.id or ed.ID end
  end
  return frame.applicantID or frame.applicantId or frame.ApplicantID or frame.id or frame.ID
end

local function GetApplicantInfoSafe(applicantID)
  if not (C_LFGList and C_LFGList.GetApplicantInfo and applicantID) then return nil end
  local values = { pcall(C_LFGList.GetApplicantInfo, applicantID) }
  if not values[1] then return nil end
  if type(values[2]) == "table" then return values[2] end
  local info = {}
  for i = 2, #values do
    local v = values[i]
    if type(v) == "string" then
      if not info.name and v ~= "" then info.name = v elseif not info.comment and v ~= "" then info.comment = v end
    elseif type(v) == "number" and not info.numMembers and v >= 0 and v <= 5 then
      info.numMembers = v
    end
  end
  return info
end

local function ReadApplicantMember(applicantID, index)
  if not (C_LFGList and C_LFGList.GetApplicantMemberInfo and applicantID and index) then return nil end
  local values = { pcall(C_LFGList.GetApplicantMemberInfo, applicantID, index) }
  if not values[1] then return nil end
  if type(values[2]) == "table" then return values[2] end

  -- Retail commonly returns: name, class, localizedClass, level, itemLevel, honorLevel,
  -- tank, healer, damage, assignedRole, relationship, dungeonScore, pvpItemLevel, factionGroup, raceID, specID, isLeaver
  return {
    name = values[2],
    classFilename = values[3],
    localizedClass = values[4],
    level = values[5],
    itemLevel = values[6],
    assignedRole = values[11],
    relationship = values[12],
    dungeonScore = values[13],
    pvpItemLevel = values[14],
    specID = values[17],
    isLeaver = values[18],
  }
end

function addon:LFG_BuildApplicantSummary(applicantID)
  if not applicantID then return nil end
  local info = GetApplicantInfoSafe(applicantID)
  if not info then return nil end
  local num = SafeNumber(info.numMembers, 1)
  if num < 1 then num = 1 elseif num > 5 then num = 5 end

  local roles = { TANK = 0, HEALER = 0, DAMAGER = 0, NONE = 0 }
  local bestScore, bestItemLevel, leavers = 0, 0, 0
  local names = {}
  local specIDs = {}

  for i = 1, num do
    local m = ReadApplicantMember(applicantID, i)
    if type(m) == "table" then
      local role = SafeText(m.assignedRole or m.role or m.lfgRole) or "NONE"
      if role == "DAMAGE" then role = "DAMAGER" end
      if roles[role] == nil then role = "NONE" end
      roles[role] = roles[role] + 1

      local score = SafeNumber(m.dungeonScore or m.mythicPlusScore, 0)
      if score > bestScore then bestScore = score end
      local ilvl = SafeNumber(m.itemLevel or m.ilvl, 0)
      if ilvl > bestItemLevel then bestItemLevel = ilvl end
      if m.isLeaver == true then leavers = leavers + 1 end
      local n = SafeText(m.name)
      if n and n ~= "" then names[#names + 1] = n end
      local specID = SafeNumber(m.specID or m.specId, 0)
      if specID > 0 then specIDs[#specIDs + 1] = specID end
    end
  end

  return {
    applicantID = applicantID,
    numMembers = num,
    roles = roles,
    bestScore = bestScore,
    bestItemLevel = bestItemLevel,
    leavers = leavers,
    names = names,
    specIDs = specIDs,
    comment = SafeText(info.comment),
    status = SafeText(info.applicationStatus),
  }
end

local function FormatApplicantChip(summary)
  if not summary then return "" end
  local text = string.format("%s%d %s%d %s%d", ROLE_SHORT.TANK, summary.roles.TANK or 0, ROLE_SHORT.HEALER, summary.roles.HEALER or 0, ROLE_SHORT.DAMAGER, summary.roles.DAMAGER or 0)
  if summary.bestItemLevel and summary.bestItemLevel > 0 then text = text .. string.format("  %.0f ilvl", summary.bestItemLevel) end
  if summary.bestScore and summary.bestScore > 0 then text = text .. string.format("  %.0f score", summary.bestScore) end
  if summary.leavers and summary.leavers > 0 then text = text .. "  !leaver" end
  return text
end

local function EnsureApplicantChip(row)
  if not row or not row.CreateFontString then return nil end
  if not row._ggApplicantChip then
    local chip = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    chip:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -10, 5)
    chip:SetJustifyH("RIGHT")
    chip:SetTextColor(0.82, 0.82, 0.82, 0.95)
    row._ggApplicantChip = chip
  end
  return row._ggApplicantChip
end

function addon:LFG_UpdateApplicantChip(row)
  if not row then return end
  if not (self.db and self.db.applicant_summary_chips) then
    if row._ggApplicantChip then row._ggApplicantChip:Hide() end
    return
  end
  local appID = GetApplicantIDFromRow(row)
  if not appID then
    if row._ggApplicantChip then row._ggApplicantChip:Hide() end
    return
  end
  local summary = self:LFG_BuildApplicantSummary(appID)
  local chip = EnsureApplicantChip(row)
  if not chip then return end
  if not summary then chip:Hide(); return end
  chip:SetText(FormatApplicantChip(summary))
  if summary.leavers and summary.leavers > 0 then
    chip:SetTextColor(1.0, 0.46, 0.30, 0.95)
  else
    chip:SetTextColor(0.82, 0.82, 0.82, 0.95)
  end
  chip:Show()
end

function addon:LFG_AppendApplicantSummaryTooltip(row)
  if not (self.db and self.db.lfg_tooltips and self.db.applicant_summary_tooltips) then return end
  if not row or not GameTooltip then return end
  local appID = GetApplicantIDFromRow(row)
  if not appID then return end
  local summary = self:LFG_BuildApplicantSummary(appID)
  if not summary then return end

  if GameTooltip:GetOwner() ~= row then GameTooltip:SetOwner(row, "ANCHOR_RIGHT") end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("|cffd33b2f" .. self:Tr("APPLICANT_SUMMARY_TITLE") .. "|r")
  GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_COMP", summary.roles.TANK or 0, summary.roles.HEALER or 0, summary.roles.DAMAGER or 0), 0.95, 0.88, 0.62, true)
  if summary.bestItemLevel and summary.bestItemLevel > 0 then
    GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_ILVL", summary.bestItemLevel), 0.82, 0.82, 0.82, true)
  end
  if summary.bestScore and summary.bestScore > 0 then
    GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_SCORE", summary.bestScore), 0.35, 0.90, 1.0, true)
  end
  if summary.leavers and summary.leavers > 0 then
    GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_LEAVER", summary.leavers), 1.0, 0.46, 0.30, true)
  end
  if type(summary.specIDs) == "table" and #summary.specIDs > 0 and IsShiftKeyDown and IsShiftKeyDown() then
    GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_SPECS") .. ": " .. table.concat(summary.specIDs, ", "), 0.78, 0.90, 1.0, true)
  elseif type(summary.specIDs) == "table" and #summary.specIDs > 0 then
    GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_SHIFT"), 0.56, 0.56, 0.56, true)
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
  for _, row in ipairs(rows) do
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
  local total, members, tanks, heals, dps, leavers = 0, 0, 0, 0, 0, 0
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
      end
    end
  end
  print((self.printPrefix or "GroupGuard LFG:"), self:Tr("APPLICANT_STATS_FMT", total, members, tanks, heals, dps, leavers))
end

function addon:LFG_InitApplicantEnhancements()
  if self._ggApplicantEnhancementsHooked then return end
  self._ggApplicantEnhancementsHooked = true
  local function schedule()
    if addon and addon.RunDebounced then
      addon:RunDebounced("applicant_chips", 0.05, function() if addon.LFG_RefreshApplicantChips then addon:LFG_RefreshApplicantChips() end end)
    elseif C_Timer and C_Timer.After then
      C_Timer.After(0.05, function() if addon and addon.LFG_RefreshApplicantChips then addon:LFG_RefreshApplicantChips() end end)
    elseif addon and addon.LFG_RefreshApplicantChips then
      addon:LFG_RefreshApplicantChips()
    end
  end

  local viewer = LFGListFrame and LFGListFrame.ApplicationViewer
  local sb = viewer and viewer.ScrollBox
  if sb and not sb._ggApplicantEnhancementHooked then
    sb._ggApplicantEnhancementHooked = true
    if sb.FullUpdate then hooksecurefunc(sb, "FullUpdate", schedule) end
    if sb.Update then hooksecurefunc(sb, "Update", schedule) end
    if sb.Refresh then hooksecurefunc(sb, "Refresh", schedule) end
  end
  if type(LFGListApplicationViewer_UpdateApplicants) == "function" then hooksecurefunc("LFGListApplicationViewer_UpdateApplicants", schedule) end
  if type(LFGListApplicationViewer_UpdateInfo) == "function" then hooksecurefunc("LFGListApplicationViewer_UpdateInfo", schedule) end
  if type(LFGListApplicationViewer_UpdateResults) == "function" then hooksecurefunc("LFGListApplicationViewer_UpdateResults", schedule) end
  schedule()
end

SLASH_GROUPGUARDLFGAPPS1 = "/ggapps"
SlashCmdList.GROUPGUARDLFGAPPS = function()
  if addon and addon.LFG_PrintApplicantStats then addon:LFG_PrintApplicantStats() end
end
