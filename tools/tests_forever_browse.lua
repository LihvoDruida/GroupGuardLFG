-- Offline integration with ORIGINAL Blizzard Lua sources, not tools/mock.lua
-- or the historical regression suites. Only C widget/game bindings below are
-- simulated. This cannot reproduce WoW's renderer, security engine or server.
assert(CLIENT_SOURCE and PROJECT_ROOT and XML_SPECS,
 "Use python3 tools/forever_source_probe.py --client-source PATH --style modern|classic")
local HARNESS_REVISION = "4.9.19"
print("[GroupGuardLFG] native list source contract " .. HARNESS_REVISION)
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
PROBE_FRAMES=frames
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
function methods:SetHeight(h) self.height=h;self.heightMutations=(self.heightMutations or 0)+1 end
function methods:GetWidth() if self.font then if PROBE_METRICS_SECRET then return PROBE_SECRET end; return self.width and self.width>0 and self.width or #(self.text or "")*7 end; return self.width or 420 end
function methods:GetHeight() if self.font then if PROBE_METRICS_SECRET then return PROBE_SECRET end; return self.height and self.height>0 and self.height or 14 end; return self.height or 300 end
function methods:SetFrameStrata(v) self.strata=v end
function methods:GetFrameStrata() return self.strata or "MEDIUM" end
function methods:SetFrameLevel(v) self.level=v end
function methods:GetFrameLevel() return self.level or 10 end
function methods:SetText(v) self.text=v end
function methods:SetTextColor(...) self.textColor={...} end
function methods:SetEnabled(v) self.enabled=v end
function methods:UnregisterAllEvents() self.events={} end
function methods:SetDesaturated(v) self.desaturated=v end
function methods:SetTexture(v) self.texture=v end
function methods:SetJustifyV(v) self.justifyV=v end
function methods:SetClampedToScreen(v) self.clamped=v end
function methods:TooltipBackdropOnLoad() self.backdropLoaded=true end
function methods:SetColorTexture(...) self.color={...} end
function methods:SetAtlas(v) self.atlas=v end
function methods:SetScrollChild(v) self.content=v end
function methods:GetVerticalScroll() return self.offset or 0 end
function methods:SetVerticalScroll(v) self.offset=v end
function methods:GetVerticalScrollRange() return math.max(0,(self.content and self.content:GetHeight() or 0)-self:GetHeight()) end
function methods:GetParent() return self.parent end
function methods:SetScale(v) self.scale=v end
function methods:GetEffectiveScale() return (self.scale or 1)*(self.parent and self.parent:GetEffectiveScale() or 1) end
for _,name in ipairs({"EnableMouse","SetMouseClickEnabled","SetMouseMotionEnabled","SetPropagateMouseClicks","SetPropagateMouseMotion","EnableMouseWheel","SetFixedFrameLevel","SetFixedFrameStrata","SetAlpha","SetJustifyH","SetWordWrap","RegisterForClicks","UpdateScrollChildRect"}) do
  methods[name]=function() end
