-- Operation counts under a synthetic event burst, not in-game FPS measurements.
local addon=dofile("run.lua")
addon:EnsureDB()
local source=arg and arg[1] or ".."
local queue={}
C_Timer={NewTimer=function(_,fn)
 local t={fn=fn}; function t:Cancel() self.cancelled=true end
 queue[#queue+1]=t; return t
end}
local function drain()
 local q=queue;queue={}
 for _,t in ipairs(q) do if not t.cancelled then t.fn() end end
end
local handler
CreateFrame=function() return {
 RegisterEvent=function() end,
 SetScript=function(_,key,fn) if key=="OnEvent" then handler=fn end end,
} end
assert(loadfile(source.."/Core/Performance.lua"))("GroupGuardLFG",addon)
assert(loadfile(source.."/Modules/EventBus.lua"))("GroupGuardLFG",addon)
addon.IsDisabledNow=function() return false end
addon.Safe.IsInGroup=function() return true end
addon.Safe.IsInRaid=function() return false end
local scans,rebuilds,forced=0,0,0
addon.CheckGroup=function() scans=scans+1; return false end
addon.ScanGroupOffenders=function() end
addon.ScheduleFrameMarkerUpdate=function() end
addon.ScheduleRaidAssist=function() end
addon.RequestLFGRefresh=function() end
addon.LFG_ClearApplicantCaches=function() end
addon.LFG_ClearSearchCaches=function() end
addon.InvalidateSocialCaches=function() end
addon.UpdateFrameMarkers=function() end
addon.PugWindow=nil
for _=1,100 do handler(nil,"GROUP_ROSTER_UPDATE") end
drain()
print_orig("100 roster events: "..scans.." group evaluations")
scans=0
for _=1,100 do handler(nil,"UNIT_NAME_UPDATE","nameplate1");handler(nil,"UNIT_CONNECTION","target") end
drain()
print_orig("200 unrelated unit events: "..scans.." group evaluations")
addon.RebuildCaches=function() rebuilds=rebuilds+1 end
addon.RebuildFriendCache=function(_,force) if force then forced=forced+1 end end
addon.RebuildGuildCache=addon.RebuildFriendCache
for _=1,100 do addon:SyncSettingsState("slider") end
drain()
print_orig("100 settings changes: "..rebuilds.." rule rebuilds, "..forced.." forced social rebuilds")
