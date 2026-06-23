-- GroupGuard LFG — Modules / Raid PUG Detector
local addonName, addon = ...

local C_Timer = C_Timer

local function SafeIsInRaid()
  if not IsInRaid then return false end
  local ok, value = pcall(IsInRaid)
  return ok and value and true or false
end

local function SafeGroupCount()
  if addon and addon.GetGroupMemberCount then return addon:GetGroupMemberCount() end
  if not GetNumGroupMembers then return 0 end
  local ok, value = pcall(GetNumGroupMembers)
  return ok and tonumber(value) or 0
end

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

local function ShortName(name)
  if type(name) ~= "string" then return "" end
  return name:match("^([^-]+)") or name
end

local function FullNameFromUnit(unit)
  local name, realm
  if UnitFullName then
    local ok, n, r = pcall(UnitFullName, unit)
    if ok then name, realm = n, r end
  end
  if not name and UnitName then
    local ok, n, r = pcall(UnitName, unit)
    if ok then name, realm = n, r end
  end
  if not CanReadValue(name) or type(name) ~= "string" or name == "" then return nil end
  if CanReadValue(realm) and type(realm) == "string" and realm ~= "" then
    return name .. "-" .. realm, name, realm
  end
  return name, name, realm
end

local function ClassColor(classFile)
  if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
    return RAID_CLASS_COLORS[classFile]
  end
  return { r = 1, g = 0.82, b = 0.36 }
end

local function SafeText(value, fallback)
  if CanReadValue(value) and value ~= nil and value ~= "" then return tostring(value) end
  return fallback or "—"
end

local function SafeGetTime()
  if GetTime then
    local ok, value = pcall(GetTime)
    if ok and type(value) == "number" then return value end
  end
  return 0
end

local function SafeUnitGUID(unit)
  if UnitGUID then
    local ok, guid = pcall(UnitGUID, unit)
    if ok and CanReadValue(guid) and type(guid) == "string" and guid ~= "" then return guid end
  end
  return nil
end

local function ReadInspectItemLevel(unit)
  local value
  if C_PaperDollInfo and type(C_PaperDollInfo.GetInspectItemLevel) == "function" then
    local ok, result = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
    if ok then value = tonumber(result) end
  end
  if (not value or value <= 0) and type(GetInspectItemLevel) == "function" then
    local ok, result = pcall(GetInspectItemLevel, unit)
    if ok then value = tonumber(result) end
  end
  if value and value > 0 then return math.floor(value + 0.5) end
  return nil
end

local function CanRequestInspect(unit)
  if not unit then return false end
  if type(InCombatLockdown) == "function" then
    local ok, locked = pcall(InCombatLockdown)
    if ok and locked then return false end
  end
  if UnitAffectingCombat then
    local ok, inCombat = pcall(UnitAffectingCombat, "player")
    if ok and inCombat then return false end
  end
  if CanInspect then
    local ok, value = pcall(CanInspect, unit, false)
    if ok and not value then return false end
  end
  return type(NotifyInspect) == "function"
end

local function FormatItemLevel(value, pending)
  value = tonumber(value)
  if value and value > 0 then return tostring(math.floor(value + 0.5)) end
  if pending then return "…" end
  return "—"
end

function addon:GetPugItemLevel(unit, fullName)
  self._pugIlvlCache = self._pugIlvlCache or {}
  local key = fullName or unit
  local guid = SafeUnitGUID(unit)
  local cache = key and self._pugIlvlCache[key] or nil
  local now = SafeGetTime()

  if cache and cache.itemLevel and (now - (cache.time or 0)) < 900 then
    return cache.itemLevel, false
  end

  local live = ReadInspectItemLevel(unit)
  if live and key then
    self._pugIlvlCache[key] = { itemLevel = live, guid = guid, time = now }
    return live, false
  end

  if not key or not CanRequestInspect(unit) then
    return cache and cache.itemLevel or nil, false
  end

  cache = cache or {}
  local requestedAt = tonumber(cache.requestedAt or 0) or 0
  if (now - requestedAt) > 12 and (now - (self._lastPugInspectRequest or 0)) > 0.9 then
    cache.requestedAt = now
    cache.guid = guid
    self._pugIlvlCache[key] = cache
    self._lastPugInspectRequest = now
    pcall(NotifyInspect, unit)
    return nil, true
  end

  return cache.itemLevel, true