end
function CreateFrame(kind,name,parent,template)
  local f=setmetatable({kind=kind,parent=parent,shown=true,scripts={},hooks={},events={},attributes={},points={}}, {__index=methods})
  frames[#frames+1]=f
  if template=="UIPanelScrollFrameTemplate" then f.ScrollBar=CreateFrame("Slider",nil,f) end
  if name then _G[name]=f end
  f.template=template
  if PROBE_APPLY_TEMPLATE then PROBE_APPLY_TEMPLATE(f,template) end
  return f
end
function methods:CreateTexture() return CreateFrame("Texture",nil,self) end
function methods:CreateFontString(_,layer,template) local f=CreateFrame("FontString",nil,self,template); f.font=true; return f end
UIParent=CreateFrame("Frame"); UIParent:SetSize(1280,720)
local secret={}
PROBE_SECRET=secret
LFGVANILLA_SETTING_MODERN_STYLE=PROBE_MODERN
function issecretvalue(v) return v==secret end
function canaccessvalue(v) return v~=secret end
function import() return {VoiceModeLabels={}} end
Enum={LFGListDisplayType={Comment=1,RoleCount=2,PlayerCount=3,RoleEnumerate=4,ClassEnumerate=5,HideAll=6}}
CLASS_SORT_ORDER={"DRUID","MAGE"}
GRAY_FONT_COLOR={}; BRIGHTBLUE_FONT_COLOR={}; LIGHTGREEN_FONT_COLOR={}
LFG_LIST_CATEGORY_GROUPS="Groups"; LFG_LIST_CATEGORY_SOLO_PLAYERS="Players"
LFG_LIST_NO_RESULTS_FOUND="No results"; GROUP_INVITE="Invite"; SEND_MESSAGE="Message"
RAID_CLASS_COLORS={DRUID={r=1,g=0.5,b=0},MAGE={r=0.4,g=0.8,b=1}}; NORMAL_FONT_COLOR={r=1,g=0.82,b=0}; HIGHLIGHT_FONT_COLOR={r=1,g=1,b=1}; GREEN_FONT_COLOR={r=0,g=1,b=0}; RED_FONT_COLOR={r=1,g=0,b=0}; GRAY_FONT_COLOR={r=0.5,g=0.5,b=0.5}; BRIGHTBLUE_FONT_COLOR={r=0.4,g=0.7,b=1}; LIGHTGREEN_FONT_COLOR={r=0.4,g=1,b=0.4}; ScrollBoxConstants={RetainScrollPosition=true}
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
  GetSearchResultPlayerInfo=function(id) return {isLeader=true,name=info[id].leaderName,classFilename=id==103 and "MAGE" or "DRUID",assignedRole="DAMAGER",level=50,lfgRoles={tank=false,healer=id~=103,dps=id==103}} end,
  GetSearchResultLeaderInfo=function(id) return {name=info[id].leaderName,classFilename="DRUID",level=50,assignedRole="HEALER",lfgRoles={tank=false,healer=true,dps=false}} end,
  GetSearchResultMemberCounts=function(id) return {TANK=id==104 and 1 or 0,HEALER=1,DAMAGER=2,TANK_REMAINING=id==104 and 0 or 1,HEALER_REMAINING=0,DAMAGER_REMAINING=1,LEADER_ROLE_DAMAGER=true} end,
  GetActivityInfoTable=function() return {categoryID=2,fullName="Deadmines",maxNumPlayers=5,displayType=Enum.LFGListDisplayType.RoleEnumerate,useDungeonRoleExpectations=true} end,
  GetActiveEntryInfo=function() end,
}
for _,file in ipairs({"Mixin.lua","TableUtil.lua","EnumUtil.lua","Flags.lua","CallbackRegistry.lua","DataProvider.lua","TreeListDataProvider.lua","ScrollUtil.lua","Blizzard_LFGVanilla_Browse.lua"}) do
  dofile(CLIENT_SOURCE .. "/" .. file)
end
dofile(PROJECT_ROOT .. "/tools/client_template_boundaries.lua")
dofile(PROJECT_ROOT .. "/tools/blank_list_c_bindings.lua")
local originalUpdate=LFGBrowseMixin.UpdateResults
local originalSort=LFGBrowseUtil_SortSearchResults
LFGBrowseFrame=CreateFrame("Frame",nil,UIParent)
Mixin(LFGBrowseFrame,LFGBrowseMixin)
local native=LFGBrowseFrame
native:SetSize(460,540)
native:SetFrameLevel(200)
native:SetFrameStrata("MEDIUM")
native.BackgroundArt=CreateFrame("Frame",nil,native)
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
-- Keep the real ScrollBoxListMixin; only the native fixture provider is simulated.
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
for _,file in ipairs({"Core/SafeAPI.lua","Modules/ForeverTooltip.lua","Modules/ForeverBrowse.lua","Modules/LFGFilters.lua","Modules/EventBus.lua"}) do
  assert(loadfile(file=="Modules/ForeverBrowse.lua" and BROWSE_IMPLEMENTATION or PROJECT_ROOT .. "/" .. file))("GroupGuardLFG",addon)
