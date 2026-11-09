local pass, fail = 0, 0
local HARNESS_REVISION = "4.9.12"
print("[GroupGuardLFG] Forever filter regression harness " .. HARNESS_REVISION)

local function check(name, ok, detail)
  if ok then pass = pass + 1; print("  ✓ " .. name)
  else fail = fail + 1; print("  ✗ " .. name .. (detail and (" -> " .. tostring(detail)) or "")) end
end

_G = _G or _ENV
UIParent = {}
ScrollBoxConstants = { RetainScrollPosition = true }
LFGVanillaBrowseDividerType = { CategorySolo = 1, CategoryGroup = 2 }
LFGVANILLA_SETTING_BROWSE_SHOW_COLLAPSIBLE_CATEGORIES = true
LFG_LIST_NO_RESULTS_FOUND = "No results"

local addon = {
  db = {
    lfg_filters_enabled = true,
    lfg_filter_group_roles = { TANK=false, HEALER=false, DAMAGER=false },
    lfg_filter_group_has_roles = { TANK=false, HEALER=false, DAMAGER=false },
    lfg_filter_player_roles = { TANK=false, HEALER=false, DAMAGER=false },
    lfg_filter_player_classes = {},
    lfg_filter_player_min_level = 0,
    lfg_filter_player_max_level = 0,
    lfg_filter_social_priority = true,
    lfg_filter_presets = {},
  },
  SafeNumber = function(_, v, fallback) local n=tonumber(v); if n then return n end; return fallback end,
  SafeText = function(_, v, fallback) return type(v)=="string" and v or fallback end,
  SafeObjectField = function(_, obj, key) return obj and obj[key] end,
  SafeGetElementData = function() return nil end,
  Tr = function(_, key) return key end,
  HasClientCapability = function() return true end,
  IsForeverClient = function() return true end,
}

local chunk, err = loadfile("../Modules/LFGFilters.lua")
assert(chunk, err)
chunk("GroupGuardLFG", addon)

local infos, counts, players = {}, {}, {}
addon.LFG_API_GetSearchResultInfo = function(_, id) return infos[id] end
addon.LFG_API_GetSearchResultMemberCounts = function(_, id) return counts[id] end
addon.LFG_API_GetSearchResultPlayerInfo = function(_, id, index) return players[id] and players[id][index] end
addon.LFG_API_GetActivityInfoTable = function(_, id) return { categoryID=2, useDungeonRoleExpectations=true, maxNumPlayers=5 } end

print("\n--- Forever filters: only matching active result categories ---")
infos[1] = { numMembers=4, activityIDs={101} }
counts[1] = { TANK_REMAINING=1, HEALER_REMAINING=1, DAMAGER_REMAINING=0 }
addon.db.lfg_filter_group_roles = { TANK=true, HEALER=true, DAMAGER=false }
check("Groups Tank+Healer uses AND when both remain", addon:LFGFilters_ResultMatches(1, {}) == true)
counts[1].HEALER_REMAINING = 0
check("Groups rejects when one selected role is already filled", addon:LFGFilters_ResultMatches(1, {}) == false)

addon.db.lfg_filter_group_roles = { TANK=false, HEALER=false, DAMAGER=false }
addon.db.lfg_filter_group_has_roles = { TANK=true, HEALER=true, DAMAGER=false }
counts[1] = { TANK=1, HEALER=1, DAMAGER=2 }
check("Groups Has Tank+Healer requires both roles already present", addon:LFGFilters_ResultMatches(1, {}) == true)
counts[1].HEALER = 0
check("Groups Has Tank+Healer rejects when healer is absent", addon:LFGFilters_ResultMatches(1, {}) == false)
addon.db.lfg_filter_group_has_roles = { TANK=false, HEALER=false, DAMAGER=false }

