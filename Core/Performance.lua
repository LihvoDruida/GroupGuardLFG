-- GroupGuard LFG — Core / Performance
local addonName, addon = ...
local unpack = unpack or table.unpack

addon._debounceTimers = addon._debounceTimers or {}

function addon:RunDebounced(key, delay, callback)
  if not key or type(callback) ~= "function" then return end
  delay = tonumber(delay) or 0

  local old = self._debounceTimers[key]
  if old and old.Cancel then
    old:Cancel()
  end

  self._debounceTimers[key] = C_Timer.NewTimer(delay, function()
    addon._debounceTimers[key] = nil
    callback()
  end)
end

function addon:CancelDebounce(key)
  local old = self._debounceTimers and self._debounceTimers[key]
  if old and old.Cancel then old:Cancel() end
  if self._debounceTimers then self._debounceTimers[key] = nil end
end

function addon:ClearDebounces()
  if not self._debounceTimers then return end
  for key, timer in pairs(self._debounceTimers) do
    if timer and timer.Cancel then timer:Cancel() end
    self._debounceTimers[key] = nil
  end
end

function addon:EnterStartupQuiet(seconds, reason)
  seconds = tonumber(seconds) or tonumber(self.db and self.db.startup_silent_seconds) or 3.0
  if seconds <= 0 then
    self._startupQuietUntil = 0
    return
  end

  self._startupQuietUntil = (GetTime and GetTime() or 0) + seconds
  self._startupQuietReason = reason or "startup"

  -- After quiet mode ends, run a visible refresh.
  -- This prevents alerts from being permanently swallowed after /reload.
  if C_Timer then
    local token = (self._startupQuietToken or 0) + 1
    self._startupQuietToken = token
    C_Timer.After(seconds + 0.08, function()
      if not addon or addon._startupQuietToken ~= token then return end
      addon._startupQuietUntil = 0
      addon._suppressedGroupAlert = nil
      addon._alertActive = false
      if addon.RequestGroupRefresh then addon:RequestGroupRefresh(0) end
      if addon.RequestLFGRefresh then addon:RequestLFGRefresh(0, true, true) end
      if addon.ScheduleFrameMarkerUpdate then addon:ScheduleFrameMarkerUpdate(0.01) end
    end)
  end
end

function addon:IsStartupQuiet()
  return (self._startupQuietUntil or 0) > (GetTime and GetTime() or 0)
end

function addon:BeginActionSequence(kind, seconds)
  self._actionSequence = kind or "action"
  self._actionSequenceUntil = (GetTime and GetTime() or 0) + (tonumber(seconds) or 2.0)
end

function addon:EndActionSequence(kind)
  if not kind or self._actionSequence == kind then
    self._actionSequence = nil
    self._actionSequenceUntil = 0
  end
end

function addon:IsActionSequenceActive(kind)
  local active = self._actionSequence and ((self._actionSequenceUntil or 0) > (GetTime and GetTime() or 0))
  if not active then return false end
  if kind then return self._actionSequence == kind end
  return true
end

function addon:ShouldSuppressAlerts(reason)
  if self:IsStartupQuiet() then return true end
  if self:IsActionSequenceActive() then return true end
  return false
end

function addon:ShouldSuppressActionSpam()
  return self.db and self.db.suppress_action_spam ~= false
end

function addon:PrintActionSummary(key, ...)
  local args = { ... }

  local function formatMessage()
    return self:Tr(key, unpack(args))
  end

  if self:ShouldSuppressActionSpam() then
    local ok, msg = pcall(formatMessage)
    print((self.printPrefix or "GroupGuard LFG:"), ok and msg or tostring(key))
  else
    print((self.printPrefix or "GroupGuard LFG:"), formatMessage())
  end
end
