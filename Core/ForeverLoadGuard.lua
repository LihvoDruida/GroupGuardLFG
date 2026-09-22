local addonName, addon = ...

-- WoW Forever 1.60.x has a Blizzard load-order edge case inside
-- Blizzard_GroupFinder_VanillaStyle:
--   ParentFrame.lua -> Listing -> Browse -> WhoList
--
-- LFGBrowseMixin:OnLoad() may call LFGParentFrame_SearchActiveEntry() when the
-- player already has an active listing. ParentFrame's local SetActiveTab()
-- unconditionally calls LFGWhoListFrame:SetShown(), but WhoList.xml has not
-- been loaded yet at that point. The result is a Blizzard error during
-- ReloadUI/login and the load-on-demand addon can stop before WhoList exists.
--
-- GroupGuard installs a tiny temporary *Lua object* (not a named Frame) before
-- Blizzard's load-on-demand addon is loaded. It only implements the methods
-- that ParentFrame can touch during this narrow gap. Once Blizzard finishes
-- loading, we rebind the global to the real LFGWhoListFrame created by
-- WhoList.xml. This keeps the workaround Camelot-only and avoids replacing or
-- modifying Blizzard's secure frames/functions.

local BLIZZARD_LFG_ADDON = "Blizzard_GroupFinder_VanillaStyle"
local WHO_FRAME_NAME = "LFGWhoListFrame"

local placeholder = nil

local function IsBlizzardLFGLoaded()
  if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
    local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, BLIZZARD_LFG_ADDON)
    if ok then return loaded == true end
  end
  if type(IsAddOnLoaded) == "function" then
    local ok, loaded = pcall(IsAddOnLoaded, BLIZZARD_LFG_ADDON)
    if ok then return loaded == true end
  end
  return false
end

local function IsFrameObject(value)
  if value == nil or value == placeholder then return false end
  local objectType = type(value.GetObjectType) == "function" and value.GetObjectType or nil
  local getName = type(value.GetName) == "function" and value.GetName or nil
  if not objectType or not getName then return false end

  local okName, name = pcall(getName, value)
  if not okName or name ~= WHO_FRAME_NAME then return false end

  local okType, frameType = pcall(objectType, value)
  return okType and type(frameType) == "string"
end

local function FindRealWhoListFrame()
  local direct = _G[WHO_FRAME_NAME]
  if IsFrameObject(direct) then return direct end
  if type(EnumerateFrames) ~= "function" then return nil end

  local frame = EnumerateFrames()
  local guard = 0
  while frame and guard < 20000 do
    if IsFrameObject(frame) then return frame end
    frame = EnumerateFrames(frame)
    guard = guard + 1
  end
  return nil
end

local function RebindWhoListFrame()
  local direct = _G[WHO_FRAME_NAME]
  if direct ~= placeholder and IsFrameObject(direct) then
    addon._foreverWhoListLoadGuardRecovered = true
    return direct
  end

  local realFrame = FindRealWhoListFrame()
  if not realFrame then return nil end

  _G[WHO_FRAME_NAME] = realFrame
  addon._foreverWhoListLoadGuardRecovered = true

  -- The temporary shim may have received a visibility request while Browse was
  -- loading. Normalize to Blizzard's selected tab after rebinding instead of
  -- replaying a stale intermediate state.
  local parent = _G.LFGParentFrame
  local selectedTab = parent and tonumber(parent.selectedTab) or nil
  if type(realFrame.SetShown) == "function" and selectedTab then
    pcall(realFrame.SetShown, realFrame, selectedTab == 3)
  end

  return realFrame
end

local function InstallPlaceholder()
  if IsBlizzardLFGLoaded() then
    RebindWhoListFrame()
    return false
  end

  local existing = _G[WHO_FRAME_NAME]
  if existing ~= nil then
    -- Never overwrite a real Blizzard frame or another addon's compatibility
    -- object. If Blizzard already created the frame there is nothing to guard.
    return false
  end

  local shim = {
    _groupGuardForeverLoadGuard = true,
    _shown = false,
  }

  function shim:SetShown(shown)
    self._shown = shown == true
  end

  function shim:IsShown()
    return self._shown == true
  end

  function shim:Show()
    self._shown = true
  end

  function shim:Hide()
    self._shown = false
  end

  placeholder = shim
  addon._foreverWhoListLoadGuard = shim
  _G[WHO_FRAME_NAME] = shim
  return true
end

function addon:ForeverLoadGuard_RebindWhoListFrame()
  return RebindWhoListFrame()
end

function addon:ForeverLoadGuard_GetStatus()
  return {
    installed = placeholder ~= nil,
    placeholderActive = placeholder ~= nil and _G[WHO_FRAME_NAME] == placeholder,
    blizzardLoaded = IsBlizzardLFGLoaded(),
    recovered = self._foreverWhoListLoadGuardRecovered == true,
    realFrame = FindRealWhoListFrame() ~= nil,
  }
end

InstallPlaceholder()

-- Register as early as possible in the Camelot TOC so we restore Blizzard's
-- global immediately when its load-on-demand addon finishes.
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, loadedName)
  if event == "ADDON_LOADED" then
    if loadedName ~= BLIZZARD_LFG_ADDON then return end
    if RebindWhoListFrame() then
      self:UnregisterEvent("ADDON_LOADED")
      self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
    return
  end

  -- Recovery path for a session where Blizzard was already partially loaded
  -- before GroupGuard got control. This is normally a no-op.
  if IsBlizzardLFGLoaded() and RebindWhoListFrame() then
    self:UnregisterEvent("ADDON_LOADED")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  end
end)
