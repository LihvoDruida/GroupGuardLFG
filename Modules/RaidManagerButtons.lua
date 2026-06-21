-- GroupGuard LFG — Raid manager integration
local addonName, addon = ...

local C_Timer = C_Timer

local retryCount = 0
local MAX_RETRIES = 10
local refreshScheduled = false

local function IsEnabled()
  if addon and addon.EnsureDB and not addon.db then addon:EnsureDB() end
  return not addon.db or addon.db.raid_manager_pug_button ~= false
end

local function IsRaidManagerAvailable()
  return _G.CompactRaidFrameManager or _G.CompactRaidFrameManagerDisplayFrame
end

local function IsRaidGroup()
  if type(IsInRaid) ~= "function" then return false end
  local ok, value = pcall(IsInRaid)
  return ok and value and true or false
end

local function SafeCall(frame, method, ...)
  if not frame or type(frame[method]) ~= "function" then return nil end
  local ok, value = pcall(frame[method], frame, ...)
  if ok then return value end
  return nil
end

local function SafeNumber(frame, method, fallback)
  local value = SafeCall(frame, method)
  value = tonumber(value)
  if value then return value end
  return fallback or 0
end

local function GetButtonText(button)
  if not button then return nil end
  local text = SafeCall(button, "GetText")
  if type(text) == "string" and text ~= "" then return text end

  local fontString = button.Text or button.text or button.label
  if fontString and type(fontString.GetText) == "function" then
    local ok, value = pcall(fontString.GetText, fontString)
    if ok and type(value) == "string" and value ~= "" then return value end
  end

  return nil
end

local function LooksLikeLeaveButton(text)
  if type(text) ~= "string" or text == "" then return false end
  local lower = text:lower()

  if PARTY_LEAVE and text == PARTY_LEAVE then return true end
  if LEAVE_PARTY and text == LEAVE_PARTY then return true end
  if LEAVE_INSTANCE_GROUP and text == LEAVE_INSTANCE_GROUP then return true end

  if lower:find("leave party", 1, true)
    or lower:find("leave raid", 1, true)
    or lower:find("leave instance", 1, true)
    or lower:find("instance group", 1, true) then
    return true
  end

  if lower:find("покинути", 1, true)
    or lower:find("залишити", 1, true)
    or lower:find("вийти з групи", 1, true)
    or lower:find("вийти з рейду", 1, true) then
    return true
  end

  return false
end

local function CollectLeaveButtons(parent, results, depth)
  if not parent or type(parent.GetNumChildren) ~= "function" or type(parent.GetChildren) ~= "function" then return results end
  results = results or {}
  depth = depth or 0
  if depth > 6 then return results end

  local count = SafeCall(parent, "GetNumChildren")
  if not count or count <= 0 then return results end

  local children = { pcall(parent.GetChildren, parent) }
  if not children[1] then return results end
  table.remove(children, 1)

  for _, child in ipairs(children) do
    if child and type(child.IsObjectType) == "function" then
      local okButton, isButton = pcall(child.IsObjectType, child, "Button")
      if okButton and isButton and LooksLikeLeaveButton(GetButtonText(child)) then
        table.insert(results, child)
      end
    end
  end

  for _, child in ipairs(children) do
    CollectLeaveButtons(child, results, depth + 1)
  end

  return results
end

local function PickBottomButton(buttons)
  local best, bestBottom
  for _, button in ipairs(buttons or {}) do
    local bottom = SafeNumber(button, "GetBottom", nil)
    if bottom and (not bestBottom or bottom < bestBottom) then
      best = button
      bestBottom = bottom
    elseif not best then
      best = button
    end
  end
  return best
end

local function GetRaidManagerRoot()
  return _G.CompactRaidFrameManagerDisplayFrame
    or (_G.CompactRaidFrameManager and (_G.CompactRaidFrameManager.displayFrame or _G.CompactRaidFrameManager.DisplayFrame))
    or _G.CompactRaidFrameManager
end

local function GetReferenceLeaveButton(root)
  return PickBottomButton(CollectLeaveButtons(root))
end

