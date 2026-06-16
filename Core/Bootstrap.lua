local addonName, addon = ...

local function GetAddonMetadataValue(field, fallback)
  local value = nil

  if C_AddOns and C_AddOns.GetAddOnMetadata then
    local ok, result = pcall(C_AddOns.GetAddOnMetadata, addonName, field)
    if ok and result and result ~= "" then value = result end
  end

  if not value and GetAddOnMetadata then
    local ok, result = pcall(GetAddOnMetadata, addonName, field)
    if ok and result and result ~= "" then value = result end
  end

  return value or fallback
end

addon.version = GetAddonMetadataValue("Version", "dev")
addon.codename = GetAddonMetadataValue("X-Codename", "Release Candidate")
addon.displayName = GetAddonMetadataValue("Title", "GroupGuard LFG")
addon.author = GetAddonMetadataValue("Author", "LihvoDruida")
addon.printPrefix = "|cffd33b2fGroupGuard LFG|r:"
addon.debug = false

local pairs, type, string = pairs, type, string
local IsInRaid, IsInGroup, UnitAffectingCombat = IsInRaid, IsInGroup, UnitAffectingCombat
local GetNumGroupMembers, UnitName, GetGuildInfo = GetNumGroupMembers, UnitName, GetGuildInfo
local GetRealmName, GetBuildInfo = GetRealmName, GetBuildInfo
local GetInstanceInfo = GetInstanceInfo
local IsInInstance = IsInInstance

local MEDIA_DIR = "Interface\\AddOns\\GroupGuardLFG\\Media\\"
local WARN_SOUND = MEDIA_DIR .. "warn.ogg"

function addon:SafeGetTime()
  return (GetTime and GetTime()) or 0
end

function addon:CanAccessValue(value)
  if value == nil then return false end
  if type(canaccessvalue) == "function" then
    local ok, allowed = pcall(canaccessvalue, value)
    if not ok or not allowed then return false end
  end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret then return false end
  end
  return true
end

function addon:CallAPI(fn, ...)
  if type(fn) ~= "function" then return false end
  return pcall(fn, ...)
end

function addon:PlayerCanManageGroup()
  if UnitIsGroupLeader then
    local ok, leader = pcall(UnitIsGroupLeader, "player")
    if ok and leader then return true end
  end

  if IsInRaid then
    local okRaid, inRaid = pcall(IsInRaid)
    if okRaid and inRaid then
      if UnitIsGroupAssistant then
        local ok, assistant = pcall(UnitIsGroupAssistant, "player")
        if ok and assistant then return true end
      end
      if UnitIsRaidOfficer then
        local ok, officer = pcall(UnitIsRaidOfficer, "player")
        if ok and officer then return true end
      end
    end
  end

  return false
end

function addon:GetGroupMemberCount()
  if not GetNumGroupMembers then return 0 end
  local ok, count = pcall(GetNumGroupMembers)
  return ok and tonumber(count) or 0
end

function addon:IsExemptUnit(name, realm, guild_name)
  return false
end

addon.DEFAULTS = {
  ui_language = "auto",
  startup_silent_seconds = 3.0,
  suppress_action_spam = true,
  show_in_party = true,
  show_in_raid  = true,
  auto_leave    = false,
  show_banner      = true,
  banner_hold_time = 10,
  play_sound  = true,
  sound_kit   = "FILE",
  sound_file  = WARN_SOUND,
  screen_flash = true,
  alert_style = "COMPACT",
  confirm_leave = true,
  flag_rules = "boost, wts, sell, carry, gdkp, gold only, spam",
  -- Language auto-detect is optional and OFF by default.
  -- It detects language/text signals only; it does not infer nationality.
  language_detect_enabled = false,
  language_detect_keywords = true,
  language_detect_scripts = false,
  language_detect_rules = "ru voice, russian voice, russian only, only russian, ru only, only ru, рус voice, русский voice, только русский, только рус, говорим по-русски",
  language_script_cyrillic = true,
  language_script_greek = true,
  language_script_arabic = true,
  language_script_hebrew = true,
  language_script_cjk = true,
  language_script_kana = true,
  language_script_hangul = true,
  scan_group_names = true,
  scan_group_guilds = true,
  sound_presets = { WARN_SOUND },
  lfg_show_button = true,
  lfg_highlight = true,
  lfg_highlight_search_members = true,
  lfg_button_text = "Decline LFG applications (%d)",
  lfg_auto_decline = false,
  lfg_auto_decline_notify = true,
  lfg_auto_decline_batch_limit = 5,
  lfg_auto_decline_delay = 0.12,
  lfg_tooltips = true,
  lfg_tooltip_reasons = true,
  lfg_tooltip_details = true,
  lfg_role_fit_hints = true,
  lfg_mute_applicant_ping = true,
  realm_insights = true,
  realm_badges = true,
  realm_same_locale_only = true,
  applicant_summary_chips = true,
  applicant_cards_enabled = true,
  applicant_summary_tooltips = true,
  applicant_auto_refresh_done = true,
  pgf_integration = true,
  alert_sound_cooldown = 10,
  alert_flash_cooldown = 10,
  scan_debounce = 0.03,
  lfg_debounce = 0.02,
  kick_button_enabled = true,
  disable_in_bg = true,
  disable_in_arena = true,
  frame_markers_enabled = true,
  frame_marker_size = 1,
  social_ignore_friends = true,
  social_ignore_guild = true,
  social_mark_friends = true,
  social_mark_guild = true,
  social_mark_lfg = true,
  raid_assist_enabled = true,
  raid_assist_guild_officers = true,
  raid_assist_officer_rank_max = 2,
  raid_assist_officer_keywords = "Офіцер, офіцер, Officer, officer, Шинкар, шинкар, Raid Leader, raid leader, raidlead, raid lead, RL, rl",
  raid_assist_selected_ranks = "",
  raid_assist_manual_names = "",
  raid_assist_notify = true,
}

