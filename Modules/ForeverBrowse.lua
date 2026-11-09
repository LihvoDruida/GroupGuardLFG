-- An addon-owned presentation for Forever filters. Never feed addon-created
-- nodes into Blizzard's browse ScrollBox: its native initializer measures name
-- widths, which can be secret in an insecure execution context (line 489).
local addonName, addon = ...

-- These frames are owned by the addon and live under UIParent. Native frame
-- strata/levels can be secret, and UIPanelManager raises the native window.
-- A fixed level on Browse's stratum can therefore end up UNDER its background.
-- Keep only our list viewport on DIALOG, above the standard panel strata.
local VIEW_LEVEL = 100
local VIEW_STRATA = "DIALOG"
local function OwnLayer(frame, level)
  frame:SetFrameStrata(VIEW_STRATA)
  frame:SetFrameLevel(level)
  if frame.SetFixedFrameStrata then frame:SetFixedFrameStrata(true) end
  if frame.SetFixedFrameLevel then frame:SetFixedFrameLevel(true) end
end

function addon:ForeverBrowse_SyncGeometry()
  local browse, frame = _G.LFGBrowseFrame, self._ggForeverBrowseView
  if not browse then return end
  local function number(object, method)
    local fn = self:SafeObjectMethod(object, method)
    if fn then local ok, value = pcall(fn, object); if ok then return self:SafeNumber(value, nil) end end
  end
  if not frame then return end
  local scale, parentScale = number(browse, "GetEffectiveScale"), number(UIParent, "GetEffectiveScale")
  if scale and parentScale and scale > 0 and parentScale > 0 then frame:SetScale(scale / parentScale) end
  OwnLayer(frame, VIEW_LEVEL)
  OwnLayer(frame.ScrollBox, VIEW_LEVEL + 1)
  if frame.ScrollBox.ScrollTarget then OwnLayer(frame.ScrollBox.ScrollTarget, VIEW_LEVEL + 2) end
  OwnLayer(frame.ScrollBar, VIEW_LEVEL + 3)
  frame.ScrollBox:ForEachFrame(function(row) OwnLayer(row, VIEW_LEVEL + 3) end)
end

local function ConsumeMouse(frame)
  frame:EnableMouse(true)
  if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(true) end
  if frame.SetMouseMotionEnabled then frame:SetMouseMotionEnabled(true) end
  if frame.SetPropagateMouseClicks then frame:SetPropagateMouseClicks(false) end
  if frame.SetPropagateMouseMotion then frame:SetPropagateMouseMotion(false) end
end

local function ReadFrameBoolean(frame, method)
  local fn = addon:SafeObjectMethod(frame, method)
  if not fn then return nil end
  local ok, value = pcall(fn, frame)
  if ok and addon:SafeCanRead(value) then return value == true end
end

local function SetNativeShown(frame, shown)
  if ReadFrameBoolean(frame, "IsShown") == shown then return true end
  if InCombatLockdown and InCombatLockdown() then
    -- Never turn a protected-frame failure into a pcall/taint workaround.
    if ReadFrameBoolean(frame, "IsProtected") ~= false then return false end
  end
  local fn = addon:SafeObjectMethod(frame, shown and "Show" or "Hide")
  if not fn then return false end
  return pcall(fn, frame)
end

-- Event-driven list ownership, independently reimplemented after reviewing
-- BetterGroupFinder/UI/Main.lua. No native provider or Lua method is replaced.
function addon:ForeverBrowse_InitNativeVisibility(browse)
  if not browse then return end
  self._ggForeverNativeVisibility = self._ggForeverNativeVisibility or {}
  local records = self._ggForeverNativeVisibility
  for _, item in ipairs({
    { frame = browse.ScrollBox, kind = "list" }, { frame = browse.ScrollBar, kind = "bar" },
  }) do
    local frame = item.frame
    if frame and not records[frame] then
      local record = { kind = item.kind }
      records[frame] = record
      local hook = self:SafeObjectMethod(frame, "HookScript")
      if hook then
        pcall(hook, frame, "OnShow", function()
          if addon._ggForeverNativeSuppressed then
            record.restoreShown = true
            if not SetNativeShown(frame, false) then addon._ggForeverNativeVisibilityDeferred = true end
          end
        end)
      end
    end
  end
