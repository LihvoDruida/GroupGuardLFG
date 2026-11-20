-- Retail 12.x filter contract: GroupGuard role filters go through Blizzard's
-- native dungeon advanced filter and never touch LFGListFrame.SearchPanel data.
local pass, fail = 0, 0
local function check(name, ok, detail)
  if ok then pass = pass + 1; print("  ✓ " .. name)
  else fail = fail + 1; print("  ✗ " .. name .. (detail and (" -> " .. tostring(detail)) or "")) end
end

_G = _G or _ENV
UIParent = {}
GetTime = function() return 100 end
canaccessvalue = function() return true end

local saved = { needsTank = false, needsHealer = false, needsDamage = false, needsMyClass = false,
  hasTank = false, hasHealer = false, activities = { 7 }, minimumRating = 0,
  difficultyNormal = false, difficultyHeroic = false, difficultyMythic = false, difficultyMythicPlus = true }
local saves = 0
local function copy(t) local o = {}; for k, v in pairs(t) do o[k] = v end; return o end
C_LFGList = {
  GetAdvancedFilter = function() return copy(saved) end,
  SaveAdvancedFilter = function(t) saves = saves + 1; saved = copy(t) end,
  GetSearchResultInfo = function() return { numMembers = 3 } end,
}

-- A native search panel whose result data must never be rewritten.
local nativeResults = { 11, 12, 13 }
local updateCalls = 0
LFGListFrame = { SearchPanel = { results = nativeResults, totalResults = 3 } }
LFGListSearchPanel_UpdateResultList = function() updateCalls = updateCalls + 1 end
LFGListSearchPanel_UpdateResults = function() updateCalls = updateCalls + 1 end
local hooked = {}
hooksecurefunc = function(name) hooked[#hooked + 1] = name end

local addon = {
  db = {
    lfg_filters_enabled = true,
    lfg_filter_group_roles = { TANK = false, HEALER = false, DAMAGER = false },
    lfg_filter_group_has_roles = { TANK = false, HEALER = false, DAMAGER = false },
    lfg_filter_player_roles = { TANK = false, HEALER = false, DAMAGER = false },
    lfg_filter_player_classes = {},
    lfg_filter_player_min_level = 0,
    lfg_filter_player_max_level = 0,
    lfg_filter_social_priority = true,
    lfg_filter_presets = {},
  },
  Tr = function(_, key) return key end,
  HasClientCapability = function(_, name) return name ~= "lfgSearchMemberCounts" or true end,
  IsForeverClient = function() return false end,
}
assert(loadfile("../Core/SafeAPI.lua"))("GroupGuardLFG", addon)
assert(loadfile("../Modules/LFGFilters.lua"))("GroupGuardLFG", addon)
addon.GetLFGSearchFrame = function() return LFGListFrame.SearchPanel end

print("\n--- Retail filters: native advanced filter ---")
check("retail uses the native advanced filter", addon:LFGFilters_UsesNativeAdvancedFilter())

-- Run the real frame hookup with UI construction stubbed out.
addon.LFGFilters_CreateButton = function() end
addon.LFGFilters_CreatePanel = function() end
addon.LFGFilters_LayoutPanel = function() end
saved.needsDamage = false
addon.db.lfg_filter_group_roles.DAMAGER = true
addon:LFGFilters_HookFrames()
check("frame hookup installs no hook on the native result list", #hooked == 0, table.concat(hooked, ","))
check("frame hookup reconciles the saved selection into the native filter", saved.needsDamage == true)
addon.db.lfg_filter_group_roles.DAMAGER = false
addon:LFGFilters_SyncAdvancedFilter()

addon.db.lfg_filter_group_roles.TANK = true
addon.db.lfg_filter_group_has_roles.HEALER = true
addon:LFGFilters_OnChanged()
check("needs tank and has healer reach the native filter", saved.needsTank == true and saved.hasHealer == true)
check("unrelated native filter settings are preserved", saved.difficultyMythicPlus == true and saved.activities[1] == 7)
check("native result data is never rewritten", LFGListFrame.SearchPanel.results == nativeResults and LFGListFrame.SearchPanel.totalResults == 3)
check("addon code never rebuilds the native result list", updateCalls == 0, updateCalls)

addon:LFGFilters_FilterFrameResults(LFGListFrame.SearchPanel)
check("legacy filter entry point is a no-op on retail", LFGListFrame.SearchPanel.results == nativeResults and updateCalls == 0)

-- The player set "needs healer" themselves in Blizzard's Filter menu.
saved.needsHealer = true
addon.db.lfg_filter_group_roles.TANK = false
addon:LFGFilters_OnChanged()
check("unchecking clears only the flag GroupGuard set", saved.needsTank == false and saved.needsHealer == true)

local before = saves
addon:LFGFilters_OnChanged()
check("no redundant native save when nothing changed", saves == before)

addon.db.lfg_filter_group_has_roles.DAMAGER = true
check("unsupported 'has damage' does not count as an active filter", select(1, addon:LFGFilters_GetActiveBlocks()) == true and saved.hasDamage == nil)
addon.db.lfg_filter_group_has_roles = { TANK = false, HEALER = false, DAMAGER = true }
addon.db.lfg_filter_player_classes = { MAGE = true }
check("player and has-damage filters alone are inactive on retail", addon:LFGFilters_HasActiveFilters() == false)

addon.db.lfg_filter_group_has_roles.HEALER = true
addon:LFGFilters_OnChanged()
addon.db.lfg_filters_enabled = false
addon:LFGFilters_SyncAdvancedFilter()
check("disabling filters releases GroupGuard's native flags", saved.hasHealer == false and saved.needsHealer == true)

C_LFGList.GetAdvancedFilter = function() error("unavailable") end
addon.db.lfg_filters_enabled = true
check("failing native filter API is handled", addon:LFGFilters_SyncAdvancedFilter() == false)

print(string.format("Retail filters: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
