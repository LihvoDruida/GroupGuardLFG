### 4.9.19 — Актуальні контракти перевірок CI

Виправлено падіння пакувального workflow на застарілому стенді 4.9.12. Перевірка фільтрів тепер завантажує справжній SafeAPI та очікує незалежні категорії, невідомі advertised roles і незмінені групи інших активностей. Старий ScrollFrame-only стенд замінено інтеграцією з оригінальними Lua/XML клієнта та реальним ScrollBox.lua. Перевірки не повертають стару поведінку фільтрів і не забороняють штатні шаблони.

`check_all.sh` і `verify.py` використовують спільний запуск `forever_checks.py` для сучасного й класичного стилів. Workflow встановлює CI-залежність lupa у venv. Оригінальні джерела завантажуються за зафіксованим commit і перевіряються за SHA-256 та Git blob; відсутність залежностей, джерел або провал будь-якого стилю завершує перевірку помилкою. Старі CLI source-probe перенаправлені на актуальний стенд.

Пройдено 35 сценаріїв фільтрів на кожному з Lua 5.1/5.4 та 72 сценарії списку для кожного стилю. Перевірено передачу ненульового exit code та виявлення старого перекриття кнопок. Усі 32 робочі Lua-файли ідентичні 4.9.18. Інші старі набори тут повторно не запускалися; повний workflow GitHub і renderer WoW не виконувалися. Деталі: `CI-4.9.19-UA.md`, `VALIDATION-4.9.19.txt`.

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

### 4.9.10 — Recover hidden Forever results independently of native rendering

- Refresh the addon results view directly on search-response and search-failure events. A Blizzard UpdateResults error can prevent its post-hook from running; the addon no longer relies on that hook alone.
- Rebuild hidden, missing or stale presentations on per-result updates, even when that result's filter verdict has not changed. Keep row-only updates for healthy presentations.
- Preserve the addon-owned empty state when a completed search has no matching results, including a solo-player minimum level of 50.
- Mark queued refreshes as pending immediately. Diagnostics now include addon version, Browse visibility, search state, hide reason, current match count and player level; a hidden/stale view reports its count as unavailable.

Validation: 334 assertions on each of Lua 5.1 and 5.4; 44 Lua files compile on both. The browse suite also passes 89 checks on each runtime with the actual client TreeDataProvider implementation and mocked UI APIs. The same new tests fail seven checks with the 4.9.9 runtime, including hidden-view recovery and empty results. The user's log establishes that the addon view was hidden, but does not establish why it was hidden in that session. In-game verification is still required. See FIX-4.9.10-UA.md and VALIDATION-4.9.10.txt.

### 4.9.11 — Show filtered Forever results above native rows

The addon could report a current filtered provider while Blizzard's unfiltered rows remained visible and hoverable. The results layer inherited Browse's stratum and derived its level from native getters, which can be secret; Browse children can also have a higher rendering stratum than Browse.

- Use fixed addon-owned DIALOG layers for the results surface, ScrollFrame, content, row pool, scrollbar and action buttons. Do not read native strata/levels to decide their rendering order.
- Keep the Forever filter panel above the results surface at its own fixed DIALOG level.
- Explicitly consume hover and click input across rows, blank list space and the original-scrollbar shield. Route wheel input over blank space to the addon list.
- Extend `/ggfilters` with view, scroll and native layer/size/alpha diagnostics. Give the results surface a stable frame name for inspection.

Validation: 342 assertions pass on each of Lua 5.1 and Lua 5.4, with all 44 Lua files compiling. The 97-check browse suite also passes on both runtimes with the actual client TreeDataProvider implementation and mocked UI/frame APIs. The new suite fails six checks against 4.9.10, covering higher native strata, secret layering values, input isolation and wheel handling. No actual WoW rendering or engine-level taint test was performed. See FIX-4.9.11-UA.md and VALIDATION-4.9.11.txt.

### 4.9.12 — Respect Forever role contracts and native UI behavior

