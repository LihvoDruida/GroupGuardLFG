-- GroupGuard LFG — Core / Alerts
local addonName, addon = ...

function addon:IsPathInMedia(path)
  if not path then return false end
  local p = path:gsub("/", "\\")
  return p:lower():find(("Interface\\AddOns\\GroupGuardLFG\\Media\\"):lower(), 1, true) == 1
end

function addon:AddPresetFromPath(path)
  if not self:IsPathInMedia(path) then return end
  for _, p in pairs(self.db.sound_presets or {}) do
    if p:lower() == path:lower() then return end
  end
  table.insert(self.db.sound_presets, path)
end

function addon:PlayAlertSound()
  if self:IsDisabledNow() then return end
  if self.ShouldSuppressAlerts and self:ShouldSuppressAlerts("sound") then return end
  if not (self.db and self.db.play_sound) then return end

  local now = GetTime and GetTime() or 0
  local cooldown = tonumber(self.db and self.db.alert_sound_cooldown) or 10
  if (self._lastAlertSoundAt or 0) + cooldown > now then return end
  self._lastAlertSoundAt = now

  local played = false
  if self.db.sound_kit == "FILE" and self.db.sound_file and self.db.sound_file ~= "" then
    if PlaySoundFile then
      local ok, willPlay = pcall(PlaySoundFile, self.db.sound_file, "Master")
      played = ok and willPlay and true or false
    end
  end

  if not played then
    if SOUNDKIT and SOUNDKIT.RAID_WARNING then
      if PlaySound then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
    else
      if PlaySound then PlaySound(8959, "Master") end
    end
  end
end

function addon:ClearAlert()
  if self.Banner and self.Banner.timer then
    pcall(function() self.Banner.timer:Cancel() end)
    self.Banner.timer = nil
  end
  if self.Banner then pcall(function() self.Banner:Hide() end) end
  if self.Flash then pcall(function() self.Flash:Hide() end) end
  self._alertActive = false
  self._needsRecheck = false
  self._placeholderShown = false
end

local function SetBannerText(frame, key, text, shown)
  if not frame or not frame[key] then return end
  frame[key]:SetText(text or "")
  if shown ~= nil and frame[key].SetShown then frame[key]:SetShown(shown and true or false) end
end

function addon:ApplyBannerKind(kind)
  if not self.Banner then return end
  kind = kind or "DETECTED"
  local tagText = self:Tr("MARKED")
  local r, g, b = 1.0, 0.28, 0.18
  if kind == "AUTO_DECLINE" then
    tagText = self:Tr("AUTO_DECLINED")
    r, g, b = 1.0, 0.58, 0.18
  elseif kind == "ACTION" then
    tagText = self:Tr("MARKED")
    r, g, b = 1.0, 0.72, 0.24
  elseif kind == "TEST" then
    tagText = self:Tr("TEST")
    r, g, b = 0.45, 0.78, 1.0
  end
  if self.Banner.tag then
    self.Banner.tag:SetText(tagText)
    self.Banner.tag:SetTextColor(r, g, b)
  end
  if self.Banner.glow then self.Banner.glow:SetColorTexture(r * 0.25, g * 0.10, b * 0.08, 0.26) end
  if self.Banner.softTop then self.Banner.softTop:SetColorTexture(r, g, b, 0.07) end
  if self.Banner.severityStrip then self.Banner.severityStrip:SetColorTexture(r, g * 0.72, b * 0.62, 0.88) end
  if self.Banner.tagBg then self.Banner.tagBg:SetColorTexture(r, g * 0.55, b * 0.45, 0.16) end
  if self.Banner.headerLine then self.Banner.headerLine:SetColorTexture(r, g * 0.74, b * 0.62, 0.18) end
  if self.Banner.iconBg then self.Banner.iconBg:SetColorTexture(r * 0.14, g * 0.08, b * 0.08, 0.88) end
  if self.Banner.icon then self.Banner.icon:SetVertexColor(1, 1, 1, 1) end
  if self.Banner.iconRing and self.Banner.iconRing.SetBackdropBorderColor then self.Banner.iconRing:SetBackdropBorderColor(r, g * 0.55, b * 0.45, 0.92) end
