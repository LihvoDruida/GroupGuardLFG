-- Exercise actual SafeAPI + filter + isolated renderer together. The native
-- provider/selection and every text-width query are traps, not silent no-ops.
local passed, failed = 0, 0
local function check(name, value)
  if value then passed=passed+1; print("PASS " .. name)
  else failed=failed+1; print("FAIL " .. name) end
end
local function frame(parent)
  local f={ parent=parent, shown=true, scripts={}, rows={}, points={} }
  function f:SetPoint(...) self.points[#self.points+1]={...} end
  function f:SetAllPoints(target) self.target=target end
  function f:ClearAllPoints() self.points={} end
  function f:SetSize(w,h) self.w,self.h=w,h end
  function f:SetWidth(w) self.w=w end
  function f:SetHeight(h) self.h=h end
  function f:GetHeight() return self.h or 120 end
  function f:GetWidth()
    if self.isFontString then error("secret text width must never be read or compared") end
    return self.w or 300
  end
  function f:GetStringWidth() error("secret string width must never be read or compared") end
  function f:GetFrameLevel() return self.level or 10 end
  function f:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end
  function f:SetFrameLevel(v) self.level=v end
  function f:SetFrameStrata(v) self.strata=v end
  function f:SetFixedFrameLevel(v) self.fixedLevel=v end
  function f:SetFixedFrameStrata(v) self.fixedStrata=v end
  function f:EnableMouse(v) self.mouseEnabled=v end
  function f:SetMouseClickEnabled(v) self.clickEnabled=v end
  function f:SetMouseMotionEnabled(v) self.motionEnabled=v end
  function f:SetPropagateMouseClicks(v) self.propagateClicks=v end
  function f:SetPropagateMouseMotion(v) self.propagateMotion=v end
  function f:SetAlpha(v) self.alpha=v end
  function f:GetAlpha() return self.alpha or 1 end
  function f:EnableMouseWheel() end
  function f:SetClampedToScreen() end
  function f:SetScale(value) self.scale=value end
  function f:SetAutoFocus() end
  function f:SetMaxLetters() end
  function f:SetNumeric() end
  function f:ClearFocus() end
  function f:SetChecked(v) self.checked=v end
  function f:GetChecked() return self.checked end
  function f:GetText() return self.text end
  function f:SetJustifyV() end
  function f:HookScript(k,fn) self.hooks=self.hooks or {}; self.hooks[k]=fn end
  function f:SetScrollChild(child) self.scrollChild=child end
  function f:GetVerticalScroll() return self.verticalScroll or 0 end
  function f:SetVerticalScroll(offset) self.verticalScroll=offset end
  function f:GetVerticalScrollRange() return math.max(0,(self.scrollChild and self.scrollChild:GetHeight() or 1)-self:GetHeight()) end
  function f:UpdateScrollChildRect() end
  function f:SetColorTexture(...) self.color={...} end
  function f:SetAtlas(v) self.atlas=v end
  function f:SetText(v) self.text=v end
  function f:RegisterEvent() end
  function f:SetOwner(row) self.owner=row end
  function f:IsOwned(row) return self.owner==row end
  function f:AddLine(text) self.lines=self.lines or {}; self.lines[#self.lines+1]=text end
  function f:ClearLines() self.lines={} end
  function f:SetTextColor(...) self.textColor={...} end
  function f:SetJustifyH() end
  function f:SetWordWrap() end
  function f:SetEnabled(v) self.enabled=v end
  function f:RegisterForClicks() end
  function f:Show() self.shown=true end
  function f:Hide() self.shown=false end
  function f:SetShown(v) self.shown=v end
  function f:IsShown() return self.shown end
  function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
  function f:SetScript(k,fn) self.scripts[k]=fn end
  function f:CreateTexture() return frame(self) end
  function f:CreateFontString() local font=frame(self); font.isFontString=true; return font end
  function f:ForEachFrame(fn) for _,r in ipairs(self.rows) do fn(r) end end
  return f
end
UIParent=frame()
UIParent:SetSize(1280,720)
CreateFrame=function(kind,_,parent,template)
  assert(template~="GroupGuardLFGBrowseRowTemplate", "new addon XML templates are unavailable in this client fixture")
  local f=frame(parent); f.kind=kind
  if template=="UIPanelScrollFrameTemplate" then f.ScrollBar=frame(f) end
  return f
end
GetTime=function() return 0 end
InviteToGroup=function() end
SlashCmdList={}
IsInGroup=function() return false end
UnitIsGroupLeader=function() return false end
UnitIsGroupAssistant=function() return false end
LFGVanillaBrowseDividerType={CategorySolo=1,CategoryGroup=2}
LFGVANILLA_SETTING_BROWSE_SHOW_COLLAPSIBLE_CATEGORIES=true
LFG_LIST_CATEGORY_SOLO_PLAYERS,LFG_LIST_CATEGORY_GROUPS="Players","Groups"
LFG_LIST_NO_RESULTS_FOUND,LFG_SELF_LISTING="No results","Your listing"
SEND_MESSAGE,GROUP_INVITE="Send message","Invite"
LFG_LIST_REPORT_GROUP_FOR,REPORT_GROUP_FINDER_ADVERTISEMENT="Report","Report ad"
ScrollBoxConstants={RetainScrollPosition=true}
TreeDataProviderConstants={DoInvalidation=false,ExcludeCollapsed=true,IncludeCollapsed=false}
RAID_CLASS_COLORS={DRUID={r=1,g=0.5,b=0}}
local nativeWrites, nativeRebuilds = 0, 0
local nativeProvider={}
local function forbidden() nativeWrites=nativeWrites+1; error("native LFG state touched") end
LFGBrowseFrame=frame(UIParent)
LFGBrowseFrame.ScrollBox=frame(LFGBrowseFrame)
LFGBrowseFrame.ScrollBar=frame(LFGBrowseFrame)
LFGBrowseFrame.SendMessageButton=frame(LFGBrowseFrame)
LFGBrowseFrame.GroupInviteButton=frame(LFGBrowseFrame)
LFGBrowseFrame.results={101,102,103}
LFGBrowseFrame.totalResults=3
LFGBrowseFrame.ScrollBox.SetDataProvider=forbidden
LFGBrowseFrame.ScrollBox.RemoveDataProvider=forbidden
LFGBrowseFrame.ScrollBox.GetDataProvider=function() return nativeProvider end
LFGBrowseFrame.selectionBehavior={ClearSelections=forbidden,ToggleSelect=forbidden}
LFGBrowseFrame.UpdateResults=function() nativeRebuilds=nativeRebuilds+1 end
LFGBrowseFrame.NoResultsFound={Show=forbidden,Hide=forbidden,SetText=forbidden}
local nativeRow=frame(LFGBrowseFrame.ScrollBox)
nativeRow.resultID=101
nativeRow.ResultBG=frame(nativeRow)
nativeRow.ResultBG.SetColorTexture=forbidden
nativeRow.HookScript=forbidden
nativeRow.SetElementData=forbidden
setmetatable(nativeRow,{__newindex=function() forbidden() end})
LFGBrowseFrame.ScrollBox.rows={nativeRow}
LFGBrowseFrame.ScrollBox.HookScript=forbidden
LFGBrowseSearchEntry_Update=forbidden
LFGBrowseSearchEntryTooltip_UpdateAndShow=forbidden
LFGBrowseSearchEntryTooltip=frame(UIParent)
LFGBrowseSearchEntryTooltip.ClearLines=forbidden

local function node(data)
  local n={data=data,children={}}
  function n:Insert(v) local child=node(v); self.children[#self.children+1]=child; return child end
  function n:SetCollapsed(v) self.collapsed=v end
  function n:ToggleCollapsed() self.collapsed=not self.collapsed end
  function n:Enumerate(_,_,excludeCollapsed)
    local nodes={}
    local function visit(current)
      for _,child in ipairs(current.children) do
        nodes[#nodes+1]=child
        if not excludeCollapsed or not child.collapsed then visit(child) end
      end
    end
    visit(self)
    local index=0
    return function() index=index+1; if nodes[index] then return index,nodes[index] end end
  end
  return n
end
CreateTreeDataProvider=function() return node() end
-- Optional contract run against the client's actual TreeListDataProvider.lua.
-- The copyrighted client source is supplied locally, not bundled in the addon.
local treeSource=os.getenv("GROUPGUARD_TREE_SOURCE")
if treeSource then
  CreateFromMixins=function(...)
    local result={}
    for i=1,select("#",...) do for k,v in pairs(select(i,...)) do result[k]=v end end
    return result
  end
  CallbackRegistryMixin={OnLoad=function() end,TriggerEvent=function() end,
    GenerateCallbackEvents=function(self,events) self.Event={}; for _,event in ipairs(events) do self.Event[event]=event end end}
  DataProviderMixin={Event={OnSizeChanged="OnSizeChanged",OnSort="OnSort"}}
  ipairs_reverse=function(values)
    local index=#values+1
    return function() index=index-1; if index>0 then return index,values[index] end end
  end
  CreateTableEnumerator=function(values,first,last)
    local index=(first or 1)-1
    return function() index=index+1; if index<=(last or #values) and values[index] then return index,values[index] end end
  end
  dofile(treeSource)
end
CreateScrollBoxListTreeListView=function()
  return {SetElementFactory=function(self,fn) self.factory=fn end,SetElementExtent=function() end}
end
ScrollUtil={InitScrollBoxListWithScrollBar=function() error("owned results must not use the native virtual-list initializer") end}

local secret=setmetatable({}, {__tostring=function() error("secret conversion") end,__lt=function() error("secret comparison") end})
canaccessvalue=function(v) return v~=secret end
issecretvalue=function(v) return v==secret end
local info={
  [101]={leaderName="Sebas",numMembers=1,activityIDs={5}},
  [102]={leaderName="Group",numMembers=4,activityIDs={5}},
  [103]={leaderName="Other",numMembers=1,activityIDs={5}},
}
C_LFGList={
  GetSearchResultInfo=function(id) return info[id] end,
  GetSearchResultPlayerInfo=function(id)
    return {name=info[id].leaderName,classFilename=id==103 and "MAGE" or "DRUID",level=42,lfgRoles={healer=true},assignedRole="HEALER"}
  end,
  GetSearchResultLeaderInfo=function(id) return {name=info[id].leaderName,classFilename="DRUID",level=42} end,
  GetSearchResultMemberCounts=function() return {TANK=1,HEALER=1,DAMAGER=2,TANK_REMAINING=0,HEALER_REMAINING=0,DAMAGER_REMAINING=1} end,
  GetActivityInfoTable=function() return {fullName="Dungeon",categoryID=2,maxNumPlayers=5,useDungeonRoleExpectations=true} end,
}
local addon={db={lfg_filters_enabled=true,lfg_filter_group_has_roles={TANK=true},lfg_filter_player_classes={DRUID=true},lfg_filter_social_priority=true},
  IsForeverClient=function() return true end,HasClientCapability=function() return true end,Tr=function(_,key) return key end,
  IsDisabledNow=function() return false end,SupportsLFGApplicantUI=function() return false end,
  SupportsLFGApplicantSettings=function() return false end,GetFlagReason=function() return false end}
for _,path in ipairs({"Core/SafeAPI.lua","Modules/LFG.lua","Modules/ForeverBrowse.lua","Modules/LFGFilters.lua", "Modules/LFGEnhancements.lua","Modules/RealmInsights.lua"}) do
  assert(loadfile("../"..path))("GroupGuardLFG",addon)
end
local results=LFGBrowseFrame.results
local ok,err=pcall(function() return addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame) end)
check("real filter and renderer initialize without measuring text",ok)
if not ok then error(err) end
local own=addon._ggForeverBrowseView
check("addon presentation is rooted under UIParent",own.parent==UIParent)
check("own provider is installed on a separate ScrollFrame",own.ScrollBox:GetDataProvider()~=nil and own.ScrollBox.kind=="ScrollFrame")
check("native provider, rows and selection never mutated",nativeWrites==0 and nativeRebuilds==0)
check("native result identity and total are preserved",LFGBrowseFrame.results==results and LFGBrowseFrame.totalResults==3)
check("nonmatching solo player omitted without a blank row",addon._ggForeverVisibleResults==2 and #own.ScrollBox.rows==4)
own.ScrollBox:SetVerticalScroll(20)
addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)
check("scroll position survives a matching result refresh",own.ScrollBox:GetVerticalScroll()==20)
check("visible count is tied to the addon view",addon:LFGFilters_GetForeverVisibleCount()==2)
local function find(id)
  for _,row in ipairs(own.ScrollBox.rows) do if row.resultID==id then return row end end
end
local solo=find(101)
solo.scripts.OnClick(solo,"LeftButton")
check("row selection belongs only to the addon",own.selectedResultID==101 and solo.Selected.shown and nativeWrites==0)
check("solo selection enables whisper and invite",own.MessageButton.enabled and own.InviteButton.enabled)
local whispered,invited
ChatFrameUtil={SendTell=function(name) whispered=name end}
InviteToGroup=function(name) invited=name end
own.MessageButton.scripts.OnClick()
own.InviteButton.scripts.OnClick()
check("explicit whisper and invite use the selected public name",whispered=="Sebas" and invited=="Sebas")
local nativeInvited
C_PartyInfo={InviteUnit=function(name) nativeInvited=name end}
invited=nil
own.InviteButton.scripts.OnClick()
check("Forever invitation prefers its native C_PartyInfo API",nativeInvited=="Sebas" and invited==nil)
C_PartyInfo=nil
local legacyInvite=InviteToGroup
InviteToGroup=nil
addon:ForeverBrowse_UpdateSelection()
check("missing invitation capability disables the button",own.InviteButton.enabled==false)
InviteToGroup=legacyInvite
addon:ForeverBrowse_UpdateSelection()
local group=find(102)
group.scripts.OnClick(group,"LeftButton")
check("group selection enables whisper but disables invite",own.MessageButton.enabled and not own.InviteButton.enabled)
check("group composition uses native role icons with readable counts",group.RoleCounts[1].text==1 and group.RoleCounts[2].text==1 and group.Roles[1].atlas=="groupfinder-icon-role-large-tank")
check("group entries use the game's group-leader marker",group.ClassIcon.atlas=="groupfinder-icon-leader")
local publicLeader=C_LFGList.GetSearchResultLeaderInfo
C_LFGList.GetSearchResultLeaderInfo=function() return nil end
addon:LFG_ForgetSearchResult(101)
addon:ForeverBrowse_RenderRow(solo,solo.elementNode)
check("solo class icons use member metadata when leader info is unavailable",solo.ClassIcon:IsShown() and solo.ClassIcon.atlas=="groupfinder-icon-class-druid")
C_LFGList.GetSearchResultLeaderInfo=publicLeader
addon:LFG_ForgetSearchResult(101)
check("native-style rows have separate entry and category extents",group:GetHeight()==52 and own.ScrollBox.rows[1]:GetHeight()==36 and group.NativeArt.atlas=="common-button-list-mid2")
local menuButtons={}
MenuUtil={CreateContextMenu=function(_,builder)
  builder(nil,{CreateTitle=function() end,CreateButton=function(_,text,fn)
    menuButtons[text]=fn
    return {SetEnabled=function() end}
  end})
end}
local soloMenu=find(101)
soloMenu.scripts.OnClick(soloMenu,"RightButton")
group.scripts.OnClick(group,"LeftButton")
menuButtons[SEND_MESSAGE]()
check("an open menu keeps its original whisper target after selection changes",whispered=="Sebas")
info[101].isDelisted=true
whispered=nil
menuButtons[SEND_MESSAGE]()
check("expired context-menu targets are revalidated on click",whispered==nil)
info[101].isDelisted=false
addon:LFG_ForgetSearchResult(101)
MenuUtil=nil
local groupHeader=own.ScrollBox.rows[1]
groupHeader.scripts.OnClick(groupHeader,"LeftButton")
addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)
local categoryNodes=own.ScrollBox:GetDataProvider().GetChildrenNodes and own.ScrollBox:GetDataProvider():GetChildrenNodes() or own.ScrollBox:GetDataProvider().children
check("category collapse survives provider rebuild",categoryNodes[1].collapsed==true and #own.ScrollBox.rows==3)

info[101].leaderName=secret
info[101].age=secret
addon:LFG_API_ClearCaches("search")
ok=pcall(function() addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame) end)
check("unreadable names and numbers never trigger string/width operations",ok and find(101).Name.text=="...")
solo=find(101)
solo.scripts.OnClick(solo,"LeftButton")
check("unreadable name disables player actions",not own.MessageButton.enabled and not own.InviteButton.enabled)

local draws=0
local oldRender=addon.ForeverBrowse_RenderRow
addon.ForeverBrowse_RenderRow=function(self,...) draws=draws+1; return oldRender(self,...) end
info[101].leaderName="Changed"
addon:LFGFilters_HandleForeverResultUpdated(101)
check("unchanged filter state repaints only the updated visible row",draws==1 and find(101).Name.text=="Changed")
addon.ForeverBrowse_RenderRow=oldRender
info[101].isDelisted=true
addon:LFG_ForgetSearchResult(101)
addon:ForeverBrowse_UpdateSelection()
check("delisted selection is cleared without native callbacks",own.selectedResultID==nil and not own.MessageButton.enabled and nativeWrites==0)
LFGBrowseFrame.searching=true
addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)
check("native searching state hides addon presentation",not own.shown and addon:LFGFilters_GetForeverVisibleCount()==nil)
LFGBrowseFrame.searching=false
LFGBrowseFrame.searchFailed=true
addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)
check("native search failure remains visible",not own.shown)
LFGBrowseFrame.searchFailed=false
LFGBrowseFrame.shown=false
addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)
check("closed Browse cannot show an orphaned addon list",not own.shown)
LFGBrowseFrame.shown=true
addon.db.lfg_filter_player_classes={}
addon.db.lfg_filter_group_has_roles={}
addon.db.lfg_filter_social_priority=false
addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)
check("turning off local presentation restores the native view",not own.shown and nativeWrites==0)
check("native-only searches still report a settled visible count",addon:LFGFilters_GetForeverVisibleCount()==3)
addon.db.lfg_filter_player_classes={WARRIOR=true}
LFGBrowseFrame.results={101,103}
addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)
check("zero matches shows an addon-owned empty state",own.shown and own.Empty.shown and #own.ScrollBox.rows==0)
local hookMethod,hookCallback
hooksecurefunc=function(target,method,fn) assert(target==LFGBrowseFrame); hookMethod,hookCallback=method,fn end
check("post-hook observes native searching and result refreshes",addon:LFGFilters_HookForeverFrame(LFGBrowseFrame) and hookMethod=="UpdateResults")
local queue,builds={},0
C_Timer={After=function(delay,fn) assert(delay==0); queue[#queue+1]=fn end}
local setter=own.ScrollBox.SetDataProvider
own.ScrollBox.SetDataProvider=function(self,...) builds=builds+1; return setter(self,...) end
for i=1,100 do hookCallback(LFGBrowseFrame) end
for _,fn in ipairs(queue) do fn() end
check("a burst of 100 native refreshes produces one addon provider update",builds==1)
own.ScrollBox.SetDataProvider=function() error("simulated addon renderer failure") end
check("renderer failure hides the stale filtered view",addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)==false and not own.shown)
check("renderer failure invalidates the visible-count cache",addon:LFGFilters_GetForeverVisibleCount()==nil)
own.ScrollBox.SetDataProvider=setter
local previousView=addon._ggForeverBrowseView
addon._ggForeverBrowseView=nil
local previousUtil=ScrollUtil
ScrollUtil=nil
check("filtering works without native virtualization or new XML templates",addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)==true and nativeWrites==0)
addon:ForeverBrowse_Hide()
ScrollUtil=previousUtil
addon._ggForeverBrowseView=previousView
print("--- Native row / tooltip isolation and secret result records ---")
local hookCount=0
hooksecurefunc=function() hookCount=hookCount+1 end
addon.GetLFGSearchFrame=function() return LFGBrowseFrame end
addon:LFG_HookSearchPanel()
addon:LFG_HookEnhancedSearchTooltip()
addon:LFG_InitRealmInsights()
check("Forever setup installs no native row/tooltip/provider observers",hookCount==0 and nativeWrites==0)
addon:LFG_InitEnhancements()
check("addon-owned tooltips need no native-hook initialization retries",not addon._ggEnhancementRetryScheduled)
addon._ggForeverBrowseView.collapsed={}
addon.db.lfg_filter_player_classes={}
addon.db.lfg_filter_social_priority=true
addon.db.lfg_highlight=true
info[101].isDelisted=false
info[101].leaderName="Sebas"
info[101].areaName="Westfall"
addon:LFG_ForgetSearchResult(101)
addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)
local savedEvaluate=addon.EvaluateSearchResultFlag
addon.EvaluateSearchResultFlag=function(_,id) return id==101 end
addon:LFG_HighlightSearchResults()
check("full search highlight paints only addon-owned rows",find(101).Background.color[1]==0.35 and nativeWrites==0)
addon:LFG_ClearVisibleHighlights()
check("highlight cleanup does not recolor native ResultBG",find(101).Background.color[1]==0.06 and nativeWrites==0)
check("single-result highlight reaches the addon row",addon:LFG_HighlightSearchResult(101) and find(101).Background.color[1]==0.35 and nativeWrites==0)
addon:LFG_HighlightRows()
check("applicant cleanup cannot hook native Forever browse rows",nativeWrites==0)
addon.EvaluateSearchResultFlag=savedEvaluate
addon.db.lfg_highlight=false
addon:LFG_HighlightSearchResults()
check("turning off highlight clears the addon color",find(101).Background.color[1]==0.06 and nativeWrites==0)

