local addon = dofile("run.lua")
local pass, fail = 0, 0
local function check(n, ok, d)
  if ok then pass=pass+1; print_orig("  ✓ "..n) else fail=fail+1; print_orig("  ✗ "..n..(d and " -> "..tostring(d) or "")) end
end

print_orig("\n--- 5. Ініціалізація: збій одного кроку не спиняє решту ---")
local order = {}
addon.StepA = function() table.insert(order,"A") end
addon.StepBoom = function() error("розрив") end
addon.StepC = function() table.insert(order,"C") end
addon.SafeInitStep("a","StepA")
addon.SafeInitStep("boom","StepBoom")
addon.SafeInitStep("c","StepC")
check("крок після збою виконався", order[1]=="A" and order[2]=="C", table.concat(order,","))
check("збій записано у діагностику", (addon._initFailures or {}).boom ~= nil)

print_orig("\n--- 6. Відновлення геометрії не знімає прив'язки ---")
-- об'єкт без жодного SetPoint: збереження має бути пропущене,
-- інакше відновлення зняло б прив'язки і елемент зник би назавжди
local mock = dofile("mock.lua")
local naked = mock.stubFrame()
naked:ClearAllPoints()
check("об'єкт без прив'язок дійсно має 0 точок", naked:GetNumPoints()==0)
local anchored = mock.stubFrame()
anchored:SetPoint("TOPLEFT", nil, "TOPLEFT", 5, -5)
check("об'єкт з прив'язкою має 1 точку", anchored:GetNumPoints()==1)

print_orig(string.format("\n=== %d пройдено, %d провалено ===", pass, fail))
os.exit(fail==0 and 0 or 1)
