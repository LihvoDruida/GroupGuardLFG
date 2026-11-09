### 4.9.18 — Відступ списку від стандартних кнопок

Нижню межу власної області результатів піднято над нижньою панеллю LFG. У сучасному стилі список закінчується на 3 px вище штатного розділювача; до верхнього краю кнопок залишається 20 px. У класичному стилі до кнопок залишається 9 px. Смуга прокрутки та область обробки миші скорочуються разом зі списком, останній частково видимий рядок обрізається штатним ScrollBox.

Збережені оригінальні шаблони, висота рядків, шрифти, позиції та обробники стандартних кнопок. Незалежні фільтри груп і гравців не змінювалися. Перевірено синтаксис 32 робочих Lua-файлів та відступи за оригінальними XML обох стилів; наявні тестові набори не запускалися. Візуальна перевірка у запущеному WoW ще потрібна. Див. `VALIDATION-4.9.18.txt`.

### 4.9.17 — Відновлення видимого списку

Виправлено регресію 4.9.16: власний список мав фіксований рівень на шарі основного вікна й міг опинитися під його фоном після підняття панелі грою. Область результатів знову використовує окремий шар DIALOG; дані про секретний шар/рівень стандартного вікна для цього не читаються. Шаблони рядків і прокрутки залишаються оригінальними, стандартні кнопки — на своїх місцях. Фільтри груп і гравців незалежні.

Після показу виконується штатне розміщення ScrollBox. Помилки ініціалізації більше не стираються наступним кроком оновлення. Якщо дані непорожні, а ScrollBox не створив жодного фрейму, аддон повертає стандартний список і показує помилку замість удавано успішного порожнього результату. `/ggfilters` тепер розрізняє число збігів, створених і видимих фреймів.

Новий вузький прогін `tools/blank_list_probe.py` виконує також оригінальні ScrollBox.lua, ScrollBoxViewUtil.lua та AnchorUtil.lua. Він відтворює збій старої версії на піднятому вікні, перевіряє 82/100, віртуалізацію, прокрутку, повторне відкриття й відновлення після помилки. Старі набори тестів не запускалися. C-геометрія, renderer і taint залишаються поза цією перевіркою; у запущеному WoW зміни ще не перевірені. Див. `FIX-4.9.17-UA.md` та `VALIDATION-4.9.17.txt`.

### 4.9.16 — Штатне оформлення списку та незалежні фільтри

Власне оформлення рядків 4.9.15 прибрано. Використовуються завантажені грою `LFGBrowseSearchEntryTemplate`, `LFGBrowseNestedSearchEntryTemplate`, `LFGBrowseSearchEntryGroupingTemplate`, стандартний `WowScrollBoxList` і смуга прокрутки відповідного стилю. Шрифти, висота рядків, п'ять місць групи, виділення та значки згортання беруться з клієнта. Суцільного фону й власних числових індикаторів складу немає. Збережені стандартні кнопки повідомлення й запрошення.

Фільтри груп і соло-гравців працюють незалежно. Порожній блок залишає свою категорію без обмежень. Вибір «Потрібен танк» фільтрує групи, зберігаючи гравців; вибір класу/ролі/рівня гравця не відкидає групи. Обидва блоки можуть бути активними одночасно. Власне оголошення зберігається у штатній верхній позиції.

Деталі й приклади: `NATIVE-UI-4.9.16-UA.md`. Новий прогін `tools/client_template_probe.py` перевіряє XML сучасного й класичного стилів та виконує 18 оригінальних Lua-файлів. Пройдено 46 перевірок для кожного стилю. Старі набори тестів не запускалися. Реальний renderer і taint у WoW цим не перевірені; піксельна перевірка в грі ще потрібна.

### 4.9.15 — Аудит реалізацій LFG та синхронізація стандартного списку

Виправлено оновлення після зміни стандартного провайдера без окремої події результатів, обробку невідомих ролей/рівня, розрахунок вільних місць у повній групі та застарілу дію стандартної кнопки запрошення. Порядок рядків і розділів береться зі стандартного провайдера; «Друзі й гільдія спочатку» змінює порядок лише всередині розділу.