GameTooltip=frame(UIParent)
function GameTooltip:SetText(text) self.text=text; self.lines={} end
addon.db.lfg_tooltips=true
addon.db.lfg_tooltip_details=true
local hover=find(101)
hover.scripts.OnEnter(hover)
local roleTextFound=false
for _,line in ipairs(GameTooltip.lines) do if line:find("LFG_FILTER_HEALER",1,true) then roleTextFound=true end end
check("member tooltip uses localized advertised roles",roleTextFound)
local publicPlayerInfo=C_LFGList.GetSearchResultPlayerInfo
C_LFGList.GetSearchResultPlayerInfo=function(id,index)
  local member=publicPlayerInfo(id,index)
  if id==102 then member.assignedRole="TANK"; member.lfgRoles={healer=true} end
  return member
end
addon:LFG_ForgetSearchResult(102)
local groupTooltipRow=frame(own.Content)
addon:ForeverBrowse_RenderRow(groupTooltipRow,{data={resultID=102}})
groupTooltipRow.scripts.OnEnter(groupTooltipRow)
local groupRoleFound=false
for _,line in ipairs(GameTooltip.lines) do if line:find("LFG_FILTER_TANK",1,true) then groupRoleFound=true end end
check("group member tooltip uses the assigned group role",groupRoleFound)
C_LFGList.GetSearchResultPlayerInfo=publicPlayerInfo
addon:LFG_ForgetSearchResult(102)
hover.scripts.OnEnter(hover)
groupTooltipRow:Hide()
local detailFound=false
for _,line in ipairs(GameTooltip.lines) do if line:find("LFG_INSIGHTS_ZONE",1,true) then detailFound=true end end
check("own row tooltip preserves insight details",GameTooltip:IsOwned(hover) and detailFound)
addon._lfgCurrentSearchTooltip=LFGBrowseSearchEntryTooltip
addon._lfgCurrentSearchResultID=101
ok=addon:LFG_RefreshCurrentSearchTooltip(101)
check("tooltip update never invokes the native Forever renderer",ok and nativeWrites==0 and GameTooltip:IsOwned(hover))
local tooltipText=GameTooltip.text
addon._ggTooltipModifierFrame.scripts.OnEvent(nil,"MODIFIER_STATE_CHANGED","LSHIFT")
check("Shift refresh uses the addon tooltip renderer",GameTooltip.text==tooltipText and nativeWrites==0)
GameTooltip:SetOwner(nativeRow)
check("tooltip refresh does not replace another tooltip owner",not addon:LFG_RefreshCurrentSearchTooltip(101) and GameTooltip:IsOwned(nativeRow))
hover.scripts.OnLeave(hover)
check("leaving a recycled row does not hide another owner's tooltip",GameTooltip:IsShown() and GameTooltip:IsOwned(nativeRow))
hover.scripts.OnEnter(hover)
local beforeRecycle=hover.elementNode
local otherNode={data={resultID=102}}
addon:ForeverBrowse_RenderRow(hover,otherNode)
check("recycling a hovered row hides its previous listing tooltip",not GameTooltip:IsShown() and addon._ggForeverBrowseView.tooltipRow==nil)
addon:ForeverBrowse_RenderRow(hover,beforeRecycle)
hover.scripts.OnEnter(hover)
local missingInfo=info[101]
info[101]=nil
addon:LFG_ForgetSearchResult(101)
hover.scripts.OnEnter(hover)
check("a disappeared listing closes its owned tooltip safely",not GameTooltip:IsShown())
info[101]=missingInfo
addon:LFG_ForgetSearchResult(101)