infos[2] = { numMembers=1, activityIDs={101} }
players[2] = { [1] = { classFilename="DRUID", assignedRole="HEALER", level=42, lfgRoles={tank=false,healer=true,dps=true} } }
addon.db.lfg_filter_player_classes = { DRUID=true }
addon.db.lfg_filter_player_roles = { HEALER=true }
check("Players class+role matches same solo player", addon:LFGFilters_ResultMatches(2, {}) == true)
addon.db.lfg_filter_player_classes = { MAGE=true }
check("Players class mismatch rejects solo player", addon:LFGFilters_ResultMatches(2, {}) == false)
addon.db.lfg_filter_player_classes = {}
addon.db.lfg_filter_player_roles = {}
addon.db.lfg_filter_player_min_level = 40
addon.db.lfg_filter_player_max_level = 50
check("Players level range accepts an in-range solo player", addon:LFGFilters_ResultMatches(2, {}) == true)
addon.db.lfg_filter_player_min_level = 43
check("Players minimum level rejects a lower solo player", addon:LFGFilters_ResultMatches(2, {}) == false)
addon.db.lfg_filter_player_min_level = 50
addon.db.lfg_filter_player_max_level = 40
check("Players normalize a reversed level range", addon:LFGFilters_ResultMatches(2, {}) == true)
addon.db.lfg_filter_player_min_level = 0
addon.db.lfg_filter_player_max_level = 0

addon.db.lfg_filter_group_roles = { TANK=true, HEALER=false, DAMAGER=false }
addon.db.lfg_filter_player_classes = {}
addon.db.lfg_filter_player_roles = {}
check("group-only conditions exclude the Players category", addon:LFGFilters_ResultMatches(2, {}) == false)
addon.db.lfg_filter_group_roles = { TANK=false, HEALER=false, DAMAGER=false }
addon.db.lfg_filter_player_classes = { MAGE=true }
check("player-only conditions exclude the Groups category", addon:LFGFilters_ResultMatches(1, {}) == false)

players[2] = nil
check("unavailable player data cannot pass active conditions", addon:LFGFilters_ResultMatches(2, {}) == false)

check("Forever healer flags override a default assigned damage role",addon:LFGFilters_PlayerHasRole({assignedRole="DAMAGER",lfgRoles={healer=true,dps=false}},{DAMAGER=true})==false)
check("Forever explicit healer choice is accepted",addon:LFGFilters_PlayerHasRole({assignedRole="DAMAGER",lfgRoles={healer=true,dps=false}},{HEALER=true})==true)
check("Forever unselected role flags do not fall back to assigned damage",addon:LFGFilters_PlayerHasRole({assignedRole="DAMAGER",lfgRoles={tank=false,healer=false,dps=false}},{DAMAGER=true})==false)
check("Forever assigned role remains a fallback when flags are unavailable",addon:LFGFilters_PlayerHasRole({assignedRole="HEALER"},{HEALER=true})==true)
addon.IsForeverClient=function() return false end
check("Retail retains its assigned-role contract",addon:LFGFilters_PlayerHasRole({assignedRole="DAMAGER",lfgRoles={healer=true,dps=false}},{DAMAGER=true})==true)
addon.IsForeverClient=function() return true end

addon.db.lfg_filter_group_roles={TANK=true}
addon.db.lfg_filter_player_classes={DRUID=true}
counts[1]={TANK_REMAINING=1}
players[2]={{classFilename="DRUID",assignedRole="HEALER",level=42}}
check("both active blocks retain a matching result of each kind",addon:LFGFilters_ResultMatches(1,{}) and addon:LFGFilters_ResultMatches(2,{}))
counts[1]={}
check("unknown required composition is excluded until data arrives",addon:LFGFilters_ResultMatches(1,{})==false)
counts[1]={TANK_REMAINING=1}
players[2]={{classFilename="DRUID",assignedRole="HEALER"}}
addon.db.lfg_filter_player_min_level=40
check("unknown required level cannot pass the player block",addon:LFGFilters_ResultMatches(2,{})==false)
addon.db.lfg_filter_player_min_level=0
local activityAPI=addon.LFG_API_GetActivityInfoTable
addon.LFG_API_GetActivityInfoTable=function() return {categoryID=1,useDungeonRoleExpectations=false} end
check("dungeon composition excludes unrelated activity groups",addon:LFGFilters_ResultMatches(1,{})==false)
addon.LFG_API_GetActivityInfoTable=activityAPI
addon.db.lfg_filter_group_roles={}