Керування залишається в області результатів. Стандартні кнопки повідомлення й запрошення, верхні селектори, вкладки та їхні обробники збережені. Контекстне меню рядка використовує прості фрейми аддона; закривається при оновленні списку, Escape, натисканні поза меню й початку бою. Тимчасово недоступні дані мають окремий лічильник і максимум три повторні читання.

Повторно переглянуто 10 пов'язаних проєктів, включно з релізними архівами Eredol, Artefius і Werko. Порівняння, точні ревізії та рішення: `AUDIT-4.9.15-UA.md`. Чужий код та вихідні файли Blizzard до пакета не включені.

Новий прогін виконує дев'ять оригінальних Lua-файлів Forever 1.60.1.70862: пройдено 51 перевірку. З 27 додаткових сценаріїв 19 не проходять на 4.9.14. Старі тести не запускалися. C-фрейми, сервер, renderer і механізм taint імітуються; перевірки в запущеному WoW не було. Див. `VALIDATION-4.9.15.txt`.

### 4.9.9 — Show only results matching the selected Forever filter sections

- Selecting dungeon Needs/Already has conditions now shows only matching dungeon groups and omits unfiltered solo-player listings.
- Selecting player class/role/level conditions alone shows only matching solo players and omits unrelated groups.
- When both sections have conditions, retain matching groups and matching players, each evaluated against its own section. Clear all conditions to restore all results.
- Require every selected group Needs/Already has role (AND). Keep OR within player class/role sets and AND between class, role and level constraints.
- Do not bypass category/condition checks for the player's own listing. Its social priority is retained when it matches.
- Missing/secret required data is not a positive match. Re-evaluate streamed result updates so matching groups appear when data becomes readable, and disappear when a required slot fills.
- Update Forever-specific panel help and include the actual selected filter sets in `/ggfilters` output. Preserve Mainline matching/help behavior.

Validation: 326 assertions on Lua 5.1 and 326 on Lua 5.4; 44 Lua files compile on both. The 81-check browse integration suite also passes using the actual Forever TreeListDataProvider.lua supplied locally, with frame/UI APIs mocked. Tests cover real checkbox handlers, only-groups/only-players/both sections, AND conditions, filled/open slots and metadata arrival. In-game visual verification still requires WoW. See FIX-4.9.9-UA.md and VALIDATION-4.9.9.txt.

### 4.9.8 — Restore filter-control application and results rendering

- Replace the separate virtualized ScrollBox/FrameFactory list with an addon-owned plain ScrollFrame and reusable row pool, using the same base template as the working filter panel. Remove the new row XML template from both TOCs and the package.
- Re-evaluate and render visible provider nodes on every filter change; keep category collapsing, selection, row actions, scroll offset, highlights and tooltips independent of native LFG state.
- Resync the addon view's frame level when the native panel opens/raises, so the original rows cannot cover filtered results.
- Explicit filter edits now enable a previously disabled saved master flag. Social-priority edits preserve that flag.
- Show the rendered/native result count in the panel. Capture view-construction/provider errors, show a failure status and report details once instead of leaving an apparently active filter over unchanged native results.
- Add `/ggfilters` diagnostics with sanitized metadata, master state, view visibility and the last rendering error.
- Extend integration tests to click the actual class/role/composition checkboxes and commit level fields, drain scheduled updates and check the displayed row IDs. Test unchecking/restoration, scrolling, collapse, row-pool reuse, saved-disabled state, raised frames and failure recovery.

Validation: 310 assertions on Lua 5.1 and 310 on Lua 5.4; 44 Lua files compile on both. The 72-check browse suite also passes with the actual Forever TreeListDataProvider.lua supplied locally, using mocked frame APIs. Both TOCs have no custom row XML dependency. The specific in-client initialization failure was not captured; real WoW rendering and final recovery still require a client test. See FIX-4.9.8-UA.md and VALIDATION-4.9.8.txt.

### 4.9.7 — Complete Forever row and tooltip isolation

