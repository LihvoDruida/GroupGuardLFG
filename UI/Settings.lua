local addonName, addon = ...


local SETTINGS_UK = {
  ["Saved"] = "Збережено",
  ["Apply"] = "Застосувати",

  ["GroupGuard LFG — Settings"] = "GroupGuard LFG — Налаштування",
  ["GroupGuard LFG — Settings (Fallback)"] = "GroupGuard LFG — Налаштування (Fallback)",
  ["Version: %s — %s"] = "Версія: %s — %s",

  ["Settings are grouped by how the addon works:\n• General — where the addon works and what to do on a match.\n• LFG applications — manual/auto decline and list highlighting.\n• Raid Assist — automatic raid assistant assignment.\n• Rules — keywords, guild names and language/text signals.\n• Notifications — banner, sound, flash and frame markers.\n• Compatibility — PGF, debounce and technical UI refresh."] =
    "Налаштування згруповані за логікою роботи аддона:\n• Основне — де працює аддон і що робити при збігу.\n• LFG-заявки — ручне/авто-відхилення та підсвітка списків.\n• Raid Assist — автоматична видача помічника рейду.\n• Правила — ключові слова, гільдії та мовні/текстові сигнали.\n• Сповіщення — банер, звук, спалах і мітки на фреймах.\n• Сумісність — PGF, debounce і технічне оновлення UI.",

  ["Interface language:"] = "Мова інтерфейсу:",
  ["Default is Game client language. Change takes effect immediately for addon messages; reopen settings to refresh all labels."] =
    "За замовчуванням використовується мова клієнта гри. Після зміни мови UI автоматично перезавантажиться.",

  ["General"] = "Основне",
  ["1. General"] = "1. Основне",
  ["Base behavior: where to scan, when to stay silent, and what to do on a match."] =
    "Базова поведінка аддона: де сканувати, коли мовчати й що робити при збігу.",
  ["Scope"] = "Де працює",
  ["Scan party"] = "Сканувати party",
  ["Scan raid"] = "Сканувати raid",
  ["Disable in Battlegrounds / BG"] = "Вимкнути на Полях бою / BG",
  ["Disable in Arenas"] = "Вимкнути на Аренах",
  ["Actions on match"] = "Дії при збігу",
  ["Show “Remove from group” button in the banner"] = "Показувати кнопку «Прибрати з групи» у банері",
  ["Automatically leave the group after detection"] = "Автоматично виходити з групи після виявлення",
  ["Confirm leaving with a popup"] = "Підтверджувати вихід спливаючим вікном",
  ["The banner can show action buttons both for removing flagged players and for leaving the current party/raid. LFG applications are handled by the separate button on the Premade Groups page."] =
    "У банері можуть з'являтися кнопки як для видалення позначених гравців, так і для виходу з поточної групи/рейду. LFG-заявки обробляє окрема кнопка на сторінці Premade Groups.",

  ["LFG applications"] = "LFG-заявки",
  ["2. LFG applications"] = "2. LFG-заявки",
  ["This page only controls LFG applications and LFG search. It does not remove players from party/raid."] =
    "Ця сторінка керує тільки LFG-заявками та LFG-пошуком. Вона не видаляє людей із party/raid.",
  ["Application decline"] = "Відхилення заявок",
  ["Automatically decline marked LFG applications when you have permission"] =
    "Автоматично відхиляти позначені LFG-заявки, якщо є права",
  ["Notify about auto-declines"] = "Сповіщати про авто-відхилення",
  ["Show the manual “Decline LFG applications” fallback button"] =
    "Показувати ручну fallback-кнопку «Відхилити LFG-заявки»",
  ["Auto-decline runs only for marked applications and only while you can manage the active listing. The manual button remains available for applicants that Blizzard does not allow to decline automatically."] =
    "Авто-відхилення працює лише для позначених заявок і тільки коли ти можеш керувати активним оголошенням. Ручна кнопка залишається fallback-дією для заявок, які Blizzard не дозволяє відхилити автоматично.",
  ["Auto-decline limit per pass:"] = "Ліміт авто-відхилень за один прохід:",
  ["Delay between auto-declines (sec):"] = "Затримка між авто-відхиленнями (сек):",
  ["Manual LFG button text:"] = "Текст ручної LFG-кнопки:",
  ["Decline LFG applications (%d)"] = "Відхилити LFG-заявки (%d)",
  ["LFG highlighting"] = "Підсвітка LFG",
  ["Highlight marked applications in the list"] = "Підсвічувати позначені заявки у списку",
  ["Check LFG members against rules"] = "Перевіряти учасників LFG за правилами",
  ["Show GroupGuard tooltip in LFG"] = "Показувати GroupGuard tooltip у LFG",
  ["Show reason in tooltip"] = "Показувати причину в tooltip",
  ["Show search result age, role composition and class breakdown in tooltip"] =
    "Показувати в tooltip вік оголошення, склад ролей і розбивку класів",
  ["Mute duplicate applicant ping while auto-decline is running"] =
    "Приглушувати зайвий звук нової заявки під час авто-відхилення",
  ["LFG tooltip insights are lightweight and do not replace Raider.IO, PGF or sorter addons. Hold Shift on a search result tooltip to show class breakdown."] =
    "LFG-інсайти легкі й не замінюють Raider.IO, PGF або сортери. Утримуй Shift на tooltip результату пошуку, щоб побачити розбивку класів.",
  ["Show role-fit hints for your current spec"] = "Показувати підказки відповідності ролі для поточної спеціалізації",
  ["Show realm/locale hints in LFG tooltips"] = "Показувати підказки реалму/локалі в LFG tooltip",
  ["Show compact realm badges on search rows"] = "Показувати компактні бейджі реалму на рядках пошуку",
  ["Hide realm badge when the leader realm matches your locale"] = "Ховати бейдж реалму, якщо реалм лідера збігається з твоєю локаллю",

  ["Show whether your current role fits the searched group"] = "Показувати, чи твоя поточна роль підходить знайденій групі",
  ["Show technical realm/locale hints in search tooltips"] = "Показувати технічні підказки реалму/локалі в tooltip пошуку",
  ["Show compact realm badges on LFG search rows"] = "Показувати компактні бейджі реалму на LFG-рядках пошуку",
  ["Only show realm hints when the realm locale differs from yours"] = "Показувати підказки реалму тільки коли локаль реалму відрізняється від твоєї",
  ["Show compact role/ilvl/score chips on applicant rows"] = "Показувати двострокові картки заявок з ролями, ilvl, M+, рівнями та коментарем",
  ["Show two-line applicant cards on applicant rows"] = "Показувати двострокові картки заявок на рядках учасників",
  ["Show applicant composition summary in tooltips"] = "Показувати підсумок складу заявки в tooltip",
  ["Refresh applicant list after cancelled/timed out/invited applications"] = "Оновлювати список заявок після cancelled/timed out/invited статусів",
  ["LFG insights are passive UI hints and do not replace Raider.IO, PGF or sorter addons. Realm locale is a realm-list hint only, not a player nationality check. Hold Shift on tooltips to show deeper breakdowns."] =
    "LFG-інсайти — пасивні UI-підказки й не замінюють Raider.IO, PGF або сортери. Локаль реалму — лише підказка зі списку реалмів, не перевірка національності гравця. Утримуй Shift у tooltip, щоб побачити детальнішу розбивку.",

  ["Friends / guild in LFG"] = "Друзі / гільдія у LFG",
  ["Ignore friends even if they match filters"] = "Не реагувати на друзів, навіть якщо вони підпадають під фільтр",
  ["Ignore your guild members even if they match filters"] =
    "Не реагувати на учасників твоєї гільдії, навіть якщо вони підпадають під фільтр",
  ["Detect friends/guild in LFG and highlight them with different colors"] =
    "Виявляти друзів/гільдію у LFG і підсвічувати іншими кольорами",
  ["Highlight friends in LFG in blue"] = "Підсвічувати друзів у LFG синім",
  ["Highlight guild members in LFG in green"] = "Підсвічувати учасників гільдії у LFG зеленим",
  ["Friends/guild are not shown on party/raid frames. Social colors work only in LFG lists and tooltips."] =
    "Друзі/гільдія не показуються на party/raid фреймах. Соціальні кольори працюють тільки в LFG-списках і tooltip-ах.",

  ["Raid Assist"] = "Raid Assist",
  ["3. Raid Assist"] = "3. Raid Assist",
  ["Automatically grants raid assistant only when you are the raid leader. Works only in raid, not party."] =
    "Автоматично видає помічника рейду тільки коли ти рейд-лідер. Працює лише в raid, не в party.",
  ["Enable automatic raid assistant assignment"] = "Увімкнути авто-видачу помічника в рейді",
  ["Automatically grant assistant to selected ranks / officers"] = "Автоматично давати помічника вибраним рангам / офіцерам",
  ["Print who received assistant in chat"] = "Писати в чат, кому видано помічника",
  ["Guild ranks that should automatically receive assistant:"] = "Ранги гільдії, яким автоматично видавати помічника:",
  ["Additional assistant names, comma-separated:"] = "Додаткові імена для помічника через кому:",
  ["Ranks are loaded from the guild roster. You can select multiple ranks. Names can be written without realm: Khayen, Forchun."] =
    "Ранги завантажуються з guild roster. Можна вибрати кілька рангів. Імена можна писати без realm: Khayen, Forchun.",
  ["Refresh assistants now"] = "Оновити помічників зараз",
  ["Refresh ranks"] = "Оновити ранги",
  ["Guild ranks are not loaded yet — open Guild/Roster or click Refresh ranks"] =
    "Ранги ще не завантажені — відкрий Guild/Roster або натисни «Оновити ранги»",

  ["Filter rules"] = "Правила фільтрів",
  ["4. Rules"] = "4. Правила",
  ["Neutral marking rules: keywords, names, guilds and optional language/text signals."] =
    "Нейтральні правила позначення: ключові слова, імена, гільдії та опціональні мовні/текстові сигнали.",
  ["What to scan"] = "Що перевіряти",
  ["Check player names in party/raid"] = "Перевіряти імена гравців у party/raid",
  ["Check guild names in party/raid"] = "Перевіряти назви гільдій у party/raid",
  ["Keywords / names / guilds, comma-separated:"] = "Ключові слова / імена / гільдії через кому:",
  ["Example: boost, wts, carry, gdkp, spam, guild-name, player-name"] =
    "Приклад: boost, wts, carry, gdkp, spam, назва-гільдії, ім'я-гравця",
  ["Language auto-detect"] = "Мовний автодетект",
  ["Enable language auto-detect"] = "Увімкнути мовний автодетект",
  ["Use language keyword phrases"] = "Використовувати мовні ключові фрази",
  ["Detect UTF-8 scripts"] = "Виявляти UTF-8 скрипти",
  ["Scripts for UTF-8 detection"] = "Скрипти для UTF-8 перевірки",
  ["Cyrillic"] = "Кирилиця",
  ["Greek"] = "Грецький",
  ["Arabic"] = "Арабський",
  ["Hebrew"] = "Іврит",
  ["CJK"] = "CJK",
  ["Kana"] = "Kana",
  ["Hangul"] = "Hangul",
  ["Script detection may produce false positives. Cyrillic includes Ukrainian, Russian, Bulgarian, Serbian, etc."] =
    "Скрипт-детект може давати хибні спрацювання. Кирилиця включає українську, російську, болгарську, сербську тощо.",
  ["Language phrases, comma-separated:"] = "Мовні фрази через кому:",

  ["Notifications and appearance"] = "Сповіщення та вигляд",
  ["5. Notifications"] = "5. Сповіщення",
  ["Banner, sound, screen flash and red marker on party/raid frames."] =
    "Банер, звук, спалах екрана та червона мітка на party/raid фреймах.",
  ["Banner and visuals"] = "Банер і візуал",
  ["Show compact notification"] = "Показувати компактне сповіщення",
  ["Screen flash"] = "Спалах екрана",
  ["Play sound"] = "Відтворювати звук",
  ["Show centered red marker on party/raid frames"] = "Показувати червону мітку по центру party/raid фреймів",
  ["Marker is centered on the character frame and shows only real filter matches. Friends/guild are not highlighted on party/raid frames."] =
    "Мітка ставиться по центру фрейма персонажа і показує тільки реальний фільтр-збіг. Друзі/гільдія на party/raid фреймах не підсвічуються.",
  ["Banner duration (sec):"] = "Тривалість банера (сек):",
  ["Sound cooldown (sec):"] = "Cooldown звуку (сек):",
  ["Flash cooldown (sec):"] = "Cooldown спалаху (сек):",
  ["Sound"] = "Звук",
  ["Sound source:"] = "Джерело звуку:",
  ["System RAID_WARNING"] = "Системний RAID_WARNING",
  ["Custom file"] = "Власний файл",
  ["Custom sound path:"] = "Шлях до власного звуку:",
  ["Default bundled sound is Media\\warn.ogg. Put custom sound files into Interface\\AddOns\\GroupGuardLFG\\Media and use /reload."] =
    "Стандартний звук: Media\\warn.ogg. Власні звуки клади в Interface\\AddOns\\GroupGuardLFG\\Media і зроби /reload.",
  ["Detection test"] = "Тест виявлення",
  ["Auto-decline test"] = "Тест авто-відхилення",
  ["Auto-declined: 2"] = "Авто-відхилено: 2",
  ["Comment — test"] = "Коментар — test",
  ["Test banner."] = "Тестовий банер.",

  ["Compatibility and technical"] = "Сумісність і технічне",
  ["6. Compatibility"] = "6. Сумісність",
  ["Technical UI refresh parameters, Premade Groups Filter compatibility and manual synchronization."] =
    "Технічні параметри оновлення UI, сумісність з Premade Groups Filter та ручна синхронізація.",
  ["Deeper compatibility with Premade Groups Filter"] = "Глибша сумісність з Premade Groups Filter",
  ["Debounce group scan (sec):"] = "Debounce group scan (сек):",
  ["Debounce LFG scan (sec):"] = "Debounce LFG scan (сек):",
  ["Silent startup after ReloadUI (sec):"] = "Тихий запуск після ReloadUI (сек):",
  ["Suppress intermediate action spam"] = "Приглушити проміжні повідомлення дій",
  ["Synchronize UI now"] = "Синхронізувати UI зараз",
}

