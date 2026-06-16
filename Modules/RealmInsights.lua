-- GroupGuard LFG — Modules / Realm Insights
-- Optional technical realm-locale hints inspired by GroupfinderFlags, without replacing Blizzard/PGF UI.
local addonName, addon = ...

local C_Timer = C_Timer

local REGION_TO_DATASET = {
  [1] = "us", -- US / Americas
  [3] = "eu", -- Europe
}

local REALM_BADGE_COLORS = {
  german = {0.55, 0.78, 1.00},
  british = {0.62, 0.92, 1.00},
  portuguese = {0.45, 1.00, 0.58},
  russian = {1.00, 0.55, 0.45},
  french = {0.55, 0.68, 1.00},
  spanish = {1.00, 0.80, 0.35},
  italian = {0.48, 1.00, 0.68},
  american = {0.70, 0.86, 1.00},
  brazilian = {0.42, 1.00, 0.46},
  oceanic = {0.60, 0.78, 1.00},
  mexican = {1.00, 0.82, 0.42},
}

local REALM_BADGE_SHORT = {
  german = "DE",
  british = "EN",
  portuguese = "PT",
  russian = "RU",
  french = "FR",
  spanish = "ES",
  italian = "IT",
  american = "US",
  brazilian = "BR",
  oceanic = "OC",
  mexican = "LA",
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

local function SafeText(value)
  if value == nil or not CanReadValue(value) then return nil end
  if type(value) == "string" then return value end
  local ok, result = pcall(tostring, value)
  if ok then return result end
  return nil
end

local function NormalizeRealm(realm)
  realm = SafeText(realm)
  if not realm or realm == "" then return nil end
  realm = realm:gsub("[%s%-']", "")
  if string.lower then realm = realm:lower() end
  return realm
end

local function OwnRealm()
  local realm
  if GetNormalizedRealmName then
    local ok, value = pcall(GetNormalizedRealmName)
    if ok and value and value ~= "" then realm = value end
  end
  if not realm and GetRealmName then
    local ok, value = pcall(GetRealmName)
    if ok and value and value ~= "" then realm = value end
  end
  return realm
end

local function SplitNameRealm(fullName)
  fullName = SafeText(fullName)
  if not fullName or fullName == "" then return nil, nil end
  local name, realm
  if strsplit then
    name, realm = strsplit("-", fullName)
  else
    name, realm = fullName:match("^([^-]+)%-(.+)$")
    if not name then name = fullName end
  end
  if not realm or realm == "" then realm = OwnRealm() end
  return name, realm
end

local function ActiveDataset()
  if GetCurrentRegion then
    local ok, region = pcall(GetCurrentRegion)
    if ok and REGION_TO_DATASET[region] then return REGION_TO_DATASET[region] end
  end
  -- Try EU first because the addon is commonly used on EU, then US as fallback.
  return "eu"
end

local function GetLabels()
  local lang = addon.GetUILanguage and addon:GetUILanguage() or "enUS"
  local labels = addon.REALM_LOCALE_LABELS and (addon.REALM_LOCALE_LABELS[lang] or addon.REALM_LOCALE_LABELS.enUS)
  return labels or {}
end

function addon:GetRealmLocaleCode(realm)
  local key = NormalizeRealm(realm)
  if not key or not self.REALM_LOCALE_DATA then return nil end

  local primary = ActiveDataset()
  local data = self.REALM_LOCALE_DATA[primary]
  local code = data and data[key]
  if code then return code, primary end

  -- Fallback for cross-region copied names or uncertain private-server/Classic variants.
  for dataset, map in pairs(self.REALM_LOCALE_DATA) do
    if dataset ~= primary and map[key] then return map[key], dataset end
  end
  return nil
end

function addon:GetRealmLocaleLabel(realm)
  local code, dataset = self:GetRealmLocaleCode(realm)
  if not code then return nil end
  local labels = GetLabels()
  return labels[code] or code, code, dataset
end

function addon:GetRealmHintFromFullName(fullName)
  local _, realm = SplitNameRealm(fullName)
  if not realm then return nil end
  local label, code, dataset = self:GetRealmLocaleLabel(realm)
  if not label then return nil end
  return {
    realm = realm,
    label = label,
    code = code,
    dataset = dataset,
    short = REALM_BADGE_SHORT[code] or tostring(code):upper(),
  }
end

local function GetSearchResultLeaderRealm(resultID)
  if not (C_LFGList and C_LFGList.GetSearchResultInfo and resultID) then return nil end
  local ok, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
  if not ok or type(info) ~= "table" then return nil end
  local leaderName = SafeText(info.leaderName)
  local _, realm = SplitNameRealm(leaderName)
  return realm, leaderName
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

local function EnsureRealmBadge(row)
  if not row or not row.CreateFontString then return nil end
  if not row._ggRealmBadge then
    local badge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badge:SetJustifyH("RIGHT")
    badge:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -5)
    badge:SetTextColor(0.85, 0.85, 0.85, 0.95)
    if badge.SetWordWrap then badge:SetWordWrap(false) end
    if badge.SetNonSpaceWrap then badge:SetNonSpaceWrap(false) end
    row._ggRealmBadge = badge
  end
  return row._ggRealmBadge
