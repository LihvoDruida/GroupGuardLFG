-- Offline integration with ORIGINAL Blizzard Lua sources, not tools/mock.lua
-- or the historical regression suites. Only C widget/game bindings below are
-- simulated. This cannot reproduce WoW's renderer, security engine or server.
local observations = {}
local function observe(name, condition)
  assert(condition, "CLIENT SOURCE PROBE FAILED: " .. name)
  observations[#observations + 1] = name
  print("SOURCE OK: " .. name)
end
unpack = unpack or table.unpack
function Mixin(object, ...)
  for i=1,select("#",...) do for k,v in pairs(select(i,...)) do object[k]=v end end
  return object
end
function CreateFromMixins(...) return Mixin({}, ...) end
function CreateCounter() local n=0; return function() n=n+1; return n end end
function securecallfunction(fn,...) return fn(...) end
function secureexecuterange(t,fn,...) for k,v in pairs(t) do fn(k,v,...) end end
function issecure() return true end
function AddSourceLocationExclude() end
function table.wipe(t) for k in pairs(t) do t[k]=nil end; return t end
wipe=table.wipe
function table.contains(t,value) for _,v in pairs(t) do if v==value then return true end end; return false end
function table.indexof(t,value) for i,v in ipairs(t) do if v==value then return i end end end
function table.removevalue(t,value) local i=table.indexof(t,value); if i then table.remove(t,i) end end
function table.invert(t) local out={}; for k,v in pairs(t) do out[v]=k end; return out end
tinsert=table.insert
local frames, timers={},{}
local combat=false
function InCombatLockdown() return combat end
function GetTime() return 100 end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
local function flush()
  for _=1,10 do
    if #timers==0 then return end
    local batch=timers; timers={}
    for _,fn in ipairs(batch) do fn() end
  end
  error("timer loop")
end
local methods={}
function methods:SetScript(name,fn) self.scripts[name]=fn end
function methods:HookScript(name,fn) self.hooks[name]=self.hooks[name] or {}; table.insert(self.hooks[name],fn) end
local function fire(f,event,...)
  if f.scripts[event] then f.scripts[event](f,...) end
  for _,fn in ipairs(f.hooks[event] or {}) do fn(f,...) end
end
function methods:Show() if self.protected and combat then error("protected Show") end; if not self.shown then self.shown=true; fire(self,"OnShow") end end
function methods:Hide() if self.protected and combat then error("protected Hide") end; if self.shown then self.shown=false; fire(self,"OnHide") end end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:IsProtected() return self.protected==true end
function methods:SetForbidden() self.forbidden=true end
function methods:SetAttribute(k,v) self.attributes[k]=v; fire(self,"OnAttributeChanged",k,v) end
function methods:GetAttribute(k) return self.attributes[k] end
function methods:RegisterEvent(k) self.events[k]=true end
function methods:SetPoint(...) self.points[#self.points+1]={...} end
function methods:ClearAllPoints() self.points={} end
function methods:SetAllPoints() end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() assert(not self.font,"text width queried"); return self.width or 420 end
function methods:GetHeight() return self.height or 300 end
function methods:SetFrameStrata(v) self.strata=v end
function methods:GetFrameStrata() return self.strata or "MEDIUM" end
function methods:SetFrameLevel(v) self.level=v end
function methods:GetFrameLevel() return self.level or 10 end
function methods:SetText(v) self.text=v end
function methods:SetTextColor(...) self.textColor={...} end
function methods:SetEnabled(v) self.enabled=v end
function methods:SetColorTexture(...) self.color={...} end
function methods:SetAtlas(v) self.atlas=v end
function methods:SetScrollChild(v) self.content=v end
function methods:GetVerticalScroll() return self.offset or 0 end
function methods:SetVerticalScroll(v) self.offset=v end
function methods:GetVerticalScrollRange() return math.max(0,(self.content and self.content:GetHeight() or 0)-self:GetHeight()) end
function methods:GetParent() return self.parent end
for _,name in ipairs({"EnableMouse","SetMouseClickEnabled","SetMouseMotionEnabled","SetPropagateMouseClicks","SetPropagateMouseMotion","EnableMouseWheel","SetFixedFrameLevel","SetFixedFrameStrata","SetAlpha","SetJustifyH","SetWordWrap","RegisterForClicks","UpdateScrollChildRect"}) do
  methods[name]=function() end
end
function CreateFrame(kind,name,parent,template)
  local f=setmetatable({kind=kind,parent=parent,shown=true,scripts={},hooks={},events={},attributes={},points={}}, {__index=methods})
  frames[#frames+1]=f
  if template=="UIPanelScrollFrameTemplate" then f.ScrollBar=CreateFrame("Slider",nil,f) end
  if name then _G[name]=f end
  return f
end
function methods:CreateTexture() return CreateFrame("Texture",nil,self) end
function methods:CreateFontString() local f=CreateFrame("FontString",nil,self); f.font=true; return f end
UIParent=CreateFrame("Frame"); UIParent:SetSize(1280,720)
local secret={}
function issecretvalue(v) return v==secret end
function canaccessvalue(v) return v~=secret end
function import() return {VoiceModeLabels={}} end
Enum={LFGListDisplayType={Comment=1,RoleCount=2,PlayerCount=3,RoleEnumerate=4,ClassEnumerate=5,HideAll=6}}
CLASS_SORT_ORDER={"DRUID","MAGE"}
GRAY_FONT_COLOR={}; BRIGHTBLUE_FONT_COLOR={}; LIGHTGREEN_FONT_COLOR={}
LFG_LIST_CATEGORY_GROUPS="Groups"; LFG_LIST_CATEGORY_SOLO_PLAYERS="Players"
LFG_LIST_NO_RESULTS_FOUND="No results"; GROUP_INVITE="Invite"; SEND_MESSAGE="Message"
RAID_CLASS_COLORS={}; ScrollBoxConstants={RetainScrollPosition=true}
LFGVANILLA_SETTING_BROWSE_SHOW_COLLAPSIBLE_CATEGORIES=true
function IsInGroup() return false end
function UnitIsGroupLeader() return false end
function UnitIsGroupAssistant() return false end
function GetGroupMemberCounts() return {TANK=0,HEALER=1,DAMAGER=0} end
C_LFGListRoles={GetRoles=function() return {healer=true} end}
local ids={101,102,103,104}
local info={
  [101]={leaderName="Healer",numMembers=1,hasSelf=false,isDelisted=false,age=10,activityIDs={799}},
  [102]={leaderName="Needs tank",numMembers=4,hasSelf=false,isDelisted=false,age=20,activityIDs={799}},
  [103]={leaderName="Mage",numMembers=1,hasSelf=false,isDelisted=false,age=30,activityIDs={799}},
  [104]={leaderName="Has tank",numMembers=4,hasSelf=false,isDelisted=false,age=40,activityIDs={799}},
}
C_LFGList={
  GetFilteredSearchResults=function() local out={}; for i,id in ipairs(ids) do out[i]=id end; return #out,out end,
  GetSearchResultInfo=function(id) local src=info[id]; if not src then return nil end; local out={}; for k,v in pairs(src) do out[k]=v end; return out end,
  GetSearchResultPlayerInfo=function(id) return {name=info[id].leaderName,classFilename=id==103 and "MAGE" or "DRUID",assignedRole="DAMAGER",level=50,lfgRoles={tank=false,healer=id~=103,dps=id==103}} end,
  GetSearchResultLeaderInfo=function(id) return {name=info[id].leaderName,classFilename="DRUID"} end,
  GetSearchResultMemberCounts=function(id) return {TANK=id==104 and 1 or 0,HEALER=1,DAMAGER=2,TANK_REMAINING=id==104 and 0 or 1,HEALER_REMAINING=0,DAMAGER_REMAINING=1,LEADER_ROLE_DAMAGER=true} end,
  GetActivityInfoTable=function() return {categoryID=2,fullName="Deadmines",maxNumPlayers=5,useDungeonRoleExpectations=true} end,
  GetActiveEntryInfo=function() end,
}
for _,file in ipairs({"Mixin.lua","TableUtil.lua","EnumUtil.lua","Flags.lua","CallbackRegistry.lua","DataProvider.lua","TreeListDataProvider.lua","ScrollUtil.lua","Blizzard_LFGVanilla_Browse.lua"}) do
  dofile(CLIENT_SOURCE .. "/" .. file)
end
local originalUpdate=LFGBrowseMixin.UpdateResults
local originalSort=LFGBrowseUtil_SortSearchResults
LFGBrowseFrame=CreateFrame("Frame",nil,UIParent)
Mixin(LFGBrowseFrame,LFGBrowseMixin)
local native=LFGBrowseFrame
native.ScrollBox=CreateFrame("Frame",nil,native)
native.ScrollBar=CreateFrame("Frame",nil,native)
native.SendMessageButton=CreateFrame("Button",nil,native)
native.GroupInviteButton=CreateFrame("Button",nil,native)
native.RefreshButton=CreateFrame("Button",nil,native)
native.SearchingSpinner=CreateFrame("Frame",nil,native)
native.NoResultsFound=native:CreateFontString()
native.CategoryDropdown={GetValue=function() return 2 end}
native.ActivityDropdown={selectedValues={799}}
local nativeProviderWrites=0
ScrollBoxListMixin={Event={OnDataProviderReassigned="OnDataProviderReassigned"}}
Mixin(native.ScrollBox,CallbackRegistryMixin)
CallbackRegistryMixin.OnLoad(native.ScrollBox)
native.ScrollBox:GenerateCallbackEvents({"OnDataProviderReassigned"})
function native.ScrollBox:SetDataProvider(provider) nativeProviderWrites=nativeProviderWrites+1; self.provider=provider; self:TriggerEvent("OnDataProviderReassigned") end
function native.ScrollBox:RemoveDataProvider() self.provider=nil; self:TriggerEvent("OnDataProviderReassigned") end
function native.ScrollBox:GetDataProvider() return self.provider end
function native.ScrollBox:HasDataProvider() return self.provider~=nil end
function native.ScrollBox:EnumerateDataProviderEntireRange() return self.provider:EnumerateEntireRange() end
function native.ScrollBox:FindFrame() return nil end -- C list virtualization is outside this probe
function native.ScrollBox:HasScrollableExtent() return true end
native.selectionBehavior=ScrollUtil.AddSelectionBehavior(native.ScrollBox,SelectionBehaviorFlags.Deselectable)
native.selectionBehavior:RegisterCallback(SelectionBehaviorMixin.Event.OnSelectionChanged,function(owner) owner:UpdateButtonState() end,native)
native.SendMessageButton:SetScript("OnClick",LFGBrowseSendMessageButtonMixin.OnClick)
native.GroupInviteButton:SetScript("OnClick",LFGBrowseGroupInviteButtonMixin.OnClick)
local messageScript=native.SendMessageButton.scripts.OnClick
local inviteScript=native.GroupInviteButton.scripts.OnClick
local messageTarget,inviteTarget
ChatFrameUtil={SendTell=function(name) messageTarget=name end}
C_PartyInfo={InviteUnit=function(name) inviteTarget=name end}
native.RefreshButton:SetScript("OnClick",function() LFGBrowse_DoSearch() end)
LFGBrowseSearchEntryTooltip=CreateFrame("Frame",nil,UIParent)
local addon={db={lfg_filters_enabled=true,lfg_filter_group_roles={TANK=true},lfg_filter_group_has_roles={},lfg_filter_player_classes={},lfg_filter_player_roles={},lfg_filter_social_priority=false},
 IsForeverClient=function() return true end,HasClientCapability=function() return true end,Tr=function(_,key) return key end,
 GetLFGSearchFrame=function() return native end,IsDisabledNow=function() return false end,SupportsLFGApplicantUI=function() return false end}
for _,file in ipairs({"Core/SafeAPI.lua","Modules/ForeverBrowse.lua","Modules/LFGFilters.lua","Modules/EventBus.lua"}) do
  assert(loadfile(PROJECT_ROOT .. "/" .. file))("GroupGuardLFG",addon)
end
local eventFrame=frames[#frames]
addon.RequestLFGRefresh=function() end -- unrelated startup/settings UI is outside this source probe
addon:LFGFilters_HookForeverFrame(native)
observe("native Lua refresh and sort functions retain original identity",native.UpdateResults==originalUpdate and LFGBrowseUtil_SortSearchResults==originalSort)
local function emit(event,arg)
  local ok,err=pcall(native.OnEvent,native,event,arg)
  assert(ok,err)
  fire(eventFrame,"OnEvent",event,arg)
  flush()
end
emit("LFG_LIST_SEARCH_RESULTS_RECEIVED")
observe("original Browse event + original sort + original provider execute",nativeProviderWrites==1 and native.totalResults==4 and #native.results==4)
observe("addon reads client-filtered API snapshot without rebuilding native provider",addon._ggForeverResultSource=="api" and nativeProviderWrites==1 and addon._ggForeverVisibleResults==1)
local view=addon._ggForeverBrowseView
observe("only the list and its scrollbar are suppressed",not native.ScrollBox:IsShown() and not native.ScrollBar:IsShown() and native.SendMessageButton:IsShown() and native.GroupInviteButton:IsShown())
observe("no replacement footer controls are created",view.MessageButton==nil and view.InviteButton==nil)
local function findRow(id)
 for _,row in ipairs(view.ScrollBox.rows) do if row.resultID==id then return row end end
end
local groupRow=findRow(102)
groupRow.scripts.OnClick(groupRow,"LeftButton")
observe("filtered group selection drives the original button state",native.SendMessageButton.enabled and not native.GroupInviteButton.enabled and native.selectionBehavior:GetFirstSelectedElementData().data.resultID==102)
fire(native.SendMessageButton,"OnClick")
observe("the original message button contacts the selected standard entry",messageTarget=="Needs tank")
groupRow.scripts.OnClick(groupRow,"LeftButton")
observe("second click deselects through the native selection controller",not native.SendMessageButton.enabled and not native.GroupInviteButton.enabled)
groupRow.scripts.OnClick(groupRow,"LeftButton")
addon.db.lfg_filter_group_roles={HEALER=true}
addon:LFGFilters_ApplyForeverPresentation(native)
observe("filtering out the selected entry clears native selection",not native.selectionBehavior:HasSelection() and not native.SendMessageButton.enabled)
addon.db.lfg_filter_group_roles={TANK=true}
addon:LFGFilters_ApplyForeverPresentation(native)
native.ScrollBox:Show()
observe("native OnShow cannot resurrect the unfiltered list",not native.ScrollBox:IsShown())
native.results={101,103} -- emulate a separate addon's in-place/native filtering
addon:LFGFilters_ApplyForeverPresentation(native)
observe("another addon's native result changes do not erase our API candidates",addon._ggForeverVisibleResults==1 and #addon._ggForeverPresentationResults==4 and #native.results==2)
local nativeTooltipOK=pcall(LFGBrowseSearchEntryTooltip_UpdateAndShow,LFGBrowseSearchEntryTooltip,999)
observe("original client reproduces the expired-listing tooltip failure",not nativeTooltipOK)
local nativeRow=CreateFrame("Button",nil,native.ScrollBox); nativeRow.resultID=999
observe("the expired native row cannot receive hover while its parent is suppressed",not nativeRow:IsVisible())
addon:ForeverBrowse_Hide("probe restore")
observe("native widgets restore when the addon releases presentation",native.ScrollBox:IsShown() and native.ScrollBar:IsShown() and native.SendMessageButton:IsShown())
native.ScrollBox.protected=true; combat=true
addon:ForeverBrowse_SetNativeSuppressed(true)
observe("protected native visibility changes defer in combat",native.ScrollBox:IsShown() and addon._ggForeverNativeVisibilityDeferred==true)
combat=false; addon:ForeverBrowse_ApplyDeferredVisibility()
observe("deferred native suppression applies outside combat",not native.ScrollBox:IsShown() and not addon._ggForeverNativeVisibilityDeferred)
combat=true; addon:ForeverBrowse_SetNativeSuppressed(false)
addon.IsDisabledNow=function() return true end
combat=false; fire(eventFrame,"OnEvent","PLAYER_REGEN_ENABLED")
observe("native restoration still runs after combat when addon features are disabled",native.ScrollBox:IsShown() and not addon._ggForeverNativeVisibilityDeferred)
addon.IsDisabledNow=function() return false end
native.ScrollBox.protected=false
ids={101}; info[101].numMembers=secret
addon:LFG_API_ClearCaches("search")
addon:LFGFilters_ApplyForeverPresentation(native)
observe("unreadable client data produces an explicit waiting state",addon._ggForeverUnavailableResults==1 and view.Empty.text=="LFG_FILTERS_DATA_UNAVAILABLE")
info[101].numMembers=1; addon.db.lfg_filter_group_roles={}; addon.db.lfg_filter_player_roles={HEALER=true}
addon:LFG_API_ClearCaches("search"); addon:LFGFilters_ApplyForeverPresentation(native)
observe("readable advertised healer roles recover after the client update",addon._ggForeverVisibleResults==1)
local playerRow=findRow(101)
playerRow.scripts.OnClick(playerRow,"LeftButton")
observe("solo selection enables both standard buttons",native.SendMessageButton.enabled and native.GroupInviteButton.enabled)
fire(native.GroupInviteButton,"OnClick")
observe("the original invite handler uses the selected native entry",inviteTarget=="Healer")
observe("standard button handlers, parents, anchors and visibility stay original",native.SendMessageButton.scripts.OnClick==messageScript and native.GroupInviteButton.scripts.OnClick==inviteScript and native.SendMessageButton.parent==native and native.GroupInviteButton.parent==native and #native.SendMessageButton.points==0 and #native.GroupInviteButton.points==0 and native.SendMessageButton:IsShown() and native.GroupInviteButton:IsShown())
local provider=CreateTreeDataProvider()
local callbacks=0
provider:RegisterCallback(provider.Event.OnSizeChanged,function() callbacks=callbacks+1 end)
provider:Insert({resultID=1})
observe("original CallbackRegistry and TreeDataProvider dispatch together",callbacks>0)
-- Additional cases from the 4.9.15 source audit. Keep collecting failures so
-- the very same original-client run can compare a previous release honestly.
local failures={}
local function audit(name,fn)
 local ok,result=pcall(fn)
 local passed=ok and result==true
 observations[#observations+1]=(passed and "PASS: " or "FAIL: ")..name
 if not passed then failures[#failures+1]=name..(not ok and (": "..tostring(result)) or "") end
 print((passed and "AUDIT OK: " or "AUDIT FAIL: ")..name)
end
local rawPlayer=C_LFGList.GetSearchResultPlayerInfo
local rawCounts=C_LFGList.GetSearchResultMemberCounts
local function refresh()
 addon:LFG_API_ClearCaches("search")
 addon:LFGFilters_ApplyForeverPresentation(native)
end
audit("native provider reassignment refreshes the filtered view without a game event",function()
 ids={103}; native:UpdateResultList(); flush()
 return addon._ggForeverVisibleResults==0 and addon._ggForeverPresentationResults[1]==103
end)
ids={101}; native:UpdateResultList(); flush(); refresh()
C_LFGList.GetSearchResultPlayerInfo=function(id)
 local p=rawPlayer(id); p.lfgRoles={tank=false,healer=secret,dps=false}; return p
end
audit("a secret advertised role stays unknown instead of becoming false",function()
 refresh()
 local state=addon._ggForeverPresentationState[101]
 local p=addon:LFG_API_GetSearchResultPlayerInfo(101,1)
 return not state.show and state.dataReason~=nil and p.lfgRoles.healer==nil
end)
audit("an unavailable roles table never falls back to assigned damage",function()
 C_LFGList.GetSearchResultPlayerInfo=function(id) local p=rawPlayer(id); p.lfgRoles=secret; return p end
 addon.db.lfg_filter_player_roles={DAMAGER=true}; refresh()
 local state=addon._ggForeverPresentationState[101]
 return not state.show and state.dataReason~=nil
end)
audit("a known selected role satisfies OR even when another role is secret",function()
 C_LFGList.GetSearchResultPlayerInfo=function(id) local p=rawPlayer(id); p.lfgRoles={tank=secret,healer=true,dps=false}; return p end
 addon.db.lfg_filter_player_roles={TANK=true,HEALER=true}; refresh()
 return addon._ggForeverPresentationState[101].show
end)
audit("an unreadable required level is reported as unavailable data",function()
 C_LFGList.GetSearchResultPlayerInfo=function(id) local p=rawPlayer(id); p.level=secret; return p end
 addon.db.lfg_filter_player_roles={}; addon.db.lfg_filter_player_min_level=40; refresh()
 local state=addon._ggForeverPresentationState[101]
 return not state.show and state.dataReason~=nil
end)
addon.db.lfg_filter_player_min_level=0
C_LFGList.GetSearchResultPlayerInfo=rawPlayer
audit("full parties do not acquire imaginary open slots in the fallback",function()
 C_LFGList.GetSearchResultMemberCounts=function() return {TANK=0,HEALER=1,DAMAGER=4} end
 info[102].numMembers=5; addon:LFG_API_ClearCaches("search")
 return addon:LFGFilters_GroupNeedsRole(102,"TANK",addon:LFG_API_GetSearchResultInfo(102))==false
end)
info[102].numMembers=4
audit("a non-healer leader cannot prove that all teammates lack a healer",function()
 C_LFGList.GetSearchResultMemberCounts=function() return {LEADER_ROLE_HEALER=false} end
 addon:LFG_API_ClearCaches("search")
 return addon:LFGFilters_GroupHasRole(102,"HEALER")==nil
end)
C_LFGList.GetSearchResultMemberCounts=rawCounts
addon.db.lfg_filter_player_roles={HEALER=true}; addon.db.lfg_filter_group_roles={TANK=true}
refresh(); addon:ForeverBrowse_SelectResult(101,false)
audit("a selected solo becoming a group disables the original invite action",function()
 info[101].numMembers=2
 addon:LFGFilters_HandleForeverResultUpdated(101); flush()
 return native.SendMessageButton.enabled==true and not native.GroupInviteButton.enabled
end)
audit("the original invite closure follows a changed selected leader",function()
 info[101].numMembers=1; info[101].leaderName="New healer"
 addon:LFGFilters_HandleForeverResultUpdated(101); flush()
 fire(native.GroupInviteButton,"OnClick")
 return inviteTarget=="New healer"
end)
audit("expired cached rows cannot select a missing native result",function()
 addon:ForeverBrowse_SelectResult(nil,false)
 local row=findRow(101)
 addon:LFG_API_GetSearchResultInfo(101)
 local previous=info[101]; info[101]=nil
 fire(row,"OnClick","LeftButton")
 local passed=not native.selectionBehavior:HasSelection()
 info[101]=previous; refresh()
 return passed
end)
local menuCalls=0
MenuUtil={CreateContextMenu=function() menuCalls=menuCalls+1 end}
audit("right-click uses a plain row menu without the protected MenuUtil path",function()
 fire(findRow(101),"OnClick","RightButton")
 local menu=addon._ggForeverRowMenu
 return menuCalls==0 and menu and menu:IsShown() and menu.resultID==101
end)
audit("row menu actions remain bound to their original result",function()
 local menu=addon._ggForeverRowMenu
 if not menu then return false end
 messageTarget=nil; fire(menu.buttons[1],"OnClick")
 return messageTarget=="New healer" and not menu:IsShown()
end)
audit("a pending list refresh closes its context menu",function()
 fire(findRow(101),"OnClick","RightButton")
 addon:LFGFilters_ScheduleForeverPresentation(native)
 local menu=addon._ggForeverRowMenu
 local closed=menu and not menu:IsShown()
 flush(); return closed
end)
audit("unknown self or delisted flags cannot enable standard actions",function()
 addon:ForeverBrowse_SelectResult(nil,false)
 info[101].hasSelf=secret; refresh()
 fire(findRow(101),"OnClick","LeftButton")
 local passed=not native.selectionBehavior:HasSelection()
 info[101].hasSelf=false; refresh()
 return passed
end)
audit("late readable roles recover through bounded retries without a game event",function()
 local reads=0
 C_LFGList.GetSearchResultPlayerInfo=function(id)
  reads=reads+1
  local p=rawPlayer(id); if reads==1 then p.lfgRoles=secret end; return p
 end
 addon._ggForeverDataRetryCount=0
 refresh(); flush()
 return addon._ggForeverVisibleResults==1 and reads>=2
end)
audit("permanently unavailable data stops retrying after three attempts",function()
 local reads=0
 C_LFGList.GetSearchResultPlayerInfo=function(id) reads=reads+1; local p=rawPlayer(id); p.lfgRoles=secret; return p end
 addon._ggForeverDataRetryCount=0; refresh(); flush()
 return addon._ggForeverVisibleResults==0 and #timers==0 and reads<=4 and addon._ggForeverDataRetryCount==3
end)
C_LFGList.GetSearchResultPlayerInfo=rawPlayer
refresh()
audit("the filtered list preserves the original native sort within a category",function()
 ids={103,101}; info[101].age=80; addon.db.lfg_filter_player_roles={HEALER=true,DAMAGER=true}
 native:UpdateResultList(); flush(); refresh()
 local first
 for _,node in view.ScrollBox:GetDataProvider():EnumerateEntireRange() do if node.data.resultID then first=node.data.resultID; break end end
 return native.results[1]==101 and first==101
end)
audit("explicit friend priority overrides native order only when enabled",function()
 info[103].numGuildMates=1; addon.db.lfg_filter_social_priority=true; refresh()
 local first
 for _,node in view.ScrollBox:GetDataProvider():EnumerateEntireRange() do if node.data.resultID then first=node.data.resultID; break end end
 info[103].numGuildMates=0; addon.db.lfg_filter_social_priority=false
 return first==103
end)
audit("class, advertised role and level bounds combine with AND",function()
 addon.db.lfg_filter_player_roles={HEALER=true}; addon.db.lfg_filter_player_classes={DRUID=true,MAGE=true}
 addon.db.lfg_filter_player_min_level=40; addon.db.lfg_filter_player_max_level=60
 addon:LFG_API_ClearCaches("search")
 if not addon:LFGFilters_ResultMatches(101,native) or addon:LFGFilters_ResultMatches(103,native) then return false end
 addon.db.lfg_filter_player_classes={MAGE=true}
 if addon:LFGFilters_ResultMatches(101,native) then return false end
 addon.db.lfg_filter_player_classes={DRUID=true}; addon.db.lfg_filter_player_min_level=51
 return not addon:LFGFilters_ResultMatches(101,native)
end)
addon.db.lfg_filter_player_min_level=0; addon.db.lfg_filter_player_max_level=0; addon.db.lfg_filter_player_classes={}
audit("group Needs and Already has conditions combine with AND",function()
 addon.db.lfg_filter_group_roles={TANK=true}; addon.db.lfg_filter_group_has_roles={HEALER=true}
 addon:LFG_API_ClearCaches("search")
 if not addon:LFGFilters_ResultMatches(102,native) or addon:LFGFilters_ResultMatches(104,native) then return false end
 addon.db.lfg_filter_group_roles={TANK=true,HEALER=true}
 return not addon:LFGFilters_ResultMatches(102,native)
end)
audit("only selected categories pass, and enabling both blocks retains both kinds",function()
 addon.db.lfg_filter_group_roles={TANK=true}; addon.db.lfg_filter_group_has_roles={}; addon.db.lfg_filter_player_roles={}
 if addon:LFGFilters_ResultMatches(101,native) then return false end
 addon.db.lfg_filter_player_roles={HEALER=true}; addon.db.lfg_filter_group_roles={}
 if addon:LFGFilters_ResultMatches(102,native) then return false end
 addon.db.lfg_filter_group_roles={TANK=true}
 return addon:LFGFilters_ResultMatches(101,native) and addon:LFGFilters_ResultMatches(102,native)
end)
audit("Escape and an outside click close the row menu without a HUD catcher",function()
 refresh(); fire(findRow(101),"OnClick","RightButton")
 local menu=addon._ggForeverRowMenu
 if not menu then return false end
 fire(menu,"OnKeyDown","ESCAPE")
 if menu:IsShown() then return false end
 fire(findRow(101),"OnClick","RightButton")
 MouseIsOver=function() return false end; fire(menu,"OnEvent","GLOBAL_MOUSE_DOWN")
 return not menu:IsShown() and menu.parent==UIParent
end)
audit("entering combat closes the plain row menu",function()
 refresh(); fire(findRow(101),"OnClick","RightButton")
 local menu=addon._ggForeverRowMenu
 if not menu then return false end
 combat=true; fire(menu,"OnEvent","PLAYER_REGEN_DISABLED"); combat=false
 return not menu:IsShown()
end)
audit("native footer stays visible when the addon releases the result list",function()
 addon.db.lfg_filter_group_roles={}; addon.db.lfg_filter_player_roles={}; refresh()
 return not view:IsShown() and native.ScrollBox:IsShown() and native.SendMessageButton:IsShown() and native.GroupInviteButton:IsShown()
end)
audit("category order follows the original client when recruiting in a party",function()
 ids={102,101,103}; addon.db.lfg_filter_group_roles={TANK=true}; addon.db.lfg_filter_player_roles={HEALER=true}
 IsInGroup=function() return true end
 native:UpdateResultList(); flush(); refresh()
 local first=view.ScrollBox:GetDataProvider():GetRootNode():GetNodes()[1]
 IsInGroup=function() return false end
 return first and first.data.dividerType==LFGVanillaBrowseDividerType.CategorySolo
end)
audit("an older metadata retry cannot overwrite a newer filter generation",function()
 ids={101}; native:UpdateResultList(); flush()
 local reads=0
 C_LFGList.GetSearchResultPlayerInfo=function(id) reads=reads+1; local p=rawPlayer(id); p.lfgRoles=secret; return p end
 addon._ggForeverDataRetryCount=0; refresh()
 C_LFGList.GetSearchResultPlayerInfo=rawPlayer
 addon.db.lfg_filter_player_roles={DAMAGER=true}
 addon:LFGFilters_RefreshCurrentResults(); flush()
 return reads==1 and addon._ggForeverVisibleResults==0 and addon._ggForeverDataRetryCount==0
end)
audit("closing Browse cancels an outstanding metadata retry",function()
 addon.db.lfg_filter_player_roles={HEALER=true}
 local reads=0
 C_LFGList.GetSearchResultPlayerInfo=function(id) reads=reads+1; local p=rawPlayer(id); p.lfgRoles=secret; return p end
 addon._ggForeverDataRetryCount=0; refresh()
 native:Hide(); addon:ForeverBrowse_Hide("source audit close"); flush()
 C_LFGList.GetSearchResultPlayerInfo=rawPlayer
 return reads==1 and not view:IsShown() and #timers==0
end)
observe("standard footer handlers remain original after all audit cases",native.SendMessageButton.scripts.OnClick==messageScript and native.GroupInviteButton.scripts.OnClick==inviteScript and native.UpdateResults==originalUpdate and LFGBrowseUtil_SortSearchResults==originalSort)
assert(#failures==0,table.concat(failures,"\n"))
print("Original Blizzard Lua integration completed; C widgets/security/renderer are simulated.")
io.stdout:flush()
return observations