end

local function EnsurePugInspectEvents()
  if addon._pugInspectFrame then return end
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("INSPECT_READY")
  frame:SetScript("OnEvent", function(_, _, guid)
    if not guid then return end
    if not addon._pugIlvlCache then return end
    for i = 1, SafeGroupCount() do
      local unit = "raid" .. i
      local unitGuid = SafeUnitGUID(unit)
      if unitGuid and unitGuid == guid then
        local fullName = FullNameFromUnit(unit)
        local ilvl = ReadInspectItemLevel(unit)
        if fullName and ilvl then
          addon._pugIlvlCache[fullName] = { itemLevel = ilvl, guid = guid, time = SafeGetTime() }
          if addon.PugWindow and addon.PugWindow:IsShown() and addon.RefreshPugWindow then
            if C_Timer and C_Timer.After then
              C_Timer.After(0.05, function()
                if addon.PugWindow and addon.PugWindow:IsShown() then addon:RefreshPugWindow() end
              end)
            else
              addon:RefreshPugWindow()
            end
          end
        end
        break
      end
    end
  end)
  addon._pugInspectFrame = frame
end

function addon:CanManagePugRemoval()
  if self.PlayerCanManageGroup then return self:PlayerCanManageGroup() end
  return false
end

local function PugRoleText(unit)
  local role = "NONE"
  if UnitGroupRolesAssigned then
    local ok, r = pcall(UnitGroupRolesAssigned, unit)
    if ok and type(r) == "string" and r ~= "" then role = r end
  end
  if role == "TANK" then return "Tank" end
  if role == "HEALER" then return "Heal" end
  if role == "DAMAGER" then return "DPS" end
  return "—"
end

local function WipeRows(rows)
  if not rows then return end
  for _, row in ipairs(rows) do row:Hide() end
end

function addon:ScanRaidPugs()
  local result = {}
  local total = 0

  if not SafeIsInRaid() then
    return result, { inRaid = false, total = 0 }
  end

  if self.RebuildFriendCache then self:RebuildFriendCache(not self._friendCache) end
  if self.RebuildGuildCache then self:RebuildGuildCache(not self._guildCache) end

  local num = SafeGroupCount()
  total = num

  for i = 1, num do
    local unit = "raid" .. i
    if UnitExists and UnitExists(unit) then
      local fullName, shortName, realm = FullNameFromUnit(unit)
      if fullName and not (UnitIsUnit and UnitIsUnit(unit, "player")) then
        local guildName
        if GetGuildInfo then
          local okGuild, g = pcall(GetGuildInfo, unit)
          if okGuild and CanReadValue(g) then guildName = g end
        end

        local isGuild = false
        if self.IsGuildUnit then isGuild = self:IsGuildUnit(unit, guildName) and true or false end
        if not isGuild and self.IsGuildMemberName then isGuild = self:IsGuildMemberName(fullName) and true or false end

        local isFriend = false
        if self.IsFriendName then isFriend = self:IsFriendName(fullName) and true or false end

        if not isGuild and not isFriend then
          local className, classFile
          if UnitClass then
            local okClass, cn, cf = pcall(UnitClass, unit)
            if okClass then className, classFile = cn, cf end
          end

          local online = true
          if UnitIsConnected then
            local okOnline, value = pcall(UnitIsConnected, unit)
            if okOnline then online = value and true or false end
          end

          local subgroup = nil
          if GetRaidRosterInfo then
            local okRoster, _, _, sg = pcall(GetRaidRosterInfo, i)
            if okRoster then subgroup = tonumber(sg) end
          end

          local itemLevel, itemLevelPending = self:GetPugItemLevel(unit, fullName)

          result[#result + 1] = {
            unit = unit,
            index = i,
            name = shortName or fullName,
            fullName = fullName,
            realm = realm,
            className = SafeText(className, "—"),
            classFile = classFile,
            guildName = SafeText(guildName, "—"),
            role = PugRoleText(unit),
            subgroup = subgroup,
            itemLevel = itemLevel,
            itemLevelPending = itemLevelPending,
            online = online,
          }
        end
      end
    end
  end

  table.sort(result, function(a, b)
    local ag = tonumber(a.subgroup or 99) or 99
    local bg = tonumber(b.subgroup or 99) or 99
    if ag ~= bg then return ag < bg end
    return tostring(a.name or "") < tostring(b.name or "")
  end)

  return result, { inRaid = true, total = total }
