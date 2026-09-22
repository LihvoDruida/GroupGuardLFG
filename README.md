# GroupGuard LFG

## 4.8.2

- Forever: stop forcing `Blizzard_GroupFinder_VanillaStyle` to load as an optional dependency.
- Forever: avoid triggering Blizzard's `LFGWhoListFrame` load-order edge case by no longer force-loading the secure VanillaStyle group finder from `OptionalDeps`.
- Forever: preserve ScrollBox position while custom class/role filters rebuild results.
- Avoid a redundant post-search result rebuild that could snap the browse list to the top.


GroupGuard LFG helps you keep LFG applications, party members and raid members easier to review. It highlights matches from your own rules, adds a small GG column to applicant lists, and gives raid leaders quick tools for cleanup and raid-assist management.

## What it does

- Marks LFG applications and group members that match your keyword, name or guild rules.
- Can auto-decline marked LFG applications when you have permission.
- Keeps a manual decline button available for cases that need review.
- Shows a compact **GG** column in applicant lists:
  - Mythic+ / dungeon listings: best matching key for the current dungeon, such as `+12`.
  - Raid listings: raid progress for the current raid and difficulty, such as `2/9`, when available from compatible data.
  - Leaver warning: `⚠` when the game reports it.
- Keeps the normal **Name / Role / iLvl / Rating** columns visible.
- Adds small tooltip warnings only when they add value, without replacing other addon tooltips.
- Detects raid PUGs: raid members outside your guild and direct friends.
- Adds a small **PUG List** button to the default raid manager panel for quick access.
- Can grant raid assistant to selected ranks, officers or named players.
- Supports English and Ukrainian UI text.
- Supports both modern **WoW 12.x** LFG and **WoW Forever 1.60.x** (`_Camelot.toc`).
- Adds a stock-style search filter panel: dungeon groups can be filtered by roles they still need; solo player listings can be filtered by class and role.

## Design rules

GroupGuard should feel like part of the default LFG window.

- No second applicant rows.
- No oversized cards.
- No custom applicant overlays.
- No row-height changes.
- No replacement of Raider.IO, Plumber, Premade Groups Filter or Blizzard tooltips.
- No replacement of the normal Rating column.

The GG column is an extra helper column only.

## Commands

```text
/gg
/gg settings
/gglfg
/groupguard
/gguard
/guardlfg
```
Open settings.

```text
/gg debug on
/gg debug off
/gg debug api
/gg debug lfg
/gg debug deps
/gg debug social
/gg perf
/gg queue
```
Debug, performance and deferred-kick queue helpers.

```text
/ggscan
```
Scan the current party or raid.

```text
/ggremove
```
Remove marked players when you have permission.

```text
/ggpugs
```
Open the raid PUG list.

```text
/ggapps
```
Show a short summary of current LFG applications.

```text
/ggadvisor
```
Show a quick role-fit summary for visible LFG search results.

```text
/gglang auto
/gglang en
/gglang uk
```
Change addon language.

## Recommended use

1. Set your rules in **Rules**.
2. Keep **LFG applications → GG column** enabled.
3. Keep **Compatibility → Improve Premade Groups Filter compatibility** enabled when PGF is installed.
4. Use `/ggapps` when you want to check whether applications are loaded.
5. Use the **PUG List** button in the default raid manager panel, or `/ggpugs`, to quickly see non-guild / non-friend members.

## Compatibility

GroupGuard is designed to run beside common LFG addons.

- Premade Groups Filter: GroupGuard does not take over PGF filters, sorting or search result logic.
- Raider.IO: GroupGuard does not replace Raider.IO tooltip content. Raid progress is used only when compatible profile data is available.
- Plumber: GroupGuard does not clear or rebuild Plumber tooltips.
- Blizzard UI: GroupGuard keeps applicant rows single-line and keeps the standard columns visible.

## Privacy and fairness

GroupGuard does not identify a player’s nationality, ethnicity, religion, origin or personal identity. Optional text checks are based only on visible text such as group titles, comments, character names, guild names and user-configured rules. Text and realm hints can be wrong, so rules should be reviewed carefully.


