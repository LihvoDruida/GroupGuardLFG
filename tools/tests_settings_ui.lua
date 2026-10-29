local addon=dofile("run.lua")
addon:EnsureDB()
local stub=dofile("mock.lua").stubFrame
local frames,pages={},{}
local passed,failed=0,0
local function check(name,condition)
 if condition then passed=passed+1;print_orig("  PASS "..name)
 else failed=failed+1;print_orig("  FAIL "..name) end
end
CreateFrame=function(kind,name,parent)
 local f=stub();f.scripts={};f.hooks={};f.name=name;f.parent=parent;f.kind=kind
 function f:GetName() return name end
 function f:SetScript(k,fn) self.scripts[k]=fn end
 function f:HookScript(k,fn) self.hooks[k]=fn end
 function f:SetScale(v) self.scale=v end
 function f:SetScrollChild(v) self.child=v end
 function f:SetText(v) self.text=v end
 function f:GetText() return self.text or "" end
 function f:SetNumber(v) self.text=tostring(v) end
 function f:GetChecked() return self.checked end
 function f:SetChecked(v) self.checked=v end
 function f:SetValue(v) self.value=v;if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end end
 function f:GetFontString() return stub() end
 if name then _G[name]=f end
 frames[#frames+1]=f; return f
end
UIDropDownMenu_SetWidth=function() end
UIDropDownMenu_SetText=function() end
UIDropDownMenu_Initialize=function() end
Settings={
 RegisterCanvasLayoutCategory=function() return {GetID=function() return 1 end} end,
 RegisterAddOnCategory=function() end,
 RegisterCanvasLayoutSubcategory=function(_,page) pages[#pages+1]=page;return {} end,
}
local syncs=0
addon.SyncSettingsState=function() syncs=syncs+1 end
addon:InitSettingsPages()
check("supported settings pages construct without syncing configuration",#pages>=5 and syncs==0)
local scroll=GroupGuardLFGConfigGeneralScroll
scroll:SetWidth(300)
scroll.hooks.OnSizeChanged(scroll)
check("narrow settings canvas scales owned content to fit",scroll.child.scale==0.5)
scroll:SetWidth(900)
scroll.hooks.OnSizeChanged(scroll)
check("wide canvas retains normal text scale",scroll.child.scale==1)
local clicked
for _,f in ipairs(frames) do
 if f.kind=="CheckButton" and f.scripts.OnClick then clicked=f;break end
end
clicked.checked=true;clicked.scripts.OnClick(clicked)
check("settings checkbox persists and requests synchronization",syncs==1)
-- Preserve Blizzard queue animation scripts: post-hooks may stop our optional glow.
local original=function() end
local anim={scripts={OnPlay=original},hooks={}}
function anim:HookScript(k,fn) self.hooks[k]=fn end
function anim:Stop() self.stopped=true end
QueueStatusButton={EyeHighlightAnim=anim}
addon.SupportsLFGApplicantSettings=function() return true end
addon._ggApplicantPingHooked=nil
addon.LFG_ShouldMuteApplicantPing=function() return true end
addon:LFG_SetupApplicantPingMute()
anim.hooks.OnPlay()
check("applicant glow keeps Blizzard script intact",anim.scripts.OnPlay==original)
check("optional muted glow is stopped by post-hook",anim.stopped==true)
print_orig(string.format("Settings UI: %d passed, %d failed",passed,failed))
os.exit(failed==0 and 0 or 1)
