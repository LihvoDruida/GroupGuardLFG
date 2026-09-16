local addonName, addon = ...

-- Raid-only guard for Blizzard's stock death dialog.
--
-- The important rule here is isolation: StaticPopup buttons are reused by many
-- Blizzard dialogs (Accept, Ready Check, confirmations, etc.). Never hook or
-- permanently change button Enable/SetEnabled methods. We only disable button1
-- while the currently shown popup is exactly DEATH and the player is in a raid,
-- then restore only state that this module itself changed.

local DeathGuard = addon.DeathGuard or {}
addon.DeathGuard = DeathGuard

DeathGuard.MESSAGE = "Don't push the horses )))"
DeathGuard.UPDATE_INTERVAL = 0.15

local popupLabels = setmetatable({}, { __mode = "k" })
local hookedPopups = setmetatable({}, { __mode = "k" })
local popupElapsed = setmetatable({}, { __mode = "k" })
local buttonState = setmetatable({}, { __mode = "k" })

local function SafeObjectMethod(object, methodName)
  if addon.SafeObjectMethod then
    return addon:SafeObjectMethod(object, methodName)
  end
  if object == nil or type(methodName) ~= "string" then return nil end
  local ok, method = pcall(function() return object[methodName] end)
  return (ok and type(method) == "function") and method or nil
end

local function SafeField(object, key)
  if addon.SafeObjectField then
    return addon:SafeObjectField(object, key)
  end
  if object == nil then return nil end
  local ok, value = pcall(function() return object[key] end)
  return ok and value or nil
end

local function IsShown(frame)
  local method = SafeObjectMethod(frame, "IsShown")
  if not method then return true end
  local ok, shown = pcall(method, frame)
  return ok and shown == true
end

local function IsEnabled(button)
  local method = SafeObjectMethod(button, "IsEnabled")
  if not method then return nil end
  local ok, enabled = pcall(method, button)
  if not ok then return nil end
  return enabled == true
end

function DeathGuard:IsRaidActive()
  if addon.Safe and type(addon.Safe.IsInRaid) == "function" then
    return addon.Safe.IsInRaid() == true
  end
  if type(IsInRaid) ~= "function" then return false end
  local ok, inRaid = pcall(IsInRaid)
  return ok and inRaid == true
end

function DeathGuard:IsDeathPopup(popup)
  if popup == nil then return false end
  local which = SafeField(popup, "which")
  return which == "DEATH" and IsShown(popup)
end

function DeathGuard:GetReleaseButton(popup)
  if popup == nil then return nil end
  return SafeField(popup, "button1")
end

-- Disable only when we can prove the button is currently enabled. This lets us
-- remember that *we* changed the state and safely restore it when the DEATH
-- popup is hidden/reused. If Blizzard already has the button disabled for its
-- own timer, we leave that state owned by Blizzard.
function DeathGuard:DisableReleaseButton(popup)
  if not self:IsRaidActive() or not self:IsDeathPopup(popup) then return false end

  local button = self:GetReleaseButton(popup)
  if not button then return false end

  local enabled = IsEnabled(button)
  if enabled ~= true then return false end

  local disable = SafeObjectMethod(button, "Disable")
  if not disable then return false end

  local ok = pcall(disable, button)
  if ok then
    buttonState[button] = true
    return true
  end
  return false
end

-- Restore only a state that DeathGuard itself disabled. This is the key that
-- prevents shared StaticPopup button1 from staying disabled when Blizzard
-- reuses the frame for an ACCEPT/OK/confirmation dialog.
function DeathGuard:RestoreReleaseButton(popup)
  local button = self:GetReleaseButton(popup)
  if not button or buttonState[button] ~= true then return false end

  buttonState[button] = nil
  local enable = SafeObjectMethod(button, "Enable")
  if not enable then return false end
  return pcall(enable, button)
end

function DeathGuard:EnsureMessage(popup)
  if not self:IsRaidActive() or not self:IsDeathPopup(popup) then return nil end

  local label = popupLabels[popup]
  if not label then
    local createFontString = SafeObjectMethod(popup, "CreateFontString")
    if not createFontString then return nil end

    local ok, created = pcall(createFontString, popup, nil, "OVERLAY", "GameFontNormalSmall")
    if not ok or not created then return nil end
    label = created
    popupLabels[popup] = label

    local clearAllPoints = SafeObjectMethod(label, "ClearAllPoints")
    if clearAllPoints then pcall(clearAllPoints, label) end

    local setPoint = SafeObjectMethod(label, "SetPoint")
    if setPoint then
      pcall(setPoint, label, "BOTTOMLEFT", popup, "BOTTOMLEFT", 18, 34)
      pcall(setPoint, label, "BOTTOMRIGHT", popup, "BOTTOMRIGHT", -18, 34)
    end

    local setJustifyH = SafeObjectMethod(label, "SetJustifyH")
    if setJustifyH then pcall(setJustifyH, label, "CENTER") end

    local setTextColor = SafeObjectMethod(label, "SetTextColor")
    if setTextColor then pcall(setTextColor, label, 1.0, 0.82, 0.0, 1.0) end
  end

  local setText = SafeObjectMethod(label, "SetText")
  if setText then pcall(setText, label, self.MESSAGE) end

  local show = SafeObjectMethod(label, "Show")
  if show then pcall(show, label) end
  return label
