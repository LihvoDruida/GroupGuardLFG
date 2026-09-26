-- GroupGuard LFG — search filters for Retail 12.x and WoW Forever
-- Two independent filter blocks:
--   1) dungeon groups: group still needs every selected role (AND)
--   2) solo players: selected class AND selected role (OR inside each set)
local addonName, addon = ...

local type, pairs, ipairs, tonumber = type, pairs, ipairs, tonumber
local tinsert = table.insert

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
local FILTER_BUTTON_VERTICAL_GAP = 4
local FILTER_PANEL_SIDE_GAP = 8

-- The Forever client showed the bundled TGA as a solid green block on some
-- builds. Keep this control texture-free: the filter glyph is assembled from
-- tiny native color textures, so it is stable across Retail 12.x and Camelot
-- and still matches the bare Blizzard options-button visual language.
local FILTER_GLYPH_NORMAL = { 0.78, 0.66, 0.34 }
local FILTER_GLYPH_HOVER = { 1.00, 0.82, 0.00 }
local FILTER_GLYPH_ACTIVE = { 1.00, 0.82, 0.00 }
local FILTER_GLYPH_DISABLED = { 0.45, 0.45, 0.45 }

local function SafeShown(frame)
  if not frame or type(frame.IsShown) ~= "function" then return false end
  local ok, shown = pcall(frame.IsShown, frame)
  return ok and shown == true
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
      or HasAnySelected(self.db.lfg_filter_player_roles)
      or HasAnySelected(self.db.lfg_filter_player_classes)
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

function addon:LFGFilters_MatchesGroupBlock(resultID, info)
  local selected = self.db and self.db.lfg_filter_group_roles
  if not HasAnySelected(selected) then return true end

  -- Dungeon role selections are a combination, not alternatives.
  -- Example: Tank + Healer means the listing must still need BOTH roles.
  -- A single readable selected role that is already filled is enough to reject
  -- the listing. Unknown role data stays fail-open so transient LFG streaming
  -- does not make valid rows disappear while Blizzard is populating counts.
  for _, role in ipairs(ROLE_ORDER) do
    if selected[role] == true then
      local needs = self:LFGFilters_GroupNeedsRole(resultID, role, info)
      if needs ~= nil then
        if not needs then return false end
      end
    end
  end

  -- All readable selected roles are still needed. If the client temporarily
  -- withholds every selected role, keep the row visible rather than guessing.
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
  local classActive = HasAnySelected(classes)
  local roleActive = HasAnySelected(roles)
  if not classActive and not roleActive then return true end

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
  return classMatches and roleMatches
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

  if HasAnySelected(self.db and self.db.lfg_filter_group_roles) and self:LFGFilters_IsDungeonResult(info, searchFrame) then
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
function addon:LFGFilters_ApplyForeverPresentation(searchFrame)
  if not searchFrame or searchFrame ~= _G.LFGBrowseFrame then return false end
  local scrollBox = searchFrame.ScrollBox
  if not scrollBox then return false end

  local active = self:LFGFilters_HasActiveFilters()
  local rows = EnumerateForeverRows(scrollBox)
  for _, row in ipairs(rows) do
    local match = true
    if active then
      local resultID = GetForeverResultIDFromRow(row)
      if resultID then match = self:LFGFilters_ResultMatches(resultID, searchFrame) end
    end

    -- Do not Hide() recycled ScrollBox rows: hiding them leaves provider holes
    -- and can confuse Blizzard's virtualization. Non-matches are visually
    -- suppressed and made non-interactive while the provider remains Blizzard-owned.
    if type(row.SetAlpha) == "function" then pcall(row.SetAlpha, row, match and 1 or 0.12) end
    if type(row.EnableMouse) == "function" then pcall(row.EnableMouse, row, match) end
    pcall(function() row._ggForeverFilterSuppressed = not match end)
  end
  return true
end

function addon:LFGFilters_ScheduleForeverPresentation(searchFrame)
  searchFrame = searchFrame or _G.LFGBrowseFrame
  if not searchFrame then return end
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

local function SetFilterGlyphColor(glyph, color)
  if not glyph or type(glyph.ggParts) ~= "table" then return end
  for _, part in ipairs(glyph.ggParts) do
    if part and type(part.SetColorTexture) == "function" then
      part:SetColorTexture(color[1], color[2], color[3], 1)
    end
  end
end