addon.L10N = {
  enUS = {
    UI_LANG_AUTO = "Game client language",
    UI_LANG_EN = "English",
    UI_LANG_UK = "Ukrainian",
    MARKED = "MARKED",
    AUTO_DECLINED = "AUTO-DECLINED",
    TEST = "TEST",
    DEFAULT_DETAIL = "Check the rules or group roster.",
    LFG_AUTO_TITLE = "Auto-declined: %d",
    LFG_MARKED_RULES = "Marked by LFG rules",
    LFG_AUTO_DETAIL = "Auto-decline is enabled. Manual fallback stays available if anything remains.",
    TEST_ALERT_TITLE = "Notification test",
    TEST_ALERT_DETAIL = "Compact panel, close button and fade-out.",
    CONFIRM_LEAVE = "Rule match detected. Leave the group?",
    CONFIRM_LEAVE_PARTY = "Rule match detected. Leave the party?",
    CONFIRM_LEAVE_RAID = "Rule match detected. Leave the raid?",
    NONE_SELECTED = "None selected",
    DETECTED_MATCH = "Rule match detected",
    REASON_LANGUAGE = "Language phrase: %s",
    REASON_SCRIPT = "Script: %s",
    REASON_RULE = "Rule: %s",
    LABEL_COMMENT = "Comment",
    LABEL_NAME = "Name",
    LABEL_MEMBER = "Member",
    LABEL_TITLE = "Title",
    LABEL_LEADER = "Leader",
    LABEL_VOICE = "Voice",
    LABEL_FRIEND = "friend",
    LABEL_GUILD = "guild",
    LABEL_MARKED = "marked",
    TOOLTIP_FRIEND_GROUP = "GroupGuard LFG — friend in group",
    TOOLTIP_GUILD_GROUP = "GroupGuard LFG — guild member in group",
    TOOLTIP_FRIEND_APP = "GroupGuard LFG — friend in application",
    TOOLTIP_GUILD_APP = "GroupGuard LFG — guild member in application",
    TOOLTIP_MARKED = "Marked by GroupGuard",
    LFG_DECLINE_BUTTON = "Decline LFG applications",
    LFG_DECLINE_BUTTON_FMT = "Decline LFG applications (%d)",
    LFG_DECLINED_PRINT = "Declined LFG applications: %d",
    LFG_DECLINE_FAILED_PRINT = "Failed to decline LFG applications: %d",
    KICK_BUTTON = "Remove from group",
    KICK_BUTTON_FMT = "Remove from group (%d)",
    LEAVE_GROUP_BUTTON = "Leave group",
    LEAVE_PARTY_BUTTON = "Leave party",
    LEAVE_RAID_BUTTON = "Leave raid",
    IN_COMBAT_KICK_QUEUE = "You are in combat — kick is queued.",
    NO_REMOVE_RIGHTS = "No permission to remove players.",
    ALREADY_NOT_IN_GROUP = "%s is no longer in the group.",
    RIGHTS_LOST = "Lost permissions during the operation.",
    REMOVE_FAILED = "Failed to remove %s. Error: %s",
    STILL_IN_GROUP = "%s is still in the group after the attempt.",
    REMOVED_FROM_GROUP = "%s removed from the group.",
    NO_QUEUE_RIGHTS = "No permission to process the queue.",
    COMBAT_KICK_AFTER = "You are in combat — kick will run after combat.",
    NO_REMOVE_PERMISSION = "No permission to remove.",
    REMOVE_ERROR = "Error while removing %s: %s",
    STILL_IN_GROUP_SHORT = "%s is still in the group.",
    REMOVED_SHORT = "%s removed.",
    RAID_ASSIST_GRANTED = "Raid assistant granted to: %s",
    STARTUP_QUIET = "Startup quiet mode",
    PUG_WINDOW_TITLE = "GroupGuard LFG — Raid PUGs",
    PUG_WINDOW_NOTE = "PUGs are raid members who are not in your guild and not direct character/Battle.net friends. Friends-of-friends cannot be verified by the public WoW addon API.",
    PUG_COUNT_FMT = "PUGs: %d / %d",
    PUG_RAID_ONLY = "Join a raid to scan PUG members.",
    PUG_EMPTY = "No PUGs found. Raid members are guild members or direct friends.",
    PUG_COL_NAME = "Name",
    PUG_COL_CLASS = "Class",
    PUG_COL_ROLE = "Role",
    PUG_COL_GUILD = "Guild",
    PUG_COL_GROUP = "Grp",
    PUG_REFRESH = "Refresh",
    PUG_PRINT = "Print",
    PUG_KICK = "Kick",
    PUG_KICK_TOOLTIP = "Remove this PUG from the raid",
    PUG_KICKING_FMT = "Removing %s from the raid...",
    REMOVING_FROM_GROUP = "Removing marked players from group...",
    LEAVING_GROUP = "Leaving the current group...",
    REMOVE_QUEUE_COMBAT = "Remove queued until combat ends.",
    GROUP_REMOVE_SUMMARY = "Group removal: %d removed, %d failed, %d skipped. If failed > 0, check raid permissions / combat / protected UI.",
    GROUP_REMOVE_DONE = "Marked players removed.",
    GROUP_REMOVE_FAILED = "Some players could not be removed.",
    LFG_DECLINE_SUMMARY = "LFG decline: %d declined, %d failed.",
    LFG_DECLINE_DONE = "LFG applications declined.",
    LFG_DECLINE_PARTIAL = "Some LFG applications could not be declined.",
    LFG_INSIGHTS_TITLE = "GroupGuard LFG insights",
    LFG_INSIGHTS_CREATED = "Created: %s ago",
    LFG_INSIGHTS_COMP = "Composition: T %d / H %d / DPS %d",
    LFG_INSIGHTS_MEMBERS = "Members: %d",
    LFG_INSIGHTS_SOCIAL = "Social: BNet %d / Friends %d / Guild %d",
    LFG_INSIGHTS_CLASSES = "Classes",
    LFG_INSIGHTS_SHIFT = "Hold Shift for class breakdown",
    LFG_STATS_FMT = "Visible LFG rows: %d, marked: %d, friends: %d, guild: %d",
    LFG_STATS_NO_RESULTS = "No visible LFG search rows found.",
    ROLE_TANK = "tank",
    ROLE_HEALER = "healer",
    ROLE_DAMAGER = "DPS",
    LFG_ROLE_FIT_OK = "Your %s role fits: %d slot(s) open",
    LFG_ROLE_FIT_FULL = "Your %s role looks full",
    LFG_ADVISOR_STATS_FMT = "Visible rows: %d, role-fit: %d, role-full: %d",
    REALM_INSIGHTS_TITLE = "Realm hint",
    REALM_INSIGHTS_LEADER = "Leader realm: %s — %s",
    REALM_INSIGHTS_NOTE = "Realm locale is a technical realm-list hint, not a player nationality check.",
    APPLICANT_SUMMARY_TITLE = "Applicant summary",
    APPLICANT_SUMMARY_STATUS = "Status: %s",
    APPLICANT_SUMMARY_COMP = "Composition: T %d / H %d / DPS %d",
    APPLICANT_SUMMARY_MEMBERS = "Members loaded: %d / %d",
    APPLICANT_SUMMARY_ILVL = "Item level: %.0f best / %.0f avg",
    APPLICANT_SUMMARY_PVP_ILVL = "Best PvP item level: %.0f",
    APPLICANT_SUMMARY_SCORE = "Best M+ score: %.0f",
    APPLICANT_SUMMARY_LEVEL = "Level: %d",
    APPLICANT_SUMMARY_LEVEL_RANGE = "Level range: %d–%d",
    APPLICANT_SUMMARY_LEAVER = "Leaver warning: %d member(s)",
    APPLICANT_SUMMARY_RELATIONSHIPS = "Relationship: %s",
    APPLICANT_SUMMARY_COMMENT = "Comment: %s",
    APPLICANT_SUMMARY_MEMBERS_TITLE = "Members",
    APPLICANT_SUMMARY_SPECS = "Spec IDs",
    APPLICANT_SUMMARY_SHIFT = "Hold Shift for spec IDs",
    APPLICANT_CHIP_ROLES = "%dp T%d H%d D%d",
    APPLICANT_CHIP_ILVL = "ilvl %.0f/%.0f avg",
    APPLICANT_CHIP_PVP_ILVL = "PvP %.0f",
    APPLICANT_CHIP_SCORE = "M+ %.0f",
    APPLICANT_CHIP_LEAVER = "⚠ %d",
    APPLICANT_CARD_MEMBERS = "%d/%d members",
    APPLICANT_CARD_ROLES = "T%d H%d D%d",
    APPLICANT_CARD_ILVL = "ilvl %.0f/%.0f avg",
    APPLICANT_CARD_PVP = "PvP %.0f",
    APPLICANT_CARD_SCORE = "M+ %.0f",
    APPLICANT_CARD_BEST_RUN = "key %s%d",
    APPLICANT_CARD_BEST_RUN_TIMED = "timed key %s%d",
    APPLICANT_CARD_LEVEL = "lvl %d",
    APPLICANT_CARD_LEVEL_RANGE = "lvl %d–%d",
    APPLICANT_CARD_STATUS = "%s",
    APPLICANT_CARD_LEAVER = "leaver ⚠ %d",
    APPLICANT_CARD_COMMENT = "note: %s",
    APPLICANT_CARD_NO_MEMBER_DATA = "member data not loaded yet",
    APPLICANT_SUMMARY_PENDING_STATUS = "Pending: %s",
    APPLICANT_SUMMARY_BEST_RUN = "Best listing run: +%d",
    APPLICANT_MEMBER_BEST_RUN = "best run +%d",
    APPLICANT_DUMP_HEADER = "Applicant API dump: %d application(s)",
    APPLICANT_DUMP_APP = "appID %s | status=%s pending=%s members=%s comment=%s",
    APPLICANT_DUMP_APP_MISSING = "appID %s | no applicant info returned",
    APPLICANT_DUMP_MEMBER = "  member %s | name=%s role=%s specID=%s ilvl=%s pvp=%s score=%s lvl=%s leaver=%s",
    APPLICANT_DUMP_MEMBER_MISSING = "  member %s | no member info returned",
    DUMP_PROTECTED = "<protected>",
    DUMP_TABLE = "<table>",
    DUMP_TRUE = "true",
    DUMP_FALSE = "false",
    DUMP_NIL = "nil",
    APPLICATION_STATUS_APPLIED = "applied",
    APPLICATION_STATUS_INVITED = "invited",
    APPLICATION_STATUS_INVITEACCEPTED = "invite accepted",
    APPLICATION_STATUS_INVITEDECLINED = "invite declined",
    APPLICATION_STATUS_CANCELLED = "cancelled",
    APPLICATION_STATUS_DECLINED = "declined",
    APPLICATION_STATUS_DECLINED_FULL = "declined: group full",
    APPLICATION_STATUS_TIMEDOUT = "timed out",
    APPLICANT_MEMBER_LEVEL = "lvl %d",
    APPLICANT_MEMBER_ILVL = "ilvl %.0f",
    APPLICANT_MEMBER_PVP_ILVL = "PvP %.0f",
    APPLICANT_MEMBER_SCORE = "M+ %.0f",
    APPLICANT_MEMBER_HONOR = "honor %d",
    APPLICANT_MEMBER_RACE = "raceID %d",
    APPLICANT_MEMBER_RELATION = "relation %s",
    APPLICANT_MEMBER_FACTION = "%s",
    APPLICANT_MEMBER_LEAVER = "leaver warning",
    ROLE_NONE = "no role",
    APPLICANT_STATS_FMT = "Visible applications: %d, members: %d, T %d / H %d / DPS %d, leavers: %d, best ilvl: %.0f, best M+: %.0f",
    APPLICANT_STATS_NO_ROWS = "No visible applicant rows found.",
    CMD_USAGE_LANG = "Usage: /gglang auto | en | uk",
    CMD_LANGUAGE_SET = "Language set to: %s. Reloading UI...",
    CMD_NO_MARKED_REMOVE = "No marked players found for removal.",
    CMD_SCAN_COMPLETE = "Scan complete. Marked group players: %d",
    CMD_STATE_TITLE = "== GroupGuard LFG /ggstate ==",
    CMD_DEBUG_TITLE = "== GroupGuard LFG LFG Debug ==",
    CMD_YES = "yes",
    CMD_NO = "no",
    CMD_LOADED = "loaded",
    CMD_NOT_LOADED = "not loaded",
    CMD_NIL = "nil",
    CMD_VERSION = "Version: %s - %s",
    CMD_IS_IN_INSTANCE = "IsInInstance: %s %s",
    CMD_GET_INSTANCE_INFO = "GetInstanceInfo: %s %s",
    CMD_DB_RESTRICTED = "DB: disable_in_bg: %s disable_in_arena: %s",
    CMD_DB_BEHAVIOR = "DB: show_in_party: %s show_in_raid: %s auto_leave: %s lfg_auto_decline: %s",
    CMD_SOCIAL_STATE = "Social: ignore_friends: %s ignore_guild: %s mark_friends: %s mark_guild: %s",
    CMD_RAID_ASSIST_STATE = "RaidAssist: enabled: %s guild_officers: %s selected_ranks: %s",
    CMD_GROUP_OFFENDERS = "Group offenders: %d canRemove: %s",
    CMD_LOCKOUT_ACTIVE = "Lockout active: %s",
    CMD_RESTRICTED_NOW = "IsInRestrictedInstance: %s",
    CMD_DISABLED_NOW = "IsDisabledNow: %s",
    CMD_LFG_FRAME_STATE = "%s: %s",
    CMD_BUTTON_COUNT = "%s.buttons: %s",
    CMD_APPLICANTS_COUNT = "C_LFGList.GetApplicants(): %d",
    CMD_FIRST_APPLICANT = "First applicantID: %s numMembers: %s",
    PUG_PRINT_ROW = "%d. %s • %s • %s • %s",
  },
  ukUA = {
    UI_LANG_AUTO = "Мова клієнта гри",
    UI_LANG_EN = "Англійська",
    UI_LANG_UK = "Українська",
    MARKED = "ПОЗНАЧЕНО",
    AUTO_DECLINED = "АВТО-ВІДХИЛЕНО",
    TEST = "ТЕСТ",
    DEFAULT_DETAIL = "Перевір правила або склад групи.",
    LFG_AUTO_TITLE = "Авто-відхилено: %d",
    LFG_MARKED_RULES = "Позначено правилами LFG",
    LFG_AUTO_DETAIL = "Авто-відхилення увімкнено. Ручний fallback лишається доступним, якщо щось залишиться.",
    TEST_ALERT_TITLE = "Тест сповіщення",
    TEST_ALERT_DETAIL = "Компактна панель, кнопка закриття та fade-out.",
    CONFIRM_LEAVE = "Виявлено збіг за правилами. Вийти з групи?",
    CONFIRM_LEAVE_PARTY = "Виявлено збіг за правилами. Вийти з групи?",
    CONFIRM_LEAVE_RAID = "Виявлено збіг за правилами. Вийти з рейду?",
    NONE_SELECTED = "Не вибрано",
    DETECTED_MATCH = "Виявлено збіг",
    REASON_LANGUAGE = "Мовна фраза: %s",
    REASON_SCRIPT = "Скрипт: %s",
    REASON_RULE = "Правило: %s",
    LABEL_COMMENT = "Коментар",
    LABEL_NAME = "Ім'я",
    LABEL_MEMBER = "Учасник",
    LABEL_TITLE = "Назва",
    LABEL_LEADER = "Лідер",
    LABEL_VOICE = "Голосовий чат",
    LABEL_FRIEND = "друг",
    LABEL_GUILD = "гільдія",
    LABEL_MARKED = "позначено",
    TOOLTIP_FRIEND_GROUP = "GroupGuard LFG — друг у складі",
    TOOLTIP_GUILD_GROUP = "GroupGuard LFG — гільдія у складі",
    TOOLTIP_FRIEND_APP = "GroupGuard LFG — друг у заявці",
    TOOLTIP_GUILD_APP = "GroupGuard LFG — гільдія у заявці",
    TOOLTIP_MARKED = "Позначено GroupGuard",
    LFG_DECLINE_BUTTON = "Відхилити LFG-заявки",
    LFG_DECLINE_BUTTON_FMT = "Відхилити LFG-заявки (%d)",
    LFG_DECLINED_PRINT = "Відхилено LFG-заявки: %d",
    LFG_DECLINE_FAILED_PRINT = "Не вдалося відхилити LFG-заявки: %d",
    KICK_BUTTON = "Прибрати з групи",
    KICK_BUTTON_FMT = "Прибрати з групи (%d)",
    LEAVE_GROUP_BUTTON = "Покинути групу",
    LEAVE_PARTY_BUTTON = "Покинути групу",
    LEAVE_RAID_BUTTON = "Покинути рейд",
    IN_COMBAT_KICK_QUEUE = "Ви в бою — кик відкладено.",
    NO_REMOVE_RIGHTS = "Немає прав для видалення гравців.",
    ALREADY_NOT_IN_GROUP = "%s вже не в групі.",
    RIGHTS_LOST = "Втрачено права під час операції.",
    REMOVE_FAILED = "Не вдалося видалити %s. Помилка: %s",
    STILL_IN_GROUP = "%s все ще в групі після спроби.",
    REMOVED_FROM_GROUP = "%s видалено з групи.",
    NO_QUEUE_RIGHTS = "Немає прав для виконання черги.",
    COMBAT_KICK_AFTER = "Ви в бою — кик буде після бою.",
    NO_REMOVE_PERMISSION = "Немає прав для видалення.",
    REMOVE_ERROR = "Помилка при видаленні %s: %s",
    STILL_IN_GROUP_SHORT = "%s все ще в групі.",
    REMOVED_SHORT = "%s видалено.",
    RAID_ASSIST_GRANTED = "Помічник рейду видано: %s",
    STARTUP_QUIET = "Тихий запуск",
    PUG_WINDOW_TITLE = "GroupGuard LFG — пуги в рейді",
    PUG_WINDOW_NOTE = "Пуги — це учасники рейду, які не є членами твоєї гільдії та не є прямими друзями персонажа або Battle.net. Друзів друзів публічний WoW addon API надійно не віддає.",
    PUG_COUNT_FMT = "Пуги: %d / %d",
    PUG_RAID_ONLY = "Зайди в рейд, щоб перевірити пугів.",
    PUG_EMPTY = "Пугів не знайдено. Учасники рейду є членами гільдії або прямими друзями.",
    PUG_COL_NAME = "Ім'я",
    PUG_COL_CLASS = "Клас",
    PUG_COL_ROLE = "Роль",
    PUG_COL_GUILD = "Гільдія",
    PUG_COL_GROUP = "Гр",
    PUG_REFRESH = "Оновити",
    PUG_PRINT = "В чат",
    PUG_KICK = "Кик",
    PUG_KICK_TOOLTIP = "Прибрати цього пуга з рейду",
    PUG_KICKING_FMT = "Прибираю %s з рейду...",
    REMOVING_FROM_GROUP = "Прибираю позначених гравців із групи...",
    LEAVING_GROUP = "Покидаю поточну групу...",
    REMOVE_QUEUE_COMBAT = "Видалення відкладено до кінця бою.",
    GROUP_REMOVE_SUMMARY = "Видалення з групи: %d видалено, %d помилок, %d пропущено. Якщо є помилки — перевір права рейду / бій / protected UI.",
    GROUP_REMOVE_DONE = "Позначених гравців прибрано.",
    GROUP_REMOVE_FAILED = "Частину гравців не вдалося прибрати.",
    LFG_DECLINE_SUMMARY = "LFG-відхилення: %d відхилено, %d помилок.",
    LFG_DECLINE_DONE = "LFG-заявки відхилено.",
    LFG_DECLINE_PARTIAL = "Частину LFG-заявок не вдалося відхилити.",
    LFG_INSIGHTS_TITLE = "GroupGuard LFG інсайти",
    LFG_INSIGHTS_CREATED = "Створено: %s тому",
    LFG_INSIGHTS_COMP = "Склад: T %d / H %d / DPS %d",
    LFG_INSIGHTS_MEMBERS = "Учасників: %d",
    LFG_INSIGHTS_SOCIAL = "Соціальне: BNet %d / друзі %d / гільдія %d",
    LFG_INSIGHTS_CLASSES = "Класи",
    LFG_INSIGHTS_SHIFT = "Утримуй Shift для розбивки класів",
    LFG_STATS_FMT = "Видимі LFG-рядки: %d, позначено: %d, друзі: %d, гільдія: %d",
    LFG_STATS_NO_RESULTS = "Видимих LFG-рядків пошуку не знайдено.",
    ROLE_TANK = "танк",
    ROLE_HEALER = "хіл",
    ROLE_DAMAGER = "ДД",
    LFG_ROLE_FIT_OK = "Твоя роль %s підходить: відкрито слотів %d",
    LFG_ROLE_FIT_FULL = "Твоя роль %s схожа на заповнену",
    LFG_ADVISOR_STATS_FMT = "Видимі рядки: %d, роль підходить: %d, роль заповнена: %d",
    REALM_INSIGHTS_TITLE = "Підказка реалму",
    REALM_INSIGHTS_LEADER = "Реалм лідера: %s — %s",
    REALM_INSIGHTS_NOTE = "Локаль реалму — технічна підказка за списком реалмів, не перевірка національності гравця.",
    APPLICANT_SUMMARY_TITLE = "Підсумок заявки",
    APPLICANT_SUMMARY_STATUS = "Статус: %s",
    APPLICANT_SUMMARY_COMP = "Склад: T %d / H %d / DPS %d",
    APPLICANT_SUMMARY_MEMBERS = "Учасників завантажено: %d / %d",
    APPLICANT_SUMMARY_ILVL = "Рівень предметів: %.0f найкращий / %.0f середній",
    APPLICANT_SUMMARY_PVP_ILVL = "Найкращий PvP ilvl: %.0f",
    APPLICANT_SUMMARY_SCORE = "Найкращий M+ score: %.0f",
    APPLICANT_SUMMARY_LEVEL = "Рівень: %d",
    APPLICANT_SUMMARY_LEVEL_RANGE = "Діапазон рівнів: %d–%d",
    APPLICANT_SUMMARY_LEAVER = "Попередження leaver: %d учасн.",
    APPLICANT_SUMMARY_RELATIONSHIPS = "Зв'язок: %s",
    APPLICANT_SUMMARY_COMMENT = "Коментар: %s",
    APPLICANT_SUMMARY_MEMBERS_TITLE = "Учасники",
    APPLICANT_SUMMARY_SPECS = "Spec ID",
    APPLICANT_SUMMARY_SHIFT = "Утримуй Shift для Spec ID",
    APPLICANT_CHIP_ROLES = "%dуч T%d H%d D%d",
    APPLICANT_CHIP_ILVL = "ilvl %.0f/%.0f сер.",
    APPLICANT_CHIP_PVP_ILVL = "PvP %.0f",
    APPLICANT_CHIP_SCORE = "M+ %.0f",
    APPLICANT_CHIP_LEAVER = "⚠ %d",
    APPLICANT_CARD_MEMBERS = "%d/%d учасн.",
    APPLICANT_CARD_ROLES = "T%d H%d D%d",
    APPLICANT_CARD_ILVL = "ilvl %.0f/%.0f сер.",
    APPLICANT_CARD_PVP = "PvP %.0f",
    APPLICANT_CARD_SCORE = "M+ %.0f",
    APPLICANT_CARD_BEST_RUN = "ключ %s%d",
    APPLICANT_CARD_BEST_RUN_TIMED = "закритий ключ %s%d",
    APPLICANT_CARD_LEVEL = "рів. %d",
    APPLICANT_CARD_LEVEL_RANGE = "рів. %d–%d",
    APPLICANT_CARD_STATUS = "%s",
    APPLICANT_CARD_LEAVER = "leaver ⚠ %d",
    APPLICANT_CARD_COMMENT = "комент: %s",
    APPLICANT_CARD_NO_MEMBER_DATA = "дані учасників ще не завантажені",
    APPLICANT_SUMMARY_PENDING_STATUS = "Очікує: %s",
    APPLICANT_SUMMARY_BEST_RUN = "Найкращий ключ під оголошення: +%d",
    APPLICANT_MEMBER_BEST_RUN = "найкращий ключ +%d",
    APPLICANT_DUMP_HEADER = "Дамп API заявок: %d заявк.",
    APPLICANT_DUMP_APP = "appID %s | статус=%s pending=%s учасн=%s комент=%s",
    APPLICANT_DUMP_APP_MISSING = "appID %s | API не повернув applicant info",
    APPLICANT_DUMP_MEMBER = "  учасник %s | ім'я=%s роль=%s specID=%s ilvl=%s pvp=%s score=%s рів=%s leaver=%s",
    APPLICANT_DUMP_MEMBER_MISSING = "  учасник %s | API не повернув member info",
    DUMP_PROTECTED = "<захищено>",
    DUMP_TABLE = "<таблиця>",
    DUMP_TRUE = "так",
    DUMP_FALSE = "ні",
    DUMP_NIL = "nil",
    APPLICATION_STATUS_APPLIED = "подано",
    APPLICATION_STATUS_INVITED = "запрошено",
    APPLICATION_STATUS_INVITEACCEPTED = "запрошення прийнято",
    APPLICATION_STATUS_INVITEDECLINED = "запрошення відхилено",
    APPLICATION_STATUS_CANCELLED = "скасовано",
    APPLICATION_STATUS_DECLINED = "відхилено",
    APPLICATION_STATUS_DECLINED_FULL = "відхилено: група повна",
    APPLICATION_STATUS_TIMEDOUT = "час вийшов",
    APPLICANT_MEMBER_LEVEL = "рів. %d",
    APPLICANT_MEMBER_ILVL = "ilvl %.0f",
    APPLICANT_MEMBER_PVP_ILVL = "PvP %.0f",
    APPLICANT_MEMBER_SCORE = "M+ %.0f",
    APPLICANT_MEMBER_HONOR = "honor %d",
    APPLICANT_MEMBER_RACE = "raceID %d",
    APPLICANT_MEMBER_RELATION = "зв'язок %s",
    APPLICANT_MEMBER_FACTION = "%s",
    APPLICANT_MEMBER_LEAVER = "попередження leaver",
    ROLE_NONE = "без ролі",
    APPLICANT_STATS_FMT = "Видимі заявки: %d, учасників: %d, T %d / H %d / DPS %d, leavers: %d, найкращий ilvl: %.0f, найкращий M+: %.0f",
    APPLICANT_STATS_NO_ROWS = "Видимих рядків заявок не знайдено.",
    CMD_USAGE_LANG = "Використання: /gglang auto | en | uk",
    CMD_LANGUAGE_SET = "Мову змінено на: %s. Перезавантажую UI...",
    CMD_NO_MARKED_REMOVE = "Позначених гравців для видалення не знайдено.",
    CMD_SCAN_COMPLETE = "Сканування завершено. Позначено гравців у групі: %d",
    CMD_STATE_TITLE = "== GroupGuard LFG /ggstate ==",
    CMD_DEBUG_TITLE = "== GroupGuard LFG LFG Debug ==",
    CMD_YES = "так",
    CMD_NO = "ні",
    CMD_LOADED = "завантажено",
    CMD_NOT_LOADED = "не завантажено",
    CMD_NIL = "nil",
    CMD_VERSION = "Версія: %s - %s",
    CMD_IS_IN_INSTANCE = "IsInInstance: %s %s",
    CMD_GET_INSTANCE_INFO = "GetInstanceInfo: %s %s",
    CMD_DB_RESTRICTED = "DB: disable_in_bg: %s disable_in_arena: %s",
    CMD_DB_BEHAVIOR = "DB: show_in_party: %s show_in_raid: %s auto_leave: %s lfg_auto_decline: %s",
    CMD_SOCIAL_STATE = "Social: ignore_friends: %s ignore_guild: %s mark_friends: %s mark_guild: %s",
    CMD_RAID_ASSIST_STATE = "RaidAssist: enabled: %s guild_officers: %s selected_ranks: %s",
    CMD_GROUP_OFFENDERS = "Позначені в групі: %d canRemove: %s",
    CMD_LOCKOUT_ACTIVE = "Lockout активний: %s",
    CMD_RESTRICTED_NOW = "IsInRestrictedInstance: %s",
    CMD_DISABLED_NOW = "IsDisabledNow: %s",
    CMD_LFG_FRAME_STATE = "%s: %s",
    CMD_BUTTON_COUNT = "%s.buttons: %s",
    CMD_APPLICANTS_COUNT = "C_LFGList.GetApplicants(): %d",
    CMD_FIRST_APPLICANT = "Перший applicantID: %s numMembers: %s",
    PUG_PRINT_ROW = "%d. %s • %s • %s • %s",
  },
}

