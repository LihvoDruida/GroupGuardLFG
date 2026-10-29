-- Passive diagnostics for Forever's Blizzard_GroupFinder_VanillaStyle load order.
-- A Lua placeholder assigned to LFGWhoListFrame taints Blizzard's global and
-- cannot emulate a secure frame. Never replace that global or scan every frame.
local addonName, addon = ...
if not (addon.IsForeverClient and addon:IsForeverClient()) then return end

local function RealWhoFrame()
  local frame = _G.LFGWhoListFrame
  if not addon:SafeCanAccessObject(frame) then return nil end
  local method = addon:SafeObjectMethod(frame, "GetObjectType")
  if not method then return nil end
  local ok, kind = pcall(method, frame)
  if ok and addon:SafeText(kind) then return frame end
end

function addon:ForeverLoadGuard_RebindWhoListFrame()
  -- Retain the diagnostic entrypoint without writing Blizzard state.
  local frame = RealWhoFrame()
  self._foreverWhoListLoadGuardRecovered = frame ~= nil
  return frame
end

function addon:ForeverLoadGuard_GetStatus()
  local fn = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
  local ok, loaded = self:SafeCall(fn, "Blizzard_GroupFinder_VanillaStyle")
  return {
    installed = false, placeholderActive = false, passive = true,
    blizzardLoaded = ok and self:SafeBool(loaded) or false,
    recovered = self._foreverWhoListLoadGuardRecovered == true,
    realFrame = RealWhoFrame() ~= nil,
  }
end

local frame = CreateFrame("Frame")
pcall(frame.RegisterEvent, frame, "ADDON_LOADED")
pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, name)
  if event == "ADDON_LOADED" and name ~= "Blizzard_GroupFinder_VanillaStyle" then return end
  if addon:ForeverLoadGuard_RebindWhoListFrame() then
    self:UnregisterEvent("ADDON_LOADED")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  end
end)
