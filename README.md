# GroupGuard LFG

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
- Detects raid PUGs: players who are not in your guild and not direct friends.
- Adds a small **PUGs** button to the default raid manager panel for quick access.
- Can grant raid assistant to selected ranks, officers or named players.
- Supports English and Ukrainian UI text.

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
```
Open settings.

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
Open the raid PUG detector.

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
5. Use the **PUGs** button in the default raid manager panel, or `/ggpugs`, to quickly see non-guild / non-friend members.

## Compatibility

GroupGuard is designed to run beside common LFG addons.

- Premade Groups Filter: GroupGuard does not take over PGF filters, sorting or search result logic.
- Raider.IO: GroupGuard does not replace Raider.IO tooltip content. Raid progress is used only when compatible profile data is available.
- Plumber: GroupGuard does not clear or rebuild Plumber tooltips.
- Blizzard UI: GroupGuard keeps applicant rows single-line and keeps the standard columns visible.

## Privacy and fairness

GroupGuard does not identify a player’s nationality, ethnicity, religion, origin or personal identity. Optional text checks are based only on visible text such as group titles, comments, character names, guild names and user-configured rules. Text and realm hints can be wrong, so rules should be reviewed carefully.


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

