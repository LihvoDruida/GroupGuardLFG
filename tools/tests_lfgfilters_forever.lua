-- Current independent-category contract; real SafeAPI, only game C APIs are fixtures.
local pass, fail = 0, 0
local HARNESS_REVISION = "4.9.19"
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
  Tr = function(_, key) return key end,
  HasClientCapability = function() return true end,
  IsForeverClient = function() return true end,
}

assert(loadfile("../Core/SafeAPI.lua"))("GroupGuardLFG",addon)
local chunk, err = loadfile("../Modules/LFGFilters.lua")
assert(chunk, err)
chunk("GroupGuardLFG", addon)

local infos, counts, players = {}, {}, {}
local secret={}
GetTime=function() return 100 end
canaccessvalue=function(v) return v~=secret end
issecretvalue=function(v) return v==secret end
C_LFGList={
 GetSearchResultInfo=function(id) return infos[id] end,
 GetSearchResultMemberCounts=function(id) return counts[id] end,
 GetSearchResultPlayerInfo=function(id,index) return players[id] and players[id][index] end,
 GetActivityInfoTable=function() return {categoryID=2,useDungeonRoleExpectations=true,maxNumPlayers=5} end,
}

local function matches(id,frame)
 addon:LFG_API_ClearCaches()
 return addon:LFGFilters_ResultMatches(id,frame)
end
print("\n--- Forever filters: independent group and player categories ---")
infos[1] = { numMembers=4, activityIDs={101} }
counts[1] = { TANK_REMAINING=1, HEALER_REMAINING=1, DAMAGER_REMAINING=0 }
addon.db.lfg_filter_group_roles = { TANK=true, HEALER=true, DAMAGER=false }
check("Groups Tank+Healer uses AND when both remain", matches(1, {}) == true)
counts[1].HEALER_REMAINING = 0
check("Groups rejects when one selected role is already filled", matches(1, {}) == false)

addon.db.lfg_filter_group_roles = { TANK=false, HEALER=false, DAMAGER=false }
addon.db.lfg_filter_group_has_roles = { TANK=true, HEALER=true, DAMAGER=false }
counts[1] = { TANK=1, HEALER=1, DAMAGER=2 }
check("Groups Has Tank+Healer requires both roles already present", matches(1, {}) == true)
counts[1].HEALER = 0
check("Groups Has Tank+Healer rejects when healer is absent", matches(1, {}) == false)
addon.db.lfg_filter_group_has_roles = { TANK=false, HEALER=false, DAMAGER=false }

infos[2] = { numMembers=1, activityIDs={101} }
players[2] = { [1] = { classFilename="DRUID", assignedRole="HEALER", level=42, lfgRoles={tank=false,healer=true,dps=true} } }
addon.db.lfg_filter_player_classes = { DRUID=true }
addon.db.lfg_filter_player_roles = { HEALER=true }
check("Players class+role matches same solo player", matches(2, {}) == true)
addon.db.lfg_filter_player_classes = { MAGE=true }
check("Players class mismatch rejects solo player", matches(2, {}) == false)
addon.db.lfg_filter_player_classes = {}
addon.db.lfg_filter_player_roles = {}
addon.db.lfg_filter_player_min_level = 40
addon.db.lfg_filter_player_max_level = 50
check("Players level range accepts an in-range solo player", matches(2, {}) == true)
addon.db.lfg_filter_player_min_level = 43
check("Players minimum level rejects a lower solo player", matches(2, {}) == false)
addon.db.lfg_filter_player_min_level = 50
addon.db.lfg_filter_player_max_level = 40
check("Players normalize a reversed level range", matches(2, {}) == true)
addon.db.lfg_filter_player_min_level = 0
addon.db.lfg_filter_player_max_level = 0

addon.db.lfg_filter_group_roles = { TANK=true, HEALER=false, DAMAGER=false }
addon.db.lfg_filter_player_classes = {}
addon.db.lfg_filter_player_roles = {}
check("group-only conditions preserve the Players category", matches(2, {}) == true)
addon.db.lfg_filter_group_roles = { TANK=false, HEALER=false, DAMAGER=false }
addon.db.lfg_filter_player_classes = { MAGE=true }
check("player-only conditions preserve the Groups category", matches(1, {}) == true)

players[2] = nil
check("unavailable player data cannot pass active conditions", matches(2, {}) == false)

check("Forever healer flags override a default assigned damage role",addon:LFGFilters_PlayerHasRole({assignedRole="DAMAGER",lfgRoles={healer=true,dps=false}},{DAMAGER=true})==false)
check("Forever explicit healer choice is accepted",addon:LFGFilters_PlayerHasRole({assignedRole="DAMAGER",lfgRoles={healer=true,dps=false}},{HEALER=true})==true)
check("Forever unselected role flags do not fall back to assigned damage",addon:LFGFilters_PlayerHasRole({assignedRole="DAMAGER",lfgRoles={tank=false,healer=false,dps=false}},{DAMAGER=true})==false)
check("Forever assigned role cannot replace unavailable advertised choices",addon:LFGFilters_PlayerHasRole({assignedRole="HEALER"},{HEALER=true})==nil)
addon.IsForeverClient=function() return false end
check("Retail retains its assigned-role contract",addon:LFGFilters_PlayerHasRole({assignedRole="DAMAGER",lfgRoles={healer=true,dps=false}},{DAMAGER=true})==true)
addon.IsForeverClient=function() return true end