- Close the remaining 4.9.6 legacy paths that observed native ScrollBox rows, attached recycle hooks, tinted native ResultBG and refreshed Blizzard's native tooltip from addon code.
- Route full/single-row highlights and cleanup exclusively to ForeverBrowse. Retain the native UpdateResults post-hook only to schedule the independent presentation.
- Render insight details and Shift refresh in the addon row tooltip. Check its owner before refreshing/hiding, so recycled rows cannot affect another tooltip.
- Keep the addon view for highlight-only or tooltip-only configurations. Restore the native view when all addon browse presentation features are off.
- Sanitize group/leadership state before enabling invite actions and avoid repainting the same row twice on result-update events.
- Expand integration coverage to load actual LFG, LFGEnhancements, RealmInsights and EventBus modules. Test secret hasSelf/numMembers/activityIDs, inaccessible records, native UI mutation traps, tooltip ownership, feature switches and Retail tooltip compatibility.

The additional user reports were recorded before 4.9.6; they do not establish a failure of that version after installation. Inspection did establish that 4.9.6 still had native row/tooltip integration paths, now removed. This release does not claim an in-client reproduction or proof that every possible source of taint is eliminated.

Validation: 292 assertions on Lua 5.1 and 292 on Lua 5.4; 44 Lua files compile on both. The 54-check browse integration suite includes all remaining integration paths above. Expanded checks detect retained native hooks/tints in 4.9.6. XML and both TOCs pass. WoW taint-engine and visual checks still require the game client. See FIX-4.9.7-UA.md and VALIDATION-4.9.7.txt.

### 4.9.6 — Forever browse secret-width taint isolation

- Stop replacing Blizzard's browse ScrollBox provider or clearing its selection from addon code. Those operations ran native row initialization in an insecure context and could contaminate later native refreshes.
- Render filtered/sorted results in a separate addon-owned view, using sanitized SafeAPI snapshots and fixed text anchors. The new renderer never queries player-name widths or calls the native LFG row initializer.
- Preserve group/player filters, level limits, saved presets, social ordering, category collapsing, rule/social colors, and the existing language-search controller.
- Keep selection, whisper/invite controls, report menus, tooltips and empty state in the addon view. Native results, totals, selection, rows and provider stay Blizzard-owned.
- Hide the addon view during native searches, failures and Browse closure. Disabling both local filtering and social sorting returns to the native list.
- Repaint changed visible rows directly; coalesce refresh bursts into one next-frame provider update and retain scroll position.
- Filtered rows now use an addon-owned compact layout and tooltip, rather than Blizzard's exact row artwork. Decorative native details such as the Discord indicator are not reproduced in this release.

Validation: 267 assertions on Lua 5.1 and 267 on Lua 5.4; 44 Lua files compile on both runtimes. XML and TOC load order pass. Tests use mocked game APIs and cannot validate WoW's taint engine or in-game appearance. See FIX-4.9.6-UA.md and VALIDATION-4.9.6.txt. A complete UI reload or game restart is required to discard taint left by the previous version.

### 4.9.5 — API, event scheduling and combat notifications

- Coalesce roster/settings event bursts; ignore unrelated unit updates.
- Fix party-member counting and clear resolved identity retries.
- Separate outgoing search applications from incoming applicants.
- Prefer namespaced party/guild APIs; avoid duplicate legacy friend enumeration.
- Bound LFG caches, reject non-finite numeric keys and preserve nil async arguments.
- Defer banners and flashes during combat; preserve native animation scripts.
- Scale addon settings content to fit narrow canvases.
- Replace the unused Forever frame-placeholder workaround with passive diagnostics.
- Keep Retail interface tags 120105/120100/120007; add 16001 to the generic
  fallback TOC. Camelot remains 16001. Classic/SoD recognition is diagnostic;
  this release does not advertise unverified Classic interface compatibility.

Validation: 236 assertions on Lua 5.1 and the same 236 on Lua 5.4;
42 Lua files compile on both runtimes. See `API-AUDIT-4.9.5.md` and
`VALIDATION-4.9.5.txt`. Client/server UI and taint validation still require WoW.

