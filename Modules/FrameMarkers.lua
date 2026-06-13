-- GroupGuard LFG — Modules / Frame Markers
local addonName, addon = ...


local function CanReadValue(value)
  if value == nil then return false end
  if type(canaccessvalue) == "function" then
    local ok, allowed = pcall(canaccessvalue, value)
    if not ok or not allowed then return false end
  end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret then return false end
  end
  return true
end

local function SafeNumber(value, fallback)
  fallback = fallback or 0
  if value == nil or not CanReadValue(value) then return fallback end
  local valueType = type(value)
  if valueType == "number" then return value end
  if valueType == "string" then return tonumber(value) or fallback end
  local ok, n = pcall(tonumber, value)
  if ok and type(n) == "number" then return n end
  return fallback
end

local function NameKey(name)
  if type(name) ~= "string" or name == "" then return nil end
  return (name:match("^([^-]+)") or name)
end

-- Non-invasive party/raid frame markers
--------------------------------------------------

local function NameKey(name)
  if type(name) ~= "string" or name == "" then return nil end
  return (name:match("^([^-]+)") or name)
end

local FRAME_MARKER_ICON = "Interface\\AddOns\\GroupGuardLFG\\Media\\warning_marker.tga"

local function SafeUnitName(unit)
  if not unit then return nil end
  local ok, name = pcall(UnitName, unit)
  if ok and CanReadValue(name) then return name end
  return nil
end

local function IsUsableFrame(frame)
  -- CompactRaidFrameContainer.flowFrames can contain sentinel strings like "linebreak".
  -- Marker parents must be real frames only.
  local t = type(frame)
  if t ~= "table" and t ~= "userdata" then return false end
  return type(frame.CreateTexture) == "function"
     and type(frame.GetObjectType) == "function"
     and type(frame.GetFrameLevel) == "function"
     and type(frame.GetHeight) == "function"
end

local function ComputeMarkerSize(frame, scaleSetting)
  local h = 0
  local ok, value = pcall(frame.GetHeight, frame)
  if ok and type(value) == "number" then h = value end
  if h <= 0 then h = 36 end

  local scale = tonumber(scaleSetting) or 1
  if scale < 0.5 then scale = 0.5 elseif scale > 1.75 then scale = 1.75 end

  -- Centered raid-frame indicator: visible, but not huge.
  local size = math.floor((h * 0.66 * scale) + 0.5)
  if size < 16 then size = 16 elseif size > 34 then size = 34 end
  return size
end

local function EnsurePulseAnimation(marker)
  if marker.GroupGuardPulse then return marker.GroupGuardPulse end
  local ag = marker:CreateAnimationGroup()
  ag:SetLooping("REPEAT")

  local a1 = ag:CreateAnimation("Alpha")
  a1:SetOrder(1)
  a1:SetFromAlpha(1.0)
  a1:SetToAlpha(0.35)
  a1:SetDuration(0.55)
  if a1.SetSmoothing then a1:SetSmoothing("IN_OUT") end

  local a2 = ag:CreateAnimation("Alpha")
  a2:SetOrder(2)
  a2:SetFromAlpha(0.35)
  a2:SetToAlpha(1.0)
  a2:SetDuration(0.75)
  if a2.SetSmoothing then a2:SetSmoothing("IN_OUT") end

  marker.GroupGuardPulse = ag
  return ag
end

local function EnsureFrameMarker(frame)
  if not IsUsableFrame(frame) then return nil end
  if frame.GroupGuardLFGMarker then return frame.GroupGuardLFGMarker end

  local marker = CreateFrame("Frame", nil, frame)
  marker:SetFrameStrata("HIGH")
  local frameLevel = 1
  local okLevel, level = pcall(frame.GetFrameLevel, frame)
  if okLevel and type(level) == "number" then frameLevel = level end
  marker:SetFrameLevel(frameLevel + 35)
  marker:EnableMouse(false)
  marker:SetAlpha(1)
  marker:Hide()

  marker.icon = marker:CreateTexture(nil, "OVERLAY")
  marker.icon:SetAllPoints()
  marker.icon:SetTexture(FRAME_MARKER_ICON)
  marker.icon:SetBlendMode("BLEND")
  marker.icon:SetTexCoord(0, 1, 0, 1)

  marker.glow = marker:CreateTexture(nil, "ARTWORK")
  marker.glow:SetAllPoints()
  marker.glow:SetTexture(FRAME_MARKER_ICON)
  marker.glow:SetBlendMode("ADD")
  marker.glow:SetVertexColor(1, 0.82, 0.35, 0.35)

  EnsurePulseAnimation(marker)

  frame.GroupGuardLFGMarker = marker
  addon._frameMarkerFrames = addon._frameMarkerFrames or {}
  addon._frameMarkerFrames[frame] = true
  return marker
end

