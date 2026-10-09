-- GroupGuard LFG — search filters for Retail 12.x and WoW Forever
-- Two independent filter blocks:
--   1) dungeon groups: role needs AND roles already present
--   2) solo players: class AND role AND level (OR inside class/role sets)
local addonName, addon = ...

local type, pairs, ipairs, tonumber = type, pairs, ipairs, tonumber
local tinsert = table.insert
local table_sort = table.sort

local DUNGEON_CATEGORY_ID = 2
local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }
local ROLE_ATLAS = {
  TANK = "groupfinder-icon-role-micro-tank",
  HEALER = "groupfinder-icon-role-micro-heal",
  DAMAGER = "groupfinder-icon-role-micro-dps",
}
local ROLE_TEXT_KEY = {
  TANK = "LFG_FILTER_TANK",
  HEALER = "LFG_FILTER_HEALER",
  DAMAGER = "LFG_FILTER_DAMAGE",
}

local FILTER_BUTTON_SIZE = 16
local FILTER_BUTTON_ICON_SIZE = 16
local FILTER_BUTTON_VERTICAL_GAP = 5
local FILTER_PANEL_SIDE_GAP = 8

local FILTER_ICON_TEXTURE = "Interface\\AddOns\\GroupGuardLFG\\Media\\filter_funnel.tga"

local function SafeShown(frame)
  if not frame or type(frame.IsShown) ~= "function" then return false end
  local ok, shown = pcall(frame.IsShown, frame)
  return ok and shown == true
end

local function SafeVisible(frame)
  if not frame then return false end
  if type(frame.IsVisible) == "function" then
    local ok, visible = pcall(frame.IsVisible, frame)
    if ok then return visible == true end
  end
  return SafeShown(frame)
end

local function HasAnySelected(tbl)
  if type(tbl) ~= "table" then return false end
  for _, value in pairs(tbl) do
    if value == true then return true end
  end
  return false
end

local function SetContains(tbl, key)
  return type(tbl) == "table" and key ~= nil and tbl[key] == true
end

local function CountSelected(tbl)
  local count = 0
  if type(tbl) == "table" then
    for _, value in pairs(tbl) do if value == true then count = count + 1 end end
  end
  return count
end

local function NormalizeLevelRange(minLevel, maxLevel)
  minLevel = math.max(0, math.floor(tonumber(minLevel) or 0))
  maxLevel = math.max(0, math.floor(tonumber(maxLevel) or 0))
  if minLevel > 0 and maxLevel > 0 and minLevel > maxLevel then
    minLevel, maxLevel = maxLevel, minLevel
  end
  return minLevel, maxLevel
end

local function CopyArray(source)
  local out = {}
  if type(source) ~= "table" then return out end
  for i = 1, #source do out[i] = source[i] end
  return out
end

-- Blizzard's Forever browser rebuilds a TreeDataProvider in UpdateResults().
-- The function calls RemoveDataProvider() before SetDataProvider(...,
-- RetainScrollPosition), so a second rebuild from an addon can still snap the
-- list to the top. Preserve scroll state explicitly: exact derived offset first,
-- percentage as a fallback. This follows the modern ScrollBox API instead of
-- manipulating scrollbar textures or legacy FauxScrollFrame state.
local function CaptureScrollState(scrollBox)
  if not scrollBox then return nil end
  local state = {}

  if type(scrollBox.GetDerivedScrollOffset) == "function" then
    local ok, value = pcall(scrollBox.GetDerivedScrollOffset, scrollBox)
    value = ok and tonumber(value) or nil
    if value then state.offset = math.max(0, value) end
  end

  if type(scrollBox.GetScrollPercentage) == "function" then
    local ok, value = pcall(scrollBox.GetScrollPercentage, scrollBox)
    value = ok and tonumber(value) or nil
    if value then
      if value < 0 then value = 0 elseif value > 1 then value = 1 end
      state.percentage = value
    end
  end

  if state.offset == nil and state.percentage == nil then return nil end
  return state
end

local function RestoreScrollState(scrollBox, state)
  if not scrollBox or type(state) ~= "table" then return end
  local noInterpolation = ScrollBoxConstants and ScrollBoxConstants.NoScrollInterpolation or nil

  -- Prefer the exact pixel offset. It is more stable than percentage when the
  -- number of LFG rows changes during a refresh.
  if state.offset ~= nil and type(scrollBox.ScrollToOffset) == "function" then
    local ok = pcall(scrollBox.ScrollToOffset, scrollBox, state.offset, noInterpolation)
    if ok then return end
  end

  if state.percentage ~= nil and type(scrollBox.SetScrollPercentage) == "function" then
    local ok = pcall(scrollBox.SetScrollPercentage, scrollBox, state.percentage, noInterpolation)
    if ok then return end
    pcall(scrollBox.SetScrollPercentage, scrollBox, state.percentage)
  end
end

local function UpdateResultsPreservingScroll(searchFrame)
  if not searchFrame or type(searchFrame.UpdateResults) ~= "function" then return false end
  local scrollBox = searchFrame.ScrollBox
  local scrollState = CaptureScrollState(scrollBox)
  local ok = pcall(searchFrame.UpdateResults, searchFrame)
  if ok then RestoreScrollState(scrollBox, scrollState) end
  return ok
end

function addon:LFGFilters_HasActiveFilters()
  if not self.db or self.db.lfg_filters_enabled == false then return false end
  return HasAnySelected(self.db.lfg_filter_group_roles)
      or HasAnySelected(self.db.lfg_filter_group_has_roles)
      or HasAnySelected(self.db.lfg_filter_player_roles)
      or HasAnySelected(self.db.lfg_filter_player_classes)
      or (tonumber(self.db.lfg_filter_player_min_level) or 0) > 0
      or (tonumber(self.db.lfg_filter_player_max_level) or 0) > 0
end

function addon:LFGFilters_NeedsPresentation()
  if not self.db then return false end
  if self:LFGFilters_HasActiveFilters() then return true end
  return self.IsForeverClient and self:IsForeverClient() and self.db.lfg_filter_social_priority ~= false
end