### 4.9.4 — Search recovery and dispatch diagnostics

Fix the live log sequence: request #4 timed out, then #5–#10 all remained
“language unconfirmed” despite receiving responses. Uncertainty now belongs to
that response window. The first ambiguous response still carries a warning;
its terminal event clears the window, so later searches start clean. Failures
and late responses received without a new pending request also clear it.

A post-hook now records **Dispatch** with the actual category, activities and
language argument passed to `C_LFGList.Search`. Preparing a secure action is no
longer logged as evidence that it executed. If PostClick observes no matching
API invocation, the panel immediately says **Search was not sent**, clears the
pending attempt and allows a manual retry. No timeout uncertainty is created
for an unsent click. Synchronous responses remain supported.

View diagnostics wait for the queued presentation passes and report a count
only when our provider is still installed for the current native result list.
A stale/replaced provider is reported as **not settled** instead of a misleading
cached count. The server API exposes no response request ID in this event;
“Search complete” describes completion of the observed active search, not an
independent verification of each listing's language or the player's name.

The same filter panel, language selector, secure Search button, saved settings
and group/player filters remain in place. Replace the complete GroupGuardLFG
folder and reload the UI to discard the old controller's session state.

### 4.9.3 — Protected search fix

Fix the reported `ADDON_ACTION_BLOCKED / UNKNOWN()` at `ForeverSearch/Search.lua`.
The existing **Search** button now inherits Blizzard's `SecureActionButtonTemplate`.
PreClick validates the selection and prepares a native macro containing only numeric
activity/category IDs and whitelisted locale booleans. Blizzard's inherited OnClick
executes it from the player's click; GroupGuard no longer invokes the protected
`C_LFGList.Search` from addon Lua, `pcall`, timers or diagnostic commands.
PostClick clears the action. No custom globals or addon callbacks run in the macro.

The language selector remains in the existing filter panel. Groups, players, saved
selections and existing role/class/level filters use the same behavior as 4.9.2.
Synchronous or delayed `UNKNOWN()` rejection associated with our pending search
ends the attempt and disables further attempts until UI reload. Combat guards defer
protected panel visibility/position changes. An unavailable macro API or oversized
request disables that attempt instead of falling back to a direct protected call.

Replace the complete `Interface/AddOns/GroupGuardLFG` folder and restart WoW
(or `/reload` after replacing files). Keep your saved settings.
Validation uses Lua 5.1 with mocked APIs. A real Forever client is still required to
verify hardware-click authorization and the resulting multilingual server search.

### 4.9.2 — Integrated language search

Search groups and solo players across languages from the existing **GroupGuard filter panel**.

1. Open Browse and click the existing GroupGuard filter icon under the options gear.
2. In **Search languages** at the top of that same panel choose All languages, Game default, or several individual languages.
3. Click **Search** beside the language selector to request listings using that choice.

The previous globe launcher is removed. No additional side tab, standalone settings panel or alternate navigation is created. The language row stays fixed; existing role/class/level/preset controls scroll below it in the same panel. Reset/preset rebuilds reuse the language controls and preserve the saved language choice.

Languages come from the game API, are saved with GroupGuardLFGDB, and apply to both groups and solo players. Existing role, class, level and social filters continue to process the returned listings. Listings are not translated. The native refresh arrow and automatic searches retain the game's own languages.

Concurrent requests, five-second cooldown, empty selections, combat, API failures, timeout and protected rejection are handled by the existing manual search controller. No automatic searches are added. The feature is disabled on Retail.

Diagnostics: `/gglanguages info`, `/gglanguages log [errors|clear]`. Installation: replace `Interface/AddOns/GroupGuardLFG` with the folder in this archive and restart WoW; existing settings are kept. ForeverLFG is not required.

Search lifecycle, language filtering, base English strings and menu selection are adapted from ForeverLFG 0.5.3, copyright (c) 2026 Forever, MIT. Full license: `LICENSE-ForeverLFG`.

Validation: `bash tools/check_all.sh`, Lua 5.1. Automated tests mock game APIs; appearance and server permissions need checking in live Forever.

