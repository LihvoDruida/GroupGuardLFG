-- The native LFG tooltip layout with readable snapshots. The game's global
-- tooltip and its unguarded nil/text-measurement renderer remain untouched.
local _, addon = ...

local function Metric(region, method, fallback)
  local fn = addon:SafeObjectMethod(region, method)
  if not fn then return fallback end
  local ok, value = pcall(fn, region)
  return ok and addon:SafeNumber(value, fallback) or fallback
end

local function Text(region, text, color)
  region:SetText(text or "")
  if color then region:SetTextColor(color.r, color.g, color.b) end
end

local function Format(pattern, ...)
  if type(pattern) ~= "string" then return "" end
  local ok, value = pcall(string.format, pattern, ...)
  return ok and value or pattern
end

local function Font(parent, name, object, text)
  local region = parent:CreateFontString(nil, "ARTWORK", object)
  parent[name] = region
  if text then region:SetText(text) end
  return region
end

local function GetTooltip()
  if addon._ggForeverNativeTooltip then return addon._ggForeverNativeTooltip end
  local f = CreateFrame("Frame", nil, UIParent, "TooltipBackdropTemplate")
  f:Hide()
  f:SetFrameStrata("TOOLTIP")
  f:SetClampedToScreen(true)
  if f.TooltipBackdropOnLoad then f:TooltipBackdropOnLoad() end
  f:SetSize(200, 1)
  Font(f, "Delisted", "GameFontRed", LFG_LIST_ENTRY_DELISTED):SetPoint("TOPLEFT", 11, -10)
  f.NewPlayerFriendlyIcon = f:CreateTexture(nil, "ARTWORK")
  f.NewPlayerFriendlyIcon:SetAtlas("newplayerchat-chaticon-newcomer", true)
  f.NewPlayerFriendlyIcon:SetPoint("TOPLEFT", 11, -10)
  Font(f, "NewPlayerFriendlyText", "GameFontGreen", LFG_LIST_NEW_PLAYER_FRIENDLY_HEADER):SetPoint("TOPLEFT", f.NewPlayerFriendlyIcon, "TOPRIGHT", 1, -2)
  f.LeaderIcon = f:CreateTexture(nil, "ARTWORK")
  f.LeaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
  f.LeaderIcon:SetSize(18, 18)
  f.Leader = CreateFrame("Frame", nil, f, "LFGBrowseSearchEntryTooltipGroupLeader")
  Font(f, "Comment", "GameFontNormalLeftLightGrey")
  f.Comment:SetJustifyV("TOP")
  f.Comment:SetJustifyH("LEFT")
  f.Comment:SetWordWrap(true)
  f.Comment:SetPoint("LEFT", f, "LEFT", 11, 0)
  f.Comment:SetPoint("RIGHT", f, "RIGHT", -11, 0)
  Font(f, "MemberCount", "GameFontNormal")
  if _G.LFGVANILLA_SETTING_MODERN_STYLE ~= false then
    Font(f, "VoiceChat", "GameFontNormal"):SetPoint("TOPLEFT", f.MemberCount, "BOTTOMLEFT", 0, -8)
  end
  Font(f, "CompletedEncounterHeader", "GameFontNormal", LFG_LIST_BOSSES_DEFEATED)
  f.members, f.activities, f.encounters = {}, {}, {}
  addon._ggForeverNativeTooltip = f
  return f
end

function addon:ForeverTooltip_Hide(row)
  local f = self._ggForeverNativeTooltip
  if f and (not row or f.ownerRow == row) then f:Hide(); f.ownerRow = nil end
  local view = self._ggForeverBrowseView
  if view and (not row or view.tooltipRow == row) then view.tooltipRow = nil end
end

local function Member(frame, info, solo)
  if not info or not info.name then frame:Hide(); return 0, 0 end
  local color = info.classFilename and RAID_CLASS_COLORS[info.classFilename] or NORMAL_FONT_COLOR
  frame.Name:SetWidth(0)
  Text(frame.Name, info.name, color)
  Text(frame.Level, info.level and ((LEVEL_ABBR or "") .. " " .. info.level) or "")
  local roles = solo and info.lfgRoles
  local assigned = info.assignedRole
  if type(LFGBrowseUtil_MapRoleStatesToRoleIcons) == "function" then
    LFGBrowseUtil_MapRoleStatesToRoleIcons(frame.Roles,
      roles and roles.tank == true or (not solo and assigned == "TANK"),
      roles and roles.healer == true or (not solo and assigned == "HEALER"),
      roles and roles.dps == true or (not solo and assigned == "DAMAGER"), solo)
  end
  local roleWidth = 0
  for _, icon in ipairs(frame.Roles) do if icon:IsShown() then roleWidth = roleWidth + 16 end end
  frame:Show()
  return Metric(frame.Name, "GetWidth", 160), Metric(frame.Level, "GetWidth", 40) + 4 + roleWidth