function addon:LFGFilters_GetAvailableClasses()
  local out, seen = {}, {}

  -- Prefer the client API over the static class ordering. Forever shares a lot
  -- of the modern runtime, so a global class list can contain classes that are
  -- not actually available on that game flavor.
  if type(GetNumClasses) == "function" and type(GetClassInfo) == "function" then
    local okCount, count = pcall(GetNumClasses)
    count = okCount and tonumber(count) or 0
    for i = 1, count do
      local ok, name, classFile = pcall(GetClassInfo, i)
      if ok and type(classFile) == "string" and classFile ~= "" and not seen[classFile] then
        out[#out + 1] = { file = classFile, name = type(name) == "string" and name or classFile }
        seen[classFile] = true
      end
    end
  end

  if #out == 0 and type(CLASS_SORT_ORDER) == "table" then
    for _, classFile in ipairs(CLASS_SORT_ORDER) do
      if type(classFile) == "string" and classFile ~= "" and not seen[classFile] then
        local localized = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile])
          or (LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[classFile])
          or classFile
        out[#out + 1] = { file = classFile, name = localized }
        seen[classFile] = true
      end
    end
  end
  return out
end

function addon:LFGFilters_IsDungeonResult(info, searchFrame)
  if type(info) ~= "table" then return false end
  local activityIDs = info.activityIDs
  if type(activityIDs) == "table" then
    for _, activityID in ipairs(activityIDs) do
      local activity = self.LFG_API_GetActivityInfoTable and self:LFG_API_GetActivityInfoTable(activityID) or nil
      if activity and (activity.useDungeonRoleExpectations == true or activity.categoryID == DUNGEON_CATEGORY_ID) then return true end
    end
    if #activityIDs > 0 then return false end
  end

  -- Fallback for a client that withholds activityIDs but exposes the current category.
  local categoryID = searchFrame and self:SafeNumber(self:SafeObjectField(searchFrame, "categoryID"), nil) or nil
  if categoryID then return categoryID == DUNGEON_CATEGORY_ID end
  if searchFrame and searchFrame.CategoryDropdown and type(searchFrame.CategoryDropdown.GetValue) == "function" then
    local ok, value = pcall(searchFrame.CategoryDropdown.GetValue, searchFrame.CategoryDropdown)
    value = ok and self:SafeNumber(value, nil) or nil
    if value then return value == DUNGEON_CATEGORY_ID end
  end
  return false
end

function addon:LFGFilters_GroupNeedsRole(resultID, role, info)
  if not (self.HasClientCapability and self:HasClientCapability("lfgSearchMemberCounts")) then return nil end
  local counts = self.LFG_API_GetSearchResultMemberCounts and self:LFG_API_GetSearchResultMemberCounts(resultID) or nil
  if type(counts) ~= "table" then return nil end

  local remainingKey = role .. "_REMAINING"
  local remaining = tonumber(counts[remainingKey])
  if remaining ~= nil then return remaining > 0 end

  -- Forever exposes *_REMAINING today, but keep a safe fallback for adjacent
  -- clients/backports that only expose current role counts.
  local current = tonumber(counts[role])
  if current == nil then return nil end

  local target = role == "DAMAGER" and 3 or 1
  if role == "DAMAGER" and info and type(info.activityIDs) == "table" and info.activityIDs[1] then
    local activity = self.LFG_API_GetActivityInfoTable and self:LFG_API_GetActivityInfoTable(info.activityIDs[1]) or nil
    local maxPlayers = activity and (tonumber(activity.maxNumPlayers) or tonumber(activity.maxPlayers)) or nil
    if maxPlayers and maxPlayers >= 3 then target = math.max(1, maxPlayers - 2) end
  end
  return current < target
end

function addon:LFGFilters_GroupHasRole(resultID, role)
  if not (self.HasClientCapability and self:HasClientCapability("lfgSearchMemberCounts")) then return nil end
  local counts = self.LFG_API_GetSearchResultMemberCounts and self:LFG_API_GetSearchResultMemberCounts(resultID) or nil
  if type(counts) ~= "table" then return nil end

  local current = tonumber(counts[role])
  if current ~= nil then return current > 0 end

  local leaderKey = "LEADER_ROLE_" .. role
  if counts[leaderKey] ~= nil then return counts[leaderKey] == true end
  return nil
end

function addon:LFGFilters_MatchesGroupBlock(resultID, info)
  local needsSelected = self.db and self.db.lfg_filter_group_roles
  local hasSelected = self.db and self.db.lfg_filter_group_has_roles
  if not HasAnySelected(needsSelected) and not HasAnySelected(hasSelected) then return true end

  -- Dungeon role selections are combinations, not alternatives. Tank + Healer
  -- means BOTH conditions must be true. Unknown streamed data stays fail-open.
  for _, role in ipairs(ROLE_ORDER) do
    if needsSelected and needsSelected[role] == true then
      local needs = self:LFGFilters_GroupNeedsRole(resultID, role, info)
      if needs ~= nil and not needs then return false end
    end
    if hasSelected and hasSelected[role] == true then
      local hasRole = self:LFGFilters_GroupHasRole(resultID, role)
      if hasRole ~= nil and not hasRole then return false end
    end
  end

  return true
end

function addon:LFGFilters_PlayerHasRole(playerInfo, selectedRoles)
  if not HasAnySelected(selectedRoles) then return true end
  if type(playerInfo) ~= "table" then return nil end

  local assigned = playerInfo.assignedRole
  if type(assigned) == "string" and SetContains(selectedRoles, assigned) then return true end

  local roles = playerInfo.lfgRoles
  if type(roles) == "table" then
    if selectedRoles.TANK and roles.tank == true then return true end
    if selectedRoles.HEALER and roles.healer == true then return true end
    if selectedRoles.DAMAGER and roles.dps == true then return true end
    return false
  end
  if type(assigned) == "string" and assigned ~= "" and assigned ~= "NONE" then return false end
  return nil
end

function addon:LFGFilters_MatchesPlayerBlock(resultID)
  local classes = self.db and self.db.lfg_filter_player_classes
  local roles = self.db and self.db.lfg_filter_player_roles
  local minLevel, maxLevel = NormalizeLevelRange(
    self.db and self.db.lfg_filter_player_min_level,
    self.db and self.db.lfg_filter_player_max_level
  )
  local classActive = HasAnySelected(classes)
  local roleActive = HasAnySelected(roles)
  local levelActive = minLevel > 0 or maxLevel > 0
  if not classActive and not roleActive and not levelActive then return true end

  if not (self.HasClientCapability and self:HasClientCapability("lfgSearchPlayerInfo")) then return true end
  local player = self.LFG_API_GetSearchResultPlayerInfo and self:LFG_API_GetSearchResultPlayerInfo(resultID, 1) or nil
  if type(player) ~= "table" then return true end -- fail open while data streams in

  local classMatches = true
  if classActive then
    local classFile = player.classFilename or player.classFileName or player.classFile
    classMatches = type(classFile) == "string" and classes[classFile] == true
  end

  local roleMatches = self:LFGFilters_PlayerHasRole(player, roles)
  if roleMatches == nil then roleMatches = true end

  local levelMatches = true
  if levelActive then
    local level = tonumber(player.level)
    if level then
      if minLevel > 0 and level < minLevel then levelMatches = false end
      if maxLevel > 0 and level > maxLevel then levelMatches = false end
    end
  end

  return classMatches and roleMatches and levelMatches
end

function addon:LFGFilters_ResultMatches(resultID, searchFrame)
  if not self:LFGFilters_HasActiveFilters() then return true end
  resultID = self:SafeNumber(resultID, nil)
  if not resultID then return true end

  local info = self.LFG_API_GetSearchResultInfo and self:LFG_API_GetSearchResultInfo(resultID) or nil
  if type(info) ~= "table" then return true end
  if info.hasSelf == true then return true end -- never hide the player's own listing

  local numMembers = tonumber(info.numMembers)
  if not numMembers then return true end

  if numMembers <= 1 then
    return self:LFGFilters_MatchesPlayerBlock(resultID)
  end

  if (HasAnySelected(self.db and self.db.lfg_filter_group_roles)
      or HasAnySelected(self.db and self.db.lfg_filter_group_has_roles))
      and self:LFGFilters_IsDungeonResult(info, searchFrame) then
    return self:LFGFilters_MatchesGroupBlock(resultID, info)
  end
  return true
end

local function GetForeverResultIDFromRow(row)
  if not row then return nil end
  local direct = nil
  if addon and addon.SafeObjectField then
    direct = addon:SafeObjectField(row, "resultID")
      or addon:SafeObjectField(row, "resultId")
      or addon:SafeObjectField(row, "searchResultID")
      or addon:SafeObjectField(row, "searchResultId")
  end
  direct = addon and addon.SafeNumber and addon:SafeNumber(direct, nil) or tonumber(direct)
  if direct then return direct end

  local ed = addon and addon.SafeGetElementData and addon:SafeGetElementData(row) or nil
  if type(ed) ~= "table" then return nil end
  for _, key in ipairs({ "resultID", "resultId", "searchResultID", "searchResultId", "id", "ID" }) do
    local value = ed[key]
    value = addon and addon.SafeNumber and addon:SafeNumber(value, nil) or tonumber(value)
    if value then return value end
  end
  return nil
end

local function EnumerateForeverRows(scrollBox)
  local rows = {}
  if not scrollBox then return rows end

  if type(scrollBox.ForEachFrame) == "function" then
    pcall(scrollBox.ForEachFrame, scrollBox, function(row)
      if row then rows[#rows + 1] = row end
    end)
    return rows
  end

  if type(scrollBox.GetFrames) == "function" then
    local ok, frames = pcall(scrollBox.GetFrames, scrollBox)
    if ok and type(frames) == "table" then
      for _, row in ipairs(frames) do rows[#rows + 1] = row end
      return rows
    end
  end

  return rows
end

-- Forever/Camelot calls C_LFGList.Search() from Blizzard's protected browse
-- path. Never write addon-filtered values back into LFGBrowseFrame.results or
-- totalResults: Blizzard reads those fields later and a tainted value can make
-- the next completely native category click fail with ADDON_ACTION_BLOCKED.
-- Apply the custom filter only to already-created row presentation instead.
local function GetForeverDividerTypes()
  local types = _G.LFGVanillaBrowseDividerType
  if type(types) == "table" then
    return types.CategorySolo or 1, types.CategoryGroup or 2
  end
  return 1, 2
end

function addon:LFGFilters_GetSocialPriority(resultID, info)
  if type(info) ~= "table" then return 2 end
  if info.hasSelf == true then return 0 end
  if not self.db or self.db.lfg_filter_social_priority == false then return 2 end

  if (tonumber(info.numBNetFriends) or 0) > 0
      or (tonumber(info.numCharFriends) or 0) > 0
      or (tonumber(info.numGuildMates) or 0) > 0 then
    return 1
  end

  local function isSocial(name)
    if type(name) ~= "string" or name == "" then return false end
    if self.IsFriendName and self:IsFriendName(name) then return true end
    if self.IsGuildMemberName and self:IsGuildMemberName(name) then return true end
    return false
  end

  local leader = self.LFG_API_GetSearchResultLeaderInfo and self:LFG_API_GetSearchResultLeaderInfo(resultID) or nil
  if type(leader) == "table" and isSocial(leader.name) then return 1 end

  if tonumber(info.numMembers) == 1 then
    local player = self.LFG_API_GetSearchResultPlayerInfo and self:LFG_API_GetSearchResultPlayerInfo(resultID, 1) or nil
    if type(player) == "table" and isSocial(player.name) then return 1 end
  end
  return 2
end

function addon:LFGFilters_GetForeverPresentationState(resultID, searchFrame, index)
  local info = self.LFG_API_GetSearchResultInfo and self:LFG_API_GetSearchResultInfo(resultID) or nil
  if type(info) ~= "table" then
    return { show = false, category = nil, priority = 2, index = index or 0 }, nil
  end

  local show = (not self:LFGFilters_HasActiveFilters()) or self:LFGFilters_ResultMatches(resultID, searchFrame)
  if info.hasSelf == true then show = true end

  local soloDivider, groupDivider = GetForeverDividerTypes()
  local numMembers = tonumber(info.numMembers)
  local category = numMembers and (numMembers <= 1 and soloDivider or groupDivider) or nil
  return {
    show = show == true,
    category = category,
    priority = self:LFGFilters_GetSocialPriority(resultID, info),
    index = index or 0,
  }, info
end

local function SamePresentationState(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  return a.show == b.show and a.category == b.category and a.priority == b.priority
end

local function SortPresentationElements(elements, socialPriorityEnabled)
  if not socialPriorityEnabled or #elements < 2 then return end
  table_sort(elements, function(a, b)
    if a.priority ~= b.priority then return a.priority < b.priority end
    return a.index < b.index
  end)
end

-- Rebuild only Forever's visual ScrollBox provider. The authoritative search
-- state (LFGBrowseFrame.results / totalResults) remains Blizzard-owned and is
-- never rewritten by GroupGuard. This removes non-matching entries from the
-- rendered tree completely, so they consume no row height and create no holes.
function addon:LFGFilters_ApplyForeverPresentation(searchFrame)
  if not searchFrame or searchFrame ~= _G.LFGBrowseFrame then return false end
  if searchFrame.searching then return false end
  local scrollBox = searchFrame.ScrollBox
  if not scrollBox or type(CreateTreeDataProvider) ~= "function" then return false end

  local results = searchFrame.results
  if type(results) ~= "table" then return false end

  local soloDivider, groupDivider = GetForeverDividerTypes()
  local useDividers = _G.LFGVANILLA_SETTING_BROWSE_SHOW_COLLAPSIBLE_CATEGORIES ~= false
  local dataProvider = CreateTreeDataProvider()
  local visibleCount = 0

  -- Forever search results are not guaranteed to arrive grouped by result type.
  -- Keep one bucket per native category and emit each divider at most once.
  local flatElements = {}
  local groupElements = {}
  local soloElements = {}
  local uncategorizedElements = {}
  local seenResultIDs = {}
  local stateByResult = {}

  for index = 1, #results do
    local resultID = self:SafeNumber(results[index], nil)
    if resultID and not seenResultIDs[resultID] then
      seenResultIDs[resultID] = true
      local state = self:LFGFilters_GetForeverPresentationState(resultID, searchFrame, index)
      stateByResult[resultID] = state
      if state.show then
        local element = { index = index, resultID = resultID, category = state.category, priority = state.priority }

        visibleCount = visibleCount + 1
        flatElements[#flatElements + 1] = element

        if state.category == groupDivider then
          groupElements[#groupElements + 1] = element
        elseif state.category == soloDivider then
          soloElements[#soloElements + 1] = element
        else
          uncategorizedElements[#uncategorizedElements + 1] = element
        end
      end
    end
  end

  local socialPriorityEnabled = self.db and self.db.lfg_filter_social_priority ~= false
  SortPresentationElements(groupElements, socialPriorityEnabled)
  SortPresentationElements(soloElements, socialPriorityEnabled)
  SortPresentationElements(uncategorizedElements, socialPriorityEnabled)
  SortPresentationElements(flatElements, socialPriorityEnabled)

  if useDividers then
    -- Match Forever's native visual order: Groups first, Players second.
    -- A self listing still belongs to its real category; hasSelf only forces it
    -- visible and no longer bypasses category classification.
    for _, element in ipairs(uncategorizedElements) do
      dataProvider:Insert(element)
    end

    if #groupElements > 0 then
      local groupSubtree = dataProvider:Insert({ index = nil, dividerType = groupDivider })
      for _, element in ipairs(groupElements) do groupSubtree:Insert(element) end
    end

    if #soloElements > 0 then
      local soloSubtree = dataProvider:Insert({ index = nil, dividerType = soloDivider })
      for _, element in ipairs(soloElements) do soloSubtree:Insert(element) end
    end
  else
    -- With Blizzard category dividers disabled, retain the original result order.
    for _, element in ipairs(flatElements) do dataProvider:Insert(element) end
  end

  -- Selection can point to an element from the old provider after a filter
  -- change. Clear it before swapping only the presentation tree.
  if searchFrame.selectionBehavior and type(searchFrame.selectionBehavior.ClearSelections) == "function" then
    pcall(searchFrame.selectionBehavior.ClearSelections, searchFrame.selectionBehavior)
  end

  local retain = _G.ScrollBoxConstants and _G.ScrollBoxConstants.RetainScrollPosition or nil
  self._ggForeverProviderApplying = true
  local ok = pcall(scrollBox.SetDataProvider, scrollBox, dataProvider, retain)
  self._ggForeverProviderApplying = false
  if not ok then return false end

  self._ggForeverPresentationState = stateByResult
  self._ggForeverRefreshPending = false

  -- Native totalResults intentionally remains untouched. This status only
  -- describes the filtered presentation and is never consumed by Search().
  self._ggForeverVisibleResults = visibleCount
  self._ggForeverPresentationProvider = dataProvider
  self._ggForeverPresentationResults = results
  if searchFrame.NoResultsFound then
    if visibleCount == 0 and not searchFrame.searchFailed then
      searchFrame.NoResultsFound:Show()
      if type(searchFrame.NoResultsFound.SetText) == "function" then
        searchFrame.NoResultsFound:SetText(_G.LFG_LIST_NO_RESULTS_FOUND or self:Tr("LFG_FILTERS_NO_MATCHES"))
      end
    else
      searchFrame.NoResultsFound:Hide()
    end
  end
  return true
end

-- Return a count only for our currently installed visual provider and result list.
function addon:LFGFilters_GetForeverVisibleCount()
  local browse = _G.LFGBrowseFrame
  if not browse or not SafeVisible(browse) then return nil, "browse hidden" end
  if browse.searching or self._ggForeverRefreshPending then return nil, "presentation pending" end
  if self._ggForeverPresentationResults ~= browse.results then return nil, "result list changed" end
  local scrollBox = browse.ScrollBox
  if not scrollBox or type(scrollBox.GetDataProvider) ~= "function" then return nil, "provider unavailable" end
  local ok, provider = pcall(scrollBox.GetDataProvider, scrollBox)
  if not ok or provider ~= self._ggForeverPresentationProvider or provider == nil then return nil, "provider replaced" end
  return self._ggForeverVisibleResults
end

function addon:LFGFilters_ScheduleForeverPresentation(searchFrame)
  searchFrame = searchFrame or _G.LFGBrowseFrame
  if not searchFrame then return end
  if not SafeVisible(searchFrame) then
    self._ggForeverRefreshPending = true
    return
  end

  self._ggForeverPresentationToken = (self._ggForeverPresentationToken or 0) + 1
  local token = self._ggForeverPresentationToken
  local function apply()
    if addon and addon._ggForeverPresentationToken == token then
      addon:LFGFilters_ApplyForeverPresentation(searchFrame)
    end
  end
  if C_Timer and type(C_Timer.After) == "function" then
    C_Timer.After(0, apply)
    C_Timer.After(0.05, apply)
  else
    apply()
  end
end

function addon:LFGFilters_HandleForeverResultUpdated(resultID)
  resultID = self:SafeNumber(resultID, nil)
  local searchFrame = _G.LFGBrowseFrame
  if not resultID or not searchFrame then return false end

  if self.LFG_ForgetSearchResult then self:LFG_ForgetSearchResult(resultID) end
  if not SafeVisible(searchFrame) then
    self._ggForeverRefreshPending = true
    return true
  end

  local oldState = self._ggForeverPresentationState and self._ggForeverPresentationState[resultID] or nil
  local index = oldState and oldState.index or 0
  local newState = self:LFGFilters_GetForeverPresentationState(resultID, searchFrame, index)
  if not SamePresentationState(oldState, newState) then
    self:LFGFilters_ScheduleForeverPresentation(searchFrame)
  else
    self._ggForeverPresentationState[resultID] = newState
  end
  return true
end

function addon:LFGFilters_FilterFrameResults(searchFrame)
  if self._lfgFilterApplying then return end
  if not searchFrame then return end

  -- Forever must stay completely out of LFGBrowseFrame's data model. The
  -- protected Search() path can consume these frame fields on a later click.
  if searchFrame == _G.LFGBrowseFrame then
    self:LFGFilters_ScheduleForeverPresentation(searchFrame)
    return
  end

  if type(searchFrame.results) ~= "table" then return end
  if not self:LFGFilters_HasActiveFilters() then return end

  self._lfgFilterApplying = true
  local filtered = {}
  for _, resultID in ipairs(searchFrame.results) do
    if self:LFGFilters_ResultMatches(resultID, searchFrame) then
      filtered[#filtered + 1] = resultID
    end
  end

  searchFrame._ggRawTotalResults = searchFrame.totalResults
  searchFrame._ggRawResultCount = #searchFrame.results
  searchFrame.results = filtered
  searchFrame.totalResults = #filtered

  -- Rebuild only the visual data provider; never trigger a protected Search().
  -- Forever needs explicit scroll restoration because its UpdateResults() first
  -- removes the old TreeDataProvider.
  if searchFrame == _G.LFGBrowseFrame and type(searchFrame.UpdateResults) == "function" then
    UpdateResultsPreservingScroll(searchFrame)
  elseif _G.LFGListFrame and searchFrame == _G.LFGListFrame.SearchPanel and type(_G.LFGListSearchPanel_UpdateResults) == "function" then
    pcall(_G.LFGListSearchPanel_UpdateResults, searchFrame)
  end
  self._lfgFilterApplying = false
end

-- Forever's LFGBrowseFrame is created from LFGBrowseMixin. Hooking the mixin
-- table *after* the XML frame already exists is not sufficient on every client:
-- the frame can retain the original function reference copied from the mixin.
-- Resolve and hook the concrete frame object as well.
function addon:LFGFilters_HookForeverFrame(searchFrame)
  if not searchFrame or searchFrame ~= _G.LFGBrowseFrame then return false end
  if self._ggForeverFrameFilterHooked then return true end
  if type(hooksecurefunc) ~= "function" then return false end
  if type(searchFrame.UpdateResultList) ~= "function" then return false end

  local ok = pcall(hooksecurefunc, searchFrame, "UpdateResultList", function(frame)
    if addon then addon:LFGFilters_ScheduleForeverPresentation(frame) end
  end)
  if ok then self._ggForeverFrameFilterHooked = true end
  return ok
end

-- Re-read the same client-side result set Blizzard uses in
-- LFGBrowseMixin:UpdateResultList(). This makes filter changes deterministic
-- even if a mixin hook was installed after LFGBrowseFrame was constructed.
function addon:LFGFilters_RefreshForeverResults(searchFrame)
  if not searchFrame or searchFrame ~= _G.LFGBrowseFrame then return false end
  -- Presentation-only refresh. Never call GetFilteredSearchResults() and write
  -- those values into Blizzard frame fields, and never invoke UpdateResults()
  -- from addon code on Forever. Both patterns can propagate taint into Search().
  self:LFGFilters_ScheduleForeverPresentation(searchFrame)
  return true
end

function addon:LFGFilters_RefreshCurrentResults()
  if self.LFG_API_ClearCaches then self:LFG_API_ClearCaches("search") end
  local searchFrame = self.GetLFGSearchFrame and self:GetLFGSearchFrame() or nil
  if not searchFrame then return end

  -- Forever: presentation-only. Never invoke Blizzard's browse rebuild from
  -- insecure addon code; let the native search/category path own its state.
  if searchFrame == _G.LFGBrowseFrame then
    self:LFGFilters_RefreshForeverResults(searchFrame)
    return
  end

  -- Retail can safely refetch its normal result list before applying the local
  -- filter so unchecking a filter restores rows without a server-side search.
  if _G.LFGListFrame and searchFrame == _G.LFGListFrame.SearchPanel and type(_G.LFGListSearchPanel_UpdateResultList) == "function" then
    pcall(_G.LFGListSearchPanel_UpdateResultList, searchFrame)
  end
end

local function PlayCheckboxSound(checked)
  if type(PlaySound) ~= "function" or not SOUNDKIT then return end
  local sound = checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
  if sound then pcall(PlaySound, sound) end
end

local function SetCheckLabelColor(label, classFile)
  local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if label and color and type(label.SetTextColor) == "function" then
    label:SetTextColor(color.r or 1, color.g or 0.82, color.b or 0)
  end
end

local function CreateCheck(parent, x, y, labelText, checked, onClick, classFile, role)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetSize(24, 24)
  check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  check:SetChecked(checked == true)
  if type(check.EnableMouse) == "function" then check:EnableMouse(true) end

  local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  label:SetPoint("LEFT", check, "RIGHT", 1, 0)
  label:SetJustifyH("LEFT")
  label:SetText(labelText or "")
  SetCheckLabelColor(label, classFile)
  check.ggLabel = label

  if role then
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("RIGHT", check, "LEFT", -1, 0)
    local atlas = ROLE_ATLAS[role]
    if atlas and type(icon.SetAtlas) == "function" then
      local ok = pcall(icon.SetAtlas, icon, atlas, false)
      if not ok then icon:Hide() end
    else
      icon:Hide()
    end
    check.ggRoleIcon = icon
  end

  check:SetScript("OnClick", function(self)
    local value = self:GetChecked() == true
    PlayCheckboxSound(value)
    onClick(value)
  end)
  return check
end

local function CreateStandardPanel(root)
  local panel
  local ok, created = pcall(CreateFrame, "Frame", "GroupGuardLFGFilterPanel", root or UIParent, "BasicFrameTemplateWithInset")
  if ok then panel = created end
  if not panel then
    panel = CreateFrame("Frame", "GroupGuardLFGFilterPanel", root or UIParent, "BackdropTemplate")
    if panel.SetBackdrop then
      panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
      })
    end
  end
  return panel
end

local function CreateFilterIcon(button)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(FILTER_ICON_TEXTURE)
  icon:SetSize(FILTER_BUTTON_ICON_SIZE, FILTER_BUTTON_ICON_SIZE)
  icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  return icon
end

local function UpdateFilterButtonIconState(button)
  if not button or not button.Icon then return end

  local enabled = true
  if type(button.IsEnabled) == "function" then
    local ok, value = pcall(button.IsEnabled, button)
    if ok then enabled = value == true end
  end

  local active = addon and addon.LFGFilters_HasActiveFilters and addon:LFGFilters_HasActiveFilters() or false
  button.Icon:ClearAllPoints()
  if button.ggPressed and enabled then
    button.Icon:SetPoint("CENTER", button, "CENTER", 1, -1)
  else
    button.Icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  end

  if not enabled then
    button.Icon:SetAlpha(0.35)
    if type(button.Icon.SetVertexColor) == "function" then button.Icon:SetVertexColor(0.55, 0.55, 0.55) end
  elseif active then
    button.Icon:SetAlpha(1.0)
    if type(button.Icon.SetVertexColor) == "function" then button.Icon:SetVertexColor(1.0, 0.82, 0.0) end
  elseif button.ggHover or button.ggPressed then
    button.Icon:SetAlpha(1.0)
    if type(button.Icon.SetVertexColor) == "function" then button.Icon:SetVertexColor(1.0, 1.0, 1.0) end
  else
    button.Icon:SetAlpha(0.90)
    if type(button.Icon.SetVertexColor) == "function" then button.Icon:SetVertexColor(0.90, 0.90, 0.90) end
  end
end

local function GetForeverSideTabWidth(root)
  if not root then return 0 end
  local width = 0
  for _, key in ipairs({ "ListingTab", "BrowsingTab", "WhoListingTab" }) do
    local tab = root[key]
    if tab and type(tab.GetWidth) == "function" then
      local ok, value = pcall(tab.GetWidth, tab)
      value = ok and tonumber(value) or nil
      if value and value > width then width = value end
    end
  end
  return width
end

local function PositionForeverFilterButton(button, searchFrame)
  if not button or not searchFrame then return false end
  local optionsButton = searchFrame.OptionsButton
  if optionsButton then
    button:SetSize(FILTER_BUTTON_SIZE, FILTER_BUTTON_SIZE)
    if button.Icon then button.Icon:SetSize(FILTER_BUTTON_ICON_SIZE, FILTER_BUTTON_ICON_SIZE) end
    button:ClearAllPoints()
    -- Blizzard's native options gear is LFGBrowseFrame.OptionsButton. Keep the
    -- custom filter control in the same header utility rail, directly below it.
    button:SetPoint("TOPRIGHT", optionsButton, "BOTTOMRIGHT", 0, -FILTER_BUTTON_VERTICAL_GAP)
    -- Keep the addon-owned control independent of the protected browse hierarchy,
    -- but guarantee that it renders above the header chrome on Forever.
    if type(button.SetFrameStrata) == "function" then button:SetFrameStrata("HIGH") end
    if type(optionsButton.GetFrameLevel) == "function" and type(button.SetFrameLevel) == "function" then
      local ok, level = pcall(optionsButton.GetFrameLevel, optionsButton)
      if ok and tonumber(level) then button:SetFrameLevel(math.max(100, tonumber(level) + 50)) end
    end
    -- Explicitly show after re-anchoring. Some Forever builds recycle/hide
    -- header utility controls while switching Browse categories. The GroupGuard
    -- launcher is addon-owned and should not inherit that transient visibility.
    if type(button.EnableMouse) == "function" then button:EnableMouse(true) end
    if type(button.SetAlpha) == "function" then button:SetAlpha(1) end
    if type(button.Show) == "function" then button:Show() end
    return true
  end
  return false
end

function addon:LFGFilters_UpdateButtonState()
  local button = self.lfgFilterButton
  if not button then return end
  local active = self:LFGFilters_HasActiveFilters()
  if button.ggActive then button.ggActive:SetShown(active) end
  UpdateFilterButtonIconState(button)
end

function addon:LFGFilters_UpdateStatusText()
  local panel = self.lfgFilterPanel
  if not panel or not panel.ggStatus then return end
  local active = self:LFGFilters_HasActiveFilters()
  local count = CountSelected(self.db and self.db.lfg_filter_group_roles)
      + CountSelected(self.db and self.db.lfg_filter_group_has_roles)
      + CountSelected(self.db and self.db.lfg_filter_player_roles)
      + CountSelected(self.db and self.db.lfg_filter_player_classes)
  if (tonumber(self.db and self.db.lfg_filter_player_min_level) or 0) > 0 then count = count + 1 end
  if (tonumber(self.db and self.db.lfg_filter_player_max_level) or 0) > 0 then count = count + 1 end
  panel.ggStatus:SetText(active and (self:Tr("LFG_FILTERS_ACTIVE") .. " (" .. count .. ")") or self:Tr("LFG_FILTERS_INACTIVE"))
end

function addon:LFGFilters_OnChanged()
  self:LFGFilters_UpdateButtonState()
  self:LFGFilters_UpdateStatusText()
  self:LFGFilters_RefreshCurrentResults()
  if self.LFG_DebouncedHighlightResults then self:LFG_DebouncedHighlightResults(0.03) end
end

function addon:LFGFilters_Reset()
  if not self.db then return end
  self.db.lfg_filter_group_roles = { TANK = false, HEALER = false, DAMAGER = false }
  self.db.lfg_filter_group_has_roles = { TANK = false, HEALER = false, DAMAGER = false }
  self.db.lfg_filter_player_roles = { TANK = false, HEALER = false, DAMAGER = false }
  self.db.lfg_filter_player_classes = {}
  self.db.lfg_filter_player_min_level = 0
  self.db.lfg_filter_player_max_level = 0
  self:LFGFilters_RebuildPanelContents()
  self:LFGFilters_OnChanged()
end

local function CopyBoolSet(source)
  local out = {}
  if type(source) ~= "table" then return out end
  for key, value in pairs(source) do
    if value == true and type(key) == "string" then out[key] = true end
  end
  return out
end

function addon:LFGFilters_CaptureState()
  local minLevel, maxLevel = NormalizeLevelRange(
    self.db and self.db.lfg_filter_player_min_level,
    self.db and self.db.lfg_filter_player_max_level
  )
  return {
    groupNeeds = CopyBoolSet(self.db and self.db.lfg_filter_group_roles),
    groupHas = CopyBoolSet(self.db and self.db.lfg_filter_group_has_roles),
    playerRoles = CopyBoolSet(self.db and self.db.lfg_filter_player_roles),
    playerClasses = CopyBoolSet(self.db and self.db.lfg_filter_player_classes),
    minLevel = minLevel,
    maxLevel = maxLevel,
  }
end

function addon:LFGFilters_ApplyState(state)
  if not self.db or type(state) ~= "table" then return false end
  self.db.lfg_filter_group_roles = CopyBoolSet(state.groupNeeds)
  self.db.lfg_filter_group_has_roles = CopyBoolSet(state.groupHas)
  self.db.lfg_filter_player_roles = CopyBoolSet(state.playerRoles)
  self.db.lfg_filter_player_classes = CopyBoolSet(state.playerClasses)
  self.db.lfg_filter_player_min_level, self.db.lfg_filter_player_max_level = NormalizeLevelRange(state.minLevel, state.maxLevel)
  self:LFGFilters_RebuildPanelContents()
  self:LFGFilters_OnChanged()
  return true
end

function addon:LFGFilters_SavePreset(name)
  if not self.db then return false end
  if type(name) ~= "string" then return false end
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then return false end
  local presets = self.db.lfg_filter_presets
  if type(presets) ~= "table" then presets = {}; self.db.lfg_filter_presets = presets end

  local replaceIndex = nil
  for i = 1, #presets do
    if type(presets[i]) == "table" and presets[i].name == name then replaceIndex = i; break end
  end
  if not replaceIndex and #presets >= 20 then
    print((self.printPrefix or "GroupGuard LFG:"), self:Tr("LFG_FILTERS_PRESET_LIMIT", 20))
    return false
  end

  local entry = { name = name, filters = self:LFGFilters_CaptureState() }
  if replaceIndex then presets[replaceIndex] = entry else presets[#presets + 1] = entry end
  return true
end

function addon:LFGFilters_DeletePreset(index)
  local presets = self.db and self.db.lfg_filter_presets
  index = tonumber(index)
  if type(presets) ~= "table" or not index or index < 1 or index > #presets then return false end
  table.remove(presets, index)
  return true
end

function addon:LFGFilters_TogglePresetMenu(anchor)
  local panel = self.lfgFilterPanel
  if not panel then return end
  local popup = panel.ggPresetPopup
  if popup and SafeShown(popup) then popup:Hide(); return end

  if not popup then
    popup = CreateStandardPanel(UIParent or panel)
    popup:SetSize(236, 260)
    if type(popup.SetFrameStrata) == "function" then popup:SetFrameStrata("TOOLTIP") end
    if type(popup.SetClampedToScreen) == "function" then popup:SetClampedToScreen(true) end
    popup:Hide()

    local scroll = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", popup, "TOPLEFT", 10, -10)
    scroll:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -28, 10)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(190, 1)
    if type(scroll.SetScrollChild) == "function" then scroll:SetScrollChild(child) end
    popup.ggScroll = scroll
    popup.ggChild = child
    panel.ggPresetPopup = popup
  end

  local child = popup.ggChild
  if type(child.ggRows) == "table" then
    for _, row in ipairs(child.ggRows) do if row and row.Hide then row:Hide() end end
  end
  child.ggRows = {}

  local presets = self.db and self.db.lfg_filter_presets or {}
  local y = -2
  if #presets == 0 then
    local empty = child:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    empty:SetPoint("TOPLEFT", child, "TOPLEFT", 4, y)
    empty:SetText(self:Tr("LFG_FILTERS_PRESET_EMPTY"))
    child.ggRows[#child.ggRows + 1] = empty
    y = y - 24
  else
    for i = 1, #presets do
      local entry = presets[i]
      if type(entry) == "table" and type(entry.name) == "string" then
        local index = i
        local load = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
        load:SetSize(158, 21)
        load:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
        load:SetText(entry.name)
        load:SetScript("OnClick", function()
          popup:Hide()
          addon:LFGFilters_ApplyState(entry.filters)
        end)
        child.ggRows[#child.ggRows + 1] = load

        local del = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
        del:SetSize(24, 21)
        del:SetPoint("LEFT", load, "RIGHT", 4, 0)
        del:SetText("×")
        del:SetScript("OnClick", function()
          addon:LFGFilters_DeletePreset(index)
          addon:LFGFilters_RebuildPanelContents()
          popup:Hide()
          addon:LFGFilters_TogglePresetMenu(anchor)
        end)
        child.ggRows[#child.ggRows + 1] = del
        y = y - 24
      end
    end
  end
  if type(child.SetHeight) == "function" then child:SetHeight(math.max(230, -y + 8)) end

  popup:ClearAllPoints()
  popup:SetPoint("TOPRIGHT", anchor or panel, "BOTTOMRIGHT", 0, -4)
  popup:Show()
end

local function CreateLevelBox(parent, x, y, value, onCommit)
  local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  box:SetSize(48, 20)
  box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  if type(box.SetAutoFocus) == "function" then box:SetAutoFocus(false) end
  if type(box.SetNumeric) == "function" then box:SetNumeric(true) end
  if type(box.SetMaxLetters) == "function" then box:SetMaxLetters(3) end
  if type(box.SetText) == "function" then box:SetText((tonumber(value) or 0) > 0 and tostring(math.floor(tonumber(value))) or "") end

  local function commit(self)
    local text = type(self.GetText) == "function" and self:GetText() or ""
    local number = math.floor(tonumber(text) or 0)
    if number < 0 then number = 0 elseif number > 999 then number = 999 end
    onCommit(number)
  end
  box:SetScript("OnEnterPressed", function(self)
    commit(self)
    if type(self.ClearFocus) == "function" then self:ClearFocus() end
  end)
  box:SetScript("OnEditFocusLost", commit)
  return box
end

function addon:LFGFilters_RebuildPanelContents()
  local panel = self.lfgFilterPanel
  if not panel or not panel.ggContent then return end
  local content = panel.ggContent

  if type(content.ggChildren) == "table" then
    for _, child in ipairs(content.ggChildren) do
      if child and type(child.Hide) == "function" then child:Hide() end
      if child and type(child.EnableMouse) == "function" then child:EnableMouse(false) end
    end
  end
  if type(content.ggRegions) == "table" then
    for _, region in ipairs(content.ggRegions) do if region and type(region.Hide) == "function" then region:Hide() end end
  end
  content.ggChildren, content.ggRegions = {}, {}

  local function KeepChild(child) content.ggChildren[#content.ggChildren + 1] = child return child end
  local function KeepRegion(region) content.ggRegions[#content.ggRegions + 1] = region return region end
  local function Text(template, text, x, y, width)
    local fs = KeepRegion(content:CreateFontString(nil, "ARTWORK", template))
    fs:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
    fs:SetWidth(width or 294)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetText(text)
    return fs
  end
  local function Divider(y)
    local divider = KeepRegion(content:CreateTexture(nil, "ARTWORK"))
    divider:SetColorTexture(0.35, 0.32, 0.25, 0.75)
    divider:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    divider:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, y)
    divider:SetHeight(1)
  end

  local groupAvailable = self.HasClientCapability and self:HasClientCapability("lfgSearchMemberCounts")
  local playerAvailable = self.HasClientCapability and self:HasClientCapability("lfgSearchPlayerInfo")
  local presets = self.db and self.db.lfg_filter_presets or {}

  Text("GameFontNormal", self:Tr("LFG_FILTERS_PRESETS"), 8, -2, 104)
  Text("GameFontDisableSmall", self:Tr("LFG_FILTERS_PRESET_NAME"), 126, -4, 105)
  local presetButton = KeepChild(CreateFrame("Button", nil, content, "UIPanelButtonTemplate"))
  presetButton:SetSize(112, 22)
  presetButton:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -20)
  presetButton:SetText(self:Tr("LFG_FILTERS_PRESETS") .. " (" .. tostring(#presets) .. ")")
  presetButton:SetScript("OnClick", function(self) addon:LFGFilters_TogglePresetMenu(self) end)

  local presetName = KeepChild(CreateFrame("EditBox", nil, content, "InputBoxTemplate"))
  presetName:SetSize(105, 20)
  presetName:SetPoint("TOPLEFT", content, "TOPLEFT", 126, -21)
  if type(presetName.SetAutoFocus) == "function" then presetName:SetAutoFocus(false) end
  if type(presetName.SetMaxLetters) == "function" then presetName:SetMaxLetters(40) end
  panel.ggPresetName = presetName

  local save = KeepChild(CreateFrame("Button", nil, content, "UIPanelButtonTemplate"))
  save:SetSize(70, 22)
  save:SetPoint("TOPLEFT", content, "TOPLEFT", 236, -20)
  save:SetText(self:Tr("LFG_FILTERS_PRESET_SAVE"))
  save:SetScript("OnClick", function()
    local name = type(presetName.GetText) == "function" and presetName:GetText() or ""
    if addon:LFGFilters_SavePreset(name) then
      if type(presetName.SetText) == "function" then presetName:SetText("") end
      addon:LFGFilters_RebuildPanelContents()
    end
  end)

  local social = KeepChild(CreateCheck(content, 8, -48, self:Tr("LFG_FILTERS_SOCIAL_FIRST"), self.db.lfg_filter_social_priority ~= false, function(value)
    addon.db.lfg_filter_social_priority = value
    addon:LFGFilters_OnChanged()
  end))
  social.ggLabel:SetWidth(250)

  Divider(-76)
  Text("GameFontNormal", self:Tr("LFG_FILTERS_GROUP_TITLE"), 8, -88, 294)
  Text("GameFontHighlightSmall", self:Tr("LFG_FILTERS_GROUP_HELP"), 8, -108, 294)

  if groupAvailable then
    Text("GameFontNormalSmall", self:Tr("LFG_FILTERS_NEEDS"), 8, -139, 80)
    local x = 26
    for _, role in ipairs(ROLE_ORDER) do
      local roleKey = role
      local cb = KeepChild(CreateCheck(content, x, -153, self:Tr(ROLE_TEXT_KEY[role]), self.db.lfg_filter_group_roles[role] == true, function(value)
        addon.db.lfg_filter_group_roles[roleKey] = value
        addon:LFGFilters_OnChanged()
      end, nil, role))
      cb.ggLabel:SetPoint("LEFT", cb, "RIGHT", 0, 0)
      x = x + 94
    end

    Text("GameFontNormalSmall", self:Tr("LFG_FILTERS_HAS"), 8, -183, 80)
    x = 26
    for _, role in ipairs(ROLE_ORDER) do
      local roleKey = role
      local cb = KeepChild(CreateCheck(content, x, -197, self:Tr(ROLE_TEXT_KEY[role]), self.db.lfg_filter_group_has_roles[role] == true, function(value)
        addon.db.lfg_filter_group_has_roles[roleKey] = value
        addon:LFGFilters_OnChanged()
      end, nil, role))
      cb.ggLabel:SetPoint("LEFT", cb, "RIGHT", 0, 0)
      x = x + 94
    end
  else
    Text("GameFontDisableSmall", self:Tr("LFG_FILTERS_UNAVAILABLE"), 8, -151, 294)
  end

  Divider(-230)
  Text("GameFontNormal", self:Tr("LFG_FILTERS_PLAYER_TITLE"), 8, -242, 294)
  Text("GameFontHighlightSmall", self:Tr("LFG_FILTERS_PLAYER_HELP"), 8, -262, 294)

  local contentHeight = 340
  if playerAvailable then
    Text("GameFontNormalSmall", self:Tr("LFG_FILTERS_ROLES"), 8, -294, 294)
    local x = 26
    for _, role in ipairs(ROLE_ORDER) do
      local roleKey = role
      KeepChild(CreateCheck(content, x, -307, self:Tr(ROLE_TEXT_KEY[role]), self.db.lfg_filter_player_roles[role] == true, function(value)
        addon.db.lfg_filter_player_roles[roleKey] = value
        addon:LFGFilters_OnChanged()
      end, nil, role))
      x = x + 94
    end

    Text("GameFontNormalSmall", self:Tr("LFG_FILTERS_LEVEL"), 8, -343, 60)
    Text("GameFontDisableSmall", self:Tr("LFG_FILTERS_LEVEL_MIN"), 72, -345, 32)
    local minBox = KeepChild(CreateLevelBox(content, 104, -351, self.db.lfg_filter_player_min_level, function(value)
      if addon.db.lfg_filter_player_min_level == value then return end
      addon.db.lfg_filter_player_min_level = value
      local minLevel, maxLevel = NormalizeLevelRange(addon.db.lfg_filter_player_min_level, addon.db.lfg_filter_player_max_level)
      addon.db.lfg_filter_player_min_level, addon.db.lfg_filter_player_max_level = minLevel, maxLevel
      if panel.ggMinLevelBox and type(panel.ggMinLevelBox.SetText) == "function" then panel.ggMinLevelBox:SetText(minLevel > 0 and tostring(minLevel) or "") end
      if panel.ggMaxLevelBox and type(panel.ggMaxLevelBox.SetText) == "function" then panel.ggMaxLevelBox:SetText(maxLevel > 0 and tostring(maxLevel) or "") end
      addon:LFGFilters_OnChanged()
    end))
    panel.ggMinLevelBox = minBox
    Text("GameFontDisableSmall", self:Tr("LFG_FILTERS_LEVEL_MAX"), 164, -345, 38)
    local maxBox = KeepChild(CreateLevelBox(content, 204, -351, self.db.lfg_filter_player_max_level, function(value)
      if addon.db.lfg_filter_player_max_level == value then return end
      addon.db.lfg_filter_player_max_level = value
      local minLevel, maxLevel = NormalizeLevelRange(addon.db.lfg_filter_player_min_level, addon.db.lfg_filter_player_max_level)
      addon.db.lfg_filter_player_min_level, addon.db.lfg_filter_player_max_level = minLevel, maxLevel
      if panel.ggMinLevelBox and type(panel.ggMinLevelBox.SetText) == "function" then panel.ggMinLevelBox:SetText(minLevel > 0 and tostring(minLevel) or "") end
      if panel.ggMaxLevelBox and type(panel.ggMaxLevelBox.SetText) == "function" then panel.ggMaxLevelBox:SetText(maxLevel > 0 and tostring(maxLevel) or "") end
      addon:LFGFilters_OnChanged()
    end))
    panel.ggMaxLevelBox = maxBox

    Text("GameFontNormalSmall", self:Tr("LFG_FILTERS_CLASSES"), 8, -389, 294)
    local classes = self:LFGFilters_GetAvailableClasses()
    contentHeight = 404 + math.ceil(#classes / 2) * 21 + 12
    for index, classInfo in ipairs(classes) do
      local col = (index - 1) % 2
      local row = math.floor((index - 1) / 2)
      local classFile = classInfo.file
      local cb = KeepChild(CreateCheck(content, 8 + col * 150, -404 - row * 21, classInfo.name, self.db.lfg_filter_player_classes[classFile] == true, function(value)
        addon.db.lfg_filter_player_classes[classFile] = value
        addon:LFGFilters_OnChanged()
      end, classFile, nil))
      cb.ggLabel:SetWidth(116)
    end
  else
    Text("GameFontDisableSmall", self:Tr("LFG_FILTERS_UNAVAILABLE"), 8, -294, 294)
  end

  if panel.ggContentScroll then
    content:SetHeight(contentHeight)
    local scroll = panel.ggContentScroll
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll() or 0, scroll:GetVerticalScrollRange() or 0))
  end
  self:LFGFilters_UpdateStatusText()
end

-- A secure Search child makes the Forever panel protected. Defer visibility and
-- positioning changes until combat ends rather than writing protected frame state.
local function PanelCombatLocked()
  return addon.ForeverSearch and InCombatLockdown and InCombatLockdown()
end

function addon:LFGFilters_SetPanelShown(shown)
  local panel = self.lfgFilterPanel
  if not panel then return end
  if PanelCombatLocked() then self._ggDeferredPanelShown = shown; return end
  self._ggDeferredPanelShown = nil
  if shown then panel:Show() else panel:Hide() end
end

function addon:LFGFilters_ApplyDeferredPanel()
  if PanelCombatLocked() then return end
  self:LFGFilters_LayoutPanel()
  if self._ggDeferredPanelShown ~= nil then self:LFGFilters_SetPanelShown(self._ggDeferredPanelShown) end
end

function addon:LFGFilters_CreatePanel(root)
  if self.lfgFilterPanel then return self.lfgFilterPanel end
  if PanelCombatLocked() then return nil end
  root = root or (self.GetLFGRootFrame and self:GetLFGRootFrame()) or UIParent
  if not root then return nil end

  -- Keep the side panel out of LFGBrowseFrame/LFGParentFrame's mouse hierarchy.
  -- Forever's ScrollBox consumes wheel input; a child panel anchored outside the
  -- parent can otherwise bubble wheel events back into the browse list.
  local panel = CreateStandardPanel(UIParent or root)
  local languageSearch = self.ForeverSearch
  local languageHeight = languageSearch and languageSearch.AttachPanel and 72 or 0
  panel:SetSize(languageHeight > 0 and 352 or 336, 640)
  panel:SetFrameStrata("DIALOG")
  if type(root.GetFrameLevel) == "function" and type(panel.SetFrameLevel) == "function" then
    local ok, level = pcall(root.GetFrameLevel, root)
    if ok and tonumber(level) then panel:SetFrameLevel(tonumber(level) + 20) end
  end
  if panel.SetClampedToScreen then panel:SetClampedToScreen(true) end
  if type(panel.EnableMouse) == "function" then panel:EnableMouse(true) end
  if type(panel.EnableMouseWheel) == "function" then panel:EnableMouseWheel(true) end
  if type(panel.SetMouseClickEnabled) == "function" then panel:SetMouseClickEnabled(true) end
  if type(panel.SetMouseMotionEnabled) == "function" then panel:SetMouseMotionEnabled(true) end
  if type(panel.SetPropagateMouseClicks) == "function" then panel:SetPropagateMouseClicks(false) end
  if type(panel.SetPropagateMouseMotion) == "function" then panel:SetPropagateMouseMotion(false) end
  -- Consume panel wheel input; the embedded language layout installs its filter scroll handler below.
  if type(panel.SetScript) == "function" then panel:SetScript("OnMouseWheel", function() end) end
  panel:Hide()
  if type(panel.HookScript) == "function" then
    panel:HookScript("OnHide", function(self)
      if self.ggPresetPopup then self.ggPresetPopup:Hide() end
    end)
  end

  local title = panel.TitleText or (panel.TitleContainer and panel.TitleContainer.TitleText)
  if not title or type(title.SetText) ~= "function" then
    title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if title and type(title.SetPoint) == "function" then
      title:SetPoint("TOP", panel, "TOP", 0, -7)
    end
  end
  if title and type(title.SetText) == "function" then
    title:SetText(self:Tr("LFG_FILTERS_TITLE"))
  end

  if not panel.CloseButton then
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
    panel.CloseButton = close
  end
  panel.CloseButton:SetScript("OnClick", function()
    addon:LFGFilters_SetPanelShown(false)
    if panel.ggPresetPopup then panel.ggPresetPopup:Hide() end
    if addon.db then addon.db.lfg_filter_panel_open = false end
  end)

  local content
  if languageHeight > 0 then
    languageSearch.AttachPanel(panel)
    -- Keep the language row fixed while the existing long filter list scrolls.
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 11, -31 - languageHeight)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -27, 43)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(314, 560)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    local function wheel(_, delta)
      local current = scroll:GetVerticalScroll() or 0
      local maximum = scroll:GetVerticalScrollRange() or 0
      scroll:SetVerticalScroll(math.max(0, math.min(maximum, current - delta * 32)))
    end
    scroll:SetScript("OnMouseWheel", wheel)
    panel:SetScript("OnMouseWheel", wheel)
    panel.ggContentScroll = scroll
  else
    content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", panel, "TOPLEFT", 11, -31)
    content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -11, 43)
  end
  panel.ggContent = content

  local status = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  status:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 18, 17)
  status:SetWidth(218)
  status:SetJustifyH("LEFT")
  panel.ggStatus = status

  local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  reset:SetSize(76, 22)
  reset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 12)
  reset:SetText(self:Tr("LFG_FILTERS_RESET"))
  reset:SetScript("OnClick", function() addon:LFGFilters_Reset() end)
  panel.ggReset = reset

  self.lfgFilterPanel = panel
  self:LFGFilters_RebuildPanelContents()
  return panel
end

function addon:LFGFilters_LayoutPanel()
  if PanelCombatLocked() then return end
  local panel = self.lfgFilterPanel
  local root = self.GetLFGRootFrame and self:GetLFGRootFrame() or nil
  if not panel or not root then return end

  panel:ClearAllPoints()

  -- Forever's modern VanillaStyle frame owns a vertical stack of 43px side
  -- tabs (Listing / Browse / Who) just outside LFGParentFrame's right edge.
  -- Anchor after that rail instead of directly on TOPRIGHT so the GroupGuard
  -- panel never covers Blizzard's navigation tabs.
  local sideTabWidth = GetForeverSideTabWidth(root)
  if sideTabWidth > 0 then
    panel:SetPoint("TOPLEFT", root, "TOPRIGHT", sideTabWidth + FILTER_PANEL_SIDE_GAP, -8)
  else
    panel:SetPoint("TOPLEFT", root, "TOPRIGHT", 12, -8)
  end
end

function addon:LFGFilters_CreateButton(searchFrame)
  searchFrame = searchFrame or (self.GetLFGSearchFrame and self:GetLFGSearchFrame()) or nil
  if not searchFrame then return nil end
  local desiredParent = (searchFrame == _G.LFGBrowseFrame and (UIParent or searchFrame)) or searchFrame
  if self.lfgFilterButton and self.lfgFilterButton:GetParent() ~= desiredParent then
    self.lfgFilterButton:Hide()
    self.lfgFilterButton:SetParent(desiredParent)
  end

  local button = self.lfgFilterButton
  if not button then
    -- Intentionally no UIPanelButtonTemplate here. Forever's native options
    -- control is a bare 16x16 utility icon (LFGOptionsButton), not a square
    -- panel button. Our filter button mirrors that visual language.
    button = CreateFrame("Button", "GroupGuardLFGFilterButton", desiredParent)
    button:SetSize(FILTER_BUTTON_SIZE, FILTER_BUTTON_SIZE)
    if type(button.SetHitRectInsets) == "function" then button:SetHitRectInsets(-2, -2, -2, -2) end
    if type(button.RegisterForClicks) == "function" then button:RegisterForClicks("LeftButtonUp") end

    local icon = CreateFilterIcon(button)
    icon:SetAlpha(0.8)
    button.Icon = icon

    button:SetScript("OnEnter", function(self)
      self.ggHover = true
      UpdateFilterButtonIconState(self)
      if GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(addon:Tr("LFG_FILTERS"))
        GameTooltip:AddLine(addon:LFGFilters_HasActiveFilters() and addon:Tr("LFG_FILTERS_ACTIVE") or addon:Tr("LFG_FILTERS_INACTIVE"), 1, 1, 1, true)
        GameTooltip:Show()
      end
    end)
    button:SetScript("OnLeave", function(self)
      self.ggHover = false
      self.ggPressed = false
      UpdateFilterButtonIconState(self)
      if GameTooltip then GameTooltip:Hide() end
    end)
    button:SetScript("OnMouseDown", function(self)
      self.ggPressed = true
      UpdateFilterButtonIconState(self)
    end)
    button:SetScript("OnMouseUp", function(self)
      self.ggPressed = false
      UpdateFilterButtonIconState(self)
    end)
    button:HookScript("OnEnable", function(self) UpdateFilterButtonIconState(self) end)
    button:HookScript("OnDisable", function(self) UpdateFilterButtonIconState(self) end)

    button:SetScript("OnClick", function()
      PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
      local root = addon.GetLFGRootFrame and addon:GetLFGRootFrame() or nil
      local panel = addon:LFGFilters_CreatePanel(root)
      if not panel then return end
      addon:LFGFilters_LayoutPanel()
      if panel:IsShown() then
        addon:LFGFilters_SetPanelShown(false)
        if addon.db then addon.db.lfg_filter_panel_open = false end
      else
        addon:LFGFilters_SetPanelShown(true)
        if addon.db then addon.db.lfg_filter_panel_open = true end
      end
    end)
    self.lfgFilterButton = button
  end

  button:ClearAllPoints()
  if searchFrame == _G.LFGBrowseFrame and PositionForeverFilterButton(button, searchFrame) then
    -- Positioned in the native header utility rail below OptionsButton.
  elseif searchFrame.FilterButton then
    button:SetSize(FILTER_BUTTON_SIZE, FILTER_BUTTON_SIZE)
    if button.Icon then button.Icon:SetSize(FILTER_BUTTON_ICON_SIZE, FILTER_BUTTON_ICON_SIZE) end
    button:SetPoint("TOPRIGHT", searchFrame.FilterButton, "BOTTOMRIGHT", 0, -4)
  elseif searchFrame.OptionsButton then
    button:SetSize(FILTER_BUTTON_SIZE, FILTER_BUTTON_SIZE)
    if button.Icon then button.Icon:SetSize(FILTER_BUTTON_ICON_SIZE, FILTER_BUTTON_ICON_SIZE) end
    button:SetPoint("TOPRIGHT", searchFrame.OptionsButton, "BOTTOMRIGHT", 0, -FILTER_BUTTON_VERTICAL_GAP)
  else
    button:SetSize(FILTER_BUTTON_SIZE, FILTER_BUTTON_SIZE)
    if button.Icon then button.Icon:SetSize(FILTER_BUTTON_ICON_SIZE, FILTER_BUTTON_ICON_SIZE) end
    button:SetPoint("TOPRIGHT", searchFrame, "TOPRIGHT", -12, -53)
  end

  local canGroup = self.HasClientCapability and self:HasClientCapability("lfgSearchMemberCounts")
  local canPlayer = self.HasClientCapability and self:HasClientCapability("lfgSearchPlayerInfo")
  local isForeverBrowse = self.IsForeverClient and self:IsForeverClient() and searchFrame == _G.LFGBrowseFrame
  -- The launcher must stay visible even when the filter master switch is off.
  -- Hiding the only way back into the filter panel made a saved
  -- lfg_filters_enabled=false state effectively irreversible from the LFG UI.
  -- Capability probes can also be briefly false while Forever's
  -- Blizzard_GroupFinder_VanillaStyle loads on demand, so the native Forever
  -- browse frame itself is enough to expose the button.
  local shouldShowButton = canGroup or canPlayer or isForeverBrowse
  -- UIParent-parented Forever controls must follow the Browse frame lifecycle
  -- explicitly, otherwise they remain on screen after Group Finder closes.
  if isForeverBrowse then
    if type(searchFrame.IsVisible) == "function" then
      shouldShowButton = shouldShowButton and searchFrame:IsVisible()
    elseif type(searchFrame.IsShown) == "function" then
      shouldShowButton = shouldShowButton and searchFrame:IsShown()
    end
  end
  if type(button.SetShown) == "function" then
    button:SetShown(shouldShowButton == true)
  elseif shouldShowButton then
    button:Show()
  else
    button:Hide()
  end
  self:LFGFilters_UpdateButtonState()
  return button
end

function addon:LFGFilters_HookFrames()
  local searchFrame = self.GetLFGSearchFrame and self:GetLFGSearchFrame() or nil
  if searchFrame then
    self:LFGFilters_CreateButton(searchFrame)
    if searchFrame == _G.LFGBrowseFrame and searchFrame.OptionsButton
        and not self._ggForeverOptionsButtonHooked and type(searchFrame.OptionsButton.HookScript) == "function" then
      self._ggForeverOptionsButtonHooked = true
      searchFrame.OptionsButton:HookScript("OnShow", function()
        if addon then addon:LFGFilters_CreateButton(_G.LFGBrowseFrame) end
      end)
    end
    local root = self.GetLFGRootFrame and self:GetLFGRootFrame() or nil
    self:LFGFilters_CreatePanel(root)
    self:LFGFilters_LayoutPanel()

    -- Forever's launcher is parented to UIParent, so it does not inherit the
    -- Group Finder root visibility. Mirror the root lifecycle explicitly to
    -- prevent the icon from remaining on screen after the LFG window closes.
    if root and not self._ggFilterRootVisibilityHooked and type(root.HookScript) == "function" then
      self._ggFilterRootVisibilityHooked = true
      root:HookScript("OnHide", function()
        if addon.lfgFilterButton then addon.lfgFilterButton:Hide() end
        if addon.lfgFilterPanel then addon:LFGFilters_SetPanelShown(false) end
      end)
      root:HookScript("OnShow", function()
        local activeSearch = addon.GetLFGSearchFrame and addon:GetLFGSearchFrame() or nil
        if activeSearch then addon:LFGFilters_CreateButton(activeSearch) end
      end)
    end
    if searchFrame == _G.LFGBrowseFrame then
      self:LFGFilters_HookForeverFrame(searchFrame)
    end

    self._ggFilterVisibilityHooks = self._ggFilterVisibilityHooks or {}
    if not self._ggFilterVisibilityHooks[searchFrame] and type(searchFrame.HookScript) == "function" then
      self._ggFilterVisibilityHooks[searchFrame] = true
      searchFrame:HookScript("OnShow", function()
        addon:LFGFilters_CreateButton(searchFrame)
        addon:LFGFilters_LayoutPanel()
        if addon._ggForeverRefreshPending and searchFrame == _G.LFGBrowseFrame then
          addon:LFGFilters_ScheduleForeverPresentation(searchFrame)
        end
        if addon.db and addon.db.lfg_filter_panel_open and addon.lfgFilterPanel then addon:LFGFilters_SetPanelShown(true) end
      end)
      searchFrame:HookScript("OnHide", function()
        if addon.lfgFilterPanel then addon:LFGFilters_SetPanelShown(false) end
        -- The Forever launcher is parented to UIParent to avoid tainting the
        -- protected LFG frame tree, so it will not inherit LFGBrowseFrame
        -- visibility automatically. Hide it explicitly when Browse closes.
        if addon.lfgFilterButton then addon.lfgFilterButton:Hide() end
      end)
    end
  end

  -- Retail 12.x path.
  if not self._ggModernFilterHooked and type(_G.LFGListSearchPanel_UpdateResultList) == "function" and type(hooksecurefunc) == "function" then
    local ok = pcall(hooksecurefunc, "LFGListSearchPanel_UpdateResultList", function(frame)
      if addon then addon:LFGFilters_FilterFrameResults(frame) end
    end)
    if ok then self._ggModernFilterHooked = true end
  end

  -- WoW Forever 1.60.x path. Blizzard_GroupFinder_VanillaStyle uses a
  -- ScrollBox tree and LFGBrowseMixin:UpdateResultList(). Hook the mixin after
  -- Blizzard fetches/sorts results, then rebuild only its data provider.
  if not self._ggForeverFrameFilterHooked and not self._ggForeverFilterHooked
      and type(_G.LFGBrowseMixin) == "table" and type(_G.LFGBrowseMixin.UpdateResultList) == "function"
      and type(hooksecurefunc) == "function" then
    local ok = pcall(hooksecurefunc, _G.LFGBrowseMixin, "UpdateResultList", function(frame)
      if addon then addon:LFGFilters_ScheduleForeverPresentation(frame) end
    end)
    if ok then self._ggForeverFilterHooked = true end
  end

end

function addon:LFGFilters_DebugDump(limit)
  limit = math.max(1, math.min(tonumber(limit) or 8, 20))
  local searchFrame = self.GetLFGSearchFrame and self:GetLFGSearchFrame() or nil
  local total, results = nil, nil
  if C_LFGList and type(C_LFGList.GetFilteredSearchResults) == "function" then
    local ok, rawTotal, rawResults = pcall(C_LFGList.GetFilteredSearchResults)
    if ok then total, results = rawTotal, rawResults end
  end
  if type(results) ~= "table" and searchFrame and type(searchFrame.results) == "table" then
    results = searchFrame.results
    total = searchFrame.totalResults or #results
  end

  print((self.printPrefix or "GroupGuard LFG:"), "LFG filter debug")
  print((self.printPrefix or "GroupGuard LFG:"), "forever=", tostring(self.IsForeverClient and self:IsForeverClient()),
    "frameHook=", tostring(self._ggForeverFrameFilterHooked == true),
    "mixinHook=", tostring(self._ggForeverFilterHooked == true),
    "active=", tostring(self:LFGFilters_HasActiveFilters()))
  local shownCount = self._ggForeverVisibleResults
  if shownCount == nil then shownCount = searchFrame and type(searchFrame.results) == "table" and #searchFrame.results or 0 end
  print((self.printPrefix or "GroupGuard LFG:"), "rawTotal=", tostring(total), "rawCount=", tostring(type(results) == "table" and #results or 0),
    "shownCount=", tostring(shownCount))

  if type(results) ~= "table" then return end
  if self.LFG_API_ClearCaches then self:LFG_API_ClearCaches("search") end
  for i = 1, math.min(#results, limit) do
    local resultID = self:SafeNumber(results[i], nil)
    local info = resultID and self.LFG_API_GetSearchResultInfo and self:LFG_API_GetSearchResultInfo(resultID) or nil
    local player = resultID and self.LFG_API_GetSearchResultPlayerInfo and self:LFG_API_GetSearchResultPlayerInfo(resultID, 1) or nil
    local counts = resultID and self.LFG_API_GetSearchResultMemberCounts and self:LFG_API_GetSearchResultMemberCounts(resultID) or nil
    local roles = player and player.lfgRoles or nil
    print((self.printPrefix or "GroupGuard LFG:"),
      "#" .. tostring(i), "id=" .. tostring(resultID),
      "members=" .. tostring(info and info.numMembers),
      "class=" .. tostring(player and player.classFilename),
      "assigned=" .. tostring(player and player.assignedRole),
      "roles=" .. tostring(roles and roles.tank) .. "/" .. tostring(roles and roles.healer) .. "/" .. tostring(roles and roles.dps),
      "remaining=" .. tostring(counts and counts.TANK_REMAINING) .. "/" .. tostring(counts and counts.HEALER_REMAINING) .. "/" .. tostring(counts and counts.DAMAGER_REMAINING),
      "match=" .. tostring(resultID and self:LFGFilters_ResultMatches(resultID, searchFrame)))
  end
end

function addon:LFGFilters_Init()
  if not self.db then self:EnsureDB() end
  if self.RefreshClientCapabilities then self:RefreshClientCapabilities() end
  self:LFGFilters_HookFrames()

  -- Group finder is load-on-demand. A short retry covers clients where the
  -- ADDON_LOADED event fires before the frame's final OnLoad completes.
  if C_Timer and C_Timer.After then
    C_Timer.After(0.10, function() if addon then addon:LFGFilters_HookFrames() end end)
    C_Timer.After(0.35, function() if addon then addon:LFGFilters_HookFrames() end end)
    C_Timer.After(1.00, function() if addon then addon:LFGFilters_HookFrames() end end)
  end
end