end

function DeathGuard:HideMessage(popup)
  local label = popup and popupLabels[popup] or nil
  if not label then return end
  local hide = SafeObjectMethod(label, "Hide")
  if hide then pcall(hide, label) end
end

function DeathGuard:CleanupPopup(popup)
  if popup == nil then return end
  self:HideMessage(popup)
  self:RestoreReleaseButton(popup)
  popupElapsed[popup] = nil
end

function DeathGuard:HookPopup(popup)
  if popup == nil or hookedPopups[popup] then return end
  hookedPopups[popup] = true

  local hookScript = SafeObjectMethod(popup, "HookScript")
  if not hookScript then return end

  -- StaticPopup frames are reused. OnShow must validate the current `which`
  -- every time; never assume the frame is still the DEATH popup.
  pcall(hookScript, popup, "OnShow", function(self)
    popupElapsed[self] = 0
    if DeathGuard:IsDeathPopup(self) and DeathGuard:IsRaidActive() then
      DeathGuard:Apply(self)
    else
      DeathGuard:CleanupPopup(self)
    end
  end)

  -- Blizzard can enable Release Spirit when its internal timer expires. Polling
  -- the active DEATH popup avoids method hooks on the shared button, so Accept
  -- and every other StaticPopup button remain untouched.
  pcall(hookScript, popup, "OnUpdate", function(self, elapsed)
    if not DeathGuard:IsDeathPopup(self) or not DeathGuard:IsRaidActive() then
      return
    end

    local total = (popupElapsed[self] or 0) + (tonumber(elapsed) or 0)
    if total < DeathGuard.UPDATE_INTERVAL then
      popupElapsed[self] = total
      return
    end
    popupElapsed[self] = 0

    DeathGuard:DisableReleaseButton(self)
    DeathGuard:EnsureMessage(self)
  end)

  pcall(hookScript, popup, "OnHide", function(self)
    DeathGuard:CleanupPopup(self)
  end)
end

function DeathGuard:Apply(popup)
  if popup == nil then return false end

  self:HookPopup(popup)

  if not self:IsDeathPopup(popup) then
    self:CleanupPopup(popup)
    return false
  end

  if not self:IsRaidActive() then
    self:CleanupPopup(popup)
    return false
  end

  local disabled = self:DisableReleaseButton(popup)
  self:EnsureMessage(popup)
  return disabled
end

function DeathGuard:FindDeathPopup()
  local count = tonumber(STATICPOPUP_NUMDIALOGS) or 4
  for i = 1, count do
    local popup = _G["StaticPopup" .. i]
    if popup and self:IsDeathPopup(popup) then
      return popup
    end
  end
  return nil
end

function DeathGuard:CleanupAllPopups()
  local count = tonumber(STATICPOPUP_NUMDIALOGS) or 4
  for i = 1, count do
    local popup = _G["StaticPopup" .. i]
    if popup then self:CleanupPopup(popup) end
  end

  -- Also clean labels created on mock/dynamically supplied popup objects that
  -- are not reachable through StaticPopup1..N.
  for popup in pairs(popupLabels) do
    self:CleanupPopup(popup)
  end
end

function DeathGuard:Refresh()
  local popup = self:FindDeathPopup()
  if popup and self:IsRaidActive() then
    self:Apply(popup)
    return
  end

  -- If the player leaves the raid or the shared frame changes to another
  -- dialog, remove only DeathGuard-owned state immediately.
  self:CleanupAllPopups()
end

local function ScheduleRefresh()
  if C_Timer and type(C_Timer.After) == "function" then
    pcall(C_Timer.After, 0, function() DeathGuard:Refresh() end)
  else
    DeathGuard:Refresh()
  end
end

if type(StaticPopup_Show) == "function" and type(hooksecurefunc) == "function" then
  pcall(hooksecurefunc, "StaticPopup_Show", function(which)
    if which == "DEATH" then
      DeathGuard:Refresh()
      ScheduleRefresh()
    else
      -- Shared StaticPopup frames can be recycled immediately after DEATH.
      -- Cleanup ensures button1 never leaks a disabled state into Accept/OK.
      DeathGuard:CleanupAllPopups()
    end
  end)
end

local eventFrame = CreateFrame and CreateFrame("Frame") or nil
if eventFrame then
  local registerEvent = SafeObjectMethod(eventFrame, "RegisterEvent")
  if registerEvent then
    pcall(registerEvent, eventFrame, "PLAYER_DEAD")
    pcall(registerEvent, eventFrame, "PLAYER_ALIVE")
    pcall(registerEvent, eventFrame, "PLAYER_UNGHOST")
    pcall(registerEvent, eventFrame, "GROUP_ROSTER_UPDATE")
  end

  local setScript = SafeObjectMethod(eventFrame, "SetScript")
  if setScript then
    pcall(setScript, eventFrame, "OnEvent", function(_, event)
      if event == "PLAYER_DEAD" or event == "GROUP_ROSTER_UPDATE" then
        ScheduleRefresh()
      elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        DeathGuard:CleanupAllPopups()
      end
    end)
  end
end
