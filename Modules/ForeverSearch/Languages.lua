-- Language filtering adapted from ForeverLFG 0.5.3 (MIT; see LICENSE-ForeverLFG).
local addonName, addon = ...
if not (addon.IsForeverClient and addon:IsForeverClient()) then return end
local NS = addon.ForeverSearch


-- Stored with GroupGuard; never read or modify another addon's SavedVariables.
function NS.Database()
    if not addon.db then addon:EnsureDB() end
    local db = addon.db
    if type(db.lfg_forever_search) ~= "table" then db.lfg_forever_search = {} end
    local search = db.lfg_forever_search
    if type(search.settings) ~= "table" then search.settings = {} end
    if type(search.settings.language) ~= "string" then search.settings.language = "all" end
    return search
end

function NS.Mode() return NS.Database().settings.language end

function NS.LanguageLabel(mode)
    if mode == "" then return NS.Text("NO_LANGUAGES_SELECTED") end
    if mode == "all" then return NS.Text("ALL_LANGUAGES") end
    if mode == "default" then return NS.Text("GAME_DEFAULT") end
    if mode:find(",", 1, true) then
        local labels = {}
        for code in mode:gmatch("[^,]+") do labels[#labels + 1] = NS.LanguageLabel(code) end
        return table.concat(labels, " + ")
    end
    local label = _G["LFG_LIST_LANGUAGE_" .. mode:upper()]
    return addon:CanAccessValue(label) and type(label) == "string" and label ~= "" and label or mode
end

function NS.AvailableLanguages()
    local fn = C_LFGList and C_LFGList.GetAvailableLanguageSearchFilter
    if type(fn) ~= "function" then return nil, NS.English("LANGUAGES_UNAVAILABLE"), "LANGUAGES_UNAVAILABLE" end
    local ok, values = pcall(fn)
    if not ok or not addon:CanAccessValue(values) or type(values) ~= "table" then return nil, NS.English("LANGUAGES_FAILED"), "LANGUAGES_FAILED" end
    local result, seen = {}, {}
    for _, code in ipairs(values) do
        if addon:CanAccessValue(code) and type(code) == "string" and code ~= "" and not seen[code] then
            result[#result + 1], seen[code] = code, true
        end
    end
    if #result == 0 then return nil, NS.English("LANGUAGES_EMPTY"), "LANGUAGES_EMPTY" end
    return result
end

function NS.LanguageFilter(mode)
    if type(mode) ~= "string" then return nil, nil, NS.English("LANGUAGE_UNAVAILABLE"), "LANGUAGE_UNAVAILABLE" end
    local lower = mode:lower()
    if lower == "" then return nil, nil, NS.English("SELECT_SEARCH_LANGUAGES"), "SELECT_SEARCH_LANGUAGES" end
    if lower == "default" then return nil, "default" end
    local available, err, key = NS.AvailableLanguages()
    if not available then return nil, nil, err, key end
    local filter, requested, found = {}, {}, {}
    for code in lower:gmatch("[^,]+") do requested[code] = true end
    for _, code in ipairs(available) do
        filter[code] = lower == "all" or requested[code:lower()] == true
        if requested[code:lower()] then found[#found + 1] = code; requested[code:lower()] = nil end
    end
    if lower ~= "all" and (next(requested) or #found == 0) then
        return nil, nil, "Language unavailable: " .. mode, "LANGUAGE_UNAVAILABLE"
    end
    table.sort(found)
    local selected = lower == "all" and "all" or table.concat(found, ",")
    return filter, selected
end