local fallbackBackdrop = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local function ApplyPanelStyle(panel, reference)
  if not panel or panel._ggStyleApplied then return end

  if type(panel.SetBackdrop) == "function" then
    local applied = false
    if reference and type(reference.GetBackdrop) == "function" then
      local ok, backdrop = pcall(reference.GetBackdrop, reference)
      if ok and type(backdrop) == "table" and next(backdrop) then
        pcall(panel.SetBackdrop, panel, backdrop)
        applied = true
        if type(reference.GetBackdropColor) == "function" and type(panel.SetBackdropColor) == "function" then
          local okR, r, g, b, a = pcall(reference.GetBackdropColor, reference)
          if okR then pcall(panel.SetBackdropColor, panel, r, g, b, a) end
        end
        if type(reference.GetBackdropBorderColor) == "function" and type(panel.SetBackdropBorderColor) == "function" then
          local okB, r, g, b, a = pcall(reference.GetBackdropBorderColor, reference)
          if okB then pcall(panel.SetBackdropBorderColor, panel, r, g, b, a) end
        end
      end
    end
    if not applied then
      pcall(panel.SetBackdrop, panel, fallbackBackdrop)
      if type(panel.SetBackdropColor) == "function" then pcall(panel.SetBackdropColor, panel, 0.08, 0.08, 0.08, 0.92) end
      if type(panel.SetBackdropBorderColor) == "function" then pcall(panel.SetBackdropBorderColor, panel, 0.55, 0.55, 0.55, 0.9) end
    end
  end

  if not panel._ggTopBorder then
    local top = panel:CreateTexture(nil, "BORDER")
    top:SetColorTexture(1, 0.82, 0.0, 0.25)
    top:SetHeight(1)
    top:SetPoint("TOPLEFT", 4, -4)
    top:SetPoint("TOPRIGHT", -4, -4)
    panel._ggTopBorder = top
  end

  panel._ggStyleApplied = true
end

local function EnsureAddonPanel(root)
  local parent = SafeCall(root, "GetParent") or UIParent
  if addon.RaidManagerAddonPanel and addon.RaidManagerAddonPanel:GetParent() ~= parent then
    addon.RaidManagerAddonPanel:SetParent(parent)
  end
  if addon.RaidManagerAddonPanel then
    ApplyPanelStyle(addon.RaidManagerAddonPanel, root)
    return addon.RaidManagerAddonPanel
  end

  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  local panel = CreateFrame("Frame", "GroupGuardLFG_RaidManagerAddonPanel", parent, template)
  panel:SetClampedToScreen(true)
  panel:SetToplevel(false)
  ApplyPanelStyle(panel, root)
  addon.RaidManagerAddonPanel = panel
  return panel
end

local function EnsureRootHooks(root)
  if not root or root._ggAddonPanelHooked then return end
  root._ggAddonPanelHooked = true
  if type(root.HookScript) == "function" then
    pcall(root.HookScript, root, "OnShow", function()
      if addon.RefreshRaidManagerPugButton then addon:RefreshRaidManagerPugButton() end
    end)
    pcall(root.HookScript, root, "OnHide", function()
      if addon.RaidManagerAddonPanel then addon.RaidManagerAddonPanel:Hide() end
    end)
    pcall(root.HookScript, root, "OnSizeChanged", function()
      if addon.RefreshRaidManagerPugButton then addon:RefreshRaidManagerPugButton() end
    end)
  end
end

local function GetManagedButtons()
  local buttons = {}
  if addon.RaidManagerPugButton then table.insert(buttons, addon.RaidManagerPugButton) end
  return buttons
end

function addon:UpdateRaidManagerPugButtonLayout()
  local button = self.RaidManagerPugButton
  local root = GetRaidManagerRoot()
  if not button or not root then return end

  EnsureRootHooks(root)

  local panel = EnsureAddonPanel(root)
  if not panel then
    button:Hide()
    return
  end

  local rootShown = SafeCall(root, "IsShown")
  if rootShown == false then
    panel:Hide()
    button:Hide()
    return
  end

  local bottomButton = GetReferenceLeaveButton(root)
  local rootWidth = math.max(120, SafeNumber(root, "GetWidth", 136))
  local buttonWidth = bottomButton and SafeNumber(bottomButton, "GetWidth", 124) or math.max(112, rootWidth - 24)
  local buttonHeight = bottomButton and SafeNumber(bottomButton, "GetHeight", 22) or 22
  local buttons = GetManagedButtons()
  local spacing = 4
  local paddingTop = 8
  local paddingBottom = 8
  local panelHeight = paddingTop + paddingBottom + buttonHeight
  if #buttons > 1 then panelHeight = panelHeight + (#buttons - 1) * (buttonHeight + spacing) end

  panel:ClearAllPoints()
  panel:SetPoint("TOPLEFT", root, "BOTTOMLEFT", 0, -8)
  panel:SetSize(rootWidth, panelHeight)

  local strata = SafeCall(root, "GetFrameStrata") or "MEDIUM"
  panel:SetFrameStrata(strata)
  panel:SetFrameLevel((SafeNumber(root, "GetFrameLevel", 1) or 1) + 1)
  panel:Show()

  local anchor = nil
  for index, managedButton in ipairs(buttons) do
    if managedButton:GetParent() ~= panel then managedButton:SetParent(panel) end
    managedButton:ClearAllPoints()
    managedButton:SetSize(buttonWidth, buttonHeight)
    if index == 1 then
      managedButton:SetPoint("TOP", panel, "TOP", 0, -paddingTop)
    else
      managedButton:SetPoint("TOP", anchor, "BOTTOM", 0, -spacing)
    end
    anchor = managedButton
  end

  button:SetText(self:Tr("RAID_MANAGER_PUG_BUTTON"))
  if IsEnabled() and IsRaidGroup() then
    button:Enable()
    button:SetAlpha(1)
  else
    button:Disable()
    button:SetAlpha(0.45)
  end

  for _, managedButton in ipairs(buttons) do managedButton:Show() end