## Release notes — 4.8.1

- Fixed WoW Forever filters not applying when `LFGBrowseFrame` had already copied `LFGBrowseMixin` methods before GroupGuard installed its hook.
- Added a concrete `LFGBrowseFrame:UpdateResultList()` post-hook instead of relying only on the shared mixin table.
- Filter changes on Forever now re-read the same `C_LFGList.GetFilteredSearchResults()` set Blizzard uses, apply GroupGuard's local class/role rules, and rebuild only `UpdateResults()`; no new server search is issued.
- Moved the side filter panel under `UIParent` while keeping it anchored to the LFG window so mouse-wheel input over the panel no longer bubbles into the Forever browse `ScrollBox`.
- The filter panel now explicitly consumes mouse-wheel input and disables mouse click/motion propagation where the client exposes those APIs.
- `/gg debug lfg` now prints the active Forever hook state plus a small sample of result IDs, member counts, class/role data, remaining dungeon roles and each result's filter verdict.
- Added regression coverage for direct Forever result refresh/filtering without a working mixin hook.



## Release notes — 4.8.0

- Added first-class **WoW Forever 1.60.x** support through `GroupGuardLFG_Camelot.toc` (`Interface 16001`).
- Added runtime client/capability detection so Mainline and Forever use the correct Blizzard LFG frames and only available API paths.
- Added a Blizzard-style filter button next to Forever's refresh button and a standard-asset settings panel anchored to the right of the LFG window.
- Added separate filter blocks for **Dungeon groups — roles still needed** and **Players — class + role**. Multiple choices are OR within a block; class and role are AND for solo-player listings.
- Filters operate on Blizzard's already-received search results and do not issue protected searches or replace Blizzard sorting/UI.
- Updated search highlighting, GroupGuard tooltips, realm hints and search insight hooks for Forever's `Blizzard_GroupFinder_VanillaStyle` frames.
- Added safe snapshots for current `C_LFGList.GetSearchResultMemberCounts`, `GetSearchResultPlayerInfo`, `GetSearchResultInfo`, and modern activity fields such as `maxNumPlayers` / `useDungeonRoleExpectations`.
- Forever settings hide Mainline ApplicationViewer-only controls that have no usable UI there.
- Added regression tests for role-needs filtering, solo class+role matching and fail-open behavior when LFG data is temporarily unavailable.


## Release notes — 4.7.4

- **Release Spirit** now stays visible in raids and is disabled only for a configurable safety window instead of being kept disabled indefinitely.
- Default GroupGuard raid release lock: **15 seconds**.
- Added **General → Raid death safety → Disable Release Spirit in raids for (sec)**. Range: **0–120 sec**; `0` disables GroupGuard's extra delay.
- The timer starts when the raid death popup appears and is not restarted by roster/settings refreshes.
- After the configured delay, GroupGuard restores only button state that it disabled itself. Blizzard-owned release timers are never shortened.
- The reminder text is shown only while the GroupGuard lock is active.

## Release notes — 4.7.3

- Fixed shared `StaticPopup` button state leaking from the death dialog into **Accept / OK / confirmation** dialogs.
- Removed method-level `Enable` / `SetEnabled` hooks from Blizzard's shared popup button.
- `Release Spirit` is now re-checked only while the active popup is exactly `DEATH` and the player is in a raid.
- DeathGuard restores only button state that it changed itself, leaving Blizzard-owned disabled/timer states alone.
- Changed the custom raid reminder to English: **“Don't push the horses )))”**.
- `Recap` and all non-death StaticPopup dialogs remain untouched.

## Release notes — 4.7.2

- Limited the death-dialog guard to **raid groups only** (`IsInRaid()`).
- In raids, **Release Spirit** stays visible but is disabled and **“Don't push the horses )))”** is shown.
- In parties, Mythic+, solo/open-world play and other non-raid states, Blizzard's death dialog is left unchanged.
- The **Recap** button and Blizzard's automatic release behavior remain untouched.

## Release notes — 4.7.1