end

local function HideRealmBadge(row)
  if row and row._ggRealmBadge then
    row._ggRealmBadge._ggOwnerResultID = nil
    row._ggRealmBadge:SetText("")
    row._ggRealmBadge:Hide()
  end
end

local function ScheduleRealmBadgeRefresh(row)
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      if not row or not addon or not addon.LFG_PaintRealmBadge then return end
      local rid = GetResultIDFromRow(row)
      addon:LFG_PaintRealmBadge(row, rid)
    end)
  elseif addon and addon.LFG_PaintRealmBadge then
    local rid = GetResultIDFromRow(row)
    addon:LFG_PaintRealmBadge(row, rid)
  end
end

local function HookRealmRow(row)
  if not row or row._ggRealmRecycleHooked then return end
  row._ggRealmRecycleHooked = true
  if row.HookScript then
    row:HookScript("OnHide", HideRealmBadge)
    row:HookScript("OnShow", function(frame)
      HideRealmBadge(frame)
      ScheduleRealmBadgeRefresh(frame)
    end)
  end
  if row.SetElementData and type(hooksecurefunc) == "function" then
    hooksecurefunc(row, "SetElementData", function(frame)
      HideRealmBadge(frame)
      ScheduleRealmBadgeRefresh(frame)
    end)
  end
end

function addon:LFG_PaintRealmBadge(row, resultID)
  if not row then return end
  HideRealmBadge(row)
  if not (self.db and self.db.realm_insights and self.db.realm_badges) then return end
  if row.IsShown and not row:IsShown() then return end
  if not resultID then return end
  local realm = GetSearchResultLeaderRealm(resultID)
  local hint = realm and self:GetRealmHintFromFullName("x-" .. realm) or nil
  if not hint then
    if row._ggRealmBadge then row._ggRealmBadge:Hide() end
    return
  end
  if self.db.realm_same_locale_only == false then
    -- show all known realms
  else
    local ownLabel, ownCode = self:GetRealmLocaleLabel(OwnRealm())
    if ownCode and ownCode == hint.code then
      if row._ggRealmBadge then row._ggRealmBadge:Hide() end
      return
    end
  end
  local badge = EnsureRealmBadge(row)
  if not badge then return end
  badge._ggOwnerResultID = resultID
  local c = REALM_BADGE_COLORS[hint.code]
  if c then badge:SetTextColor(c[1], c[2], c[3], 0.95) else badge:SetTextColor(0.85, 0.85, 0.85, 0.95) end
  badge:SetText("[" .. (hint.short or "RL") .. "]")
  badge:Show()
end