-- Multiple selections inside the Players block are alternatives within their
-- own set, while class + role remain an AND between the two sets.
infos[5] = { numMembers=1, activityIDs={101} }
infos[6] = { numMembers=1, activityIDs={101} }
infos[7] = { numMembers=1, activityIDs={101} }
players[5] = { [1] = { classFilename="DRUID", assignedRole="DAMAGER", lfgRoles={healer=false,dps=true} } }
players[6] = { [1] = { classFilename="MAGE", assignedRole="HEALER", lfgRoles={healer=true,dps=false} } }
players[7] = { [1] = { classFilename="ROGUE", assignedRole="DAMAGER", lfgRoles={healer=false,dps=true} } }
addon.db.lfg_filter_player_classes = { DRUID=true, MAGE=true }
addon.db.lfg_filter_player_roles = { HEALER=true, DAMAGER=true }
check("Players two classes use OR inside class selection", addon:LFGFilters_ResultMatches(5, {}) == true and addon:LFGFilters_ResultMatches(6, {}) == true)
check("Players two roles use OR inside role selection", addon:LFGFilters_ResultMatches(5, {}) == true and addon:LFGFilters_ResultMatches(6, {}) == true)
check("Players class set still rejects an unselected class", addon:LFGFilters_ResultMatches(7, {}) == false)


print("\n--- Forever protected-state isolation ---")
local protectedFrame = { results={11,12,13}, totalResults=3 }
_G.LFGBrowseFrame = protectedFrame
local originalResults = protectedFrame.results
local scheduled = 0
local oldSchedule = addon.LFGFilters_ScheduleForeverPresentation
addon.LFGFilters_ScheduleForeverPresentation = function() scheduled = scheduled + 1 end
addon:LFGFilters_FilterFrameResults(protectedFrame)
addon.LFGFilters_ScheduleForeverPresentation = oldSchedule
check("Forever FilterFrameResults schedules presentation only", scheduled == 1, scheduled)
check("Forever results table is not replaced", protectedFrame.results == originalResults)
check("Forever totalResults is not modified", protectedFrame.totalResults == 3, protectedFrame.totalResults)

print("\n--- Forever visual provider rebuild: no hidden row height ---")
local function node(data)
  local n = { data=data, children={} }
  function n:Insert(v) local c=node(v); self.children[#self.children+1]=c; return c end
  return n
end
CreateTreeDataProvider = function()
  local p = node(nil)
  return p
end
local provider
local scrollBox = { SetDataProvider=function(_, p) provider=p end, GetDataProvider=function() return provider end }
-- A native provider/selection must never be touched by addon filtering, even
-- when no Lua error is thrown by the setter itself (taint can surface later).
local nativeWrites = 0
local nativeScrollBox = { SetDataProvider=function() nativeWrites=nativeWrites+1; error("native initializer would compare a secret width") end }
addon.ForeverBrowse_GetScrollBox = function() return scrollBox end
addon._ggForeverBrowseView = { ScrollBox=scrollBox, collapsed={}, IsShown=function() return true end }
local noResults = { shown=false, Show=function(self) self.shown=true end, Hide=function(self) self.shown=false end, SetText=function() end }
LFGBrowseFrame = { searching=false, ScrollBox=nativeScrollBox, results={1,2,3,4}, NoResultsFound=noResults,
  IsShown=function() return true end,
  selectionBehavior={ ClearSelections=function() nativeWrites=nativeWrites+1 end } }
_G.LFGBrowseFrame = LFGBrowseFrame
infos[1] = { numMembers=4, activityIDs={101} }
infos[2] = { numMembers=1, activityIDs={101} }
infos[3] = { numMembers=5, activityIDs={101} }
infos[4] = { numMembers=1, activityIDs={101}, hasSelf=true }
counts[1] = { TANK_REMAINING=1 }
counts[3] = { TANK_REMAINING=0 }
players[2] = { [1] = { classFilename="DRUID", assignedRole="HEALER", lfgRoles={healer=true} } }
players[4] = { [1] = { classFilename="MAGE", assignedRole="DAMAGER", lfgRoles={dps=true} } }
addon.db.lfg_filter_group_roles = { TANK=true, HEALER=false, DAMAGER=false }
addon.db.lfg_filter_player_classes = { DRUID=true }
addon.db.lfg_filter_player_roles = {}
local ok = addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)
check("provider rebuild succeeds", ok == true)
check("filtering never initializes native rows or changes native selection", nativeWrites == 0, nativeWrites)
check("filtering leaves native empty-state presentation untouched", noResults.shown == false)
LFGBrowseFrame.IsShown=function() return true end
check("diagnostic count belongs to the installed filtered provider", addon:LFGFilters_GetForeverVisibleCount()==addon._ggForeverVisibleResults)
local savedProvider=provider
provider={}
check("native-overwritten provider invalidates the cached count", addon:LFGFilters_GetForeverVisibleCount()==nil)
provider=savedProvider
local savedResults=LFGBrowseFrame.results
LFGBrowseFrame.results={1,2,3,4}
check("new native result list invalidates the cached count", addon:LFGFilters_GetForeverVisibleCount()==nil)
LFGBrowseFrame.results=savedResults
LFGBrowseFrame.searching=true
check("search in progress has no settled presentation count", addon:LFGFilters_GetForeverVisibleCount()==nil)
LFGBrowseFrame.searching=false

