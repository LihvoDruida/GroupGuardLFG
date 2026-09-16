-- GroupGuard LFG — Core / Safe API and UI helpers
-- Centralized guards for WoW 12.x secret values, recycled ScrollBox rows and optional addon conflicts.
local addonName, addon = ...

local type, tostring, tonumber, pairs, ipairs = type, tostring, tonumber, pairs, ipairs

function addon:SafeCanRead(value)
  -- Never compare/test a possibly-secret value before asking Blizzard whether
  -- addon code may read it. In Midnight, the guard itself must be the first
  -- operation performed on the value.
  if type(canaccessvalue) == "function" then
    local ok, allowed = pcall(canaccessvalue, value)
    if not ok or allowed ~= true then return false end
  end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret == true then return false end
  end
  return value ~= nil
end

function addon:SafeCanAccessTable(value)
  if type(value) ~= "table" then return false end
  if type(canaccesstable) == "function" then
    local ok, allowed = pcall(canaccesstable, value)
    if not ok or allowed ~= true then return false end
  end
  if type(issecrettable) == "function" then
    local ok, secret = pcall(issecrettable, value)
    if not ok or secret == true then return false end
  end
  return true
end

function addon:SafeText(value, fallback)
  if not self:SafeCanRead(value) then return fallback end
  if type(value) == "string" then return value end
  local ok, result = pcall(tostring, value)
  return ok and result or fallback
end

function addon:SafeNumber(value, fallback)
  if not self:SafeCanRead(value) then return fallback end
  if type(value) == "number" then return value end
  if type(value) == "string" then return tonumber(value) or fallback end
  local ok, result = pcall(tonumber, value)
  return (ok and type(result) == "number") and result or fallback
end

function addon:SafeBool(value)
  if not self:SafeCanRead(value) then return false end
  return value == true
end

-- Midnight 12.1 introduced object access constraints/forbidden aspects. Reading
-- methods or fields from a restricted Blizzard object can itself raise a Lua
-- error in a tainted execution path, so object access is checked before we
-- inspect or decorate frames returned by Blizzard UI code.
function addon:SafeCanAccessObject(object)
  if object == nil then return false end
  local objectType = type(object)
  if objectType ~= "table" and objectType ~= "userdata" then return false end

  local okMethod, method = pcall(function() return object.CanBeAccessedInContext end)
  if not okMethod then return false end
  if type(method) == "function" then
    local okAccess, canAccess = pcall(method, object)
    if not okAccess or canAccess ~= true then return false end
  end
  return true
end

function addon:SafeObjectMethod(object, methodName)
  if not self:SafeCanAccessObject(object) or type(methodName) ~= "string" then return nil end
  local ok, method = pcall(function() return object[methodName] end)
  if ok and type(method) == "function" then return method end
  return nil
end

function addon:SafeObjectField(object, key)
  if not self:SafeCanAccessObject(object) then return nil end
  local ok, value = pcall(function() return object[key] end)
  if not ok or not self:SafeCanRead(value) then return nil end
  return value
end

function addon:SafeTableField(tbl, key)
  if not self:SafeCanAccessTable(tbl) then return nil end
  local ok, value = pcall(function() return tbl[key] end)
  if not ok or not self:SafeCanRead(value) then return nil end
  return value
end

function addon:SafeGetElementData(frame)
  local method = self:SafeObjectMethod(frame, "GetElementData")
  if not method then return nil end
  local ok, data = pcall(method, frame)
  if ok and self:SafeCanAccessTable(data) then return data end
  return nil
end

function addon:SafeCall(fn, ...)
  if type(fn) ~= "function" then return false end
  return pcall(fn, ...)
end

-- Public Safe namespace for modules. Keep old addon:Safe* methods for
-- compatibility, but route new code through one shared table instead of
-- duplicating guards in every module.
addon.Safe = addon.Safe or {}
local SafeNS = addon.Safe
function SafeNS.CanReadValue(value) return addon:SafeCanRead(value) end
function SafeNS.CanAccessTable(value) return addon:SafeCanAccessTable(value) end
function SafeNS.Text(value, fallback) return addon:SafeText(value, fallback) end
function SafeNS.Number(value, fallback) return addon:SafeNumber(value, fallback) end
function SafeNS.Bool(value) return addon:SafeBool(value) end
function SafeNS.Call(fn, ...) return addon:SafeCall(fn, ...) end
function SafeNS.CanAccessObject(object) return addon:SafeCanAccessObject(object) end
function SafeNS.ObjectMethod(object, methodName) return addon:SafeObjectMethod(object, methodName) end
function SafeNS.ObjectField(object, key) return addon:SafeObjectField(object, key) end
function SafeNS.TableField(tbl, key) return addon:SafeTableField(tbl, key) end
function SafeNS.UnitExists(unit)
  if not UnitExists then return false end
  local ok, exists = pcall(UnitExists, unit)
  return ok and addon:SafeBool(exists) or false
end
function SafeNS.UnitFullName(unit)
  local name, realm
  if UnitFullName then
    local ok, n, r = pcall(UnitFullName, unit)
    if ok then
      name = addon:SafeText(n)
      realm = addon:SafeText(r)
    end
  end
  if not name and UnitName then
    local ok, n, r = pcall(UnitName, unit)
    if ok then
      name = addon:SafeText(n)
      realm = addon:SafeText(r)
    end
  end
  if not name or name == "" then return nil, nil, nil end
  if realm and realm ~= "" then return name .. "-" .. realm, name, realm end
  return name, name, realm
end
function SafeNS.IsInRaid()
  if not IsInRaid then return false end
  local ok, value = pcall(IsInRaid)
  return ok and addon:SafeBool(value) or false
end
function SafeNS.IsInGroup()
  if not IsInGroup then return false end
  local ok, value = pcall(IsInGroup)
  return ok and addon:SafeBool(value) or false
