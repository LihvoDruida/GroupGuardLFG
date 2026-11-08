-- Exercise actual SafeAPI + filter + isolated renderer together. The native
-- provider/selection and every width query are traps, not silent mock no-ops.
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
  function f:GetWidth() error("secret width must never be read or compared") end
  function f:GetStringWidth() error("secret string width must never be read or compared") end
  function f:GetFrameLevel() return 10 end
  function f:GetFrameStrata() return "MEDIUM" end
  function f:SetFrameLevel(v) self.level=v end
  function f:SetFrameStrata(v) self.strata=v end
  function f:EnableMouse() end
  function f:SetColorTexture(...) self.color={...} end
  function f:SetAtlas(v) self.atlas=v end
  function f:SetText(v) self.text=v end
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
  function f:CreateFontString() return frame(self) end
  function f:ForEachFrame(fn) for _,r in ipairs(self.rows) do fn(r) end end
  return f
end
UIParent=frame()
CreateFrame=function(_,_,parent) return frame(parent) end
GetTime=function() return 0 end
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
TreeDataProviderConstants={DoInvalidation=false}
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

local function node(data)
  local n={data=data,children={}}
  function n:Insert(v) local child=node(v); self.children[#self.children+1]=child; return child end
  function n:SetCollapsed(v) self.collapsed=v end
  function n:ToggleCollapsed() self.collapsed=not self.collapsed end
  return n
end
CreateTreeDataProvider=function() return node() end
CreateScrollBoxListTreeListView=function()
  return {SetElementFactory=function(self,fn) self.factory=fn end,SetElementExtent=function() end}
end
ScrollUtil={InitScrollBoxListWithScrollBar=function(scroll,bar,view)
  scroll.view,scroll.bar=view,bar
  function scroll:GetDataProvider() return self.provider end
  function scroll:SetDataProvider(provider,retain)
    self.provider,self.retain=provider,retain
    self.rows={}
    local function render(n)
      if n.data then
        view.factory(function(template,init)
          assert(template=="GroupGuardLFGBrowseRowTemplate", "native LFG row template must never be used")
          local row=frame(self); self.rows[#self.rows+1]=row; init(row,n)
        end,n)
      end
      if not n.collapsed then for _,child in ipairs(n.children) do render(child) end end
    end
    render(provider)
  end
end}

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
local addon={db={lfg_filters_enabled=true,lfg_filter_player_classes={DRUID=true},lfg_filter_social_priority=true},
  IsForeverClient=function() return true end,HasClientCapability=function() return true end,Tr=function(_,key) return key end}
for _,path in ipairs({"Core/SafeAPI.lua","Modules/ForeverBrowse.lua","Modules/LFGFilters.lua"}) do
  assert(loadfile("../"..path))("GroupGuardLFG",addon)
end
local results=LFGBrowseFrame.results
local ok,err=pcall(function() return addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame) end)
check("real filter and renderer initialize without measuring text",ok)
if not ok then error(err) end
local own=addon._ggForeverBrowseView
check("addon presentation is rooted under UIParent",own.parent==UIParent)
check("own provider is installed on a separate ScrollBox",own.ScrollBox.provider~=nil and own.ScrollBox~=LFGBrowseFrame.ScrollBox)
check("native provider, rows and selection never mutated",nativeWrites==0 and nativeRebuilds==0)
check("native result identity and total are preserved",LFGBrowseFrame.results==results and LFGBrowseFrame.totalResults==3)
check("nonmatching solo player omitted without a blank row",addon._ggForeverVisibleResults==2 and #own.ScrollBox.rows==4)
check("scroll retention is requested on the addon provider",own.ScrollBox.retain==true)
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
local group=find(102)
group.scripts.OnClick(group,"LeftButton")
check("group selection enables whisper but disables invite",own.MessageButton.enabled and not own.InviteButton.enabled)
local groupHeader=own.ScrollBox.rows[1]
groupHeader.scripts.OnClick(groupHeader,"LeftButton")
addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)
check("category collapse survives provider rebuild",own.ScrollBox.provider.children[1].collapsed==true and #own.ScrollBox.rows==3)

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
check("missing view support never falls back to the native provider",addon:LFGFilters_ApplyForeverPresentation(LFGBrowseFrame)==false and nativeWrites==0)
ScrollUtil=previousUtil
addon._ggForeverBrowseView=previousView
check("all paths leave native provider untouched",nativeWrites==0 and nativeRebuilds==0)
print(string.format("Forever browse isolation: %d passed, %d failed",passed,failed))
os.exit(failed==0 and 0 or 1)