end

function addon:ForeverTooltip_Show(row)
  local id = row.resultID
  if not id then self:ForeverTooltip_Hide(row); return end
  if self.LFG_ForgetSearchResult then self:LFG_ForgetSearchResult(id) end
  local info = self:LFG_API_GetSearchResultInfo(id)
  if not info or not info.numMembers then self:ForeverTooltip_Hide(row); return end
  local f = GetTooltip()
  f.ownerRow = row
  if self._ggForeverBrowseView then self._ggForeverBrowseView.tooltipRow = row end
  for _, pool in ipairs({ f.members, f.activities, f.encounters }) do for _, region in ipairs(pool) do region:Hide() end end
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", row, "TOPRIGHT", 8, 38)
  f.Delisted:SetShown(info.isDelisted == true)
  local friendly = info.newPlayerFriendly == true and not info.isDelisted
  f.NewPlayerFriendlyIcon:SetShown(friendly)
  f.NewPlayerFriendlyText:SetShown(friendly)
  f.LeaderIcon:ClearAllPoints()
  if friendly then f.LeaderIcon:SetPoint("TOPLEFT", f.NewPlayerFriendlyIcon, "BOTTOMLEFT", 0, -5)
  elseif info.isDelisted then f.LeaderIcon:SetPoint("TOPLEFT", f.Delisted, "BOTTOMLEFT", 0, -8)
  else f.LeaderIcon:SetPoint("TOPLEFT", f, "TOPLEFT", 11, -10) end
  local solo = info.numMembers == 1
  f.LeaderIcon:SetShown(not solo)
  f.Leader:ClearAllPoints()
  f.Leader:SetPoint("TOPLEFT", f.LeaderIcon, solo and "TOPLEFT" or "TOPRIGHT", 0, -2)
  local leader = self:LFG_API_GetSearchResultLeaderInfo(id)
  local maxName, maxRole = Member(f.Leader, leader, solo)
  if not leader or not leader.name then f.LeaderIcon:Hide() end
  local last, memberCount = f.Leader, 0
  if info.numMembers <= 10 then
    for index = 1, info.numMembers do
      local player = self:LFG_API_GetSearchResultPlayerInfo(id, index)
      if player and player.name and not player.isLeader and (not leader or player.name ~= leader.name) then
        memberCount = memberCount + 1
        local line = f.members[memberCount]
        if not line then line = CreateFrame("Frame", nil, f, "LFGBrowseSearchEntryTooltipGroupMember"); f.members[memberCount] = line end
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, 0)
        local nameWidth, roleWidth = Member(line, player, false)
        maxName, maxRole = math.max(maxName, nameWidth), math.max(maxRole, roleWidth)
        last = line
      end
    end
  end
  local maxWidth = maxName + 4 + maxRole + (f.LeaderIcon:IsShown() and 18 or 0)
  if maxName > 0 then
    f.Leader.Name:SetWidth(maxName)
    for index = 1, memberCount do f.members[index].Name:SetWidth(maxName) end
  end
  f.Comment:SetPoint("TOP", last, "BOTTOM", 0, -8)
  local comment = info.comment and info.comment ~= ""
  f.Comment:SetShown(comment == true)
  f.MemberCount:ClearAllPoints()
  if comment then
    Text(f.Comment, Format(LFG_LIST_COMMENT_FORMAT, info.comment))
    f.MemberCount:SetPoint("TOPLEFT", f.Comment, "BOTTOMLEFT", 0, -8)
  else f.MemberCount:SetPoint("TOPLEFT", f.Comment, "TOPLEFT", 0, 0) end
  local counts = self:LFG_API_GetSearchResultMemberCounts(id)
  if solo then Text(f.MemberCount, Format(LFG_LIST_TOOLTIP_MEMBERS_SIMPLE, info.numMembers))
  elseif counts and counts.TANK and counts.HEALER and counts.DAMAGER then
    Text(f.MemberCount, Format(LFG_LIST_TOOLTIP_MEMBERS, info.numMembers, counts.TANK, counts.HEALER, counts.DAMAGER))
  else Text(f.MemberCount, Format(LFG_LIST_TOOLTIP_MEMBERS_SIMPLE, info.numMembers)) end
  local modes = Enum.LFGEntryVoiceMode or {}
  local labels = { [modes.None or 0] = VOICE_CHAT_MODE_NONE, [modes.Legacy or 1] = VOICE_CHAT_MODE_LEGACY,
    [modes.Discord or 2] = VOICE_CHAT_MODE_DISCORD, [modes.Custom or 3] = VOICE_CHAT_MODE_CUSTOM }
  local voice = f.VoiceChat and labels[info.voiceMode or modes.None or 0]
  if f.VoiceChat then f.VoiceChat:SetShown(voice ~= nil) end
  if voice then
    Text(f.VoiceChat, Format(VOICE_CHAT_MODE_FORMAT, voice))
    maxWidth = math.max(maxWidth, Metric(f.VoiceChat, "GetWidth", 160))
  end
  local anchor = f.VoiceChat or f.MemberCount
  local groups, order, active = {}, {}, {}
  local entry = self:LFG_API_GetActiveEntryInfo()
  local activeIDs = self:SafeTableField(entry, "activityIDs")
  if self:SafeCanAccessTable(activeIDs) then
    for index = 1, #activeIDs do
      local activityID = self:SafeNumber(self:SafeTableField(activeIDs, index), nil)
      if activityID then active[activityID] = true end
    end
  end
  for _, activityID in ipairs(info.activityIDs) do
    local activity = self:LFG_API_GetActivityInfoTable(activityID)
    local group = activity and activity.groupID or 0
    if not groups[group] then groups[group] = {}; order[#order + 1] = group end
    groups[group][#groups[group] + 1] = activityID
  end
  if type(LFGUtil_SortActivityGroupIDs) == "function" then pcall(LFGUtil_SortActivityGroupIDs, order) else table.sort(order) end
  local lineCount, lastActivity = 0, nil
  local function ActivityLine(text, color, gap)
    lineCount = lineCount + 1
    local line = f.activities[lineCount]
    if not line then line = f:CreateFontString(nil, "ARTWORK", "LFGBrowseSearchEntryTooltipActivityNameTemplate"); f.activities[lineCount] = line end
    line:ClearAllPoints()
    line:SetWidth(0)
    Text(line, text, color)
    maxWidth = math.max(maxWidth, Metric(line, "GetWidth", 180))
    line:SetPoint("TOPLEFT", lastActivity or anchor, "BOTTOMLEFT", 0, lastActivity and -(gap or 0) or -8)
    line:SetPoint("RIGHT", f, "RIGHT", -11, 0)
    line:Show()
    lastActivity = line
    return line
  end
  for index, group in ipairs(order) do
    local header, matched = nil, false
    if group ~= 0 then header = ActivityLine(self:LFG_API_GetActivityGroupInfo(group) or "", GRAY_FONT_COLOR, index > 1 and 6 or 0) end
    for _, activityID in ipairs(groups[group]) do
      local name = self:ForeverBrowse_ActivityName(activityID)
      if name ~= "" then
        local match = active[activityID] == true
        matched = matched or match
        ActivityLine(group == 0 and name or Format(LFG_LIST_INDENT, name), match and BRIGHTBLUE_FONT_COLOR or GRAY_FONT_COLOR)
      end
    end
    if header then local c = matched and BRIGHTBLUE_FONT_COLOR or GRAY_FONT_COLOR; header:SetTextColor(c.r, c.g, c.b) end
  end
  f.CompletedEncounterHeader:Hide()
  local encounterCount = 0
  if #info.activityIDs == 1 and lastActivity and C_LFGList and type(C_LFGList.GetSearchResultEncounterInfo) == "function" then
    local ok, encounters = pcall(C_LFGList.GetSearchResultEncounterInfo, id)
    if ok and self:SafeCanAccessTable(encounters) then
      local previous = f.CompletedEncounterHeader
      for index = 1, #encounters do
        local name = self:SafeText(self:SafeTableField(encounters, index), nil)
        if name then
          encounterCount = encounterCount + 1
          local line = f.encounters[encounterCount]
          if not line then line = f:CreateFontString(nil, "ARTWORK", "LFGBrowseSearchEntryTooltipCompletedEncounterTemplate"); f.encounters[encounterCount] = line end
          line:ClearAllPoints(); line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, 0)
          Text(line, name, RED_FONT_COLOR); line:Show(); previous = line
        end
      end
      if encounterCount > 0 then f.CompletedEncounterHeader:SetPoint("TOPLEFT", lastActivity, "BOTTOMLEFT", 0, -8); f.CompletedEncounterHeader:Show() end
    end
  end
  f:SetWidth(math.max(200, maxWidth + 22))
  local height = 40 + Metric(f.Leader, "GetHeight", 14) + memberCount * 14 + Metric(f.MemberCount, "GetHeight", 14)
  if info.isDelisted then height = height + Metric(f.Delisted, "GetHeight", 14) + 8 end
  if friendly then height = height + Metric(f.NewPlayerFriendlyText, "GetHeight", 14) + 8 end
  if comment then height = height + Metric(f.Comment, "GetHeight", 14) + 8 end
  if voice then height = height + Metric(f.VoiceChat, "GetHeight", 14) + 8 end
  for index = 1, lineCount do height = height + Metric(f.activities[index], "GetHeight", 14) end
  height = height + 6 * math.max(0, #order - 1)
  if encounterCount > 0 then height = height + Metric(f.CompletedEncounterHeader, "GetHeight", 14) + 8 + encounterCount * 14 end
  f:SetHeight(height)
  f:Show()
end
