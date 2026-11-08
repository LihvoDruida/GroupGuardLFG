-- An addon-owned presentation for Forever filters. Never feed addon-created
-- nodes into Blizzard's browse ScrollBox: its native initializer measures name
-- widths, which can be secret in an insecure execution context (line 489).
local addonName, addon = ...

local function SelectedInfo()
  local view = addon._ggForeverBrowseView
  local id = view and view.selectedResultID
  local info = id and addon:LFG_API_GetSearchResultInfo(id)
  if not info or info.hasSelf or info.isDelisted then return nil end
  return info, id
end

local function CanInvite(info)
  if not info or info.numMembers ~= 1 or not info.leaderName then return false end
  return not IsInGroup() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

local function WhisperSelected()
  local info = SelectedInfo()
  if not info or not info.leaderName then return end
  local send = ChatFrameUtil and ChatFrameUtil.SendTell or ChatFrame_SendTell
  if type(send) == "function" then send(info.leaderName) end
end

local function InviteSelected()
  local info = SelectedInfo()
  if not CanInvite(info) then return end
  local invite = InviteToGroup or (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
  if type(invite) == "function" then invite(info.leaderName) end
end

function addon:ForeverBrowse_UpdateSelection()
  local view = self._ggForeverBrowseView
  if not view then return end
  local info = SelectedInfo()
  if not info then view.selectedResultID = nil end
  view.MessageButton:SetEnabled(info ~= nil and info.leaderName ~= nil)
  view.InviteButton:SetEnabled(CanInvite(info))
  view.ScrollBox:ForEachFrame(function(row)
    if row.Selected then row.Selected:SetShown(row.resultID ~= nil and row.resultID == view.selectedResultID) end
  end)
end

local function ShowMenu(row)
  if not (MenuUtil and type(MenuUtil.CreateContextMenu) == "function") then return end
  local info, id = SelectedInfo()
  if not info then return end
  MenuUtil.CreateContextMenu(row, function(_, root)
    root:CreateTitle(info.leaderName or "...")
    root:CreateButton(SEND_MESSAGE, WhisperSelected):SetEnabled(info.leaderName ~= nil)
    root:CreateButton(GROUP_INVITE, InviteSelected):SetEnabled(CanInvite(info))
    if info.leaderName and type(LFGBrowseUtil_ReportListing) == "function" then
      root:CreateButton(LFG_LIST_REPORT_GROUP_FOR, function() LFGBrowseUtil_ReportListing(id, info.leaderName) end)
    end
    if info.leaderName and type(LFGBrowseUtil_ReportAdvertisement) == "function" then
      root:CreateButton(REPORT_GROUP_FINDER_ADVERTISEMENT, function() LFGBrowseUtil_ReportAdvertisement(id, info.leaderName) end)
    end
  end)
end

local function ShowTooltip(row)
  if not row.resultID or not GameTooltip then return end
  local info = addon:LFG_API_GetSearchResultInfo(row.resultID)
  if not info then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:SetText(info.leaderName or "...")
  if info.comment and info.comment ~= "" then GameTooltip:AddLine(info.comment, 1, 1, 1, true) end
  if info.numMembers then GameTooltip:AddLine((MEMBERS or "Members") .. ": " .. info.numMembers, 0.8, 0.8, 0.8) end
  for index = 1, math.min(info.numMembers or 0, 40) do
    local member = addon:LFG_API_GetSearchResultPlayerInfo(row.resultID, index)
    if member and member.name then
      local level = member.level and (" (" .. member.level .. ")") or ""
      GameTooltip:AddLine(member.name .. level .. " — " .. (member.assignedRole or ""), 0.85, 0.85, 0.85)
    end
  end
  if addon.LFG_AddSearchTooltip then addon:LFG_AddSearchTooltip(GameTooltip, row.resultID) end
  GameTooltip:Show()
end

local function CreateRowRegions(row)
  if row.Name then return end
  row:EnableMouse(true)
  row.Background = row:CreateTexture(nil, "BACKGROUND")
  row.Background:SetAllPoints()
  row.Selected = row:CreateTexture(nil, "BORDER")
  row.Selected:SetAllPoints()
  row.Selected:SetColorTexture(0.65, 0.5, 0.12, 0.3)
  row.Highlight = row:CreateTexture(nil, "HIGHLIGHT")
  row.Highlight:SetAllPoints()
  row.Highlight:SetColorTexture(1, 1, 1, 0.08)
  row.ClassIcon = row:CreateTexture(nil, "ARTWORK")
  row.ClassIcon:SetSize(18, 18)
  row.ClassIcon:SetPoint("TOPLEFT", 7, -4)
  row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.Name:SetPoint("TOPLEFT", 30, -4)
  row.Name:SetPoint("TOPRIGHT", -125, -4)
  row.Name:SetJustifyH("LEFT")
  row.Name:SetWordWrap(false)
  row.ActivityName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.ActivityName:SetPoint("BOTTOMLEFT", 30, 4)
  row.ActivityName:SetPoint("BOTTOMRIGHT", -8, 4)
  row.ActivityName:SetJustifyH("LEFT")
  row.ActivityName:SetWordWrap(false)
  row.Composition = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.Composition:SetPoint("TOPRIGHT", -7, -4)
  row.Composition:SetWidth(112)
  row.Composition:SetJustifyH("RIGHT")
  row.Roles = {}
  for i = 1, 3 do
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(13, 13)
    icon:SetPoint("TOPRIGHT", -7 - (3 - i) * 15, -4)
    row.Roles[i] = icon
  end
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row:SetScript("OnClick", function(self, button)
    local view = addon._ggForeverBrowseView
    if self.dividerType then
      self.elementNode:ToggleCollapsed(nil, TreeDataProviderConstants.DoInvalidation)
      view.collapsed[self.dividerType] = self.elementNode.collapsed == true
      self.Name:SetText((self.elementNode.collapsed and "+ " or "- ") .. self.categoryLabel)
      return
    end
    local info = self.resultID and addon:LFG_API_GetSearchResultInfo(self.resultID)
    if not info or info.hasSelf or info.isDelisted then return end
    if button == "RightButton" then
      view.selectedResultID = self.resultID
      addon:ForeverBrowse_UpdateSelection()
      ShowMenu(self)
    else
      view.selectedResultID = view.selectedResultID ~= self.resultID and self.resultID or nil
      addon:ForeverBrowse_UpdateSelection()
    end
  end)
  row:SetScript("OnEnter", ShowTooltip)
  row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  row:SetScript("OnHide", function(self)
    if GameTooltip and type(GameTooltip.IsOwned) == "function" and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
  end)
end

function addon:ForeverBrowse_RenderRow(row, node)
  CreateRowRegions(row)
  local data = node.data
  row.elementNode, row.resultID, row.dividerType = node, data.resultID, data.dividerType
  row.Selected:Hide()
  row.ClassIcon:Hide()
  row.Composition:SetText("")
  row.Composition:ClearAllPoints()
  row.Composition:SetPoint("TOPRIGHT", -7, -4)
  row.ActivityName:SetText("")
  for _, icon in ipairs(row.Roles) do icon:Hide() end
  if data.dividerType then
    local types = LFGVanillaBrowseDividerType
    row.categoryLabel = data.dividerType == types.CategorySolo and LFG_LIST_CATEGORY_SOLO_PLAYERS or LFG_LIST_CATEGORY_GROUPS
    row.Name:SetText((node.collapsed and "+ " or "- ") .. row.categoryLabel)
    row.Name:SetTextColor(1, 0.82, 0)
    row.Background:SetColorTexture(0.18, 0.15, 0.1, 1)
    return
  end

  local info = self:LFG_API_GetSearchResultInfo(data.resultID)
  row.Name:SetText(info and info.leaderName or "...")
  row.Name:SetTextColor(1, 1, 1)
  row.Background:SetColorTexture(0.06, 0.055, 0.04, 1)
  if not info then return end
  local leader = self:LFG_API_GetSearchResultLeaderInfo(data.resultID)
  if leader and leader.classFilename then
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[leader.classFilename]
    if color then row.Name:SetTextColor(color.r, color.g, color.b) end
    row.ClassIcon:SetAtlas("groupfinder-icon-class-" .. string.lower(leader.classFilename))
    row.ClassIcon:Show()
  end
  if info.numMembers == 1 then
    local player = self:LFG_API_GetSearchResultPlayerInfo(data.resultID, 1)
    if player and player.level then
      row.Composition:ClearAllPoints()
      row.Composition:SetPoint("TOPRIGHT", -57, -4)
      row.Composition:SetText(player.level)
    end
    local roles = player and player.lfgRoles or (leader and leader.lfgRoles)
    local keys, atlases = { "tank", "healer", "dps" }, { "tank", "heal", "dps" }
    for i, key in ipairs(keys) do
      if roles and roles[key] then
        row.Roles[i]:SetAtlas("groupfinder-icon-role-micro-" .. atlases[i])
        row.Roles[i]:Show()
      end
    end
  else
    local counts = self:LFG_API_GetSearchResultMemberCounts(data.resultID)
    row.Composition:SetText(counts and string.format("%d / %d / %d", counts.TANK or 0, counts.HEALER or 0, counts.DAMAGER or 0) or (info.numMembers or ""))
  end
  local activities = {}
  for _, activityID in ipairs(info.activityIDs or {}) do
    local activity = self:LFG_API_GetActivityInfoTable(activityID)
    if activity then activities[#activities + 1] = activity.fullName or activity.shortName end
  end
  row.ActivityName:SetText(info.hasSelf and LFG_SELF_LISTING or table.concat(activities, ", "))
  if info.hasSelf then row.Background:SetColorTexture(0.08, 0.2, 0.1, 1) end
  if self.db and self.db.lfg_highlight and self.EvaluateSearchResultFlag and self:EvaluateSearchResultFlag(data.resultID) then
    row.Background:SetColorTexture(0.35, 0.07, 0.04, 1)
  elseif self.db and self.db.social_mark_lfg and self.LFG_EvaluateSearchResultSocial and self:LFG_EvaluateSearchResultSocial(data.resultID) then
    row.Background:SetColorTexture(0.06, 0.19, 0.25, 1)
  end
  if info.isDelisted then row.Name:SetTextColor(0.4, 0.4, 0.4) end
  row.Selected:SetShown(data.resultID == self._ggForeverBrowseView.selectedResultID)
end

function addon:ForeverBrowse_GetScrollBox(browse)
  if not browse or browse ~= LFGBrowseFrame or not browse.ScrollBox then return nil end
  if self._ggForeverBrowseView then return self._ggForeverBrowseView.ScrollBox end
  if not (ScrollUtil and type(ScrollUtil.InitScrollBoxListWithScrollBar) == "function"
      and type(CreateScrollBoxListTreeListView) == "function") then return nil end
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:Hide()
  frame:SetFrameStrata(browse:GetFrameStrata())
  frame:SetFrameLevel((self:SafeNumber(browse.ScrollBox:GetFrameLevel(), 10) or 10) + 10)
  frame:SetPoint("TOPLEFT", browse.ScrollBox, "TOPLEFT")
  frame:SetPoint("BOTTOMRIGHT", browse.ScrollBox, "BOTTOMRIGHT")
  frame:EnableMouse(true)
  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetColorTexture(0.025, 0.022, 0.017, 1)
  frame.ScrollBox = CreateFrame("Frame", nil, frame, "WowScrollBoxList")
  frame.ScrollBox:SetPoint("TOPLEFT")
  frame.ScrollBox:SetPoint("BOTTOMRIGHT")
  frame.ScrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
  if browse.ScrollBar then
    frame.ScrollBar:SetAllPoints(browse.ScrollBar)
  else
    frame.ScrollBox:SetPoint("BOTTOMRIGHT", -18, 0)
    frame.ScrollBar:SetPoint("TOPRIGHT", -2, -2)
    frame.ScrollBar:SetPoint("BOTTOMRIGHT", -2, 2)
  end
  local barBackground = frame.ScrollBar:CreateTexture(nil, "BACKGROUND")
  barBackground:SetPoint("TOPLEFT", -3, 3)
  barBackground:SetPoint("BOTTOMRIGHT", 3, -3)
  barBackground:SetColorTexture(0.025, 0.022, 0.017, 1)
  local view = CreateScrollBoxListTreeListView(0, 0, 0, 0, 0, 1)
  view:SetElementFactory(function(factory)
    factory("GroupGuardLFGBrowseRowTemplate", function(row, node) addon:ForeverBrowse_RenderRow(row, node) end)
  end)
  view:SetElementExtent(38)
  ScrollUtil.InitScrollBoxListWithScrollBar(frame.ScrollBox, frame.ScrollBar, view)
  frame.Empty = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.Empty:SetPoint("CENTER")
  frame.Empty:SetText(LFG_LIST_NO_RESULTS_FOUND or self:Tr("LFG_FILTERS"))
  frame.MessageButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.InviteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  for _, entry in ipairs({ { frame.MessageButton, browse.SendMessageButton, SEND_MESSAGE, WhisperSelected },
      { frame.InviteButton, browse.GroupInviteButton, GROUP_INVITE, InviteSelected } }) do
    local button, native = entry[1], entry[2]
    if native then button:SetAllPoints(native) else button:Hide() end
    button:SetText(entry[3])
    button:SetScript("OnClick", entry[4])
  end
  frame.collapsed = {}
  self._ggForeverBrowseView = frame
  return frame.ScrollBox
end

function addon:ForeverBrowse_Show(visibleCount)
  local view = self._ggForeverBrowseView
  if not view then return end
  view.Empty:SetShown(visibleCount == 0)
  self:ForeverBrowse_UpdateSelection()
  view:Show()
end

function addon:ForeverBrowse_Hide()
  local view = self._ggForeverBrowseView
  if view then view:Hide() end
end