- Added a death-dialog safety guard that keeps Blizzard's **Release Spirit** button visible but disabled.
- Kept the stock **Recap** button and the rest of Blizzard's death dialog unchanged.
- Added the reminder line **“Don't push the horses )))”** above the stock death-dialog buttons.
- Uses guarded post-hooks instead of replacing `StaticPopupDialogs["DEATH"]`, reducing taint risk on Retail 12.1.
- Blizzard's own automatic release timeout is not modified.

## Release notes — 4.7.0

- Added Retail 12.1.5 PTR interface `120105` while keeping 12.1.0 (`120100`) compatibility.
- Hardened secret-value and secret-table handling before comparisons, casts, string conversion or boolean evaluation.
- Added `FrameScriptObject:CanBeAccessedInContext()` guards for Blizzard-owned LFG and ScrollBox objects.
- Sanitized LFG search/player/applicant data into addon-owned readable values before feature modules consume them.
- Removed unsafe duplicate ScrollBox fallback access paths and consolidated guarded observation.
- Updated applicant handling for current 12.1 API shapes/statuses, including `relationship`, `isLeaver` and `declined_delisted`.
- Isolated asynchronous/debounced callback failures so a single Blizzard/UI timing error does not break the addon event flow.
- Confirmed use of `C_LFGList.GetSearchResultPlayerInfo` rather than removed legacy member APIs.
- Added dedicated Midnight 12.1 regression tests for secret data, forbidden frames and LFG API normalization.

## Release notes — 4.2.41

- Reworked applicant list GG column as a measured stock-grid reflow instead of an overlay.
- Applicant headers now resolve to `Name | R | GG | iLvl | Rating` when Blizzard's ApplicationViewer grid is recognized.
- The Name column is compacted to make real space for GG, while Role is reduced to `R`.
- Row role icon, GG text, iLvl and optional Rating are aligned under the same measured headers.
- If Name/Role/iLvl headers cannot be found or measured, GG is hidden and the stock Blizzard UI is restored.
- Removed unsafe fallback positions that placed GG next to iLvl or near the row right edge.
- `/gg debug lfg` now prints GG layout reason, detected headers and column widths.

## Release notes — 4.2.19

- Reduced CPU spikes during LFG scrolling and applicant updates.
- Added short-lived guarded LFG API caches.
- Coalesced repeated refresh events into fewer UI passes.
- Reduced applicant GG column refresh retries.
- Kept stock applicant UI, Rating column, PGF, Raider.IO and Plumber compatibility.

## Release notes — 4.2.18

- Updated Retail TOC Interface to 120007 for WoW 12.0.7.
- Kept the addon behavior unchanged. This is a compatibility metadata update only.

## Release notes — 4.2.17

- Cleaned user-facing text in settings, README and applicant output.
- Simplified normal UI descriptions.
- Kept developer-style applicant details out of the regular workflow.
- Kept applicant rows stock-style with a separate GG column.
- Preserved normal iLvl and Rating columns.
- Kept tooltip behavior append-only and minimal.
- Updated version to 4.2.17.

## QA checklist

Use this before release:

- Settings open without missing labels in English and Ukrainian.
- Applicant list shows `Name | R | GG | iLvl | Rating` when Rating exists.
- Dungeon listing keeps Rating visible and shows `+key` in GG when data is available.
- Raid listing shows GG progress only when compatible raid progress data exists.
- No second applicant row appears.
- Applicant rows do not overlap while scrolling.
- Tooltip from Raider.IO or Plumber remains intact.
- `/ggapps` prints a short readable summary.
- Auto-decline still affects only marked applications.
- Raid PUG detector opens and refreshes without errors.

## Error / defect / failure terms

- **Error** — a human mistake in logic, design or implementation.
- **Defect** — a flaw in the product that does not meet requirements.
- **Failure** — visible incorrect behavior during use, caused by a defect.


- Raid manager PUG button resized and centered below the stock button block, above Leave Party.
## Release notes — 4.2.29

- Moved the PUG button below the full Leave Party / Leave Instance Group button block.
- Matched the PUG button size and shape to the stock bottom raid-manager buttons.
- Expanded the raid manager panel safely so the new button fits without overlapping Blizzard controls.