end
local eventFrame=frames[#frames]
addon.RequestLFGRefresh=function() end -- unrelated startup/settings UI is outside this source probe
addon:LFGFilters_HookForeverFrame(native)
local originalTooltip=LFGBrowseSearchEntryTooltip_UpdateAndShow
local function emit(event,arg)
  native:OnEvent(event,arg);fire(eventFrame,"OnEvent",event,arg);flush()
end
local function apply()
  addon:LFG_API_ClearCaches("search")
  assert(addon:LFGFilters_ApplyForeverPresentation(native))
  assert(not addon._ggForeverPresentationError,addon._ggForeverPresentationError)
end

-- Current CI integration: original ScrollBox range/layout and native XML templates.
emit("LFG_LIST_SEARCH_RESULTS_RECEIVED")
local view=assert(addon._ggForeverBrowseView)
local scroll=view.ScrollBox
local function row(id)
 local found;view.ScrollBox:ForEachFrame(function(f) if f.resultID==id then found=f end end);return found
end
local function header(kind)
 local found;view.ScrollBox:ForEachFrame(function(f) if f.dividerType==kind then found=f end end);return found
end
local function shown(id) return addon._ggForeverPresentationState[id] and addon._ggForeverPresentationState[id].show==true end
local function reset()
 addon.db.lfg_filter_group_roles={};addon.db.lfg_filter_group_has_roles={};addon.db.lfg_filter_player_roles={};addon.db.lfg_filter_player_classes={}
 addon.db.lfg_filter_player_min_level=0;addon.db.lfg_filter_player_max_level=0
end

observe("group role filters leave both solo players unchanged",shown(101) and shown(103) and shown(102) and not shown(104) and addon._ggForeverVisibleResults==3)
observe("original provider and Lua methods are untouched",nativeProviderWrites==1 and #native.results==4 and native.UpdateResults==originalUpdate and LFGBrowseUtil_SortSearchResults==originalSort)
observe("the standard ScrollBox template is used",view.ScrollBox.template=="WowScrollBoxList")
observe("the original scroll viewport retains clipping",view.ScrollBox.clipChildren==true)
observe("the original scrollbar for the current style is used",view.ScrollBar.template==(PROBE_MODERN and "MinimalScrollBar" or "WowClassicScrollBar"))
observe("group and player rows inherit the game's nested row template",row(102).template=="LFGBrowseNestedSearchEntryTemplate" and row(101).template=="LFGBrowseNestedSearchEntryTemplate")
local height=C_XMLUtil.GetTemplateInfo("LFGBrowseNestedSearchEntryTemplate").height
observe("row height is supplied by the original XML",row(102):GetHeight()==height)
observe("native row fonts are inherited",row(102).Name.fontObject==(PROBE_MODERN and "GameFontNormalLarge" or "GameFontNormal"))
observe("no custom row background, numeric composition or replacement art exists",not row(102).Background and not row(102).Composition and not row(102).RoleCounts and not row(102).NativeArt)
observe("native leader icon and five-slot role display are retained",row(102).PartyIcon:IsShown() and row(102).DataDisplay.Enumerate:IsShown() and #row(102).DataDisplay.Enumerate.Icons==5)
observe("native solo level, class icon and advertised role display are retained",row(101).Level.text=="Lv 50" and row(101).ClassIcon:IsShown() and row(101).DataDisplay.Solo:IsShown())
observe("headers use native labels and plus/minus textures",header(1).template=="LFGBrowseSearchEntryGroupingTemplate" and header(1).CategoryLabel.text=="Players" and header(1).CollapseIcon:IsShown() and not header(1).ExpandIcon:IsShown())
observe("standard footer buttons stay visible with original handlers",native.SendMessageButton:IsShown() and native.GroupInviteButton:IsShown() and native.SendMessageButton.scripts.OnClick==messageScript and native.GroupInviteButton.scripts.OnClick==inviteScript)

reset();addon.db.lfg_filter_player_classes={MAGE=true};apply()
observe("player class filters do not filter groups",shown(102) and shown(104) and shown(103) and not shown(101))
reset();addon.db.lfg_filter_player_roles={HEALER=true};apply()
observe("player role filters do not filter groups",shown(101) and not shown(103) and shown(102) and shown(104))
reset();addon.db.lfg_filter_player_min_level=51;apply()
observe("player level filters leave both groups visible",not shown(101) and not shown(103) and shown(102) and shown(104))
reset();addon.db.lfg_filter_player_classes={MAGE=true};addon.db.lfg_filter_group_roles={TANK=true};apply()
observe("both active blocks independently filter their respective categories",shown(102) and shown(103) and not shown(101) and not shown(104))
addon.db.lfg_filter_group_roles={};apply()
observe("clearing group conditions restores groups without changing player filters",shown(102) and shown(104) and shown(103) and not shown(101))
addon.db.lfg_filter_group_roles={TANK=true};addon.db.lfg_filter_player_classes={};apply()
observe("clearing player conditions restores players without changing group filters",shown(101) and shown(103) and shown(102) and not shown(104))
addon.db.lfg_filter_group_roles={TANK=true,HEALER=true};apply()
observe("group role AND conditions never leak into the player category",shown(101) and shown(103) and not shown(102) and not shown(104))
reset();addon.db.lfg_filter_group_has_roles={TANK=true};apply()
observe("Already has conditions affect groups only",shown(104) and not shown(102) and shown(101) and shown(103))

reset();addon.db.lfg_filter_group_roles={TANK=true};info[104].hasSelf=true;apply()
observe("the original own listing and native unlist visibility are retained",shown(104) and row(104).template=="LFGBrowseSearchEntryTemplate" and row(104).DataDisplay.DelistButton:IsShown()==(row(104).DataDisplay.showDelistButton==true))
info[104].hasSelf=false
reset();addon.db.lfg_filter_player_roles={HEALER=true,DAMAGER=true};LFGVANILLA_SETTING_BROWSE_SHOW_COLLAPSIBLE_CATEGORIES=false;apply()
observe("disabling categories restores the original flat row template and height",row(102).template=="LFGBrowseSearchEntryTemplate" and row(102):GetHeight()==C_XMLUtil.GetTemplateInfo("LFGBrowseSearchEntryTemplate").height and not header(1))
LFGVANILLA_SETTING_BROWSE_SHOW_COLLAPSIBLE_CATEGORIES=true;apply()
local h=header(2);fire(h,"OnClick","LeftButton")
observe("native collapse behavior hides groups without hiding players",not row(102) and row(101)~=nil and header(2).ExpandIcon:IsShown())
fire(header(2),"OnClick","LeftButton")
observe("native expand behavior restores the group rows",row(102)~=nil and header(2).CollapseIcon:IsShown())
apply()
observe("category collapse state survives an independent filter refresh",view.collapsed[2]==false and row(102)~=nil)

addon:ForeverBrowse_SelectResult(nil,false);fire(row(102),"OnClick","LeftButton")
observe("group selection drives the original message button",native.SendMessageButton.enabled==true and not native.GroupInviteButton.enabled)
fire(native.SendMessageButton,"OnClick")
observe("the original message handler contacts the selected group",messageTarget=="Needs tank")
fire(row(101),"OnClick","LeftButton")
fire(native.GroupInviteButton,"OnClick")
observe("solo selection drives the original invite handler",native.GroupInviteButton.enabled and inviteTarget=="Healer")
local selected=native.selectionBehavior:GetFirstSelectedElementData()
fire(row(102),"OnClick","RightButton")
observe("right click uses the standard menu without changing the selected row",MenuUtil.owner==row(102) and MenuUtil.root.title=="Needs tank" and native.selectionBehavior:GetFirstSelectedElementData()==selected)
observe("the standard menu keeps the native message and invite action order",MenuUtil.root.items[1].text==SEND_MESSAGE and MenuUtil.root.items[2].text==GROUP_INVITE and not MenuUtil.root.items[2].enabled)
addon:ForeverBrowse_CloseMenu()
observe("only the owned native menu is closed",MenuUtil.root==nil)

fire(row(101),"OnEnter")
local tooltip=addon._ggForeverNativeTooltip
observe("the tooltip uses native backdrop and member templates",tooltip and tooltip.template=="TooltipBackdropTemplate" and tooltip.Leader.template=="LFGBrowseSearchEntryTooltipGroupLeader")
observe("the game's global tooltip and function remain untouched",tooltip~=LFGBrowseSearchEntryTooltip and LFGBrowseSearchEntryTooltip_UpdateAndShow==originalTooltip)
fire(row(101),"OnLeave")
observe("leaving the row hides only its tooltip",not tooltip:IsShown())
local cached=info[101];info[101]=nil
fire(row(101),"OnEnter")
observe("expired rows never invoke the unsafe native nil-result tooltip path",not tooltip:IsShown())
info[101]=cached;apply()
PROBE_METRICS_SECRET=true
addon:ForeverBrowse_RefreshRows();fire(row(101),"OnEnter")
observe("secret text metrics are guarded in row and tooltip layout",not addon._ggForeverPresentationError and tooltip:IsShown())
PROBE_METRICS_SECRET=false;fire(row(101),"OnLeave")
info[102].generalPlaystyle=2;GetGeneralPlaystyleString=function() return "Relaxed" end;apply()
observe("the native nested playstyle label is retained when provided by the style",not PROBE_MODERN or row(102).PlaystyleLabel.text=="Relaxed")

reset();addon.db.lfg_filter_group_roles={TANK=true};apply()

assert(not addon._ggForeverPresentationError,addon._ggForeverPresentationError)
observe("original ScrollBox.lua owns SetDataProvider and Update",scroll.SetDataProvider==ScrollBoxListMixin.SetDataProvider and scroll.Update==ScrollBoxListMixin.Update)
observe("group Needs Tank preserves unfiltered player category",addon._ggForeverVisibleResults==3 and addon._ggForeverPresentationState[101].show and addon._ggForeverPresentationState[103].show and not addon._ggForeverPresentationState[104].show)
observe("resolved viewport has positive dimensions",scroll:GetWidth()>0 and scroll:GetHeight()>0)
observe("original range/layout acquires real XML row templates",scroll:GetFrameCount()>0 and scroll:GetDataIndexBegin()>0 and scroll:GetDataIndexEnd()>=scroll:GetDataIndexBegin())
local strataOrder={BACKGROUND=0,LOW=1,MEDIUM=2,HIGH=3,DIALOG=4,FULLSCREEN=5,FULLSCREEN_DIALOG=6,TOOLTIP=7}
local function inFront(a,b)
  local sa,sb=strataOrder[a:GetFrameStrata()],strataOrder[b:GetFrameStrata()]
  return sa>sb or (sa==sb and a:GetFrameLevel()>b:GetFrameLevel())
end
observe("list rows remain above a raised native background",inFront(scroll,native))
local oldLayer=view:GetFrameStrata()
view:SetFrameStrata(native:GetFrameStrata());scroll:SetFrameStrata(native:GetFrameStrata())
observe("reproduces 4.9.16 layering failure despite nonzero provider",scroll:GetDataProviderSize()>0 and not inFront(scroll,native))
addon:ForeverBrowse_SyncGeometry()
observe("geometry synchronization repairs list layer",view:GetFrameStrata()==oldLayer and inFront(scroll,native))
native.GetFrameStrata=function() return secret end
native.GetFrameLevel=function() return secret end
addon:ForeverBrowse_SyncGeometry()
observe("secret native layering cannot lower owned list",scroll:GetFrameStrata()=='DIALOG')
native.GetFrameStrata=nil;native.GetFrameLevel=nil
local viewportBottom
for _,point in ipairs(view.points) do if point[1]=="BOTTOMRIGHT" then viewportBottom=point[5] end end
for _,spec in ipairs(XML_SPECS.LFGBrowseFrame.children) do
 if spec.attrs.parentKey=="SendMessageButton" or spec.attrs.parentKey=="GroupInviteButton" then
  local top=tonumber(spec.points[1].y)+spec.height
  observe("viewport clears native footer: "..spec.attrs.parentKey,viewportBottom>=top+8)
  observe("scrollbar clears native footer: "..spec.attrs.parentKey,viewportBottom+(PROBE_MODERN and 2 or -5)>top)
 end
end
observe("no replacement footer controls are created",not view.MessageButton and not view.InviteButton)
for _,row in ipairs(scroll:GetFrames()) do
 observe("acquired row is visible and has XML height",row:IsVisible() and row:GetHeight()>0 and row.template~=nil)
end
addon:ForeverBrowse_Hide('probe reopen')
apply()
observe("hidden-to-shown layout retains a valid data range",scroll:IsVisible() and scroll:GetFrameCount()>0 and not addon._ggForeverPresentationError)
observe("standard bottom buttons and native provider remain intact",native.SendMessageButton:IsShown() and native.GroupInviteButton:IsShown() and nativeProviderWrites==1 and native.ScrollBox:GetDataProvider()~=scroll:GetDataProvider())
native.scale=1.25;addon:ForeverBrowse_SyncGeometry()
observe("viewport scale follows the native panel",view.scale==1.25)
native.scale=1;addon:ForeverBrowse_SyncGeometry()
local rawPlayer=C_LFGList.GetSearchResultPlayerInfo
C_LFGList.GetSearchResultPlayerInfo=function(id) local player=rawPlayer(id);if id==101 then player.lfgRoles={tank=false,healer=secret,dps=false} end;return player end
reset();addon.db.lfg_filter_player_roles={HEALER=true};apply()
observe("restricted player roles wait without filtering groups",not shown(101) and shown(102) and shown(104) and addon._ggForeverPresentationState[101].dataReason~=nil)
C_LFGList.GetSearchResultPlayerInfo=rawPlayer
addon:LFGFilters_RefreshCurrentResults();flush()
observe("readable player metadata restores the row",shown(101) and shown(102) and shown(104))
ids={101,103};native:UpdateResultList();flush()
observe("native provider replacement refreshes the owned list",addon._ggForeverVisibleResults==1 and shown(101) and not shown(103))
observe("classic tooltip omits the modern voice field",PROBE_MODERN or tooltip.VoiceChat==nil)
ids={};native:UpdateResultList();flush()
observe("native empty state is not duplicated",native.NoResultsFound:IsShown() and not view.Empty:IsShown())
reset();addon.db.lfg_filter_group_roles={TANK=true}
-- A realistic result cap must be virtualized by the original ScrollBox.
for i=1,100 do
 local id=100+i;ids[i]=id
 info[id]={leaderName="Listing "..i,numMembers=i<=48 and 4 or 1,hasSelf=false,isDelisted=false,age=i,activityIDs={799}}
end
C_LFGList.GetSearchResultMemberCounts=function(id)
 return {TANK=id<=118 and 1 or 0,HEALER=1,DAMAGER=2,TANK_REMAINING=id<=118 and 0 or 1,HEALER_REMAINING=0,DAMAGER_REMAINING=1,LEADER_ROLE_DAMAGER=true}
end
emit("LFG_LIST_SEARCH_RESULTS_RECEIVED")
observe("82 of 100 are filtered before native view virtualization",addon._ggForeverVisibleResults==82 and scroll:GetDataProviderSize()>82)
observe("original ScrollBox creates viewport rows instead of 82 full rows",scroll:GetFrameCount()>0 and scroll:GetFrameCount()<scroll:GetDataProviderSize())
scroll:ScrollToEnd(ScrollBoxConstants.NoScrollInterpolation)
observe("scrolling to the end acquires later rows",scroll:GetDataIndexBegin()>1 and scroll:GetDataIndexEnd()==scroll:GetDataProviderSize() and scroll:GetFrameCount()>0)
scroll:ScrollToBegin(ScrollBoxConstants.NoScrollInterpolation)
observe("scrolling back restores the first category",scroll:GetDataIndexBegin()==1 and scroll:GetFrameCount()>0)
local renderer=addon.ForeverBrowse_RenderRow
addon.ForeverBrowse_RenderRow=function() error("intentional row initialization failure") end
addon:LFG_API_ClearCaches("search")
local ok=addon:LFGFilters_ApplyForeverPresentation(native)
observe("initializer failures cannot be erased and shown as an empty success",not ok and addon._ggForeverPresentationError~=nil and not view:IsShown() and native.ScrollBox:IsShown())
addon.ForeverBrowse_RenderRow=renderer
apply()
observe("successful refresh recovers after a render failure",view:IsVisible() and not addon._ggForeverPresentationError and scroll:GetFrameCount()>0)
local update=scroll.FullUpdate
scroll.FullUpdate=function(self) self:GetView():Flush() end
ok=addon:LFGFilters_ApplyForeverPresentation(native)
observe("nonempty data with zero acquired frames restores the native list",not ok and addon._ggForeverPresentationError~=nil and not view:IsShown() and native.ScrollBox:IsShown())
scroll.FullUpdate=update
apply()
observe("restored layout can show results again",view:IsVisible() and scroll:GetFrameCount()>0)
return observations
