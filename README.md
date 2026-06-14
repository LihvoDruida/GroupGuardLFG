# GroupGuard LFG

**GroupGuard LFG** is a World of Warcraft addon for managing LFG applications, party/raid group visibility, and local UI warnings based on user-defined rules.

The addon does not identify nationality, ethnicity, origin, religion, or any personal characteristic of players. All checks are based only on technical text signals such as character names, guild names, group titles, LFG comments, keywords, and optional UTF-8 script checks configured by the user.

---

## Features

* Scan party and raid members using configurable rules.
* Scan LFG applications and LFG search results.
* Add lightweight LFG tooltip insights: listing age, role composition, social counters, and Shift class breakdown.
* Manually or automatically decline marked LFG applications.
* Show a button to remove marked players from party/raid when you have permission.
* Centered visual marker on party/raid unit frames.
* Compact notification banner with action button.
* WARN sound and optional screen flash.
* Automatic Raid Assist assignment for selected guild ranks or manually listed characters.
* Raid PUG detector: lists raid members who are not guild members and not direct friends.
* Friend and guild-member handling for trusted/social LFG entries.
* Safe compatibility with Premade Groups Filter.
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
    Performance.lua
    Rules.lua
    Alerts.lua
    Social.lua
    GroupScan.lua

  Modules/
    EventBus.lua
    FrameMarkers.lua
    GroupActions.lua
    LFG.lua
    RaidAssist.lua
    PugDetector.lua

  UI/
    Notify.lua
    Settings.lua

  Media/
    warn.ogg
    warning_marker.tga

  GroupGuardLFG.toc
  README_GroupGuardLFG.txt
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