info[101].hasSelf=secret
info[101].numMembers=secret
info[101].newPlayerFriendly=secret
info[101].activityIDs=secret
addon:LFG_ForgetSearchResult(101)
ok=pcall(function() addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame); addon:LFG_HighlightSearchResult(101) end)
check("secret hasSelf, numMembers and activityIDs are never tested raw",ok and nativeWrites==0)
local snapshot=addon:LFG_API_GetSearchResultInfo(101)
check("secret flags/counts produce a safe snapshot",snapshot.hasSelf==false and snapshot.numMembers==nil and #snapshot.activityIDs==0)
local savedInfo=info[101]
info[101]=secret
addon:LFG_ForgetSearchResult(101)
ok=pcall(function() addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame) end)
check("a fully inaccessible result table is skipped safely",ok and addon:LFG_API_GetSearchResultInfo(101)==nil and nativeWrites==0)
info[101]=savedInfo
info[101].hasSelf=false
info[101].numMembers=1
info[101].activityIDs={5}
addon:LFG_ForgetSearchResult(101)
addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)
hover=find(101)
hover.scripts.OnClick(hover,"LeftButton")
IsInGroup=function() return secret end
addon:ForeverBrowse_UpdateSelection()
check("unreadable group state cannot authorize an invite",own.InviteButton.enabled==false)
IsInGroup=function() return true end
UnitIsGroupLeader=function() return secret end
UnitIsGroupAssistant=function() return secret end
addon:ForeverBrowse_UpdateSelection()
check("secret leadership flags do not undergo boolean tests",own.InviteButton.enabled==false)
IsInGroup=function() return false end
addon:ForeverBrowse_UpdateSelection()
check("public solo state restores the invite action",own.InviteButton.enabled==true)
local originalCreate=CreateFrame
local eventFrame
CreateFrame=function(...) eventFrame=originalCreate(...); return eventFrame end
assert(loadfile("../Modules/EventBus.lua"))("GroupGuardLFG",addon)
CreateFrame=originalCreate
local renderCount=0
local render=addon.ForeverBrowse_RenderRow
addon.ForeverBrowse_RenderRow=function(self,...) renderCount=renderCount+1; return render(self,...) end
info[101].leaderName="Event update"
eventFrame.scripts.OnEvent(eventFrame,"LFG_LIST_SEARCH_RESULT_UPDATED",101)
check("real result-update event repaints one addon row without native hooks",renderCount==1 and find(101).Name.text=="Event update" and nativeWrites==0)
addon.ForeverBrowse_RenderRow=render
addon.db.lfg_filter_player_classes={}
addon.db.lfg_filter_social_priority=false
addon.db.lfg_highlight=true
addon.db.lfg_tooltips=false
check("highlight-only mode keeps addon-owned rows",addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame) and own:IsShown() and nativeWrites==0)
addon.db.lfg_highlight=false
addon.db.lfg_tooltips=true
check("tooltip-only mode keeps addon-owned rows",addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame) and own:IsShown() and nativeWrites==0)
addon.db.lfg_tooltips=false
check("disabling all browse features restores untouched native rows",not addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame) and not own:IsShown() and nativeWrites==0)
local visibleRows=own.ScrollBox.rows
addon:ForeverBrowse_Hide()
check("closed addon view does not fall back to native highlighting",not addon:LFG_HighlightSearchResult(101) and own.ScrollBox.rows==visibleRows and nativeWrites==0)
addon:LFG_HighlightSearchResults()
addon:LFG_ClearVisibleHighlights()
check("all paths leave native provider untouched",nativeWrites==0 and nativeRebuilds==0)
print("--- Real filter-control clicks -> queued refresh -> visible owned rows ---")
local classes={{"Druid","DRUID"},{"Mage","MAGE"}}
GetNumClasses=function() return #classes end
GetClassInfo=function(index) return classes[index][1],classes[index][2] end
addon.db.lfg_filter_group_roles={}
addon.db.lfg_filter_group_has_roles={}
addon.db.lfg_filter_player_roles={}
addon.db.lfg_filter_player_classes={}
addon.db.lfg_filter_player_min_level=0
addon.db.lfg_filter_player_max_level=0
addon.db.lfg_filters_enabled=false
addon.db.lfg_filter_social_priority=true
LFGBrowseFrame.results={101,102,103}
LFGBrowseFrame.totalResults=3
C_LFGList.GetSearchResultPlayerInfo=function(id)
  local mage=id==103
  return {name=info[id].leaderName,classFilename=mage and "MAGE" or "DRUID",level=42,
    assignedRole=mage and "DAMAGER" or "HEALER",lfgRoles={healer=not mage,dps=mage}}
