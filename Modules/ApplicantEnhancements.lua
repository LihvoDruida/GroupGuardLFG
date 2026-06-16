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
    if not ok or secret then return false end
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
  if addon and addon.LFG_API_GetApplicantInfo then
    return addon:LFG_API_GetApplicantInfo(applicantID)
  end
  return nil
end

local function GetApplicantsSafe()
  if addon and addon.LFG_API_GetApplicants then
    return addon:LFG_API_GetApplicants()
  end
  return {}
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
  local m = addon and addon.LFG_API_GetApplicantMemberInfo and addon:LFG_API_GetApplicantMemberInfo(applicantID, index) or nil
  if type(m) ~= "table" then return nil end

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
  if addon and addon.SafeEnumerateScrollBoxFrames then return addon:SafeEnumerateScrollBoxFrames(sb) end
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
  local cached = SafeNumber(frame._ggLastApplicantID, nil)
  if cached then return cached end

  local direct = SafeNumber(frame.applicantID or frame.applicantId or frame.ApplicantID or frame.id or frame.ID, nil)
  if direct then return direct end

  if frame.GetParent then
    local okParent, parent = pcall(frame.GetParent, frame)
    if okParent and parent then
      local parentID = SafeNumber(parent.applicantID or parent.applicantId or parent.ApplicantID or parent._ggLastApplicantID, nil)
      if parentID then return parentID end
    end
  end

  if frame.GetElementData then
    local ok, ed = pcall(frame.GetElementData, frame)
    if ok then
      local id = ResolveApplicantIDFromElementData(ed)
      if id then return id end
    end
  end

  -- Last-resort visible-row fallback: it is only used after all direct Blizzard fields fail.
  -- It is immediately revalidated by GetApplicantInfoSafe before any UI is shown.
  local rows = EnumerateApplicantRows()
  local apps = GetApplicantsSafe()
  if rows and apps and #apps > 0 then
    for index, row in ipairs(rows) do
      if row == frame then
        local id = SafeNumber(apps[index], nil)
        if id and GetApplicantInfoSafe(id) then return id end
      end
    end
  end
  return nil
end

local function GetApplicantHostFrame(frame, applicantID)
  if not frame then return nil end
  applicantID = SafeNumber(applicantID, nil)
  if frame.Members or SafeNumber(frame.applicantID or frame._ggLastApplicantID, nil) == applicantID then return frame end
  if frame.GetParent then
    local ok, parent = pcall(frame.GetParent, frame)
    if ok and parent and (parent.Members or SafeNumber(parent.applicantID or parent._ggLastApplicantID, nil) == applicantID) then
      return parent
    end
  end
  return frame
end

local function HookApplicantTooltipFrame(frame)
  if not frame or not frame.HookScript or frame._ggApplicantTooltipHooked then return end
  frame._ggApplicantTooltipHooked = true
  pcall(frame.HookScript, frame, "OnEnter", function(f) if addon and addon.LFG_AppendApplicantSummaryTooltip then addon:LFG_AppendApplicantSummaryTooltip(f) end end)
  pcall(frame.HookScript, frame, "OnLeave", function(f) if GameTooltip and GameTooltip:GetOwner() == f then GameTooltip:Hide() end end)
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

local function LayoutApplicantCard(frame, card)
  if not frame or not card then return end
  card:ClearAllPoints()
  local width = 0
  if frame.GetWidth then
    local ok, w = pcall(frame.GetWidth, frame)
    if ok and type(w) == "number" then width = w end
  end
  if width >= 520 then
    card:SetPoint("LEFT", frame, "LEFT", 168, 0)
    card:SetPoint("RIGHT", frame, "RIGHT", -104, 0)
  elseif width >= 360 then
    card:SetPoint("LEFT", frame, "LEFT", 8, 0)
    card:SetPoint("RIGHT", frame, "RIGHT", -78, 0)
  else
    card:SetPoint("LEFT", frame, "LEFT", 4, 0)
    card:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
  end
  card:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)
end

local function EnsureApplicantCard(frame)
  if not frame or not frame.CreateFontString then return nil end
  if not frame._ggApplicantCard then
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local card = CreateFrame("Frame", nil, frame, template)
    card:SetHeight(31)
    if card.EnableMouse then card:EnableMouse(false) end
    local strata = "MEDIUM"
    if type(frame.GetFrameStrata) == "function" then
      local okStrata, frameStrata = pcall(frame.GetFrameStrata, frame)
      if okStrata and frameStrata then strata = frameStrata end
    end
    if card.SetFrameStrata then card:SetFrameStrata(strata) end
    if type(frame.GetFrameLevel) == "function" and card.SetFrameLevel then
      local okLevel, level = pcall(frame.GetFrameLevel, frame)
      card:SetFrameLevel(((okLevel and type(level) == "number") and level or 1) + 8)
    end
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

    if card.SetClipsChildren then card:SetClipsChildren(true) end
    card:Hide()
    frame._ggApplicantCard = card
  end
  return frame._ggApplicantCard
end

local function HookApplicantMemberFrame(frame)
  if not frame then return end
  HookApplicantTooltipFrame(frame)
  if frame._ggApplicantCardHooked then return end
  frame._ggApplicantCardHooked = true
  if frame.HookScript then
    pcall(frame.HookScript, frame, "OnHide", HideApplicantCard)
    pcall(frame.HookScript, frame, "OnShow", function(f)
      HideApplicantCard(f)
      if f._ggLastApplicantID and f._ggLastMemberIdx and addon and addon.LFG_ShowApplicantCard then
        addon:LFG_ShowApplicantCard(f, f._ggLastApplicantID, f._ggLastMemberIdx)
      end
    end)
  end
