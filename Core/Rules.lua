-- GroupGuard LFG — Core / Rules
local addonName, addon = ...

-- =========================================================
-- PvP/BG/Arena gating (fix)
-- =========================================================


addon._instanceLockoutUntil = 0

function addon:EnterInstanceLockout(seconds)
  if self.InvalidateInstanceFlags then self:InvalidateInstanceFlags() end
  seconds = tonumber(seconds) or 1.5
  local now = self.SafeGetTime and self:SafeGetTime() or ((GetTime and GetTime()) or 0)
  self._instanceLockoutUntil = now + seconds
end

function addon:IsInInstanceLockout()
  local now = self.SafeGetTime and self:SafeGetTime() or ((GetTime and GetTime()) or 0)
  return (self._instanceLockoutUntil or 0) > now
end

function addon:IsDisabledNow()
  if self:IsInInstanceLockout() then return true end
  return self:IsInRestrictedInstance()
end

-- PERF: IsDisabledNow() sits at the top of the group scan, the LFG tooltip
-- path and every alert, and this used to fire up to four pcalls (including
-- GetInstanceInfo) on each call.  Instance state only changes on zone events,
-- so the result is cached until InvalidateInstanceFlags() is called.
function addon:InvalidateInstanceFlags()
  self._instanceFlagsCached = nil
end

function addon:DetectInstanceFlags()
  local cached = self._instanceFlagsCached
  if cached then return cached[1], cached[2] end
  local inInst, instType = false, nil
  if IsInInstance then
    local ok, inside, kind = pcall(IsInInstance)
    if ok then inInst, instType = inside and true or false, kind end
  end

  local isBG, isArena = false, false

  -- Primary: instType from IsInInstance is usually reliable
  if instType == "pvp" then isBG = true end
  if instType == "arena" then isArena = true end

  -- Secondary: GetInstanceInfo
  if GetInstanceInfo then
    local okInfo, _, instanceType = pcall(GetInstanceInfo)
    if okInfo then
      if instanceType == "pvp" then isBG = true end
      if instanceType == "arena" then isArena = true end
    end
  end

  -- Bonus: C_PvP
  if C_PvP then
    if type(C_PvP.IsBattleground) == "function" then
      local ok, v = pcall(C_PvP.IsBattleground)
      if ok and v then isBG = true end
    end
    if type(C_PvP.IsArena) == "function" then
      local ok, v = pcall(C_PvP.IsArena)
      if ok and v then isArena = true end
    end
  end

  if not inInst then
    isBG, isArena = false, false
  end

  self._instanceFlagsCached = { isBG, isArena }
  return isBG, isArena
end

function addon:IsInRestrictedInstance()
  local isBG, isArena = self:DetectInstanceFlags()

  if isBG and self.db and self.db.disable_in_bg then
    return true
  end
  if isArena and self.db and self.db.disable_in_arena then
    return true
  end
  return false
end


-- =========================================================

local function CanAccess(v)
  if v == nil then return false end

  -- Do not call IsMidnightOrLater here.
  -- In modular builds this helper can be local to another file, and WoW can also expose
  -- different API behavior by client. Direct guarded checks are safer and fast enough.
  if type(canaccessvalue) == "function" then
    local ok, allowed = pcall(canaccessvalue, v)
    if not ok or not allowed then return false end
  end

  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, v)
    if not ok or secret then return false end
  end

  return true
end

function addon:CanAccess(v)
  return CanAccess(v)
end

local CYRILLIC_LOWER_MAP = {
  ["А"]="а", ["Б"]="б", ["В"]="в", ["Г"]="г", ["Д"]="д", ["Е"]="е", ["Ё"]="ё", ["Ж"]="ж",
  ["З"]="з", ["И"]="и", ["Й"]="й", ["К"]="к", ["Л"]="л", ["М"]="м", ["Н"]="н", ["О"]="о",
  ["П"]="п", ["Р"]="р", ["С"]="с", ["Т"]="т", ["У"]="у", ["Ф"]="ф", ["Х"]="х", ["Ц"]="ц",
  ["Ч"]="ч", ["Ш"]="ш", ["Щ"]="щ", ["Ъ"]="ъ", ["Ы"]="ы", ["Ь"]="ь", ["Э"]="э", ["Ю"]="ю", ["Я"]="я",
  ["Є"]="є", ["І"]="і", ["Ї"]="ї", ["Ґ"]="ґ",
}

