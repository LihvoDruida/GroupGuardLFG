-- Search diagnostics adapted from ForeverLFG 0.5.3 (MIT; see LICENSE-ForeverLFG).
local addonName, addon = ...
if not (addon.IsForeverClient and addon:IsForeverClient()) then return end
local NS = addon.ForeverSearch

function NS.Describe(value, depth)
    if value == nil then return "nil" end
    if not addon:CanAccessValue(value) then return "<inaccessible>" end
    if type(value) ~= "table" then return tostring(value) end
    depth = depth or 0
    if depth >= 3 then return "{...}" end
    local parts = {}
    for key, item in pairs(value) do
        parts[#parts + 1] = NS.Describe(key, depth + 1) .. "=" .. NS.Describe(item, depth + 1)
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ", ") .. "}"
end

function NS.ReadOptional(name)
    local fn = C_LFGList and C_LFGList[name]
    if type(fn) ~= "function" then return "function unavailable" end
    local ok, value = pcall(fn)
    if ok and addon:CanAccessValue(value) then return value end
    return "unavailable"
end

function NS.Context()
    local version, build, buildDate, interface = GetBuildInfo()
    return { addonVersion = addon.version, version = version, build = build,
        buildDate = buildDate, interface = interface, locale = GetLocale() }
end

function NS.Summary(run)
    local prefix = (run.requestID and "#" .. run.requestID .. " " or "") .. run.mode .. ": " .. run.status
    if type(run.elapsed) == "number" then prefix = prefix .. string.format(" (%.1f s)", run.elapsed) end
    if not run.raw then return prefix .. (run.reason and " - " .. run.reason or "") end
    return string.format("%s; received=%d, client-filtered=%d; players=%d, groups=%d, self=%d, delisted=%d, missing=%d",
        prefix, run.raw.count, run.filtered.count, run.filtered.solo, run.filtered.groups,
        run.filtered.self, run.filtered.delisted, run.filtered.missing)
end

function NS.Say(message) print(addon.printPrefix, message) end
function NS.SourceLabel(source) return source or "click" end
function NS.NextRequestID()
    local db = NS.Database()
    db.nextRequestID = (tonumber(db.nextRequestID) or 0) + 1
    return db.nextRequestID
end
function NS.SearchParameters(category, filter, preferred, languages, crossFaction, advanced, activities)
    return "category=" .. NS.Describe(category) .. "; activities=" .. NS.Describe(activities)
        .. "; languages=" .. NS.Describe(languages) .. "; filter=" .. NS.Describe(filter)
        .. "; preferred=" .. NS.Describe(preferred) .. "; crossFaction=" .. NS.Describe(crossFaction)
        .. "; advanced=" .. NS.Describe(advanced)
end
function NS.InitializeLog()
    local db = NS.Database()
    if type(db.journal) ~= "table" then db.journal = {} end
    while #db.journal > 50 do table.remove(db.journal, 1) end
end
function NS.Log(kind, message, isError, run)
    NS.InitializeLog()
    local journal = NS.Database().journal
    journal[#journal + 1] = { timestamp = time(), kind = kind, text = message,
        isError = isError or nil, requestID = run and run.requestID }
    while #journal > 50 do table.remove(journal, 1) end
end
function NS.PrintLog(option)
    if option == "clear" then NS.Database().journal = {}; NS.Say("Search log cleared."); return end
    for _, entry in ipairs(NS.Database().journal or {}) do
        if option ~= "errors" or entry.isError then
            NS.Say(date("%d.%m %H:%M:%S", entry.timestamp) .. " " .. entry.kind .. ": " .. entry.text)
        end
    end
end
-- A protected rejection disables this session's manual route. No retries from timers.
function NS.DisableCustomRefresh(reason)
    NS.blocked = true
    NS.Log("Error", "Manual language search disabled until reload: " .. NS.Describe(reason), true)
end

SLASH_GROUPGUARDLANGUAGES1 = "/gglanguages"
SlashCmdList.GROUPGUARDLANGUAGES = function(message)
    local command, option = (message or ""):match("^%s*(%S*)%s*(%S*)%s*$")
    if command == "log" and (option == "" or option == "errors" or option == "clear") then NS.PrintLog(option)
    elseif command == "info" then
        NS.Say(NS.Describe(NS.Context()) .. "; selected=" .. NS.Mode())
        NS.Say("Available: " .. NS.Describe(NS.ReadOptional("GetAvailableLanguageSearchFilter")))
    else
        NS.Say("/gglanguages info; /gglanguages log [errors|clear].")
        NS.Say(NS.Text("HELP"))
    end
end
