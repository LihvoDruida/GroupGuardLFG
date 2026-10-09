-- Embedded language selection; uses only GroupGuard's existing filter panel.
-- Language menu adapted from ForeverLFG 0.5.3 (MIT; see LICENSE-ForeverLFG).
local addonName, addon = ...
if not (addon.IsForeverClient and addon:IsForeverClient()) then return end
local NS = addon.ForeverSearch
local T = NS.Text

function NS.UpdateUI()
    local row = NS.PanelControls
    if not row then return end
    row.Title:SetText(T("LANGUAGE_MENU"))
    row.Language:SetText(NS.LanguageLabel(NS.Mode()))
    local enabled, key, remaining = NS.SearchButtonState()
    if not InCombatLockdown() and not NS.IsIssuing() then row.Search:SetEnabled(enabled) end
    row.Search:SetText(T("SEARCH_BUTTON"))
    row.Status:SetText(enabled and NS.ShortStatus() or (remaining and T(key, remaining) or T(key)))
end

local function SelectMode(value)
    NS.SelectLanguage(value)
    NS.UpdateUI()
end

local function Menu(_, root)
    root:CreateTitle(T("LANGUAGE_MENU"))
    local available = NS.AvailableLanguages()
    local function selected(mode) return NS.Mode() == mode end
    local all = root:CreateRadio(T("ALL_LANGUAGES"), selected, SelectMode, "all")
    all:SetEnabled(available ~= nil)
    if MenuResponse then all:SetResponse(MenuResponse.Refresh) end
    local default = root:CreateRadio(T("GAME_DEFAULT"), selected, SelectMode, "default")
    if MenuResponse then default:SetResponse(MenuResponse.Refresh) end
    root:CreateDivider()
    for _, code in ipairs(available or {}) do
        local label = NS.LanguageLabel(code)
        local checkbox = root:CreateCheckbox(label == code and code or (label .. " (" .. code .. ")"), function(value)
            for item in NS.Mode():gmatch("[^,]+") do if item == value then return true end end
            return false
        end, function(value)
            local chosen, mode = {}, NS.Mode()
            if mode ~= "all" and mode ~= "default" then
                for item in mode:gmatch("[^,]+") do chosen[item] = true end
            end
            chosen[value] = not chosen[value]
            local codes = {}
            for item, checked in pairs(chosen) do if checked then codes[#codes + 1] = item end end
            table.sort(codes)
            SelectMode(table.concat(codes, ","))
        end, code)
        if MenuResponse then checkbox:SetResponse(MenuResponse.Refresh) end
    end
end

function NS.OpenLanguageMenu(owner)
    if not MenuUtil or type(MenuUtil.CreateContextMenu) ~= "function" then return end
    MenuUtil.CreateContextMenu(owner, Menu)
end

function NS.AttachPanel(panel)
    if panel.ggLanguageControls or InCombatLockdown() then return end
    local row = CreateFrame("Frame", nil, panel)
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 11, -31)
    row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -27, -31)
    row:SetHeight(72)
    panel.ggLanguageControls = row
    NS.PanelControls = row

    row.Title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.Title:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -2)
    row.Language = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.Language:SetSize(192, 22)
    row.Language:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -22)
    local label = row.Language:GetFontString()
    if label then label:SetWidth(172); label:SetWordWrap(false) end
    row.Language:SetScript("OnClick", function(self) NS.OpenLanguageMenu(self) end)
    row.Language:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(T("LANGUAGE_MENU"))
        GameTooltip:AddLine(NS.LanguageLabel(NS.Mode()), 1, .82, 0, true)
        GameTooltip:AddLine(T("SELECT_HINT"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row.Language:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    row.Search = CreateFrame("Button", nil, row, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    row.Search:SetSize(98, 22)
    row.Search:SetPoint("TOPLEFT", row, "TOPLEFT", 208, -22)
    row.Search:RegisterForClicks("LeftButtonUp")
    row.Search:SetAttribute("useOnKeyDown", false)
    -- Keep the template's native OnClick; PreClick only arms validated literals.
    row.Search:SetScript("PreClick", function(self, button, down)
        if button == "LeftButton" and not down then NS.Request(nil, nil, false, "filter-panel", self) end
    end)
    row.Search:SetScript("PostClick", function(self) NS.EndClick(self) end)
    row.Status = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.Status:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -49)
    row.Status:SetWidth(298)
    row.Status:SetJustifyH("LEFT")
    row.Status:SetWordWrap(false)
    local divider = row:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(.35, .32, .25, .75)
    divider:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -69)
    divider:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -69)
    divider:SetHeight(1)
    local elapsed = 0
    row:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= .25 then elapsed = 0; NS.UpdateUI() end
    end)
    row:SetScript("OnShow", NS.UpdateUI)
    NS.UpdateUI()
end
