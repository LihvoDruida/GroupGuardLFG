-- GroupGuard LFG — Modules / Applicant Enhancements
-- Two-line applicant cards and diagnostics. Reads only Blizzard LFG data and uses safe hooks only.
local addonName, addon = ...

local C_Timer = C_Timer
local string_format = string.format
local table_concat = table.concat
local math_floor = math.floor

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

local function ClampText(text, limit)
  text = SafeText(text) or ""
  limit = limit or 96
  if #text > limit then return text:sub(1, limit - 1) .. "…" end
  return text
end

local function FormatNumberCompact(n)
  n = SafeNumber(n, 0) or 0
  if n >= 1000 then return string_format("%.1fk", n / 1000) end
  return string_format("%.0f", n)
end

local function FormatRoleCounts(self, roles)
  roles = roles or {}
  return self:Tr("APPLICANT_CARD_ROLES", roles.TANK or 0, roles.HEALER or 0, roles.DAMAGER or 0)
end

local function LocalizeStatus(self, status)
  status = SafeText(status)
  if not status or status == "" then return nil end
  local key = "APPLICATION_STATUS_" .. status:upper():gsub("[^A-Z0-9]", "_")
  local translated = self:Tr(key)
  if translated ~= key then return translated end
  return status
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
  return SafeText(values[3]) or SafeText(values[2])
end

local function ColorizeClass(classFile, text)
  text = text or classFile or "?"
  classFile = SafeText(classFile)
  if not classFile then return text end
  classFile = classFile:upper()
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if not c then return text end
  local r = math_floor(((c.r or 1) * 255) + 0.5)
  local g = math_floor(((c.g or 1) * 255) + 0.5)
  local b = math_floor(((c.b or 1) * 255) + 0.5)
  return string_format("|cff%02x%02x%02x%s|r", r, g, b, text)
end

local function GetApplicantInfoSafe(applicantID)
  applicantID = SafeNumber(applicantID, nil)
  if not (C_LFGList and C_LFGList.GetApplicantInfo and applicantID) then return nil end
  local values = { pcall(C_LFGList.GetApplicantInfo, applicantID) }
  if not values[1] then return nil end

  if type(values[2]) == "table" then
    local t = values[2]
    return {
      applicantID = SafeNumber(t.applicantID or t.id or applicantID, applicantID),
      applicationStatus = SafeText(t.applicationStatus or t.status),
      pendingApplicationStatus = SafeText(t.pendingApplicationStatus),
      numMembers = SafeNumber(t.numMembers or t.memberCount or t.numApplicants, nil),
      isNew = SafeBool(t.isNew),
      comment = SafeText(t.comment),
      displayOrderID = SafeNumber(t.displayOrderID or t.displayOrderId, nil),
      raw = t,
    }
  end

  -- Older/fallback API shape:
  -- applicantID, applicationStatus, pendingApplicationStatus, numMembers, isNew, comment, displayOrderID
  local info = {
    applicantID = SafeNumber(values[2], applicantID) or applicantID,
    applicationStatus = SafeText(values[3]),
    pendingApplicationStatus = SafeText(values[4]),
    numMembers = SafeNumber(values[5], nil),
    isNew = SafeBool(values[6]),
    comment = SafeText(values[7]),
    displayOrderID = SafeNumber(values[8], nil),
  }

  -- Defensive fallback for clients/addons that proxy the API in a different order.
  if not info.numMembers then
    for i = 2, #values do
      local n = SafeNumber(values[i], nil)
      if n and n >= 1 and n <= 5 then info.numMembers = n break end
    end
  end
  if not info.applicationStatus then
    for i = 2, #values do
      local s = SafeText(values[i])
      if s == "applied" or s == "invited" or s == "inviteaccepted" or s == "invitedeclined" or s == "cancelled" or s == "declined" or s == "declined_full" or s == "timedout" then
        info.applicationStatus = s
        break
      end
    end
  end
  return info
end