### 4.9.0 — Forever search intelligence
- Add safe Forever LFG metadata wrappers and capability probes for search results, categories, activities, activity groups, player level, zone and general playstyle.
- Expand dungeon composition filters with independent **Needs** and **Already has** role sets; every selected composition condition is combined with AND.
- Add solo-player **Min / Max level** filtering with fail-open handling while Forever result data is still streaming.
- Add **My filters** named presets (up to 20) for group needs/has roles, player roles/classes and level range.
- Add optional **Friends & guild first** ordering inside Blizzard's native Groups and Players sections while preserving the native result data model.
- Add Zone, Playstyle, Player level, Activity and Suggested level details to GroupGuard search tooltips when the client exposes them.
- Optimize Forever result updates: re-evaluate only the changed result, rebuild the visual provider only when visibility/category/social priority changes, and defer presentation refreshes while Browse is hidden.
- Preserve the taint-safe architecture: GroupGuard never writes filtered values into `LFGBrowseFrame.results` / `totalResults` and never calls protected `C_LFGList.Search()` itself.

### 4.8.16 — Forever native LFG filtering rebuild
- Return to the stable 4.8.11 Forever filter architecture and keep the two native result categories independent: **Groups** use Dungeon Needs filters, while **Players** use class/role filters.
- Remove the 4.8.15 behavior that applied player class/role matching across members of group listings.
- Rebuild only the native Forever ScrollBox display provider after Blizzard finishes a search. Non-matching results are omitted from the visual tree completely, so they consume no row height and leave no empty gaps.
- Keep `LFGBrowseFrame.results`, `totalResults`, dropdown state and protected `C_LFGList.Search()` Blizzard-owned and untouched.
- Preserve Blizzard's native result order and native Groups/Players collapsible sections.
- Restore the 16x16 GroupGuard filter button below `LFGBrowseFrame.OptionsButton` and raise it to the native button strata/frame level so it remains visible on current Forever builds.
- Keep the filter button available while the load-on-demand Forever LFG capability probes are still initializing.


### 4.8.11 — Forever LFG taint isolation
- Remove the Camelot `ForeverLoadGuard` that assigned a temporary value to Blizzard global `LFGWhoListFrame`.
- Stop rebinding `LFGWhoListFrame` after `Blizzard_GroupFinder_VanillaStyle` loads. Writing to this Blizzard global can persistently taint the VanillaStyle LFG execution path and later block protected `Search()`.
- Keep the 4.8.10 presentation-only filtering rules: no writes to `LFGBrowseFrame.results` / `totalResults` and no addon-driven Forever result rebuilds.
- Retail behavior remains unchanged.

### 4.8.10 — Forever protected Search taint hotfix

- Forever filters no longer overwrite `LFGBrowseFrame.results` / `totalResults`.
- Forever no longer invokes Blizzard browse result rebuild methods from addon code.
- Filter presentation is applied only after Blizzard creates visible rows.
- The Forever filter utility button is parented to `UIParent`, not the protected browse frame.
- Retail filtering behavior remains unchanged.
# GroupGuard LFG

## 4.8.9

- Change **Dungeons — group needs** role selection from OR to AND matching.
- Selecting Tank + Healer now shows only dungeon listings that still need both Tank and Healer; listings needing only one of them are excluded.
- Selecting all three roles requires all three roles to still be needed.
- Keep fail-open behavior only for temporarily unavailable Blizzard role-count data.
- Update English and Ukrainian filter help text to describe the combination logic correctly.

## 4.8.8