local function LayoutFrameMarker(frame, marker)
  if not (IsUsableFrame(frame) and marker) then return end
  local size = ComputeMarkerSize(frame, addon.db and addon.db.frame_marker_size)
  marker:SetSize(size, size)
  marker:ClearAllPoints()

  -- The marker is intentionally centered on the character frame.
  -- This works better for compact raid frames than the old right-side offset.
  marker:SetPoint("CENTER", frame, "CENTER", 0, 0)
end

local MARKER_COLORS = {
  FLAG = { 1.00, 0.28, 0.10, 1.00, 0.45, 0.08, 0.02, 0.42 },
  FRIEND = { 0.20, 0.70, 1.00, 1.00, 0.04, 0.38, 0.95, 0.42 },
  GUILD = { 0.15, 1.00, 0.42, 1.00, 0.02, 0.70, 0.18, 0.42 },
}

local function ApplyMarkerMode(marker, mode)
  local c = MARKER_COLORS[mode or "FLAG"] or MARKER_COLORS.FLAG
  if marker.icon then marker.icon:SetVertexColor(c[1], c[2], c[3], c[4]) end
  if marker.glow then marker.glow:SetVertexColor(c[5], c[6], c[7], c[8]) end
end

local function ShowFrameMarker(frame, marker, mode)
  if not marker then return end
  LayoutFrameMarker(frame, marker)
  ApplyMarkerMode(marker, mode)
  marker:Show()
  marker:SetAlpha(1)
  if marker.GroupGuardPulse and not marker.GroupGuardPulse:IsPlaying() then
    marker.GroupGuardPulse:Play()
  end
end

local function HideFrameMarker(marker)
  if not marker then return end
  if marker.GroupGuardPulse and marker.GroupGuardPulse:IsPlaying() then
    marker.GroupGuardPulse:Stop()
  end
  marker:SetAlpha(1)
  marker:Hide()
end

local function CollectKnownUnitFrames()
  local frames = {}

  local function add(frame)
    if IsUsableFrame(frame) then frames[frame] = true end
  end

  for i = 1, 40 do add(_G["CompactRaidFrame" .. i]) end
  for i = 1, 5 do add(_G["CompactPartyFrameMember" .. i]) end
  for i = 1, 4 do add(_G["PartyMemberFrame" .. i]) end

  if CompactRaidFrameContainer and type(CompactRaidFrameContainer.flowFrames) == "table" then
    for _, frame in pairs(CompactRaidFrameContainer.flowFrames) do add(frame) end
  end
  if CompactPartyFrame and type(CompactPartyFrame.memberUnitFrames) == "table" then
    for _, frame in pairs(CompactPartyFrame.memberUnitFrames) do add(frame) end
  end

  return frames
end

local function GetFramePlayerName(frame)
  if not IsUsableFrame(frame) then return nil end

  local unit = frame.unit or frame.displayedUnit or frame.unitToken
  local name = SafeUnitName(unit)
  if name then return name end

  local label = frame.name or frame.Name or frame.nameText or frame.NameText
  if label and label.GetText then
    local ok, value = pcall(label.GetText, label)
    if ok and CanReadValue(value) then return value end
  end

  return nil
end

function addon:ClearFrameMarkers()
  if not self._frameMarkerFrames then return end
  for frame in pairs(self._frameMarkerFrames) do
    if frame and frame.GroupGuardLFGMarker then
      HideFrameMarker(frame.GroupGuardLFGMarker)
    end
  end
end

function addon:UpdateFrameMarkers()
  if not (self.db and self.db.frame_markers_enabled) then
    self:ClearFrameMarkers()
    return
  end

  local offenders = self._groupOffenders or {}
  local offenderKeys = self._groupOffenderKeys or {}
  local social = self._groupSocialKeys or {}
  local frames = CollectKnownUnitFrames()

  for frame in pairs(frames) do
    local marker = EnsureFrameMarker(frame)
    if marker then
      local rawName = GetFramePlayerName(frame)
      local name = NameKey(rawName)
      local mode = nil

      local fullKey = nil
      if rawName then
        fullKey = string.lower(tostring(rawName))
      end

      if rawName and offenders[rawName] then
        mode = "FLAG"
      elseif fullKey and offenderKeys[fullKey] then
        mode = "FLAG"
      elseif name and offenderKeys[name] then
        mode = "FLAG"
      end

      if mode then
        ShowFrameMarker(frame, marker, mode)
      else
        HideFrameMarker(marker)
      end
    end
  end
end

function addon:ScheduleFrameMarkerUpdate(delay)
  delay = tonumber(delay) or 0.05
  if self.RunDebounced then
    return self:RunDebounced("frame_marker_update", delay, function()
      if addon.UpdateFrameMarkers then addon:UpdateFrameMarkers() end
    end)
  end
  if self._frameMarkerUpdatePending then return end
  self._frameMarkerUpdatePending = true
  local function run()
    addon._frameMarkerUpdatePending = nil
    if addon.UpdateFrameMarkers then addon:UpdateFrameMarkers() end
  end
  if C_Timer and C_Timer.After then C_Timer.After(delay, run) else run() end
end