end
function SafeNS.UnitIsUnit(unitA, unitB)
  if type(UnitIsUnit) ~= "function" then return false end
  local ok, value = pcall(UnitIsUnit, unitA, unitB)
  return ok and addon:SafeBool(value) or false
end
function SafeNS.UnitIsConnected(unit)
  if type(UnitIsConnected) ~= "function" then return false end
  local ok, value = pcall(UnitIsConnected, unit)
  return ok and addon:SafeBool(value) or false
end
function SafeNS.UnitAffectingCombat(unit)
  if type(UnitAffectingCombat) ~= "function" then return false end
  local ok, value = pcall(UnitAffectingCombat, unit or "player")
  return ok and addon:SafeBool(value) or false
end
function SafeNS.InCombatLockdown()
  if type(InCombatLockdown) ~= "function" then return false end
  local ok, value = pcall(InCombatLockdown)
  return ok and addon:SafeBool(value) or false
end
function SafeNS.CanInspect(unit)
  if type(CanInspect) ~= "function" then return false end
  local ok, value = pcall(CanInspect, unit, false)
  return ok and addon:SafeBool(value) or false
end
function SafeNS.UnitGUID(unit)
  if type(UnitGUID) ~= "function" then return nil end
  local ok, value = pcall(UnitGUID, unit)
  if not ok then return nil end
  local guid = addon:SafeText(value)
  return guid ~= "" and guid or nil
end
function SafeNS.IsInGuild()
  if type(IsInGuild) ~= "function" then return false end
  local ok, value = pcall(IsInGuild)
  return ok and addon:SafeBool(value) or false
end
function SafeNS.GetRaidSubgroup(index)
  if type(GetRaidRosterInfo) ~= "function" then return nil end
  local ok, _, _, subgroup = pcall(GetRaidRosterInfo, index)
  if not ok then return nil end
  return addon:SafeNumber(subgroup, nil)
end
-- 12.1: UnitIsGroupLeader / UnitIsGroupAssistant / UnitIsRaidOfficer / UnitInRaid /
-- UnitClass / UnitRace / UnitGroupRolesAssigned return secret values when the unit
-- identity is secret. `value and true or false` would raise a Lua error on a secret,
-- so every result has to go through SafeBool/SafeText first.
function addon:SafeUnitBool(fn, unit)
  if type(fn) ~= "function" then return false end
  local ok, value = pcall(fn, unit or "player")
  if not ok then return false end
  return self:SafeBool(value)
end

function addon:SafeUnitString(fn, unit)
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, unit or "player")
  if not ok then return nil end
  local text = self:SafeText(value)
  if text == "" then return nil end
  return text
end

function SafeNS.IsGroupLeader(unit)
  return addon:SafeUnitBool(UnitIsGroupLeader, unit)
end
function SafeNS.IsGroupAssistant(unit)
  return addon:SafeUnitBool(UnitIsGroupAssistant, unit)
end
function SafeNS.IsRaidOfficer(unit)
  return addon:SafeUnitBool(UnitIsRaidOfficer, unit)
end
function SafeNS.IsAssistantOrLeader(unit)
  if SafeNS.IsGroupLeader(unit) then return true end
  if SafeNS.IsGroupAssistant(unit) then return true end
  return false
end
function SafeNS.UnitInRaid(unit)
  return addon:SafeUnitBool(UnitInRaid, unit)
end

-- Returns a plain, readable role string or nil. Never returns a secret, so the
-- result is safe to use as a table key.
function SafeNS.GroupRole(unit)
  local role = addon:SafeUnitString(UnitGroupRolesAssigned, unit)
  if role == "TANK" or role == "HEALER" or role == "DAMAGER" then return role end
  return nil
end

function SafeNS.UnitClass(unit)
  if type(UnitClass) ~= "function" then return nil, nil end
  local ok, localized, fileName = pcall(UnitClass, unit)
  if not ok then return nil, nil end
  return addon:SafeText(localized), addon:SafeText(fileName)
end

-- 12.1: GetGuildInfo no longer accepts compound unit tokens (raid1target, partypet2...).
-- Passing one now errors, so unsupported tokens are filtered out here.
local COMPOUND_TOKEN_SUFFIX = { target = true, pet = true, focus = true }
function SafeNS.IsSimpleUnitToken(unit)
  if type(unit) ~= "string" or unit == "" then return false end
  local lowered = unit:lower()
  for suffix in pairs(COMPOUND_TOKEN_SUFFIX) do
    if lowered:find(suffix, 1, true) and lowered ~= suffix then return false end
  end
  return true
end

function SafeNS.GuildName(unit)
  if type(GetGuildInfo) ~= "function" then return nil end
  if not SafeNS.IsSimpleUnitToken(unit) then return nil end
  local ok, guildName = pcall(GetGuildInfo, unit)
  if not ok then return nil end
  local text = addon:SafeText(guildName)
  if text == "" then return nil end
  return text
end

-- hooksecurefunc callbacks run inline inside the Blizzard function that was
-- hooked. An error thrown there does not stay contained: it unwinds through
-- Blizzard's own code, so whatever that function had left to do -- laying out
-- panels, showing tabs, filling rows -- never happens. Every callback we install
-- is wrapped so a bug on our side can never blank out someone else's UI.
function addon:WrapHookCallback(fn, label)
  if type(fn) ~= "function" then return nil end
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then
      self._hookFailures = self._hookFailures or {}
      local key = label or "hook"
      self._hookFailures[key] = (self._hookFailures[key] or 0) + 1
      -- Report once per hook so a repeating error cannot spam the chat frame.
      if self.debug and self._hookFailures[key] == 1 then
        print(self.printPrefix, "hook error:", key, tostring(err))
      end
    end
  end
end

