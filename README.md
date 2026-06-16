# GroupGuard LFG

**GroupGuard LFG** is a World of Warcraft addon for managing LFG applications, party/raid group visibility, and local UI warnings based on user-defined rules.

The addon does not identify nationality, ethnicity, origin, religion, or any personal characteristic of players. All checks are based only on technical text signals such as character names, guild names, group titles, LFG comments, keywords, and optional UTF-8 script checks configured by the user.

---

## Features

* Scan party and raid members using configurable rules.
* Scan LFG applications and LFG search results.
* Add lightweight LFG tooltip insights: listing age, role composition, role-fit hints, social counters, realm-locale hints, and Shift class/spec breakdowns.
* Manually or automatically decline marked LFG applications.
* Show two-line applicant cards directly on applicant rows with member count, T/H/D composition, best/average ilvl, PvP ilvl, M+ score, level range, status, leaver warnings, names, specs and comments.
* Show compact realm badges and technical realm-locale hints for LFG search rows.
* Show a button to remove marked players from party/raid when you have permission.
* Centered visual marker on party/raid unit frames.
* Compact notification banner with action button.
* WARN sound and optional screen flash.
* Automatic Raid Assist assignment for selected guild ranks or manually listed characters.
* Raid PUG detector: lists raid members who are not guild members and not direct friends.
* Friend and guild-member handling for trusted/social LFG entries.
* Safe compatibility with Premade Groups Filter and Plumber-style UI patterns: passive hooks only, no Blizzard UI replacement, no PGF/Plumber interception.
* Optional duplicate applicant-ping mute while auto-decline is processing.
* Interface language selector:

  * Game client language
  * English
  * Ukrainian

---

## How it works

GroupGuard LFG compares available text data against your configured rules:

* character name;
* guild name;
* LFG group title;
* LFG description or comment;
* keyword rules;
* optional UTF-8 script signals.

The addon does not infer anything about a player’s nationality, ethnicity, origin, religion, or personal identity. If language or script detection is enabled, it is only a technical text signal and may produce false positives. The user is responsible for configuring fair and appropriate rules.

---

## Addon structure

```text
GroupGuardLFG/
  Core/
    Bootstrap.lua
    SafeAPI.lua
    Performance.lua
    Rules.lua
    Alerts.lua
    Social.lua
    GroupScan.lua

  Data/
    RealmLocaleData.lua

  Modules/
    EventBus.lua
    FrameMarkers.lua
    GroupActions.lua
    LFG.lua
    LFGEnhancements.lua
    RealmInsights.lua
    LFGAdvisor.lua
    ApplicantEnhancements.lua
    RaidAssist.lua
    PugDetector.lua

  UI/
    Notify.lua
    Settings.lua

  Media/
    warn.ogg
    warning_marker.tga

  GroupGuardLFG.toc
  README.md
```

---

## Installation

1. Delete the old addon folder completely:

```text
Interface/AddOns/GroupGuardLFG
```

2. Extract the new version so the path is:

```text
Interface/AddOns/GroupGuardLFG/GroupGuardLFG.toc
```

3. Restart the game or run:

```text
/reload
```

---

## Commands

```text
/groupguard
/gglfg
/gguard
/guardlfg
```

Open addon settings.

```text
/gglang auto
/gglang en
/gglang uk
```

Change interface language.

```text
/ggscan
```

Force a group, LFG, and frame-marker rescan.

```text
/ggremove
```

Try to remove currently marked players from party/raid.

```text
/ggpugs
/raidpugs
/groupguard pugs
```

Open the Raid PUG detector window. PUGs are raid members who are not in your guild and not direct character/Battle.net friends. Friends-of-friends cannot be verified reliably through the public WoW addon API.

```text
/ggstate
```

Show current addon state.

```text
/ggdebug
```

Show technical LFG debug information.

```text
/gglfgstats
```

Print a quick summary of visible LFG search rows: total, marked, friend, and guild entries.

```text
/ggapps
```

Print a summary of current Blizzard LFG applicants.

```text
/ggapps dump
```

Print what Blizzard's applicant API is currently returning: applicant IDs, status, comment, member count, member names, roles, specID, ilvl, PvP ilvl, M+ score, level and leaver state. Use this to distinguish a UI issue from missing API data.

---

## Settings

### General

* Enable or disable party scanning.
* Enable or disable raid scanning.
* Disable the addon in Battlegrounds.
* Disable the addon in Arenas.
* Enable the party/raid remove button.
* Enable confirmation before leaving a group.

### LFG applications

* Automatically decline marked LFG applications.
* Show a manual decline button for marked LFG applications.
* Configure auto-decline batch limit.
* Configure delay between auto-decline actions.
* Enable LFG highlighting.
* Show the match reason in tooltips.
* Show optional search tooltip details inspired by LFGInspect: created age, role composition, social counters, and Shift class breakdown.
* Show two-line applicant cards on the real `LFGListApplicationViewer_UpdateApplicantMember` rows, using the applicantID/memberIdx Blizzard passes to the UI.
* Use `/ggapps dump` to inspect the exact applicant data returned by the client.
* Mute duplicate applicant ping while auto-decline is running.