function addon:GetUILanguage()
  local lang = self.db and self.db.ui_language or "auto"
  if lang == "enUS" or lang == "ukUA" then return lang end
  local client = (GetLocale and GetLocale()) or "enUS"
  if client == "ukUA" or client == "uk" then return "ukUA" end
  return "enUS"
end

function addon:Tr(key, ...)
  local lang = self:GetUILanguage()
  local tableForLang = self.L10N and (self.L10N[lang] or self.L10N.enUS) or nil
  local text = tableForLang and tableForLang[key]
  if text == nil and self.L10N and self.L10N.enUS then text = self.L10N.enUS[key] end
  if text == nil then text = tostring(key) end
  if select("#", ...) > 0 then
    local ok, formatted = pcall(string.format, text, ...)
    if ok then return formatted end
  end
  return text
end

function addon:DefaultLFGButtonText()
  return self:Tr("LFG_DECLINE_BUTTON_FMT")
end

function addon:SetUILanguage(lang)
  if not self.db then self:EnsureDB() end
  if lang ~= "auto" and lang ~= "enUS" and lang ~= "ukUA" then lang = "auto" end
  local oldDefaultEN = self.L10N and self.L10N.enUS and self.L10N.enUS.LFG_DECLINE_BUTTON_FMT
  local oldDefaultUK = self.L10N and self.L10N.ukUA and self.L10N.ukUA.LFG_DECLINE_BUTTON_FMT
  local oldValue = self.db.lfg_button_text
  self.db.ui_language = lang
  if oldValue == nil or oldValue == "" or oldValue == oldDefaultEN or oldValue == oldDefaultUK or oldValue == "Відхилити позначені (%d)" then
    self.db.lfg_button_text = self:DefaultLFGButtonText()
  end