function addon:SafeHookOnce(key, target, methodOrFunc, maybeFunc)
  if type(hooksecurefunc) ~= "function" or not key then return false end
  self._safeHookKeys = self._safeHookKeys or {}
  if self._safeHookKeys[key] then return true end

  local ok = false
  if type(target) == "string" and type(methodOrFunc) == "function" then
    ok = pcall(hooksecurefunc, target, self:WrapHookCallback(methodOrFunc, key))
  elseif (type(target) == "table" or type(target) == "userdata") and type(methodOrFunc) == "string" and type(maybeFunc) == "function" then
    local method = self:SafeObjectMethod(target, methodOrFunc)
    if method then
      ok = pcall(hooksecurefunc, target, methodOrFunc, self:WrapHookCallback(maybeFunc, key))
    end
  end

  if ok then self._safeHookKeys[key] = true end
  return ok
end

function addon:SafeEnumerateScrollBoxFrames(scrollBox)
  if not self:SafeCanAccessObject(scrollBox) then return {} end
  local getFrames = self:SafeObjectMethod(scrollBox, "GetFrames")
  if getFrames then
    local ok, frames = pcall(getFrames, scrollBox)
    if ok and self:SafeCanAccessTable(frames) then return frames end
  end
  local enumerateFrames = self:SafeObjectMethod(scrollBox, "EnumerateFrames")
  if enumerateFrames then
    local frames = {}
    local ok = pcall(function()
      for frame in enumerateFrames(scrollBox) do
        if self:SafeCanAccessObject(frame) then frames[#frames + 1] = frame end
      end
    end)
    if ok then return frames end
  end
  return {}
end

function addon:SafeObserveScrollBox(scrollBox, key, onFramesChanged, onScroll)
  if not key or not self:SafeCanAccessObject(scrollBox) then return false end
  self._observedScrollBoxes = self._observedScrollBoxes or {}
  if self._observedScrollBoxes[key] then return true end
  self._observedScrollBoxes[key] = true

  local function callFrames()
    if type(onFramesChanged) == "function" then
      local frames = addon:SafeEnumerateScrollBoxFrames(scrollBox)
      pcall(onFramesChanged, frames, scrollBox)
    end
  end

  local function callScroll(frame)
    if type(onScroll) == "function" then pcall(onScroll, frame or scrollBox) end
    callFrames()
  end

  if ScrollBoxUtil then
    if type(ScrollBoxUtil.OnViewFramesChanged) == "function" then
      pcall(ScrollBoxUtil.OnViewFramesChanged, scrollBox, function(frames) if type(onFramesChanged) == "function" then pcall(onFramesChanged, frames or {}, scrollBox) end end)
    end
    if type(ScrollBoxUtil.OnViewScrollChanged) == "function" then
      pcall(ScrollBoxUtil.OnViewScrollChanged, scrollBox, callScroll)
    end
  end

  local hookScript = self:SafeObjectMethod(scrollBox, "HookScript")
  if hookScript then
    pcall(hookScript, scrollBox, "OnMouseWheel", callScroll)
    pcall(hookScript, scrollBox, "OnShow", callFrames)
    pcall(hookScript, scrollBox, "OnHide", callFrames)
  end
  self:SafeHookOnce(key .. ":FullUpdate", scrollBox, "FullUpdate", callFrames)
  self:SafeHookOnce(key .. ":Update", scrollBox, "Update", callFrames)
  self:SafeHookOnce(key .. ":Refresh", scrollBox, "Refresh", callFrames)

  callFrames()
  return true
end

local function SafeTableValue(self, t, key)
  if not self:SafeCanAccessTable(t) then return nil end
  local ok, value = pcall(function() return t[key] end)
  if not ok or not self:SafeCanRead(value) then return nil end
  return value
end

local function FirstSafeTableValue(self, t, keys)
  if not self:SafeCanAccessTable(t) then return nil end
  for i = 1, #keys do
    local value = SafeTableValue(self, t, keys[i])
    if value ~= nil then return value end
  end
  return nil
end

local function FirstSafeTableText(self, t, keys)
  for i = 1, #keys do
    local text = self:SafeText(SafeTableValue(self, t, keys[i]))
    if text and text ~= "" then return text end
  end
  return nil
end

local function FirstSafeTableNumber(self, t, keys, fallback)
  for i = 1, #keys do
    local n = self:SafeNumber(SafeTableValue(self, t, keys[i]), nil)
    if n ~= nil then return n end
  end
  return fallback
end

local APPLICATION_STATUS_KNOWN = {
  applied = true,
  invited = true,
  failed = true,
  inviteaccepted = true,
  invitedeclined = true,
  cancelled = true,
  declined = true,
  declined_full = true,
  declined_delisted = true,
  timedout = true,
}

function addon:LFG_API_GetApplicants()
  if not (C_LFGList and type(C_LFGList.GetApplicants) == "function") then return {} end
  local values = { pcall(C_LFGList.GetApplicants) }
  if not values[1] then return {} end
  if self:SafeCanAccessTable(values[2]) then
    local out = {}
    for i = 1, #values[2] do
      local id = self:SafeNumber(values[2][i], nil)
      if id then out[#out + 1] = id end
    end
    return out
  end
  local out = {}
  for i = 2, #values do
    local id = self:SafeNumber(values[i], nil)
    if id then out[#out + 1] = id end
  end
  return out
end

function addon:LFG_API_GetApplicantInfo(applicantID)
  applicantID = self:SafeNumber(applicantID, nil)
  if not (C_LFGList and type(C_LFGList.GetApplicantInfo) == "function" and applicantID) then return nil end
  -- Retail returns a table; only the legacy multi-return path needs the
  -- vararg capture below.
  local ok, first = pcall(C_LFGList.GetApplicantInfo, applicantID)
  if not ok then return nil end
  if not self:SafeCanAccessTable(first) then
    return self:_LFG_API_ApplicantInfoPositional(applicantID)
  end

  do
    local t = first
    return {
      applicantID = FirstSafeTableNumber(self, t, { "applicantID", "id" }, applicantID),
      applicationStatus = FirstSafeTableText(self, t, { "applicationStatus", "status" }),
      pendingApplicationStatus = FirstSafeTableText(self, t, { "pendingApplicationStatus" }),
      numMembers = FirstSafeTableNumber(self, t, { "numMembers", "memberCount", "numApplicants" }, nil),
      isNew = self:SafeBool(SafeTableValue(self, t, "isNew")),
      comment = self:SafeText(SafeTableValue(self, t, "comment")),
      displayOrderID = FirstSafeTableNumber(self, t, { "displayOrderID", "displayOrderId" }, nil),
    }
  end
end

-- Legacy/foreign clients where GetApplicantInfo returns positional values.
-- Kept off the hot path so retail never pays for the vararg capture.
function addon:_LFG_API_ApplicantInfoPositional(applicantID)
  local values = { pcall(C_LFGList.GetApplicantInfo, applicantID) }
  if not values[1] then return nil end
  -- The call can succeed while returning nothing at all, which used to produce
  -- a record full of nils. Callers read that as "applicant loaded, nothing to
  -- flag" and cached the verdict, so the row stayed unmarked forever.
  if not self:SafeCanRead(values[2]) then return nil end

  local info = {
    applicantID = self:SafeNumber(values[2], applicantID) or applicantID,
    applicationStatus = self:SafeText(values[3]),
    pendingApplicationStatus = self:SafeText(values[4]),
    numMembers = self:SafeNumber(values[5], nil),
    isNew = self:SafeBool(values[6]),
    comment = self:SafeText(values[7]),
    displayOrderID = self:SafeNumber(values[8], nil),
  }

  if not info.applicationStatus then
    for i = 2, #values do
      local status = self:SafeText(values[i])
      if status and APPLICATION_STATUS_KNOWN[status] then info.applicationStatus = status break end
    end
  end
  if not info.numMembers then
    for i = 2, #values do
      local n = self:SafeNumber(values[i], nil)
      if n and n >= 1 and n <= 5 then info.numMembers = n break end
    end
  end
  return info
end

function addon:LFG_API_GetApplicantMemberInfo(applicantID, memberIndex)
  applicantID = self:SafeNumber(applicantID, nil)
  memberIndex = self:SafeNumber(memberIndex, nil)
  if not (C_LFGList and type(C_LFGList.GetApplicantMemberInfo) == "function" and applicantID and memberIndex and memberIndex >= 1) then return nil end
  -- PERF: this is called for every member of every visible applicant on every
  -- refresh.  Capturing the returns in explicit locals avoids allocating a
  -- vararg table per call.
  local ok, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, v16, v17 =
    pcall(C_LFGList.GetApplicantMemberInfo, applicantID, memberIndex)
  if not ok then return nil end

  local m
  if self:SafeCanAccessTable(v1) then
    local t = v1
    m = {
      name = FirstSafeTableValue(self, t, { "name", "memberName", "playerName", "fullName" }),
      classFilename = FirstSafeTableValue(self, t, { "classFilename", "classFileName", "classFile", "class" }),
      localizedClass = FirstSafeTableValue(self, t, { "localizedClass", "className" }),
      level = SafeTableValue(self, t, "level"),
      itemLevel = FirstSafeTableValue(self, t, { "itemLevel", "ilvl" }),
      honorLevel = SafeTableValue(self, t, "honorLevel"),
      tank = SafeTableValue(self, t, "tank"),
      healer = SafeTableValue(self, t, "healer"),
      damage = FirstSafeTableValue(self, t, { "damage", "damager" }),
      assignedRole = FirstSafeTableValue(self, t, { "assignedRole", "role", "lfgRole" }),
      relationship = SafeTableValue(self, t, "relationship"),
      dungeonScore = FirstSafeTableValue(self, t, { "dungeonScore", "mythicPlusScore", "mplusScore" }),
      pvpItemLevel = SafeTableValue(self, t, "pvpItemLevel"),
      factionGroup = FirstSafeTableValue(self, t, { "factionGroup", "faction" }),
      raceID = FirstSafeTableValue(self, t, { "raceID", "raceId" }),
      specID = FirstSafeTableValue(self, t, { "specID", "specId" }),
      isLeaver = SafeTableValue(self, t, "isLeaver"),
    }
  else
    m = {
      name = v1,
      classFilename = v2,
      localizedClass = v3,
      level = v4,
      itemLevel = v5,
      honorLevel = v6,
      tank = v7,
      healer = v8,
      damage = v9,
      assignedRole = v10,
      relationship = v11,
      dungeonScore = v12,
      pvpItemLevel = v13,
      factionGroup = v14,
      raceID = v15,
      specID = v16,
      isLeaver = v17,
    }
  end

  m.name = self:SafeText(m.name)
  if not m.name then return nil end
  m.classFilename = self:SafeText(m.classFilename)
  m.localizedClass = self:SafeText(m.localizedClass)
  m.level = self:SafeNumber(m.level, nil)
  m.itemLevel = self:SafeNumber(m.itemLevel, nil)
  m.honorLevel = self:SafeNumber(m.honorLevel, nil)
  m.assignedRole = self:SafeText(m.assignedRole)
  m.relationship = self:SafeBool(m.relationship)
  m.dungeonScore = self:SafeNumber(m.dungeonScore, nil)
  m.pvpItemLevel = self:SafeNumber(m.pvpItemLevel, nil)
  m.factionGroup = self:SafeText(m.factionGroup)
  m.raceID = self:SafeNumber(m.raceID, nil)
  m.specID = self:SafeNumber(m.specID, nil)
  m.isLeaver = self:SafeBool(m.isLeaver)
  return m
end


function addon:LFG_API_GetActiveEntryInfo()
  if not (C_LFGList and type(C_LFGList.GetActiveEntryInfo) == "function") then return nil end
  local ok, entry = pcall(C_LFGList.GetActiveEntryInfo)
  if ok and self:SafeCanAccessTable(entry) then return entry end
  return nil
end

function addon:LFG_API_GetActivityInfoTable(activityID)
  activityID = self:SafeNumber(activityID, nil)
  if not activityID then return nil end
  if C_LFGList and type(C_LFGList.GetActivityInfoTable) == "function" then
    local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
    if ok and self:SafeCanAccessTable(info) then
      -- Return an addon-owned snapshot rather than the Blizzard table itself.
      -- This prevents later modules from accidentally comparing a secret field.
      return {
        fullName = FirstSafeTableText(self, info, { "fullName", "name" }),
        shortName = FirstSafeTableText(self, info, { "shortName" }),
        categoryID = FirstSafeTableNumber(self, info, { "categoryID", "categoryId" }, nil),
        groupID = FirstSafeTableNumber(self, info, { "groupID", "groupId" }, nil),
        itemLevel = FirstSafeTableNumber(self, info, { "itemLevel" }, nil),
        filters = FirstSafeTableNumber(self, info, { "filters" }, nil),
        minLevel = FirstSafeTableNumber(self, info, { "minLevel" }, nil),
        maxPlayers = FirstSafeTableNumber(self, info, { "maxPlayers" }, nil),
        displayType = FirstSafeTableNumber(self, info, { "displayType" }, nil),
        orderIndex = FirstSafeTableNumber(self, info, { "orderIndex" }, nil),
        useHonorLevel = self:SafeBool(SafeTableValue(self, info, "useHonorLevel")),
        showQuickJoinToast = self:SafeBool(SafeTableValue(self, info, "showQuickJoinToast")),
        isMythicPlusActivity = self:SafeBool(SafeTableValue(self, info, "isMythicPlusActivity")),
        isRatedPvpActivity = self:SafeBool(SafeTableValue(self, info, "isRatedPvpActivity")),
        isCurrentRaidActivity = self:SafeBool(SafeTableValue(self, info, "isCurrentRaidActivity")),
      }
    end
  end
  if C_LFGList and type(C_LFGList.GetActivityInfo) == "function" then
    local values = { pcall(C_LFGList.GetActivityInfo, activityID) }
    if values[1] then
      return {
        fullName = self:SafeText(values[2]),
        shortName = self:SafeText(values[3]),
        categoryID = self:SafeNumber(values[4], nil),
        groupID = self:SafeNumber(values[5], nil),
        itemLevel = self:SafeNumber(values[6], nil),
        filters = self:SafeNumber(values[7], nil),
        minLevel = self:SafeNumber(values[8], nil),
        maxPlayers = self:SafeNumber(values[9], nil),
        displayType = self:SafeNumber(values[10], nil),
        orderIndex = self:SafeNumber(values[11], nil),
        useHonorLevel = self:SafeBool(values[12]),
        showQuickJoinToast = self:SafeBool(values[13]),
        isMythicPlusActivity = self:SafeBool(values[14]),
        isRatedPvpActivity = self:SafeBool(values[15]),
        isCurrentRaidActivity = self:SafeBool(values[16]),
      }
    end
  end
  return nil
end

function addon:LFG_API_GetApplicantDungeonScoreForListing(applicantID, memberIndex, activityID)
  applicantID = self:SafeNumber(applicantID, nil)
  memberIndex = self:SafeNumber(memberIndex, nil)
  activityID = self:SafeNumber(activityID, nil)
  if not (C_LFGList and type(C_LFGList.GetApplicantDungeonScoreForListing) == "function" and applicantID and memberIndex and memberIndex >= 1 and activityID) then return nil end
  local ok, scoreInfo = pcall(C_LFGList.GetApplicantDungeonScoreForListing, applicantID, memberIndex, activityID)
  if ok and self:SafeCanAccessTable(scoreInfo) then
    return {
      mapScore = FirstSafeTableNumber(self, scoreInfo, { "mapScore" }, 0) or 0,
      bestRunLevel = FirstSafeTableNumber(self, scoreInfo, { "bestRunLevel", "level", "bestLevel" }, 0) or 0,
      finishedSuccess = self:SafeBool(FirstSafeTableValue(self, scoreInfo, { "finishedSuccess", "wasTimed" })),
      bestLevelIncrement = FirstSafeTableNumber(self, scoreInfo, { "bestLevelIncrement", "levelIncrement" }, 0) or 0,
      raw = scoreInfo,
    }
  end
  return nil
end

function addon:LFG_API_GetApplicantBestDungeonScore(applicantID, memberIndex)
  applicantID = self:SafeNumber(applicantID, nil)
  memberIndex = self:SafeNumber(memberIndex, nil)
  if not (C_LFGList and type(C_LFGList.GetApplicantBestDungeonScore) == "function" and applicantID and memberIndex and memberIndex >= 1) then return nil end
  local ok, scoreInfo = pcall(C_LFGList.GetApplicantBestDungeonScore, applicantID, memberIndex)
  if ok and self:SafeCanAccessTable(scoreInfo) then
    return {
      mapScore = FirstSafeTableNumber(self, scoreInfo, { "mapScore" }, 0) or 0,
      mapName = FirstSafeTableText(self, scoreInfo, { "mapName" }),
      bestRunLevel = FirstSafeTableNumber(self, scoreInfo, { "bestRunLevel", "level", "bestLevel" }, 0) or 0,
      finishedSuccess = self:SafeBool(FirstSafeTableValue(self, scoreInfo, { "finishedSuccess", "wasTimed" })),
      bestLevelIncrement = FirstSafeTableNumber(self, scoreInfo, { "bestLevelIncrement", "levelIncrement" }, 0) or 0,
      raw = scoreInfo,
    }
  end
  return nil
end

function addon:LFG_API_GetSearchResultInfo(resultID)
  resultID = self:SafeNumber(resultID, nil)
  if not (C_LFGList and type(C_LFGList.GetSearchResultInfo) == "function" and resultID) then return nil, false end
  local ok, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
  if not ok or not self:SafeCanAccessTable(info) then return nil, ok == true end

  -- Return an addon-owned table containing only values that were proven
  -- readable. Modules may safely compare/concatenate these fields.
  return {
    searchResultID = resultID,
    name = FirstSafeTableText(self, info, { "name" }),
    comment = FirstSafeTableText(self, info, { "comment" }),
    voiceChat = FirstSafeTableText(self, info, { "voiceChat" }),
    leaderName = FirstSafeTableText(self, info, { "leaderName" }),
    numMembers = FirstSafeTableNumber(self, info, { "numMembers" }, nil),
    age = FirstSafeTableNumber(self, info, { "age" }, nil),
    numBNetFriends = FirstSafeTableNumber(self, info, { "numBNetFriends" }, 0) or 0,
    numCharFriends = FirstSafeTableNumber(self, info, { "numCharFriends" }, 0) or 0,
    numGuildMates = FirstSafeTableNumber(self, info, { "numGuildMates" }, 0) or 0,
    censored = self:SafeBool(SafeTableValue(self, info, "censored")),
  }, true
end

function addon:LFG_API_GetSearchResultPlayerInfo(resultID, memberIndex)
  resultID = self:SafeNumber(resultID, nil)
  memberIndex = self:SafeNumber(memberIndex, nil)
  if not (C_LFGList and type(C_LFGList.GetSearchResultPlayerInfo) == "function" and resultID and memberIndex and memberIndex >= 1) then return nil end
  local ok, info = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, memberIndex)
  if not ok or not self:SafeCanAccessTable(info) then return nil end

  local role = FirstSafeTableText(self, info, { "assignedRole", "role", "lfgRole" })
  local classFile = FirstSafeTableText(self, info, { "classFilename", "classFileName", "classFile", "class" })
  return {
    name = FirstSafeTableText(self, info, { "name", "memberName", "playerName", "fullName" }),
    assignedRole = role, role = role, lfgRole = role,
    classFilename = classFile, classFileName = classFile, classFile = classFile,
    className = FirstSafeTableText(self, info, { "className", "localizedClass" }),
    specName = FirstSafeTableText(self, info, { "specName", "specializationName" }),
    isLeader = self:SafeBool(SafeTableValue(self, info, "isLeader")),
  }
end


-- Short-lived LFG API cache. Blizzard LFG fires many update/scroll hooks in bursts;
-- caching avoids repeated protected API calls for the same visible rows.
-- PERF: values and expiry timestamps live in two parallel tables so a cache
-- write does not allocate a wrapper table on every miss.
local GG_NIL = {}
local function CacheNow() return (GetTime and GetTime()) or 0 end
local function CacheBucket(self, name)
  self._lfgAPICache = self._lfgAPICache or {}
  local bucket = self._lfgAPICache[name]
  if not bucket then
    bucket = { values = {}, expires = {} }
    self._lfgAPICache[name] = bucket
  end
  return bucket
end
local function CacheGet(self, name, key)
  local bucket = self._lfgAPICache and self._lfgAPICache[name]
  if not bucket then return false, nil end
  local expires = bucket.expires[key]
  if expires and expires >= CacheNow() then
    local value = bucket.values[key]
    return true, value ~= GG_NIL and value or nil
  end
  if expires then
    bucket.values[key] = nil
    bucket.expires[key] = nil
  end
  return false, nil
end
-- A nil result almost always means "the client has not sent this yet", not
-- "there is nothing here". Caching that under the normal TTL made missing data
-- stick around long after it arrived -- worst of all for activity info, whose
-- 120s TTL left the GG column and role hints blank for two minutes after login.
-- Misses are therefore retried quickly regardless of the caller's TTL.
local CACHE_MISS_TTL = 0.25
local function CacheSet(self, name, key, value, ttl)
  local bucket = CacheBucket(self, name)
  bucket.values[key] = value == nil and GG_NIL or value
  if value == nil then
    bucket.expires[key] = CacheNow() + math.min(ttl or CACHE_MISS_TTL, CACHE_MISS_TTL)
  else
    bucket.expires[key] = CacheNow() + (ttl or 0.6)
  end
  return value
end

function addon:LFG_API_ClearCaches(scope)
  if not self._lfgAPICache then return end
  if not scope or scope == "all" then
    self._lfgAPICache = {}
  elseif scope == "applicants" then
    self._lfgAPICache.applicants = nil
    self._lfgAPICache.applicantInfo = nil
    self._lfgAPICache.memberInfo = nil
    self._lfgAPICache.listingScore = nil
    self._lfgAPICache.bestScore = nil
  elseif scope == "search" then
    self._lfgAPICache.searchInfo = nil
    self._lfgAPICache.searchPlayer = nil
  elseif scope == "activity" then
    self._lfgAPICache.activeEntry = nil
    self._lfgAPICache.activityInfo = nil
  end
end

local _rawGetApplicants = addon.LFG_API_GetApplicants
function addon:LFG_API_GetApplicants()
  local hit, value = CacheGet(self, "applicants", "list")
  if hit then return value or {} end
  return CacheSet(self, "applicants", "list", _rawGetApplicants(self), 0.35) or {}
end

local _rawGetApplicantInfo = addon.LFG_API_GetApplicantInfo
function addon:LFG_API_GetApplicantInfo(applicantID)
  applicantID = self:SafeNumber(applicantID, nil)
  if not applicantID then return nil end
  local key = applicantID
  local hit, value = CacheGet(self, "applicantInfo", key)
  if hit then return value end
  return CacheSet(self, "applicantInfo", key, _rawGetApplicantInfo(self, applicantID), 0.65)
end

local _rawGetApplicantMemberInfo = addon.LFG_API_GetApplicantMemberInfo
function addon:LFG_API_GetApplicantMemberInfo(applicantID, memberIndex)
  applicantID = self:SafeNumber(applicantID, nil)
  memberIndex = self:SafeNumber(memberIndex, nil)
  if not applicantID or not memberIndex or memberIndex < 1 then return nil end
  local key = (applicantID * 8) + memberIndex
  local hit, value = CacheGet(self, "memberInfo", key)
  if hit then return value end
  return CacheSet(self, "memberInfo", key, _rawGetApplicantMemberInfo(self, applicantID, memberIndex), 0.65)
end

local _rawGetActiveEntryInfo = addon.LFG_API_GetActiveEntryInfo
function addon:LFG_API_GetActiveEntryInfo()
  local hit, value = CacheGet(self, "activeEntry", "entry")
  if hit then return value end
  return CacheSet(self, "activeEntry", "entry", _rawGetActiveEntryInfo(self), 0.8)
end

local _rawGetActivityInfoTable = addon.LFG_API_GetActivityInfoTable
function addon:LFG_API_GetActivityInfoTable(activityID)
  activityID = self:SafeNumber(activityID, nil)
  if not activityID then return nil end
  local key = activityID
  local hit, value = CacheGet(self, "activityInfo", key)
  if hit then return value end
  return CacheSet(self, "activityInfo", key, _rawGetActivityInfoTable(self, activityID), 120)
end

local _rawGetListingScore = addon.LFG_API_GetApplicantDungeonScoreForListing
function addon:LFG_API_GetApplicantDungeonScoreForListing(applicantID, memberIndex, activityID)
  applicantID = self:SafeNumber(applicantID, nil)
  memberIndex = self:SafeNumber(memberIndex, nil)
  activityID = self:SafeNumber(activityID, nil)
  if not applicantID or not memberIndex or memberIndex < 1 or not activityID then return nil end
  local key = tostring(applicantID) .. ":" .. tostring(memberIndex) .. ":" .. tostring(activityID)
  local hit, value = CacheGet(self, "listingScore", key)
  if hit then return value end
  return CacheSet(self, "listingScore", key, _rawGetListingScore(self, applicantID, memberIndex, activityID), 2.5)
end

local _rawGetBestScore = addon.LFG_API_GetApplicantBestDungeonScore
function addon:LFG_API_GetApplicantBestDungeonScore(applicantID, memberIndex)
  applicantID = self:SafeNumber(applicantID, nil)
  memberIndex = self:SafeNumber(memberIndex, nil)
  if not applicantID or not memberIndex or memberIndex < 1 then return nil end
  local key = (applicantID * 8) + memberIndex
  local hit, value = CacheGet(self, "bestScore", key)
  if hit then return value end
  return CacheSet(self, "bestScore", key, _rawGetBestScore(self, applicantID, memberIndex), 2.5)
end

local _rawGetSearchResultInfo = addon.LFG_API_GetSearchResultInfo
function addon:LFG_API_GetSearchResultInfo(resultID)
  resultID = self:SafeNumber(resultID, nil)
  if not resultID then return nil, false end
  local key = resultID
  local hit, value = CacheGet(self, "searchInfo", key)
  if hit then return value and value[1], value and value[2] or false end
  local info, ok = _rawGetSearchResultInfo(self, resultID)
  -- The wrapper table is never nil, so the miss TTL has to be applied by hand.
  CacheSet(self, "searchInfo", key, { info, ok }, info and 0.65 or CACHE_MISS_TTL)
  return info, ok
end

local _rawGetSearchResultPlayerInfo = addon.LFG_API_GetSearchResultPlayerInfo
function addon:LFG_API_GetSearchResultPlayerInfo(resultID, memberIndex)
  resultID = self:SafeNumber(resultID, nil)
  memberIndex = self:SafeNumber(memberIndex, nil)
  if not resultID or not memberIndex or memberIndex < 1 then return nil end
  local key = (resultID * 64) + memberIndex
  local hit, value = CacheGet(self, "searchPlayer", key)
  if hit then return value end
  return CacheSet(self, "searchPlayer", key, _rawGetSearchResultPlayerInfo(self, resultID, memberIndex), 0.65)
end


-- Explicit raw/cached LFG namespaces. Legacy addon:LFG_API_* methods remain
-- available, but diagnostics and future modules can choose the intended layer.
addon.LFGRaw = addon.LFGRaw or {}
addon.LFGRaw.GetApplicants = function(...) return _rawGetApplicants(addon, ...) end
addon.LFGRaw.GetApplicantInfo = function(applicantID) return _rawGetApplicantInfo(addon, applicantID) end
addon.LFGRaw.GetApplicantMemberInfo = function(applicantID, memberIndex) return _rawGetApplicantMemberInfo(addon, applicantID, memberIndex) end
addon.LFGRaw.GetActiveEntryInfo = function() return _rawGetActiveEntryInfo(addon) end
addon.LFGRaw.GetActivityInfoTable = function(activityID) return _rawGetActivityInfoTable(addon, activityID) end
addon.LFGRaw.GetApplicantDungeonScoreForListing = function(applicantID, memberIndex, activityID) return _rawGetListingScore(addon, applicantID, memberIndex, activityID) end
addon.LFGRaw.GetApplicantBestDungeonScore = function(applicantID, memberIndex) return _rawGetBestScore(addon, applicantID, memberIndex) end
addon.LFGRaw.GetSearchResultInfo = function(resultID) return _rawGetSearchResultInfo(addon, resultID) end
addon.LFGRaw.GetSearchResultPlayerInfo = function(resultID, memberIndex) return _rawGetSearchResultPlayerInfo(addon, resultID, memberIndex) end

addon.LFG = addon.LFG or {}
addon.LFG.GetApplicants = function() return addon:LFG_API_GetApplicants() end
addon.LFG.GetApplicantInfo = function(applicantID) return addon:LFG_API_GetApplicantInfo(applicantID) end
addon.LFG.GetApplicantMemberInfo = function(applicantID, memberIndex) return addon:LFG_API_GetApplicantMemberInfo(applicantID, memberIndex) end
addon.LFG.GetActiveEntryInfo = function() return addon:LFG_API_GetActiveEntryInfo() end
addon.LFG.GetActivityInfoTable = function(activityID) return addon:LFG_API_GetActivityInfoTable(activityID) end
addon.LFG.GetApplicantDungeonScoreForListing = function(applicantID, memberIndex, activityID) return addon:LFG_API_GetApplicantDungeonScoreForListing(applicantID, memberIndex, activityID) end
addon.LFG.GetApplicantBestDungeonScore = function(applicantID, memberIndex) return addon:LFG_API_GetApplicantBestDungeonScore(applicantID, memberIndex) end
addon.LFG.GetSearchResultInfo = function(resultID) return addon:LFG_API_GetSearchResultInfo(resultID) end
addon.LFG.GetSearchResultPlayerInfo = function(resultID, memberIndex) return addon:LFG_API_GetSearchResultPlayerInfo(resultID, memberIndex) end

-- 12.1 (Curse of Ula'tek): censored listings
--------------------------------------------------
-- LfgSearchResultData and LfgEntryData gained a `censored` flag. While it is set
-- the client withholds name/comment/voiceChat and the row renders as
-- "[Censored] Click to show" until RevealCensoredSearchResult is called.
-- Rule matching on that hidden text would silently return "clean", so every
-- consumer has to ask whether a listing is censored before trusting its text.

function addon:LFG_IsCensorshipSupported()
  return C_LFGList ~= nil and type(C_LFGList.RevealCensoredSearchResult) == "function"
end

function addon:LFG_IsSearchResultCensored(resultID, info)
  if not self:LFG_IsCensorshipSupported() then return false end
  if type(info) ~= "table" then
    info = self:LFG_API_GetSearchResultInfo(resultID)
  end
  if type(info) ~= "table" then return false end
  return self:SafeBool(info.censored)
end

function addon:LFG_IsActiveEntryCensored(entry)
  if not self:LFG_IsCensorshipSupported() then return false end
  if type(entry) ~= "table" then
    entry = self:LFG_API_GetActiveEntryInfo()
  end
  if type(entry) ~= "table" then return false end
  return self:SafeBool(entry.censored)
end

-- True when the player's own listing was censored and they have not yet chosen
-- to edit or keep it. Blizzard blocks listing edits in that state.
function addon:LFG_IsCensoredActiveEntryUnresolved()
  if not (C_LFGList and type(C_LFGList.IsCensoredActiveEntryUnresolved) == "function") then return false end
  local ok, unresolved = pcall(C_LFGList.IsCensoredActiveEntryUnresolved)
  if not ok then return false end
  return self:SafeBool(unresolved)
end

function addon:LFG_RevealSearchResult(resultID)
  resultID = self:SafeNumber(resultID, nil)
  if not resultID or not self:LFG_IsCensorshipSupported() then return false end
  local ok = pcall(C_LFGList.RevealCensoredSearchResult, resultID)
  if ok then self:LFG_ForgetSearchResult(resultID) end
  return ok
end

-- Drops every cached verdict for one search result so the next pass re-reads the
-- now-revealed text instead of the censored placeholder.
function addon:LFG_ForgetSearchResult(resultID)
  resultID = self:SafeNumber(resultID, nil)
  if not resultID then return end

  local cache = self._lfgAPICache
  if cache then
    for _, name in ipairs({ "searchInfo", "searchPlayer" }) do
      local bucket = cache[name]
      if bucket then
        if name == "searchInfo" then
          bucket.values[resultID] = nil
          bucket.expires[resultID] = nil
        else
          for key in pairs(bucket.expires) do
            if type(key) == "number" and math.floor(key / 64) == resultID then
              bucket.values[key] = nil
              bucket.expires[key] = nil
            end
          end
        end
      end
    end
  end

  if self._lfgResultFlagCache then self._lfgResultFlagCache[resultID] = nil end
  if self._lfgResultFlagReasons then self._lfgResultFlagReasons[resultID] = nil end
  if self._lfgResultSocialCache then self._lfgResultSocialCache[resultID] = nil end
  if self._lfgResultSocialReasons then self._lfgResultSocialReasons[resultID] = nil end
end

addon.LFG.IsSearchResultCensored = function(resultID, info) return addon:LFG_IsSearchResultCensored(resultID, info) end
addon.LFG.IsActiveEntryCensored = function(entry) return addon:LFG_IsActiveEntryCensored(entry) end
addon.LFG.IsCensoredActiveEntryUnresolved = function() return addon:LFG_IsCensoredActiveEntryUnresolved() end
addon.LFG.RevealSearchResult = function(resultID) return addon:LFG_RevealSearchResult(resultID) end

-- Blizzard reveals a listing from its own row click; mirror that so our cached
-- verdict for the row is dropped at the same moment the text becomes readable.
function addon:LFG_InstallCensorHooks()
  if self._lfgCensorHooksInstalled then return end
  if not self:LFG_IsCensorshipSupported() then return end
  if type(hooksecurefunc) ~= "function" then return end
  local ok = pcall(hooksecurefunc, C_LFGList, "RevealCensoredSearchResult", self:WrapHookCallback(function(resultID)
    addon:LFG_ForgetSearchResult(resultID)
    if addon.LFG_RetryHighlightSearchResults then
      addon:LFG_RetryHighlightSearchResults(true)
    end
  end, "RevealCensoredSearchResult"))
  self._lfgCensorHooksInstalled = ok and true or false
end

function addon:LFG_API_DebugDump()
  local buckets, entries = 0, 0
  if type(self._lfgAPICache) == "table" then
    for _, bucket in pairs(self._lfgAPICache) do
      buckets = buckets + 1
      if type(bucket) == "table" then for _ in pairs(bucket) do entries = entries + 1 end end
    end
  end
  return { buckets = buckets, entries = entries }
end