end
local tankRemaining=1
C_LFGList.GetSearchResultMemberCounts=function()
  return {TANK=1,HEALER=1,DAMAGER=2,TANK_REMAINING=tankRemaining,HEALER_REMAINING=0,DAMAGER_REMAINING=1}
end
addon:LFG_API_ClearCaches("search")
local root=frame(UIParent)
addon.GetLFGRootFrame=function() return root end
local panel=addon:LFGFilters_CreatePanel(root)
panel:Show()
local screenWidth,screenHeight=UIParent:GetWidth(),UIParent:GetHeight()
UIParent:SetHeight(540)
eventFrame.scripts.OnEvent(eventFrame,"DISPLAY_SIZE_CHANGED")
check("the filter panel fits a short display without shrinking game fonts",panel.scale==1 and panel:GetHeight()==508 and panel.ggContentScroll~=nil)
local previousHeight=panel:GetHeight()
local savedSearch=addon.ForeverSearch
addon.ForeverSearch={}
InCombatLockdown=function() return true end
UIParent:SetHeight(400)
eventFrame.scripts.OnEvent(eventFrame,"UI_SCALE_CHANGED")
check("protected filter-panel layout is deferred in combat",panel:GetHeight()==previousHeight)
InCombatLockdown=function() return false end
addon:LFGFilters_ApplyDeferredPanel()
check("panel resizing is applied after combat",panel:GetHeight()<previousHeight and panel.scale==1)
addon.ForeverSearch=savedSearch
UIParent:SetSize(screenWidth,screenHeight)
addon:LFGFilters_LayoutPanel()
check("normal displays restore the panel's intended size",panel.scale==1 and panel:GetHeight()==640)
addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)
UIParent:Hide()
check("addon results follow the game's hidden HUD",not own:IsVisible())
UIParent:Show()
check("restoring the game HUD restores the addon view",own:IsVisible())
local groupsHelp,playersHelp=false,false
for _,region in ipairs(panel.ggContent.ggRegions) do
  if region.text=="LFG_FILTERS_GROUP_HELP_FOREVER" then groupsHelp=true end
  if region.text=="LFG_FILTERS_PLAYER_HELP_FOREVER" then playersHelp=true end
