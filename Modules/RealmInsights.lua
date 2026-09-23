-- GroupGuard LFG — Modules / Realm Insights
-- Optional technical realm-locale hints inspired by GroupfinderFlags, without replacing Blizzard/PGF UI.
local addonName, addon = ...

-- An error raised inside a hooksecurefunc callback unwinds through the Blizzard
-- function that was hooked, so everything that function had left to do -- laying
-- out panels, showing tabs, filling rows -- silently never happens. Every hook
-- installed from this file goes through this guard instead.
local function GGHook(target, methodOrFunc, maybeFunc)
  if type(hooksecurefunc) ~= "function" then return false end
  local isGlobal = type(methodOrFunc) == "function"
  local fn = isGlobal and methodOrFunc or maybeFunc
  if type(fn) ~= "function" then return false end
  local label = isGlobal and tostring(target) or tostring(methodOrFunc)
  local guarded = (addon.WrapHookCallback and addon:WrapHookCallback(fn, label)) or fn
  local ok
  if isGlobal then
    ok = pcall(hooksecurefunc, target, guarded)
  else
    if addon.Safe and addon.Safe.CanAccessObject and not addon.Safe.CanAccessObject(target) then return false end
    ok = pcall(hooksecurefunc, target, methodOrFunc, guarded)
  end
  return ok and true or false
end

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
  if addon and addon.Safe and addon.Safe.CanReadValue then return addon.Safe.CanReadValue(value) end
  if type(canaccessvalue) == "function" then
    local ok, allowed = pcall(canaccessvalue, value)
    if not ok or allowed ~= true then return false end
  end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret == true then return false end
  end
  return value ~= nil
end

local function SafeText(value)
  if not CanReadValue(value) then return nil end
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
  local info = addon and addon.LFG_API_GetSearchResultInfo and addon:LFG_API_GetSearchResultInfo(resultID) or nil
  if type(info) ~= "table" then return nil end
  local leaderName = SafeText(info.leaderName)
  local _, realm = SplitNameRealm(leaderName)
  return realm, leaderName
end

local function GetResultIDFromRow(frame)
  if not frame then return nil end
  local Safe = addon and addon.Safe
  if not (Safe and Safe.CanAccessObject and Safe.CanAccessObject(frame)) then return nil end
  local keys = { "resultID", "resultId", "searchResultID", "searchResultId", "id", "ID" }
  if addon.SafeGetElementData and Safe.TableField then
    local ed = addon:SafeGetElementData(frame)
    for i = 1, #keys do
      local id = Safe.Number(Safe.TableField(ed, keys[i]), nil)
      if id then return id end
    end
  end
  if Safe.ObjectField then
    for i = 1, #keys do
      local id = Safe.Number(Safe.ObjectField(frame, keys[i]), nil)
      if id then return id end
    end
  end
  return nil
end

local function EnumerateScrollBoxFrames(sb)
  if addon and addon.SafeEnumerateScrollBoxFrames then return addon:SafeEnumerateScrollBoxFrames(sb) end
  return nil
end

local function SafeSetField(object, key, value)
  local Safe = addon and addon.Safe
  if not (Safe and Safe.CanAccessObject and Safe.CanAccessObject(object)) then return false end
  return pcall(function() object[key] = value end)
end

local function EnsureRealmBadge(row)
  local Safe = addon and addon.Safe
  if not (Safe and Safe.CanAccessObject and Safe.CanAccessObject(row)) then return nil end
  local badge = Safe.ObjectField and Safe.ObjectField(row, "_ggRealmBadge") or nil
  if badge and Safe.CanAccessObject and not Safe.CanAccessObject(badge) then badge = nil end
  if not badge then
    local create = Safe.ObjectMethod and Safe.ObjectMethod(row, "CreateFontString")
    if not create then return nil end
    local okCreate, created = pcall(create, row, nil, "OVERLAY", "GameFontNormalSmall")
    if not okCreate or not created or not Safe.CanAccessObject(created) then return nil end
    badge = created
    local justify = Safe.ObjectMethod(badge, "SetJustifyH")
    local setPoint = Safe.ObjectMethod(badge, "SetPoint")
    local setColor = Safe.ObjectMethod(badge, "SetTextColor")
    if justify then pcall(justify, badge, "RIGHT") end
    if setPoint then pcall(setPoint, badge, "TOPRIGHT", row, "TOPRIGHT", -8, -5) end
    if setColor then pcall(setColor, badge, 0.85, 0.85, 0.85, 0.95) end
    local wordWrap = Safe.ObjectMethod(badge, "SetWordWrap")
    if wordWrap then pcall(wordWrap, badge, false) end
    local nonSpaceWrap = Safe.ObjectMethod(badge, "SetNonSpaceWrap")
    if nonSpaceWrap then pcall(nonSpaceWrap, badge, false) end
    if not SafeSetField(row, "_ggRealmBadge", badge) then return nil end
  end
  return badge