- Forever: use nickname-only player identity across LFG, social caches, group scans and raid/group tools; do not append or depend on realm names.
- Forever: read the leader through `C_LFGList.GetSearchResultLeaderInfo()` when available and fall back to `GetSearchResultInfo().leaderName`.
- Apply GroupGuard rules and Cyrillic/script detection to the visible Forever leader name and every available LFG member name.
- Forever: social-ignore applies per player instead of exempting the entire listing, so a friend/guild member cannot hide a rule match on another roster member.
- Use Blizzard Forever's native `ResultBG` row texture for rule/social highlighting so marked Cyrillic names are visibly highlighted instead of being hidden behind the row background.
- Expand Cyrillic UTF-8 detection to the broader Cyrillic byte range used by modern character names.
- Keep guild-name rule checks for party/raid members through `GetGuildInfo(unit)` and consume an LFG guild-name field only if a client build actually exposes one; arbitrary guild names are never guessed because the documented Forever search-result API does not provide them.
- Hide/disable realm insight controls on Forever while preserving full realm-aware behavior on Retail.
- Add a safe cached wrapper for `C_LFGList.GetSearchResultLeaderInfo()`.

## 4.8.7

- Hide Retail-only applicant-management and Premade Groups Filter integration settings on WoW Forever.
- Build the LFG settings page from client capabilities so unsupported controls are not shown.
- Keep Forever search highlighting, member checks, tooltips, role-fit hints, realm hints and social highlighting when their APIs are available.
- Hide the auto-decline test and applicant-only GG-column controls on Forever.
- Use modern `C_PartyInfo.UninviteUnit`, `C_PartyInfo.PromoteToAssistant` and `C_PartyInfo.DemoteAssistant` when available, with legacy fallbacks.
- Stop applicant-only hook retries on clients without the Retail ApplicationViewer.
- Do not load or initialize Premade Groups Filter integration from the Camelot TOC.

## 4.8.6

- Forever: replace the external filter TGA with a texture-free native funnel glyph to prevent the solid-green icon failure.
- Keep the GroupGuard filter control directly below `LFGBrowseFrame.OptionsButton` in the same 16x16 utility rail.
- Match the native options gear behavior: muted idle state, gold hover/active state, 1 px pressed offset, and no square button chrome.
- Reduce the vertical gap below the gear to 4 px for tighter alignment.
- Preserve the 4.8.5 Camelot WhoList load-order guard and all existing filter behavior.

## 4.8.5

- Historical (removed in 4.8.11): added an early Camelot-only load guard for Blizzard's `LFGWhoListFrame` initialization race.
- Prevent `LFGBrowseMixin:OnLoad()` from crashing when an active listing exists during `/reload` before Blizzard has loaded `WhoList.xml`.
- Historical (removed in 4.8.11): rebound the temporary compatibility object to Blizzard's real `LFGWhoListFrame`.
- Do not replace Blizzard secure frames or Group Finder functions; the guard exists only during the TOC load gap.
- Add a recovery path for partially loaded Forever Group Finder sessions.

## 4.8.4

- Forever: move the GroupGuard filter control out of the refresh row and into Blizzard's native LFG header utility rail directly below `LFGBrowseFrame.OptionsButton`.
- Replace the temporary gear artwork with a dedicated funnel/filter icon while matching Blizzard's 16x16 options-button hover, press, and alpha behavior.
- Remove square `UIPanelButtonTemplate` chrome from the Forever filter control so it visually matches the native options gear instead of the refresh button.
- Move the filter panel past the native right-side Listing / Browse / Who tab rail so the GroupGuard window no longer covers Blizzard navigation tabs.
- Remove obsolete bundled gear textures.

## 4.8.3

- Replace the temporary Forever filter placeholder with a dedicated GroupGuard gear icon.
- Add normal, hover, pressed, and disabled gear artwork bundled with the addon.
- Match the filter button size and vertical alignment to Blizzard's native refresh button.
- Keep the 4 px gap between the native refresh control and GroupGuard filters.
- Preserve Blizzard button chrome, tooltip behavior, and the active-filter indicator.

## 4.8.2

- Forever: stop forcing `Blizzard_GroupFinder_VanillaStyle` to load as an optional dependency.
- Forever: stop adding an extra forced-load path for Blizzard's VanillaStyle group finder; the native client can still hit its own `LFGWhoListFrame` TOC-order race when reloading with an active listing (fixed defensively in 4.8.5).
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
- Adds a stock-style search filter panel: dungeon groups can be filtered by roles they still need **and** roles already present; solo player listings can be filtered by class, role and level.
- Supports named filter presets and optional friend/guild priority inside the native Forever Groups/Players sections.

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
- Added separate filter blocks for **Dungeon groups — roles still needed** and **Players — class + role**. Dungeon role choices are AND (all selected roles must still be needed); player classes/roles remain OR within each set, with class AND role between the two player sets.
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

