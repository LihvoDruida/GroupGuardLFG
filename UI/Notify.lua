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
  f:SetSize(560, 176)
  f:SetPoint("TOP", UIParent, "TOP", 0, -88)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(260)
  f:EnableMouse(true)
  f:Hide()
  f:SetAlpha(1)

  if f.SetClampedToScreen then f:SetClampedToScreen(true) end
  if f.TitleText then f.TitleText:SetText("") end
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
    bg:SetColorTexture(0.05, 0.05, 0.06, 0.84)
    f.insetBg = bg
  end

  local glow = f:CreateTexture(nil, "BACKGROUND")
  glow:SetPoint("TOPLEFT", 8, -28)
  glow:SetPoint("BOTTOMRIGHT", -8, 8)
  glow:SetColorTexture(0.65, 0.16, 0.08, 0.08)
  f.glow = glow

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("TOP", f, "TOP", 0, -6)
  title:SetText(DISPLAY_NAME)
  title:SetTextColor(1.0, 0.82, 0.36)
  f.title = title

  local headerLine = CreateDivider(f, "TOPLEFT", f, "TOPLEFT", 16, -26, 528, 1, 1, 0.82, 0.36, 0.16)
  f.headerLine = headerLine

  local tag = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  tag:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, -31)
  tag:SetText(addon:Tr("MARKED"))
  tag:SetTextColor(1.0, 0.38, 0.22)
  f.tag = tag

  local iconBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
  iconBox:SetSize(50, 50)
  iconBox:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -44)
  iconBox:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
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
  iconBg:SetColorTexture(0.16, 0.09, 0.06, 0.85)
  f.iconBg = iconBg

  local icon = iconBox:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("CENTER", iconBox, "CENTER", 0, 0)
  icon:SetSize(38, 38)
  icon:SetTexture(MEDIA_DIR .. "warning_marker.tga")
  f.icon = icon

  local primary = f:CreateFontString(nil, "ARTWORK")
  primary:SetPoint("TOPLEFT", f, "TOPLEFT", 88, -46)
  primary:SetPoint("RIGHT", f, "RIGHT", -110, 0)
  primary:SetJustifyH("LEFT")
  primary:SetFont(SAFE_FONT, 17, "OUTLINE")
  primary:SetTextColor(1, 0.92, 0.76)
  primary:SetShadowColor(0, 0, 0, 0.95)
  primary:SetShadowOffset(1, -1)
  f.primary = primary

  local secondary = f:CreateFontString(nil, "ARTWORK")
  secondary:SetPoint("TOPLEFT", primary, "BOTTOMLEFT", 0, -5)
  secondary:SetPoint("RIGHT", f, "RIGHT", -34, 0)
  secondary:SetJustifyH("LEFT")
  secondary:SetFont(SAFE_FONT, 12, "")
  secondary:SetTextColor(1.0, 0.74, 0.42)
  secondary:SetShadowColor(0, 0, 0, 0.9)
  secondary:SetShadowOffset(1, -1)
  f.secondary = secondary

  local caution = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  caution:SetPoint("TOPLEFT", secondary, "BOTTOMLEFT", 0, -6)
  caution:SetPoint("RIGHT", f, "RIGHT", -34, 0)
  caution:SetJustifyH("LEFT")
  caution:SetTextColor(0.86, 0.82, 0.72)
  f.caution = caution

  local status = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 24, 16)
  status:SetJustifyH("LEFT")
  status:SetTextColor(0.62, 0.58, 0.52)
  f.status = status

  local actionDivider = CreateDivider(f, "BOTTOMLEFT", f, "BOTTOMLEFT", 16, 42, 528, 1, 1, 0.82, 0.36, 0.12)
  actionDivider:Hide()
  f.actionDivider = actionDivider

  local actionBar = CreateFrame("Frame", nil, f)
  actionBar:SetSize(312, 26)
  actionBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, 12)
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
