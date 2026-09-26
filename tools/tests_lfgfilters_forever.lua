local pass, fail = 0, 0
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
    lfg_filter_player_roles = { TANK=false, HEALER=false, DAMAGER=false },
    lfg_filter_player_classes = {},
  },
  SafeNumber = function(_, v, fallback) local n=tonumber(v); if n then return n end; return fallback end,
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

print("\n--- Forever filters: independent Groups / Players ---")
infos[1] = { numMembers=4, activityIDs={101} }
counts[1] = { TANK_REMAINING=1, HEALER_REMAINING=1, DAMAGER_REMAINING=0 }
addon.db.lfg_filter_group_roles = { TANK=true, HEALER=true, DAMAGER=false }
check("Groups Tank+Healer uses AND when both remain", addon:LFGFilters_ResultMatches(1, {}) == true)
counts[1].HEALER_REMAINING = 0
check("Groups rejects when one selected role is already filled", addon:LFGFilters_ResultMatches(1, {}) == false)

infos[2] = { numMembers=1, activityIDs={101} }
players[2] = { [1] = { classFilename="DRUID", assignedRole="HEALER", lfgRoles={tank=false,healer=true,dps=true} } }
addon.db.lfg_filter_player_classes = { DRUID=true }
addon.db.lfg_filter_player_roles = { HEALER=true }
check("Players class+role matches same solo player", addon:LFGFilters_ResultMatches(2, {}) == true)
addon.db.lfg_filter_player_classes = { MAGE=true }
check("Players class mismatch rejects solo player", addon:LFGFilters_ResultMatches(2, {}) == false)

addon.db.lfg_filter_group_roles = { TANK=true, HEALER=false, DAMAGER=false }
addon.db.lfg_filter_player_classes = {}
addon.db.lfg_filter_player_roles = {}
check("Group filter does not remove Players category", addon:LFGFilters_ResultMatches(2, {}) == true)
addon.db.lfg_filter_group_roles = { TANK=false, HEALER=false, DAMAGER=false }
addon.db.lfg_filter_player_classes = { MAGE=true }
check("Player filter does not remove Groups category", addon:LFGFilters_ResultMatches(1, {}) == true)

players[2] = nil
check("Unavailable streamed player data fails open", addon:LFGFilters_ResultMatches(2, {}) == true)


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
local scrollBox = { SetDataProvider=function(_, p) provider=p end }
local noResults = { shown=false, Show=function(self) self.shown=true end, Hide=function(self) self.shown=false end, SetText=function() end }
LFGBrowseFrame = { searching=false, ScrollBox=scrollBox, results={1,2,3,4}, NoResultsFound=noResults }
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
check("visible result count excludes nonmatches", addon._ggForeverVisibleResults == 3, addon._ggForeverVisibleResults)
local flat = {}
for _, top in ipairs(provider.children) do
  if top.data and top.data.resultID then flat[#flat+1]=top.data.resultID end
  for _, child in ipairs(top.children or {}) do if child.data and child.data.resultID then flat[#flat+1]=child.data.resultID end end
end
local joined=table.concat(flat, ",")
check("nonmatching result is absent from visual tree", joined == "1,2,4", joined)
check("self listing remains visible", joined:find("4",1,true) ~= nil)

print("\n--- Filter launcher visibility regression ---")
local function frame(parent)
  local f={parent=parent,shown=true,points={},level=10,strata="MEDIUM",scripts={}}
  function f:GetParent() return self.parent end
  function f:SetParent(p) self.parent=p end
  function f:SetSize(w,h) self.w=w self.h=h end
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
addon:LFGFilters_HookFrames()
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

print(string.format("\n=== Forever filter regression: %d passed, %d failed ===", pass, fail))
os.exit(fail == 0 and 0 or 1)