end

function addon:ShowBanner(primaryText, secondaryText, unusedOverlayText, kind, detailText)
  if self:IsDisabledNow() then return end
  if self.ShouldSuppressAlerts and kind ~= "TEST" and kind ~= "ACTION" and self:ShouldSuppressAlerts("banner") then return end
  if not (self.db and self.db.show_banner) then return end
  if not self.Banner then return end

  self:ApplyBannerKind(kind or "DETECTED")
  local fontPrimary   = self:GetFontForText(primaryText)
  local fontSecondary = self:GetFontForText(secondaryText)

  if self.Banner.primary then
    self.Banner.primary:SetFont(fontPrimary, 18, "OUTLINE")
    self.Banner.primary:SetText(primaryText or "")
  end
  if self.Banner.secondary then
    self.Banner.secondary:SetFont(fontSecondary, 12, "OUTLINE")
    self.Banner.secondary:SetText(secondaryText or "")
    self.Banner.secondary:SetShown((secondaryText or "") ~= "")
  end
  local detail = detailText or self:Tr("DEFAULT_DETAIL")
  SetBannerText(self.Banner, "caution", detail, detail ~= "")
  if self.Banner.status then
    self.Banner.status:SetText(date and date("%H:%M:%S") or "")
  end

  if self.UpdateBannerGroupButtons then self:UpdateBannerGroupButtons() end
  if self.LayoutBannerActionButtons then self:LayoutBannerActionButtons() end

  self.Banner:Show()
  if UIFrameFadeIn then
    UIFrameFadeIn(self.Banner, 0.10, 0.20, 1)
  else
    self.Banner:SetAlpha(1)
  end

  local hold = tonumber(self.db.banner_hold_time) or 10
  if self.Banner.timer and self.Banner.timer.Cancel then self.Banner.timer:Cancel() end
  local function hideBanner()
    if addon.Banner then
      if UIFrameFadeOut then
        UIFrameFadeOut(addon.Banner, 0.16, addon.Banner:GetAlpha() or 1, 0)
        local function finishHide()
          if addon.Banner then addon.Banner:Hide(); addon.Banner:SetAlpha(1) end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.18, finishHide) else finishHide() end
      else
        addon.Banner:Hide()
      end
    end
  end
  if C_Timer and C_Timer.NewTimer then
    self.Banner.timer = C_Timer.NewTimer(hold, hideBanner)
  else
    self.Banner.timer = nil
  end
end

function addon:UpdateBanner(primaryText, secondaryText, unusedOverlayText, kind, detailText)
  if self:IsDisabledNow() then return end
  if not self.Banner then return end
  if self.UpdateBannerGroupButtons then self:UpdateBannerGroupButtons() end
  self:ShowBanner(primaryText, secondaryText, false, kind, detailText)
end