local function LS(text)
  if text == nil then return text end
  if addon and addon.GetUILanguage and addon:GetUILanguage() == "ukUA" then
    return SETTINGS_UK[text] or text
  end
  return text
end

local function LSF(text, ...)
  local translated = LS(text)
  if select("#", ...) > 0 then
    local ok, result = pcall(string.format, translated, ...)
    if ok then return result end
  end
  return translated
end

--------------------------------------------------
-- Утиліти
--------------------------------------------------

local function FS(parent, template, text)
  local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
  fs:SetJustifyH("LEFT")
  if text then fs:SetText(LS(text)) end
  return fs
end

local function showSavedHint(parent, anchorTo)
  if parent._savedHint then parent._savedHint:Hide() end
  local hint = parent:CreateFontString(nil, "ARTWORK", "GameFontGreenSmall")
  hint:SetText(LS("Saved"))
  hint:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 2, -4)
  hint:SetAlpha(1)
  parent._savedHint = hint
  if C_Timer and C_Timer.After then C_Timer.After(1.2, function() if hint then hint:Hide() end end) end
end

local function AddCheck(parent, anchor, label, key, onToggle)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  if anchor then
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
  else
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -4)
  end

  cb.text = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  cb.text:SetPoint("LEFT", cb, "RIGHT", 0, 1)
  cb.text:SetWidth(535)
  cb.text:SetJustifyH("LEFT")
  cb.text:SetText(LS(label))

  if not addon.db then addon:EnsureDB() end
  cb:SetChecked(addon.db[key] and true or false)

  cb:SetScript("OnClick", function(self)
    addon.db[key] = self:GetChecked() and true or false
    showSavedHint(parent, cb.text)
    if onToggle then
      onToggle()
    elseif addon.SyncSettingsState then
      addon:SyncSettingsState("checkbox:" .. tostring(key))
    end
  end)

  return cb