end

local function CreateHeaderText(parent, text, width, point, rel, relPoint, x, y)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  fs:SetText(text or "")
  fs:SetWidth(width or 80)
  fs:SetJustifyH("LEFT")
  fs:SetPoint(point, rel, relPoint, x or 0, y or 0)
  return fs
end


local PUG_COL = {
  NUM_X = 8,  NUM_W = 26,
  NAME_X = 40, NAME_W = 160,
  CLASS_X = 206, CLASS_W = 84,
  ROLE_X = 296, ROLE_W = 46,
  ILVL_X = 348, ILVL_W = 42,
  GUILD_X = 396, GUILD_W = 126,
  GROUP_X = 528, GROUP_W = 22,
  ACTION_X = 548, ACTION_W = 18,
  ROW_W = 570,
}

local function CreateRow(parent, index)
  local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
  row:SetSize(PUG_COL.ROW_W, 24)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * 26))
  row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
  if index % 2 == 0 then
    row:SetBackdropColor(1, 0.82, 0.36, 0.035)
  else
    row:SetBackdropColor(0, 0, 0, 0.08)
  end
  row:Hide()

  row.num = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  row.num:SetPoint("LEFT", row, "LEFT", PUG_COL.NUM_X, 0)
  row.num:SetWidth(PUG_COL.NUM_W)
  row.num:SetJustifyH("LEFT")

  row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.name:SetPoint("LEFT", row, "LEFT", PUG_COL.NAME_X, 0)
  row.name:SetWidth(PUG_COL.NAME_W)
  row.name:SetJustifyH("LEFT")

  row.class = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  row.class:SetPoint("LEFT", row, "LEFT", PUG_COL.CLASS_X, 0)
  row.class:SetWidth(PUG_COL.CLASS_W)
  row.class:SetJustifyH("LEFT")

  row.role = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  row.role:SetPoint("LEFT", row, "LEFT", PUG_COL.ROLE_X, 0)
  row.role:SetWidth(PUG_COL.ROLE_W)
  row.role:SetJustifyH("LEFT")

  row.ilvl = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  row.ilvl:SetPoint("LEFT", row, "LEFT", PUG_COL.ILVL_X, 0)
  row.ilvl:SetWidth(PUG_COL.ILVL_W)
  row.ilvl:SetJustifyH("LEFT")

  row.guild = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  row.guild:SetPoint("LEFT", row, "LEFT", PUG_COL.GUILD_X, 0)
  row.guild:SetWidth(PUG_COL.GUILD_W)
  row.guild:SetJustifyH("LEFT")

  row.group = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  row.group:SetPoint("LEFT", row, "LEFT", PUG_COL.GROUP_X, 0)
  row.group:SetWidth(PUG_COL.GROUP_W)
  row.group:SetJustifyH("LEFT")

  row.kick = CreateFrame("Button", nil, row, "UIPanelCloseButton")
  row.kick:SetSize(PUG_COL.ACTION_W, PUG_COL.ACTION_W)
  row.kick:SetPoint("LEFT", row, "LEFT", PUG_COL.ACTION_X, 0)
  row.kick:SetScript("OnEnter", function(btn)
    if not GameTooltip then return end
    GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
    GameTooltip:AddLine(addon:Tr("PUG_KICK"), 1, 0.82, 0.36)
    GameTooltip:AddLine(addon:Tr("PUG_KICK_TOOLTIP"), 0.86, 0.82, 0.72, true)
    if not addon:CanManagePugRemoval() then
      GameTooltip:AddLine(addon:Tr("NO_REMOVE_PERMISSION"), 1, 0.25, 0.2, true)
    end
    GameTooltip:Show()
  end)
  row.kick:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)
  row.kick:SetScript("OnClick", function(btn)
    local data = btn:GetParent() and btn:GetParent().pugData
    if not data then return end

    if not addon:CanManagePugRemoval() then
      print((addon.printPrefix or "GroupGuard LFG:"), addon:Tr("NO_REMOVE_PERMISSION"))
      return
    end

    local display = data.fullName or data.name or "?"
    if addon.UpdateBanner then
      addon:UpdateBanner(addon:Tr("PUG_KICKING_FMT", display), "", false, "ACTION", "")
    end

    if addon.KickNamesSequential then
      addon:KickNamesSequential({ { unit = data.unit, name = data.name, fullName = data.fullName } }, 0.15)
    elseif UninviteUnit then
      pcall(UninviteUnit, data.unit or data.fullName or data.name)
    end

    btn:Disable()
    local function refreshOpen()
      if addon.PugWindow and addon.PugWindow:IsShown() then addon:RefreshPugWindow() end
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(0.35, refreshOpen)
      C_Timer.After(1.10, refreshOpen)
    else
      refreshOpen()
    end
  end)

  return row