check("visible result count excludes nonmatches", addon._ggForeverVisibleResults == 2, addon._ggForeverVisibleResults)
local flat = {}
for _, top in ipairs(provider.children) do
  if top.data and top.data.resultID then flat[#flat+1]=top.data.resultID end
  for _, child in ipairs(top.children or {}) do if child.data and child.data.resultID then flat[#flat+1]=child.data.resultID end end
end
local joined=table.concat(flat, ",")
check("only matching group and player rows are emitted", joined == "1,2", joined)
check("nonmatching own listing does not bypass selected classes", joined:find("4",1,true) == nil)

-- Interleaved Blizzard results must still produce exactly one native Groups
-- block and one Players block. The previous transition-based builder created
-- duplicate headers (Groups/Players/Groups/Players) after restrictive filters.
local dividerCounts = { [1]=0, [2]=0 }
for _, top in ipairs(provider.children) do
  local divider = top.data and top.data.dividerType
  if dividerCounts[divider] ~= nil then dividerCounts[divider] = dividerCounts[divider] + 1 end
end
check("visual tree contains one Groups divider", dividerCounts[2] == 1, dividerCounts[2])
check("visual tree contains one Players divider", dividerCounts[1] == 1, dividerCounts[1])
check("native category order remains Groups then Players",
  provider.children[1] and provider.children[1].data and provider.children[1].data.dividerType == 2
  and provider.children[2] and provider.children[2].data and provider.children[2].data.dividerType == 1)
check("Players category contains only matching players",
  provider.children[2] and #provider.children[2].children == 1)
players[4][1].classFilename="DRUID"
addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)
check("a matching own listing keeps social priority within its category",
  provider.children[2].children[1].data.resultID==4 and addon._ggForeverVisibleResults==3)
addon.db.lfg_filter_player_classes={}
check("own solo listing is omitted in groups-only mode",addon:LFGFilters_GetForeverPresentationState(4,LFGBrowseFrame,4).show==false)
addon.db.lfg_filter_player_classes={MAGE=true}
players[4][1].classFilename="DRUID"
local foreverClient=addon.IsForeverClient
addon.IsForeverClient=function() return false end
check("Mainline's existing own-listing behavior is preserved",addon:LFGFilters_ResultMatches(4,{})==true)
addon.IsForeverClient=foreverClient
addon.db.lfg_filter_player_classes={DRUID=true}

-- Social results keep native category grouping but move ahead of ordinary rows.
infos[8] = { numMembers=3, activityIDs={101}, numGuildMates=0 }
infos[9] = { numMembers=3, activityIDs={101}, numGuildMates=1 }
counts[8] = { TANK_REMAINING=1 }
counts[9] = { TANK_REMAINING=1 }
LFGBrowseFrame.results = {8,9}
addon.db.lfg_filter_group_roles = { TANK=true, HEALER=false, DAMAGER=false }
addon.db.lfg_filter_player_classes = {}
addon.db.lfg_filter_social_priority = true
addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)
local socialOrder = {}
for _, top in ipairs(provider.children) do
  for _, child in ipairs(top.children or {}) do
    if child.data and child.data.resultID then socialOrder[#socialOrder+1]=child.data.resultID end
  end
end
check("guild/friend listings are prioritized inside their category", table.concat(socialOrder, ",") == "9,8", table.concat(socialOrder, ","))

print("\n--- Saved filter presets ---")
addon.db.lfg_filter_group_roles = { TANK=true, HEALER=true, DAMAGER=false }
addon.db.lfg_filter_group_has_roles = { TANK=false, HEALER=false, DAMAGER=true }
addon.db.lfg_filter_player_roles = { HEALER=true }
addon.db.lfg_filter_player_classes = { DRUID=true }
addon.db.lfg_filter_player_min_level = 40
addon.db.lfg_filter_player_max_level = 50
check("named filter preset saves", addon:LFGFilters_SavePreset("Level heal") == true)
addon.db.lfg_filter_group_roles = {}
addon.db.lfg_filter_group_has_roles = {}
addon.db.lfg_filter_player_roles = {}
addon.db.lfg_filter_player_classes = {}
addon.db.lfg_filter_player_min_level = 0
addon.db.lfg_filter_player_max_level = 0
check("named filter preset restores all filter dimensions", addon:LFGFilters_ApplyState(addon.db.lfg_filter_presets[1].filters) == true
  and addon.db.lfg_filter_group_roles.TANK == true
  and addon.db.lfg_filter_group_roles.HEALER == true
  and addon.db.lfg_filter_group_has_roles.DAMAGER == true
  and addon.db.lfg_filter_player_roles.HEALER == true
  and addon.db.lfg_filter_player_classes.DRUID == true
  and addon.db.lfg_filter_player_min_level == 40
  and addon.db.lfg_filter_player_max_level == 50)

print("\n--- Filter launcher visibility regression ---")
local function frame(parent)
  local f={parent=parent,shown=true,points={},level=10,strata="MEDIUM",scripts={}}
  function f:GetParent() return self.parent end
  function f:SetParent(p) self.parent=p end
  function f:SetSize(w,h) self.w=w self.h=h end
  function f:SetWidth(w) self.w=w end
  function f:SetHeight(h) self.h=h end
  function f:GetWidth() return self.w or 0 end
  function f:GetHeight() return self.h or 0 end
  function f:SetText(v) self.text=v end
  function f:GetText() return self.text end
  function f:SetJustifyH(v) self.justifyH=v end
  function f:SetJustifyV(v) self.justifyV=v end
  function f:SetTextColor(...) self.textColor={...} end
  function f:SetChecked(v) self.checked=v == true end
  function f:GetChecked() return self.checked == true end
  function f:EnableMouse(v) self.mouseEnabled = v ~= false end
  function f:EnableMouseWheel(v) self.mouseWheelEnabled = v ~= false end
  function f:SetScrollChild(child) self.scrollChild=child end
  function f:GetVerticalScroll() return self.scrollOffset or 0 end
  function f:SetVerticalScroll(value) self.scrollOffset=value end
  function f:GetVerticalScrollRange() return 0 end
  function f:UpdateScrollChildRect() end
  function f:SetMouseClickEnabled(v) self.mouseClickEnabled=v end
  function f:SetMouseMotionEnabled(v) self.mouseMotionEnabled=v end
  function f:SetPropagateMouseClicks(v) self.propagateMouseClicks=v end
  function f:SetPropagateMouseMotion(v) self.propagateMouseMotion=v end
  function f:SetClampedToScreen(v) self.clampedToScreen=v end
  function f:SetBackdrop(v) self.backdrop=v end
  function f:SetAtlas(v) self.atlas=v end
  function f:SetHitRectInsets() end
  function f:RegisterForClicks() end
  function f:SetScript(k,v) self.scripts[k]=v end
  function f:HookScript(k,v)
    self.hooks = self.hooks or {}
    self.hooks[k] = self.hooks[k] or {}
    table.insert(self.hooks[k], v)
  end
  function f:RunHooks(k)
    for _, fn in ipairs((self.hooks and self.hooks[k]) or {}) do fn(self) end
  end
  function f:CreateTexture()
    local t=frame(self)
    function t:SetColorTexture() end
    function t:SetTexture(v) self.texture=v end
    function t:SetTexCoord(...) self.texCoord={...} end
    function t:SetVertexColor(...) self.vertexColor={...} end
    function t:SetBlendMode(v) self.blendMode=v end
    return t
  end
  function f:CreateFontString() return frame(self) end
  function f:SetPoint(...) self.points={...} end
  function f:ClearAllPoints() self.points={} end
  function f:SetAlpha() end
  function f:SetShown(v) self.shown=v end
  function f:Show() self.shown=true end
  function f:Hide() self.shown=false end
  function f:IsShown() return self.shown end
  function f:IsVisible()
    if not self.shown then return false end
    if self.parent and type(self.parent.IsVisible) == "function" then return self.parent:IsVisible() end
    return true
  end
  function f:IsEnabled() return true end
  function f:SetFrameStrata(v) self.strata=v end
  function f:GetFrameStrata() return self.strata end
  function f:SetFrameLevel(v) self.level=v end
  function f:GetFrameLevel() return self.level end
  return f
end
UIParent=frame(nil); _G.UIParent=UIParent
CreateFrame=function(_,_,parent) return frame(parent) end
local lfgRoot=frame(nil); _G.LFGParentFrame=lfgRoot
local options=frame(nil); options.level=30
local browse=frame(lfgRoot); browse.OptionsButton=options
LFGBrowseFrame=browse; _G.LFGBrowseFrame=browse
addon.lfgFilterButton=nil
addon.db.lfg_filters_enabled=false
addon.HasClientCapability=function() return false end
addon.IsForeverClient=function() return true end
local btn=addon:LFGFilters_CreateButton(browse)
check("filter icon texture is assigned", btn and btn.Icon and btn.Icon.texture == "Interface\\AddOns\\GroupGuardLFG\\Media\\filter_funnel.tga", btn and btn.Icon and btn.Icon.texture)
check("button remains visible when master filtering is disabled", btn and btn.shown == true)
check("Forever button remains addon-owned under UIParent", btn and btn.parent == UIParent)
check("button is anchored below Blizzard OptionsButton", btn and btn.points[2] == options and btn.points[3] == "BOTTOMRIGHT")
check("button frame level is raised above options control", btn and btn.level > options.level, btn and btn.level)

-- Hook the real lifecycle path, then emulate closing/reopening Group Finder.
addon.GetLFGSearchFrame=function() return browse end
addon.GetLFGRootFrame=function() return lfgRoot end
-- The isolated provider fixture above has no native UI methods.
addon._ggForeverBrowseView=nil
local hookOk, hookErr = pcall(function() addon:LFGFilters_HookFrames() end)
check("filter lifecycle hooks install without mock UI errors", hookOk == true, hookErr)
check("filter panel is created by the lifecycle path", hookOk and addon.lfgFilterPanel ~= nil)
if hookOk then
  lfgRoot.shown=false
  lfgRoot:RunHooks("OnHide")
  check("button hides when the LFG root closes", btn and btn.shown == false)
  lfgRoot.shown=true
  lfgRoot:RunHooks("OnShow")
  check("button returns when the LFG root reopens", btn and btn.shown == true)

  -- Also cover direct Browse hide/show while the root remains open.
  browse.shown=false
  browse:RunHooks("OnHide")
  check("button hides when Browse closes", btn and btn.shown == false)
  browse.shown=true
  browse:RunHooks("OnShow")
  check("button returns when Browse reopens", btn and btn.shown == true)

  print("\n--- Per-result refresh optimization ---")
  addon.db.lfg_filters_enabled = true
  addon.HasClientCapability = function() return true end
  addon.db.lfg_filter_group_roles = { TANK=true, HEALER=false, DAMAGER=false }
  addon.db.lfg_filter_group_has_roles = {}
  infos[1] = { numMembers=4, activityIDs={101} }
  counts[1] = { TANK_REMAINING=1, TANK=0 }
  local oldState = addon:LFGFilters_GetForeverPresentationState(1, browse, 1)
  addon._ggForeverPresentationState = { [1] = oldState }
  -- The row-only optimization requires a current visible view. The previous
  -- fixture accidentally asserted it with no presentation at all.
  local currentProvider={}
  browse.results={1}
  addon._ggForeverPresentationResults=browse.results
  addon._ggForeverPresentationProvider=currentProvider
  addon._ggForeverVisibleResults=1
  addon._ggForeverRefreshPending=false
  addon._ggForeverBrowseView={IsShown=function() return true end,ScrollBox={GetDataProvider=function() return currentProvider end}}
  local rebuilds = 0
  local savedSchedule = addon.LFGFilters_ScheduleForeverPresentation
  addon.LFGFilters_ScheduleForeverPresentation = function() rebuilds = rebuilds + 1 end
  addon:LFGFilters_HandleForeverResultUpdated(1)
  check("unchanged result does not rebuild the provider", rebuilds == 0, rebuilds)
  counts[1].TANK_REMAINING = 0
  addon:LFGFilters_HandleForeverResultUpdated(1)
  check("visibility change rebuilds the provider once", rebuilds == 1, rebuilds)
  addon.LFGFilters_ScheduleForeverPresentation = savedSchedule

  browse.shown=false
  addon._ggForeverRefreshPending=false
  addon:LFGFilters_ScheduleForeverPresentation(browse)
  check("hidden Forever browse defers presentation work", addon._ggForeverRefreshPending == true)
  browse.shown=true
end

print(string.format("\n=== Forever filter regression: %d passed, %d failed ===", pass, fail))
os.exit(fail == 0 and 0 or 1)
