-- Minimal WoW-ish environment: enough to load the addon files and exercise
-- the code paths that were reported as broken.
local mock = {}

local function stubFrame(name)
  local f = {}
  f._points, f._shown, f._w, f._h = {}, true, 100, 20
  function f:SetPoint(...) self._points[#self._points+1] = {...} end
  function f:ClearAllPoints() self._points = {} end
  function f:GetNumPoints() return #self._points end
  function f:GetPoint(i)
    local p = self._points[i]
    if not p then return nil end
    return p[1], p[2], p[3], p[4] or 0, p[5] or 0
  end
  function f:SetWidth(v) self._w = v end
  function f:SetHeight(v) self._h = v end
  function f:SetSize(w,h) self._w, self._h = w, h end
  function f:GetWidth() return self._w end
  function f:GetHeight() return self._h end
  function f:GetLeft() return 0 end
  function f:GetRight() return self._w end
  function f:Show() self._shown = true end
  function f:Hide() self._shown = false end
  function f:IsShown() return self._shown end
  function f:IsVisible() return self._shown end
  function f:SetScript() end
  function f:HookScript() end
  function f:RegisterEvent() end
  function f:UnregisterEvent() end
  function f:CreateFontString() return stubFrame() end
  function f:CreateTexture() return stubFrame() end
  function f:SetText() end
  function f:GetText() return "" end
  function f:SetJustifyH() end
  function f:SetTextColor() end
  function f:GetObjectType() return "Frame" end
  function f:SetBackdrop() end
  function f:SetMouseClickEnabled() end
  function f:SetMouseMotionEnabled() end
  function f:EnableMouse() end
  function f:GetFontString() return nil end
  -- catch-all: any widget method we did not model returns a harmless stub
  setmetatable(f, { __index = function(t, k)
    -- Unknown keys behave as both a callable method and a child widget,
    -- which is what addon code expects from Blizzard frame members.
    local child
    child = setmetatable({}, {
      __call = function(_, ...) return nil end,
      __index = function(_, k2) return stubFrame()[k2] end,
      __newindex = function(t2, k2, v2) rawset(t2, k2, v2) end,
    })
    rawset(t, k, child)
    return child
  end })
  return f
end
mock.stubFrame = stubFrame
return mock