end

function addon:CreatePugWindow()
  if self.PugWindow then return self.PugWindow end
  EnsurePugInspectEvents()

  local f = CreateFrame("Frame", "GroupGuardLFG_PugWindow", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(640, 430)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(270)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f:Hide()

  if f.TitleText then f.TitleText:SetText(self:Tr("PUG_WINDOW_TITLE")) end

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -34)
  title:SetText(self:Tr("PUG_WINDOW_TITLE"))
  title:SetTextColor(1, 0.82, 0.36)
  f.title = title

  local count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -32, -38)
  count:SetText("")
  f.count = count

  local note = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  note:SetPoint("RIGHT", f, "RIGHT", -28, 0)
  note:SetJustifyH("LEFT")
  note:SetText(self:Tr("PUG_WINDOW_NOTE"))
  f.note = note

  local header = CreateFrame("Frame", nil, f)
  header:SetSize(PUG_COL.ROW_W, 22)
  header:SetPoint("TOPLEFT", f, "TOPLEFT", 36, -88)
  f.header = header

  CreateHeaderText(header, "#", PUG_COL.NUM_W, "LEFT", header, "LEFT", PUG_COL.NUM_X, 0)
  CreateHeaderText(header, self:Tr("PUG_COL_NAME"), PUG_COL.NAME_W, "LEFT", header, "LEFT", PUG_COL.NAME_X, 0)
  CreateHeaderText(header, self:Tr("PUG_COL_CLASS"), PUG_COL.CLASS_W, "LEFT", header, "LEFT", PUG_COL.CLASS_X, 0)
  CreateHeaderText(header, self:Tr("PUG_COL_ROLE"), PUG_COL.ROLE_W, "LEFT", header, "LEFT", PUG_COL.ROLE_X, 0)
  CreateHeaderText(header, self:Tr("PUG_COL_ILVL"), PUG_COL.ILVL_W, "LEFT", header, "LEFT", PUG_COL.ILVL_X, 0)
  CreateHeaderText(header, self:Tr("PUG_COL_GUILD"), PUG_COL.GUILD_W, "LEFT", header, "LEFT", PUG_COL.GUILD_X, 0)
  CreateHeaderText(header, self:Tr("PUG_COL_GROUP"), PUG_COL.GROUP_W, "LEFT", header, "LEFT", PUG_COL.GROUP_X, 0)
  local actionHeader = CreateHeaderText(header, "", PUG_COL.ACTION_W, "LEFT", header, "LEFT", PUG_COL.ACTION_X, 0)
  actionHeader:SetTextColor(1, 0.82, 0.36)

  local line = header:CreateTexture(nil, "BORDER")
  line:SetColorTexture(1, 0.82, 0.36, 0.16)
  line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, -2)
  line:SetSize(PUG_COL.ROW_W, 1)

  local scroll = CreateFrame("ScrollFrame", "GroupGuardLFG_PugScroll", f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -46, 62)

  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(PUG_COL.ROW_W, 260)
  scroll:SetScrollChild(child)
  f.scroll = scroll
  f.child = child
  f.rows = {}

  local empty = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  empty:SetPoint("CENTER", scroll, "CENTER", 0, 6)
  empty:SetWidth(PUG_COL.ROW_W - 20)
  empty:SetJustifyH("CENTER")
  empty:SetText("")
  empty:Hide()
  f.empty = empty

  local refresh = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  refresh:SetSize(110, 24)
  refresh:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -142, 22)
  refresh:SetText(self:Tr("PUG_REFRESH"))
  refresh:SetScript("OnClick", function() addon:RefreshPugWindow() end)
  f.refresh = refresh

  local printBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  printBtn:SetSize(110, 24)
  printBtn:SetPoint("RIGHT", refresh, "LEFT", -8, 0)
  printBtn:SetText(self:Tr("PUG_PRINT"))
  printBtn:SetScript("OnClick", function() addon:PrintRaidPugs() end)
  f.printBtn = printBtn

  local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  close:SetSize(96, 24)
  close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 22)
  close:SetText(CLOSE or "Close")
  close:SetScript("OnClick", function() f:Hide() end)
  f.close = close

  self.PugWindow = f
  return f
