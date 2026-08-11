local mock = dofile("mock.lua")
local stubFrame = mock.stubFrame

-- globals the addon touches at load time
CreateFrame = function() return stubFrame() end
UIParent = stubFrame()
GetTime = function() return os.clock() end
GetLocale = function() return "ukUA" end
hooksecurefunc = function(a,b,c) end
C_Timer = { After = function(_, fn) end, NewTicker = function() return { Cancel = function() end } end }
IsInRaid = function() return false end
IsInGroup = function() return false end
UnitName = function() return "Тест", nil end
GetRealmName = function() return "TestRealm" end
GetBuildInfo = function() return "12.1.0", "69111", "date", 120100 end
GetInstanceInfo = function() return "none", "none" end
IsInInstance = function() return false, "none" end
UnitAffectingCombat = function() return false end
GetNumGroupMembers = function() return 0 end
C_AddOns = { GetAddOnMetadata = function(_, f)
  local t = { Version = "4.5.0", ["X-Codename"] = "test", Title = "GroupGuard LFG", Author = "a" }
  return t[f] end }
SOUNDKIT = { RAID_WARNING = 1 }
NAME, ROLE, ITEM_LEVEL_ABBR, RATING = "Name", "Role", "iLvl", "Rating"
Settings = nil  -- force fallback panel path
LFGListFrame = nil
C_LFGList = {}
print_orig = print
SlashCmdList = {}
StaticPopupDialogs = {}
StaticPopup_Show = function() end
UnitIsGroupLeader = function() return false end
UnitIsGroupAssistant = function() return false end
UnitIsRaidOfficer = function() return false end
UnitGroupRolesAssigned = function() return "NONE" end
UnitExists = function() return false end
UnitClass = function() return "Маг", "MAGE" end
GetGuildInfo = function() return nil end
UnitIsInMyGuild = function() return false end
RAID_CLASS_COLORS = {}
NORMAL_FONT_COLOR = { r=1,g=1,b=1 }


local addonTable = {}
local files = {
  "Core/Bootstrap.lua","Core/SafeAPI.lua","Core/Performance.lua","Core/Rules.lua",
  "Core/Alerts.lua","Core/Social.lua","Core/GroupScan.lua","Data/RealmLocaleData.lua",
  "UI/Notify.lua","Modules/FrameMarkers.lua","Modules/LFG.lua","Modules/LFGEnhancements.lua",
  "Modules/RealmInsights.lua","Modules/LFGAdvisor.lua","Modules/ApplicantEnhancements.lua",
  "Modules/GroupActions.lua","Modules/RaidAssist.lua","Modules/PugDetector.lua",
  "Modules/RaidManagerButtons.lua","Modules/EventBus.lua","UI/Settings.lua",
}
for _, f in ipairs(files) do
  local chunk, err = loadfile("../" .. f)
  if not chunk then print_orig("LOAD ERROR " .. f .. ": " .. tostring(err)); os.exit(1) end
  local ok, e = pcall(chunk, "GroupGuardLFG", addonTable)
  if not ok then print_orig("RUNTIME ERROR " .. f .. ": " .. tostring(e)); os.exit(1) end
end
print_orig("✓ всі 21 файл завантажилися без помилок")
return addonTable