end

local function HideRealmBadge(row)
  local Safe = addon and addon.Safe
  if not (Safe and Safe.CanAccessObject and Safe.CanAccessObject(row)) then return end
  local badge = Safe.ObjectField and Safe.ObjectField(row, "_ggRealmBadge") or nil
  if not badge or not Safe.CanAccessObject(badge) then return end
  SafeSetField(badge, "_ggOwnerResultID", nil)
  local setText = Safe.ObjectMethod(badge, "SetText")
  local hide = Safe.ObjectMethod(badge, "Hide")
  if setText then pcall(setText, badge, "") end
  if hide then pcall(hide, badge) end
end

-- PERF: this used to allocate a closure and a C_Timer per row on every OnShow
-- and every SetElementData.  Scrolling a full search panel therefore created
-- dozens of one-shot timers per frame.  Rows are collected into a pending set
-- and repainted once on the next tick instead.
local pendingRealmRows = {}
local realmRepaintScheduled = false

local function FlushRealmBadgeRefresh()
  realmRepaintScheduled = false
  local rows = pendingRealmRows
  pendingRealmRows = {}
  if not (addon and addon.LFG_PaintRealmBadge) then return end
  for row in pairs(rows) do
    local Safe = addon.Safe
    local isShown = Safe and Safe.ObjectMethod and Safe.ObjectMethod(row, "IsShown")
    local okShown, shown = false, false
    if isShown then okShown, shown = pcall(isShown, row) end
    if okShown and shown == true then addon:LFG_PaintRealmBadge(row, GetResultIDFromRow(row)) end
  end
end

local function ScheduleRealmBadgeRefresh(row)
  if not row or not (addon.Safe and addon.Safe.CanAccessObject and addon.Safe.CanAccessObject(row)) then return end
  if not (C_Timer and C_Timer.After) then
    if addon and addon.LFG_PaintRealmBadge then
      addon:LFG_PaintRealmBadge(row, GetResultIDFromRow(row))
    end
    return
  end
  pendingRealmRows[row] = true
  if realmRepaintScheduled then return end
  realmRepaintScheduled = true
  C_Timer.After(0, FlushRealmBadgeRefresh)
end

local function HookRealmRow(row)
  local Safe = addon and addon.Safe
  if not (Safe and Safe.CanAccessObject and Safe.CanAccessObject(row)) then return end
  if Safe.ObjectField(row, "_ggRealmRecycleHooked") == true then return end
  if not SafeSetField(row, "_ggRealmRecycleHooked", true) then return end
  local hookScript = Safe.ObjectMethod(row, "HookScript")
  if hookScript then
    pcall(hookScript, row, "OnHide", HideRealmBadge)
    pcall(hookScript, row, "OnShow", function(frame)
      HideRealmBadge(frame)
      ScheduleRealmBadgeRefresh(frame)
    end)
  end
  if Safe.ObjectMethod(row, "SetElementData") and type(hooksecurefunc) == "function" then
    GGHook(row, "SetElementData", function(frame)
      HideRealmBadge(frame)
      ScheduleRealmBadgeRefresh(frame)
    end)
  end
end