local function CreateFilterGlyph(button)
  local glyph = CreateFrame("Frame", nil, button)
  glyph:SetSize(FILTER_BUTTON_ICON_SIZE, FILTER_BUTTON_ICON_SIZE)
  glyph:SetPoint("CENTER")
  glyph.ggParts = {}

  local function AddPart(width, height, x, y)
    local shadow = glyph:CreateTexture(nil, "BACKGROUND")
    shadow:SetSize(width, height)
    shadow:SetPoint("CENTER", glyph, "CENTER", x + 1, y - 1)
    shadow:SetColorTexture(0, 0, 0, 0.75)

    local part = glyph:CreateTexture(nil, "ARTWORK")
    part:SetSize(width, height)
    part:SetPoint("CENTER", glyph, "CENTER", x, y)
    part:SetColorTexture(FILTER_GLYPH_NORMAL[1], FILTER_GLYPH_NORMAL[2], FILTER_GLYPH_NORMAL[3], 1)
    glyph.ggParts[#glyph.ggParts + 1] = part
  end

  -- Compact funnel/filter mark. It deliberately uses only WoW-created
  -- textures rather than an external image, avoiding the solid-green texture
  -- failure seen on some Forever/Camelot builds.
  AddPart(12, 2, 0, 4)
  AddPart(8, 2, 0, 1)
  AddPart(5, 2, 0, -2)
  AddPart(2, 5, 0, -5)

  return glyph
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

  -- Mirror Blizzard's small options gear: subdued at rest, fully visible on
  -- hover/press. Active filters remain gold instead of using a colored square.
  if not enabled then
    button.Icon:SetAlpha(0.35)
    SetFilterGlyphColor(button.Icon, FILTER_GLYPH_DISABLED)
  elseif button.ggHover or button.ggPressed then
    button.Icon:SetAlpha(1.0)
    SetFilterGlyphColor(button.Icon, FILTER_GLYPH_HOVER)
  elseif active then
    button.Icon:SetAlpha(1.0)
    SetFilterGlyphColor(button.Icon, FILTER_GLYPH_ACTIVE)
  else
    button.Icon:SetAlpha(0.80)
    SetFilterGlyphColor(button.Icon, FILTER_GLYPH_NORMAL)
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
    if type(optionsButton.GetFrameLevel) == "function" and type(button.SetFrameLevel) == "function" then
      local ok, level = pcall(optionsButton.GetFrameLevel, optionsButton)
      if ok and tonumber(level) then button:SetFrameLevel(tonumber(level)) end
    end
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
      + CountSelected(self.db and self.db.lfg_filter_player_roles)
      + CountSelected(self.db and self.db.lfg_filter_player_classes)
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
  self.db.lfg_filter_player_roles = { TANK = false, HEALER = false, DAMAGER = false }
  self.db.lfg_filter_player_classes = {}
  self:LFGFilters_RebuildPanelContents()
  self:LFGFilters_OnChanged()
end

function addon:LFGFilters_RebuildPanelContents()
  local panel = self.lfgFilterPanel
  if not panel or not panel.ggContent then return end
  local content = panel.ggContent

  if type(content.ggChildren) == "table" then
    for _, child in ipairs(content.ggChildren) do
      -- WoW frames cannot be destroyed. Hide old controls and keep them owned
      -- by the panel; this avoids SetParent(nil) differences between clients.
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
    fs:SetWidth(width or 262)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetText(text)
    return fs
  end

  local groupAvailable = self.HasClientCapability and self:HasClientCapability("lfgSearchMemberCounts")
  local playerAvailable = self.HasClientCapability and self:HasClientCapability("lfgSearchPlayerInfo")

  Text("GameFontNormal", self:Tr("LFG_FILTERS_GROUP_TITLE"), 8, -6, 258)
  Text("GameFontHighlightSmall", self:Tr("LFG_FILTERS_GROUP_HELP"), 8, -27, 258)

  if groupAvailable then
    local x = 19
    for _, role in ipairs(ROLE_ORDER) do
      local roleKey = role
      local cb = KeepChild(CreateCheck(content, x, -66, self:Tr(ROLE_TEXT_KEY[role]), self.db.lfg_filter_group_roles[role] == true, function(value)
        addon.db.lfg_filter_group_roles[roleKey] = value
        addon:LFGFilters_OnChanged()
      end, nil, role))
      cb.ggLabel:SetPoint("LEFT", cb, "RIGHT", 0, 0)
      x = x + 84
    end
  else
    Text("GameFontDisableSmall", self:Tr("LFG_FILTERS_UNAVAILABLE"), 8, -68, 258)
  end

  local divider = KeepRegion(content:CreateTexture(nil, "ARTWORK"))
  divider:SetColorTexture(0.35, 0.32, 0.25, 0.75)
  divider:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -103)
  divider:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, -103)
  divider:SetHeight(1)

  Text("GameFontNormal", self:Tr("LFG_FILTERS_PLAYER_TITLE"), 8, -119, 258)
  Text("GameFontHighlightSmall", self:Tr("LFG_FILTERS_PLAYER_HELP"), 8, -140, 258)

  if playerAvailable then
    Text("GameFontNormalSmall", self:Tr("LFG_FILTERS_ROLES"), 8, -180, 258)
    local x = 19
    for _, role in ipairs(ROLE_ORDER) do
      local roleKey = role
      KeepChild(CreateCheck(content, x, -197, self:Tr(ROLE_TEXT_KEY[role]), self.db.lfg_filter_player_roles[role] == true, function(value)
        addon.db.lfg_filter_player_roles[roleKey] = value
        addon:LFGFilters_OnChanged()
      end, nil, role))
      x = x + 84
    end

    Text("GameFontNormalSmall", self:Tr("LFG_FILTERS_CLASSES"), 8, -234, 258)
    local classes = self:LFGFilters_GetAvailableClasses()
    for index, classInfo in ipairs(classes) do
      local col = (index - 1) % 2
      local row = math.floor((index - 1) / 2)
      local classFile = classInfo.file
      local cb = KeepChild(CreateCheck(content, 8 + col * 132, -251 - row * 24, classInfo.name, self.db.lfg_filter_player_classes[classFile] == true, function(value)
        addon.db.lfg_filter_player_classes[classFile] = value
        addon:LFGFilters_OnChanged()
      end, classFile, nil))
      cb.ggLabel:SetWidth(102)
    end
  else
    Text("GameFontDisableSmall", self:Tr("LFG_FILTERS_UNAVAILABLE"), 8, -183, 258)
  end

  self:LFGFilters_UpdateStatusText()
