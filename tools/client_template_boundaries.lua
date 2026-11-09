-- Explicit offline boundaries: XML instantiation, frame pools and native C
-- ScrollBox layout. The view, callbacks, provider and display helpers are real
-- client Lua. This file does not emulate WoW's renderer or security engine.
local function split(value) local out={}; for v in (value or ""):gmatch("[^, ]+") do out[#out+1]=v end; return out end
local function createRegion(parent, spec)
  local key=spec.attrs.parentKey
  local region=key and parent[key]
  if not region then region=CreateFrame(spec.kind,nil,parent); if key then parent[key]=region end end
  if spec.attrs.parentArray then parent[spec.attrs.parentArray]=parent[spec.attrs.parentArray] or {}; table.insert(parent[spec.attrs.parentArray],region) end
  PROBE_APPLY_SPEC(region,spec)
end
function PROBE_APPLY_SPEC(f,spec)
  for _,base in ipairs(split(spec.attrs.inherits)) do PROBE_APPLY_TEMPLATE(f,base) end
  if spec.width then f.width=spec.width end; if spec.height then f.height=spec.height end
  if spec.kind=="FontString" then f.font=true; f.fontObject=spec.attrs.inherits end
  if spec.attrs.atlas then f.atlas=spec.attrs.atlas end
  if spec.attrs.file then f.texture=spec.attrs.file end
  if spec.attrs.hidden then f.shown=spec.attrs.hidden~="true" end
  if spec.attrs.clipChildren then f.clipChildren=spec.attrs.clipChildren=="true" end
  f.xmlPoints=spec.points
  for _,kv in ipairs(spec.keys) do
    local value=kv.value
    if kv.type=="number" then value=tonumber(value) elseif kv.type=="boolean" then value=value=="true" elseif kv.type=="global" then value=_G[value] end
    f[kv.key]=value
  end
  for _,child in ipairs(spec.children) do createRegion(f,child) end
  if spec.scripts then
    for event,attrs in pairs(spec.scripts) do
      if attrs["function"] and type(_G[attrs["function"]])=="function" then
        f.scripts[event]=_G[attrs["function"]]
      end
    end
  end
end
local function templateInfo(name)
  local spec=XML_SPECS[name]; if not spec then return nil end
  local info={type=spec.kind,width=spec.width,height=spec.height}
  for _,base in ipairs(split(spec.attrs.inherits)) do
    local inherited=templateInfo(base)
    if inherited then info.width=info.width or inherited.width;info.height=info.height or inherited.height end
  end
  return info
end
C_XMLUtil={GetTemplateInfo=templateInfo}
function CreateFramePoolCollection()
  local collection={pools={}}
  function collection:GetOrCreatePool(kind,parent,template)
    if self.pools[template] then return self.pools[template] end
    local pool={active={},free={}}
    function pool:Acquire()
      local frame=table.remove(self.free)
      local new=frame==nil
      frame=frame or CreateFrame(kind,nil,parent,template)
      self.active[frame]=true
      return frame,new
    end
    function pool:Release(frame) if self.active[frame] then self.active[frame]=nil;frame:Hide();self.free[#self.free+1]=frame end end
    function pool:ReleaseAll() local active={};for f in pairs(self.active) do active[#active+1]=f end;for _,f in ipairs(active) do self:Release(f) end end
    self.pools[template]=pool
    return pool
  end
  function collection:ReleaseAll() for _,p in pairs(self.pools) do p:ReleaseAll() end end
  function collection:Release(frame) for _,p in pairs(self.pools) do p:Release(frame) end end
  function collection:GetNumActive() local n=0;for _,p in pairs(self.pools) do for _ in pairs(p.active) do n=n+1 end end;return n end
  return collection
end
function CreateAndInitFromMixin(mixin,...) local v=CreateFromMixins(mixin);v:Init(...);return v end
BaseScrollBoxEvents={OnScroll="OnScroll",OnSizeChanged="OnSizeChanged",OnAllowScrollChanged="OnAllowScrollChanged",OnLayout="OnLayout"}
InputUtil={IsMouseOver=function(row) return row.hovered==true end}
LEVEL_ABBR="Lv"; LFG_SELF_LISTING="Your listing"; LFGBROWSE_ACTIVITY_COUNT="%d activities"; LFGBROWSE_ACTIVITY_MATCHING_COUNT="%d matching activities"
Enum.LFGEntryVoiceMode={None=0,Legacy=1,Discord=2,Custom=3}
LFG_LIST_ENTRY_DELISTED="Delisted"; LFG_LIST_NEW_PLAYER_FRIENDLY_HEADER="New player friendly"
LFG_LIST_COMMENT_FORMAT="%s"; LFG_LIST_TOOLTIP_MEMBERS_SIMPLE="%d members"; LFG_LIST_TOOLTIP_MEMBERS="%d members (%d/%d/%d)"
LFG_LIST_INDENT="  %s"; VOICE_CHAT_MODE_NONE="None"; VOICE_CHAT_MODE_LEGACY="Voice";VOICE_CHAT_MODE_DISCORD="Discord";VOICE_CHAT_MODE_CUSTOM="Custom"
VOICE_CHAT_MODE_FORMAT="Voice: %s";LFG_LIST_BOSSES_DEFEATED="Bosses defeated"
function LFGUtil_GetActivityInfoName(info) return info.fullName or info.shortName end
local extra={"ScrollController.lua","ScrollBoxPadding.lua","ScrollBoxStride.lua","TemplateInfoCache.lua","FrameFactory.lua","ScrollBoxView.lua","ScrollBoxListView.lua","ScrollBoxLinearView.lua","ScrollBoxTreeView.lua"}
for _,file in ipairs(extra) do dofile(CLIENT_SOURCE.."/"..file) end

local function registry(f)
  Mixin(f,CallbackRegistryMixin);CallbackRegistryMixin.OnLoad(f);f:SetUndefinedEventsAllowed(true)
end
local function render(scroll)
  if scroll.rendering or not scroll.view or not scroll.provider then return end
  scroll.rendering=true
  local view=scroll.view
  view.frameFactory:ReleaseAll();view.frames={}
  local extent=0
  for _,node in scroll.provider:Enumerate(nil,nil,TreeDataProviderConstants.ExcludeCollapsed) do
    view.elementFactory(function(template,initializer)
      local frame=view.frameFactory:Create(scroll.ScrollTarget,template)
      view:AssignAccessors(frame,node)
      initializer(frame,node)
      view.frames[#view.frames+1]=frame
      extent=extent+frame:GetHeight()
    end,node)
  end
  scroll.extent=extent
  scroll.rendering=false
  scroll:TriggerEvent(BaseScrollBoxEvents.OnLayout)
end
function PROBE_APPLY_TEMPLATE(f,template)
  if not template then return end
  local spec=XML_SPECS[template]
  if spec then PROBE_APPLY_SPEC(f,spec) end
  if template=="WowScrollBoxList" then
    registry(f)
    f.ScrollTarget=f.ScrollTarget or CreateFrame("Frame",nil,f)
    function f:Init(view)
      self.view=view;view:SetScrollBox(self)
      view:RegisterCallback(ScrollBoxListViewMixin.Event.OnDataChanged,function() render(self) end,self)
    end
    function f:GetView() return self.view end
    function f:GetScrollTarget() return self.ScrollTarget end
    function f:SetDataProvider(provider) self.provider=provider; self.view:SetDataProvider(provider) end
    function f:GetDataProvider() return self.provider end
    function f:ForEachFrame(fn) for _,row in ipairs(self.view and self.view.frames or {}) do if fn(row,row:GetElementData()) then return true end end end
    function f:HasScrollableExtent() return (self.extent or 0)>self:GetHeight() end
    function f:GetVisibleExtentPercentage() return math.min(1,self:GetHeight()/math.max(1,self.extent or 1)) end
    function f:CalculatePanExtentPercentage() return 0.1 end
    function f:CanInterpolateScroll() return false end
    function f:SetInterpolateScroll(v) self.interpolate=v end
    function f:SetScrollAllowed(v) self.allowScroll=v end
    function f:SetScrollPercentage(v) self.percentage=v; self:TriggerEvent(BaseScrollBoxEvents.OnScroll,v,self:GetVisibleExtentPercentage(),0.1) end
    function f:GetScrollPercentage() return self.percentage or 0 end
    function f:FindFrame(node) for _,row in ipairs(self.view.frames) do if row:GetElementData()==node then return row end end end
  elseif template=="MinimalScrollBar" or template=="WowClassicScrollBar" then
    registry(f)
    function f:Init(visible,pan) self.visibleExtent,self.pan=visible,pan end
    function f:CanInterpolateScroll() return false end
    function f:SetInterpolateScroll(v) self.interpolate=v end
    function f:SetScrollPercentage(v) self.percentage=v end
    function f:SetVisibleExtentPercentage(v) self.visibleExtent=v end
    function f:SetPanExtentPercentage(v) self.pan=v end
    function f:SetScrollAllowed(v) self.allowScroll=v end
  end
  if f.scripts.OnLoad and (template=="LFGBrowseSearchEntryTemplate" or template=="LFGBrowseNestedSearchEntryTemplate") then f.scripts.OnLoad(f) end
end
function CreateAnchor(point,x,y)
  return {SetPoint=function(_,frame) frame:SetPoint(point,frame:GetParent(),point,x,y) end}
end
MenuUtil={}
function MenuUtil.CreateContextMenu(owner,generator)
  local root={items={}}
  function root:CreateTitle(text) self.title=text end
  function root:CreateButton(text,fn)
    local item={text=text,callback=fn}; function item:SetEnabled(v) self.enabled=v end
    self.items[#self.items+1]=item;return item
  end
  generator(owner,root)
  MenuUtil.owner,MenuUtil.root=owner,root
  function root:Close() if MenuUtil.root==self then MenuUtil.owner,MenuUtil.root=nil,nil end end
  return root
end