- For Forever solo-player filters, advertised `lfgRoles` takes precedence over `assignedRole`. A healer advertising only healer no longer also matches Damage because the API's assigned role defaults to DAMAGER. Keep the established Retail contract and the assigned-role fallback when advertised flags are absent.
- Use localized advertised roles for solo-player tooltip entries and assigned roles for members of an existing group.
- Prefer Forever's `C_PartyInfo.InviteUnit`, retain legacy fallbacks, and disable invitations when the capability is absent. Context-menu actions keep their original result ID and revalidate it on click.
- Close owned tooltips when a row is recycled or its result disappears; leave other tooltip owners alone.
- Use client list artwork, 52px entries, 36px category headers, a group-leader marker, and role icons with counts. Solo class icons use player metadata even when leader metadata is unavailable.
- On short displays, shorten the Forever filter panel's scroll viewport before scaling, preserving ordinary font sizes. Refit on display/UI-scale changes; defer protected layout changes during combat. All Forever filter controls remain scrollable even without the language module.

Validation: 365 assertions pass on each of Lua 5.1 and Lua 5.4; 44 Lua files compile on both. The 115-check browse suite also passes with the locally supplied client TreeDataProvider implementation on both runtimes. The two new role regressions fail against 4.9.11. Frame/UI APIs and events are mocked; no actual WoW rendering or engine-level taint test was performed. See FIX-4.9.12-UA.md and VALIDATION-4.9.12.txt.

### 4.9.13 — Use original client sources and event-driven browse ownership

- Remove Forever hooks on `LFGBrowseFrame:UpdateResults` and `LFGBrowseMixin:UpdateResults`. Do not install Mainline browse-function hooks on Forever. Use events and frame lifecycle/refresh-click scripts.
- Hide the original list, scrollbar and action buttons while the own view is active. Re-hide native controls if Blizzard shows them again. Restore prior/intended visibility when the own view closes, preserving native provider and selection data.
- Defer protected visibility changes during combat and perform restoration after combat even when addon features are disabled.
- Read the documented `GetFilteredSearchResults` return contract into an independent safe snapshot. Native result filtering by another addon no longer removes candidates from this view. Keep a guarded native fallback for unavailable APIs.
- Skip unavailable member data and show a waiting message instead of reporting it as zero matches. Distinguish actual zero matches from empty client results.
- Add build/source/visibility diagnostics and an original-source verification manifest.

Research: pinned original Forever 1.60.1.70862 sources; BetterGroupFinder UI ownership/event approach; LFG Filter Forever sorting hook reviewed but not adopted. No upstream addon source/assets are bundled.

Validation: historical test suites were NOT run, as requested. The new source probe loads original Mixin, TableUtil, CallbackRegistry, DataProvider, TreeListDataProvider and Blizzard browse Lua, verifies their hashes, and runs the native event/sort/provider paths alongside addon logic. It reproduces the original expired-tooltip nil failure and checks that suppressed native rows cannot receive hover. C bindings/security/renderer are simulated; an actual client run is still required.

### 4.9.14 — Limit control to the results list; preserve the native footer

- Stop suppressing native message/invite buttons. Remove the addon-created footer replacements entirely.
- Preserve native footer handlers, parent, anchors, visibility and client-owned enabled state. The overlay remains restricted to the list viewport and its scrollbar.
- Bridge row clicks to actual nodes in the standard provider with SelectionBehavior SelectElementData/DeselectElementData. Original Blizzard callbacks update the original buttons; no addon click handler replaces them.
- Mirror native selection in filtered rows and clear a selected entry if filters exclude it. Wait for standard provider nodes instead of injecting addon-created selection data.
- Track native provider changes and report native selection/footer mode in diagnostics.

Validation: only the original-client-source probe and production syntax checks ran; historical suites did not. The probe now loads nine checksum-verified original files. It executes original ScrollUtil/SelectionBehavior and original message/invite callbacks, including group/solo eligibility, deselection and filtered-out selection handling. Native footer scripts, parents, anchors and visibility remain unchanged in this probe. Actual engine rendering/security and server operations remain unverified.

