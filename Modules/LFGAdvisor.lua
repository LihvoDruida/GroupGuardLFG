-- GroupGuard LFG — Modules / LFG Advisor
-- Role-fit and visible-list advice inspired by PGFinder role checks, implemented as passive hints only.
local addonName, addon = ...

local ROLE_REMAINING_KEY = {
  TANK = "TANK_REMAINING",
  HEALER = "HEALER_REMAINING",
  DAMAGER = "DAMAGER_REMAINING",
}

local function CanReadValue(value)
  if value == nil then return false end
  if type(canaccessvalue) == "function" then
    local ok, allowed = pcall(canaccessvalue, value)
    if not ok or not allowed then return false end
  end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if ok and secret then return false end
  end
  return true
end

local function SafeNumber(value, fallback)
  if value == nil or not CanReadValue(value) then return fallback end
  if type(value) == "number" then return value end
  if type(value) == "string" then return tonumber(value) or fallback end
  local ok, n = pcall(tonumber, value)
  return (ok and type(n) == "number") and n or fallback
end

local function GetPlayerRole()
  if UnitGroupRolesAssigned then
    local ok, role = pcall(UnitGroupRolesAssigned, "player")
    if ok and role and role ~= "NONE" then return role end
  end
  if GetSpecialization and GetSpecializationRole then
    local okSpec, spec = pcall(GetSpecialization)
    if okSpec and spec then
      local okRole, role = pcall(GetSpecializationRole, spec)
      if okRole and role and role ~= "NONE" then return role end
    end
  end
  return nil
end

local function GetCurrentGroupRoleNeeds()
  local needs = { TANK = 0, HEALER = 0, DAMAGER = 0 }
  if not IsInGroup or not IsInGroup() then return needs end
  local count = (GetNumGroupMembers and GetNumGroupMembers()) or 0
  for i = 1, count do
    local unit = (IsInRaid and IsInRaid()) and ("raid" .. i) or ("party" .. i)
    if UnitExists and UnitExists(unit) and UnitGroupRolesAssigned then
      local ok, role = pcall(UnitGroupRolesAssigned, unit)
      if ok and needs[role] ~= nil then needs[role] = needs[role] + 1 end
    end
  end
  return needs
end

function addon:LFG_GetSearchResultRoleFit(resultID, info)
  if not (self.db and self.db.lfg_role_fit_hints) then return nil end
  if not (C_LFGList and C_LFGList.GetSearchResultMemberCounts and resultID) then return nil end
  local playerRole = GetPlayerRole()
  if not playerRole or not ROLE_REMAINING_KEY[playerRole] then return nil end

  local ok, counts = pcall(C_LFGList.GetSearchResultMemberCounts, resultID)
  if not ok or type(counts) ~= "table" then return nil end
  local remainingKey = ROLE_REMAINING_KEY[playerRole]
  local remaining = SafeNumber(counts[remainingKey] or counts[remainingKey:lower()] or counts[playerRole .. "Remaining"], nil)
  if remaining == nil then return nil end

  local text
  local state
  if remaining > 0 then
    text = self:Tr("LFG_ROLE_FIT_OK", self:Tr("ROLE_" .. playerRole), remaining)
    state = "OK"
  else
    text = self:Tr("LFG_ROLE_FIT_FULL", self:Tr("ROLE_" .. playerRole))
    state = "FULL"
  end

  return {
    role = playerRole,
    remaining = remaining,
    state = state,
    text = text,
  }
end

function addon:LFG_AppendAdvisorTooltipLines(tooltip, resultID, insight, ensureHeader)
  if not (self.db and self.db.lfg_tooltips and self.db.lfg_role_fit_hints) then return end
  if not tooltip or not resultID then return end
  local fit = self:LFG_GetSearchResultRoleFit(resultID, insight)
  if not fit then return end
  if ensureHeader then ensureHeader() end
  if fit.state == "OK" then
    tooltip:AddLine("• " .. fit.text, 0.35, 1.00, 0.48, true)
  else
    tooltip:AddLine("• " .. fit.text, 1.00, 0.62, 0.25, true)
  end
end

function addon:LFG_PrintAdvisorStats()
  local sp = LFGListFrame and LFGListFrame.SearchPanel
  local sb = sp and sp.ScrollBox
  local frames = nil
  if sb then
    if sb.GetFrames then frames = sb:GetFrames() elseif sb.EnumerateFrames then frames = {}; for f in sb:EnumerateFrames() do frames[#frames+1] = f end end
  end
  if not frames then
    print((self.printPrefix or "GroupGuard LFG:"), self:Tr("LFG_STATS_NO_RESULTS"))
    return
  end
  local total, fit, full = 0, 0, 0
  for _, row in ipairs(frames) do
    local rid
    if row.GetElementData then
      local ed = row:GetElementData()
      if type(ed) == "table" then rid = ed.resultID or ed.resultId or ed.id or ed.ID end
    end
    rid = rid or row.resultID or row.resultId or row.id or row.ID
    if rid then
      total = total + 1
      local state = self:LFG_GetSearchResultRoleFit(rid)
      if state and state.state == "OK" then fit = fit + 1 elseif state and state.state == "FULL" then full = full + 1 end
    end
  end
  print((self.printPrefix or "GroupGuard LFG:"), self:Tr("LFG_ADVISOR_STATS_FMT", total, fit, full))
end

SLASH_GROUPGUARDLFGADVISOR1 = "/ggadvisor"
SlashCmdList.GROUPGUARDLFGADVISOR = function()
  if addon and addon.LFG_PrintAdvisorStats then addon:LFG_PrintAdvisorStats() end
end