function addon:LFG_AppendRealmInsightTooltip(tooltip, resultID)
  if not (self.db and self.db.lfg_tooltips and self.db.realm_insights) then return end
  if not tooltip or not resultID then return end
  local now = GetTime and GetTime() or 0
  if tooltip._ggRealmResultID == resultID and (tooltip._ggRealmAddedAt or 0) + 0.05 > now then return end
  tooltip._ggRealmResultID = resultID
  tooltip._ggRealmAddedAt = now
  local realm, leaderName = GetSearchResultLeaderRealm(resultID)
  if not realm then return end
  local label, code = self:GetRealmLocaleLabel(realm)
  if not label then return end
  if self.db.realm_same_locale_only ~= false then
    local ownLabel, ownCode = self:GetRealmLocaleLabel(OwnRealm())
    if ownCode and ownCode == code then return end
  end
  tooltip:AddLine(" ")
  tooltip:AddLine("|cffd33b2f" .. self:Tr("REALM_INSIGHTS_TITLE") .. "|r")
  tooltip:AddLine("• " .. self:Tr("REALM_INSIGHTS_LEADER", realm, label), 0.82, 0.88, 1.0, true)
  tooltip:AddLine("• " .. self:Tr("REALM_INSIGHTS_NOTE"), 0.56, 0.56, 0.56, true)
  tooltip:Show()
end

local function RefreshRealmBadges()
  if not (addon and addon.db and addon.db.realm_insights) then return end
  local sp = LFGListFrame and LFGListFrame.SearchPanel
  local sb = sp and sp.ScrollBox
  local frames = EnumerateScrollBoxFrames(sb)
  if not frames then return end
  addon._ggRealmRows = addon._ggRealmRows or {}
  for _, row in ipairs(frames) do
    addon._ggRealmRows[row] = true
    HookRealmRow(row)
    local rid = GetResultIDFromRow(row)
    if addon.LFG_PaintRealmBadge then addon:LFG_PaintRealmBadge(row, rid) end
  end
end

function addon:LFG_HideRealmDecorations()
  if not self._ggRealmRows then return end
  for row in pairs(self._ggRealmRows) do HideRealmBadge(row) end
end

function addon:LFG_InitRealmInsights()
  if self._ggRealmInsightsHooked then return end
  self._ggRealmInsightsHooked = true

  if type(hooksecurefunc) == "function" and type(LFGListUtil_SetSearchEntryTooltip) == "function" then
    hooksecurefunc("LFGListUtil_SetSearchEntryTooltip", function(tooltip, resultID)
      if addon and addon.LFG_AppendRealmInsightTooltip then addon:LFG_AppendRealmInsightTooltip(tooltip, resultID) end
    end)
  end

  local function schedule()
    if addon and addon.LFG_HideRealmDecorations then addon:LFG_HideRealmDecorations() end
    if addon and addon.RunDebounced then
      addon:RunDebounced("realm_badges", 0.01, RefreshRealmBadges)
    elseif C_Timer and C_Timer.After then
      C_Timer.After(0.01, RefreshRealmBadges)
    else
      RefreshRealmBadges()
    end
  end

  local sp = LFGListFrame and LFGListFrame.SearchPanel
  local sb = sp and sp.ScrollBox
  if sb and not sb._ggRealmHooked then
    sb._ggRealmHooked = true
    if sb.HookScript then sb:HookScript("OnMouseWheel", schedule) end
    if sb.FullUpdate then hooksecurefunc(sb, "FullUpdate", schedule) end
    if sb.Update then hooksecurefunc(sb, "Update", schedule) end
    if sb.Refresh then hooksecurefunc(sb, "Refresh", schedule) end
  end
  if type(LFGListSearchPanel_UpdateResults) == "function" then hooksecurefunc("LFGListSearchPanel_UpdateResults", schedule) end
  if type(LFGListSearchPanel_UpdateResultList) == "function" then hooksecurefunc("LFGListSearchPanel_UpdateResultList", schedule) end
  schedule()
end