end

local function CopyDefaults(src, dst)
  if type(dst) ~= "table" then dst = {} end
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = CopyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

function addon:EnsureDB()
  _G.GroupGuardLFGDB = CopyDefaults(self.DEFAULTS, _G.GroupGuardLFGDB)
  self.db = _G.GroupGuardLFGDB
  if self.db.ui_language == nil then self.db.ui_language = "auto" end
  if self.db.startup_silent_seconds == nil then self.db.startup_silent_seconds = 3.0 end
  if self.db.suppress_action_spam == nil then self.db.suppress_action_spam = true end
  if type(self.db.sound_file) == "string" and (
      self.db.sound_file:find("pig_burp%.ogg") or self.db.sound_file:find("burp%.ogg")) then
    self.db.sound_file = WARN_SOUND
  end
  self.db.sound_presets = { WARN_SOUND }
  if self.db.banner_hold_time == nil or self.db.banner_hold_time == 5 then self.db.banner_hold_time = 10 end
  if self.db.alert_sound_cooldown == nil or self.db.alert_sound_cooldown == 1.25 then self.db.alert_sound_cooldown = 10 end
  if self.db.alert_flash_cooldown == nil or self.db.alert_flash_cooldown == 0.75 then self.db.alert_flash_cooldown = 10 end
  if self.db.frame_markers_enabled == nil then self.db.frame_markers_enabled = true end
  if self.db.frame_marker_size == nil then self.db.frame_marker_size = 1 end
  if self.db.social_ignore_friends == nil then self.db.social_ignore_friends = true end
  if self.db.social_ignore_guild == nil then self.db.social_ignore_guild = true end
  if self.db.social_mark_friends == nil then self.db.social_mark_friends = true end
  if self.db.social_mark_guild == nil then self.db.social_mark_guild = true end
  if self.db.social_mark_lfg == nil then self.db.social_mark_lfg = true end
  if self.db.raid_assist_enabled == nil then self.db.raid_assist_enabled = true end
  if self.db.raid_assist_guild_officers == nil then self.db.raid_assist_guild_officers = true end
  if self.db.raid_assist_officer_rank_max == nil then self.db.raid_assist_officer_rank_max = 2 end
  if self.db.raid_assist_officer_keywords == nil then self.db.raid_assist_officer_keywords = "Офіцер, офіцер, Officer, officer, Шинкар, шинкар, Raid Leader, raid leader, raidlead, raid lead, RL, rl" end
  if self.db.raid_assist_selected_ranks == nil then self.db.raid_assist_selected_ranks = "" end
  if self.db.raid_assist_manual_names == nil then self.db.raid_assist_manual_names = "" end
  if self.db.raid_assist_notify == nil then self.db.raid_assist_notify = true end
  if self.db.scan_debounce == nil or self.db.scan_debounce == 0.18 then self.db.scan_debounce = 0.03 end
  if self.db.lfg_debounce == nil or self.db.lfg_debounce == 0.08 then self.db.lfg_debounce = 0.02 end
  if self.db.lfg_tooltip_details == nil then self.db.lfg_tooltip_details = true end
  if self.db.lfg_role_fit_hints == nil then self.db.lfg_role_fit_hints = true end
  if self.db.lfg_mute_applicant_ping == nil then self.db.lfg_mute_applicant_ping = true end
  if self.db.realm_insights == nil then self.db.realm_insights = true end
  if self.db.realm_badges == nil then self.db.realm_badges = true end
  if self.db.realm_same_locale_only == nil then self.db.realm_same_locale_only = true end
  if self.db.applicant_summary_chips == nil then self.db.applicant_summary_chips = true end
  if self.db.applicant_cards_enabled == nil then self.db.applicant_cards_enabled = self.db.applicant_summary_chips ~= false end
  self.db.applicant_summary_chips = self.db.applicant_cards_enabled ~= false
  if self.db.applicant_summary_tooltips == nil then self.db.applicant_summary_tooltips = true end
  if self.db.applicant_auto_refresh_done == nil then self.db.applicant_auto_refresh_done = true end
  if self.db.lfg_button_text == "Decline LFG applications (%d)" or self.db.lfg_button_text == "Відхилити позначені (%d)" or self.db.lfg_button_text == "Відхилити LFG-заявки (%d)" then self.db.lfg_button_text = self:DefaultLFGButtonText() end
  self:RebuildCaches()
end

