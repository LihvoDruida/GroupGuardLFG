local addon = dofile("run.lua")
addon:EnsureDB()
addon.db.flag_rules = "wts,boost,carry,gdkp,rmt,продам,бустер,золото"
addon.db.language_detect_enabled = true
addon.db.language_detect_keywords = true
addon.db.language_detect_scripts = true
addon.db.language_detect_rules = "eng only,rus only,тільки укр"
for _, d in ipairs(addon.LANGUAGE_SCRIPT_DETECTORS) do addon.db[d.key] = true end
addon:RebuildCaches()

local samples = {}
for i = 1, 200 do samples[i] = "M+ 12 key need tank and healer, link achi, run " .. i end
samples[50] = "WTS boost gdkp run"

local function pass() for i = 1, #samples do addon:GetFlagReason(samples[i]) end end

-- сценарій: гравець бігає світом, ZONE_CHANGED_NEW_AREA фіксується часто,
-- а список груп перемальовується між зонами
addon:ClearRuleMemo(); addon._ruleSignature = nil
addon:RebuildCaches(); pass()
local t0 = os.clock()
for _ = 1, 300 do
  addon:RebuildCaches()   -- зміна зони
  pass()                  -- перемальовка списку
end
local zoning = os.clock() - t0
print_orig(string.format("300 змін зони + перемальовок: %.0f мс (%.2f мс на подію)", zoning*1000, zoning/300*1000))

-- контроль: memo справді переживає зміну зони
addon:RebuildCaches()
local memoAlive = next(addon._ruleMemo) ~= nil
print_orig("memo переживає зміну зони: " .. tostring(memoAlive))

-- контроль: зміна налаштувань memo таки скидає
addon.db.flag_rules = addon.db.flag_rules .. ",newrule"
addon:RebuildCaches()
print_orig("memo скинуто при зміні правил: " .. tostring(next(addon._ruleMemo) == nil))
addon:RebuildCaches(); pass()
addon.db.language_script_cjk = false
addon:RebuildCaches()
print_orig("memo скинуто при вимкненні детектора CJK: " .. tostring(next(addon._ruleMemo) == nil))
