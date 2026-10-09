-- Manual request contract and interaction regression tests; no live server required.
local passed, failed = 0, 0
local function check(name, condition)
    if condition then passed = passed + 1; print("  PASS " .. name)
    else failed = failed + 1; print("  FAIL " .. name) end
end
local files = { "Localization", "Languages", "Log", "Search", "UI" }
local function setup(retail, withUI)
    local now, combat, frames, timers, calls = 100, false, {}, {}, {}
    local secureAction, macroErrors = false, {}
    local secret = {}
    _G.GroupGuardLFGDB, _G.ForeverLFGProbeDB = nil, { settings = { language = "ru" } }
    _G.GroupGuardLFGLanguageGlobe, _G.ForeverLFGLanguageGlobe = nil, nil
    SlashCmdList = {}
    GetTime = function() return now end
    time, date = os.time, os.date
    GetLocale = function() return "enUS" end
    GetBuildInfo = function() return retail and "12.0.1" or "1.60.1", "70124", "Sep 29", retail and 120001 or 16001 end
    InCombatLockdown = function() return combat end
    C_Timer = { After = function(delay, fn) timers[#timers+1] = { at=now+delay, fn=fn } end }
    local function widget()
        local w = { shown=true, scripts={}, hooks={}, enabled=true, width=43, height=43 }
        function w:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
        function w:SetScript(event, fn) self.scripts[event] = fn end
        function w:HookScript(event, fn) self.hooks[event] = fn end
        function w:IsShown() return self.shown end
        function w:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
        function w:SetText(v) self.text=v end
        function w:GetText() return self.text end
        function w:SetHeight(v) self.height=v end
        function w:SetWidth(v) self.width=v end
        function w:SetChecked(v) self.checked=v end
        function w:GetChecked() return self.checked end
        function w:GetFontString() if not self.label then self.label=widget() end; return self.label end
        function w:CreateFontString() return widget() end
        function w:SetScrollChild(v) self.child=v end
        function w:GetVerticalScroll() return self.offset or 0 end
        function w:GetVerticalScrollRange() return 100 end
        function w:SetVerticalScroll(v) self.offset=v end
        function w:SetShown(v) self.shown = v end
        function w:Show() self.shown=true; if self.hooks.OnShow then self.hooks.OnShow(self) end end
        function w:Hide() self.shown=false; if self.hooks.OnHide then self.hooks.OnHide(self) end end
        function w:IsMouseOver() return false end
        function w:GetWidth() return self.width end
        function w:GetHeight() return self.height end
        function w:GetFrameStrata() return "HIGH" end
        function w:GetFrameLevel() return 5 end
        function w:SetEnabled(v)
            if self.secure and combat then error("protected Enable in combat") end
            self.enabled=v
        end
        function w:SetAttribute(key,value)
            if self.secure and combat then error("protected attribute write in combat") end
            self.attributes=self.attributes or {}; self.attributes[key]=value
        end
        function w:GetAttribute(key) return self.attributes and self.attributes[key] end
        function w:SetPoint(...) self.point={...} end
        function w:SetSize(x,y) self.width,self.height=x,y end
        function w:SetNormalTexture() self.normal=widget() end
        function w:SetHighlightTexture() self.highlight=widget() end
        function w:GetNormalTexture() return self.normal end
        function w:GetHighlightTexture() return self.highlight end
        function w:CreateTexture() return widget() end
        for _, method in ipairs({ "SetFrameStrata", "SetFrameLevel", "SetClampedToScreen", "SetAtlas", "ClearAllPoints", "RegisterForClicks", "SetWordWrap", "SetJustifyH", "SetJustifyV", "SetColorTexture", "EnableMouse", "EnableMouseWheel", "SetAutoFocus", "SetMaxLetters" }) do w[method]=function() end end
        return w
    end
    local function nativeClick(w)
        if w:GetAttribute("type") == "macro" then
            local macro=w:GetAttribute("macrotext")
            secureAction=true
            local ok,err=pcall(assert(loadstring(macro:sub(6))))
            secureAction=false
            if not ok then macroErrors[#macroErrors+1]=err end
        end
    end
    CreateFrame = function(_, name, parent, template)
        local w=widget(); w.parent=parent; w.template=template; frames[#frames+1]=w
        if template and template:find("SecureActionButtonTemplate",1,true) then
            w.secure=true; w.scripts.OnClick=nativeClick
        end
        if name then _G[name]=w end
        return w
    end
    UIParent = widget()
    local rawResults={101,102}
    LFGBrowseFrame = { IsShown=function() return true end, CategoryDropdown={GetValue=function() return 2 end},
        ActivityDropdown={selectedValues={111,222}}, results=rawResults, totalResults=2, searching=false, RefreshButton=widget() }
    LFGParentFrame = withUI and widget() or nil
    if LFGParentFrame then LFGParentFrame.WhoListingTab=widget() end
    LFGUtil_GetFilteredActivities = function(category) assert(category==2); return {333,444} end
    local available={ "enUS", "ruRU", "deDE", "enUS" }
    local resultInfo={ [101]={numMembers=4}, [102]={numMembers=1} }
    C_LFGList = {
        GetAvailableLanguageSearchFilter=function() return available end,
        GetSearchResults=function() return 2, {101,102} end,
        GetFilteredSearchResults=function() return 2, {101,102} end,
        GetSearchResultInfo=function(id) return resultInfo[id] end,
        Search=function(...) calls[#calls+1]={secure=secureAction,n=select("#",...),...} end,
    }
    C_Macro={RunMacroText=function() error("addon must not call macro API directly") end}
    hooksecurefunc=function(tbl,key,callback)
        local native=tbl[key]
        tbl[key]=function(...) native(...); callback(...) end
    end
    MenuResponse={Refresh=1}
    local menuRoot
    local function menuItem(text, callback, data)
        local item={text=text,callback=callback,data=data}
        function item:SetEnabled(v) self.enabled=v end
        function item:SetResponse() end
        function item:AddInitializer(fn) self.initializer=fn end
        return item
    end
    MenuUtil={CreateContextMenu=function(owner, fn)
        menuRoot={items={}}
        function menuRoot:CreateTitle() end
        function menuRoot:CreateDivider() end
        function menuRoot:CreateButton(text, callback) local item=menuItem(text,callback); self.items[#self.items+1]=item; return item end
        function menuRoot:CreateRadio(text, selected, callback, data) local item=menuItem(text,callback,data); item.selected=selected; self.items[#self.items+1]=item; return item end
        menuRoot.CreateCheckbox=menuRoot.CreateRadio
        fn(owner,menuRoot)
    end}
    local addon={ db={}, version="4.9.4", printPrefix="GG:", IsForeverClient=function() return not retail end,
        GetUILanguage=function() return "ukUA" end, CanAccessValue=function(_,value) return value~=nil and value~=secret end }
    for _, file in ipairs(files) do
        if withUI or file~="UI" then assert(loadfile("../Modules/ForeverSearch/"..file..".lua"))("GroupGuardLFG", addon) end
    end
    -- Simulate the engine's PreClick -> secure template OnClick -> PostClick.
    -- Test convenience Request always performs a physical click; rawRequest does not.
    local rawRequest=addon.ForeverSearch and addon.ForeverSearch.Request
    local function click(button)
        if button.scripts.PreClick then button.scripts.PreClick(button,"LeftButton",false) end
        if button.scripts.OnClick then button.scripts.OnClick(button,"LeftButton",false) end
        if button.scripts.PostClick then button.scripts.PostClick(button,"LeftButton",false) end
    end
    if rawRequest then
        addon.ForeverSearch.Request=function(mode,wide,diagnostic,source,button)
            if button then return rawRequest(mode,wide,diagnostic,source,button) end
            local ns=addon.ForeverSearch
            if not ns.PanelControls then
                local search=CreateFrame("Button",nil,UIParent,"SecureActionButtonTemplate")
                ns.PanelControls={Search=search,Title=widget(),Language=widget(),Status=widget()}
            end
            local search=ns.PanelControls.Search
            local ok=rawRequest(mode,wide,diagnostic,source,search)
            if ok then nativeClick(search) end
            ns.EndClick(search)
            return ok and not ns.blocked and ns.statusKey~="SEARCH_NOT_SENT"
        end
    end
    local function event(name,...)
        for _, frame in ipairs(frames) do
            if frame.events and frame.events[name] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame,name,...) end
        end
    end
    local function advance(delta)
        now=now+delta
        local queued=timers; timers={}
        for _, task in ipairs(queued) do if task.at<=now then task.fn() else timers[#timers+1]=task end end
    end
    return { addon=addon, ns=addon.ForeverSearch, calls=calls, frames=frames, event=event, advance=advance,
        combat=function(v) combat=v end, secret=secret, infos=resultInfo, raw=rawResults,
        menu=function() return menuRoot end, available=available, widget=widget, click=click, rawRequest=rawRequest, macroErrors=macroErrors }
end

print("--- Forever multilingual search ---")
local t=setup(false)
local ns=t.ns
check("fresh profile selects all languages", ns.Mode()=="all")
check("donor SavedVariables remain untouched", ForeverLFGProbeDB.settings.language=="ru")
local filter,canonical=ns.LanguageFilter("all")
check("all includes each API language once", canonical=="all" and filter.enUS and filter.ruRU and filter.deDE)
filter,canonical=ns.LanguageFilter("ruru,enUS,ruru")
check("multi selection canonicalized without duplicate codes", canonical=="enUS,ruRU" and filter.enUS and filter.ruRU and filter.deDE==false)
filter,canonical=ns.LanguageFilter("default")
check("game default passes nil", filter==nil and canonical=="default")
check("unavailable language rejected", select(2,ns.LanguageFilter("xxXX"))==nil)
ns.SelectLanguage("enUS,ruRU")
check("changing languages sends no search", #t.calls==0)
check("UA interface text independent of search languages", ns.Text("ALL_LANGUAGES")=="Усі мови")
t.event("ADDON_LOADED","GroupGuardLFG")
check("initialization sends no search", #t.calls==0)
check("manual multi-language request succeeds", ns.Request())
local call=t.calls[1]
check("Forever seven-argument Search contract preserved", call.n==7 and call[1]==2 and call[2]==0 and call[3]==0 and call[4].enUS and call[4].ruRU and call[4].deDE==false and call[5]==false and call[6]==nil and call[7][1]==111)
check("activities copied instead of sharing native table", call[7]~=LFGBrowseFrame.ActivityDropdown.selectedValues)
check("native search state unchanged", LFGBrowseFrame.results==t.raw and LFGBrowseFrame.totalResults==2 and LFGBrowseFrame.searching==false)
check("concurrent custom request refused", ns.Request()==false and #t.calls==1)
t.event("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("response counts include groups and solo players", ns.resultCounts.groups==1 and ns.resultCounts.solo==1 and not ns.IsPending())
check("five second cooldown prevents duplicate request", ns.Request()==false and #t.calls==1)
t.advance(5)
check("cooldown expiry does not auto search", #t.calls==1)
ns.SelectLanguage("default")
check("default request accepted", ns.Request())
check("default language argument is nil", t.calls[2][4]==nil)
t.event("LFG_LIST_SEARCH_FAILED", "test")
check("failure finishes pending search", not ns.IsPending() and ns.statusKey=="SEARCH_INCOMPLETE")
t.advance(5)
ns.SelectLanguage("")
check("empty selection saved and search disabled", ns.Mode()=="" and ns.Request()==false and #t.calls==2)
ns.SelectLanguage("all"); t.combat(true)
check("combat refuses request", ns.Request()==false and #t.calls==2)
t.combat(false)
LFGBrowseFrame.ActivityDropdown.selectedValues={}
check("empty activity selection uses filtered category list", ns.Request() and t.calls[3][7][1]==333)
t.advance(30)
check("timeout is distinct from empty successful results", ns.statusKey=="SEARCH_INCOMPLETE" and not ns.IsPending())
check("timeout does not retry", #t.calls==3)

local v=setup(false); ns=v.ns
v.event("ADDON_LOADED","GroupGuardLFG")
C_LFGList.Search(2,0,0,nil,false,nil,{111})
check("external native search is observed", ns.IsPending() and ns.Request()==false and #v.calls==1)
v.event("LFG_LIST_SEARCH_RESULTS_RECEIVED"); v.advance(5)
check("can manually search after native response and cooldown", ns.Request())
C_LFGList.Search(2,0,0,nil,false,nil,{111})
check("native search supersedes addon request without false success", ns.IsPending() and ns.statusKey=="NATIVE_SEARCHING")
v.event("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("superseded native results do not claim selected languages", ns.statusKey=="NATIVE_COMPLETE")

v=setup(false); ns=v.ns
LFGBrowseFrame.CategoryDropdown.GetValue=function() return v.secret end
check("secret category rejected", ns.Request()==false and #v.calls==0)
LFGBrowseFrame.CategoryDropdown.GetValue=function() return 2 end
LFGBrowseFrame.ActivityDropdown.selectedValues={v.secret}
check("secret activity rejected", ns.Request()==false and #v.calls==0)
LFGBrowseFrame.ActivityDropdown.selectedValues={111}
v.infos[101].numMembers=v.secret
check("search can start with inaccessible result metadata", ns.Request())
v.event("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("inaccessible result data is counted as missing", ns.resultCounts.missing==1 and ns.resultCounts.solo==1)
v.advance(5)
C_LFGList.GetAvailableLanguageSearchFilter=nil
check("missing language API disables all-language search", ns.Request()==false and #v.calls==1)
ns.SelectLanguage("default")
check("game default works without language-list API", ns.Request())

v=setup(false); ns=v.ns
v.event("ADDON_ACTION_BLOCKED","GroupGuardLFG","Button:SetPassThroughButtons()")
check("unrelated addon block does not disable search", not ns.blocked)
C_LFGList.Search=function() v.event("ADDON_ACTION_BLOCKED","GroupGuardLFG","C_LFGList.Search()") end
check("blocked Search returns failure", ns.Request()==false and ns.blocked)
v.advance(60)
check("blocked session never retries and menu stays disabled", ns.Request()==false and select(1,ns.SearchButtonState())==false)
for i=1,80 do ns.Log("Test","event") end
check("diagnostic journal bounded at 50 entries", #ns.Database().journal==50)
local selected=ns.Mode(); ns.PrintLog("clear")
check("clearing journal preserves languages", ns.Mode()==selected and #ns.Database().journal==0)

v=setup(true,true)
check("Retail does not initialize module or create frames", v.ns==nil and #v.frames==0 and SlashCmdList.GROUPGUARDLANGUAGES==nil)

v=setup(false,true); ns=v.ns
local native=LFGBrowseFrame.RefreshButton
local panel=v.widget(); panel.parent=UIParent
v.addon.lfgFilterPanel=panel
ns.AttachPanel(panel)
local row=panel.ggLanguageControls
check("language controls belong to the existing filter panel", row and row.parent==panel and row.Language.parent==row and row.Search.parent==row)
check("no additional globe or language launcher is created", _G.GroupGuardLFGLanguageGlobe==nil and ns.Globe==nil)
check("integrated controls preserve native refresh", LFGBrowseFrame.RefreshButton==native and native.scripts.OnClick==nil and #v.calls==0)
row.Language.scripts.OnClick(row.Language)
check("opening embedded language dropdown sends no request", v.menu() and #v.calls==0)
v.click(row.Search)
check("embedded Search button sends selected languages", #v.calls==1 and v.calls[1][4].enUS and v.calls[1][4].ruRU)
check("embedded Search disables during active request", row.Search.enabled==false)
v.event("LFG_LIST_SEARCH_RESULTS_RECEIVED"); v.advance(5)
row.scripts.OnUpdate(row,.25)
check("embedded Search enables after cooldown without request", row.Search.enabled and #v.calls==1)
local languageItem=v.menu().items[#v.menu().items]
languageItem.callback(languageItem.data)
check("embedded checkbox changes saved languages without request", ns.Mode()=="deDE" and #v.calls==1 and row.Language.text=="deDE")
v.click(row.Search)
check("embedded Search uses saved checkbox selection", #v.calls==2 and v.calls[2][4].deDE and v.calls[2][4].enUS==false)
local count=#v.frames
ns.AttachPanel(panel)
check("panel reattachment reuses controls", #v.frames==count and panel.ggLanguageControls==row)
panel:Hide()
check("closing original panel hides all embedded controls", not row:IsVisible())
panel:Show()
check("reopening original panel does not query", row:IsVisible() and #v.calls==2)
ns.SelectLanguage("")
check("empty embedded selection disables Search", row.Search.enabled==false)

-- Verify the imported language request feeds the existing GroupGuard filters.
v=setup(false); ns=v.ns
local addon=v.addon
addon.db.lfg_filters_enabled=true
addon.db.lfg_filter_group_roles={TANK=true,HEALER=true,DAMAGER=false}
addon.db.lfg_filter_group_has_roles={}
addon.db.lfg_filter_player_roles={HEALER=true,DAMAGER=true}
addon.db.lfg_filter_player_classes={DRUID=true,MAGE=true}
addon.db.lfg_filter_player_min_level=0
addon.db.lfg_filter_player_max_level=0
addon.SafeNumber=function(_,x,fallback) return tonumber(x) or fallback end
addon.SafeObjectField=function(_,object,key) return object and object[key] end
addon.Tr=function(_,key) return key end
addon.HasClientCapability=function() return true end
v.infos[101].activityIDs={111}
v.infos[102].activityIDs={111}
addon.LFG_API_GetSearchResultInfo=function(_,id) return v.infos[id] end
local roles={TANK_REMAINING=1,HEALER_REMAINING=0,DAMAGER_REMAINING=1}
addon.LFG_API_GetSearchResultMemberCounts=function() return roles end
addon.LFG_API_GetActivityInfoTable=function() return {categoryID=2,useDungeonRoleExpectations=true,maxNumPlayers=5} end
addon.LFG_API_GetSearchResultPlayerInfo=function() return {classFilename="DRUID",assignedRole="HEALER",lfgRoles={healer=true,dps=false}} end
assert(loadfile("../Modules/LFGFilters.lua"))("GroupGuardLFG",addon)
local savedRoles=addon.db.lfg_filter_group_roles
check("all-language request returns listings for our filters", ns.Request())
v.event("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("language request preserves configured GroupGuard role filters", addon.db.lfg_filter_group_roles==savedRoles)
check("multi-language results still reject group needing only tank", addon:LFGFilters_ResultMatches(101,{})==false)
roles.HEALER_REMAINING=1
check("multi-language results accept group needing tank and healer", addon:LFGFilters_ResultMatches(101,{})==true)
check("multi-language player results retain class/role OR matching", addon:LFGFilters_ResultMatches(102,{})==true)

assert(loadfile("../Modules/ForeverSearch/UI.lua"))("GroupGuardLFG",addon)
addon.db.lfg_filter_presets={}
addon.db.lfg_filter_social_priority=true
addon.HasClientCapability=function() return false end
local filterPanel=addon:LFGFilters_CreatePanel(UIParent)
check("real filter panel creation attaches embedded language row", filterPanel.ggLanguageControls and filterPanel.ggLanguageControls.parent==filterPanel)
check("existing filter content has a scroll viewport", filterPanel.ggContentScroll and filterPanel.ggContentScroll.child==filterPanel.ggContent)
filterPanel.ggContentScroll.scripts.OnMouseWheel(filterPanel.ggContentScroll,-1)
check("filter wheel scrolls down inside bounds", filterPanel.ggContentScroll.offset==32)
filterPanel.ggContentScroll.scripts.OnMouseWheel(filterPanel.ggContentScroll,-10)
check("filter scroll clamps at bottom", filterPanel.ggContentScroll.offset==100)
filterPanel.ggContentScroll.scripts.OnMouseWheel(filterPanel.ggContentScroll,10)
check("filter scroll clamps at top", filterPanel.ggContentScroll.offset==0)
local controls=filterPanel.ggLanguageControls
addon:LFGFilters_RebuildPanelContents()
check("filter rebuild preserves embedded controls", filterPanel.ggLanguageControls==controls and controls.Language.text==ns.LanguageLabel(ns.Mode()))
local nativeShow,nativeHide=filterPanel.Show,filterPanel.Hide
local combatVisible=true
filterPanel:Show()
filterPanel.Show=function(self) if combatVisible then error("protected panel Show") end; nativeShow(self) end
filterPanel.Hide=function(self) if combatVisible then error("protected panel Hide") end; nativeHide(self) end
v.combat(true)
addon:LFGFilters_SetPanelShown(false)
check("protected panel hide is deferred during combat", filterPanel:IsShown() and addon._ggDeferredPanelShown==false)
addon:LFGFilters_LayoutPanel()
filterPanel.CloseButton.scripts.OnClick()
check("panel close in combat does not invoke protected Hide", filterPanel:IsShown() and addon.db.lfg_filter_panel_open==false)
v.combat(false); combatVisible=false; v.event("PLAYER_REGEN_ENABLED")
check("deferred panel close runs after combat", not filterPanel:IsShown() and addon._ggDeferredPanelShown==nil)
filterPanel.Show,filterPanel.Hide=nativeShow,nativeHide



v=setup(false); ns=v.ns
ns.Request(); ns.SelectLanguage("enUS"); v.event("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("selection changed during request requires another search", ns.statusKey=="REFRESH_LANGUAGE")
v.advance(5); ns.Request(); v.advance(30)
check("timeout remains incomplete", ns.statusKey=="SEARCH_INCOMPLETE")
ns.Request(); v.event("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("response after timeout never falsely confirms language", ns.statusKey=="LANGUAGE_UNCONFIRMED")
v.advance(5); ns.Request(); v.event("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("next completed search recovers after the ambiguous response", ns.statusKey=="SEARCH_COMPLETE")
v.advance(5); ns.Request(); v.event("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("timeout uncertainty does not stick across later searches", ns.statusKey=="SEARCH_COMPLETE")


v=setup(false); ns=v.ns
C_LFGList.Search=function() error("API call failed") end
check("macro error is immediately reported as not sent", ns.Request()==false and not ns.IsPending() and ns.statusKey=="SEARCH_NOT_SENT" and #v.macroErrors==1)
v.advance(60)
check("unsent macro never waits for a response or retries", not ns.IsPending() and ns.statusKey=="SEARCH_NOT_SENT" and #v.macroErrors==1)

v=setup(false); ns=v.ns
hooksecurefunc=function() error("hook unavailable") end
check("observer installation failure prevents untracked request", ns.Request()==false and #v.calls==0)


-- Protected search regression: preparation never invokes Search from addon Lua.
v=setup(false); ns=v.ns
check("no programmatic Request without the embedded button", v.rawRequest()==false and #v.calls==0)
local secureButton=CreateFrame("Button",nil,UIParent,"SecureActionButtonTemplate")
ns.PanelControls={Search=secureButton}
check("PreClick only arms a macro, without calling Search", v.rawRequest(nil,nil,false,"filter-panel",secureButton) and #v.calls==0 and secureButton:GetAttribute("type")=="macro")
local macro=secureButton:GetAttribute("macrotext")
check("macro uses only native API and literals", macro:find("C_LFGList.Search",1,true) and not macro:find("GroupGuard",1,true) and not macro:find("pcall",1,true) and #macro<=1023)
secureButton.scripts.OnClick(secureButton)
ns.EndClick(secureButton)
check("secure engine action preserves all seven search arguments", #v.calls==1 and v.calls[1].secure and v.calls[1].n==7 and v.calls[1][4].enUS and v.calls[1][6]==nil and v.calls[1][7][1]==111)
check("PostClick disarms macro and issuing state", secureButton:GetAttribute("type")==nil and secureButton:GetAttribute("macrotext")==nil and not ns.IsIssuing())
v.event("ADDON_ACTION_BLOCKED","OtherAddon","UNKNOWN()")
check("another addon's UNKNOWN does not cancel our request", ns.IsPending() and not ns.blocked)
v.event("ADDON_ACTION_FORBIDDEN","GroupGuardLFG","UNKNOWN()")
check("asynchronous UNKNOWN ends our request and disables Search", not ns.IsPending() and ns.blocked and select(1,ns.SearchButtonState())==false)
v.advance(60)
check("UNKNOWN rejection never retries", #v.calls==1 and ns.Request()==false)

v=setup(false); ns=v.ns
C_LFGList.Search=function() v.event("ADDON_ACTION_BLOCKED","GroupGuardLFG","UNKNOWN()") end
check("synchronous UNKNOWN rejection disables Search", ns.Request()==false and ns.blocked and not ns.IsPending())
v=setup(false); ns=v.ns
v.event("ADDON_ACTION_BLOCKED","GroupGuardLFG","UNKNOWN()")
check("UNKNOWN outside our attempt is not attributed to search", not ns.blocked)
C_Macro=nil
check("no direct fallback when secure macro API is absent", ns.Request()==false and #v.calls==0)

v=setup(false,true); ns=v.ns
local combatPanel=v.widget(); combatPanel.parent=UIParent
ns.AttachPanel(combatPanel)
v.combat(true)
ns.UpdateUI(); v.click(combatPanel.ggLanguageControls.Search)
check("combat never writes protected attributes or launches Search", #v.calls==0 and not ns.IsPending())
v.combat(false); v.event("PLAYER_REGEN_ENABLED")
check("combat end restores the embedded Search button", combatPanel.ggLanguageControls.Search.enabled)
check("secure template native OnClick remains installed", combatPanel.ggLanguageControls.Search.secure and combatPanel.ggLanguageControls.Search.scripts.OnClick~=nil)

v=setup(false); ns=v.ns
local values={}; for i=1,400 do values[i]=100000+i end
LFGBrowseFrame.ActivityDropdown.selectedValues=values
check("oversized activity macro is rejected without truncation", ns.Request()==false and #v.calls==0 and not ns.IsPending())

v=setup(false); ns=v.ns
ns.SelectLanguage("ruRU"); ns.Request(); v.advance(30)
check("observed request times out without confirmation", ns.statusKey=="SEARCH_INCOMPLETE")
ns.SelectLanguage("zhCN"); ns.Request(); v.event("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("first response after timeout stays conservatively unconfirmed", ns.statusKey=="LANGUAGE_UNCONFIRMED")
for _,mode in ipairs({"zhCN,esMX","esMX","ruRU","koKR","koKR"}) do
    v.advance(5); ns.SelectLanguage(mode); ns.Request(); v.event("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    check("user log recovery sequence "..mode, ns.statusKey=="SEARCH_COMPLETE")
end
local observed=0
for _,entry in ipairs(ns.Database().journal) do if entry.kind=="Dispatch" then observed=observed+1 end end
check("journal records actual native API dispatches", observed>=5)

v=setup(false); ns=v.ns
ns.Request(); v.advance(30); v.event("LFG_LIST_SEARCH_RESULTS_RECEIVED")
v.advance(5); ns.Request(); v.event("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("late response without a new pending request clears old uncertainty", ns.statusKey=="SEARCH_COMPLETE")

v=setup(false); ns=v.ns
ns.Request(); v.advance(30); ns.Request(); v.event("LFG_LIST_SEARCH_FAILED","test")
v.advance(5); ns.Request(); v.event("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("terminal failure also clears the uncertainty window", ns.statusKey=="SEARCH_COMPLETE")

v=setup(false,true); ns=v.ns
local noDispatchPanel=v.widget(); noDispatchPanel.parent=UIParent
ns.AttachPanel(noDispatchPanel)
local noDispatchButton=noDispatchPanel.ggLanguageControls.Search
noDispatchButton.scripts.OnClick=function() end
v.click(noDispatchButton)
check("missing secure dispatch does not fake a 30-second search", ns.statusKey=="SEARCH_NOT_SENT" and not ns.IsPending() and #v.calls==0)
check("unsent click keeps manual retry available without cooldown", ns.SearchButtonState()==true)
v.advance(60)
check("no dispatch does not poison later request attribution", ns.statusKey=="SEARCH_NOT_SENT")

v=setup(false); ns=v.ns
ns.Request(); v.event("LFG_LIST_SEARCH_RESULTS_RECEIVED")
v.addon._ggForeverVisibleResults=42
v.addon.LFGFilters_GetForeverVisibleCount=function() return nil,"provider replaced" end
v.advance(.1)
local view=ns.Database().journal[#ns.Database().journal]
check("view diagnostic does not report a stale previous count", view.kind=="View" and view.text:find("not settled (provider replaced)",1,true)~=nil and not view.text:find("visible=42",1,true))

v=setup(false); ns=v.ns
ns.Request(); v.event("LFG_LIST_SEARCH_RESULTS_RECEIVED")
v.addon.LFGFilters_GetForeverVisibleCount=function() return 0 end
v.advance(.05)
check("view diagnostic waits until the presentation passes finish", ns.Database().journal[#ns.Database().journal].kind~="View")
v.advance(.05)
view=ns.Database().journal[#ns.Database().journal]
check("verified empty presentation is reported as zero", view.kind=="View" and view.text:find("visible=0",1,true)~=nil)

v=setup(false); ns=v.ns
C_LFGList.Search=function(...)
    v.calls[#v.calls+1]={n=select("#",...),...}
    v.event("LFG_LIST_SEARCH_RESULTS_RECEIVED")
end
check("synchronous response survives post-hook dispatch observation", ns.Request() and ns.statusKey=="SEARCH_COMPLETE" and not ns.IsPending())
v.advance(60)
check("synchronous completion never starts a timeout or retry", ns.statusKey=="SEARCH_COMPLETE" and #v.calls==1)

print(string.format("Multilingual search: %d passed, %d failed", passed, failed))
if failed>0 then os.exit(1) end