function addon:LFG_PaintRealmBadge(row, resultID)
  if self.HasClientCapability and not self:HasClientCapability("lfgRealmInsights") then return end
  local Safe = self.Safe
  if not (Safe and Safe.CanAccessObject and Safe.CanAccessObject(row)) then return end
  HideRealmBadge(row)
  if not (self.db and self.db.realm_insights and self.db.realm_badges) then return end
  local isShown = Safe.ObjectMethod(row, "IsShown")
  if isShown then
    local okShown, shown = pcall(isShown, row)
    if okShown and shown ~= true then return end
  end
  if not resultID then return end
  local realm = GetSearchResultLeaderRealm(resultID)
  local hint = realm and self:GetRealmHintFromFullName("x-" .. realm) or nil
  if not hint then return end
  if self.db.realm_same_locale_only ~= false then
    local _, ownCode = self:GetRealmLocaleLabel(OwnRealm())
    if ownCode and ownCode == hint.code then return end
  end
  local badge = EnsureRealmBadge(row)
  if not badge then return end
  SafeSetField(badge, "_ggOwnerResultID", resultID)
  local setColor = Safe.ObjectMethod(badge, "SetTextColor")
  local c = REALM_BADGE_COLORS[hint.code]
  if setColor then
    if c then pcall(setColor, badge, c[1], c[2], c[3], 0.95)
    else pcall(setColor, badge, 0.85, 0.85, 0.85, 0.95) end
  end
  local setText = Safe.ObjectMethod(badge, "SetText")
  local show = Safe.ObjectMethod(badge, "Show")
  if setText then pcall(setText, badge, "[" .. (hint.short or "RL") .. "]") end
  if show then pcall(show, badge) end
end

function addon:LFG_AppendRealmInsightTooltip(tooltip, resultID)
  if self.HasClientCapability and not self:HasClientCapability("lfgRealmInsights") then return end
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
  local sp = addon and addon.GetLFGSearchFrame and addon:GetLFGSearchFrame() or (LFGListFrame and LFGListFrame.SearchPanel)
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
  if self.HasClientCapability and not self:HasClientCapability("lfgRealmInsights") then
    if self.LFG_HideRealmDecorations then self:LFG_HideRealmDecorations() end
    return
  end
  local function schedule()
    if addon and addon.LFG_HideRealmDecorations then addon:LFG_HideRealmDecorations() end
    if addon and addon.RunDebounced then
      addon:RunDebounced("realm_badges", 0.08, RefreshRealmBadges)
    elseif C_Timer and C_Timer.After then
      C_Timer.After(0.08, RefreshRealmBadges)
    else
      RefreshRealmBadges()
    end
  end

  if type(hooksecurefunc) == "function" then
    if not self._ggRealmTooltipHookedMainline and type(LFGListUtil_SetSearchEntryTooltip) == "function" then
      local ok = GGHook("LFGListUtil_SetSearchEntryTooltip", function(tooltip, resultID)
        if addon and addon.LFG_AppendRealmInsightTooltip then addon:LFG_AppendRealmInsightTooltip(tooltip, resultID) end
      end)
      if ok then self._ggRealmTooltipHookedMainline = true end
    end
    if not self._ggRealmTooltipHookedForever and type(LFGBrowseSearchEntryTooltip_UpdateAndShow) == "function" then
      local ok = GGHook("LFGBrowseSearchEntryTooltip_UpdateAndShow", function(tooltip, resultID)
        if addon and addon.LFG_AppendRealmInsightTooltip then addon:LFG_AppendRealmInsightTooltip(tooltip, resultID) end
      end)
      if ok then self._ggRealmTooltipHookedForever = true end
    end
  end

  local sp = addon and addon.GetLFGSearchFrame and addon:GetLFGSearchFrame() or (LFGListFrame and LFGListFrame.SearchPanel)
  local sb = sp and sp.ScrollBox
  if sb and self.SafeObserveScrollBox then
    self:SafeObserveScrollBox(sb, "realm-insights-search", function() schedule() end, schedule)
  end

  if not self._ggRealmResultsHookedMainline then
    local hooked = false
    if type(LFGListSearchPanel_UpdateResults) == "function" then hooked = GGHook("LFGListSearchPanel_UpdateResults", schedule) or hooked end
    if type(LFGListSearchPanel_UpdateResultList) == "function" then hooked = GGHook("LFGListSearchPanel_UpdateResultList", schedule) or hooked end
    if hooked then self._ggRealmResultsHookedMainline = true end
  end
  if not self._ggRealmResultsHookedForever and type(LFGBrowseMixin) == "table" and type(LFGBrowseMixin.UpdateResults) == "function" then
    local ok = GGHook(LFGBrowseMixin, "UpdateResults", schedule)
    if ok then self._ggRealmResultsHookedForever = true end
  end

  schedule()
end
