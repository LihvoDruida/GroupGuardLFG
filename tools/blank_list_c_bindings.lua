-- Only the C/widget boundary is modeled here. Range calculation, frame
-- acquisition, layout and initialization below run the pinned client Lua.
MathUtil={Epsilon=0.00001}
TextureKitConstants={UseAtlasSize=true}
function Round(v) return math.floor(v+0.5) end
function Saturate(v) return math.max(0,math.min(1,v)) end
function ClampedPercentageBetween(v,a,b) return Saturate((v-a)/(b-a)) end
function ApproximatelyEqual(a,b) return math.abs(a-b)<MathUtil.Epsilon end
function WithinRangeExclusive(v,a,b) return v>a and v<b end
function GenerateClosure(fn,...) local args={...};return function(...) local all={unpack(args)};for i=1,select('#',...) do all[#all+1]=select(i,...) end;return fn(unpack(all)) end end
function tContains(t,v) return table.contains(t,v) end
function tDeleteItem(t,v) return table.removevalue(t,v) end
InputUtil.IsGamepadUIEnabled=function() return false end
dofile(CLIENT_SOURCE..'/ScrollBoxViewUtil.lua')
dofile(CLIENT_SOURCE..'/ScrollBox.lua')
dofile(CLIENT_SOURCE..'/AnchorUtil.lua')

local methods=getmetatable(UIParent).__index
local xy={TOPLEFT={0,1},TOP={.5,1},TOPRIGHT={1,1},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},BOTTOMLEFT={0,0},BOTTOM={.5,0},BOTTOMRIGHT={1,0}}
function methods:GetScript(k) return self.scripts[k] end
function methods:SetPoint(point,relative,relativePoint,x,y)
  if type(relative)=='number' then x,y=relative,relativePoint;relative,relativePoint=self.parent,point
  elseif relative==nil then relative,relativePoint,x,y=self.parent,point,0,0
  elseif type(relativePoint)=='number' then x,y=relativePoint,x;relativePoint=point end
  relative=type(relative)=='string' and _G[relative] or relative
  relative=relative or self.parent;relativePoint=relativePoint or point
  local value={point,relative,relativePoint,x or 0,y or 0}
  for i,p in ipairs(self.points) do if p[1]==point then self.points[i]=value;return end end
  self.points[#self.points+1]=value
end
local function axis(f,dimension,seen)
  if f.font then return dimension=='width' and (f.width or #(f.text or '')*7) or (f.height or 14) end
  seen=seen or {};assert(not seen[f],'cyclic anchors');seen[f]=true
  local index=dimension=='width' and 1 or 2
  local first,firstPart
  for _,p in ipairs(f.points) do
    local relative=p[2]
    if relative then
      local part=xy[p[1]][index]
      local extent=axis(relative,dimension,seen)
      local coordinate=extent*xy[p[3]][index]+p[index+3]
      if firstPart and part~=firstPart then seen[f]=nil;return math.abs((coordinate-first)/(part-firstPart)) end
      first,firstPart=coordinate,part
    end
  end
  seen[f]=nil;return f[dimension] or 0
end
local baseWidth,baseHeight=methods.GetWidth,methods.GetHeight
function methods:GetWidth() if self.font then return baseWidth(self) end;return axis(self,'width') end
function methods:GetHeight() if self.font then return baseHeight(self) end;return axis(self,'height') end
function methods:GetSize() return self:GetWidth(),self:GetHeight() end
function methods:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or 'MEDIUM' end
function methods:GetFrameLevel() return self.level or (self.parent and self.parent:GetFrameLevel()+1) or 0 end
function methods:GetAlpha() return self.alpha or 1 end
function methods:GetEffectiveAlpha() return self:GetAlpha()*(self.parent and self.parent:GetEffectiveAlpha() or 1) end
function methods:SetAlpha(v) self.alpha=v end

local previousTemplate=PROBE_APPLY_TEMPLATE
function PROBE_APPLY_TEMPLATE(f,template)
  if template~='WowScrollBoxList' then return previousTemplate(f,template) end
  PROBE_APPLY_SPEC(f,XML_SPECS[template])
  Mixin(f,ScrollBoxListMixin)
  Mixin(f.ScrollTarget,CallbackRegistryMixin)
  CallbackRegistryMixin.OnLoad(f.ScrollTarget);f.ScrollTarget:SetUndefinedEventsAllowed(true)
  f:OnLoad()
  f:SetScript('OnSizeChanged',f.OnSizeChanged)
end