end

function addon:RefreshPugWindow()
  local f = self.PugWindow or self:CreatePugWindow()
  local pugs, meta = self:ScanRaidPugs()
  WipeRows(f.rows)

  if not meta or not meta.inRaid then
    f.count:SetText(self:Tr("PUG_COUNT_FMT", 0, 0))
    f.empty:SetText(self:Tr("PUG_RAID_ONLY"))
    f.empty:Show()
    f.child:SetHeight(260)
    return
  end

  f.count:SetText(self:Tr("PUG_COUNT_FMT", #pugs, meta.total or 0))

  if #pugs == 0 then
    f.empty:SetText(self:Tr("PUG_EMPTY"))
    f.empty:Show()
    f.child:SetHeight(260)
    return
  end

  f.empty:Hide()
  f.child:SetWidth(PUG_COL.ROW_W)
  f.child:SetHeight(math.max(260, #pugs * 26))

  for i, pug in ipairs(pugs) do
    local row = f.rows[i]
    if not row then
      row = CreateRow(f.child, i)
      f.rows[i] = row
    end

    local classColor = ClassColor(pug.classFile)
    local canKick = self:CanManagePugRemoval()
    row.pugData = pug
    row.num:SetText(tostring(i))
    row.name:SetText(pug.fullName or pug.name or "?")
    row.name:SetTextColor(classColor.r or 1, classColor.g or 0.82, classColor.b or 0.36)
    row.class:SetText(pug.className or "—")
    row.role:SetText(pug.role or "—")
    row.ilvl:SetText(FormatItemLevel(pug.itemLevel, pug.itemLevelPending))
    row.guild:SetText(pug.guildName or "—")
    row.group:SetText(pug.subgroup and tostring(pug.subgroup) or "—")
    row:SetAlpha(pug.online and 1 or 0.48)
    if row.kick then
      row.kick:Show()
      row.kick:SetEnabled(canKick and pug.online)
      row.kick:SetAlpha((canKick and pug.online) and 1 or 0.35)
    end
    row:Show()
  end
end

function addon:ShowPugWindow()
  local f = self.PugWindow or self:CreatePugWindow()
  self:RefreshPugWindow()
  f:Show()
end

function addon:TogglePugWindow()
  local f = self.PugWindow or self:CreatePugWindow()
  if f:IsShown() then
    f:Hide()
  else
    self:ShowPugWindow()
  end
end

function addon:PrintRaidPugs()
  local pugs, meta = self:ScanRaidPugs()
  if not meta or not meta.inRaid then
    print((self.printPrefix or "GroupGuard LFG:"), self:Tr("PUG_RAID_ONLY"))
    return
  end

  print((self.printPrefix or "GroupGuard LFG:"), self:Tr("PUG_COUNT_FMT", #pugs, meta.total or 0))
  if #pugs == 0 then
    print((self.printPrefix or "GroupGuard LFG:"), self:Tr("PUG_EMPTY"))
    return
  end

  for i, pug in ipairs(pugs) do
    print(addon:Tr("PUG_PRINT_ROW", i, pug.fullName or pug.name or "?", pug.className or "—", pug.role or "—", FormatItemLevel(pug.itemLevel, pug.itemLevelPending), pug.guildName or "—"))
  end
end

SLASH_GROUPGUARDLFGPUGS1 = "/ggpugs"
SLASH_GROUPGUARDLFGPUGS2 = "/raidpugs"
SlashCmdList.GROUPGUARDLFGPUGS = function()
  if not addon.db and addon.EnsureDB then addon:EnsureDB() end
  addon:TogglePugWindow()
end