end

local function AddSlider(parent, anchor, label, minV, maxV, step, getFunc, setFunc, sliderName, width)
  local labelFS = FS(parent, "GameFontNormal", label)
  if anchor then
    labelFS:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
  else
    labelFS:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -4)
  end

  local name = sliderName or (parent:GetName() and (parent:GetName() .. "_Slider_" .. tostring(math.random(1000000)))) or ("GroupGuardLFG_Slider_" .. tostring(math.random(1000000)))
  local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", labelFS, "BOTTOMLEFT", 0, -8)
  slider:SetMinMaxValues(minV, maxV)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)
  slider:SetWidth(width or 300)

  local low  = _G[name .. "Low"]
  local high = _G[name .. "High"]
  local text = _G[name .. "Text"]
  if low  then low:SetText(tostring(minV)) end
  if high then high:SetText(tostring(maxV)) end
  if text then text:SetText("") end

  slider:SetScript("OnValueChanged", function(self, value)
    setFunc(value)
    showSavedHint(parent, labelFS)
  end)

  -- первинна ініціалізація
  local ok, v = pcall(getFunc)
  if not ok then v = minV end
  slider:SetValue(v or minV)

  slider:HookScript("OnShow", function(self)
    local ok2, v2 = pcall(getFunc)
    if not ok2 then v2 = minV end
    self:SetValue(v2 or minV)
  end)

  return slider, labelFS
end

local function AddEdit(parent, anchor, labelText, getter, onApply, numeric)
  -- Row-based layout prevents labels/editboxes from overlapping when the returned
  -- first value is used as the anchor for the next option.
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(560, 66)
  if anchor then
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
  else
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -4)
  end

  local label = FS(row, "GameFontNormal", labelText)
  label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
  label:SetJustifyH("LEFT")

  local edit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
  edit:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -28)
  edit:SetSize(410, 22)
  edit:SetAutoFocus(false)
  if numeric then edit:SetNumeric(true) end

  local function init()
    if not addon.db then addon:EnsureDB() end
    local v = getter() or ""
    if numeric then
      edit:SetNumber(tonumber(v) or 0)
      edit:SetCursorPosition(0)
    else
      edit:SetText(tostring(v))
      edit:SetCursorPosition(0)
    end
  end

  init()

  local apply = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  apply:SetSize(104, 22)
  apply:SetPoint("LEFT", edit, "RIGHT", 10, 0)
  apply:SetText(LS("Apply"))
  apply:SetScript("OnClick", function()
    onApply(edit:GetText())
    edit:SetCursorPosition(0)
    edit:ClearFocus()
    showSavedHint(parent, apply)
    if addon.SyncSettingsState then addon:SyncSettingsState("edit:" .. tostring(labelText)) end
  end)

  row.label = label
  row.edit = edit
  row.apply = apply
  return row, edit, apply
end

local function CreateScrolledPage(name, width, height, titleText)
  local page = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  page:SetSize(width, height)
  page:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
  })

  local scroll = CreateFrame("ScrollFrame", name .. "Scroll", page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", -32, 8)

  local child = CreateFrame("Frame", name .. "Child", scroll)
  child:SetWidth(width - 40)
  child:SetHeight(math.max(height - 16, 1550))
  scroll:SetScrollChild(child)

  local title = FS(child, "GameFontNormalLarge", titleText)
  title:SetPoint("TOPLEFT", 16, -12)

  return page, child, title
end

local function SyncAll(reason)
  if addon and addon.SyncSettingsState then
    addon:SyncSettingsState(reason or "settings")
  else
    if addon and addon.RebuildCaches then addon:RebuildCaches() end
    if addon and addon.ScanGroupOffenders then addon:ScanGroupOffenders() end
    if addon and addon.LFG_ScanApplicants then addon:LFG_ScanApplicants() end
    if addon and addon.LFG_UpdateButton then addon:LFG_UpdateButton() end
    if addon and addon.LFG_RetryHighlightSearchResults then addon:LFG_RetryHighlightSearchResults() end
    if addon and addon.UpdateFrameMarkers then addon:UpdateFrameMarkers() end
  end
end

local function AddSection(parent, anchor, text)
  local fs = FS(parent, "GameFontNormal", text)
  if anchor then
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -22)
  else
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -14)
  end
  fs:SetTextColor(1.0, 0.82, 0.28)
  return fs
end

local function AddNote(parent, anchor, text, offsetX, offsetY)
  local fs = FS(parent, "GameFontDisableSmall", text)
  fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", offsetX or 0, offsetY or -8)
  fs:SetPoint("RIGHT", parent, "RIGHT", -24, 0)
  fs:SetJustifyH("LEFT")
  return fs
end

local function CreateMultiRankDropdown(parent, anchor, labelText)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(560, 76)
  row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -18)

  local label = FS(row, "GameFontNormal", labelText)
  label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  label:SetPoint("RIGHT", row, "RIGHT", -24, 0)
  label:SetJustifyH("LEFT")

  local dropdownName = "GroupGuardLFGRaidAssistRankDropdown"
  local dropdown = CreateFrame("Frame", dropdownName, row, "UIDropDownMenuTemplate")
  dropdown:SetPoint("TOPLEFT", row, "TOPLEFT", -16, -22)

  local function refreshText()
    if addon.GetRaidAssistSelectedRankText then
      UIDropDownMenu_SetText(dropdown, addon:GetRaidAssistSelectedRankText())
    else
      UIDropDownMenu_SetText(dropdown, addon and addon.Tr and addon:Tr("NONE_SELECTED") or "None selected")
    end
  end

  UIDropDownMenu_SetWidth(dropdown, 285)
  UIDropDownMenu_Initialize(dropdown, function(self, level)
    if not addon.db then addon:EnsureDB() end
    if GuildRoster then pcall(GuildRoster) end
    if addon.RebuildGuildCache then addon:RebuildGuildCache(true) end

    local opts = addon.GetGuildRankOptions and addon:GetGuildRankOptions() or {}
    if #opts == 0 then
      local info = UIDropDownMenu_CreateInfo()
      info.text = LS("Guild ranks are not loaded yet — open Guild/Roster or click Refresh ranks")
      info.disabled = true
      UIDropDownMenu_AddButton(info, level)
      return
    end

    local set = addon.GetRaidAssistSelectedRankSet and addon:GetRaidAssistSelectedRankSet() or {}
    for _, opt in ipairs(opts) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = ("[%d] %s"):format(opt.index or 0, opt.name or "?")
      info.arg1 = opt.index
      info.keepShownOnClick = true
      info.isNotRadio = true
      info.checked = set[opt.index] and true or false
      info.func = function(_, rankIndex, _, checked)
        if addon.SetRaidAssistRankSelected then
          addon:SetRaidAssistRankSelected(rankIndex, checked and true or false)
        end
        addon._raidAssistRankSet = nil
        addon._raidAssistRankSetText = nil
        refreshText()
        SyncAll("raid_assist_rank_dropdown")
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  refreshText()

  local reload = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  reload:SetSize(128, 23)
  reload:SetPoint("LEFT", dropdown, "RIGHT", -8, 2)
  reload:SetText(LS("Refresh ranks"))
  reload:SetScript("OnClick", function()
    if GuildRoster then pcall(GuildRoster) end
    if addon.RebuildGuildCache then addon:RebuildGuildCache(true) end
    refreshText()
    SyncAll("raid_assist_rank_refresh")
  end)

  row.dropdown = dropdown
  row.reloadButton = reload
  row.refreshText = refreshText
  return row, label, reload
end

local function CreateLanguageDropdown(parent, anchor)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(560, 90)
  row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -18)

  local label = FS(row, "GameFontNormal", LS("Interface language:"))
  label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)

  local dropdown = CreateFrame("Frame", "GroupGuardLFGLanguageDropdown", row, "UIDropDownMenuTemplate")
  dropdown:SetPoint("TOPLEFT", row, "TOPLEFT", -16, -22)
  UIDropDownMenu_SetWidth(dropdown, 260)

  local function LanguageText(value)
    if value == "enUS" then return addon:Tr("UI_LANG_EN") end
    if value == "ukUA" then return addon:Tr("UI_LANG_UK") end
    return addon:Tr("UI_LANG_AUTO")
  end

  local function refreshText()
    if not addon.db then addon:EnsureDB() end
    UIDropDownMenu_SetText(dropdown, LanguageText(addon.db.ui_language or "auto"))
  end

  UIDropDownMenu_Initialize(dropdown, function(self, level)
    local options = {
      { value = "auto", text = addon:Tr("UI_LANG_AUTO") },
      { value = "enUS", text = addon:Tr("UI_LANG_EN") },
      { value = "ukUA", text = addon:Tr("UI_LANG_UK") },
    }

    for _, opt in ipairs(options) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = opt.text
      info.arg1 = opt.value
      info.checked = (addon.db and addon.db.ui_language or "auto") == opt.value
      info.func = function(_, value)
        local selected = value or opt.value
        if addon.SetUILanguage then addon:SetUILanguage(selected) end
        refreshText()
        SyncAll("ui_language")

        -- Full WoW UI reload is required because Blizzard Settings category
        -- labels and already-created controls do not rebuild reliably in-place.
        if ReloadUI then
          if C_Timer and C_Timer.After then C_Timer.After(0.05, function() ReloadUI() end) else ReloadUI() end
        end
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  refreshText()

  local note = FS(row, "GameFontDisableSmall", LS("Default is Game client language. Change takes effect immediately for addon messages; reopen settings to refresh all labels."))
  note:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 16, -4)
  note:SetPoint("RIGHT", row, "RIGHT", -10, 0)
  note:SetJustifyH("LEFT")

  return row, dropdown
