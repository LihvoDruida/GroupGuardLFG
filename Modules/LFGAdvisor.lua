-- GroupGuard LFG — Modules / LFG Advisor
-- Role-fit and visible-list advice inspired by PGFinder role checks, implemented as passive hints only.
local addonName, addon = ...

local ROLE_REMAINING_KEY = {
  TANK = "TANK_REMAINING",
  HEALER = "HEALER_REMAINING",
  DAMAGER = "DAMAGER_REMAINING",
}

local function CanReadValue(value)
  if addon and addon.Safe and addon.Safe.CanReadValue then return addon.Safe.CanReadValue(value) end
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

local function CanAccessTable(value)
  if addon and addon.Safe and addon.Safe.CanAccessTable then return addon.Safe.CanAccessTable(value) end
  return type(value) == "table"
end

local function TableField(t, key)
  if addon and addon.Safe and addon.Safe.TableField then return addon.Safe.TableField(t, key) end
  if not CanAccessTable(t) then return nil end
  local ok, value = pcall(function() return t[key] end)
  if ok and CanReadValue(value) then return value end
  return nil
end

local function SafeNumber(value, fallback)
  if not CanReadValue(value) then return fallback end
  if type(value) == "number" then return value end
  if type(value) == "string" then return tonumber(value) or fallback end
  local ok, n = pcall(tonumber, value)
  return (ok and type(n) == "number") and n or fallback
end

local function GetPlayerRole()
  -- 12.1: UnitGroupRolesAssigned can return a secret; Safe.GroupRole yields a
  -- plain string or nil so the value stays usable as a table key.
  local Safe = addon.Safe
  if Safe and Safe.GroupRole then
    local role = Safe.GroupRole("player")
    if role then return role end
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
  local Safe = addon.Safe
  local inGroup = Safe and Safe.IsInGroup and Safe.IsInGroup() or false
  if not inGroup then return needs end
  local count = addon.GetGroupMemberCount and addon:GetGroupMemberCount() or 0
  local inRaid = Safe and Safe.IsInRaid and Safe.IsInRaid() or false
  for i = 1, count do
    local unit = inRaid and ("raid" .. i) or ("party" .. i)
    if Safe and Safe.UnitExists and Safe.UnitExists(unit) and Safe.GroupRole then
      local role = Safe.GroupRole(unit)
      if role and needs[role] ~= nil then needs[role] = needs[role] + 1 end
    end
  end
  return needs
end

function addon:LFG_GetSearchResultRoleFit(resultID, info)
  if not (self.db and self.db.lfg_role_fit_hints) then return nil end
  if not resultID then return nil end
  local playerRole = GetPlayerRole()
  if not playerRole or not ROLE_REMAINING_KEY[playerRole] then return nil end

  local counts = self.LFG_API_GetSearchResultMemberCounts and self:LFG_API_GetSearchResultMemberCounts(resultID) or nil
  if not CanAccessTable(counts) then return nil end
  local remainingKey = ROLE_REMAINING_KEY[playerRole]
  local remaining = SafeNumber(TableField(counts, remainingKey), nil)
    or SafeNumber(TableField(counts, remainingKey:lower()), nil)
    or SafeNumber(TableField(counts, playerRole .. "Remaining"), nil)
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
  local sp = self.GetLFGSearchFrame and self:GetLFGSearchFrame() or (LFGListFrame and LFGListFrame.SearchPanel)
  local sb = sp and sp.ScrollBox
  local frames = nil
  if sb and addon and addon.SafeEnumerateScrollBoxFrames then
    frames = addon:SafeEnumerateScrollBoxFrames(sb)
  end
  if not frames then
    print((self.printPrefix or "GroupGuard LFG:"), self:Tr("LFG_STATS_NO_RESULTS"))
    return
  end
  local total, fit, full = 0, 0, 0
  for _, row in ipairs(frames) do
    local rid
    local keys = { "resultID", "resultId", "searchResultID", "searchResultId", "id", "ID" }
    if addon and addon.SafeGetElementData and addon.Safe and addon.Safe.TableField then
      local ed = addon:SafeGetElementData(row)
      for i = 1, #keys do
        rid = SafeNumber(addon.Safe.TableField(ed, keys[i]), nil)
        if rid then break end
      end
    end
    if not rid and addon and addon.Safe and addon.Safe.ObjectField then
      for i = 1, #keys do
        rid = SafeNumber(addon.Safe.ObjectField(row, keys[i]), nil)
        if rid then break end
      end
    end
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
