-- Search lifecycle adapted from ForeverLFG 0.5.3 (MIT; see LICENSE-ForeverLFG).
local addonName, addon = ...
if not (addon.IsForeverClient and addon:IsForeverClient()) then return end
local NS = addon.ForeverSearch

local frame = CreateFrame("Frame")
local pending, issuing, clickRun, hooked, externalPending, uncertain
local lastSearch, externalID = -math.huge, 0
local viewGeneration = 0

local Say = NS.Say
local BuildRequest

function NS.IsIssuing() return issuing == true end
local function NativeSearching()
    local value = LFGBrowseFrame and LFGBrowseFrame.searching
    return addon:CanAccessValue(value) and value == true
end

function NS.SetStatus(key, detail, kind, run)
    local message = NS.English(key)
    NS.statusKey, NS.status, NS.detail, NS.statusKind = key, message, detail or message, kind or "info"
    local isError = kind == "error" or kind == "validation"
    NS.Log(isError and "Error" or "Search", detail and detail ~= message and message .. ": " .. detail or message, isError, run)
    if NS.UpdateUI then NS.UpdateUI() end
end

function NS.IsPending() return pending ~= nil or externalPending end

function NS.CooldownRemaining() return math.max(0, math.ceil(5 - (GetTime() - lastSearch))) end

function NS.ShortStatus()
    if NS.blocked then return NS.Text("OPERATION_BLOCKED"), false end
    -- Проверяем поля при наведении без поиска и записи в журнал.
    local run, _, key = BuildRequest(NS.Mode())
    if not run then return NS.Text(key), false end
    if InCombatLockdown() then return NS.Text("OUT_OF_COMBAT"), true end
    if NS.IsPending() or NativeSearching() then return NS.Text("SEARCHING"), true end
    if NS.statusKind == "cooldown" then
        local remaining = NS.CooldownRemaining()
        return remaining > 0 and NS.Text("RETRY_IN", remaining) or NS.Text("READY"), true
    end
    if NS.statusKind == "validation" then return NS.Text("READY"), true end
    return NS.Text(NS.statusKey or "START_SEARCH"), true
end

-- Доступность нашего пункта меню. Проверка не пишет в журнал и не отправляет запрос.
function NS.SearchButtonState()
    if NS.blocked then return false, "OPERATION_BLOCKED" end
    local run, _, key = BuildRequest(NS.Mode())
    if not run then return false, key end
    if InCombatLockdown() then return false, "OUT_OF_COMBAT" end
    if NS.IsPending() or NativeSearching() then return false, "WAIT_CURRENT" end
    for _, name in ipairs({ "Search", "GetSearchResults", "GetFilteredSearchResults", "GetSearchResultInfo" }) do
        if not C_LFGList or type(C_LFGList[name]) ~= "function" then return false, "SEARCH_UNAVAILABLE" end
    end
    if not C_Macro or type(C_Macro.RunMacroText) ~= "function" then return false, "SEARCH_UNAVAILABLE" end
    local remaining = NS.CooldownRemaining()
    if remaining > 0 then return false, "RETRY_IN", remaining end
    return true, "APPLY_LANGUAGES"
end

local Describe, ReadOptional, Context, Summary = NS.Describe, NS.ReadOptional, NS.Context, NS.Summary

local function ObserveView(run)
    local generation = viewGeneration
    -- Presentation is queued for the next frame and again at 0.05 s. Never
    -- report a cached count from an older/native-overwritten ScrollBox provider.
    C_Timer.After(0.1, function()
        if generation ~= viewGeneration then return end
        local count, reason
        if addon.LFGFilters_GetForeverVisibleCount then count, reason = addon:LFGFilters_GetForeverVisibleCount() end
        NS.Log("View", "#" .. (run.requestID or 0) .. "; GroupGuard visible="
            .. (count ~= nil and NS.Describe(count) or "not settled (" .. (reason or "presentation unavailable") .. ")"))
    end)
end

