-- Base English strings adapted from ForeverLFG 0.5.3 (MIT; see LICENSE-ForeverLFG).
local addonName, addon = ...
if not (addon.IsForeverClient and addon:IsForeverClient()) then return end
addon.ForeverSearch = {}
local NS = addon.ForeverSearch

-- Переводы интерфейса независимы от списка языков поиска, который возвращает API.
NS.english = {
    LANGUAGE = "Selected languages",
    GROUPS = "Groups: %d",
    PLAYERS = "Players: %d",
    LANGUAGE_MENU = "Search languages",
    ALL_LANGUAGES = "All languages",
    GAME_DEFAULT = "Game default",
    NO_LANGUAGES_SELECTED = "None selected",
    SELECT_SEARCH_LANGUAGES = "Choose at least one language",
    LANGUAGES_UNAVAILABLE = "Language list unavailable. Use Game default.",
    LANGUAGES_FAILED = "Could not retrieve languages",
    LANGUAGES_EMPTY = "No languages available yet. Use Game default.",
    LANGUAGE_UNAVAILABLE = "Selected language unavailable",
    OPEN_SEARCH = "Open the group search tab",
    SELECT_CATEGORY = "Select a category",
    READ_CATEGORY_FAILED = "Could not read category",
    READ_FILTERS_FAILED = "Could not read filters",
    ACTIVITIES_UNAVAILABLE = "Activities unavailable",
    NO_ACTIVITIES = "No matching activities",
    OUT_OF_COMBAT = "Search available out of combat",
    SEARCHING = "Searching...",
    RETRY_IN = "Retry in %d s",
    READY = "Ready to search",
    START_SEARCH = "Choose a language and start searching",
    SEARCH_COMPLETE = "Search complete",
    LANGUAGE_UNCONFIRMED = "List updated; language unconfirmed",
    REFRESH_LANGUAGE = "Language selected. Search again",
    SEARCH_INCOMPLETE = "Search did not complete",
    NATIVE_SEARCHING = "Default search in progress...",
    NO_RESPONSE = "No response. Try again",
    WAIT_CURRENT = "Wait for the current search",
    SEARCH_UNAVAILABLE = "Search unavailable",
    SEARCH_NOT_SENT = "Search was not sent. Click Search again",
    WAIT_RETRY = "Wait before searching again",
    OPERATION_BLOCKED = "Operation blocked",
    NATIVE_FAILED = "Another search failed",
    READ_RESULTS_FAILED = "Could not read results",
    NATIVE_COMPLETE = "Game search complete. Use Search in GroupGuard filters for your languages",
}

local function Format(strings, key, ...)
    local value = strings[key] or NS.english[key]
    assert(value, "Unknown localization key: " .. tostring(key))
    if select("#", ...) > 0 then return string.format(value, ...) end
    return value
end

function NS.English(key, ...) return Format(NS.english, key, ...) end

NS.english.SEARCH_BUTTON = "Search"
NS.english.SELECT_HINT = "Selection is saved. Click Search in this panel to apply it."
NS.english.HELP = "Select languages and click Search in the GroupGuard filter panel."
NS.ukrainian = {
    LANGUAGE_MENU = "Мови пошуку", ALL_LANGUAGES = "Усі мови", GAME_DEFAULT = "Мови клієнта",
    NO_LANGUAGES_SELECTED = "Не вибрано", SELECT_SEARCH_LANGUAGES = "Виберіть хоча б одну мову",
    LANGUAGES_UNAVAILABLE = "Список мов недоступний. Виберіть мови клієнта.",
    LANGUAGES_FAILED = "Не вдалося отримати мови", LANGUAGES_EMPTY = "Мови поки недоступні. Виберіть мови клієнта.",
    LANGUAGE_UNAVAILABLE = "Вибрана мова недоступна", OPEN_SEARCH = "Відкрийте вкладку пошуку груп",
    SELECT_CATEGORY = "Виберіть категорію", READ_CATEGORY_FAILED = "Не вдалося прочитати категорію",
    READ_FILTERS_FAILED = "Не вдалося прочитати фільтри", ACTIVITIES_UNAVAILABLE = "Активності недоступні",
    NO_ACTIVITIES = "Немає відповідних активностей", OUT_OF_COMBAT = "Пошук доступний поза боєм",
    SEARCHING = "Пошук…", RETRY_IN = "Повторити через %d с", READY = "Можна шукати",
    START_SEARCH = "Виберіть мови та почніть пошук", SEARCH_COMPLETE = "Пошук завершено",
    LANGUAGE_UNCONFIRMED = "Список оновлено; мови не підтверджено", REFRESH_LANGUAGE = "Мови змінено. Запустіть пошук",
    SEARCH_INCOMPLETE = "Пошук не завершено", NATIVE_SEARCHING = "Триває штатний пошук…",
    NO_RESPONSE = "Немає відповіді. Повторіть пошук", WAIT_CURRENT = "Дочекайтеся поточного пошуку",
    SEARCH_NOT_SENT = "Запит не надіслано. Натисніть «Шукати» ще раз",
    SEARCH_UNAVAILABLE = "Пошук недоступний", WAIT_RETRY = "Зачекайте перед повторним пошуком",
    OPERATION_BLOCKED = "Пошук заблоковано до перезавантаження UI", NATIVE_FAILED = "Інший пошук завершився помилкою",
    READ_RESULTS_FAILED = "Не вдалося прочитати результати", NATIVE_COMPLETE = "Штатний пошук завершено. Натисніть «Шукати» в панелі фільтрів для вибраних мов",
    SEARCH_BUTTON = "Шукати", SELECT_HINT = "Вибір збережено. Натисніть «Шукати» в цій панелі, щоб застосувати його.",
    HELP = "Виберіть мови та натисніть «Шукати» в панелі фільтрів GroupGuard.",
}
function NS.Text(key, ...)
    return Format(addon:GetUILanguage() == "ukUA" and NS.ukrainian or NS.english, key, ...)
end
