-- GroupGuard LFG — client/flavor capability detection
-- Keep compatibility decisions capability-based. WoW Forever currently shares
-- much of the modern 12.x runtime, while exposing the VanillaStyle group finder.
local addonName, addon = ...

local type, tonumber, tostring = type, tonumber, tostring

local function HasFunction(tbl, key)
  return type(tbl) == "table" and type(tbl[key]) == "function"
end

function addon:RefreshClientCapabilities()
  local version, build, buildDate, interfaceVersion = nil, nil, nil, nil
  if type(GetBuildInfo) == "function" then
    local ok, v, b, d, i = pcall(GetBuildInfo)
    if ok then
      version, build, buildDate, interfaceVersion = v, b, d, tonumber(i)
    end
  end

  local versionText = type(version) == "string" and version or ""
  local iface = interfaceVersion or 0
  local isForever = (iface >= 16000 and iface < 17000) or versionText:match("^1%.60%.") ~= nil
  local isRetail12 = iface >= 120000 and iface < 130000

  self.Client = self.Client or {}
  self.Client.version = versionText
  self.Client.build = build
  self.Client.buildDate = buildDate
  self.Client.interfaceVersion = iface
  self.Client.isForever = isForever
  self.Client.isRetail12 = isRetail12
  self.Client.groupFinderStyle = isForever and "vanilla-style" or (isRetail12 and "mainline" or "unknown")

  local caps = self.Client.capabilities or {}
  self.Client.capabilities = caps

  caps.lfg = type(C_LFGList) == "table"
  caps.lfgSearch = caps.lfg and HasFunction(C_LFGList, "Search")
  caps.lfgSearchResults = caps.lfg and (HasFunction(C_LFGList, "GetFilteredSearchResults") or HasFunction(C_LFGList, "GetSearchResults"))
  caps.lfgSearchInfo = caps.lfg and HasFunction(C_LFGList, "GetSearchResultInfo")
  caps.lfgSearchPlayerInfo = caps.lfg and HasFunction(C_LFGList, "GetSearchResultPlayerInfo")
  caps.lfgSearchMemberCounts = caps.lfg and HasFunction(C_LFGList, "GetSearchResultMemberCounts")
  caps.lfgLeaderInfo = caps.lfg and HasFunction(C_LFGList, "GetSearchResultLeaderInfo")
  caps.lfgApplicants = caps.lfg and HasFunction(C_LFGList, "GetApplicants") and HasFunction(C_LFGList, "GetApplicantInfo") and HasFunction(C_LFGList, "GetApplicantMemberInfo")
  caps.lfgDeclineApplicant = caps.lfg and HasFunction(C_LFGList, "DeclineApplicant")
  caps.lfgAdvancedFilter = caps.lfg and HasFunction(C_LFGList, "GetAdvancedFilter") and HasFunction(C_LFGList, "SaveAdvancedFilter")
  caps.lfgCensor = caps.lfg and HasFunction(C_LFGList, "RevealCensoredSearchResult")
  caps.lfgRoles = type(C_LFGListRoles) == "table" and HasFunction(C_LFGListRoles, "GetRoles")
  caps.scrollBox = type(ScrollUtil) == "table" or type(CreateScrollBoxListLinearView) == "function" or type(CreateScrollBoxListTreeListView) == "function"
  caps.modernLFGFrame = _G.LFGListFrame ~= nil
  caps.foreverLFGFrame = _G.LFGBrowseFrame ~= nil or _G.LFGParentFrame ~= nil or _G.LFGListingFrame ~= nil
  -- Applicant management is a Mainline ApplicationViewer workflow. Forever can
  -- expose overlapping C_LFGList functions without exposing that UI, so API
  -- presence alone is not enough to enable applicant-only features.
  caps.lfgApplicantUI = not isForever and _G.LFGListFrame ~= nil and _G.LFGListFrame.ApplicationViewer ~= nil

  -- Feature-level capabilities used by settings and modules. Keep these based on
  -- API contracts rather than frame presence because Blizzard LFG UI is LoD.
  caps.lfgSearchUI = caps.lfgSearchResults and caps.lfgSearchInfo and (isRetail12 or isForever or caps.modernLFGFrame or caps.foreverLFGFrame)
  caps.lfgSearchMemberRules = caps.lfgSearchUI and caps.lfgSearchPlayerInfo
  caps.lfgSearchRoleNeeds = caps.lfgSearchUI and caps.lfgSearchMemberCounts
  caps.lfgSearchTooltips = caps.lfgSearchUI and caps.lfgSearchInfo
  caps.lfgRealmInsights = caps.lfgSearchUI and caps.lfgLeaderInfo
  caps.lfgApplicantActions = (not isForever) and caps.lfgApplicants and caps.lfgDeclineApplicant
  caps.pgfIntegration = not isForever
  caps.partyUninvite = (type(C_PartyInfo) == "table" and HasFunction(C_PartyInfo, "UninviteUnit")) or type(UninviteUnit) == "function"
  caps.raidPromoteAssistant = (type(C_PartyInfo) == "table" and HasFunction(C_PartyInfo, "PromoteToAssistant")) or type(PromoteToAssistant) == "function"
  caps.raidDemoteAssistant = (type(C_PartyInfo) == "table" and HasFunction(C_PartyInfo, "DemoteAssistant")) or type(DemoteAssistant) == "function"
  caps.frameMarkers = isRetail12 or isForever or _G.CompactRaidFrameContainer ~= nil or _G.CompactPartyFrame ~= nil

  return self.Client