end

function addon:LFG_ShowApplicantCard(memberFrame, applicantID, memberIdx)
  if not memberFrame then return end
  HookApplicantMemberFrame(memberFrame)
  if not (self.db and (self.db.applicant_cards_enabled ~= false)) then
    HideApplicantCard(memberFrame)
    return
  end
  if memberFrame.IsShown and not memberFrame:IsShown() then return end
  applicantID = SafeNumber(applicantID, nil) or GetApplicantIDFromRow(memberFrame)
  memberIdx = SafeNumber(memberIdx, memberFrame.memberIdx or 1) or 1
  if not applicantID then return end

  memberFrame._ggLastApplicantID = applicantID
  memberFrame._ggLastMemberIdx = memberIdx

  local hostFrame = GetApplicantHostFrame(memberFrame, applicantID)
  if not hostFrame then return end
  HookApplicantMemberFrame(hostFrame)
  hostFrame._ggLastApplicantID = applicantID
  hostFrame._ggLastMemberIdx = 1

  -- One full two-line card per application. If Blizzard sends member #2 first,
  -- draw only when the parent does not already have a valid visible card.
  if memberIdx ~= 1 and memberIdx ~= 0 then
    local existing = hostFrame._ggApplicantCard
    if existing and existing:IsShown() and existing._ggOwnerApplicantID == applicantID then return end
  end

  local summary = self:LFG_BuildApplicantSummary(applicantID)
  if not summary then return end
  local card = EnsureApplicantCard(hostFrame)
  if not card then return end
  local line1, line2 = FormatApplicantCardLines(self, summary)
  card._ggOwnerApplicantID = applicantID
  card._ggOwnerMemberIdx = memberIdx
  LayoutApplicantCard(hostFrame, card)
  card.Line1:SetText(ClampText(line1, 170))
  card.Line2:SetText(ClampText(line2, 190))
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
    if row then
      HookApplicantMemberFrame(row)
      local appID = GetApplicantIDFromRow(row)
      if appID then
        row._ggLastApplicantID = appID
        if self.LFG_ShowApplicantCard then self:LFG_ShowApplicantCard(row, appID, 1) end
        if type(row.Members) == "table" then
          for memberIdx, memberFrame in pairs(row.Members) do
            if type(memberFrame) == "table" then
              memberFrame._ggLastApplicantID = appID
              memberFrame._ggLastMemberIdx = SafeNumber(memberFrame.memberIdx, memberIdx) or memberIdx
              HookApplicantMemberFrame(memberFrame)
            end
          end
        end
      end
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
    local function onFramesChanged(frames)
      if addon and addon.LFG_HideApplicantDecorations then addon:LFG_HideApplicantDecorations() end
      for _, frame in ipairs(frames or {}) do HookApplicantMemberFrame(frame) end
      schedule()
    end
    if addon.SafeObserveScrollBox then
      addon:SafeObserveScrollBox(sb, "applicant_cards", onFramesChanged, hideThenSchedule)
    else
      if sb.HookScript then sb:HookScript("OnMouseWheel", hideThenSchedule) end
      if sb.FullUpdate then hooksecurefunc(sb, "FullUpdate", hideThenSchedule) end
      if sb.Update then hooksecurefunc(sb, "Update", hideThenSchedule) end
      if sb.Refresh then hooksecurefunc(sb, "Refresh", hideThenSchedule) end
    end
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
  if type(LFGListApplicationViewer_UpdateApplicant) == "function" and not self._ggHookedUpdateApplicant then
    self._ggHookedUpdateApplicant = true
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicant", function(applicantFrame, applicantID)
      if not addon or not applicantFrame then return end
      applicantID = SafeNumber(applicantID, nil) or GetApplicantIDFromRow(applicantFrame)
      if applicantID then
        applicantFrame._ggLastApplicantID = applicantID
        HookApplicantMemberFrame(applicantFrame)
        if addon.LFG_ShowApplicantCard then addon:LFG_ShowApplicantCard(applicantFrame, applicantID, 1) end
        if type(applicantFrame.Members) == "table" then
          for memberIdx, memberFrame in pairs(applicantFrame.Members) do
            if type(memberFrame) == "table" then
              memberFrame._ggLastApplicantID = applicantID
              memberFrame._ggLastMemberIdx = SafeNumber(memberFrame.memberIdx, memberIdx) or memberIdx
              HookApplicantMemberFrame(memberFrame)
            end
          end
        end
      end
    end)
  end
  if type(LFGListApplicationViewer_UpdateApplicantMember) == "function" and not self._ggHookedUpdateApplicantMember then
    self._ggHookedUpdateApplicantMember = true
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", function(memberFrame, applicantID, memberIdx)
      if not addon then return end
      addon._ggApplicantMemberFrames = addon._ggApplicantMemberFrames or {}
      if memberFrame then
        addon._ggApplicantMemberFrames[memberFrame] = true
        memberFrame._ggLastApplicantID = SafeNumber(applicantID, nil) or memberFrame._ggLastApplicantID
        memberFrame._ggLastMemberIdx = SafeNumber(memberIdx, memberFrame.memberIdx or 1) or 1
        HookApplicantMemberFrame(memberFrame)
      end
      if addon.LFG_ShowApplicantCard then addon:LFG_ShowApplicantCard(memberFrame, applicantID, memberIdx) end
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