end

function addon:ForeverBrowse_SetNativeSuppressed(suppressed)
  self:ForeverBrowse_InitNativeVisibility(_G.LFGBrowseFrame)
  local records = self._ggForeverNativeVisibility or {}
  if suppressed and not self._ggForeverNativeSuppressed then
    for frame, record in pairs(records) do record.restoreShown = ReadFrameBoolean(frame, "IsShown") end
  end
  self._ggForeverNativeSuppressed = suppressed == true
  local deferred = false
  for frame, record in pairs(records) do
    if suppressed then
      if not SetNativeShown(frame, false) then deferred = true end
    elseif record.restoreShown then
      local restore = true
      if record.kind == "bar" then
        local browse = _G.LFGBrowseFrame
        local scrollBox = browse and browse.ScrollBox
        if scrollBox and ReadFrameBoolean(scrollBox, "HasScrollableExtent") == false then restore = false end
      end
      if not restore or SetNativeShown(frame, true) then record.restoreShown = nil else deferred = true end
    end
  end
  self._ggForeverNativeVisibilityDeferred = deferred
  if suppressed and _G.LFGBrowseSearchEntryTooltip then SetNativeShown(_G.LFGBrowseSearchEntryTooltip, false) end
end

function addon:ForeverBrowse_ApplyDeferredVisibility()
  if self._ggForeverNativeVisibilityDeferred then self:ForeverBrowse_SetNativeSuppressed(self._ggForeverNativeSuppressed == true) end
end

