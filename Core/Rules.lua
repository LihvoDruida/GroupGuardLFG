-- GroupGuard LFG — Core / Rules
local addonName, addon = ...

-- =========================================================
-- PvP/BG/Arena gating (fix)
-- =========================================================


addon._instanceLockoutUntil = 0

function addon:EnterInstanceLockout(seconds)
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

function addon:DetectInstanceFlags()
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

local function LowerLite(text)
  text = string.lower(text or "")
  for upper, lower in pairs(CYRILLIC_LOWER_MAP) do
    text = text:gsub(upper, lower)
  end
  return text
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

function addon:RebuildFlagRules()
  self._flagRules = SplitRules(self.db and self.db.flag_rules or "")
end

function addon:RebuildLanguageRules()
  self._languageRules = SplitRules(self.db and self.db.language_detect_rules or "")
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

local function HasLuaPattern(text, pattern)
  if not text or not pattern then return false end
  local ok, pos = pcall(string.find, text, pattern)
  return ok and pos ~= nil
end

function addon:GetLanguageKeywordReason(text)
  if not (self.db and self.db.language_detect_enabled and self.db.language_detect_keywords) then return nil end
  local haystack = NormalizeForRules(text)
  if not haystack then return nil end

  local rules = self._languageRules
  if not rules then
    self:RebuildLanguageRules()
    rules = self._languageRules
  end

  for _, rule in ipairs(rules or {}) do
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

function addon:GetFlagReason(text)
  local haystack = NormalizeForRules(text)
  if not haystack then return false, nil end

  local rules = self._flagRules
  if not rules then
    self:RebuildFlagRules()
    rules = self._flagRules
  end

  for _, rule in ipairs(rules or {}) do
    if rule ~= "" and string.find(haystack, rule, 1, true) then
      return true, self:Tr("REASON_RULE", rule)
    end
  end

  local languageReason = self:GetLanguageKeywordReason(text) or self:GetLanguageScriptReason(text)
  if languageReason then
    return true, languageReason
  end

  return false, nil
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
  self:RebuildFlagRules()
  self:RebuildLanguageRules()
end