end

function addon:IsForeverClient()
  if not self.Client then self:RefreshClientCapabilities() end
  return self.Client and self.Client.isForever == true
end

function addon:IsRetail12Client()
  if not self.Client then self:RefreshClientCapabilities() end
  return self.Client and self.Client.isRetail12 == true
end

function addon:HasClientCapability(name)
  if not self.Client or not self.Client.capabilities then self:RefreshClientCapabilities() end
  return self.Client and self.Client.capabilities and self.Client.capabilities[name] == true
end

-- The active search frame is intentionally resolved at call time because both
-- Blizzard group finder implementations are load-on-demand.
function addon:GetLFGSearchFrame()
  if _G.LFGBrowseFrame then return _G.LFGBrowseFrame end
  local modern = _G.LFGListFrame
  if modern and modern.SearchPanel then return modern.SearchPanel end
  return nil
end

function addon:GetLFGRootFrame()
  if _G.LFGParentFrame then return _G.LFGParentFrame end
  if _G.LFGListFrame then return _G.LFGListFrame end
  if _G.PVEFrame then return _G.PVEFrame end
  if _G.LookingForGroupFrame then return _G.LookingForGroupFrame end
  if _G.LFDParentFrame then return _G.LFDParentFrame end
  return nil
end

function addon:GetLFGApplicantViewer()
  local modern = _G.LFGListFrame
  return modern and modern.ApplicationViewer or nil
end

function addon:SupportsLFGApplicantUI()
  -- Resolve this dynamically because Blizzard_GroupFinder is load-on-demand.
  -- Never infer support from C_LFGList.GetApplicants on Forever: the client can
  -- expose APIs that have no matching ApplicationViewer surface.
  if self:IsForeverClient() then return false end
  return self:GetLFGApplicantViewer() ~= nil
end

function addon:SupportsLFGApplicantSettings()
  -- Settings are created before the Mainline ApplicationViewer may exist, so
  -- use the API contract here and keep Forever explicitly excluded.
  if self:IsForeverClient() then return false end
  return self:HasClientCapability("lfgApplicantActions")
end

function addon:SupportsPGFIntegration()
  return self:HasClientCapability("pgfIntegration")
end

function addon:SupportsPartyUninvite()
  return self:HasClientCapability("partyUninvite")
end

function addon:SupportsRaidAssistActions()
  return self:HasClientCapability("raidPromoteAssistant")
end

addon:RefreshClientCapabilities()