### 4.9.10 — Recover hidden Forever results

Search responses now refresh the independent addon view even if Blizzard's renderer aborts before its post-hook. Per-result updates also restore hidden or missing presentations. A completed search with no matches keeps the addon-owned empty list visible.

`/ggfilters` now reports version, Browse visibility, search state, hide reason, current matches and player levels. A cached count from a hidden view is no longer presented as the number currently shown.

Validation: 334 assertions pass on each of Lua 5.1 and 5.4, including recovery regressions that fail against 4.9.9. WoW UI APIs are mocked; live-client behavior still requires verification. See FIX-4.9.10-UA.md and VALIDATION-4.9.10.txt.

### 4.9.11 — Show filtered Forever results above native rows

Fix the case where the filter counter changed but Blizzard's original list remained on screen. The addon list now uses its own fixed foreground rendering layers and consumes mouse input over the native list. The filter panel stays above it. `/ggfilters` also reports layer, size and alpha information.

Validation: 342 assertions pass on each of Lua 5.1 and 5.4. Rendering and mouse APIs are mocked; the final in-game result still requires verification. See FIX-4.9.11-UA.md and VALIDATION-4.9.11.txt.

### 4.9.12 — Forever API and native UI behavior

Fix solo-player role filtering when Forever's assigned role differs from the advertised roles. Improve row and tooltip recycling, preserve context-menu targets, and prefer the client's native invitation API.

The independent list uses game artwork, role icons/counts and separate entry/category heights. The Forever filter panel shortens its scroll viewport on small displays, keeps normal text sizes where possible and defers protected layout changes during combat. Global HUD settings and Blizzard providers remain untouched.

365 assertions pass on each of Lua 5.1 and Lua 5.4. UI APIs are mocked; in-game verification remains necessary. See FIX-4.9.12-UA.md and VALIDATION-4.9.12.txt.

### 4.9.13 — Original client sources and event-driven browse ownership

Remove Forever hooks on Blizzard's Lua browse refresh methods. Follow game events and frame scripts instead. While the addon view is active, hide the original list, scrollbar and footer controls, then restore them when releasing the view. Protected visibility changes wait until combat ends.

Build the view from a sanitized `C_LFGList.GetFilteredSearchResults()` snapshot, preserving Blizzard's result table/provider and separating unavailable data from zero matches. Diagnostics include client build, event mode, snapshot source and native visibility state.

Implementation reviewed against the original Forever 1.60.1.70862 UI and the MIT-licensed BetterGroupFinder and LFG Filter Forever sources. See SOURCES-4.9.13-UA.md for the comparison and precise revisions.

At the user's request, historical test suites were not run for this release. The new `tools/client_source_probe.py` executes six checksum-verified ORIGINAL Blizzard Lua files with the production addon modules. C widget bindings are simulated: this does not certify in-game rendering, taint, server searches or invitations. See VALIDATION-4.9.13.txt.

### 4.9.14 — Preserve standard LFG buttons and control only the results viewport

Remove replacement message/invite buttons. Keep the original footer controls visible, with their original handlers, parent and anchors. Only the results list and its scrollbar are visually suppressed during filtered presentation.

Selecting a filtered row selects the corresponding ORIGINAL node through Blizzard's SelectionBehavior API. The client updates and executes its own message/invite buttons. Filtered-out selections are cleared through that same controller. Entries not yet present in the standard provider wait for the client rather than receiving invented selection data.

The source integration probe now loads nine original client files, including Flags, EnumUtil and ScrollUtil. It executes the original selection controller and the original message/invite handlers, and confirms no replacement footer widgets exist. Historical suites were not run. C widgets/security/renderer remain simulated; actual WoW verification is still required. See SCOPE-4.9.14-UA.md and VALIDATION-4.9.14.txt.