end

function addon:LFGFilters_CreatePanel(root)
  if self.lfgFilterPanel then return self.lfgFilterPanel end
  root = root or (self.GetLFGRootFrame and self:GetLFGRootFrame()) or UIParent
  if not root then return nil end

  -- Keep the side panel out of LFGBrowseFrame/LFGParentFrame's mouse hierarchy.
  -- Forever's ScrollBox consumes wheel input; a child panel anchored outside the
  -- parent can otherwise bubble wheel events back into the browse list.
  local panel = CreateStandardPanel(UIParent or root)
  panel:SetSize(296, 474)
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
  -- Explicitly consume the wheel while the cursor is over the side panel. The
  -- filter window itself has no scrollable content.
  if type(panel.SetScript) == "function" then panel:SetScript("OnMouseWheel", function() end) end
  panel:Hide()

  local title = panel.TitleText or (panel.TitleContainer and panel.TitleContainer.TitleText)
  if not title then
    title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", panel, "TOP", 0, -7)
  end
  title:SetText(self:Tr("LFG_FILTERS_TITLE"))

  if not panel.CloseButton then
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
    panel.CloseButton = close
  end
  panel.CloseButton:SetScript("OnClick", function()
    panel:Hide()
    if addon.db then addon.db.lfg_filter_panel_open = false end
  end)

  local content = CreateFrame("Frame", nil, panel)
  content:SetPoint("TOPLEFT", panel, "TOPLEFT", 11, -31)
  content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -11, 43)
  panel.ggContent = content

  local status = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  status:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 18, 17)
  status:SetWidth(180)
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
  local desiredParent = (searchFrame == _G.LFGBrowseFrame and UIParent) or searchFrame
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

    local icon = CreateFilterGlyph(button)
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
        panel:Hide()
        if addon.db then addon.db.lfg_filter_panel_open = false end
      else
        panel:Show()
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
  button:SetShown(self.db and self.db.lfg_filters_enabled ~= false and (canGroup or canPlayer))
  self:LFGFilters_UpdateButtonState()
  return button
end

function addon:LFGFilters_HookFrames()
  local searchFrame = self.GetLFGSearchFrame and self:GetLFGSearchFrame() or nil
  if searchFrame then
    self:LFGFilters_CreateButton(searchFrame)
    local root = self.GetLFGRootFrame and self:GetLFGRootFrame() or nil
    self:LFGFilters_CreatePanel(root)
    self:LFGFilters_LayoutPanel()
    if searchFrame == _G.LFGBrowseFrame then
      self:LFGFilters_HookForeverFrame(searchFrame)
    end

    self._ggFilterVisibilityHooks = self._ggFilterVisibilityHooks or {}
    if not self._ggFilterVisibilityHooks[searchFrame] and type(searchFrame.HookScript) == "function" then
      self._ggFilterVisibilityHooks[searchFrame] = true
      searchFrame:HookScript("OnShow", function()
        addon:LFGFilters_CreateButton(searchFrame)
        addon:LFGFilters_LayoutPanel()
        if addon.db and addon.db.lfg_filter_panel_open and addon.lfgFilterPanel then addon.lfgFilterPanel:Show() end
      end)
      searchFrame:HookScript("OnHide", function()
        if addon.lfgFilterPanel then addon.lfgFilterPanel:Hide() end
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

  -- Recycled ScrollBox rows are rebound while scrolling without necessarily
  -- rebuilding the whole result list. Re-apply presentation filtering after a
  -- row update, still without touching Blizzard's result data model.
  if not self._ggForeverRowFilterHooked and type(_G.LFGBrowseSearchEntry_Update) == "function" and type(hooksecurefunc) == "function" then
    local ok = pcall(hooksecurefunc, "LFGBrowseSearchEntry_Update", function()
      if addon then addon:LFGFilters_ScheduleForeverPresentation(_G.LFGBrowseFrame) end
    end)
    if ok then self._ggForeverRowFilterHooked = true end
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
  print((self.printPrefix or "GroupGuard LFG:"), "rawTotal=", tostring(total), "rawCount=", tostring(type(results) == "table" and #results or 0),
    "shownCount=", tostring(searchFrame and type(searchFrame.results) == "table" and #searchFrame.results or 0))

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
  end
end