end

--------------------------------------------------
-- InitSettingsPages
--------------------------------------------------

function addon:InitSettingsPages()
  if not addon.db then addon:EnsureDB() end

  if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then
    self.configFrame = self:CreateFallbackPanel()
    self.settingsRoot = nil
    return
  end

  --------------------------------------------------
  -- Root / Overview
  --------------------------------------------------
  local rootPanel = CreateFrame("Frame", "GroupGuardLFGConfigRoot", UIParent, "BackdropTemplate")
  rootPanel:SetSize(640, 480)

  local title = FS(rootPanel, "GameFontNormalLarge", LS("GroupGuard LFG — Settings"))
  title:SetPoint("TOPLEFT", 16, -12)

  local subtitle = FS(rootPanel, "GameFontHighlightSmall",
    LSF("Version: %s — %s", addon.version or "4.0.0", addon.codename or "Release Candidate"))
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

  local overview = FS(rootPanel, "GameFontHighlight",
    "Settings are grouped by how the addon works:\n" ..
    "• General — where the addon works and what to do on a match.\n" ..
    "• LFG applications — manual/auto decline and list highlighting.\n" ..
    "• Raid Assist — automatic raid assistant assignment.\n" ..
    "• Rules — keywords, guild names and language/text signals.\n" ..
    "• Notifications — banner, sound, flash and frame markers.\n" ..
    "• Compatibility — PGF, debounce and technical UI refresh.")
  overview:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -18)
  overview:SetPoint("RIGHT", rootPanel, "RIGHT", -24, 0)
  overview:SetJustifyH("LEFT")

  local rootCategory = Settings.RegisterCanvasLayoutCategory(rootPanel, "GroupGuard LFG")
  Settings.RegisterAddOnCategory(rootCategory)
  self.settingsRoot = rootCategory

  rootPanel:SetScript("OnHide", function()
    -- Top-screen text overlay removed in 2.3.0.
  end)

  local function RegisterPage(frameName, pageTitle, categoryTitle)
    local page, child, titleText = CreateScrolledPage(frameName, 640, 480, LS(pageTitle))
    local cat = Settings.RegisterCanvasLayoutSubcategory(rootCategory, page, LS(categoryTitle or pageTitle))
    return page, child, titleText, cat
  end

  local function AddActionButton(parent, anchor, text, width, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 190, 26)
    btn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
    btn:SetText(LS(text))
    btn:SetScript("OnClick", onClick)
    return btn
  end

  local function AddSoundDropdown(parent, anchor)
    local soundHeader = AddSection(parent, anchor, "Sound")

    local soundRow = CreateFrame("Frame", nil, parent)
    soundRow:SetSize(560, 64)
    soundRow:SetPoint("TOPLEFT", soundHeader, "BOTTOMLEFT", 0, -12)

    local soundLabel = FS(soundRow, "GameFontNormal", "Sound source:")
    soundLabel:SetPoint("TOPLEFT", soundRow, "TOPLEFT", 0, 0)

    local soundDropdown = CreateFrame("Frame", "GroupGuardLFGSoundDropDown", soundRow, "UIDropDownMenuTemplate")
    soundDropdown:SetPoint("TOPLEFT", soundRow, "TOPLEFT", -16, -24)
    UIDropDownMenu_SetWidth(soundDropdown, 275)

    local warnPath = "Interface\\AddOns\\GroupGuardLFG\\Media\\warn.ogg"

    local function basename(path)
      local p = (path or ""):gsub("\\", "/")
      return p:match("([^/]+)$") or path
    end

    local function RefreshSoundText()
      if not addon.db then addon:EnsureDB() end
      if addon.db.sound_kit == "RAID_WARNING" then
        UIDropDownMenu_SetText(soundDropdown, LS("System RAID_WARNING"))
      else
        local current = type(addon.db.sound_file) == "string" and addon.db.sound_file or ""
        if current:lower() == warnPath:lower() then
          UIDropDownMenu_SetText(soundDropdown, "WARN")
        elseif current ~= "" then
          UIDropDownMenu_SetText(soundDropdown, basename(current))
        else
          UIDropDownMenu_SetText(soundDropdown, "WARN")
        end
      end
    end

    local function SetSoundSource(mode, path)
      if mode == "RAID_WARNING" then
        addon.db.sound_kit = "RAID_WARNING"
      elseif mode == "WARN" then
        addon.db.sound_kit = "FILE"
        addon.db.sound_file = warnPath
      elseif mode == "FILE_CUSTOM" then
        addon.db.sound_kit = "FILE"
      end
      RefreshSoundText()
      showSavedHint(parent, soundDropdown)
      SyncAll("sound_source")
    end

    UIDropDownMenu_Initialize(soundDropdown, function(self, level)
      local info = UIDropDownMenu_CreateInfo()
      info.text = "WARN"
      info.func = function() SetSoundSource("WARN") end
      UIDropDownMenu_AddButton(info, level)

      info = UIDropDownMenu_CreateInfo()
      info.text = LS("System RAID_WARNING")
      info.func = function() SetSoundSource("RAID_WARNING") end
      UIDropDownMenu_AddButton(info, level)

      info = UIDropDownMenu_CreateInfo()
      info.text = LS("Custom file")
      info.func = function() SetSoundSource("FILE_CUSTOM") end
      UIDropDownMenu_AddButton(info, level)
    end)

    soundDropdown:HookScript("OnShow", RefreshSoundText)
    RefreshSoundText()

    local soundFileRow = AddEdit(
      parent, soundRow, "Custom sound path:",
      function() return addon.db.sound_file or warnPath end,
      function(txt)
        addon.db.sound_kit = "FILE"
        addon.db.sound_file = txt or warnPath
        RefreshSoundText()
        SyncAll("sound_file")
      end,
      false
    )

    -- Extra spacing below the edit row so the note does not overlap the input/button.
    local infoText = FS(parent, "GameFontDisableSmall",
      "Default bundled sound is Media\\warn.ogg. Put custom sound files into Interface\\AddOns\\GroupGuardLFG\\Media and use /reload.")
    infoText:SetPoint("TOPLEFT", soundFileRow, "BOTTOMLEFT", 0, -14)
    infoText:SetPoint("RIGHT", parent, "RIGHT", -24, 0)
    infoText:SetJustifyH("LEFT")
    return infoText
  end

  --------------------------------------------------
  -- 1. General
  --------------------------------------------------
  local generalPage, generalChild, generalTitle = RegisterPage("GroupGuardLFGConfigGeneral", "General", "1. General")

  local generalNote = FS(generalChild, "GameFontHighlightSmall",
    "Base behavior: where to scan, when to stay silent, and what to do on a match.")
  generalNote:SetPoint("TOPLEFT", generalTitle, "BOTTOMLEFT", 0, -10)
  generalNote:SetPoint("RIGHT", generalChild, "RIGHT", -24, 0)
  generalNote:SetJustifyH("LEFT")

  local langRow = CreateLanguageDropdown(generalChild, generalNote)

  local secScope = AddSection(generalChild, langRow, "Scope")
  local g1 = AddCheck(generalChild, secScope, "Scan party", "show_in_party", function() SyncAll("show_in_party") end)
  local g2 = AddCheck(generalChild, g1, "Scan raid", "show_in_raid", function() SyncAll("show_in_raid") end)
  local g3 = AddCheck(generalChild, g2, "Disable in Battlegrounds / BG", "disable_in_bg", function() SyncAll("disable_in_bg") end)
  local g4 = AddCheck(generalChild, g3, "Disable in Arenas", "disable_in_arena", function() SyncAll("disable_in_arena") end)

  local secActions = AddSection(generalChild, g4, "Actions on match")
  local g5 = AddCheck(generalChild, secActions, "Show “Remove from group” button in the banner", "kick_button_enabled", function() SyncAll("kick_button_enabled") end)
  local g6 = AddCheck(generalChild, g5, "Automatically leave the group after detection", "auto_leave", function() SyncAll("auto_leave") end)
  local g7 = AddCheck(generalChild, g6, "Confirm leaving with a popup", "confirm_leave", function() SyncAll("confirm_leave") end)

  local generalWarn = AddNote(generalChild, g7,
    "The banner can show action buttons both for removing flagged players and for leaving the current party/raid. LFG applications are handled by the separate button on the Premade Groups page.")

  --------------------------------------------------
  -- 2. LFG заявки
  --------------------------------------------------
  local lfgPage, lfgChild, lfgTitle = RegisterPage("GroupGuardLFGConfigLFG", "LFG applications", "2. LFG applications")

  local lfgNote = FS(lfgChild, "GameFontHighlightSmall",
    "This page only controls LFG applications and LFG search. It does not remove players from party/raid.")
  lfgNote:SetPoint("TOPLEFT", lfgTitle, "BOTTOMLEFT", 0, -10)
  lfgNote:SetPoint("RIGHT", lfgChild, "RIGHT", -24, 0)
  lfgNote:SetJustifyH("LEFT")

  local secDecline = AddSection(lfgChild, lfgNote, "Application decline")
  local l1 = AddCheck(lfgChild, secDecline, "Automatically decline marked LFG applications when you have permission", "lfg_auto_decline", function() SyncAll("lfg_auto_decline") end)
  local l2 = AddCheck(lfgChild, l1, "Notify about auto-declines", "lfg_auto_decline_notify", function() SyncAll("lfg_auto_decline_notify") end)
  local l3 = AddCheck(lfgChild, l2, "Show the manual “Decline LFG applications” fallback button", "lfg_show_button", function() SyncAll("lfg_show_button") end)
  local lfgAutoNote = AddNote(lfgChild, l3,
    "Auto-decline runs only for marked applications and only while you can manage the active listing. The manual button remains available for applicants that Blizzard does not allow to decline automatically.")

  local limitRow = AddEdit(
    lfgChild, lfgAutoNote, "Auto-decline limit per pass:",
    function() return addon.db.lfg_auto_decline_batch_limit or 5 end,
    function(txt)
      local v = tonumber(txt) or 5
      if v < 1 then v = 1 elseif v > 20 then v = 20 end
      addon.db.lfg_auto_decline_batch_limit = v
      SyncAll("lfg_auto_decline_batch_limit")
    end,
    true
  )

  local delayRow = AddEdit(
    lfgChild, limitRow, "Delay between auto-declines (sec):",
    function() return addon.db.lfg_auto_decline_delay or 0.12 end,
    function(txt)
      local v = tonumber(txt) or 0.12
      if v < 0.03 then v = 0.03 elseif v > 1.0 then v = 1.0 end
      addon.db.lfg_auto_decline_delay = v
      SyncAll("lfg_auto_decline_delay")
    end,
    false
  )

  local textRow = AddEdit(
    lfgChild, delayRow, "Manual LFG button text:",
    function() return addon.db.lfg_button_text or "Decline LFG applications (%d)" end,
    function(txt)
      if txt == "" then txt = "Decline LFG applications (%d)" end
      addon.db.lfg_button_text = txt
      SyncAll("lfg_button_text")
    end,
    false
  )

  local secHighlight = AddSection(lfgChild, textRow, "LFG highlighting")
  local l4 = AddCheck(lfgChild, secHighlight, "Highlight marked applications in the list", "lfg_highlight", function() SyncAll("lfg_highlight") end)
  local l5 = AddCheck(lfgChild, l4, "Check LFG members against rules", "lfg_highlight_search_members", function() SyncAll("lfg_members") end)
  local l6 = AddCheck(lfgChild, l5, "Show GroupGuard tooltip in LFG", "lfg_tooltips", function() SyncAll("lfg_tooltips") end)
  local l7 = AddCheck(lfgChild, l6, "Show reason in tooltip", "lfg_tooltip_reasons", function() SyncAll("lfg_tooltip_reasons") end)
  local l7b = AddCheck(lfgChild, l7, "Show search result age, role composition and class breakdown in tooltip", "lfg_tooltip_details", function() SyncAll("lfg_tooltip_details") end)
  local l7fit = AddCheck(lfgChild, l7b, "Show whether your current role fits the searched group", "lfg_role_fit_hints", function() SyncAll("lfg_role_fit_hints") end)
  local l7realm = AddCheck(lfgChild, l7fit, "Show technical realm/locale hints in search tooltips", "realm_insights", function() SyncAll("realm_insights") end)
  local l7badge = AddCheck(lfgChild, l7realm, "Show compact realm badges on LFG search rows", "realm_badges", function() SyncAll("realm_badges") end)
  local l7same = AddCheck(lfgChild, l7badge, "Only show realm hints when the realm locale differs from yours", "realm_same_locale_only", function() SyncAll("realm_same_locale_only") end)
  local l7apps = AddCheck(lfgChild, l7same, "Show two-line applicant cards on applicant rows", "applicant_cards_enabled", function() SyncAll("applicant_summary_cards") end)
  local l7appt = AddCheck(lfgChild, l7apps, "Show applicant composition summary in tooltips", "applicant_summary_tooltips", function() SyncAll("applicant_summary_tooltips") end)
  local l7refresh = AddCheck(lfgChild, l7appt, "Refresh applicant list after cancelled/timed out/invited applications", "applicant_auto_refresh_done", function() SyncAll("applicant_auto_refresh_done") end)
  local l7c = AddCheck(lfgChild, l7refresh, "Mute duplicate applicant ping while auto-decline is running", "lfg_mute_applicant_ping", function() SyncAll("lfg_mute_applicant_ping") end)
  local lfgInsightNote = AddNote(lfgChild, l7c,
    "LFG insights are passive UI hints and do not replace Raider.IO, PGF or sorter addons. Realm locale is a realm-list hint only, not a player nationality check. Hold Shift on tooltips to show deeper breakdowns.")

  local secSocial = AddSection(lfgChild, lfgInsightNote, "Friends / guild in LFG")
  local l8 = AddCheck(lfgChild, secSocial, "Ignore friends even if they match filters", "social_ignore_friends", function() SyncAll("social_ignore_friends") end)
  local l9 = AddCheck(lfgChild, l8, "Ignore your guild members even if they match filters", "social_ignore_guild", function() SyncAll("social_ignore_guild") end)
  local l10 = AddCheck(lfgChild, l9, "Detect friends/guild in LFG and highlight them with different colors", "social_mark_lfg", function() SyncAll("social_mark_lfg") end)
  local l11 = AddCheck(lfgChild, l10, "Highlight friends in LFG in blue", "social_mark_friends", function() SyncAll("social_mark_friends") end)
  local l12 = AddCheck(lfgChild, l11, "Highlight guild members in LFG in green", "social_mark_guild", function() SyncAll("social_mark_guild") end)

  AddNote(lfgChild, l12,
    "Friends/guild are not shown on party/raid frames. Social colors work only in LFG lists and tooltips.")

  --------------------------------------------------
  -- 3. Raid Assist
  --------------------------------------------------
  local raidPage, raidChild, raidTitle = RegisterPage("GroupGuardLFGConfigRaidAssist", "Raid Assist", "3. Raid Assist")

  local raidNote = FS(raidChild, "GameFontHighlightSmall",
    "Automatically grants raid assistant only when you are the raid leader. Works only in raid, not party.")
  raidNote:SetPoint("TOPLEFT", raidTitle, "BOTTOMLEFT", 0, -10)
  raidNote:SetPoint("RIGHT", raidChild, "RIGHT", -24, 0)
  raidNote:SetJustifyH("LEFT")

  local r1 = AddCheck(raidChild, raidNote, "Enable automatic raid assistant assignment", "raid_assist_enabled", function() SyncAll("raid_assist_enabled") end)
  local r2 = AddCheck(raidChild, r1, "Automatically grant assistant to selected ranks / officers", "raid_assist_guild_officers", function() SyncAll("raid_assist_guild_officers") end)
  local r3 = AddCheck(raidChild, r2, "Print who received assistant in chat", "raid_assist_notify", function() SyncAll("raid_assist_notify") end)

  local rankDropdown = CreateMultiRankDropdown(
    raidChild, r3, "Guild ranks that should automatically receive assistant:"
  )

  local manualNamesRow = AddEdit(
    raidChild, rankDropdown, "Additional assistant names, comma-separated:",
    function() return addon.db.raid_assist_manual_names or "" end,
    function(txt)
      addon.db.raid_assist_manual_names = txt or ""
      addon._raidAssistManualSet = nil
      addon._raidAssistManualSetText = nil
      SyncAll("raid_assist_manual_names")
    end,
    false
  )

  local raidHint = AddNote(raidChild, manualNamesRow,
    "Ranks are loaded from the guild roster. You can select multiple ranks. Names can be written without realm: Khayen, Forchun.")

  AddActionButton(raidChild, raidHint, "Refresh assistants now", 200, function()
    if addon.ScheduleRaidAssist then addon:ScheduleRaidAssist(0, "settings_button") end
    SyncAll("raid_assist_button")
  end)

  --------------------------------------------------
  -- 4. Filter rules
  --------------------------------------------------
  local rulesPage, rulesChild, rulesTitle = RegisterPage("GroupGuardLFGConfigRules", "Filter rules", "4. Rules")

  local rulesNote = FS(rulesChild, "GameFontHighlightSmall",
    "Neutral marking rules: keywords, names, guilds and optional language/text signals.")
  rulesNote:SetPoint("TOPLEFT", rulesTitle, "BOTTOMLEFT", 0, -10)
  rulesNote:SetPoint("RIGHT", rulesChild, "RIGHT", -24, 0)
  rulesNote:SetJustifyH("LEFT")

  local secTargets = AddSection(rulesChild, rulesNote, "What to scan")
  local f1 = AddCheck(rulesChild, secTargets, "Check player names in party/raid", "scan_group_names", function() SyncAll("scan_group_names") end)
  local f2 = AddCheck(rulesChild, f1, "Check guild names in party/raid", "scan_group_guilds", function() SyncAll("scan_group_guilds") end)

  local rulesRow = AddEdit(
    rulesChild, f2, "Keywords / names / guilds, comma-separated:",
    function() return addon.db.flag_rules or "" end,
    function(txt)
      addon.db.flag_rules = txt or ""
      SyncAll("flag_rules")
    end,
    false
  )

  local rulesExample = AddNote(rulesChild, rulesRow,
    "Example: boost, wts, carry, gdkp, spam, guild-name, player-name")

  local secLang = AddSection(rulesChild, rulesExample, "Language auto-detect")
  local m1 = AddCheck(rulesChild, secLang, "Enable language auto-detect", "language_detect_enabled", function() SyncAll("language_detect_enabled") end)
  local m2 = AddCheck(rulesChild, m1, "Use language keyword phrases", "language_detect_keywords", function() SyncAll("language_detect_keywords") end)
  local m3 = AddCheck(rulesChild, m2, "Detect UTF-8 scripts", "language_detect_scripts", function() SyncAll("language_detect_scripts") end)

  local scriptHeader = AddSection(rulesChild, m3, "Scripts for UTF-8 detection")
  local s1 = AddCheck(rulesChild, scriptHeader, "Cyrillic", "language_script_cyrillic", function() SyncAll("script_cyrillic") end)
  local s2 = AddCheck(rulesChild, s1, "Greek", "language_script_greek", function() SyncAll("script_greek") end)
  local s3 = AddCheck(rulesChild, s2, "Arabic", "language_script_arabic", function() SyncAll("script_arabic") end)
  local s4 = AddCheck(rulesChild, s3, "Hebrew", "language_script_hebrew", function() SyncAll("script_hebrew") end)
  local s5 = AddCheck(rulesChild, s4, "CJK", "language_script_cjk", function() SyncAll("script_cjk") end)
  local s6 = AddCheck(rulesChild, s5, "Kana", "language_script_kana", function() SyncAll("script_kana") end)
  local s7 = AddCheck(rulesChild, s6, "Hangul", "language_script_hangul", function() SyncAll("script_hangul") end)

  local langWarn = AddNote(rulesChild, s7,
    "Script detection may produce false positives. Cyrillic includes Ukrainian, Russian, Bulgarian, Serbian, etc.")

  AddEdit(
    rulesChild, langWarn, "Language phrases, comma-separated:",
    function() return addon.db.language_detect_rules or "" end,
    function(txt)
      addon.db.language_detect_rules = txt or ""
      SyncAll("language_detect_rules")
    end,
    false
  )

  --------------------------------------------------
  -- 5. Notifications and appearance
  --------------------------------------------------
  local visualPage, visualChild, visualTitle = RegisterPage("GroupGuardLFGConfigVisual", "Notifications and appearance", "5. Notifications")

  local visualNote = FS(visualChild, "GameFontHighlightSmall",
    "Banner, sound, screen flash and red marker on party/raid frames.")
  visualNote:SetPoint("TOPLEFT", visualTitle, "BOTTOMLEFT", 0, -10)
  visualNote:SetPoint("RIGHT", visualChild, "RIGHT", -24, 0)
  visualNote:SetJustifyH("LEFT")

  local vSec = AddSection(visualChild, visualNote, "Banner and visuals")
  local v1 = AddCheck(visualChild, vSec, "Show compact notification", "show_banner", function() SyncAll("show_banner") end)
  local v2 = AddCheck(visualChild, v1, "Screen flash", "screen_flash", function() SyncAll("screen_flash") end)
  local v3 = AddCheck(visualChild, v2, "Play sound", "play_sound", function() SyncAll("play_sound") end)
  local v4 = AddCheck(visualChild, v3, "Show centered red marker on party/raid frames", "frame_markers_enabled", function()
    if addon.UpdateFrameMarkers then addon:UpdateFrameMarkers() end
    SyncAll("frame_markers_enabled")
  end)

  local markerNote = AddNote(visualChild, v4,
    "Marker is centered on the character frame and shows only real filter matches. Friends/guild are not highlighted on party/raid frames.")

  local durRow = AddEdit(
    visualChild, markerNote, "Banner duration (sec):",
    function() return addon.db.banner_hold_time or 10 end,
    function(txt)
      local v = tonumber(txt) or 10
      if v < 1 then v = 1 elseif v > 30 then v = 30 end
      addon.db.banner_hold_time = v
      SyncAll("banner_hold_time")
    end,
    true
  )

  local soundCdRow = AddEdit(
    visualChild, durRow, "Sound cooldown (sec):",
    function() return addon.db.alert_sound_cooldown or 10 end,
    function(txt)
      local v = tonumber(txt) or 10
      if v < 0.2 then v = 0.2 elseif v > 30 then v = 30 end
      addon.db.alert_sound_cooldown = v
      SyncAll("alert_sound_cooldown")
    end,
    false
  )

  local flashCdRow = AddEdit(
    visualChild, soundCdRow, "Flash cooldown (sec):",
    function() return addon.db.alert_flash_cooldown or 10 end,
    function(txt)
      local v = tonumber(txt) or 10
      if v < 0.2 then v = 0.2 elseif v > 30 then v = 30 end
      addon.db.alert_flash_cooldown = v
      SyncAll("alert_flash_cooldown")
    end,
    false
  )

  local soundInfo = AddSoundDropdown(visualChild, flashCdRow)

  local testBtn = AddActionButton(visualChild, soundInfo, "Detection test", 160, function()
    if addon.TestAlert then addon:TestAlert() end
  end)
  local testAutoBtn = CreateFrame("Button", nil, visualChild, "UIPanelButtonTemplate")
  testAutoBtn:SetSize(180, 26)
  testAutoBtn:SetPoint("LEFT", testBtn, "RIGHT", 10, 0)
  testAutoBtn:SetText(LS("Auto-decline test"))
  testAutoBtn:SetScript("OnClick", function()
    if addon.ShowBanner then addon:ShowBanner(LS("Auto-declined: 2"), LS("Comment — test"), false, "AUTO_DECLINE", LS("Test banner.")) end
  end)

  --------------------------------------------------
  -- 6. Compatibility and technical
  --------------------------------------------------
  local compatPage, compatChild, compatTitle = RegisterPage("GroupGuardLFGConfigCompat", "Compatibility and technical", "6. Compatibility")

  local compatNote = FS(compatChild, "GameFontHighlightSmall",
    "Technical UI refresh parameters, Premade Groups Filter compatibility and manual synchronization.")
  compatNote:SetPoint("TOPLEFT", compatTitle, "BOTTOMLEFT", 0, -10)
  compatNote:SetPoint("RIGHT", compatChild, "RIGHT", -24, 0)
  compatNote:SetJustifyH("LEFT")

  local c1 = AddCheck(compatChild, compatNote, "Deeper compatibility with Premade Groups Filter", "pgf_integration", function() SyncAll("pgf_integration") end)

  local scanRow = AddEdit(
    compatChild, c1, "Debounce group scan (sec):",
    function() return addon.db.scan_debounce or 0.03 end,
    function(txt)
      local v = tonumber(txt) or 0.03
      if v < 0 then v = 0 elseif v > 1.0 then v = 1.0 end
      addon.db.scan_debounce = v
      SyncAll("scan_debounce")
    end,
    false
  )

  local lfgDebounceRow = AddEdit(
    compatChild, scanRow, "Debounce LFG scan (sec):",
    function() return addon.db.lfg_debounce or 0.02 end,
    function(txt)
      local v = tonumber(txt) or 0.02
      if v < 0 then v = 0 elseif v > 1.0 then v = 1.0 end
      addon.db.lfg_debounce = v
      SyncAll("lfg_debounce")
    end,
    false
  )

  local silentRow = AddEdit(
    compatChild, lfgDebounceRow, "Silent startup after ReloadUI (sec):",
    function() return addon.db.startup_silent_seconds or 3.0 end,
    function(txt)
      local v = tonumber(txt) or 3.0
      if v < 0 then v = 0 elseif v > 15 then v = 15 end
      addon.db.startup_silent_seconds = v
      SyncAll("startup_silent_seconds")
    end,
    false
  )

  local spamCheck = AddCheck(compatChild, silentRow, "Suppress intermediate action spam", "suppress_action_spam", function()
    SyncAll("suppress_action_spam")
  end)

  AddActionButton(compatChild, spamCheck, "Synchronize UI now", 190, function()
    SyncAll("manual_full_sync")
  end)
