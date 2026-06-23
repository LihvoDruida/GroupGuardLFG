local addonName, addon = ...

local DISPLAY_NAME = addon.displayName or "GroupGuard LFG"
local MEDIA_DIR = "Interface\\AddOns\\GroupGuardLFG\\Media\\"
local SAFE_FONT = "Fonts\\FRIZQT__.TTF"

local function CreateDivider(parent, anchorPoint, relativeTo, relativePoint, x, y, w, h, r, g, b, a)
  local tex = parent:CreateTexture(nil, "BORDER")
  tex:SetColorTexture(r or 1, g or 1, b or 1, a or 0.14)
  tex:SetSize(w or 1, h or 1)
  tex:SetPoint(anchorPoint, relativeTo, relativePoint, x or 0, y or 0)
  return tex
end

local function CreateBanner()
  local f = CreateFrame("Frame", "GroupGuardLFG_Banner", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(556, 154)
  f:SetPoint("TOP", UIParent, "TOP", 0, -92)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(260)
  f:EnableMouse(true)
  f:Hide()
  f:SetAlpha(1)

  if f.SetClampedToScreen then f:SetClampedToScreen(true) end
  if f.TitleText then
    f.TitleText:SetText(DISPLAY_NAME)
    f.TitleText:SetTextColor(1.0, 0.82, 0.36)
  end
  if f.CloseButton then
    f.CloseButton:Show()
    f.CloseButton:SetScript("OnClick", function()
      if f.timer then pcall(function() f.timer:Cancel() end); f.timer = nil end
      f:Hide()
      f:SetAlpha(1)
    end)
  end

  if f.Inset then
    local bg = f.Inset:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0.055, 0.055, 0.065, 0.88)
    f.insetBg = bg
  end

  local glow = f:CreateTexture(nil, "BACKGROUND")
  glow:SetPoint("TOPLEFT", 10, -30)
  glow:SetPoint("BOTTOMRIGHT", -10, 10)
  glow:SetColorTexture(0.65, 0.16, 0.08, 0.06)
  f.glow = glow

  local severityStrip = f:CreateTexture(nil, "BORDER")
  severityStrip:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -32)
  severityStrip:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 14)
  severityStrip:SetWidth(3)
  severityStrip:SetColorTexture(1.0, 0.22, 0.12, 0.82)
  f.severityStrip = severityStrip

  local softTop = f:CreateTexture(nil, "BORDER")
  softTop:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -30)
  softTop:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -30)
  softTop:SetHeight(16)
  softTop:SetColorTexture(1.0, 0.55, 0.18, 0.05)
  f.softTop = softTop

  local headerLine = CreateDivider(f, "TOPLEFT", f, "TOPLEFT", 18, -30, 520, 1, 1, 0.82, 0.36, 0.14)
  f.headerLine = headerLine

  local tagBg = f:CreateTexture(nil, "ARTWORK")
  tagBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -26, -34)
  tagBg:SetSize(104, 18)
  tagBg:SetColorTexture(1.0, 0.22, 0.12, 0.12)
  f.tagBg = tagBg

  local tag = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  tag:SetPoint("CENTER", tagBg, "CENTER", 0, 0)
  tag:SetText(addon:Tr("MARKED"))
  tag:SetTextColor(1.0, 0.38, 0.22)
  f.tag = tag

  local iconBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
  iconBox:SetSize(46, 46)
  iconBox:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -42)
  iconBox:SetBackdrop({
    bgFile = "Interface\Buttons\WHITE8X8",
    edgeFile = "Interface\Tooltips\UI-Tooltip-Border",
    tile = false,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  iconBox:SetBackdropColor(0.08, 0.06, 0.04, 0.95)
  iconBox:SetBackdropBorderColor(1.0, 0.30, 0.14, 0.90)
  f.iconRing = iconBox

  local iconBg = iconBox:CreateTexture(nil, "BACKGROUND")
  iconBg:SetPoint("TOPLEFT", 4, -4)
  iconBg:SetPoint("BOTTOMRIGHT", -4, 4)
  iconBg:SetColorTexture(0.16, 0.09, 0.06, 0.82)
  f.iconBg = iconBg

  local icon = iconBox:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("CENTER", iconBox, "CENTER", 0, 0)
  icon:SetSize(34, 34)
  icon:SetTexture(MEDIA_DIR .. "warning_marker.tga")
  f.icon = icon

  local primary = f:CreateFontString(nil, "ARTWORK")
  primary:SetPoint("TOPLEFT", f, "TOPLEFT", 82, -42)
  primary:SetPoint("RIGHT", f, "RIGHT", -136, 0)
  primary:SetJustifyH("LEFT")
  primary:SetSpacing(2)
  primary:SetFont(SAFE_FONT, 16, "")
  primary:SetTextColor(1, 0.92, 0.76)
  primary:SetShadowColor(0, 0, 0, 0.95)
  primary:SetShadowOffset(1, -1)
  f.primary = primary

  local secondary = f:CreateFontString(nil, "ARTWORK")
  secondary:SetPoint("TOPLEFT", primary, "BOTTOMLEFT", 0, -4)
  secondary:SetPoint("RIGHT", f, "RIGHT", -28, 0)
  secondary:SetJustifyH("LEFT")
  secondary:SetFont(SAFE_FONT, 12, "")
  secondary:SetTextColor(1.0, 0.74, 0.42)
  secondary:SetShadowColor(0, 0, 0, 0.9)
  secondary:SetShadowOffset(1, -1)
  f.secondary = secondary

  local caution = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  caution:SetPoint("TOPLEFT", secondary, "BOTTOMLEFT", 0, -6)
  caution:SetPoint("RIGHT", f, "RIGHT", -28, 0)
  caution:SetJustifyH("LEFT")
  caution:SetSpacing(1)
  caution:SetTextColor(0.84, 0.81, 0.74)
  f.caution = caution

  local footerLine = CreateDivider(f, "BOTTOMLEFT", f, "BOTTOMLEFT", 18, 42, 520, 1, 1, 0.82, 0.36, 0.10)
  footerLine:Hide()
  f.actionDivider = footerLine

  local status = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 22, 18)
  status:SetJustifyH("LEFT")
  status:SetTextColor(0.62, 0.58, 0.52)
  f.status = status

  local actionBar = CreateFrame("Frame", nil, f)
  actionBar:SetSize(320, 24)
  actionBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 14)
  f.actionBar = actionBar

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