-- PERF: this used to run one gsub per map entry (37 passes, 37 string
-- allocations) on every name, comment and member the LFG panels scanned.
-- One table-driven gsub does the same work in a single pass, and pure-ASCII
-- text skips it entirely.
local CYRILLIC_BYTES = "[\208-\210][\128-\191]"

local function LowerLite(text)
  if type(text) ~= "string" or text == "" then return "" end
  text = string.lower(text)
  if not string.find(text, "[\208-\210]") then return text end
  return (string.gsub(text, CYRILLIC_BYTES, CYRILLIC_LOWER_MAP))
end

local function NormalizeForRules(value)
  if not value or not CanAccess(value) then return nil end
  local ok, text = pcall(tostring, value)
  if not ok or not text or text == "" then return nil end
  return LowerLite(text)
end

local function SplitRules(text)
  local rules = {}
  text = type(text) == "string" and text or ""
  text = text:gsub("[\r\n;]+", ",")
  for raw in string.gmatch(text, "[^,]+") do
    local rule = raw:gsub("^%s+", ""):gsub("%s+$", "")
    if rule ~= "" then
      rules[#rules + 1] = LowerLite(rule)
    end
  end
  return rules
end

local LANGUAGE_SCRIPT_DETECTORS = {
  { key = "language_script_cyrillic", label = "Cyrillic", pattern = "[\208\209][\128-\191]" },
  { key = "language_script_greek",    label = "Greek",    pattern = "[\206\207][\128-\191]" },
  { key = "language_script_arabic",   label = "Arabic",   pattern = "[\216\217][\128-\191]" },
  { key = "language_script_hebrew",   label = "Hebrew",   pattern = "\215[\144-\191]" },
  { key = "language_script_cjk",      label = "CJK",      pattern = "[\228-\233][\128-\191][\128-\191]" },
  { key = "language_script_kana",     label = "Kana",     pattern = "\227[\129-\131][\128-\191]" },
  { key = "language_script_hangul",   label = "Hangul",   pattern = "[\234-\237][\128-\191][\128-\191]" },
}
addon.LANGUAGE_SCRIPT_DETECTORS = LANGUAGE_SCRIPT_DETECTORS

-- PERF: the same names and comments are re-tested on every scroll tick and
-- every panel refresh.  A bounded memo keyed on the raw text turns repeated
-- passes into a single table lookup.  It is dropped whenever the rules or the
-- language settings change.
local RULE_MEMO_LIMIT = 512
addon._ruleMemo = addon._ruleMemo or {}
addon._ruleMemoCount = addon._ruleMemoCount or 0

function addon:ClearRuleMemo()
  self._ruleMemo = {}
  self._ruleMemoCount = 0
end

-- The memo caches a full verdict, so it must be dropped when ANY input to that
-- verdict changes -- not only the rule text, but the language toggles and every
-- script detector checkbox too. Skipping that would trade a stale-results bug
-- for the performance win, so all of them go into one signature.
function addon:GetRuleSignature()
  local db = self.db
  if not db then return "" end
  local parts = {
    tostring(db.flag_rules or ""),
    tostring(db.language_detect_rules or ""),
    db.language_detect_enabled and "1" or "0",
    db.language_detect_keywords and "1" or "0",
    db.language_detect_scripts and "1" or "0",
  }
  for i = 1, #LANGUAGE_SCRIPT_DETECTORS do
    parts[#parts + 1] = db[LANGUAGE_SCRIPT_DETECTORS[i].key] and "1" or "0"
  end
  return table.concat(parts, "\1")
end

function addon:RebuildFlagRules(force)
  local source = self.db and self.db.flag_rules or ""
  if not force and self._flagRules and self._flagRulesSource == source then return end
  self._flagRules = SplitRules(source)
  self._flagRulesSource = source
end

function addon:RebuildLanguageRules(force)
  local source = self.db and self.db.language_detect_rules or ""
  if not force and self._languageRules and self._languageRulesSource == source then return end
  self._languageRules = SplitRules(source)
  self._languageRulesSource = source
end

local function HasLuaPattern(text, pattern)
  if not text or not pattern then return false end
  local ok, pos = pcall(string.find, text, pattern)
  return ok and pos ~= nil
end

-- `haystack` lets callers that already normalized the text skip a second
-- lowercase pass over the same string on every clean listing.
function addon:GetLanguageKeywordReason(text, haystack)
  if not (self.db and self.db.language_detect_enabled and self.db.language_detect_keywords) then return nil end
  haystack = haystack or NormalizeForRules(text)
  if not haystack then return nil end

  local rules = self._languageRules
  if not rules then
    self:RebuildLanguageRules()
    rules = self._languageRules
  end
  if not rules then return nil end

  for i = 1, #rules do
    local rule = rules[i]
    if rule ~= "" and string.find(haystack, rule, 1, true) then
      return self:Tr("REASON_LANGUAGE", rule)
    end
  end
  return nil
end

function addon:GetLanguageScriptReason(text)
  if not (self.db and self.db.language_detect_enabled and self.db.language_detect_scripts) then return nil end
  if not text or not CanAccess(text) then return nil end

  -- UTF-8 byte-range signals. These are script hints only, not nationality detection.
  for _, detector in ipairs(LANGUAGE_SCRIPT_DETECTORS) do
    if self.db[detector.key] and HasLuaPattern(text, detector.pattern) then
      return self:Tr("REASON_SCRIPT", detector.label)
    end
  end
  return nil
end

function addon:IsLanguageFlaggedText(text)
  return (self:GetLanguageKeywordReason(text) ~= nil) or (self:GetLanguageScriptReason(text) ~= nil)
end

local FALSE_RESULT = { false }

function addon:GetFlagReason(text)
  local memoKey = type(text) == "string" and text ~= "" and text or nil
  if memoKey then
    local memo = self._ruleMemo[memoKey]
    if memo then return memo[1], memo[2] end
  end

  local haystack = NormalizeForRules(text)
  if not haystack then return false, nil end

  local rules = self._flagRules
  if not rules then
    self:RebuildFlagRules()
    rules = self._flagRules
  end

  local flagged, reason = false, nil
  for i = 1, #rules do
    local rule = rules[i]
    if rule ~= "" and string.find(haystack, rule, 1, true) then
      flagged, reason = true, self:Tr("REASON_RULE", rule)
      break
    end
  end

  if not flagged then
    reason = self:GetLanguageKeywordReason(text, haystack) or self:GetLanguageScriptReason(text)
    if reason then flagged = true end
  end

  if memoKey then
    if self._ruleMemoCount >= RULE_MEMO_LIMIT then self:ClearRuleMemo() end
    if self._ruleMemo[memoKey] == nil then self._ruleMemoCount = self._ruleMemoCount + 1 end
    self._ruleMemo[memoKey] = flagged and { true, reason } or FALSE_RESULT
  end

  return flagged, reason
end

function addon:IsFlaggedText(text)
  local flagged = self:GetFlagReason(text)
  return flagged and true or false
end

addon.IsGroupGuardFlaggedText = addon.IsFlaggedText

function addon:GetFontForText(text)
  return "Fonts\\ARIALN.TTF"
end


function addon:RebuildCaches()
  self.realm_name = GetRealmName() or self.realm_name or ""
  self:InvalidateInstanceFlags()
  self:RebuildFlagRules()
  self:RebuildLanguageRules()

  -- Only a real change to any verdict input drops the memo. Zoning, which is
  -- what calls this most often, now leaves the warmed cache intact.
  local signature = self:GetRuleSignature()
  if signature ~= self._ruleSignature then
    self._ruleSignature = signature
    self:ClearRuleMemo()
  end
end