end

--------------------------------------------------
-- Fallback панель
--------------------------------------------------

function addon:CreateFallbackPanel()
  local panel = CreateFrame("Frame", "GroupGuardLFGFallbackConfig", UIParent, "BackdropTemplate")
  panel:SetSize(720, 580)
  panel:SetPoint("CENTER")
  panel:SetFrameStrata("DIALOG")
  panel:EnableMouse(true)
  panel:SetMovable(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", panel.StartMoving)
  panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
  panel:SetScript("OnHide", function()
    -- Top-screen text overlay removed in 2.3.0.
  end)
  panel:SetClampedToScreen(true)
  panel:Hide()
  panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
  })
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(LS("GroupGuard LFG — Settings (Fallback)"))
  return panel
end

--------------------------------------------------
-- Команди
--------------------------------------------------

SLASH_GROUPGUARDLFG1 = "/gglfg"
SLASH_GROUPGUARDLFG2 = "/groupguard"
SLASH_GROUPGUARDLFG3 = "/gguard"
SLASH_GROUPGUARDLFG4 = "/guardlfg"

local function HandleSlash(msg)
  msg = tostring(msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "pugs" or msg == "pug" or msg == "raidpugs" or msg == "пуги" then
    if addon.TogglePugWindow then addon:TogglePugWindow() end
    return
  end
  if not addon.settingsRoot then addon:InitSettingsPages() end
  if Settings and addon.settingsRoot and Settings.OpenToCategory then
    local id = addon.settingsRoot.ID or (addon.settingsRoot.GetID and addon.settingsRoot:GetID()) or addon.settingsRoot
    local ok = pcall(Settings.OpenToCategory, id)
    if ok then return end
  end
  if not addon.configFrame then addon.configFrame = addon:CreateFallbackPanel() end
  addon.configFrame:Show()
end
SlashCmdList.GROUPGUARDLFG = HandleSlash



SLASH_GROUPGUARDLFGLANG1 = "/gglang"
SlashCmdList.GROUPGUARDLFGLANG = function(msg)
  msg = tostring(msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  local lang = nil
  if msg == "uk" or msg == "ua" or msg == "ukua" or msg == "українська" then
    lang = "ukUA"
  elseif msg == "en" or msg == "enus" or msg == "english" then
    lang = "enUS"
  elseif msg == "auto" or msg == "" then
    lang = "auto"
  end

  if not lang then
    print((addon.printPrefix or "GroupGuard LFG:"), addon:Tr("CMD_USAGE_LANG"))
    return
  end

  if addon.SetUILanguage then addon:SetUILanguage(lang) end
  print((addon.printPrefix or "GroupGuard LFG:"), addon:Tr("CMD_LANGUAGE_SET", lang))
  if ReloadUI then if C_Timer and C_Timer.After then C_Timer.After(0.05, function() ReloadUI() end) else ReloadUI() end end
end


SLASH_GROUPGUARDLFGREMOVE1 = "/ggremove"
SlashCmdList.GROUPGUARDLFGREMOVE = function()
  if not addon.db and addon.EnsureDB then addon:EnsureDB() end
  if addon.ScanGroupOffenders then addon:ScanGroupOffenders() end

  local toKick = {}
  if addon._groupOffenders then
    for name in pairs(addon._groupOffenders) do
      local target = addon._groupOffenderTargets and addon._groupOffenderTargets[name]
      toKick[#toKick + 1] = target or name
    end
  end

  if #toKick == 0 then
    print((addon.printPrefix or "GroupGuard LFG:"), addon:Tr("CMD_NO_MARKED_REMOVE"))
    return
  end

  if addon.KickNamesSequential then
    addon:KickNamesSequential(toKick, 0.15)
  end
end

SLASH_GROUPGUARDLFGSCAN1 = "/ggscan"
SlashCmdList.GROUPGUARDLFGSCAN = function()
  if not addon.db and addon.EnsureDB then addon:EnsureDB() end
  if addon.RebuildCaches then addon:RebuildCaches() end
  if addon.ScanGroupOffenders then addon:ScanGroupOffenders() end
  if addon.RequestGroupRefresh then addon:RequestGroupRefresh(0) end
  if addon.RequestLFGRefresh then addon:RequestLFGRefresh(0, true, true) end
  if addon.ScheduleFrameMarkerUpdate then addon:ScheduleFrameMarkerUpdate(0.01) end

  local count = 0
  if addon._groupOffenders then for _ in pairs(addon._groupOffenders) do count = count + 1 end end
  print((addon.printPrefix or "GroupGuard LFG:"), addon:Tr("CMD_SCAN_COMPLETE", count))
end

SLASH_GROUPGUARDLFGSTATE1 = "/ggstate"
SlashCmdList.GROUPGUARDLFGSTATE = function()
  -- Ensure DB so settings exist
  if not addon.db and addon.EnsureDB then addon:EnsureDB() end

  local inInst, instType = false, "nil"
  if type(IsInInstance) == "function" then
    inInst, instType = IsInInstance()
  end

  local name, instanceType = "nil", "nil"
  if type(GetInstanceInfo) == "function" then
    name, instanceType = GetInstanceInfo()
  end

  local disabledNow = "nil"
  if addon and addon.IsDisabledNow then
    local ok, v = pcall(function() return addon:IsDisabledNow() end)
    disabledNow = ok and tostring(v) or ("error: " .. tostring(v))
  end

  local restrictedNow = "nil"
  if addon and addon.IsInRestrictedInstance then
    local ok, v = pcall(function() return addon:IsInRestrictedInstance() end)
    restrictedNow = ok and tostring(v) or ("error: " .. tostring(v))
  end

  local lockout = "n/a"
  if addon and addon.IsInInstanceLockout then
    local ok, v = pcall(function() return addon:IsInInstanceLockout() end)
    lockout = ok and tostring(v) or ("error: " .. tostring(v))
  end

  local db = addon and addon.db or nil
  local disBG = db and tostring(db.disable_in_bg) or "nil"
  local disArena = db and tostring(db.disable_in_arena) or "nil"
  local showParty = db and tostring(db.show_in_party) or "nil"
  local showRaid  = db and tostring(db.show_in_raid) or "nil"
  local autoLeave = db and tostring(db.auto_leave) or "nil"
  local autoDecline = db and tostring(db.lfg_auto_decline) or "nil"

  print(addon:Tr("CMD_STATE_TITLE"))
  print(addon:Tr("CMD_VERSION", tostring(addon.version), tostring(addon.codename)))
  print(addon:Tr("CMD_IS_IN_INSTANCE", tostring(inInst), tostring(instType)))
  print(addon:Tr("CMD_GET_INSTANCE_INFO", tostring(name), tostring(instanceType)))
  print(addon:Tr("CMD_DB_RESTRICTED", disBG, disArena))
  print(addon:Tr("CMD_DB_BEHAVIOR", showParty, showRaid, autoLeave, autoDecline))
  print(addon:Tr("CMD_SOCIAL_STATE", tostring(db and db.social_ignore_friends), tostring(db and db.social_ignore_guild), tostring(db and db.social_mark_friends), tostring(db and db.social_mark_guild)))
  print(addon:Tr("CMD_RAID_ASSIST_STATE", tostring(db and db.raid_assist_enabled), tostring(db and db.raid_assist_guild_officers), tostring(db and db.raid_assist_selected_ranks or "")))
  local offenderCount = 0
  if addon._groupOffenders then for _ in pairs(addon._groupOffenders) do offenderCount = offenderCount + 1 end end
  print(addon:Tr("CMD_GROUP_OFFENDERS", offenderCount, tostring(addon.KickNamesSequential ~= nil)))
  print(addon:Tr("CMD_LOCKOUT_ACTIVE", lockout))
  print(addon:Tr("CMD_RESTRICTED_NOW", restrictedNow))
  print(addon:Tr("CMD_DISABLED_NOW", disabledNow))
end


SLASH_GROUPGUARDLFGDEBUG1 = "/ggdebug"
SlashCmdList.GROUPGUARDLFGDEBUG = function()
  local viewer = LFGListFrame and LFGListFrame.ApplicationViewer
  local sp = LFGListFrame and LFGListFrame.SearchPanel

  print(addon:Tr("CMD_DEBUG_TITLE"))
  print(addon:Tr("CMD_LFG_FRAME_STATE", "LFGListFrame", LFGListFrame and addon:Tr("CMD_YES") or addon:Tr("CMD_NO")))
  print(addon:Tr("CMD_LFG_FRAME_STATE", "SearchPanel", sp and addon:Tr("CMD_YES") or addon:Tr("CMD_NO")))
  print(addon:Tr("CMD_LFG_FRAME_STATE", "ApplicationViewer", viewer and addon:Tr("CMD_YES") or addon:Tr("CMD_NO")))
  print(addon:Tr("CMD_LFG_FRAME_STATE", "Premade Groups Filter", addon.IsPremadeGroupsFilterLoaded and addon:IsPremadeGroupsFilterLoaded() and addon:Tr("CMD_LOADED") or addon:Tr("CMD_NOT_LOADED")))

  if viewer then
    print(addon:Tr("CMD_LFG_FRAME_STATE", "viewer.ScrollFrame", viewer.ScrollFrame and addon:Tr("CMD_YES") or addon:Tr("CMD_NO")))
    print(addon:Tr("CMD_LFG_FRAME_STATE", "viewer.ScrollBox", viewer.ScrollBox and addon:Tr("CMD_YES") or addon:Tr("CMD_NO")))
    print(addon:Tr("CMD_BUTTON_COUNT", "viewer.ScrollFrame", tostring(viewer.ScrollFrame and viewer.ScrollFrame.buttons and #viewer.ScrollFrame.buttons or addon:Tr("CMD_NIL"))))
  end

  if sp then
    print(addon:Tr("CMD_LFG_FRAME_STATE", "search.ScrollFrame", sp.ScrollFrame and addon:Tr("CMD_YES") or addon:Tr("CMD_NO")))
    print(addon:Tr("CMD_LFG_FRAME_STATE", "search.ScrollBox", sp.ScrollBox and addon:Tr("CMD_YES") or addon:Tr("CMD_NO")))
    print(addon:Tr("CMD_BUTTON_COUNT", "search.ScrollFrame", tostring(sp.ScrollFrame and sp.ScrollFrame.buttons and #sp.ScrollFrame.buttons or addon:Tr("CMD_NIL"))))
  end

  if C_LFGList and C_LFGList.GetApplicants then
    local apps = addon.LFG_API_GetApplicants and addon:LFG_API_GetApplicants() or {}
    print(addon:Tr("CMD_APPLICANTS_COUNT", #apps))
    if apps[1] and C_LFGList.GetApplicantInfo then
      local info = addon.LFG_API_GetApplicantInfo and addon:LFG_API_GetApplicantInfo(apps[1]) or nil
      print(addon:Tr("CMD_FIRST_APPLICANT", tostring(apps[1]), tostring(info and info.numMembers or addon:Tr("CMD_NIL"))))
    end
  end
end
