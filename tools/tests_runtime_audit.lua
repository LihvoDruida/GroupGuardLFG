-- Stateful regressions: real addon modules, deterministic timer/event driver.
local addon = dofile("run.lua")
addon:EnsureDB()
local passed, failed = 0, 0
local function check(name, condition)
  if condition then passed=passed+1; print_orig("  PASS "..name)
  else failed=failed+1; print_orig("  FAIL "..name) end
end
local now, timers, frames = 100, {}, {}
GetTime = function() return now end
C_Timer = { After = function(delay, fn) timers[#timers+1]={at=now+delay,fn=fn} end }
local function advance(dt)
  now=now+dt
  local queue=timers; timers={}
  for _,t in ipairs(queue) do if t.at<=now then t.fn() else timers[#timers+1]=t end end
end
local stub = dofile("mock.lua").stubFrame
CreateFrame = function(_,name)
  local f=stub(name); f.scripts={}; f.hooks={}; f.events={}
  function f:SetScript(k,fn) self.scripts[k]=fn end
  function f:HookScript(k,fn) self.hooks[k]=fn end
  function f:RegisterEvent(k) self.events[k]=true end
  function f:UnregisterEvent(k) self.events[k]=nil end
  frames[#frames+1]=f; return f
end
-- EventBus captures C_Timer at load time.
assert(loadfile("../Modules/EventBus.lua"))("GroupGuardLFG",addon)
local eventFrame=frames[#frames]
local function event(name,arg) eventFrame.scripts.OnEvent(eventFrame,name,arg) end
addon.IsDisabledNow=function() return false end
IsInGroup=function() return true end
IsInRaid=function() return false end
local scans=0
addon.CheckGroup=function() scans=scans+1; return false end
addon.ScanGroupOffenders=function() end
addon.ScheduleFrameMarkerUpdate=function() end
addon.ScheduleRaidAssist=function() end
addon.RequestLFGRefresh=function() end
addon.LFG_ClearApplicantCaches=function() end
addon.LFG_ClearSearchCaches=function() end
addon.PugWindow=nil
for _=1,100 do event("GROUP_ROSTER_UPDATE") end
check("100 roster events do not scan synchronously", scans==0)
advance(0.1)
check("100 roster events coalesce into one group evaluation",scans==1)
for _=1,100 do event("UNIT_NAME_UPDATE","nameplate1"); event("UNIT_CONNECTION","target") end
advance(0.1)
check("200 unrelated unit events cause no group evaluation",scans==1)
for _=1,100 do event("UNIT_NAME_UPDATE","party1") end
advance(0.1)
check("party unit updates still refresh once",scans==2)
local refreshApplicants, refreshResults, doneID
addon.RequestLFGRefresh=function(_,_,a,r) refreshApplicants=a;refreshResults=r end
addon.LFG_RefreshApplicantsAfterDone=function(_,id) doneID=id end
event("LFG_LIST_APPLICATION_STATUS_UPDATED",77)
check("outgoing application status refreshes search, not applicants",refreshApplicants==false and refreshResults==true and doneID==nil)
event("LFG_LIST_APPLICANT_UPDATED",88)
check("incoming applicant status still refreshes applicants",refreshApplicants==true and doneID==88)

local count, argCount, last = 0, 0
addon:RunDebounced("cancel_after",0.1,function() count=count+1 end)
addon:CancelDebounce("cancel_after")
addon:RunDebounced("cancel_after",0.1,function() count=count+10 end)
advance(0.2)
check("After fallback invalidates cancelled timer without removing its replacement",count==10)
addon:RunSafeAsync("nil_args",function(...) argCount=select("#",...); last=select(3,...) end,1,nil,3,nil)
check("async callbacks preserve interior and trailing nil arguments",argCount==4 and last==3)
local rebuilds,forced=0,0
addon.RebuildCaches=function() rebuilds=rebuilds+1 end
addon.RebuildFriendCache=function(_,force) if force then forced=forced+1 end end
addon.RebuildGuildCache=addon.RebuildFriendCache
for _=1,100 do addon:SyncSettingsState("slider") end
check("settings burst defers expensive rebuild",rebuilds==0)
advance(0.1)
check("100 settings changes rebuild rules once",rebuilds==1)
check("settings reuse social caches",forced==0)

-- Real roster scan: a full party has no party5, and resolved names stop retrying.
assert(loadfile("../Core/GroupScan.lua"))("GroupGuardLFG",addon)
addon.GetGroupMemberCount=function() return 5 end
addon.ShouldIgnoreFilteredUnit=function() return false end
addon.IsExemptUnit=function() return false end
addon.IsFlaggedText=function() return false end
addon.Safe.GuildName=function() return nil end
local units={}
addon.Safe.UnitFullName=function(unit) units[#units+1]=unit; return "Member","Member",nil end
addon.db.show_in_party=true
addon._needsRecheck=true
addon:CheckGroup()
check("full party scans exactly party1 through party4",#units==4 and units[4]=="party4")
check("resolved roster clears pending recheck flag",addon._needsRecheck==false)
units={};addon.GetGroupMemberCount=function() return 2 end
addon:CheckGroup()
check("two-player party scans one teammate without a phantom unit",#units==1 and units[1]=="party1" and not addon._needsRecheck)
addon.Safe.UnitFullName=function() return nil end
addon:CheckGroup()
check("missing roster identity still requests a retry",addon._needsRecheck==true)

check("NaN rejected before cache indexing",addon:SafeNumber(0/0,7)==7)
check("infinity rejected before indexing",addon:SafeNumber(math.huge,7)==7)
local secret={}
issecretvalue=function(v) return v==secret end
check("secret table cannot pass table accessibility guard",addon:SafeCanAccessTable(secret)==false)
InCombatLockdown=function() return secret end
check("secret combat state fails closed",addon.Safe.InCombatLockdown()==true)
InCombatLockdown=function() error("combat unavailable") end
check("failed combat API fails closed",addon.Safe.InCombatLockdown()==true)
issecretvalue=nil
InCombatLockdown=function() return false end
local modern,legacy=0,0
C_PartyInfo={PromoteToAssistant=function() modern=modern+1 end}
local oldPromote=function() legacy=legacy+1 end
addon.Safe.PartyCall("PromoteToAssistant",oldPromote,"Name",true)
check("party API prefers namespace",modern==1 and legacy==0)
C_PartyInfo.PromoteToAssistant=function() error("protected call blocked") end
local partyOK=addon.Safe.PartyCall("PromoteToAssistant",oldPromote,"Name",true)
check("blocked party action never retries through legacy API",partyOK==false and legacy==0)
C_PartyInfo={}
addon.Safe.PartyCall("PromoteToAssistant",oldPromote,"Name",true)
check("missing modern party API uses legacy fallback",legacy==1)
InCombatLockdown=function() return true end
partyOK=addon.Safe.PartyCall("PromoteToAssistant",oldPromote,"Name",true)
check("party dispatcher blocks actions during combat",partyOK==false and legacy==1)
InCombatLockdown=function() return false end
addon:LFG_API_ClearCaches()
C_LFGList.GetSearchResultInfo=function(id) return { name="Group"..id, numMembers=1 } end
for id=1,2000 do addon:LFG_API_GetSearchResultInfo(id) end
local stats=addon:LFG_API_DebugDump()
check("LFG caches remain bounded after 2000 unique results",stats.entries<=512 and stats.entries>0)
C_LFGList.GetSearchResultPlayerInfo=function(id,index) return { name=id.."/"..index } end
local first=addon:LFG_API_GetSearchResultPlayerInfo(1,65)
local second=addon:LFG_API_GetSearchResultPlayerInfo(2,1)
check("member cache keys cannot collide across results",first~=second)
addon:LFG_ForgetSearchResult(1)
local cache=addon._lfgAPICache.searchPlayer
check("targeted invalidation clears string member keys",cache.values["1:65"]==nil and cache.values["2:1"]~=nil)

-- Client flavor is distinct from optional API capabilities.
local function client(iface,version,project)
 GetBuildInfo=function() return version,"test","test",iface end
 WOW_PROJECT_ID=project; return addon:RefreshClientCapabilities()
end
WOW_PROJECT_MAINLINE=1; WOW_PROJECT_CLASSIC=2
check("Retail 12 recognized",client(120105,"12.1.5",1).flavor=="retail")
check("Forever overrides vanilla project identity",client(16001,"1.60.1",2).flavor=="forever")
check("Classic Era recognized without seasonal API",client(11508,"1.15.8",2).flavor=="classic")
Enum={SeasonID={SeasonOfDiscovery=9}}
C_Seasons={GetActiveSeason=function() return 9 end}
check("SoD uses active season enum",client(11508,"1.15.8",2).flavor=="sod")
C_Seasons.GetActiveSeason=function() return 10 end
check("other seasons are not mislabeled SoD",client(11508,"1.15.8",2).isSeasonOfDiscovery==false)
C_Seasons=nil
client(16001,"1.60.1",2)
local originalWho={}
LFGWhoListFrame=originalWho
assert(loadfile("../Core/ForeverLoadGuard.lua"))("GroupGuardLFG",addon)
addon:ForeverLoadGuard_RebindWhoListFrame()
check("Forever guard never replaces Blizzard global",LFGWhoListFrame==originalWho)
check("Forever guard reports passive mode",addon:ForeverLoadGuard_GetStatus().passive==true)

-- Combat notifications use one deferred payload; stale fade callbacks cannot
-- hide a notification that was shown later.
assert(loadfile("../Core/Alerts.lua"))("GroupGuardLFG",addon)
addon.Banner=stub(); addon.Flash=stub()
addon.Banner.timer=nil
addon.ShouldSuppressAlerts=function() return false end
addon.GetFontForText=function() return "font" end
addon.UpdateBannerGroupButtons=function() end
addon.LayoutBannerActionButtons=function() end
addon.db.show_banner=true
addon.Banner:Hide()
local combat=true
InCombatLockdown=function() return combat end
addon:ShowBanner("old","",false,"TEST","")
addon:ShowBanner("latest","",false,"TEST","")
check("combat defers toast without displaying it",not addon.Banner:IsShown())
check("combat queue retains only latest payload",addon._deferredBanner.primary=="latest")
combat=false; addon:FlushDeferredBanner()
check("combat end shows deferred notification",addon.Banner:IsShown() and addon._deferredBanner==nil)
combat=true; addon:SuspendBannerForCombat()
check("entering combat hides existing toast",not addon.Banner:IsShown())
addon:ClearAlert(); combat=false; addon:FlushDeferredBanner()
check("clear discards deferred toast",not addon.Banner:IsShown())
-- Exercise the fade timer race with a real deterministic NewTimer handle.
C_Timer.NewTimer=function(delay,fn)
 local timer={cancelled=false};function timer:Cancel() self.cancelled=true end
 C_Timer.After(delay,function() if not timer.cancelled then fn() end end)
 return timer
end
UIFrameFadeOut=function() end
addon.db.banner_hold_time=0.05
addon:ShowBanner("first","",false,"TEST","")
advance(0.06) -- first fade queued its finishHide callback
addon:ShowBanner("replacement","",false,"TEST","")
advance(0.19) -- old finishHide must not hide the replacement
check("stale fade completion cannot hide replacement toast",addon.Banner:IsShown())
-- Modern social APIs are exclusive with legacy enumeration.
assert(loadfile("../Core/Social.lua"))("GroupGuardLFG",addon)
local friendCalls,oldFriendCalls=0,0
C_SocialRestrictions={IsFriendsDisabled=function() return false end}
C_FriendList={
 IsLegacyFriendSystemEnabled=function() return true end,
 GetNumFriends=function() friendCalls=friendCalls+1;return 1 end,
 GetFriendInfoByIndex=function() return {name="Friend"} end,
}
GetNumFriends=function() oldFriendCalls=oldFriendCalls+1;return 1 end
GetFriendInfo=function() return "Friend" end
C_BattleNet=nil
addon:RebuildFriendCache(true)
check("modern friends do not duplicate legacy enumeration",friendCalls==1 and oldFriendCalls==0)
C_FriendList.IsLegacyFriendSystemEnabled=function() return false end
addon:RebuildFriendCache(true)
check("disabled legacy friend list is not enumerated",friendCalls==1 and oldFriendCalls==0)
local guildCalls,oldGuildCalls=0,0
C_GuildInfo={GuildRoster=function() guildCalls=guildCalls+1 end}
GuildRoster=function() oldGuildCalls=oldGuildCalls+1 end
addon._lastGuildRosterRequest=nil
for _=1,20 do addon.Safe.RequestGuildRoster() end
check("guild roster request prefers namespace and throttles bursts",guildCalls==1 and oldGuildCalls==0)
now=now+11;C_GuildInfo=nil;addon.Safe.RequestGuildRoster()
check("guild roster legacy fallback remains available",oldGuildCalls==1)
local scale
UIParent:SetSize(640,360)
local window={SetScale=function(_,s) scale=s end}
addon:FitWindowToScreen(window,720,580)
check("fallback settings fit small viewport",scale<1 and scale*580<=328)
print_orig(string.format("Runtime audit: %d passed, %d failed",passed,failed))
os.exit(failed==0 and 0 or 1)