local function CountResults(total, ids)
    assert(addon:CanAccessValue(ids) and type(ids) == "table", "API did not return an accessible result table")
    local result = { total = addon:CanAccessValue(total) and total or "unknown", count = #ids, solo = 0, groups = 0, self = 0, delisted = 0, missing = 0 }
    for _, id in ipairs(ids) do
        local info = addon:CanAccessValue(id) and C_LFGList.GetSearchResultInfo(id) or nil
        if not addon:CanAccessValue(info) or type(info) ~= "table" then result.missing = result.missing + 1
        elseif addon:CanAccessValue(info.isDelisted) and info.isDelisted == true then result.delisted = result.delisted + 1
        elseif addon:CanAccessValue(info.hasSelf) and info.hasSelf == true then result.self = result.self + 1
        elseif not addon:CanAccessValue(info.numMembers) or type(info.numMembers) ~= "number" then result.missing = result.missing + 1
        elseif info.numMembers <= 1 then result.solo = result.solo + 1
        else result.groups = result.groups + 1 end
    end
    return result
end

local function Finish(status, reason)
    if not pending then return end
    local run = pending
    pending = nil
    NS.resultCounts = run.filtered
    run.status, run.reason = status, reason and NS.Describe(reason) or nil
    run.elapsed = GetTime() - run.started
    -- Не записываем флаги Blizzard и не вызываем его UpdateResults/UpdateButtonState.
    if run.diagnostic then Say(Summary(run)) end
    if run.filtered then
        local detail = Summary(run)
        if run.attributionUncertain then
            detail = detail .. "\nThe response cannot be matched to a request after an earlier failure. This is the shared result list; the selected language is not confirmed."
        elseif run.mode ~= NS.Mode() then
            detail = detail .. "\nA different language is selected. Click Search in the GroupGuard filter panel to search again."
        end
        local short = "SEARCH_COMPLETE"
        if run.attributionUncertain then short = "LANGUAGE_UNCONFIRMED"
        elseif run.mode ~= NS.Mode() then short = "REFRESH_LANGUAGE" end
        NS.SetStatus(short, detail, (run.attributionUncertain or run.mode ~= NS.Mode()) and "info" or "success", run)
        ObserveView(run)
    else
        NS.SetStatus("SEARCH_INCOMPLETE", Summary(run) .. "\nRetry manually using the GroupGuard filter panel or the default refresh button. Details: /gglanguages log.", "error", run)
    end
end

local function MatchesRequest(run, category, filter, preferred, languages, crossFaction, advanced, activities)
    if not addon:CanAccessValue(category) or category ~= run.categoryID then return false end
    if not addon:CanAccessValue(filter) or not addon:CanAccessValue(preferred) or not addon:CanAccessValue(crossFaction) then return false end
    if filter ~= 0 or preferred ~= 0 or crossFaction ~= false or advanced ~= nil then return false end
    if run.languages == nil then
        if languages ~= nil then return false end
    else
        if not addon:CanAccessValue(languages) or type(languages) ~= "table" then return false end
        for code, selected in pairs(run.languages) do
            local actual = languages[code]
            if actual ~= nil and not addon:CanAccessValue(actual) then return false end
            if (actual == true) ~= selected then return false end
        end
    end
    if run.activityIDs == nil then return activities == nil end
    if not addon:CanAccessValue(activities) or type(activities) ~= "table" or #activities ~= #run.activityIDs then return false end
    for i, id in ipairs(run.activityIDs) do
        if not addon:CanAccessValue(activities[i]) or activities[i] ~= id then return false end
    end
    return true
end

local function EnsureHook()
    if hooked then return true end
    local ok = pcall(hooksecurefunc, C_LFGList, "Search", function(category, filter, preferred, languages, crossFaction, advanced, activities)
        lastSearch = GetTime()
        if issuing and clickRun and MatchesRequest(clickRun, category, filter, preferred, languages, crossFaction, advanced, activities) then
            clickRun.dispatched, clickRun.dispatchTime = true, GetTime()
            NS.Log("Dispatch", "#" .. clickRun.requestID .. "; API invocation observed; "
                .. NS.SearchParameters(category, filter, preferred, languages, crossFaction, advanced, activities), false, clickRun)
            return
        end
        viewGeneration = viewGeneration + 1
        NS.resultCounts = nil
        if externalPending then
            NS.Log("Search", "#" .. externalPending.requestID .. " replaced by another external request; response attribution is uncertain")
            uncertain = true
        end
        externalPending = { requestID = NS.NextRequestID(), mode = "native/other", started = GetTime() }
        externalID = externalID + 1
        local token = externalID
        if pending then
            uncertain = true
            Finish("superseded", "The response cannot be attributed to the selected language")
        end
        local requestID = externalPending.requestID
        NS.SetStatus("NATIVE_SEARCHING", "#" .. requestID .. " native/other: " .. NS.SearchParameters(category, filter, preferred, languages, crossFaction, advanced, activities))
        C_Timer.After(30, function()
            if token == externalID and externalPending then
                externalPending, uncertain = nil, true
                NS.SetStatus("NO_RESPONSE", "#" .. requestID .. " native/other: timeout after 30 s; a late response may change the shared list.", "error")
            end
        end)
    end)
    hooked = ok
    return ok
end

BuildRequest = function(mode, wide, diagnostic, source)
    local browse = LFGBrowseFrame
    if not browse or not browse:IsShown() or not browse.CategoryDropdown or not browse.ActivityDropdown then
        return nil, NS.English("OPEN_SEARCH"), "OPEN_SEARCH"
    end
    local dropdown = browse.CategoryDropdown
    if type(dropdown.GetValue) ~= "function" then return nil, "Category selector method unavailable", "SELECT_CATEGORY" end
    local ok, categoryID = pcall(dropdown.GetValue, dropdown)
    if not ok then return nil, "Category read failed: " .. NS.Describe(categoryID), "READ_CATEGORY_FAILED" end
    if not addon:CanAccessValue(categoryID) or type(categoryID) ~= "number" or categoryID <= 0 then return nil, NS.English("SELECT_CATEGORY"), "SELECT_CATEGORY" end
    local languages, canonical, err, key = NS.LanguageFilter(mode)
    if not canonical then return nil, err, key end
    local activities
    if not wide then
        local values = browse.ActivityDropdown.selectedValues
        if not addon:CanAccessValue(values) or type(values) ~= "table" then return nil, "Unknown activity filter", "READ_FILTERS_FAILED" end
        if #values == 0 then
            if type(LFGUtil_GetFilteredActivities) ~= "function" then return nil, "Activity list function unavailable", "ACTIVITIES_UNAVAILABLE" end
            local ok, result = pcall(LFGUtil_GetFilteredActivities, categoryID)
            if not ok or not addon:CanAccessValue(result) or type(result) ~= "table" then return nil, "Could not retrieve activities", "ACTIVITIES_UNAVAILABLE" end
            values = result
        end
        activities = {}
        for i, id in ipairs(values) do
            if not addon:CanAccessValue(id) or type(id) ~= "number" or id <= 0 then
                return nil, "Invalid or inaccessible activity", "READ_FILTERS_FAILED"
            end
            activities[i] = id
        end
        if #activities == 0 then return nil, "No activities for the selected filters", "NO_ACTIVITIES" end
    end
    return { mode = canonical, wide = wide, diagnostic = diagnostic, source = source or "click",
        categoryID = categoryID, activityIDs = activities, languages = languages }
end

-- The macro contains only validated literals: it never reads addon globals or calls
-- addon Lua. Forever's native SecureActionButton handler executes it on a click.
local function SearchMacro(run)
    local languages = "nil"
    if run.languages then
        local fields = {}
        for _, code in ipairs({ "enUS", "koKR", "frFR", "deDE", "zhCN", "zhTW", "esES", "esMX", "ruRU", "ptBR", "itIT" }) do
            fields[#fields + 1] = code .. "=" .. tostring(run.languages[code] == true)
        end
        languages = "{" .. table.concat(fields, ",") .. "}"
        for code in pairs(run.languages) do
            if not code:match("^[a-z][a-z][A-Z][A-Z]$") then return nil end
            local known = false
            for _, field in ipairs(fields) do if field:sub(1, 4) == code then known = true; break end end
            if not known then return nil end
        end
    end
    local activities = "nil"
    if run.activityIDs then
        local ids = {}
        for _, id in ipairs(run.activityIDs) do
            if id ~= math.floor(id) or id == math.huge then return nil end
            ids[#ids + 1] = string.format("%.0f", id)
        end
        activities = "{" .. table.concat(ids, ",") .. "}"
    end
    if run.categoryID ~= math.floor(run.categoryID) or run.categoryID == math.huge then return nil end
    local text = "/run if not InCombatLockdown() then C_LFGList.Search(" .. string.format("%.0f", run.categoryID)
        .. ",0,0," .. languages .. ",false,nil," .. activities .. ") end"
    -- Reject overlong macros instead of truncating a request or dropping filters.
    if #text > 1023 then return nil end
    return text
end

-- Prepare one action during PreClick; never call the protected API from addon Lua.

function NS.Request(mode, wide, diagnostic, source, button)
    if InCombatLockdown() then NS.SetStatus("OUT_OF_COMBAT", nil, "validation"); return false end
    if not NS.PanelControls or button ~= NS.PanelControls.Search then
        NS.SetStatus("SEARCH_UNAVAILABLE", "Use the Search button in the GroupGuard filter panel", "validation"); return false
    end
    button:SetAttribute("type", nil)
    button:SetAttribute("macrotext", nil)
    if NS.blocked then NS.SetStatus("OPERATION_BLOCKED", nil, "error"); return false end
    NS.Log("Action", NS.SourceLabel(source) .. "; language=" .. tostring(mode or NS.Mode()) .. (wide and "; wide" or ""))
    local run, err, short = BuildRequest(mode or NS.Mode(), wide, diagnostic, source)
    if not run then
        NS.resultCounts = nil
        NS.SetStatus(short, err, "validation")
        if diagnostic then Say(err) end
        return false
    end
    if InCombatLockdown() then NS.SetStatus("OUT_OF_COMBAT", nil, "validation"); return false end
    if NS.IsPending() or NativeSearching() then
        NS.SetStatus("WAIT_CURRENT", "No search was queued. Click Search in the GroupGuard filter panel after the response.")
        return false
    end
    for _, name in ipairs({ "Search", "GetSearchResults", "GetFilteredSearchResults", "GetSearchResultInfo" }) do
        if not C_LFGList or type(C_LFGList[name]) ~= "function" then NS.SetStatus("SEARCH_UNAVAILABLE", "Missing C_LFGList." .. name, "error"); return false end
    end
    if not C_Macro or type(C_Macro.RunMacroText) ~= "function" then NS.SetStatus("SEARCH_UNAVAILABLE", "Secure macro API unavailable", "error"); return false end
    local macro = SearchMacro(run)
    if not macro then NS.SetStatus("SEARCH_UNAVAILABLE", "Filters cannot be represented safely within the macro limit", "validation"); return false end
    if not EnsureHook() then NS.SetStatus("SEARCH_UNAVAILABLE", "Could not install the search observer", "error"); return false end
    local delay = 5 - (GetTime() - lastSearch)
    if delay > 0 then
        NS.SetStatus("WAIT_RETRY", "Request not sent: cooldown between searches. Retry manually.", "cooldown")
        return false
    end
    run.requestID = NS.NextRequestID()
    run.context, run.timestamp, run.started = Context(), time(), GetTime()
    run.attributionUncertain = uncertain or nil
    run.availableLanguages = ReadOptional("GetAvailableLanguageSearchFilter")
    run.defaultLanguages = ReadOptional("GetDefaultLanguageSearchFilter")
    run.savedLanguages = ReadOptional("GetLanguageSearchFilter")
    NS.resultCounts = nil
    pending, issuing, clickRun = run, true, run
    viewGeneration = viewGeneration + 1
    NS.SetStatus("SEARCHING", "#" .. run.requestID .. " language=" .. run.mode .. "; " .. NS.SearchParameters(run.categoryID, 0, 0, run.languages, false, nil, run.activityIDs)
        .. "; available=" .. Describe(run.availableLanguages) .. "; default=" .. Describe(run.defaultLanguages) .. "; saved API=" .. Describe(run.savedLanguages))
    if run.diagnostic then Say("Request " .. run.mode .. "; category=" .. run.categoryID .. "; activities=" .. (run.activityIDs and table.concat(run.activityIDs, ",") or "nil")) end
    button:SetAttribute("macrotext", macro)
    button:SetAttribute("type", "macro")

    return true
end

-- PostClick does bookkeeping only; it cannot launch another search.
function NS.EndClick(button)
    local run = clickRun
    issuing, clickRun = false, nil
    if not InCombatLockdown() then
        button:SetAttribute("type", nil)
        button:SetAttribute("macrotext", nil)
    end
    if run and pending == run then
        if not run.dispatched then
            Finish("not-dispatched", "The secure click did not invoke the expected C_LFGList.Search. No server request is confirmed; click Search again.")
            NS.SetStatus("SEARCH_NOT_SENT", Summary(run), "error", run)
        else
            C_Timer.After(30, function()
                if pending == run then
                    uncertain = true
                    Finish("timeout", "No response within 30 seconds; this is not an empty result")
                end
            end)
        end
    end
    if NS.UpdateUI then NS.UpdateUI() end
end

function NS.SelectLanguage(mode)
    local _, canonical, err, key = NS.LanguageFilter(mode)
    -- Пустой набор сохраняем после снятия последней галочки, но поиск с ним запрещён.
    if mode == "" then canonical = "" end
    if canonical == nil then NS.SetStatus(key, err, "validation"); return false end
    if canonical == NS.Mode() then return true end
    local previous = NS.Mode()
    NS.Database().settings.language = canonical
    NS.Log("Language", (previous ~= "" and previous or "(none)") .. " -> " .. (canonical ~= "" and canonical or "(none)") .. "; saved; search not sent")
    NS.SetStatus(canonical == "" and "SELECT_SEARCH_LANGUAGES" or "REFRESH_LANGUAGE")
    return true
end

local function RecordBlocked(event, owner, functionName)
    if owner ~= addonName or type(functionName) ~= "string" then return end
    if not functionName:find("Search", 1, true) and not ((issuing or pending) and functionName == "UNKNOWN()") then return end
    if NS.DisableCustomRefresh then NS.DisableCustomRefresh("search operation blocked") end
    local detail = event .. ": " .. NS.Describe(owner) .. " / " .. NS.Describe(functionName)
    if pending then Finish("blocked", detail)
    else NS.SetStatus("OPERATION_BLOCKED", detail, "error") end
end

frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
frame:RegisterEvent("LFG_LIST_SEARCH_FAILED")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        if addon.LFGFilters_ApplyDeferredPanel then addon:LFGFilters_ApplyDeferredPanel() end
        if NS.PanelControls then NS.EndClick(NS.PanelControls.Search) end
    elseif event == "ADDON_LOADED" then
        if ... == addonName then
            NS.InitializeLog()
            NS.Log("Session", Describe(Context()) .. "; selected language=" .. NS.Mode())
            if C_LFGList and type(C_LFGList.Search) == "function" then EnsureHook() end
        end
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        RecordBlocked(event, ...)
    elseif event == "LFG_LIST_SEARCH_FAILED" or event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
        local external = externalPending
        local responseUncertain = uncertain
        uncertain = nil
        externalPending = nil
        externalID = externalID + 1
        if not pending then
            local run = external or { mode = "unsolicited response" }
            run.elapsed = run.started and GetTime() - run.started or nil
            NS.resultCounts = nil
            if event == "LFG_LIST_SEARCH_FAILED" then
                run.status, run.reason = "failed", NS.Describe((...) or "reason not provided")
                NS.SetStatus("NATIVE_FAILED", Summary(run), "error")
            else
                local ok, raw, filtered = pcall(function()
                    return CountResults(C_LFGList.GetSearchResults()), CountResults(C_LFGList.GetFilteredSearchResults())
                end)
                if ok then
                    run.status = (responseUncertain or not external) and "response-unmatched" or "response"
                    run.raw, run.filtered = raw, filtered
                    NS.resultCounts = filtered
                    NS.SetStatus("NATIVE_COMPLETE", Summary(run) .. "; click Search in the GroupGuard filter panel to search using the selected language")
                    ObserveView(run)
                else
                    run.status, run.reason = "read-error", NS.Describe(raw)
                    NS.SetStatus("READ_RESULTS_FAILED", Summary(run), "error")
                end
            end
            return
        end
        if event == "LFG_LIST_SEARCH_FAILED" then Finish("failed", (...) or "reason not provided"); return end
        local ok, raw, filtered = pcall(function()
            return CountResults(C_LFGList.GetSearchResults()), CountResults(C_LFGList.GetFilteredSearchResults())
        end)
        if ok then
            pending.raw, pending.filtered = raw, filtered
            Finish(pending.attributionUncertain and "response-unmatched" or "response")
        else Finish("read-error", raw) end
    end
end)