end

function addon:CreateRaidManagerPugButton()
  if not IsEnabled() then return nil end
  if self.RaidManagerPugButton then
    self:UpdateRaidManagerPugButtonLayout()
    return self.RaidManagerPugButton
  end

  local root = GetRaidManagerRoot()
  local parent = root and (SafeCall(root, "GetParent") or UIParent) or UIParent

  local button = CreateFrame("Button", "GroupGuardLFG_RaidManagerPugButton", parent, "UIPanelButtonTemplate")
  button:SetText(self:Tr("RAID_MANAGER_PUG_BUTTON"))
  if button.Text and type(button.Text.SetJustifyH) == "function" then button.Text:SetJustifyH("CENTER") end

  local strata = root and (SafeCall(root, "GetFrameStrata") or "MEDIUM") or "MEDIUM"
  button:SetFrameStrata(strata)
  button:SetFrameLevel((root and SafeNumber(root, "GetFrameLevel", 1) or 1) + 2)

  button:SetScript("OnClick", function()
    if addon.ShowPugWindow then addon:ShowPugWindow() end
  end)
  button:SetScript("OnEnter", function(btn)
    if not GameTooltip then return end
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:AddLine(addon:Tr("RAID_MANAGER_PUG_BUTTON"), 1, 0.82, 0.36)
    GameTooltip:AddLine(addon:Tr("RAID_MANAGER_PUG_TOOLTIP"), 0.86, 0.82, 0.72, true)
    if not IsRaidGroup() then
      GameTooltip:AddLine(addon:Tr("PUG_RAID_ONLY"), 1, 0.35, 0.28, true)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)

  self.RaidManagerPugButton = button
  self:UpdateRaidManagerPugButtonLayout()
  return button
end

function addon:RefreshRaidManagerPugButton()
  if not IsEnabled() then
    if self.RaidManagerPugButton then self.RaidManagerPugButton:Hide() end
    if self.RaidManagerAddonPanel then self.RaidManagerAddonPanel:Hide() end
    return
  end
  if not IsRaidManagerAvailable() then return end
  self:CreateRaidManagerPugButton()
end

local function ScheduleRefresh(delay)
  if refreshScheduled then return end
  refreshScheduled = true
  local function run()
    refreshScheduled = false
    if addon.RefreshRaidManagerPugButton then addon:RefreshRaidManagerPugButton() end
  end
  if not C_Timer or not C_Timer.After then
    run()
    return
  end
  C_Timer.After(delay or 0.05, run)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, loadedName)
  if event == "ADDON_LOADED" and loadedName ~= "Blizzard_CompactRaidFrames" and loadedName ~= addonName then return end
  ScheduleRefresh(0.05)
  if not IsRaidManagerAvailable() and retryCount < MAX_RETRIES then
    retryCount = retryCount + 1
    ScheduleRefresh(0.35 + retryCount * 0.15)
  end
end)

if hooksecurefunc then
  local function HookManagerFunction(name)
    if type(_G[name]) == "function" then
      pcall(hooksecurefunc, name, function() ScheduleRefresh(0.05) end)
    end
  end
  HookManagerFunction("CompactRaidFrameManager_UpdateShown")
  HookManagerFunction("CompactRaidFrameManager_UpdateOptionsFlowContainer")
  HookManagerFunction("CompactRaidFrameManager_SetSetting")
end
