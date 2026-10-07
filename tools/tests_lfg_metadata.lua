local addon = dofile("run.lua")
local pass, fail = 0, 0
local function check(name, ok, detail)
  if ok then pass = pass + 1; print_orig("  ✓ " .. name)
  else fail = fail + 1; print_orig("  ✗ " .. name .. (detail and (" -> " .. tostring(detail)) or "")) end
end

print_orig("\n--- Forever LFG metadata SafeAPI ---")
C_LFGList.GetSearchResultInfo = function(id)
  return { name="Test", numMembers=1, activityIDs={401}, generalPlaystyle=2, areaName="Westfall" }
end
C_LFGList.GetSearchResultPlayerInfo = function(id, index)
  return { name="Player-Realm", level=24, areaName="Westfall", classFilename="DRUID", assignedRole="HEALER" }
end
C_LFGList.GetActivityInfoTable = function(id)
  return { fullName="The Deadmines", categoryID=2, groupID=40, minLevelSuggestion=17, maxLevelSuggestion=26, maxNumPlayers=5, useDungeonRoleExpectations=true }
end
C_LFGList.GetSearchResults = function() return 3, { 101, 102, 103 } end
C_LFGList.GetAvailableCategories = function() return { 1, 2, 3 } end
C_LFGList.GetAvailableActivities = function(categoryID, groupID) return { 401, 402 } end
C_LFGList.GetLfgCategoryInfo = function(categoryID)
  return { name="Dungeons", separateRecommended=true, autoChooseActivity=false, showPlaystyleDropdown=true }
end
C_LFGList.GetActivityGroupInfo = function(groupID) return "Classic Dungeons" end
addon:LFG_API_ClearCaches()

local info = addon:LFG_API_GetSearchResultInfo(101)
check("search result exposes playstyle", info and info.generalPlaystyle == 2, info and info.generalPlaystyle)
check("search result exposes area", info and info.areaName == "Westfall", info and info.areaName)
local player = addon:LFG_API_GetSearchResultPlayerInfo(101, 1)
check("solo result exposes level", player and player.level == 24, player and player.level)
check("solo result exposes zone", player and player.areaName == "Westfall", player and player.areaName)
local activity = addon:LFG_API_GetActivityInfoTable(401)
check("activity exposes suggested level range", activity and activity.minLevelSuggestion == 17 and activity.maxLevelSuggestion == 26)
local results, total = addon:LFG_API_GetSearchResults()
check("search results sanitize result ids", total == 3 and #results == 3 and results[3] == 103, total)
C_LFGList.GetSearchResults = function() return { 201, 202 }, 2 end
local reversedResults, reversedTotal = addon:LFG_API_GetSearchResults()
check("search results wrapper tolerates results,total order", reversedTotal == 2 and #reversedResults == 2 and reversedResults[2] == 202, reversedTotal)
C_LFGList.GetSearchResults = function() return 3, { 101, 102, 103 } end
local categories = addon:LFG_API_GetAvailableCategories()
check("available categories wrapper works", #categories == 3 and categories[2] == 2)
local activities = addon:LFG_API_GetAvailableActivities(2, 40)
check("available activities wrapper works", #activities == 2 and activities[1] == 401)
local category = addon:LFG_API_GetCategoryInfo(2)
check("category metadata wrapper works", category and category.name == "Dungeons" and category.showPlaystyleDropdown == true)
check("activity group wrapper works", addon:LFG_API_GetActivityGroupInfo(40) == "Classic Dungeons")

print_orig("\n--- Client capability probes ---")
local clientChunk, err = loadfile("../Core/ClientSupport.lua")
assert(clientChunk, err)
clientChunk("GroupGuardLFG", addon)
GetBuildInfo = function() return "1.60.1", "70170", "Oct 2026", 16001 end
addon.Client = nil
local client = addon:RefreshClientCapabilities()
check("Forever client detected", client and client.isForever == true)
check("browse metadata capability detected", addon:HasClientCapability("lfgBrowseMetadata") == true)
check("activity group capability detected", addon:HasClientCapability("lfgActivityGroups") == true)

print_orig(string.format("\n=== LFG metadata: %d passed, %d failed ===", pass, fail))
os.exit(fail == 0 and 0 or 1)