local function GetApplicantsSafe()
  if not (C_LFGList and C_LFGList.GetApplicants) then return {} end
  local values = { pcall(C_LFGList.GetApplicants) }
  if not values[1] then return {} end
  if type(values[2]) == "table" then return values[2] end
  local out = {}
  for i = 2, #values do
    local n = SafeNumber(values[i], nil)
    if n then out[#out + 1] = n end
  end
  return out
end

local function ReadApplicantDungeonListingScore(applicantID, memberIndex)
  if not (C_LFGList and C_LFGList.GetApplicantDungeonScoreForListing and C_LFGList.GetActiveEntryInfo) then return nil end
  local okEntry, entry = pcall(C_LFGList.GetActiveEntryInfo)
  if not okEntry or type(entry) ~= "table" or type(entry.activityIDs) ~= "table" then return nil end
  local best
  for _, activityID in ipairs(entry.activityIDs) do
    local ok, scoreInfo = pcall(C_LFGList.GetApplicantDungeonScoreForListing, applicantID, memberIndex, activityID)
    if ok and type(scoreInfo) == "table" then
      local runLevel = SafeNumber(scoreInfo.bestRunLevel, 0) or 0
      local mapScore = SafeNumber(scoreInfo.mapScore, 0) or 0
      if runLevel > 0 or mapScore > 0 then
        if not best or runLevel > (best.bestRunLevel or 0) or mapScore > (best.mapScore or 0) then
          best = {
            mapScore = mapScore,
            bestRunLevel = runLevel,
            finishedSuccess = SafeBool(scoreInfo.finishedSuccess),
            bestLevelIncrement = SafeNumber(scoreInfo.bestLevelIncrement, 0) or 0,
          }
        end
      end
    end
  end
  return best
end

local function ReadApplicantMember(applicantID, index)
  if not (C_LFGList and C_LFGList.GetApplicantMemberInfo and applicantID and index ~= nil) then return nil end
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
    -- Retail positional shape:
    -- name, classFilename, localizedClass, level, itemLevel, honorLevel,
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
  if not m.name then return nil end
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
  m.listingScore = ReadApplicantDungeonListingScore(applicantID, index)
  return m
end

local function ResolveApplicantIDFromElementData(ed)
  if type(ed) ~= "table" then return nil end
  local direct = SafeNumber(ed.applicantID or ed.applicantId or ed.ApplicantID or ed.id or ed.ID, nil)
  if direct then return direct end
  local nested = ed.applicantInfo or ed.applicationInfo or ed.info or ed.data or ed.elementData
  if type(nested) == "table" then
    return ResolveApplicantIDFromElementData(nested)
  end
  return nil
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

local function GetApplicantIDFromRow(frame)
  if not frame then return nil end
  if frame.GetElementData then
    local ok, ed = pcall(frame.GetElementData, frame)
    if ok then
      local id = ResolveApplicantIDFromElementData(ed)
      if id then return id end
    end
  end
  local direct = SafeNumber(frame.applicantID or frame.applicantId or frame.ApplicantID or frame.id or frame.ID, nil)
  if direct then return direct end

  -- Last-resort ScrollBox fallback: bind visible row order to C_LFGList.GetApplicants().
  local rows = EnumerateApplicantRows()
  local apps = GetApplicantsSafe()
  if rows and apps then
    for index, row in ipairs(rows) do
      if row == frame then return SafeNumber(apps[index], nil) end
    end
  end
  return nil
end

function addon:LFG_BuildApplicantSummary(applicantID)
  applicantID = SafeNumber(applicantID, nil)
  if not applicantID then return nil end
  local info = GetApplicantInfoSafe(applicantID)
  if not info then return nil end
  local num = SafeNumber(info.numMembers, 1) or 1
  if num < 1 then num = 1 elseif num > 5 then num = 5 end

  local roles = { TANK = 0, HEALER = 0, DAMAGER = 0, NONE = 0 }
  local bestScore, bestItemLevel, bestPvpItemLevel = 0, 0, 0
  local bestRunLevel, bestRunIncrement, bestRunTimed = 0, 0, false
  local itemLevelTotal, itemLevelCount = 0, 0
  local leavers = 0
  local minLevel, maxLevel = nil, nil
  local names, memberLines, specIDs, members = {}, {}, {}, {}
  local relationships = {}

  local function addMember(m)
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
    if type(m.listingScore) == "table" then
      local run = SafeNumber(m.listingScore.bestRunLevel, 0) or 0
      if run > bestRunLevel then
        bestRunLevel = run
        bestRunIncrement = SafeNumber(m.listingScore.bestLevelIncrement, 0) or 0
        bestRunTimed = SafeBool(m.listingScore.finishedSuccess)
      end
    end
  end

  for i = 1, num do
    local m = ReadApplicantMember(applicantID, i)
    if type(m) == "table" then addMember(m) end
  end
  -- Some third-party wrappers/older clients have been seen using 0-based member indices.
  if #members == 0 and num > 0 then
    for i = 0, num - 1 do
      local m = ReadApplicantMember(applicantID, i)
      if type(m) == "table" then addMember(m) end
    end
  end

  for _, m in ipairs(members) do
    local label = m.name or "?"
    local specOrClass = m.specName or m.localizedClass or m.classFilename
    if specOrClass and specOrClass ~= "" then label = label .. " " .. specOrClass end
    local roleShort = ROLE_SHORT[m.assignedRole or "NONE"] or "-"
    label = label .. " " .. roleShort
    if m.itemLevel and m.itemLevel > 0 then label = label .. " " .. string_format("%.0f", m.itemLevel) end
    if m.dungeonScore and m.dungeonScore > 0 then label = label .. " M+" .. FormatNumberCompact(m.dungeonScore) end
    if m.isLeaver then label = label .. " ⚠" end
    memberLines[#memberLines + 1] = label
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
    bestRunLevel = bestRunLevel,
    bestRunIncrement = bestRunIncrement,
    bestRunTimed = bestRunTimed,
    itemLevelCount = itemLevelCount,
    leavers = leavers,
    minLevel = minLevel,
    maxLevel = maxLevel,
    names = names,
    memberLines = memberLines,
    specIDs = specIDs,
    members = members,
    relationships = relationships,
    comment = SafeText(info.comment),
    status = SafeText(info.applicationStatus or info.status),
    pendingStatus = SafeText(info.pendingApplicationStatus),
    displayOrderID = SafeNumber(info.displayOrderID, nil),
  }
end

local function FormatLevel(summary, self)
  if summary.minLevel and summary.maxLevel then
    if summary.minLevel == summary.maxLevel then return self:Tr("APPLICANT_CARD_LEVEL", summary.maxLevel) end
    return self:Tr("APPLICANT_CARD_LEVEL_RANGE", summary.minLevel, summary.maxLevel)
  end
  return nil
end

local function FormatRun(summary, self)
  if not summary.bestRunLevel or summary.bestRunLevel <= 0 then return nil end
  local prefix = ""
  for i = 1, math.min(summary.bestRunIncrement or 0, 3) do prefix = prefix .. "+" end
  if prefix ~= "" then prefix = prefix .. " " end
  if summary.bestRunTimed then
    return self:Tr("APPLICANT_CARD_BEST_RUN_TIMED", prefix, summary.bestRunLevel)
  end
  return self:Tr("APPLICANT_CARD_BEST_RUN", prefix, summary.bestRunLevel)
end

local function FormatApplicantCardLines(self, summary)
  if not summary then return "", "" end
  local first = {}
  first[#first + 1] = self:Tr("APPLICANT_CARD_MEMBERS", summary.loadedMembers or 0, summary.numMembers or 0)
  first[#first + 1] = FormatRoleCounts(self, summary.roles)
  if summary.bestItemLevel and summary.bestItemLevel > 0 then first[#first + 1] = self:Tr("APPLICANT_CARD_ILVL", summary.bestItemLevel, summary.avgItemLevel or 0) end
  if summary.bestPvpItemLevel and summary.bestPvpItemLevel > 0 then first[#first + 1] = self:Tr("APPLICANT_CARD_PVP", summary.bestPvpItemLevel) end
  if summary.bestScore and summary.bestScore > 0 then first[#first + 1] = self:Tr("APPLICANT_CARD_SCORE", summary.bestScore) end
  local run = FormatRun(summary, self)
  if run then first[#first + 1] = run end
  local level = FormatLevel(summary, self)
  if level then first[#first + 1] = level end
  if summary.status and summary.status ~= "" then first[#first + 1] = self:Tr("APPLICANT_CARD_STATUS", LocalizeStatus(self, summary.status) or summary.status) end
  if summary.leavers and summary.leavers > 0 then first[#first + 1] = self:Tr("APPLICANT_CARD_LEAVER", summary.leavers) end

  local second = {}
  if #summary.memberLines > 0 then second[#second + 1] = table_concat(summary.memberLines, ", ") end
  if summary.comment and summary.comment ~= "" then second[#second + 1] = self:Tr("APPLICANT_CARD_COMMENT", ClampText(summary.comment, 90)) end
  if #second == 0 then second[#second + 1] = self:Tr("APPLICANT_CARD_NO_MEMBER_DATA") end
  return table_concat(first, "  •  "), table_concat(second, "  •  ")
end

local function HideApplicantCard(frame)
  if frame and frame._ggApplicantCard then
    frame._ggApplicantCard._ggOwnerApplicantID = nil
    frame._ggApplicantCard._ggOwnerMemberIdx = nil
    frame._ggApplicantCard.Line1:SetText("")
    frame._ggApplicantCard.Line2:SetText("")
    frame._ggApplicantCard:Hide()
  end
end

local function ApplyCardBackdrop(card)
  if card.SetBackdrop then
    card:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    card:SetBackdropColor(0.03, 0.035, 0.045, 0.78)
    card:SetBackdropBorderColor(0.82, 0.18, 0.16, 0.62)
  end
end

local function EnsureApplicantCard(frame)
  if not frame or not frame.CreateFontString then return nil end
  if not frame._ggApplicantCard then
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local card = CreateFrame("Frame", nil, frame, template)
    card:SetHeight(31)
    card:SetPoint("LEFT", frame, "LEFT", 4, 0)
    card:SetPoint("RIGHT", frame, "RIGHT", -104, 0)
    card:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)
    card:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
    if frame.GetFrameLevel and card.SetFrameLevel then card:SetFrameLevel((frame:GetFrameLevel() or 1) + 8) end
    ApplyCardBackdrop(card)

    card.Accent = card:CreateTexture(nil, "ARTWORK")
    card.Accent:SetTexture("Interface\\Buttons\\WHITE8X8")
    card.Accent:SetPoint("LEFT", card, "LEFT", 0, 0)
    card.Accent:SetSize(3, 27)
    card.Accent:SetColorTexture(0.82, 0.18, 0.16, 0.95)

    card.Line1 = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.Line1:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -3)
    card.Line1:SetPoint("RIGHT", card, "RIGHT", -4, 0)
    card.Line1:SetJustifyH("LEFT")
    card.Line1:SetTextColor(1.0, 0.87, 0.50, 1)
    if card.Line1.SetWordWrap then card.Line1:SetWordWrap(false) end
    if card.Line1.SetNonSpaceWrap then card.Line1:SetNonSpaceWrap(false) end

    card.Line2 = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.Line2:SetPoint("TOPLEFT", card.Line1, "BOTTOMLEFT", 0, -1)
    card.Line2:SetPoint("RIGHT", card, "RIGHT", -4, 0)
    card.Line2:SetJustifyH("LEFT")
    card.Line2:SetTextColor(0.80, 0.86, 0.92, 1)
    if card.Line2.SetWordWrap then card.Line2:SetWordWrap(false) end
    if card.Line2.SetNonSpaceWrap then card.Line2:SetNonSpaceWrap(false) end

    card:Hide()
    frame._ggApplicantCard = card
  end
  return frame._ggApplicantCard
end

local function HookApplicantMemberFrame(frame)
  if not frame or frame._ggApplicantCardHooked then return end
  frame._ggApplicantCardHooked = true
  if frame.HookScript then
    frame:HookScript("OnHide", HideApplicantCard)
    frame:HookScript("OnShow", function(f)
      HideApplicantCard(f)
      if f._ggLastApplicantID and f._ggLastMemberIdx and addon and addon.LFG_ShowApplicantCard then
        addon:LFG_ShowApplicantCard(f, f._ggLastApplicantID, f._ggLastMemberIdx)
      end
    end)
  end
end

function addon:LFG_ShowApplicantCard(memberFrame, applicantID, memberIdx)
  if not memberFrame then return end
  HideApplicantCard(memberFrame)
  HookApplicantMemberFrame(memberFrame)
  if not (self.db and self.db.applicant_summary_chips) then return end
  if memberFrame.IsShown and not memberFrame:IsShown() then return end
  applicantID = SafeNumber(applicantID, nil)
  memberIdx = SafeNumber(memberIdx, 1) or 1
  if not applicantID then return end

  memberFrame._ggLastApplicantID = applicantID
  memberFrame._ggLastMemberIdx = memberIdx

  -- Show one full two-line card per application, not on every member row.
  if memberIdx ~= 1 and memberIdx ~= 0 then return end

  local summary = self:LFG_BuildApplicantSummary(applicantID)
  if not summary then return end
  local card = EnsureApplicantCard(memberFrame)
  if not card then return end
  local line1, line2 = FormatApplicantCardLines(self, summary)
  card._ggOwnerApplicantID = applicantID
  card._ggOwnerMemberIdx = memberIdx
  card.Line1:SetText(ClampText(line1, 150))
  card.Line2:SetText(ClampText(line2, 170))
  if summary.leavers and summary.leavers > 0 then
    if card.SetBackdropBorderColor then card:SetBackdropBorderColor(1.0, 0.42, 0.18, 0.82) end
    card.Accent:SetColorTexture(1.0, 0.42, 0.18, 1)
  else
    if card.SetBackdropBorderColor then card:SetBackdropBorderColor(0.82, 0.18, 0.16, 0.62) end
    card.Accent:SetColorTexture(0.82, 0.18, 0.16, 0.95)
  end
  card:Show()
end

function addon:LFG_UpdateApplicantChip(row)
  -- Backward-compatible entry point used by EventBus. Prefer UpdateApplicantMember hook when available.
  if not row then return end
  HideApplicantCard(row)
  local appID = GetApplicantIDFromRow(row)
  if appID then self:LFG_ShowApplicantCard(row, appID, 1) end
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
  if type(m.listingScore) == "table" and (m.listingScore.bestRunLevel or 0) > 0 then
    parts[#parts + 1] = self:Tr("APPLICANT_MEMBER_BEST_RUN", m.listingScore.bestRunLevel)
  end
  if m.isLeaver then parts[#parts + 1] = self:Tr("APPLICANT_MEMBER_LEAVER") end
  return name .. " — " .. table_concat(parts, " • ")
end

local function FormatRelationships(summary)
  local out = {}
  for relation, count in pairs(summary.relationships or {}) do out[#out + 1] = tostring(relation) .. " x" .. tostring(count) end
  return #out > 0 and table_concat(out, ", ") or nil
end

function addon:LFG_AppendApplicantSummaryTooltip(row)
  if not (self.db and self.db.lfg_tooltips and self.db.applicant_summary_tooltips) then return end
  if not row or not GameTooltip then return end
  local appID = SafeNumber(row._ggLastApplicantID, nil) or GetApplicantIDFromRow(row)
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
  if summary.status and summary.status ~= "" then GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_STATUS", LocalizeStatus(self, summary.status) or summary.status), 0.82, 0.82, 0.82, true) end
  if summary.pendingStatus and summary.pendingStatus ~= "" then GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_PENDING_STATUS", LocalizeStatus(self, summary.pendingStatus) or summary.pendingStatus), 0.82, 0.82, 0.82, true) end
  GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_COMP", summary.roles.TANK or 0, summary.roles.HEALER or 0, summary.roles.DAMAGER or 0), 0.95, 0.88, 0.62, true)
  GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_MEMBERS", summary.loadedMembers or 0, summary.numMembers or 0), 0.82, 0.82, 0.82, true)
  if summary.bestItemLevel and summary.bestItemLevel > 0 then GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_ILVL", summary.bestItemLevel, summary.avgItemLevel or 0), 0.82, 0.82, 0.82, true) end
  if summary.bestPvpItemLevel and summary.bestPvpItemLevel > 0 then GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_PVP_ILVL", summary.bestPvpItemLevel), 0.82, 0.82, 0.82, true) end
  if summary.bestScore and summary.bestScore > 0 then GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_SCORE", summary.bestScore), 0.35, 0.90, 1.0, true) end
  if summary.bestRunLevel and summary.bestRunLevel > 0 then GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_BEST_RUN", summary.bestRunLevel), 0.35, 0.90, 1.0, true) end
  if summary.minLevel and summary.maxLevel then
    if summary.minLevel == summary.maxLevel then GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_LEVEL", summary.maxLevel), 0.82, 0.82, 0.82, true)
    else GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_LEVEL_RANGE", summary.minLevel, summary.maxLevel), 0.82, 0.82, 0.82, true) end
  end
  if summary.leavers and summary.leavers > 0 then GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_LEAVER", summary.leavers), 1.0, 0.46, 0.30, true) end
  local rel = FormatRelationships(summary)
  if rel then GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_RELATIONSHIPS", rel), 0.56, 0.86, 1.0, true) end
  if summary.comment and summary.comment ~= "" then GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_COMMENT", summary.comment), 0.86, 0.82, 0.72, true) end
  if type(summary.members) == "table" and #summary.members > 0 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(self:Tr("APPLICANT_SUMMARY_MEMBERS_TITLE"), 1.0, 0.82, 0.36, true)
    for i = 1, #summary.members do GameTooltip:AddLine("• " .. MemberDisplayLine(self, summary.members[i]), 0.78, 0.90, 1.0, true) end
  elseif type(summary.specIDs) == "table" and #summary.specIDs > 0 then
    GameTooltip:AddLine("• " .. self:Tr("APPLICANT_SUMMARY_SPECS") .. ": " .. table_concat(summary.specIDs, ", "), 0.78, 0.90, 1.0, true)
  end
  GameTooltip:Show()
end

function addon:LFG_RefreshApplicantChips()
  local rows = EnumerateApplicantRows()
  if not rows then return end
  self._ggApplicantRows = self._ggApplicantRows or {}
  for index, row in ipairs(rows) do
    self._ggApplicantRows[row] = true
    if row and row.HookScript and not row._ggApplicantSummaryTooltipHooked then
      row._ggApplicantSummaryTooltipHooked = true
      row:HookScript("OnHide", HideApplicantCard)
      row:HookScript("OnShow", function(frame) HideApplicantCard(frame) end)
      row:HookScript("OnEnter", function(frame) if addon and addon.LFG_AppendApplicantSummaryTooltip then addon:LFG_AppendApplicantSummaryTooltip(frame) end end)
      row:HookScript("OnLeave", function(frame) if GameTooltip and GameTooltip:GetOwner() == frame then GameTooltip:Hide() end end)
    end
    -- Only use visible-row fallback when the authoritative UpdateApplicantMember hook has not filled it.
    if row and not row._ggLastApplicantID then
      local appID = GetApplicantIDFromRow(row)
      if appID and self.LFG_ShowApplicantCard then self:LFG_ShowApplicantCard(row, appID, 1) end
    end
  end
end

function addon:LFG_HideApplicantDecorations()
  if self._ggApplicantRows then
    for row in pairs(self._ggApplicantRows) do HideApplicantCard(row) end
  end
  if self._ggApplicantMemberFrames then
    for frame in pairs(self._ggApplicantMemberFrames) do HideApplicantCard(frame) end
  end
end

function addon:LFG_RefreshApplicantsAfterDone(applicantID)
  if not (self.db and self.db.applicant_auto_refresh_done) then return end
  if not applicantID or not (C_LFGList and C_LFGList.GetApplicantInfo and C_LFGList.RefreshApplicants) then return end
  local info = GetApplicantInfoSafe(applicantID)
  local status = info and SafeText(info.applicationStatus)
  if status and APPLICATION_DONE[status] then
    if C_Timer and C_Timer.After then C_Timer.After(0.08, function() if C_LFGList and C_LFGList.RefreshApplicants then pcall(C_LFGList.RefreshApplicants) end end)
    else pcall(C_LFGList.RefreshApplicants) end
  end
end

function addon:LFG_PrintApplicantStats()
  local applicants = GetApplicantsSafe()
  if #applicants == 0 then
    print((self.printPrefix or "GroupGuard LFG:"), self:Tr("APPLICANT_STATS_NO_ROWS"))
    return
  end
  local total, members, tanks, heals, dps, leavers, bestIlvl, bestScore = 0, 0, 0, 0, 0, 0, 0, 0
  for _, appID in ipairs(applicants) do
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
  print((self.printPrefix or "GroupGuard LFG:"), self:Tr("APPLICANT_STATS_FMT", total, members, tanks, heals, dps, leavers, bestIlvl, bestScore))
end

local function DumpValue(self, value)
  if not CanReadValue(value) then return self:Tr("DUMP_PROTECTED") end
  if type(value) == "table" then return self:Tr("DUMP_TABLE") end
  if type(value) == "boolean" then return value and self:Tr("DUMP_TRUE") or self:Tr("DUMP_FALSE") end
  if value == nil then return self:Tr("DUMP_NIL") end
  return ClampText(tostring(value), 80)
end

function addon:LFG_DumpApplicants()
  local prefix = self.printPrefix or "GroupGuard LFG:"
  local applicants = GetApplicantsSafe()
  print(prefix, self:Tr("APPLICANT_DUMP_HEADER", #applicants))
  if #applicants == 0 then return end
  for _, appID in ipairs(applicants) do
    local info = GetApplicantInfoSafe(appID)
    if info then
      print(prefix, self:Tr("APPLICANT_DUMP_APP", appID, DumpValue(self, info.applicationStatus), DumpValue(self, info.pendingApplicationStatus), DumpValue(self, info.numMembers), DumpValue(self, info.comment)))
      local num = SafeNumber(info.numMembers, 1) or 1
      if num < 1 then num = 1 elseif num > 5 then num = 5 end
      for i = 1, num do
        local m = ReadApplicantMember(appID, i)
        if m then
          print(prefix, self:Tr("APPLICANT_DUMP_MEMBER", i, DumpValue(self, m.name), DumpValue(self, m.assignedRole), DumpValue(self, m.specID), DumpValue(self, m.itemLevel), DumpValue(self, m.pvpItemLevel), DumpValue(self, m.dungeonScore), DumpValue(self, m.level), DumpValue(self, m.isLeaver)))
        else
          print(prefix, self:Tr("APPLICANT_DUMP_MEMBER_MISSING", i))
        end
      end
    else
      print(prefix, self:Tr("APPLICANT_DUMP_APP_MISSING", appID))
    end
  end
end

function addon:LFG_InitApplicantEnhancements()
  local function schedule()
    if addon and addon.RunDebounced then
      addon:RunDebounced("applicant_cards", 0.01, function() if addon.LFG_RefreshApplicantChips then addon:LFG_RefreshApplicantChips() end end)
    elseif C_Timer and C_Timer.After then
      C_Timer.After(0.01, function() if addon and addon.LFG_RefreshApplicantChips then addon:LFG_RefreshApplicantChips() end end)
    elseif addon and addon.LFG_RefreshApplicantChips then addon:LFG_RefreshApplicantChips() end
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
  if type(LFGListApplicationViewer_UpdateApplicants) == "function" and not self._ggHookedUpdateApplicants then
    self._ggHookedUpdateApplicants = true
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicants", hideThenSchedule)
  end
  if type(LFGListApplicationViewer_UpdateInfo) == "function" and not self._ggHookedUpdateInfo then
    self._ggHookedUpdateInfo = true
    hooksecurefunc("LFGListApplicationViewer_UpdateInfo", hideThenSchedule)
  end
  if type(LFGListApplicationViewer_UpdateResults) == "function" and not self._ggHookedUpdateResults then
    self._ggHookedUpdateResults = true
    hooksecurefunc("LFGListApplicationViewer_UpdateResults", hideThenSchedule)
  end
  if type(LFGListApplicationViewer_UpdateApplicantMember) == "function" and not self._ggHookedUpdateApplicantMember then
    self._ggHookedUpdateApplicantMember = true
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", function(memberFrame, applicantID, memberIdx)
      if not addon then return end
      addon._ggApplicantMemberFrames = addon._ggApplicantMemberFrames or {}
      if memberFrame then addon._ggApplicantMemberFrames[memberFrame] = true end
      if addon.LFG_ShowApplicantCard then addon:LFG_ShowApplicantCard(memberFrame, applicantID, memberIdx) end
      if memberFrame and memberFrame.HookScript and not memberFrame._ggApplicantTooltipHooked then
        memberFrame._ggApplicantTooltipHooked = true
        memberFrame:HookScript("OnEnter", function(frame) if addon and addon.LFG_AppendApplicantSummaryTooltip then addon:LFG_AppendApplicantSummaryTooltip(frame) end end)
        memberFrame:HookScript("OnLeave", function(frame) if GameTooltip and GameTooltip:GetOwner() == frame then GameTooltip:Hide() end end)
      end
    end)
  end
  schedule()
end

SLASH_GROUPGUARDLFGAPPS1 = "/ggapps"
SlashCmdList.GROUPGUARDLFGAPPS = function(msg)
  msg = SafeText(msg) or ""
  msg = msg:lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "dump" then
    if addon and addon.LFG_DumpApplicants then addon:LFG_DumpApplicants() end
  elseif addon and addon.LFG_PrintApplicantStats then
    addon:LFG_PrintApplicantStats()
  end
end