function addon:LayoutBannerActionButtons()
  if not self.Banner then return end

  local actionBar = self.Banner.actionBar or self.Banner
  local ordered = {}

  local function prepare(btn)
    if not btn then return end
    btn:SetParent(self.Banner)
    btn:SetFrameStrata(self.Banner:GetFrameStrata() or "DIALOG")
    btn:SetFrameLevel((self.Banner:GetFrameLevel() or 260) + 12)
    btn:ClearAllPoints()
    if btn:IsShown() then
      ordered[#ordered + 1] = btn
    end
  end

  prepare(self.leaveButton)
  prepare(self.kickButton)

  local prev
  for i = #ordered, 1, -1 do
    local btn = ordered[i]
    if not prev then
      btn:SetPoint("RIGHT", actionBar, "RIGHT", 0, 0)
    else
      btn:SetPoint("RIGHT", prev, "LEFT", -8, 0)
    end
    prev = btn
  end

  if self.Banner.actionDivider then
    self.Banner.actionDivider:SetShown(#ordered > 0)
  end
end

function addon:LayoutBannerActionButton()
  self:LayoutBannerActionButtons()
end

function addon:NotifyLFGAutoDeclined(count, details)
  if self.ShouldSuppressAlerts and self:ShouldSuppressAlerts("lfg_auto_decline_notice") then return end
  if not (self.db and self.db.lfg_auto_decline_notify) then return end
  count = tonumber(count) or 0
  if count <= 0 then return end
  local now = GetTime and GetTime() or 0
  if (self._lastAutoDeclineNoticeAt or 0) + 1.0 > now then return end
  self._lastAutoDeclineNoticeAt = now
  self:PlayAlertSound()
  self:FlashScreen()
  local title = self:Tr("LFG_AUTO_TITLE", count)
  local sub = details or self:Tr("LFG_MARKED_RULES")
  self:ShowBanner(title, sub, false, "AUTO_DECLINE", self:Tr("LFG_AUTO_DETAIL"))
end

function addon:FlashScreen()
  if self:IsDisabledNow() then return end
  if self.ShouldSuppressAlerts and self:ShouldSuppressAlerts("flash") then return end
  if not (self.db and self.db.screen_flash) then return end
  if not self.Flash then return end
  local now = GetTime and GetTime() or 0
  local cooldown = tonumber(self.db and self.db.alert_flash_cooldown) or 10
  if (self._lastFlashAt or 0) + cooldown > now then return end
  self._lastFlashAt = now
  self.Flash:Show()
  self.Flash:SetAlpha(0.35)
  if UIFrameFadeOut then
    UIFrameFadeOut(self.Flash, 0.6, 0.35, 0)
  else
    if C_Timer and C_Timer.After then
      C_Timer.After(0.6, function() if addon.Flash then addon.Flash:Hide() end end)
    elseif addon.Flash then
      addon.Flash:Hide()
    end
  end
end

function addon:TestAlert()
  if self:IsDisabledNow() then return end
  self:PlayAlertSound()
  self:FlashScreen()
  self:ShowBanner(self:Tr("TEST_ALERT_TITLE"), "GroupGuard LFG", false, "TEST", self:Tr("TEST_ALERT_DETAIL"))
end

local function SafeIsInRaid()
  if not IsInRaid then return false end
  local ok, value = pcall(IsInRaid)
  return ok and value and true or false
end

local function SafeIsInGroup()
  if not IsInGroup then return false end
  local ok, value = pcall(IsInGroup)
  return ok and value and true or false
end

function addon:GetLeaveActionLabel()
  if SafeIsInRaid() then return self:Tr("LEAVE_RAID_BUTTON") end
  if SafeIsInGroup() then return self:Tr("LEAVE_PARTY_BUTTON") end
  return self:Tr("LEAVE_GROUP_BUTTON")
end

function addon:GetLeaveConfirmText()
  if SafeIsInRaid() then return self:Tr("CONFIRM_LEAVE_RAID") end
  if SafeIsInGroup() then return self:Tr("CONFIRM_LEAVE_PARTY") end
  return self:Tr("CONFIRM_LEAVE")
end

function addon:ConfirmAndLeave()
  if self:IsDisabledNow() then return end

  local function leaveNow()
    if C_PartyInfo and C_PartyInfo.LeaveParty then
      C_PartyInfo.LeaveParty()
    elseif LeaveParty then
      LeaveParty()
    end
  end

  if self.db and self.db.confirm_leave then
    StaticPopupDialogs["GROUP_GUARD_LFG_LEAVE"] = {
      text = self:GetLeaveConfirmText(),
      button1 = YES, button2 = NO,
      timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
      OnAccept = leaveNow,
    }
    StaticPopup_Show("GROUP_GUARD_LFG_LEAVE")
  else
    leaveNow()
  end
end

addon._alertActive = false
addon._needsRecheck = false
addon._placeholderShown = false