### Raid Assist

* Automatically grant Raid Assist.
* Select guild ranks that should receive assistant.
* Add manually listed character names.
* Enable or disable chat notifications when assistant is granted.

### Rules

* Keywords.
* Character names.
* Guild names.
* Optional language keyword detection.
* Optional UTF-8 script detection.

Script detection does not mean nationality or identity detection. It only checks which character ranges appear in text.

### Notifications

* Compact banner.
* WARN sound.
* Screen flash.
* Centered frame marker.
* Cooldowns for sound and screen flash.

### Compatibility

* Debounce settings.
* Premade Groups Filter compatibility.
* Silent startup after ReloadUI.
* Suppression of intermediate action spam.

---

## Party/Raid removal

Removal only works if you have the required group permissions.

The addon tries to resolve the target using:

* live unit token, such as `raid1`, `raid2`, or `party1`;
* full name, such as `Name-Realm`;
* short name fallback.

`UninviteUnit()` is triggered directly from the user action to reduce protected-action issues.

If removal fails, check:

* whether you are the raid leader or have enough permissions;
* whether you are in combat;
* whether the target is still in the group;
* whether Blizzard UI blocked the protected action.

---

## LFG decline

LFG applications are handled separately from party/raid removal.

* The LFG button only affects LFG applications.
* The banner button only affects party/raid members.
* Auto-decline can be disabled if you prefer manual review.

---

## Premade Groups Filter compatibility

GroupGuard LFG does not overwrite Premade Groups Filter behavior.

It uses only safe integration:

* `hooksecurefunc`;
* optional hooks;
* no hard dependency on PGF internals;
* no overwriting of PGF functions.

---

## SavedVariables

The addon uses only one SavedVariables database:

```text
GroupGuardLFGDB
```

Old databases from other addons are not used.

---

## Important note

GroupGuard LFG is a local UI organization tool for LFG and group management. It is not intended for discrimination, harassment, or judging people based on personal characteristics.

Recommended use cases include filtering spam, boost advertising, carry offers, sell messages, GDKP advertisements, repeated unwanted text patterns, or other technical signals that interfere with your gameplay.


## 4.2.0 user-experience enhancements

This release integrates safe ideas from GroupfinderFlags, PGFinder and GroupFinderRio without replacing Blizzard, PGF or sorter addon UI.

* Realm hints are based on realm-list metadata and are shown only as technical UI hints. They are not nationality or personal-origin checks.
* Role-fit hints show whether your current selected role appears to have open slots in a visible group.
* Applicant cards summarize visible applications directly in the LFG application list.
* `/ggapps` prints visible applicant statistics.
* `/ggadvisor` prints role-fit statistics for visible LFG search results.

## 4.2.1 applicant data and recycled-row UI fixes

* Applicant row summaries read safe Blizzard-provided member fields available through `C_LFGList.GetApplicantMemberInfo`:
  role composition, loaded member count, level range, item level best/average, PvP item level, M+ score, spec, class, relationship and leaver warning.
* Applicant tooltips show a per-member breakdown instead of only the top-line role/ilvl/score summary.
* Recycled Blizzard LFG rows are cleared on `OnShow`, `OnHide`, `SetElementData` and scroll updates, preventing stale GroupGuard applicant cards, realm badges or highlights from appearing on the wrong applicant/search row.
* Missing UI labels for the new LFG/realm/applicant settings were localized.


---

## 4.2.2 notes

* Replaced the old tiny applicant chip with a visible two-line applicant card on the application/member row.
* Fixed applicant data reads for both table-return and positional-return `C_LFGList.GetApplicantInfo()` / `GetApplicantMemberInfo()` shapes.
* Added authoritative hooks to `LFGListApplicationViewer_UpdateApplicantMember(memberFrame, applicantID, memberIdx)` so cards bind to the real Blizzard applicant ID instead of guessing from recycled ScrollBox rows.
* Added `/ggapps dump` diagnostics for current applicant API data.
* Improved recycled-row protection: cards hide before ScrollBox refresh/update/full update, mouse wheel recycling, row OnShow/OnHide, and member-frame reuse.
* Kept compatibility passive: no Blizzard UI replacement, no PGF override, no Plumber interception.


---

## 4.2.3 audit notes

* Added `Core/SafeAPI.lua` as a single guarded layer for Blizzard LFG applicant/search API reads.
* Reworked applicant cards to bind to real applicant/member update hooks first, then fall back to visible row data only after validation.
* Added stronger recycled-row cleanup for applicant cards, realm badges and LFG highlights.
* Added `LFG_LIST_APPLICATION_STATUS_UPDATED` handling for applicant status refreshes.
* Replaced scattered raw LFG applicant reads with guarded helpers where possible.
* Tightened Secret Value guards: values that cannot be checked safely are treated as unreadable.
* Completed EN/UA localization parity for current UI text.
