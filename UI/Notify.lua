local addonName, addon = ...

local DISPLAY_NAME = addon.displayName or "GroupGuard LFG"
local MEDIA_DIR = "Interface\\AddOns\\GroupGuardLFG\\Media\\"

local function CreateLine(parent, template, text)
  local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
  fs:SetJustifyH("LEFT")
  fs:SetText(text or "")
  return fs
end

local function CreateBanner()
  -- SettingsUI-style notification frame: BasicFrameTemplateWithInset, clean padding,
  -- no overlapping text and no oversized alert title.
  local f = CreateFrame("Frame", "GroupGuardLFG_Banner", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(560, 156)
  f:SetPoint("TOP", UIParent, "TOP", 0, -88)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(260)
  f:EnableMouse(true)
  f:Hide()
  f:SetAlpha(1)

  if f.SetClampedToScreen then f:SetClampedToScreen(true) end
  if f.CloseButton then
    f.CloseButton:Show()
    f.CloseButton:SetScript("OnClick", function()
      if f.timer then pcall(function() f.timer:Cancel() end); f.timer = nil end
      f:Hide()
      f:SetAlpha(1)
      -- Do not clear addon._alertActive here; otherwise the same offender can instantly reopen the banner.
    end)
  end
  if f.TitleText then f.TitleText:SetText("") end

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  title:SetPoint("TOP", f, "TOP", 0, -6)
  title:SetText(DISPLAY_NAME)
  title:SetTextColor(1.0, 0.82, 0.36)
  f.title = title

  local tag = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  tag:SetPoint("TOPRIGHT", f, "TOPRIGHT", -26, -30)
  tag:SetText(addon:Tr("MARKED"))
  tag:SetTextColor(1.0, 0.38, 0.22)
  f.tag = tag

  -- No left red stripe: keep the notification clean and SettingsUI-like.
  f.accent = nil

  local iconBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
  iconBox:SetSize(48, 48)
  iconBox:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -46)
  iconBox:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 10,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  iconBox:SetBackdropColor(0.03, 0.02, 0.015, 0.94)
  iconBox:SetBackdropBorderColor(1.0, 0.28, 0.12, 0.96)
  f.iconRing = iconBox

  local icon = iconBox:CreateTexture(nil, "OVERLAY")
  icon:SetPoint("CENTER", iconBox, "CENTER", 0, 0)
  icon:SetSize(38, 38)
  icon:SetTexture(MEDIA_DIR .. "warning_marker.tga")
  f.icon = icon

  local safe = "Fonts\\ARIALN.TTF"

  local primary = f:CreateFontString(nil, "ARTWORK")
  primary:SetPoint("TOPLEFT", f, "TOPLEFT", 88, -48)
  primary:SetPoint("RIGHT", f, "RIGHT", -72, 0)
  primary:SetJustifyH("LEFT")
  primary:SetFont(safe, 18, "OUTLINE")
  primary:SetTextColor(1, 0.92, 0.74)
  primary:SetShadowColor(0, 0, 0, 0.9)
  primary:SetShadowOffset(1, -1)
  f.primary = primary

  local secondary = f:CreateFontString(nil, "ARTWORK")
  secondary:SetPoint("TOPLEFT", primary, "BOTTOMLEFT", 0, -4)
  secondary:SetPoint("RIGHT", f, "RIGHT", -34, 0)
  secondary:SetJustifyH("LEFT")
  secondary:SetFont(safe, 12, "OUTLINE")
  secondary:SetTextColor(1, 0.74, 0.42)
  secondary:SetShadowColor(0, 0, 0, 0.85)
  secondary:SetShadowOffset(1, -1)
  f.secondary = secondary

  local caution = f:CreateFontString(nil, "ARTWORK")
  caution:SetPoint("TOPLEFT", secondary, "BOTTOMLEFT", 0, -5)
  caution:SetPoint("RIGHT", f, "RIGHT", -34, 0)
  caution:SetJustifyH("LEFT")
  caution:SetFont(safe, 11, "OUTLINE")
  caution:SetTextColor(0.86, 0.82, 0.72)
  f.caution = caution

  local status = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  status:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 16)
  status:SetTextColor(0.62, 0.58, 0.52)
  f.status = status

  addon.Banner = f
end

local function CreateFlash()
  local f = CreateFrame("Frame", "GroupGuardLFG_FlashOverlay", UIParent, "BackdropTemplate")
  f:SetAllPoints(UIParent)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:Hide()
  local tex = f:CreateTexture(nil, "BACKGROUND")
  tex:SetAllPoints(true)
  tex:SetColorTexture(0.95, 0.10, 0.04, 1)
  f.tex = tex
  addon.Flash = f
end

CreateBanner()
CreateFlash()
