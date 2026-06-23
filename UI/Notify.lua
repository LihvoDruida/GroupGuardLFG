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
  f:SetSize(430, 190)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
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
    bg:SetColorTexture(0.05, 0.08, 0.10, 0.90)
    f.insetBg = bg
  end

  local topGlow = f:CreateTexture(nil, "BORDER")
  topGlow:SetPoint("TOPLEFT", 12, -28)
  topGlow:SetPoint("TOPRIGHT", -12, -28)
  topGlow:SetHeight(20)
  topGlow:SetColorTexture(0.20, 0.55, 0.70, 0.06)
  f.glow = topGlow

  local headerLine = CreateDivider(f, "TOPLEFT", f, "TOPLEFT", 18, -31, 394, 1, 0.55, 0.72, 0.82, 0.20)
  f.headerLine = headerLine

  local tagBg = f:CreateTexture(nil, "ARTWORK")
  tagBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -32, -38)
  tagBg:SetSize(88, 16)
  tagBg:SetColorTexture(0.90, 0.28, 0.18, 0.12)
  f.tagBg = tagBg

  local tag = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  tag:SetPoint("CENTER", tagBg, "CENTER", 0, 0)
  tag:SetText(addon:Tr("MARKED"))
  tag:SetTextColor(1.0, 0.48, 0.30)
  f.tag = tag

  local iconBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
  iconBox:SetSize(56, 56)
  iconBox:SetPoint("TOP", f, "TOP", 0, -52)
  iconBox:SetBackdrop({
    bgFile = "Interface\Buttons\WHITE8X8",
    edgeFile = "Interface\Tooltips\UI-Tooltip-Border",
    tile = false,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  iconBox:SetBackdropColor(0.10, 0.18, 0.20, 0.95)
  iconBox:SetBackdropBorderColor(0.48, 0.74, 0.82, 0.84)
  f.iconRing = iconBox

  local icon = iconBox:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("CENTER", iconBox, "CENTER", 0, 0)
  icon:SetSize(42, 42)
  icon:SetTexture(MEDIA_DIR .. "warning_marker.tga")
  f.icon = icon

  local primary = f:CreateFontString(nil, "ARTWORK")
  primary:SetPoint("TOP", iconBox, "BOTTOM", 0, -8)
  primary:SetPoint("LEFT", f, "LEFT", 26, 0)
  primary:SetPoint("RIGHT", f, "RIGHT", -26, 0)
  primary:SetJustifyH("CENTER")
  primary:SetSpacing(2)
  primary:SetFont(SAFE_FONT, 18, "")
  primary:SetTextColor(1, 0.90, 0.58)
  primary:SetShadowColor(0, 0, 0, 0.95)
  primary:SetShadowOffset(1, -1)
  f.primary = primary

  local secondary = f:CreateFontString(nil, "ARTWORK")
  secondary:SetPoint("TOP", primary, "BOTTOM", 0, -4)
  secondary:SetPoint("LEFT", f, "LEFT", 24, 0)
  secondary:SetPoint("RIGHT", f, "RIGHT", -24, 0)
  secondary:SetJustifyH("CENTER")
  secondary:SetFont(SAFE_FONT, 13, "")
  secondary:SetTextColor(0.86, 0.88, 0.88)
  secondary:SetShadowColor(0, 0, 0, 0.90)
  secondary:SetShadowOffset(1, -1)
  f.secondary = secondary

  local caution = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  caution:SetPoint("TOP", secondary, "BOTTOM", 0, -8)
  caution:SetPoint("LEFT", f, "LEFT", 30, 0)
  caution:SetPoint("RIGHT", f, "RIGHT", -30, 0)
  caution:SetJustifyH("CENTER")
  caution:SetTextColor(0.82, 0.78, 0.70)
  f.caution = caution

  local footerLine = CreateDivider(f, "BOTTOMLEFT", f, "BOTTOMLEFT", 18, 42, 394, 1, 0.55, 0.72, 0.82, 0.14)
  footerLine:Hide()
  f.actionDivider = footerLine

  local status = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 22, 18)
  status:SetJustifyH("LEFT")
  status:SetTextColor(0.58, 0.64, 0.67)
  f.status = status

  local actionBar = CreateFrame("Frame", nil, f)
  actionBar:SetSize(320, 24)
  actionBar:SetPoint("BOTTOM", f, "BOTTOM", 0, 16)
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
