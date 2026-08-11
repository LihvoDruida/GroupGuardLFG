local addon = dofile("run.lua")
local pass, fail = 0, 0
local function check(name, ok, detail)
  if ok then pass = pass + 1; print_orig("  ✓ " .. name)
  else fail = fail + 1; print_orig("  ✗ " .. name .. (detail and (" -> " .. tostring(detail)) or "")) end
end

print_orig("\n--- 1. Негативне кешування (дані не з'являються) ---")
addon.db = addon.db or {}
local calls = 0
C_LFGList.GetActivityInfoTable = function(id) calls = calls + 1; return nil end
addon:LFG_API_GetActivityInfoTable(123)
local firstCalls = calls
-- previously this stayed cached as nil for 120 seconds
local expiry = addon._lfgAPICache.activityInfo.expires[123] - GetTime()
check("miss for activityInfo кешується коротко, а не 120с", expiry <= 0.30, string.format("%.2fs", expiry))

C_LFGList.GetActivityInfoTable = function(id) calls = calls + 1; return { fullName = "Dungeon" } end
addon:LFG_API_ClearCaches("activity")
local info = addon:LFG_API_GetActivityInfoTable(123)
check("після появи даних вони читаються", info ~= nil and info.fullName == "Dungeon")
local exp2 = addon._lfgAPICache.activityInfo.expires[123] - GetTime()
check("реальні дані кешуються надовго", exp2 > 100, string.format("%.0fs", exp2))

print_orig("\n--- 2. Помилка в хуку не має виходити назовні ---")
local reached = false
local cb = addon:WrapHookCallback(function() error("boom") end, "test")
local ok = pcall(function() cb(); reached = true end)
check("виклик пережив помилку всередині хука", ok and reached)
check("збій зафіксовано для діагностики", (addon._hookFailures or {}).test == 1)

print_orig("\n--- 3. Заявка без даних не кешується як 'чиста' ---")
addon._lfgFlagCache, addon._lfgFlagReasons = {}, {}
C_LFGList.GetApplicantInfo = function() return nil end
addon:LFG_API_ClearCaches("applicants")
local flagged = addon:EvaluateApplicantFlag(77)
check("вердикт не виставлено", flagged == false)
check("порожній результат НЕ потрапив у кеш", addon._lfgFlagCache[77] == nil)

print_orig("\n--- 4. Секретні значення 12.1 не валять код ---")
local SECRET = setmetatable({}, { __tostring = function() error("secret!") end })
issecretvalue = function(v) return v == SECRET end
canaccessvalue = function(v) return v ~= SECRET end
UnitIsGroupLeader = function() return SECRET end
UnitGroupRolesAssigned = function() return SECRET end
UnitClass = function() return SECRET, SECRET end
local ok1, r1 = pcall(function() return addon.Safe.IsGroupLeader("raid1") end)
check("IsGroupLeader на secret -> false без помилки", ok1 and r1 == false, r1)
local ok2, r2 = pcall(function() return addon.Safe.GroupRole("raid1") end)
check("GroupRole на secret -> nil без помилки", ok2 and r2 == nil, r2)
local ok3 = pcall(function() return addon:PlayerCanManageGroup() end)
check("PlayerCanManageGroup переживає secret", ok3)
local ok4, needs = pcall(function() return addon.Safe.UnitClass("raid1") end)
check("UnitClass на secret -> nil без помилки", ok4 and needs == nil, needs)

print_orig(string.format("\n=== %d пройдено, %d провалено ===", pass, fail))
os.exit(fail == 0 and 0 or 1)