addon.db.lfg_filter_group_roles={TANK=true}
addon.db.lfg_filter_player_classes={DRUID=true}
counts[1]={TANK_REMAINING=1}
players[2]={{classFilename="DRUID",assignedRole="HEALER",level=42}}
check("both active blocks retain a matching result of each kind",matches(1,{}) and matches(2,{}))
counts[1]={}
check("unknown required composition is excluded until data arrives",matches(1,{})==false)
counts[1]={TANK_REMAINING=1}
players[2]={{classFilename="DRUID",assignedRole="HEALER"}}
addon.db.lfg_filter_player_min_level=40
check("unknown required level cannot pass the player block",matches(2,{})==false)
addon.db.lfg_filter_player_min_level=0
local activityAPI=addon.LFG_API_GetActivityInfoTable
addon.LFG_API_GetActivityInfoTable=function() return {categoryID=1,useDungeonRoleExpectations=false} end
check("dungeon composition preserves unrelated activity groups",matches(1,{})==true)
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
check("Players two classes use OR inside class selection", matches(5, {}) == true and matches(6, {}) == true)
check("Players two roles use OR inside role selection", matches(5, {}) == true and matches(6, {}) == true)
check("Players class set still rejects an unselected class", matches(7, {}) == false)



-- New contract coverage for secret snapshots and partial category state.
addon.db.lfg_filter_player_classes={DRUID=true}
addon.db.lfg_filter_player_roles={HEALER=true}
players[2]={{classFilename="DRUID",assignedRole="HEALER",level=42,lfgRoles={tank=false,healer=secret,dps=false}}}
local accepted,reason=matches(2,{})
check("secret advertised role waits with an explicit reason",accepted==false and reason~=nil)
players[2][1].lfgRoles.healer=true
check("readable advertised choice restores the player",matches(2,{})==true)
addon.db.lfg_filter_player_min_level=40
players[2][1].level=secret
accepted,reason=matches(2,{})
check("secret required level waits with a reason",accepted==false and reason~=nil)
check("player metadata restrictions never exclude unfiltered groups",matches(1,{})==true)
infos[2].hasSelf=true
check("own listing remains pinned independently of player criteria",matches(2,{})==true)
infos[2].hasSelf=false
addon.db.lfg_filter_player_roles={};addon.db.lfg_filter_player_classes={};addon.db.lfg_filter_player_min_level=0
addon.db.lfg_filter_group_roles={TANK=true}
counts[1]={TANK=0,HEALER=1,DAMAGER=4};infos[1].numMembers=5
check("full group cannot need another tank in count fallback",matches(1,{})==false)
infos[1].numMembers=4;counts[1]={TANK=0,HEALER=1,DAMAGER=3}
check("five-player count fallback recognizes a remaining tank slot",matches(1,{})==true)
check("empty player block restores players while group criteria stay active",matches(2,{})==true)
addon.db.lfg_filters_enabled=false
check("disabled filtering leaves both categories unchanged",matches(1,{}) and matches(2,{}))
addon.db.lfg_filters_enabled=true
addon.db.lfg_filter_group_roles={TANK=true,HEALER=true}
addon.db.lfg_filter_group_has_roles={DAMAGER=true}
addon.db.lfg_filter_player_classes={DRUID=true};addon.db.lfg_filter_player_roles={HEALER=true}
addon.db.lfg_filter_player_min_level=40;addon.db.lfg_filter_player_max_level=50
check("named preset saves every filter dimension",addon:LFGFilters_SavePreset("Level heal")==true)
local state=addon.db.lfg_filter_presets[1].filters
addon.db.lfg_filter_group_roles={};addon.db.lfg_filter_group_has_roles={}
addon.db.lfg_filter_player_classes={};addon.db.lfg_filter_player_roles={}
addon.db.lfg_filter_player_min_level=0;addon.db.lfg_filter_player_max_level=0
-- UI refresh is covered separately using the original client-source harness.
addon.LFGFilters_RebuildPanelContents=function() end
addon.LFGFilters_OnChanged=function() end
check("named preset restores all independent filter dimensions",addon:LFGFilters_ApplyState(state)==true
 and addon.db.lfg_filter_group_roles.TANK and addon.db.lfg_filter_group_roles.HEALER
 and addon.db.lfg_filter_group_has_roles.DAMAGER and addon.db.lfg_filter_player_classes.DRUID
 and addon.db.lfg_filter_player_roles.HEALER and addon.db.lfg_filter_player_min_level==40
 and addon.db.lfg_filter_player_max_level==50)
print(string.format("Forever filter contract %s: %d passed, %d failed",HARNESS_REVISION,pass,fail))
assert(fail==0,"Forever filter contract failed")