end
check("Forever panel explains the selected result-category behavior",groupsHelp and playersHelp)
local function flush()
  local batch=queue;queue={}
  for _,fn in ipairs(batch) do fn() end
end
local function control(label,nth)
  local found=0
  for _,child in ipairs(panel.ggContent.ggChildren) do
    if child.ggLabel and child.ggLabel.text==label then
      found=found+1; if found==(nth or 1) then return child end
    end
  end
  error("Missing real filter control: "..label)
end
local function click(child,value)
  child:SetChecked(value)
  child.scripts.OnClick(child)
  flush()
end
local function visible()
  local ids={}
  own.ScrollBox:ForEachFrame(function(row) if row.resultID then ids[#ids+1]=row.resultID end end)
  table.sort(ids)
  return table.concat(ids,",")
end
local mage=control("Mage")
check("filter clicks target a visible panel control",mage:IsVisible())
click(mage,true)
check("checking a class enables filtering and shows only matching solo players",addon.db.lfg_filters_enabled==true and visible()=="103")
check("filter panel reports the actual filtered/native count",panel.ggStatus.text:find("1/3",1,true)~=nil)
click(mage,false)
check("unchecking a class restores omitted rows without a server search",visible()=="101,102,103")
local healer=control("LFG_FILTER_HEALER",3)
click(healer,true)
check("solo role checkbox shows only matching solo players",visible()=="101")
click(healer,false)
local needsTank=control("LFG_FILTER_TANK",1)
click(needsTank,true)
check("Needs Tank shows only groups with an available tank slot",visible()=="102")
tankRemaining=0
eventFrame.scripts.OnEvent(eventFrame,"LFG_LIST_SEARCH_RESULT_UPDATED",102)
flush()
check("a group disappears as soon as the selected role fills",visible()=="")
tankRemaining=1
eventFrame.scripts.OnEvent(eventFrame,"LFG_LIST_SEARCH_RESULT_UPDATED",102)
flush()
check("a group returns when the selected role becomes needed again",visible()=="102")
local publicCounts=C_LFGList.GetSearchResultMemberCounts
C_LFGList.GetSearchResultMemberCounts=function() return {} end
eventFrame.scripts.OnEvent(eventFrame,"LFG_LIST_SEARCH_RESULT_UPDATED",102)
flush()
check("a group with unavailable required composition is not treated as a match",visible()=="")
C_LFGList.GetSearchResultMemberCounts=publicCounts
eventFrame.scripts.OnEvent(eventFrame,"LFG_LIST_SEARCH_RESULT_UPDATED",102)
flush()
check("matching groups return after composition data becomes readable",visible()=="102")
click(needsTank,false)
local hasHealer=control("LFG_FILTER_HEALER",2)
click(hasHealer,true)
check("Already has Healer shows only groups with that composition",visible()=="102")
click(control("Mage"),true)
check("both active sections show matching groups plus matching players",visible()=="102,103")
click(healer,true)
check("player class and role must match together while group conditions remain separate",visible()=="102")
click(control("Mage"),false)
check("both active sections keep a matching healer and a matching group",visible()=="101,102")
click(healer,false)
tankRemaining=0
click(needsTank,true)
check("needs and already-has conditions must both match",visible()=="")
click(needsTank,false)
click(hasHealer,false)
panel.ggMinLevelBox:SetText("40")
panel.ggMinLevelBox.scripts.OnEnterPressed(panel.ggMinLevelBox)
flush()
check("level-only conditions show matching players and omit groups",visible()=="101,103")
panel.ggMinLevelBox:SetText("43")
panel.ggMinLevelBox.scripts.OnEnterPressed(panel.ggMinLevelBox)
flush()
check("a level bound with no matching players shows an empty list",visible()=="")
panel.ggMinLevelBox:SetText("")
panel.ggMinLevelBox.scripts.OnEditFocusLost(panel.ggMinLevelBox)
flush()
check("clearing the level bound restores solo players",visible()=="101,102,103")
local header=own.ScrollBox.rows[1]
header.scripts.OnClick(header,"LeftButton")
check("category click updates displayed rows immediately",visible()=="101,103")
header=own.ScrollBox.rows[1]
header.scripts.OnClick(header,"LeftButton")
check("expanding the category restores matching group rows",visible()=="101,102,103")
local rowCount=#own.ScrollBox.rowPool
for _=1,5 do click(control("Mage"),true); click(control("Mage"),false) end
check("repeated filtering reuses the existing row pool",#own.ScrollBox.rowPool==rowCount and visible()=="101,102,103")
print("--- Recover hidden presentations without a native UpdateResults post-hook ---")
local requestRefresh=addon.RequestLFGRefresh
addon.RequestLFGRefresh=function() end
click(control("Mage"),true)
addon:ForeverBrowse_Hide("search in progress")
eventFrame.scripts.OnEvent(eventFrame,"LFG_LIST_SEARCH_RESULTS_RECEIVED")
flush()
check("search response restores matching rows even when the native post-hook never runs",own:IsShown() and visible()=="103")
addon:ForeverBrowse_Hide("browse hidden")
eventFrame.scripts.OnEvent(eventFrame,"LFG_LIST_SEARCH_RESULT_UPDATED",103)
flush()
check("an unchanged result restores a hidden filtered view",own:IsShown() and visible()=="103")
local previousProvider=own.ScrollBox._ggDataProvider
own.ScrollBox._ggDataProvider=nil
eventFrame.scripts.OnEvent(eventFrame,"LFG_LIST_SEARCH_RESULT_UPDATED",103)
flush()
check("an unchanged result restores a missing provider",own.ScrollBox:GetDataProvider()~=nil and own.ScrollBox:GetDataProvider()~=previousProvider and visible()=="103")
panel.ggMinLevelBox:SetText("50")
panel.ggMinLevelBox.scripts.OnEnterPressed(panel.ggMinLevelBox)
flush()
addon:ForeverBrowse_Hide("search in progress")
eventFrame.scripts.OnEvent(eventFrame,"LFG_LIST_SEARCH_RESULTS_RECEIVED")
flush()
check("a response with zero level matches restores the empty overlay instead of native rows",own:IsShown() and own.Empty:IsShown() and visible()=="" and addon:LFGFilters_GetForeverVisibleCount()==0)
addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)
LFGBrowseFrame.searchFailed=true
eventFrame.scripts.OnEvent(eventFrame,"LFG_LIST_SEARCH_FAILED")
flush()
check("search failure hides the addon list even without a native post-hook",not own:IsShown() and addon:LFGFilters_GetForeverVisibleCount()==nil)
LFGBrowseFrame.searchFailed=false
eventFrame.scripts.OnEvent(eventFrame,"LFG_LIST_SEARCH_RESULTS_RECEIVED")
flush()
check("a later successful search restores the filtered empty state",own:IsShown() and own.Empty:IsShown())
local debugLines={}
local originalPrint=print
print=function(...)
  local line={}
  for index=1,select("#",...) do line[#line+1]=tostring(select(index,...)) end
  debugLines[#debugLines+1]=table.concat(line," ")
end
addon:LFGFilters_DebugDump(1)
addon:ForeverBrowse_Hide("browse hidden")
addon:LFGFilters_DebugDump(1)
print=originalPrint
local debugText=table.concat(debugLines,"\n")
check("debug separates current matches, unreadable presentation counts and player levels",debugText:find("matchingNow= 0",1,true) and debugText:find("shownCount= unavailable",1,true) and debugText:find("level=42",1,true) and debugText:find("hiddenReason= browse hidden",1,true))
LFGBrowseFrame:Hide()
eventFrame.scripts.OnEvent(eventFrame,"LFG_LIST_SEARCH_RESULTS_RECEIVED")
flush()
check("a response while Browse is closed is deferred",addon._ggForeverRefreshPending==true)
LFGBrowseFrame:Show()
addon:LFGFilters_ScheduleForeverPresentation(LFGBrowseFrame)
flush()
panel.ggMinLevelBox:SetText("")
panel.ggMinLevelBox.scripts.OnEditFocusLost(panel.ggMinLevelBox)
flush()
click(control("Mage"),false)
addon.RequestLFGRefresh=requestRefresh
LFGBrowseFrame.ScrollBox:SetFrameLevel(200)
click(control("Mage"),true)
local strataRank={BACKGROUND=1,LOW=2,MEDIUM=3,HIGH=4,DIALOG=5,FULLSCREEN=6,FULLSCREEN_DIALOG=7,TOOLTIP=8}
local function above(front,back)
  local first,last=strataRank[front:GetFrameStrata()],strataRank[back:GetFrameStrata()]
  return first>last or (first==last and front:GetFrameLevel()>back:GetFrameLevel())
end
check("reopened native panels cannot cover the filtered list",above(own,LFGBrowseFrame.ScrollBox))
print("--- Visible filtered counts with the native list in a higher rendering stratum ---")
LFGBrowseFrame.strata="MEDIUM"
LFGBrowseFrame.ScrollBox.strata="HIGH"
addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)
check("the native list cannot cover a current filtered provider in a lower Browse stratum",addon:LFGFilters_GetForeverVisibleCount()==1 and visible()=="103" and above(own,LFGBrowseFrame.ScrollBox))
local nativeStrata=LFGBrowseFrame.GetFrameStrata
local nativeLevel=LFGBrowseFrame.ScrollBox.GetFrameLevel
local layerReads=0
LFGBrowseFrame.GetFrameStrata=function() layerReads=layerReads+1; return secret end
LFGBrowseFrame.ScrollBox.GetFrameLevel=function() layerReads=layerReads+1; return secret end
addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)
check("secret native strata and levels do not determine addon layering",layerReads==0 and own:GetFrameStrata()=="DIALOG" and own:GetFrameLevel()==100)
check("owned scroll content and pooled rows stay above the native list",own.ScrollBox:GetFrameStrata()=="DIALOG" and own.ScrollBox:GetFrameLevel()>own:GetFrameLevel() and find(103):GetFrameStrata()=="DIALOG" and find(103):GetFrameLevel()>own.ScrollBox:GetFrameLevel())
check("blank list space, scroll content and rows consume native hover and clicks",own.mouseEnabled and own.motionEnabled and own.propagateMotion==false and own.propagateClicks==false and own.ScrollBox.motionEnabled and own.ScrollBox.propagateMotion==false and find(103).motionEnabled and find(103).propagateClicks==false)
check("the scrollbar shield blocks native hover",own.NativeBarMask.motionEnabled and own.NativeBarMask.propagateMotion==false)
check("the filter panel remains above the owned results",panel:GetFrameStrata()=="DIALOG" and panel:GetFrameLevel()>own.ScrollBox:GetFrameLevel())
local oldOffset=own.ScrollBox:GetVerticalScroll()
local oldRange=own.ScrollBox.GetVerticalScrollRange
own.ScrollBox.GetVerticalScrollRange=function() return 100 end
if own.scripts.OnMouseWheel then own.scripts.OnMouseWheel(own,-1) end
check("wheel input over blank list space scrolls the addon list",own.ScrollBox:GetVerticalScroll()>oldOffset and nativeWrites==0)
own.ScrollBox.GetVerticalScrollRange=oldRange
LFGBrowseFrame.GetFrameStrata=nativeStrata
LFGBrowseFrame.ScrollBox.GetFrameLevel=nativeLevel
LFGBrowseFrame.ScrollBox.strata=nil
check("layer isolation leaves native rows and providers untouched",nativeWrites==0 and nativeRebuilds==0)
click(control("Mage"),false)
local savedGet=addon.ForeverBrowse_GetScrollBox
addon.ForeverBrowse_GetScrollBox=function() error("view initialization failed") end
click(control("Mage"),true)
check("a view initialization failure appears in panel status",addon._ggForeverPresentationError~=nil and panel.ggStatus.text=="LFG_FILTERS_RENDER_FAILED" and not own:IsShown())
addon.ForeverBrowse_GetScrollBox=savedGet
click(control("Mage"),false)
check("a later successful click recovers the view and clears the error",addon._ggForeverPresentationError==nil and own:IsShown() and visible()=="101,102,103")
addon.ForeverBrowse_GetScrollBox=function() error("temporary view failure") end
click(control("Mage"),true)
click(control("LFG_FILTERS_SOCIAL_FIRST"),false)
click(control("Mage"),false)
check("disabling all presentation clears an obsolete render error",addon._ggForeverPresentationError==nil and not own:IsShown())
addon.ForeverBrowse_GetScrollBox=savedGet
check("real checkbox and level controls never alter native state",nativeWrites==0 and nativeRebuilds==0)
local retailTooltips=0
addon.IsForeverClient=function() return false end
addon._lfgCurrentSearchTooltip=GameTooltip
addon._lfgCurrentSearchResultID=101
GameTooltip:Show()
LFGListUtil_SetSearchEntryTooltip=function(tooltip,id) assert(tooltip==GameTooltip and id==101); retailTooltips=retailTooltips+1 end
check("Retail tooltip refresh retains its normal renderer",addon:LFG_RefreshCurrentSearchTooltip(101) and retailTooltips==1)
addon._ggTooltipModifierFrame.scripts.OnEvent(nil,"MODIFIER_STATE_CHANGED","RSHIFT")
check("Retail Shift tooltip refresh is preserved",retailTooltips==2)
print(string.format("Forever browse isolation: %d passed, %d failed",passed,failed))
os.exit(failed==0 and 0 or 1)
