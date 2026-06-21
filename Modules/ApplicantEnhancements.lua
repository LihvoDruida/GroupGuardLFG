-- GroupGuard LFG — Modules / Applicant Enhancements
-- Adds the compact GroupGuard applicant column while keeping the default applicant list intact.
local addonName, addon = ...

local C_Timer = C_Timer
local table_concat = table.concat
local math_floor = math.floor
local string_format = string.format

local ROLE_SHORT = { TANK = "T", HEALER = "H", DAMAGER = "DPS", NONE = "-" }
local APPLICATION_DONE = {
  cancelled = true,
  timedout = true,
  inviteaccepted = true,
  invitedeclined = true,
  declined = true,
  declined_full = true,
}

local GG_CONTEXT_COLUMN_WIDTH = 38
local GG_CONTEXT_HEADER_TEXT = "GG"
local GG_CONTEXT_EMPTY = ""

-- ActivityID -> Raider.IO raid id/difficulty.
-- Difficulty follows Raider.IO progress values: 1 normal, 2 heroic, 3 mythic.
-- Kept local and read-only; no dependency on GroupFinderRio internals.
local RAID_ACTIVITY_MAP = {
  [1189] = { id = 14030, difficulty = 1 }, [1190] = { id = 14030, difficulty = 2 }, [1191] = { id = 14030, difficulty = 3 },
  [1235] = { id = 14663, difficulty = 1 }, [1236] = { id = 14663, difficulty = 2 }, [1237] = { id = 14663, difficulty = 3 },
  [1251] = { id = 14643, difficulty = 1 }, [1252] = { id = 14643, difficulty = 2 }, [1253] = { id = 14643, difficulty = 3 },
  [1505] = { id = 14980, difficulty = 1 }, [1506] = { id = 14980, difficulty = 2 }, [1504] = { id = 14980, difficulty = 3 },
  [1601] = { id = 15522, difficulty = 1 }, [1600] = { id = 15522, difficulty = 2 }, [1602] = { id = 15522, difficulty = 3 },
  [1617] = { id = 16178, difficulty = 1 }, [1618] = { id = 16178, difficulty = 2 }, [1619] = { id = 16178, difficulty = 3 },
  [1772] = { id = 16340, difficulty = 1 }, [1773] = { id = 16340, difficulty = 2 }, [1774] = { id = 16340, difficulty = 3 },
  [1775] = { id = 16340, difficulty = 1 }, [1776] = { id = 16340, difficulty = 2 }, [1777] = { id = 16340, difficulty = 3 },
  [1778] = { id = 16340, difficulty = 1 }, [1779] = { id = 16340, difficulty = 2 }, [1780] = { id = 16340, difficulty = 3 },
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

local function GetActiveEntryInfoSafe()
  if addon and addon.LFG_API_GetActiveEntryInfo then
    return addon:LFG_API_GetActiveEntryInfo()
  end
  if not (C_LFGList and C_LFGList.GetActiveEntryInfo) then return nil end
  local ok, entry = pcall(C_LFGList.GetActiveEntryInfo)
  return (ok and type(entry) == "table") and entry or nil
end

local function GetActivityInfoSafe(activityID)
  if addon and addon.LFG_API_GetActivityInfoTable then
    return addon:LFG_API_GetActivityInfoTable(activityID)
  end
  if C_LFGList and C_LFGList.GetActivityInfoTable then
    local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
    if ok and type(info) == "table" then return info end
  end
  return nil
end

local function GetActiveActivityIDs()
  local entry = GetActiveEntryInfoSafe()
  if type(entry) ~= "table" then return {}, nil end
  local ids = {}
  if type(entry.activityIDs) == "table" then
    for _, activityID in ipairs(entry.activityIDs) do
      local id = SafeNumber(activityID, nil)
      if id then ids[#ids + 1] = id end
    end
  end
  local single = SafeNumber(entry.activityID or entry.activityId, nil)
  if single and #ids == 0 then ids[#ids + 1] = single end
  return ids, entry
end

local function IsRaidActivity(activityID, entry)
  activityID = SafeNumber(activityID, nil)
  if activityID and RAID_ACTIVITY_MAP[activityID] then return true end
  local info = activityID and GetActivityInfoSafe(activityID) or nil
  if type(info) == "table" and SafeBool(info.isCurrentRaidActivity) then return true end
  local cat = SafeNumber(entry and entry.categoryID, nil)
  return cat ~= nil and GROUP_FINDER_CATEGORY_ID_RAIDS ~= nil and cat == GROUP_FINDER_CATEGORY_ID_RAIDS
end

local function IsDungeonActivity(activityID, entry)
  local info = activityID and GetActivityInfoSafe(activityID) or nil
  if type(info) == "table" and SafeBool(info.isMythicPlusActivity) then return true end
  local cat = SafeNumber(entry and entry.categoryID, nil)
  return cat ~= nil and GROUP_FINDER_CATEGORY_ID_DUNGEONS ~= nil and cat == GROUP_FINDER_CATEGORY_ID_DUNGEONS
end

local function NormalizeDungeonScoreInfo(scoreInfo, activityID, source)
  if type(scoreInfo) ~= "table" then return nil end
  local runLevel = SafeNumber(scoreInfo.bestRunLevel or scoreInfo.level or scoreInfo.bestLevel, 0) or 0
  local mapScore = SafeNumber(scoreInfo.mapScore, 0) or 0
  if runLevel <= 0 and mapScore <= 0 then return nil end
  return {
    mapScore = mapScore,
    mapName = SafeText(scoreInfo.mapName),
    bestRunLevel = runLevel,
    finishedSuccess = SafeBool(scoreInfo.finishedSuccess or scoreInfo.wasTimed),
    bestLevelIncrement = SafeNumber(scoreInfo.bestLevelIncrement or scoreInfo.levelIncrement, 0) or 0,
    activityID = activityID,
    source = source or "blizzard",
  }
end

local function ReadApplicantBestDungeonScore(applicantID, memberIndex)
  if addon and addon.LFG_API_GetApplicantBestDungeonScore then
    return addon:LFG_API_GetApplicantBestDungeonScore(applicantID, memberIndex)
  end
  if not (C_LFGList and C_LFGList.GetApplicantBestDungeonScore) then return nil end
  local ok, result = pcall(C_LFGList.GetApplicantBestDungeonScore, applicantID, memberIndex)
  if ok then return NormalizeDungeonScoreInfo(result, nil, "blizzard-best") end
  return nil
end

local function ReadApplicantDungeonListingScore(applicantID, memberIndex)
  local activityIDs = GetActiveActivityIDs()
  local best

  -- Prefer the active listing value so the GG column stays relevant to the current group.
  for _, activityID in ipairs(activityIDs) do
    local scoreInfo
    if addon and addon.LFG_API_GetApplicantDungeonScoreForListing then
      scoreInfo = addon:LFG_API_GetApplicantDungeonScoreForListing(applicantID, memberIndex, activityID)
    elseif C_LFGList and C_LFGList.GetApplicantDungeonScoreForListing then
      local ok, result = pcall(C_LFGList.GetApplicantDungeonScoreForListing, applicantID, memberIndex, activityID)
      if ok then scoreInfo = NormalizeDungeonScoreInfo(result, activityID, "blizzard") end
    end
    scoreInfo = NormalizeDungeonScoreInfo(scoreInfo, activityID, "blizzard") or scoreInfo
    if type(scoreInfo) == "table" then
      local run = SafeNumber(scoreInfo.bestRunLevel, 0) or 0
      local mapScore = SafeNumber(scoreInfo.mapScore, 0) or 0
      if run > 0 or mapScore > 0 then
        if not best or run > (best.bestRunLevel or 0) or (run == (best.bestRunLevel or 0) and mapScore > (best.mapScore or 0)) then
          best = scoreInfo
        end
      end
    end
  end

  -- Fallback when the exact listing value is unavailable.
  if not best or (SafeNumber(best.bestRunLevel, 0) or 0) <= 0 then
    local fallback = NormalizeDungeonScoreInfo(ReadApplicantBestDungeonScore(applicantID, memberIndex), nil, "blizzard-best")
    if fallback then best = fallback end
  end

  return best
end

local function ReadApplicantMemberStats(applicantID, memberIndex)
  if not (C_LFGList and C_LFGList.GetApplicantMemberStats) then return nil end
  local ok, stats = pcall(C_LFGList.GetApplicantMemberStats, applicantID, memberIndex)
  if ok and type(stats) == "table" then return stats end
  return nil
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
  -- Expensive listing score and stats are read lazily only when the GG column needs them.
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

local function IsFontString(obj)
  return type(obj) == "table" and type(obj.GetText) == "function" and type(obj.SetText) == "function"
end

local function SafeGetText(fs)
  if not IsFontString(fs) then return nil end
  local ok, text = pcall(fs.GetText, fs)
  if ok then return SafeText(text) end
  return nil
end

local function SafeSetText(fs, text)
  if not IsFontString(fs) then return false end
  return pcall(fs.SetText, fs, text or "")
end

local function StripLegacySuffix(text)
  text = SafeText(text)
  if not text or text == "" then return text end
  local pos = text:find(" · ", 1, true)
  if pos then return text:sub(1, pos - 1) end
  return text
end

local function HideFontString(fs)
  if IsFontString(fs) then
    SafeSetText(fs, "")
    if type(fs.Hide) == "function" then pcall(fs.Hide, fs) end
  end
end

local function SafeSetSize(frame, width, height)
  if not frame or type(frame.SetSize) ~= "function" then return false end
  return pcall(frame.SetSize, frame, width, height)
end

local function SafeSetWidth(frame, width)
  if not frame or type(frame.SetWidth) ~= "function" then return false end
  return pcall(frame.SetWidth, frame, width)
end

local function SafeClearAllPoints(frame)
  if frame and type(frame.ClearAllPoints) == "function" then return pcall(frame.ClearAllPoints, frame) end
  return false
end

local function SafeSetPoint(frame, ...)
  if frame and type(frame.SetPoint) == "function" then return pcall(frame.SetPoint, frame, ...) end
  return false
end

local function SafeSetHeight(frame, height)
  if not frame or type(frame.SetHeight) ~= "function" then return false end
  return pcall(frame.SetHeight, frame, height)
end

local function SafeSetFrameLevel(frame, level)
  if not frame or type(frame.SetFrameLevel) ~= "function" then return false end
  return pcall(frame.SetFrameLevel, frame, level)
end

local function SafeGetFrameLevel(frame)
  if not frame or type(frame.GetFrameLevel) ~= "function" then return nil end
  local ok, value = pcall(frame.GetFrameLevel, frame)
  return (ok and type(value) == "number") and value or nil
end

local function SafeEnableMouse(frame, enabled)
  if frame and type(frame.EnableMouse) == "function" then pcall(frame.EnableMouse, frame, enabled and true or false) end
  if frame and type(frame.SetMouseClickEnabled) == "function" then pcall(frame.SetMouseClickEnabled, frame, enabled and true or false) end
  if frame and type(frame.SetMouseMotionEnabled) == "function" then pcall(frame.SetMouseMotionEnabled, frame, enabled and true or false) end
end

local function SafeSetBackdrop(frame, backdrop)
  if frame and type(frame.SetBackdrop) == "function" then return pcall(frame.SetBackdrop, frame, backdrop) end
  return false
end

local function SafeSetBackdropColor(frame, r, g, b, a)
  if frame and type(frame.SetBackdropColor) == "function" then pcall(frame.SetBackdropColor, frame, r, g, b, a) end
end

local function SafeSetBackdropBorderColor(frame, r, g, b, a)
  if frame and type(frame.SetBackdropBorderColor) == "function" then pcall(frame.SetBackdropBorderColor, frame, r, g, b, a) end
end

local function SafeCreateFrame(kind, name, parent, template)
  if type(CreateFrame) ~= "function" then return nil end
  local ok, frame = pcall(CreateFrame, kind or "Frame", name, parent, template)
  return ok and frame or nil
end

local FindItemLevelFontString

local function CanPositionObject(obj)
  return type(obj) == "table" and type(obj.GetLeft) == "function" and type(obj.GetRight) == "function"
end

local function SafeGetLeft(obj)
  if not CanPositionObject(obj) then return nil end
  local ok, value = pcall(obj.GetLeft, obj)
  return (ok and type(value) == "number") and value or nil
end

local function SafeGetRight(obj)
  if not CanPositionObject(obj) then return nil end
  local ok, value = pcall(obj.GetRight, obj)
  return (ok and type(value) == "number") and value or nil
end

local function SafeGetWidthValue(obj)
  if not obj or type(obj.GetWidth) ~= "function" then return nil end
  local ok, value = pcall(obj.GetWidth, obj)
  return (ok and type(value) == "number") and value or nil
end

local function SafeSetDrawLayer(region, layer, sublevel)
  if region and type(region.SetDrawLayer) == "function" then
    pcall(region.SetDrawLayer, region, layer, sublevel or 0)
  end
end

local function SafeShow(region)
  if region and type(region.Show) == "function" then pcall(region.Show, region) end
end

local function SafeGetObjectType(obj)
  if obj and type(obj.GetObjectType) == "function" then
    local ok, kind = pcall(obj.GetObjectType, obj)
    if ok then return kind end
  end
  return nil
end

local function IsLikelyRoleRegion(obj)
  if not CanPositionObject(obj) or IsFontString(obj) then return false end
  local kind = SafeGetObjectType(obj)
  if kind == "Texture" then return true end
  if type(obj.GetNormalTexture) == "function" or type(obj.GetTexture) == "function" then return true end
  return false
end

local function FindRoleRegion(frame)
  if not frame then return nil end
  local candidates = {
    frame.Role, frame.RoleIcon, frame.RoleTexture, frame.RoleIconTexture,
    frame.role, frame.roleIcon, frame.roleTexture, frame.Icon, frame.IconTexture,
  }
  for _, obj in ipairs(candidates) do
    if IsLikelyRoleRegion(obj) then return obj end
  end

  local ilvl = FindItemLevelFontString(frame)
  local ilvlLeft = SafeGetLeft(ilvl)
  local frameLeft = SafeGetLeft(frame)
  local best, bestRight
  local function consider(obj)
    if not IsLikelyRoleRegion(obj) then return end
    local left, right = SafeGetLeft(obj), SafeGetRight(obj)
    local width = SafeGetWidthValue(obj)
    if not left or not right or not width or width < 8 or width > 32 then return end
    if ilvlLeft and right >= ilvlLeft then return end
    if frameLeft and left < frameLeft then return end
    if not bestRight or right > bestRight then
      best, bestRight = obj, right
    end
  end

  if type(frame.GetRegions) == "function" then
    local ok, regions = pcall(function() return { frame:GetRegions() } end)
    if ok then
      for _, region in ipairs(regions) do consider(region) end
    end
  end
  if type(frame.GetChildren) == "function" then
    local ok, children = pcall(function() return { frame:GetChildren() } end)
    if ok then
      for _, child in ipairs(children) do consider(child) end
    end
  end
  return best
end

local function FindNumericFontString(frame, minValue, maxValue, preferSmall)
  if not frame or type(frame.GetRegions) ~= "function" then return nil end
  local ok, regions = pcall(function() return { frame:GetRegions() } end)
  if not ok or type(regions) ~= "table" then return nil end
  local best
  for _, region in ipairs(regions) do
    if IsFontString(region) then
      local text = SafeGetText(region)
      local n = text and tonumber((text:gsub("[^%d]", ""))) or nil
      if n and n >= minValue and n <= maxValue then
        if not best then best = region end
        if preferSmall then return region end
      end
    end
  end
  return best
end

FindItemLevelFontString = function(frame)
  if not frame then return nil end
  local candidates = {
    frame.ItemLevel, frame.ItemLevelText, frame.Ilvl, frame.iLvl, frame.ILvl,
    frame.ItemLevelFontString, frame.PlayerItemLevel, frame.PlayerItemLevelText,
  }
  for _, fs in ipairs(candidates) do
    if IsFontString(fs) then return fs end
  end
  -- Item level is normally a 2-3 digit value, while M+ rating is usually four digits.
  return FindNumericFontString(frame, 1, 999, true)
end

local function FindRatingFontString(frame)
  if not frame then return nil end
  local candidates = { frame.Rating, frame.RatingText, frame.Score, frame.ScoreText, frame.DungeonScore, frame.DungeonScoreText }
  for _, fs in ipairs(candidates) do
    if IsFontString(fs) then return fs end
  end
  return FindNumericFontString(frame, 1000, 9999, true)
end

local function FindHeaderFontStringByText(parent, texts)
  if not parent then return nil end
  local wanted = {}
  for _, text in pairs(texts or {}) do
    if text and text ~= "" then wanted[text:lower()] = true end
  end
  local function checkObject(obj)
    if IsFontString(obj) then
      local text = SafeGetText(obj)
      if text and wanted[text:lower()] then return obj end
    end
    if type(obj) == "table" and type(obj.GetText) == "function" then
      local ok, text = pcall(obj.GetText, obj)
      text = ok and SafeText(text) or nil
      if text and wanted[text:lower()] then return obj end
    end
    if type(obj) == "table" and type(obj.GetRegions) == "function" then
      local ok, regions = pcall(function() return { obj:GetRegions() } end)
      if ok then
        for _, region in ipairs(regions) do
          local found = checkObject(region)
          if found then return found end
        end
      end
    end
    return nil
  end
  local found = checkObject(parent)
  if found then return found end
  if type(parent.GetChildren) == "function" then
    local ok, children = pcall(function() return { parent:GetChildren() } end)
    if ok then
      for _, child in ipairs(children) do
        found = checkObject(child)
        if found then return found end
      end
    end
  end
  return nil
end

local function GetHeaderOwner(fs)
  if not fs then return nil end
  if type(fs.GetObjectType) == "function" then
    local ok, kind = pcall(fs.GetObjectType, fs)
    if ok and kind ~= "FontString" then return fs end
  end
  if type(fs.GetParent) == "function" then
    local ok, parent = pcall(fs.GetParent, fs)
    if ok then return parent end
  end
  return nil
end

local function HideApplicantContextHeader(viewer)
  viewer = viewer or (LFGListFrame and LFGListFrame.ApplicationViewer)
  if not viewer then return end
  if viewer._ggContextHeader and type(viewer._ggContextHeader.Hide) == "function" then pcall(viewer._ggContextHeader.Hide, viewer._ggContextHeader) end
  if viewer._ggContextHeaderFrame and type(viewer._ggContextHeaderFrame.Hide) == "function" then pcall(viewer._ggContextHeaderFrame.Hide, viewer._ggContextHeaderFrame) end
end

local function StyleApplicantContextHeaderFrame(frame, templateUsed)
  if not frame then return end
  SafeEnableMouse(frame, false)
  -- Prefer the native column style when available.
  if not templateUsed then
    SafeSetBackdrop(frame, {
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 8,
      edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    SafeSetBackdropColor(frame, 0.07, 0.07, 0.07, 0.88)
    SafeSetBackdropBorderColor(frame, 0.42, 0.42, 0.42, 0.95)
  end
end

local function EnsureApplicantContextHeaderFrame(viewer)
  if not viewer then return nil end
  local frame = viewer._ggContextHeaderFrame
  if frame then return frame end

  local templates = { "LFGListApplicationViewerColumnHeaderTemplate", "LFGListColumnHeaderButtonTemplate", "LFGListColumnHeaderTemplate", "WhoFrameColumnHeaderTemplate", "ColumnHeaderButtonTemplate", "ColumnHeaderTemplate", "BackdropTemplate" }
  local templateUsed = nil
  for _, template in ipairs(templates) do
    frame = SafeCreateFrame("Button", nil, viewer, template)
    if frame then
      templateUsed = template ~= "BackdropTemplate" and template or nil
      break
    end
  end
  if not frame then
    frame = SafeCreateFrame("Button", nil, viewer, nil)
  end
  if not frame then return nil end

  viewer._ggContextHeaderFrame = frame
  StyleApplicantContextHeaderFrame(frame, templateUsed)
  SafeSetSize(frame, GG_CONTEXT_COLUMN_WIDTH, 20)
  local baseLevel = SafeGetFrameLevel(viewer) or 1
  SafeSetFrameLevel(frame, baseLevel + 8)

  local label = IsFontString(frame.Text) and frame.Text or nil
  if not label and type(frame.GetFontString) == "function" then
    local ok, fontString = pcall(frame.GetFontString, frame)
    if ok and IsFontString(fontString) then label = fontString end
  end
  if not label and type(frame.CreateFontString) == "function" then
    local ok, created = pcall(frame.CreateFontString, frame, nil, "OVERLAY", "GameFontNormalSmall")
    if ok then label = created end
  end
  if label then
    viewer._ggContextHeader = label
    if type(label.SetJustifyH) == "function" then pcall(label.SetJustifyH, label, "CENTER") end
    if type(label.SetJustifyV) == "function" then pcall(label.SetJustifyV, label, "MIDDLE") end
    if type(label.SetTextColor) == "function" then pcall(label.SetTextColor, label, 1.0, 0.82, 0.0) end
    SafeSetDrawLayer(label, "OVERLAY", 7)
    SafeClearAllPoints(label)
    SafeSetPoint(label, "CENTER", frame, "CENTER", 0, 0)
  end

  return frame
end

local function SetHeaderText(header, owner, text)
  text = text or ""
  if IsFontString(header) then
    SafeSetText(header, text)
  elseif header and type(header.SetText) == "function" then
    pcall(header.SetText, header, text)
  end
  if owner then
    if owner.Text and IsFontString(owner.Text) then SafeSetText(owner.Text, text) end
    if owner.Label and IsFontString(owner.Label) then SafeSetText(owner.Label, text) end
    if type(owner.SetText) == "function" then pcall(owner.SetText, owner, text) end
  end
end

local function GetHeaderHeight(owner, fallback)
  if owner and type(owner.GetHeight) == "function" then
    local ok, h = pcall(owner.GetHeight, owner)
    if ok and type(h) == "number" and h > 0 then return h end
  end
  return fallback or 18
end

local function ReflowApplicantColumnHeaders(viewer, headerFrame)
  if not (viewer and headerFrame) then return false end

  local nameHeader = FindHeaderFontStringByText(viewer, { NAME, "Name", "Ім'я", "Ім’я" })
  local roleHeader = FindHeaderFontStringByText(viewer, { ROLE, "Role", "Роль", "R" })
  local ilvlHeader = FindHeaderFontStringByText(viewer, { ITEM_LEVEL_ABBR, "iLvl", "ilvl", "ILvl", "Item Level" })
  local ratingHeader = FindHeaderFontStringByText(viewer, { RATING, "Rating", "Рейтинг" })

  local nameOwner = GetHeaderOwner(nameHeader)
  local roleOwner = GetHeaderOwner(roleHeader)
  local ilvlOwner = GetHeaderOwner(ilvlHeader)
  local ratingOwner = GetHeaderOwner(ratingHeader)
  if nameOwner == viewer then nameOwner = nil end
  if roleOwner == viewer then roleOwner = nil end
  if ilvlOwner == viewer then ilvlOwner = nil end
  if ratingOwner == viewer then ratingOwner = nil end
  if not (nameOwner and roleOwner and ilvlOwner) then return false end

  local roleWidth = 24
  local ggWidth = GG_CONTEXT_COLUMN_WIDTH
  local ilvlWidth = math.max(30, math.min(42, SafeGetWidthValue(ilvlOwner) or 36))
  local ratingWidth = ratingOwner and math.max(42, math.min(56, SafeGetWidthValue(ratingOwner) or 48)) or nil
  local headerHeight = GetHeaderHeight(ilvlOwner, GetHeaderHeight(roleOwner, 18))

  -- Preserve original stock sizes once, but intentionally reflow the visible grid so values follow headers.
  if not roleOwner._ggOriginalWidth then roleOwner._ggOriginalWidth = SafeGetWidthValue(roleOwner) end
  if not ilvlOwner._ggOriginalWidth then ilvlOwner._ggOriginalWidth = SafeGetWidthValue(ilvlOwner) end
  if ratingOwner and not ratingOwner._ggOriginalWidth then ratingOwner._ggOriginalWidth = SafeGetWidthValue(ratingOwner) end

  SetHeaderText(roleHeader, roleOwner, "R")
  SafeSetWidth(roleOwner, roleWidth)
  SafeSetWidth(ilvlOwner, ilvlWidth)
  if ratingOwner and ratingWidth then SafeSetWidth(ratingOwner, ratingWidth) end

  SafeClearAllPoints(roleOwner)
  SafeSetPoint(roleOwner, "LEFT", nameOwner, "RIGHT", 0, 0)

  SafeSetSize(headerFrame, ggWidth, headerHeight)
  SafeClearAllPoints(headerFrame)
  SafeSetPoint(headerFrame, "LEFT", roleOwner, "RIGHT", 0, 0)

  SafeClearAllPoints(ilvlOwner)
  SafeSetPoint(ilvlOwner, "LEFT", headerFrame, "RIGHT", 0, 0)

  if ratingOwner then
    SafeClearAllPoints(ratingOwner)
    SafeSetPoint(ratingOwner, "LEFT", ilvlOwner, "RIGHT", 0, 0)
  end

  viewer._ggApplicantColumnLayout = {
    nameOwner = nameOwner,
    roleOwner = roleOwner,
    ggOwner = headerFrame,
    ilvlOwner = ilvlOwner,
    ratingOwner = ratingOwner,
  }
  return true
end

local function PositionRegionUnderHeader(region, row, headerOwner)
  if not (region and row and headerOwner) then return false end
  local rowLeft = SafeGetLeft(row)
  local headerLeft, headerRight = SafeGetLeft(headerOwner), SafeGetRight(headerOwner)
  if not (rowLeft and headerLeft and headerRight) then return false end
  SafeClearAllPoints(region)
  SafeSetPoint(region, "CENTER", row, "LEFT", ((headerLeft + headerRight) / 2) - rowLeft, 0)
  return true
end

local function PositionFontStringUnderHeader(fs, row, headerOwner, padding)
  if not (IsFontString(fs) and row and headerOwner) then return false end
  local rowLeft = SafeGetLeft(row)
  local headerLeft, headerRight = SafeGetLeft(headerOwner), SafeGetRight(headerOwner)
  if not (rowLeft and headerLeft and headerRight) then return false end
  padding = padding or 2
  SafeClearAllPoints(fs)
  SafeSetPoint(fs, "LEFT", row, "LEFT", headerLeft - rowLeft + padding, 0)
  SafeSetPoint(fs, "RIGHT", row, "LEFT", headerRight - rowLeft - padding, 0)
  if type(fs.SetJustifyH) == "function" then pcall(fs.SetJustifyH, fs, "CENTER") end
  return true
end

local function PositionApplicantRowColumns(row, contextFS)
  local viewer = LFGListFrame and LFGListFrame.ApplicationViewer
  local layout = viewer and viewer._ggApplicantColumnLayout
  if not (row and layout) then return false end

  local roleRegion = FindRoleRegion(row)
  local ilvl = FindItemLevelFontString(row)
  local rating = FindRatingFontString(row)

  if roleRegion and layout.roleOwner then PositionRegionUnderHeader(roleRegion, row, layout.roleOwner) end
  if IsFontString(contextFS) and layout.ggOwner then PositionFontStringUnderHeader(contextFS, row, layout.ggOwner, 2) end
  if ilvl and layout.ilvlOwner then PositionFontStringUnderHeader(ilvl, row, layout.ilvlOwner, 2) end
  if rating and layout.ratingOwner then PositionFontStringUnderHeader(rating, row, layout.ratingOwner, 2) end
  return true
end

local function EnsureApplicantContextHeader()
  local viewer = LFGListFrame and LFGListFrame.ApplicationViewer
  if not (viewer and addon and addon.db and addon.db.applicant_context_progress) then
    HideApplicantContextHeader(viewer)
    return
  end

  local headerFrame = EnsureApplicantContextHeaderFrame(viewer)
  if not headerFrame then return end
  local fs = viewer._ggContextHeader
  local label = (addon and addon.Tr and addon:Tr("APPLICANT_CONTEXT_COLUMN")) or GG_CONTEXT_HEADER_TEXT
  SafeSetText(fs, label)
  if headerFrame.Text and IsFontString(headerFrame.Text) then SafeSetText(headerFrame.Text, label) end
  if type(headerFrame.SetText) == "function" then pcall(headerFrame.SetText, headerFrame, label) end

  local now = (GetTime and GetTime()) or 0
  if viewer._ggApplicantColumnLayout and (viewer._ggHeaderReflowUntil or 0) > now then
    SafeShow(headerFrame)
    SafeShow(fs)
    return
  end

  if ReflowApplicantColumnHeaders(viewer, headerFrame) then
    viewer._ggHeaderReflowUntil = now + 0.25
    SafeShow(headerFrame)
    SafeShow(fs)
  else
    -- Wait until the applicant viewer has finished drawing its headers.
    HideApplicantContextHeader(viewer)
  end
end

local function EnsureRowContextColumn(frame)
  if not frame or not (addon and addon.db and addon.db.applicant_context_progress) then return nil end
  local fs = frame._ggContextColumnFS
  if not IsFontString(fs) then
    if type(frame.CreateFontString) ~= "function" then return nil end
    local ok, created = pcall(frame.CreateFontString, frame, nil, "OVERLAY", "GameFontNormalSmall")
    if not ok or not created then return nil end
    fs = created
    frame._ggContextColumnFS = fs
    if type(fs.SetJustifyH) == "function" then pcall(fs.SetJustifyH, fs, "CENTER") end
    if type(fs.SetTextColor) == "function" then pcall(fs.SetTextColor, fs, 1.0, 0.82, 0.0) end
    SafeSetDrawLayer(fs, "OVERLAY", 6)
  end

  if not PositionApplicantRowColumns(frame, fs) then
    -- Keep the value near iLvl until the header grid is measurable.
    SafeClearAllPoints(fs)
    local ilvl = FindItemLevelFontString(frame)
    if ilvl then
      SafeSetSize(fs, GG_CONTEXT_COLUMN_WIDTH, 14)
      SafeSetPoint(fs, "RIGHT", ilvl, "LEFT", -4, 0)
    else
      SafeSetSize(fs, GG_CONTEXT_COLUMN_WIDTH, 14)
      SafeSetPoint(fs, "RIGHT", frame, "RIGHT", -64, 0)
    end
  end
  return fs
end

local function CleanupLegacyApplicantDecorations(frame)
  if not frame then return end
  local detail = frame._ggApplicantDetailLine
  if IsFontString(detail) then HideFontString(detail) end
  frame._ggApplicantDetailLine = nil
  if IsFontString(frame._ggContextColumnFS) then HideFontString(frame._ggContextColumnFS) end
  if IsFontString(frame._ggStockNameFS) then
    local current = SafeGetText(frame._ggStockNameFS)
    local clean = StripLegacySuffix(current)
    if clean and current ~= clean then SafeSetText(frame._ggStockNameFS, clean) end
  end
  if IsFontString(frame._ggStockIlvlFS) then
    local current = SafeGetText(frame._ggStockIlvlFS)
    local clean = StripLegacySuffix(current)
    if clean and current ~= clean then SafeSetText(frame._ggStockIlvlFS, clean) end
  end
  -- Restore legacy 4.2.12 rating overrides once, then leave the stock Rating column alone.
  if frame._ggRatingOverridden and IsFontString(frame._ggStockRatingFS) then
    SafeSetText(frame._ggStockRatingFS, frame._ggOriginalRatingText or "")
  end
  frame._ggStockRatingFS = nil
  frame._ggOriginalRatingText = nil
  frame._ggRatingOverridden = nil
  frame._ggContextMetric = nil
  frame._ggMetricToken = nil
  frame._ggStockNameFS = nil
  frame._ggStockIlvlFS = nil
  frame._ggApplicantDetailParent = nil
  frame._ggApplicantDetailMembers = nil
  frame._ggOriginalHeights = nil
  frame._ggAppliedHeightExtras = nil
end

local function TooltipOwnerIs(frame)
  if not frame or not GameTooltip or type(GameTooltip.GetOwner) ~= "function" then return false end
  local ok, owner = pcall(GameTooltip.GetOwner, GameTooltip)
  return ok and owner == frame
end

local function TooltipHasGroupGuardSection()
  if not GameTooltip or type(GameTooltip.NumLines) ~= "function" then return false end
  local ok, count = pcall(GameTooltip.NumLines, GameTooltip)
  if not ok or type(count) ~= "number" then return false end
  for i = 1, count do
    local fs = _G and _G["GameTooltipTextLeft" .. i]
    if IsFontString(fs) then
      local text = SafeGetText(fs)
      if text and text:find("GroupGuard", 1, true) then return true end
    end
  end
  return false
end

local function AddTooltipLine(text, r, g, b)
  text = SafeText(text)
  if not text or text == "" or not GameTooltip then return end
  GameTooltip:AddLine(text, r or 0.86, g or 0.86, b or 0.86, true)
end

local function AddTooltipDoubleLine(left, right, lr, lg, lb, rr, rg, rb)
  left = SafeText(left)
  right = SafeText(right)
  if not left or left == "" or not right or right == "" or not GameTooltip or type(GameTooltip.AddDoubleLine) ~= "function" then return end
  GameTooltip:AddDoubleLine(left, right, lr or 0.86, lg or 0.86, lb or 0.86, rr or 1.0, rg or 0.82, rb or 0.36)
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
  local members = {}

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
    -- GG context runs are intentionally not calculated here; this summary is used by tooltips/stats.
  end

  for i = 1, num do
    local m = ReadApplicantMember(applicantID, i)
    if type(m) == "table" then addMember(m) end
  end
  if #members == 0 and num > 0 then
    for i = 0, num - 1 do
      local m = ReadApplicantMember(applicantID, i)
      if type(m) == "table" then addMember(m) end
    end
  end

  return {
    applicantID = applicantID,
    numMembers = num,
    loadedMembers = #members,
    roles = roles,
    bestScore = bestScore,
    bestItemLevel = bestItemLevel,
    avgItemLevel = itemLevelCount > 0 and (itemLevelTotal / itemLevelCount) or 0,
    bestPvpItemLevel = bestPvpItemLevel,
    bestRunLevel = bestRunLevel,
    bestRunIncrement = bestRunIncrement,
    bestRunTimed = bestRunTimed,
    itemLevelCount = itemLevelCount,
    leavers = leavers,
    minLevel = minLevel,
    maxLevel = maxLevel,
    members = members,
    comment = SafeText(info.comment),
    status = SafeText(info.applicationStatus or info.status),
    pendingStatus = SafeText(info.pendingApplicationStatus),
    displayOrderID = SafeNumber(info.displayOrderID, nil),
  }
end

local function GetApplicantMemberName(member)
  member = type(member) == "table" and member or nil
  return member and SafeText(member.name) or nil
end

local function NormalizeNameKey(text)
  text = SafeText(text)
  if not text then return nil end
  text = text:lower()
  text = text:gsub("%b()", " ")
  text = text:gsub("[%p%c]", " ")
  text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  text = text:gsub("normal", ""):gsub("heroic", ""):gsub("mythic", ""):gsub("raid finder", "")
  text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return text ~= "" and text or nil
end

local function DetectDifficultyFromText(text)
  text = SafeText(text)
  if not text then return nil end
  local lower = text:lower()
  if lower:find("mythic", 1, true) or lower:find("міф", 1, true) then return 3 end
  if lower:find("heroic", 1, true) or lower:find("гер", 1, true) then return 2 end
  if lower:find("normal", 1, true) or lower:find("норм", 1, true) then return 1 end
  return nil
end

local function GetActiveRaidContext()
  local activityIDs, entry = GetActiveActivityIDs()
  local context = { difficulty = nil, nameKey = nil, zone = nil }
  for _, activityID in ipairs(activityIDs) do
    local mapped = RAID_ACTIVITY_MAP[activityID]
    if mapped then
      context.zone = mapped
      context.difficulty = mapped.difficulty
      return context
    end
  end
  for _, activityID in ipairs(activityIDs) do
    local info = GetActivityInfoSafe(activityID)
    local text = info and (SafeText(info.fullName) or SafeText(info.shortName) or SafeText(info.name))
    if text then
      context.difficulty = context.difficulty or DetectDifficultyFromText(text)
      context.nameKey = context.nameKey or NormalizeNameKey(text)
    end
  end
  local title = entry and (SafeText(entry.name) or SafeText(entry.questName) or SafeText(entry.comment))
  if title then
    context.difficulty = context.difficulty or DetectDifficultyFromText(title)
    context.nameKey = context.nameKey or NormalizeNameKey(title)
  end
  return context
end

local function ReadRaiderIORaidProgress(member)
  if type(member) ~= "table" or not _G.RaiderIO or type(_G.RaiderIO.GetProfile) ~= "function" then return nil end
  local raidContext = GetActiveRaidContext()
  if type(raidContext) ~= "table" or (not raidContext.zone and not raidContext.nameKey) then return nil end

  local name = GetApplicantMemberName(member)
  if not name then return nil end
  local faction = SafeText(member.factionGroup)
  local ok, profile = pcall(_G.RaiderIO.GetProfile, name, faction)
  if not ok or type(profile) ~= "table" then return nil end
  local raidProfile = type(profile.raidProfile) == "table" and profile.raidProfile or nil
  local progressList = raidProfile and raidProfile.raidProgress
  if type(progressList) ~= "table" then return nil end

  local wantedID = raidContext.zone and SafeNumber(raidContext.zone.id, nil) or nil
  local wantedDifficulty = (raidContext.zone and SafeNumber(raidContext.zone.difficulty, nil)) or SafeNumber(raidContext.difficulty, nil)
  local wantedNameKey = raidContext.nameKey
  local bestMain, bestAny
  for _, raid in pairs(progressList) do
    local raidInfo = type(raid.raid) == "table" and raid.raid or nil
    local raidID = SafeNumber(raidInfo and raidInfo.id, nil)
    local raidNameKey = NormalizeNameKey(raidInfo and (raidInfo.name or raidInfo.shortName or raidInfo.slug))
    local idMatches = wantedID and raidID and raidID == wantedID
    local nameMatches = wantedNameKey and raidNameKey and (wantedNameKey == raidNameKey or wantedNameKey:find(raidNameKey, 1, true) or raidNameKey:find(wantedNameKey, 1, true))
    if idMatches or nameMatches then
      local total = SafeNumber(raidInfo and raidInfo.bossCount, nil)
      local kills = nil
      if type(raid.progress) == "table" then
        for _, diff in ipairs(raid.progress) do
          if wantedDifficulty and SafeNumber(diff and diff.difficulty, nil) == wantedDifficulty then
            kills = SafeNumber(diff.kills, 0) or 0
            break
          end
        end
        if kills == nil and not wantedDifficulty then
          local highest = raid.progress[#raid.progress]
          kills = SafeNumber(highest and highest.kills, nil)
        end
      end
      if total and total > 0 and kills ~= nil then
        local result = { text = string_format("%d/%d", kills, total), kills = kills, total = total, source = idMatches and "raiderio" or "raiderio-name", main = SafeBool(raid.isMainProgress) }
        bestAny = bestAny or result
        if result.main then bestMain = bestMain or result else return result end
      end
    end
  end
  return bestMain or bestAny
end

local function BuildApplicantContextMetric(applicantID, memberIdx)
  applicantID = SafeNumber(applicantID, nil)
  memberIdx = SafeNumber(memberIdx, 1) or 1
  if not applicantID then return nil end

  local activityIDs, entry = GetActiveActivityIDs()
  local member = ReadApplicantMember(applicantID, memberIdx)
  if not member and memberIdx ~= 1 then member = ReadApplicantMember(applicantID, 1) end
  if not member and memberIdx ~= 0 then member = ReadApplicantMember(applicantID, 0) end
  if not member then return nil end

  local raidMode = false
  local dungeonMode = false
  for _, activityID in ipairs(activityIDs) do
    if IsRaidActivity(activityID, entry) then raidMode = true end
    if IsDungeonActivity(activityID, entry) then dungeonMode = true end
  end

  if raidMode then
    local raidProgress = ReadRaiderIORaidProgress(member)
    if raidProgress and raidProgress.text then return raidProgress, member end
    return nil, member
  end

  if dungeonMode then
    local score = nil
    if not score then
      local tried = {}
      local candidates = { memberIdx, 1 }
      for _, idx in ipairs(candidates) do
        idx = SafeNumber(idx, nil)
        if idx ~= nil and not tried[idx] then
          tried[idx] = true
          score = ReadApplicantDungeonListingScore(applicantID, idx)
          if type(score) == "table" and (SafeNumber(score.bestRunLevel, 0) or 0) > 0 then break end
        end
      end
    end
    local run = type(score) == "table" and SafeNumber(score.bestRunLevel, 0) or 0
    if run and run > 0 then
      return { text = "+" .. tostring(math_floor(run)), level = run, source = "blizzard" }, member
    end
  end

  return nil, member
end


local function AddLeaverFlagToMetric(metric, applicantID, memberIdx, member)
  member = member or ReadApplicantMember(applicantID, memberIdx or 1)
  if not member and memberIdx ~= 1 then member = ReadApplicantMember(applicantID, 1) end
  if member and member.isLeaver then
    if metric and metric.text and metric.text ~= "" then
      metric.text = metric.text .. " ⚠"
      metric.leaver = true
      return metric
    end
    return { text = "⚠", source = "blizzard", leaver = true }
  end
  return metric
end

local function ApplyApplicantContextMetric(frame, applicantID, memberIdx)
  if not frame then return end
  EnsureApplicantContextHeader()
  local fs = EnsureRowContextColumn(frame)
  if not fs then return end
  -- Re-run after the row value exists so header and values share one grid.
  EnsureApplicantContextHeader()
  HideFontString(fs)
  if not (addon and addon.db and addon.db.applicant_context_progress) then return end

  -- Keep the normal Rating column unchanged.
  if frame._ggRatingOverridden and IsFontString(frame._ggStockRatingFS) then
    SafeSetText(frame._ggStockRatingFS, frame._ggOriginalRatingText or "")
    frame._ggRatingOverridden = nil
  end

  applicantID = SafeNumber(applicantID, nil) or SafeNumber(frame._ggLastApplicantID, nil) or GetApplicantIDFromRow(frame)
  memberIdx = SafeNumber(memberIdx, nil) or SafeNumber(frame._ggLastMemberIdx, nil) or SafeNumber(frame.memberIdx, nil) or 1
  local metric, member = BuildApplicantContextMetric(applicantID, memberIdx)
  metric = AddLeaverFlagToMetric(metric, applicantID, memberIdx, member)
  if not metric or not metric.text or metric.text == "" then return nil end

  frame._ggContextMetric = metric
  SafeSetText(fs, metric.text)
  if metric.leaver and (metric.text == "⚠" or metric.text:find("⚠", 1, true)) then
    if type(fs.SetTextColor) == "function" then pcall(fs.SetTextColor, fs, 1.0, 0.36, 0.22) end
  else
    if type(fs.SetTextColor) == "function" then pcall(fs.SetTextColor, fs, 1.0, 0.82, 0.0) end
  end
  if type(fs.Show) == "function" then pcall(fs.Show, fs) end
  return metric
end

local function ScheduleApplicantContextMetric(frame, applicantID, memberIdx)
  if not frame then return end
  applicantID = SafeNumber(applicantID, nil) or SafeNumber(frame._ggLastApplicantID, nil)
  memberIdx = SafeNumber(memberIdx, nil) or SafeNumber(frame._ggLastMemberIdx, nil) or 1
  local metric = ApplyApplicantContextMetric(frame, applicantID, memberIdx)
  if metric and metric.text and metric.text ~= "" then return end

  -- One late pass is enough for Blizzard applicant data that arrives after the row update.
  frame._ggMetricToken = (frame._ggMetricToken or 0) + 1
  local token = frame._ggMetricToken
  if C_Timer and C_Timer.After then
    C_Timer.After(0.16, function()
      if frame._ggMetricToken == token then
        ApplyApplicantContextMetric(frame, applicantID, memberIdx)
      end
    end)
  end
end

local function BuildMinimalTooltipLines(self, summary)
  if type(summary) ~= "table" then return nil end
  local lines = {}
  local loaded = summary.loadedMembers or 0
  local total = summary.numMembers or loaded or 1
  local roles = summary.roles or {}

  if total > 1 or loaded > 1 then
    lines[#lines + 1] = self:Tr("APPLICANT_TOOLTIP_PARTY", roles.TANK or 0, roles.HEALER or 0, roles.DAMAGER or 0, loaded, total)
  end

  if (summary.leavers or 0) > 0 then
    lines[#lines + 1] = self:Tr("APPLICANT_TOOLTIP_LEAVER", summary.leavers or 0)
  end

  return #lines > 0 and lines or nil
end

local function RenderApplicantSummaryTooltip(self, row, appID)
  if not (self.db and self.db.lfg_tooltips and self.db.applicant_summary_tooltips) then return end
  if not row or not GameTooltip or not TooltipOwnerIs(row) then return end
  appID = SafeNumber(appID, nil) or SafeNumber(row._ggLastApplicantID, nil) or GetApplicantIDFromRow(row)
  if not appID then return end

  local shown = true
  if type(GameTooltip.IsShown) == "function" then
    local okShown, isShown = pcall(GameTooltip.IsShown, GameTooltip)
    shown = okShown and isShown or false
  end
  if not shown or TooltipHasGroupGuardSection() then return end

  local summary = self:LFG_BuildApplicantSummary(appID)
  local lines = BuildMinimalTooltipLines(self, summary)
  if not lines then return end

  GameTooltip:AddLine(" ")
  AddTooltipDoubleLine("GroupGuard", self:Tr("APPLICANT_TOOLTIP_SUPPLEMENT"), 1.0, 0.82, 0.36, 0.70, 0.70, 0.70)
  for _, line in ipairs(lines) do
    AddTooltipLine(line, 0.95, 0.88, 0.62)
  end
  GameTooltip:Show()
end

function addon:LFG_AppendApplicantSummaryTooltip(row, appID)
  RenderApplicantSummaryTooltip(self, row, appID)
end

function addon:LFG_RequestApplicantSummaryTooltip(row)
  if not row then return end
  local appID = SafeNumber(row._ggLastApplicantID, nil) or GetApplicantIDFromRow(row)
  if not appID then return end
  row._ggTooltipToken = {}
  local token = row._ggTooltipToken
  local function tryAppend()
    if row._ggTooltipToken == token and TooltipOwnerIs(row) then
      RenderApplicantSummaryTooltip(addon, row, appID)
    end
  end
  -- Wait briefly so other tooltip addons can finish first.
  if C_Timer and C_Timer.After then
    C_Timer.After(0.08, tryAppend)
  else
    tryAppend()
  end
end

local function HookApplicantTooltipFrame(frame)
  if not frame or not frame.HookScript or frame._ggApplicantTooltipHooked then return end
  frame._ggApplicantTooltipHooked = true
  pcall(frame.HookScript, frame, "OnEnter", function(f)
    if addon and addon.LFG_RequestApplicantSummaryTooltip then addon:LFG_RequestApplicantSummaryTooltip(f) end
  end)
  pcall(frame.HookScript, frame, "OnLeave", function(f)
    if f then f._ggTooltipToken = nil end
    -- Do not hide or clear GameTooltip here.
  end)
end

local function HookApplicantMemberFrame(frame)
  if not frame then return end
  CleanupLegacyApplicantDecorations(frame)
  HookApplicantTooltipFrame(frame)
  if frame._ggApplicantCleanHooked then return end
  frame._ggApplicantCleanHooked = true
  if frame.HookScript then
    pcall(frame.HookScript, frame, "OnHide", CleanupLegacyApplicantDecorations)
    pcall(frame.HookScript, frame, "OnShow", CleanupLegacyApplicantDecorations)
  end
end

function addon:LFG_ShowApplicantCard(memberFrame, applicantID, memberIdx)
  -- Compatibility entry point: no row replacement.
  if not memberFrame then return end
  memberFrame._ggLastApplicantID = SafeNumber(applicantID, nil) or memberFrame._ggLastApplicantID or GetApplicantIDFromRow(memberFrame)
  memberFrame._ggLastMemberIdx = SafeNumber(memberIdx, memberFrame.memberIdx or 1) or 1
  HookApplicantMemberFrame(memberFrame)
  ScheduleApplicantContextMetric(memberFrame, memberFrame._ggLastApplicantID, memberFrame._ggLastMemberIdx)
end

function addon:LFG_UpdateApplicantChip(row)
  if not row then return end
  CleanupLegacyApplicantDecorations(row)
  HookApplicantMemberFrame(row)
  local appID = GetApplicantIDFromRow(row)
  if appID then row._ggLastApplicantID = appID end
  if type(row.Members) == "table" then
    for memberIdx, memberFrame in pairs(row.Members) do
      if type(memberFrame) == "table" then
        memberFrame._ggLastApplicantID = appID or memberFrame._ggLastApplicantID
        memberFrame._ggLastMemberIdx = SafeNumber(memberFrame.memberIdx, memberIdx) or memberIdx
        HookApplicantMemberFrame(memberFrame)
        ScheduleApplicantContextMetric(memberFrame, memberFrame._ggLastApplicantID, memberFrame._ggLastMemberIdx)
      end
    end
  end
end

function addon:LFG_RefreshApplicantChips()
  local rows = EnumerateApplicantRows()
  if not rows then return end
  self._ggApplicantRows = self._ggApplicantRows or {}
  for _, row in ipairs(rows) do
    self._ggApplicantRows[row] = true
    self:LFG_UpdateApplicantChip(row)
  end
end

function addon:LFG_HideApplicantDecorations()
  if self._ggApplicantRows then
    for row in pairs(self._ggApplicantRows) do CleanupLegacyApplicantDecorations(row) end
  end
  if self._ggApplicantMemberFrames then
    for frame in pairs(self._ggApplicantMemberFrames) do CleanupLegacyApplicantDecorations(frame) end
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
      print(prefix, self:Tr("APPLICANT_DUMP_APP", appID, DumpValue(self, info.applicationStatus), DumpValue(self, info.numMembers), DumpValue(self, info.comment)))
      local num = SafeNumber(info.numMembers, 1) or 1
      if num < 1 then num = 1 elseif num > 5 then num = 5 end
      for i = 1, num do
        local m = ReadApplicantMember(appID, i)
        if m then
          local metric = BuildApplicantContextMetric(appID, i)
          local run = metric and metric.level or nil
          local memberLabel = m.specName or m.assignedRole or "-"
          print(prefix, self:Tr("APPLICANT_DUMP_MEMBER", i, DumpValue(self, m.name), DumpValue(self, memberLabel), DumpValue(self, m.itemLevel), DumpValue(self, m.dungeonScore), DumpValue(self, run), DumpValue(self, metric and metric.text), DumpValue(self, m.isLeaver)))
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
    EnsureApplicantContextHeader()
    if addon and addon.RunDebounced then
      addon:RunDebounced("applicant_minimal_hooks", 0.10, function() if addon.LFG_RefreshApplicantChips then addon:LFG_RefreshApplicantChips() end end)
    elseif C_Timer and C_Timer.After then
      C_Timer.After(0.10, function() if addon and addon.LFG_RefreshApplicantChips then addon:LFG_RefreshApplicantChips() end end)
    elseif addon and addon.LFG_RefreshApplicantChips then addon:LFG_RefreshApplicantChips() end
  end
  local function cleanupThenSchedule()
    if addon and addon.LFG_HideApplicantDecorations then addon:LFG_HideApplicantDecorations() end
    schedule()
  end

  local viewer = LFGListFrame and LFGListFrame.ApplicationViewer
  local sb = viewer and viewer.ScrollBox
  if sb and not sb._ggApplicantEnhancementHooked then
    sb._ggApplicantEnhancementHooked = true
    local function onFramesChanged(frames)
      for _, frame in ipairs(frames or {}) do HookApplicantMemberFrame(frame) end
      schedule()
    end
    if addon.SafeObserveScrollBox then
      addon:SafeObserveScrollBox(sb, "applicant_minimal_hooks", onFramesChanged, cleanupThenSchedule)
    else
      if sb.HookScript then sb:HookScript("OnMouseWheel", cleanupThenSchedule) end
      if sb.FullUpdate then hooksecurefunc(sb, "FullUpdate", cleanupThenSchedule) end
      if sb.Update then hooksecurefunc(sb, "Update", cleanupThenSchedule) end
      if sb.Refresh then hooksecurefunc(sb, "Refresh", cleanupThenSchedule) end
    end
  end
  if type(LFGListApplicationViewer_UpdateApplicants) == "function" and not self._ggHookedUpdateApplicants then
    self._ggHookedUpdateApplicants = true
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicants", cleanupThenSchedule)
  end
  if type(LFGListApplicationViewer_UpdateApplicant) == "function" and not self._ggHookedUpdateApplicant then
    self._ggHookedUpdateApplicant = true
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicant", function(applicantFrame, applicantID)
      if not addon or not applicantFrame then return end
      applicantID = SafeNumber(applicantID, nil) or GetApplicantIDFromRow(applicantFrame)
      if applicantID then applicantFrame._ggLastApplicantID = applicantID end
      HookApplicantMemberFrame(applicantFrame)
      if type(applicantFrame.Members) == "table" then
        for memberIdx, memberFrame in pairs(applicantFrame.Members) do
          if type(memberFrame) == "table" then
            memberFrame._ggLastApplicantID = applicantID or memberFrame._ggLastApplicantID
            memberFrame._ggLastMemberIdx = SafeNumber(memberFrame.memberIdx, memberIdx) or memberIdx
            HookApplicantMemberFrame(memberFrame)
            ScheduleApplicantContextMetric(memberFrame, memberFrame._ggLastApplicantID, memberFrame._ggLastMemberIdx)
          end
        end
      end
    end)
  end
  if type(LFGListApplicationViewer_UpdateApplicantMember) == "function" and not self._ggHookedUpdateApplicantMember then
    self._ggHookedUpdateApplicantMember = true
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", function(memberFrame, applicantID, memberIdx)
      if not addon or not memberFrame then return end
      addon._ggApplicantMemberFrames = addon._ggApplicantMemberFrames or {}
      addon._ggApplicantMemberFrames[memberFrame] = true
      memberFrame._ggLastApplicantID = SafeNumber(applicantID, nil) or memberFrame._ggLastApplicantID
      memberFrame._ggLastMemberIdx = SafeNumber(memberIdx, memberFrame.memberIdx or 1) or 1
      HookApplicantMemberFrame(memberFrame)
      ScheduleApplicantContextMetric(memberFrame, memberFrame._ggLastApplicantID, memberFrame._ggLastMemberIdx)
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