local function InviteAPI()
  return (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteToGroup or InviteUnit
end

local function CanInvite(info)
  if not info or info.numMembers ~= 1 or not info.leaderName then return false end
  local ok, inGroup = pcall(IsInGroup)
  if not ok or not addon:SafeCanRead(inGroup) then return false end
  if inGroup == false then return true end
  return addon.Safe.IsAssistantOrLeader("player")
end

local function ActionInfo(id)
  id = addon:SafeNumber(id, nil)
  if not id then return nil end
  local state = addon._ggForeverPresentationState and addon._ggForeverPresentationState[id]
  local view = addon._ggForeverBrowseView
  if not state or not state.show or not view or not view:IsVisible() or addon._ggForeverRefreshPending then return nil end
  -- A menu can outlive a result. Revalidate on the hardware click, rather than
  -- acting on an old tooltip/selection cache or a newly selected other row.
  if addon.LFG_ForgetSearchResult then addon:LFG_ForgetSearchResult(id) end
  local info = addon:LFG_API_GetSearchResultInfo(id)
  if not info or not info.leaderName or info.leaderName == "" or info.hasSelf ~= false or info.isDelisted ~= false then return nil end
  if not addon:LFGFilters_ResultMatches(id, _G.LFGBrowseFrame) then return nil end
  return info
end

local function WhisperResult(id)
  local info = ActionInfo(id)
  if not info or not info.leaderName then return end
  local send = ChatFrameUtil and ChatFrameUtil.SendTell or ChatFrame_SendTell
  if type(send) == "function" then send(info.leaderName) end
end

local function InviteResult(id)
  local info = ActionInfo(id)
  if not CanInvite(info) then return end
  local invite = InviteAPI()
  if type(invite) == "function" then invite(info.leaderName) end
end

local function NativeSelection()
  return addon:SafeObjectField(_G.LFGBrowseFrame, "selectionBehavior")
end

local function NodeResultID(node)
  local data = addon:SafeObjectField(node, "data")
  return addon:SafeNumber(addon:SafeTableField(data, "resultID"), nil)
end

function addon:ForeverBrowse_GetNativeProvider()
  local browse = _G.LFGBrowseFrame
  local scroll = browse and self:SafeObjectField(browse, "ScrollBox")
  local get = self:SafeObjectMethod(scroll, "GetDataProvider")
  if not get then return nil end
  local ok, provider = pcall(get, scroll)
  if ok and self:SafeCanAccessTable(provider) then return provider end
end

function addon:ForeverBrowse_GetNativeNodes()
  local provider = self:ForeverBrowse_GetNativeProvider()
  local enumerate = self:SafeObjectMethod(provider, "EnumerateEntireRange")
  if not enumerate then return {}, provider end
  local nodes = {}
  local ok = pcall(function()
    for _, node in enumerate(provider) do
      local id = NodeResultID(node)
      if id then nodes[id] = node end
    end
  end)
  return ok and nodes or {}, provider
end

local function SelectedNativeNode()
  local selection = NativeSelection()
  local get = addon:SafeObjectMethod(selection, "GetFirstSelectedElementData")
  if not get then return nil end
  local ok, node = pcall(get, selection)
  if ok and addon:SafeCanAccessTable(node) then return node end
end

function addon:ForeverBrowse_SelectResult(resultID, toggle)
  local selection = NativeSelection()
  local nodes = self:ForeverBrowse_GetNativeNodes()
  local node = resultID and nodes[resultID]
  local current = SelectedNativeNode()
  local method, target = "SelectElementData", node
  if not node or (toggle and NodeResultID(current) == resultID) then method, target = "DeselectElementData", current end
  local fn = self:SafeObjectMethod(selection, method)
  local ok, err = true, nil
  if target and fn then ok, err = pcall(fn, selection, target)
  elseif target then ok, err = false, "native selection API unavailable" end
  self._ggForeverNativeSelectionError = not ok and self:SafeText(err, "native selection unavailable") or nil
  self:ForeverBrowse_UpdateSelection()
  return ok and node ~= nil
end

function addon:ForeverBrowse_UpdateSelection()
  local view = self._ggForeverBrowseView
  if not view then return end
  local selected = SelectedNativeNode()
  local id = NodeResultID(selected)
  local state = id and self._ggForeverPresentationState and self._ggForeverPresentationState[id]
  local info = id and self:LFG_API_GetSearchResultInfo(id)
  if id and (not state or not state.show or not info or not info.leaderName or info.leaderName == "" or info.hasSelf ~= false or info.isDelisted ~= false) then
    local selection = NativeSelection()
    local deselect = self:SafeObjectMethod(selection, "DeselectElementData")
    if deselect then pcall(deselect, selection, selected) end
    id = nil
  end
  -- Blizzard's invite button closes over the selected result info. A solo
  -- becoming a group, or changing leader, needs a fresh native callback even
  -- when the result ID and filter verdict remain the same.
  local previous = self._ggForeverSelectedAction
  if id and previous and previous.node == selected
      and (previous.name ~= info.leaderName or previous.members ~= info.numMembers) then
    local selection = NativeSelection()
    local deselect = self:SafeObjectMethod(selection, "DeselectElementData")
    local select = self:SafeObjectMethod(selection, "SelectElementData")
    local ok, err = pcall(function()
      assert(deselect and select, "native selection API unavailable")
      deselect(selection, selected)
      select(selection, selected)
    end)
    self._ggForeverNativeSelectionError = not ok and self:SafeText(err, "native selection unavailable") or nil
    if not ok then id = nil end
  end
  self._ggForeverSelectedAction = id and { node = selected, name = info.leaderName, members = info.numMembers } or nil
  view.selectedResultID = id
  view.ScrollBox:ForEachFrame(function(row)
    self:ForeverBrowse_SetRowSelection(row, row.resultID ~= nil and row.resultID == view.selectedResultID)
  end)
end

function addon:ForeverBrowse_CloseMenu()
  local menu = self._ggForeverRowMenu
  local close = self:SafeObjectMethod(menu, "Close")
  if close then pcall(close, menu) end
  self._ggForeverRowMenu, self._ggForeverMenuOwner = nil, nil
end

local function ShowMenu(row)
  local id = row.resultID
  local info = ActionInfo(id)
  if not info or not MenuUtil or type(MenuUtil.CreateContextMenu) ~= "function" then return end
  addon._ggForeverMenuOwner = row
  -- The game's own menu widgets, labels and action order; actions revalidate
  -- the original result so a recycled row cannot contact another candidate.
  addon._ggForeverRowMenu = MenuUtil.CreateContextMenu(row, function(_, root)
    root:CreateTitle(info.leaderName)
    root:CreateButton(SEND_MESSAGE, function() WhisperResult(id) end):SetEnabled(true)
    root:CreateButton(GROUP_INVITE, function() InviteResult(id) end):SetEnabled(CanInvite(info))
    for _, item in ipairs({ { LFG_LIST_REPORT_GROUP_FOR, "LFGBrowseUtil_ReportListing" },
        { REPORT_GROUP_FINDER_ADVERTISEMENT, "LFGBrowseUtil_ReportAdvertisement" } }) do
      local fn = _G[item[2]]
      if item[1] and type(fn) == "function" then
        root:CreateButton(item[1], function()
          local current = ActionInfo(id)
          if current then fn(id, current.leaderName) end
        end)
      end
    end
  end)
end

local function HideRowTooltip(row)
  if addon.ForeverTooltip_Hide then addon:ForeverTooltip_Hide(row) end
end

local function Hovered(row)
  if InputUtil and type(InputUtil.IsMouseOver) == "function" then
    local ok, value = pcall(InputUtil.IsMouseOver, row)
    return ok and addon:SafeBool(value)
  end
  return false
end

function addon:ForeverBrowse_SetRowSelection(row, selected)
  if not row.Selected then return end
  row.Selected:SetShown(selected)
  if row.Highlight then row.Highlight:SetShown(not selected and Hovered(row)) end
end

local function ConfigureRow(row)
  if row._ggNativeTemplateConfigured then return end
  row._ggNativeTemplateConfigured = true
  -- Native templates register a global result event in OnLoad. Their standard
  -- renderer must never run on our nodes; the addon event bus handles updates.
  row:UnregisterAllEvents()
  row:SetScript("OnEvent", nil)
  row:SetScript("OnClick", function(self, button)
    addon:ForeverBrowse_CloseMenu()
    if self.dividerType then
      local node, divider = self.elementNode, self.dividerType
      node:ToggleCollapsed(nil, TreeDataProviderConstants.DoInvalidation)
      addon._ggForeverBrowseView.collapsed[divider] = node:IsCollapsed()
      if self.elementNode == node then
        self.ExpandIcon:SetShown(node:IsCollapsed())
        self.CollapseIcon:SetShown(not node:IsCollapsed())
      end
      return
    end
    if not ActionInfo(self.resultID) then return end
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
    if button == "RightButton" then ShowMenu(self)
    else addon:ForeverBrowse_SelectResult(self.resultID, true) end
  end)
  row:SetScript("OnEnter", function(self)
    if self.resultID and addon.ForeverTooltip_Show then addon:ForeverTooltip_Show(self) end
    if self.Highlight and (not self.Selected or not self.Selected:IsShown()) then self.Highlight:Show() end
  end)
  row:SetScript("OnLeave", function(self)
    HideRowTooltip(self)
    if self.Highlight then self.Highlight:Hide() end
  end)
  row:HookScript("OnHide", function(self)
    HideRowTooltip(self)
    if addon._ggForeverMenuOwner == self then addon:ForeverBrowse_CloseMenu() end
  end)
  if row.CategoryLabel then row:RegisterForClicks("LeftButtonUp")
  else row:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
end

local function Color(region, color)
  if region and color then region:SetTextColor(color.r, color.g, color.b) end
end

local function ReadWidth(region)
  local get = addon:SafeObjectMethod(region, "GetWidth")
  if not get then return nil end
  local ok, value = pcall(get, region)
  return ok and addon:SafeNumber(value, nil) or nil
end

local function ActiveActivities()
  local active = addon:LFG_API_GetActiveEntryInfo()
  local ids = addon:SafeTableField(active, "activityIDs")
  local out = {}
  if addon:SafeCanAccessTable(ids) then
    for index = 1, #ids do
      local id = addon:SafeNumber(addon:SafeTableField(ids, index), nil)
      if id then out[id] = true end
    end
  end
  return out
end

function addon:ForeverBrowse_ActivityName(id)
  local activity = self:LFG_API_GetActivityInfoTable(id)
  if not activity then return "" end
  if type(LFGUtil_GetActivityInfoName) == "function" then
    local ok, text = pcall(LFGUtil_GetActivityInfoName, activity)
    text = ok and self:SafeText(text, nil)
    if text then return text end
  end
  return activity.fullName or activity.shortName or ""
end

local function Format(text, ...)
  if type(text) ~= "string" then return "" end
  local ok, value = pcall(string.format, text, ...)
  return ok and value or text
end

local function DisplayCounts(id, kind, members)
  local counts = addon:LFG_API_GetSearchResultMemberCounts(id)
  if not counts then return nil end
  local keys = { "TANK", "HEALER", "DAMAGER" }
  if kind == Enum.LFGListDisplayType.ClassEnumerate then keys = CLASS_SORT_ORDER
  elseif kind == Enum.LFGListDisplayType.PlayerCount then keys = { "TANK", "HEALER", "DAMAGER", "NOROLE" } end
  for _, key in ipairs(keys) do
    if type(counts[key]) ~= "number" or counts[key] < 0 then return nil end
  end
  return counts
end

-- Geometry, fonts, atlases and child layouts come from the actual loaded
-- game template. This renderer changes content only, and guards every metric.
function addon:ForeverBrowse_RenderRow(row, node)
  ConfigureRow(row)
  local data = node.data
  if row.resultID ~= data.resultID then HideRowTooltip(row) end
  row.elementNode, row.resultID, row.dividerType = node, data.resultID, data.dividerType
  if data.dividerType then
    row:Show()
    row.CategoryLabel:SetText(data.dividerType == LFGVanillaBrowseDividerType.CategorySolo
      and LFG_LIST_CATEGORY_SOLO_PLAYERS or LFG_LIST_CATEGORY_GROUPS)
    row.ExpandIcon:SetShown(node:IsCollapsed())
    row.CollapseIcon:SetShown(not node:IsCollapsed())
    return
  end
  local info = self:LFG_API_GetSearchResultInfo(data.resultID)
  if not info then row:Hide(); return end
  row:Show()
  local solo = info.numMembers == 1
  local player = solo and self:LFG_API_GetSearchResultPlayerInfo(data.resultID, 1) or nil
  row.isDelisted, row.hasSelf = info.isDelisted, info.hasSelf
  row.PartyIcon:SetShown(not solo)
  row.ClassIcon:SetShown(solo and player ~= nil and player.classFilename ~= nil and player.level ~= nil)
  row.Level:SetShown(solo and player ~= nil and player.classFilename ~= nil and player.level ~= nil)
  row.Name:ClearAllPoints()
  if solo then
    if player and player.classFilename and player.level then
      row.Level:SetText((LEVEL_ABBR or "") .. " " .. player.level)
      row.ClassIcon:SetAtlas("groupfinder-icon-class-" .. string.lower(player.classFilename), false)
    end
    row.Name:SetPoint("TOPLEFT", row.PartyIcon, "TOPLEFT", row.NameSoloOffsetX, row.NameSoloOffsetY)
  else
    row.Name:SetPoint("TOPLEFT", row.PartyIcon, "TOPRIGHT", row.NameGroupOffsetX, row.NameGroupOffsetY)
  end
  row.NewPlayerFriendlyIcon:ClearAllPoints()
  row.NewPlayerFriendlyIcon:SetPoint("LEFT", solo and row.ClassIcon or (row.DiscordIcon or row.Name), "RIGHT", 2, 0)

  local selected = self:SafeObjectField(_G.LFGBrowseFrame, "ActivityDropdown")
  local selectedIDs = self:SafeObjectField(selected, "selectedValues")
  local filters = {}
  if self:SafeCanAccessTable(selectedIDs) then
    for index = 1, #selectedIDs do
      local id = self:SafeNumber(self:SafeTableField(selectedIDs, index), nil)
      if id then filters[id] = true end
    end
  end
  local active, matches, matching = ActiveActivities(), next(filters) == nil, {}
  for _, id in ipairs(info.activityIDs) do
    if filters[id] then matches = true end
    if active[id] then matching[#matching + 1] = id end
  end
  local activities = #matching > 0 and matching or info.activityIDs
  local activityText
  if info.hasSelf then activityText = LFG_SELF_LISTING
  elseif #activities == 1 then activityText = self:ForeverBrowse_ActivityName(activities[1])
  else activityText = Format(#matching > 0 and LFGBROWSE_ACTIVITY_MATCHING_COUNT or LFGBROWSE_ACTIVITY_COUNT, #activities) end
  local leader = self:LFG_API_GetSearchResultLeaderInfo(data.resultID)
  local nameColor = leader and leader.classFilename and RAID_CLASS_COLORS[leader.classFilename] or NORMAL_FONT_COLOR
  local levelColor, activityColor = GRAY_FONT_COLOR, GRAY_FONT_COLOR
  if info.isDelisted or not matches then
    nameColor, levelColor, activityColor = { r = 0.3, g = 0.3, b = 0.3 }, { r = 0.3, g = 0.3, b = 0.3 }, { r = 0.3, g = 0.3, b = 0.3 }
  elseif info.hasSelf then activityColor = LIGHTGREEN_FONT_COLOR
  elseif #matching > 0 then activityColor = BRIGHTBLUE_FONT_COLOR end
  row.Name:SetWidth(0)
  row.Name:SetText(info.leaderName or "...")
  Color(row.Name, nameColor)
  local maxWidth = row.NameMaxWidth
  if row.DiscordIcon then
    local discord = Enum.LFGEntryVoiceMode and info.voiceMode == Enum.LFGEntryVoiceMode.Discord
    row.DiscordIcon:SetShown(discord == true)
    row.DiscordIcon:SetDesaturated(info.isDelisted == true)
    if discord then maxWidth = maxWidth - 20 end -- native 16px Discord icon + 4px gap
    row.Level:ClearAllPoints()
    row.Level:SetPoint("BOTTOMLEFT", discord and row.DiscordIcon or row.Name, "BOTTOMRIGHT", 4, 0)
  end
  row.NewPlayerFriendlyIcon:SetShown(info.newPlayerFriendly == true)
  row.NewPlayerFriendlyIcon:SetDesaturated(info.isDelisted == true)
  if info.newPlayerFriendly then maxWidth = maxWidth - (ReadWidth(row.NewPlayerFriendlyIcon) or 20) - 1 end
  local width = ReadWidth(row.Name)
  if not width or width > maxWidth then row.Name:SetWidth(maxWidth) end
  Color(row.Level, levelColor)
  row.ClassIcon:SetDesaturated(info.isDelisted == true)
  row.ActivityName:SetText(activityText or "")
  Color(row.ActivityName, activityColor)
  if row.PlaystyleLabel then
    local text = ""
    if info.generalPlaystyle and type(GetGeneralPlaystyleString) == "function" then
      local ok, value = pcall(GetGeneralPlaystyleString, info.generalPlaystyle)
      if ok then text = self:SafeText(value, "") end
    end
    row.PlaystyleLabel:SetText(text)
  end
  local displayType, maximum
  if type(LFGBrowseUtil_GetBestDisplayTypeForActivityIDs) == "function" then
    local ok, kind, count = pcall(LFGBrowseUtil_GetBestDisplayTypeForActivityIDs, info.activityIDs)
    if ok then displayType, maximum = self:SafeNumber(kind, nil), self:SafeNumber(count, nil) end
  end
  local display = row.DataDisplay
  local counts = displayType and DisplayCounts(data.resultID, displayType, info.numMembers)
  local roles = player and player.lfgRoles
  if maximum and display.Enumerate and display.Enumerate.Icons then maximum = math.min(maximum, #display.Enumerate.Icons) end
  -- Reset all native display modes before rendering, including recycled rows.
  for _, key in ipairs({ "Solo", "RoleCount", "Enumerate", "PlayerCount", "Comment", "DelistButton" }) do
    if display[key] then display[key]:Hide() end
  end
  if displayType and type(LFGBrowseGroupDataDisplay_Update) == "function" then
    LFGBrowseGroupDataDisplay_Update(display, displayType, maximum or 5, counts,
      info.isDelisted == true, solo, roles, info.comment or "", info.hasSelf == true)
  end
  self:ForeverBrowse_SetRowSelection(row, data.resultID == self._ggForeverBrowseView.selectedResultID)
end

function addon:ForeverBrowse_RefreshRows(resultID)
  local view = self._ggForeverBrowseView
  if not view or not view:IsShown() then return false end
  local updated = false
  view.ScrollBox:ForEachFrame(function(row)
    if row.resultID and row.elementNode and (not resultID or row.resultID == resultID) then
      self:ForeverBrowse_RenderRow(row, row.elementNode)
      updated = true
    end
  end)
  self:ForeverBrowse_UpdateSelection()
  return updated
end

function addon:ForeverBrowse_RefreshTooltip(resultID)
  local view = self._ggForeverBrowseView
  local row = view and view.tooltipRow
  if row and row.resultID == resultID and view:IsVisible() and row:IsVisible() and self.ForeverTooltip_Show then
    self:ForeverTooltip_Show(row)
    return true
  end
  return false
end

function addon:ForeverBrowse_GetScrollBox(browse)
  if not browse or browse ~= _G.LFGBrowseFrame then return nil end
  self:ForeverBrowse_SyncGeometry()
  if self._ggForeverBrowseView then return self._ggForeverBrowseView.ScrollBox end
  local native = browse.ScrollBox
  local modern = _G.LFGVANILLA_SETTING_MODERN_STYLE ~= false
  local frame = CreateFrame("Frame", "GroupGuardLFGForeverBrowseView", UIParent)
  frame:Hide()
  OwnLayer(frame, VIEW_LEVEL)
  local left = self:SafeNumber(self:SafeObjectField(native, "AnchorOffsetLeft"), modern and 7 or 22)
  local top = self:SafeNumber(self:SafeObjectField(native, "AnchorOffsetTop"), modern and -112 or -128)
  local right = self:SafeNumber(self:SafeObjectField(native, "AnchorOffsetRight"), modern and -6 or -38)
  local bottom = self:SafeNumber(self:SafeObjectField(native, "AnchorOffsetBottom"), modern and 40 or 102)
  -- Native rows share the panel's layer, where footer art can cover them.
  -- Our DIALOG viewport must end above that art and the standard buttons:
  -- modern separator at y=61 (+3px); classic button top at y=101 (+9px).
  -- Reserve the space in the viewport itself so clipping, wheel input and
  -- both managed scrollbar anchor sets all stop before the footer.
  bottom = math.max(bottom, modern and 64 or 110)
  local barWidth = self:SafeNumber(self:SafeObjectField(native, "ScrollBarWidth"), modern and 16 or 28)
  frame:SetPoint("TOPLEFT", browse, "TOPLEFT", left, top)
  frame:SetPoint("BOTTOMRIGHT", browse, "BOTTOMRIGHT", right, bottom)
  ConsumeMouse(frame)
  -- No fill, row art, fonts or manually chosen row heights. The native window
  -- background remains visible behind the actual game row templates.
  local scroll = CreateFrame("Frame", nil, frame, "WowScrollBoxList")
  local bar = CreateFrame("EventFrame", nil, frame, modern and "MinimalScrollBar" or "WowClassicScrollBar")
  frame.ScrollBox, frame.ScrollBar, frame.collapsed = scroll, bar, {}
  OwnLayer(scroll, VIEW_LEVEL + 1)
  if scroll.ScrollTarget then OwnLayer(scroll.ScrollTarget, VIEW_LEVEL + 2) end
  OwnLayer(bar, VIEW_LEVEL + 3)
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -barWidth, 0)
  bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", modern and 2 or 0, modern and -4 or 4)
  bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 0, modern and 2 or -5)
  local view = CreateScrollBoxListTreeListView(0, 0, 0, 0, 0, 0)
  view:SetElementFactory(function(factory, node)
    local data = node.data
    local template = data.dividerType and "LFGBrowseSearchEntryGroupingTemplate"
      or data.category and "LFGBrowseNestedSearchEntryTemplate" or "LFGBrowseSearchEntryTemplate"
    factory(template, function(row, element)
      OwnLayer(row, VIEW_LEVEL + 3)
      local ok, err = pcall(addon.ForeverBrowse_RenderRow, addon, row, element)
      if not ok then addon:LFGFilters_ReportPresentationError(err) end
    end)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(scroll, bar, view)
  ScrollUtil.AddManagedScrollBarVisibilityBehavior(scroll, bar,
    { CreateAnchor("TOPLEFT", 0, 0), CreateAnchor("BOTTOMRIGHT", -barWidth, 0) },
    { CreateAnchor("TOPLEFT", 0, 0), CreateAnchor("BOTTOMRIGHT", 0, 0) })
  if BaseScrollBoxEvents and BaseScrollBoxEvents.OnScroll then
    scroll:RegisterCallback(BaseScrollBoxEvents.OnScroll, function() addon:ForeverBrowse_CloseMenu() end, frame)
  end
  frame.Empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  frame.Empty:SetPoint("TOP", browse.BackgroundArt or frame, "TOP", 0, -40)
  frame.Empty:SetWidth(240)
  frame.Empty:SetWordWrap(true)
  self._ggForeverBrowseView = frame
  self:ForeverBrowse_SyncGeometry()
  return scroll
end

function addon:ForeverBrowse_Show(visibleCount)
  local view = self._ggForeverBrowseView
  if not view then return end
  local results = self._ggForeverPresentationResults
  local text = LFG_LIST_NO_RESULTS_FOUND
  if (self._ggForeverUnavailableResults or 0) > 0 then text = self:Tr("LFG_FILTERS_DATA_UNAVAILABLE")
  elseif type(results) == "table" and #results > 0 then text = self:Tr("LFG_FILTERS_NO_MATCHES") end
  view.Empty:SetText(text)
  local nativeEmpty = _G.LFGBrowseFrame and ReadFrameBoolean(_G.LFGBrowseFrame.NoResultsFound, "IsShown") == true
  view.Empty:SetShown(visibleCount == 0 and not nativeEmpty)
  view:Show()
  -- SetDataProvider can run while the viewport is hidden. Lay out again after
  -- showing it so the original ScrollBox uses the resolved viewport rectangle.
  local ok, err = pcall(view.ScrollBox.FullUpdate, view.ScrollBox, ScrollBoxConstants.UpdateImmediately)
  if not ok then self:LFGFilters_ReportPresentationError(err); return false end
  if self._ggForeverPresentationError then return false end
  -- The match count measures data, not pixels. Never suppress the original
  -- list with a supposedly successful nonempty provider and no acquired frame.
  local acquired = false
  view.ScrollBox:ForEachFrame(function() acquired = true end)
  if visibleCount > 0 and not acquired then
    self:LFGFilters_ReportPresentationError("GroupGuard browse: nonempty results but ScrollBox acquired no frames")
    return false
  end
  self:ForeverBrowse_UpdateSelection()
  self:ForeverBrowse_SetNativeSuppressed(true)
  self._ggForeverPresentationHiddenReason = nil
  return true
end

function addon:ForeverBrowse_Hide(reason)
  self:ForeverBrowse_CloseMenu()
  self._ggForeverPresentationHiddenReason = reason or "hidden"
  local view = self._ggForeverBrowseView
  if view then
    if view.tooltipRow then HideRowTooltip(view.tooltipRow) end
    view:Hide()
  end
  self:ForeverBrowse_SetNativeSuppressed(false)
end
