# HANDOFF — Explorer 3 for Milestone 3: Navigation, Active Kit Link & Victory Transition

**Author:** Explorer 3 (`teamwork_preview_explorer_m3_3`)  
**Parent:** `6fa20b7c-dc2d-40cc-9d90-84e64adeddcf`  
**Date:** 2026-09-11  
**Target Milestone:** Milestone 3 (Navigation Architecture, Feature 22 & Feature 23)  

---

## 1. Observation

Direct observations from codebase inspection and local test execution:

1. **Current Screen & Routing State**:
   - `lib/main.dart` lines 28–47 define `TsumiPuraApp`, which sets `home: BattleAtelierScreen(...)` without route definitions.
   - `lib/main.dart` lines 618–678 define `_buildHeaderHUD()`, which contains only the title `'TSUMI-PURA RPG'`, gold coin count, and an `InkWell` for `Key('btn_craft_log')` opening `CraftLogScreen`.
   - `lib/main.dart` lines 513–550 implement `_showQuestClearDialog()` which currently features a single button `'收錄至展示櫃 (Showcase)'` that executes:
     ```dart
     Navigator.of(context).pop();
     final resetKit = _activeKit.reset();
     _activeKit = resetKit;
     _kitRepo.saveKit(resetKit).catchError((e) => debugPrint('$e'));
     ```
     This call to `reset()` immediately wiped the `completed` status and erased `completedAt`, keeping the kit unstarted and preventing `ShowcaseScreen` from ever displaying it.

2. **M2 Test Contract & Tension with M3**:
   - In `test/challenge/ui_state_autosave_stress_test.dart` lines 234–252:
     ```dart
     // Verify kit in repository marked as completed
     final defeatedKit = await kitRepo.getActiveKit();
     expect(defeatedKit, isNotNull);
     expect(defeatedKit!.currentHp, equals(0));
     expect(defeatedKit.isCompleted, isTrue);

     // Tap "收錄至展示櫃 (Showcase)" button
     await tester.tap(find.textContaining('收錄至展示櫃'));
     await tester.pump();
     await tester.pump(const Duration(milliseconds: 300));

     // Dialog dismissed, HP reset to 500
     expect(find.text('★ QUEST CLEAR ★'), findsNothing);
     expect(find.textContaining('500 / 500 HP'), findsOneWidget);

     // Repository updated with reset kit
     final resetKit = await kitRepo.getActiveKit();
     expect(resetKit!.currentHp, equals(500));
     ```
     This M2 stress test explicitly relies on `find.textContaining('收錄至展示櫃')` resetting the single kit for consecutive combat cycles.

3. **Background Navigation & Timer Preservation Contract**:
   - `test/challenge/ui_state_autosave_stress_test.dart` lines 674–725 (`Challenge Task 4: Navigation State Preservation Stress`) proved that navigating via `Navigator.push` keeps `BattleAtelierScreen` mounted so that background `Timer.periodic` continues without corruption.

4. **Peer Explorer Interfaces**:
   - Explorer 1 (`teamwork_preview_explorer_m3_1/analysis.md`):
     `HangarScreen` (`lib/presentation/screens/hangar_screen.dart`) provides `Key('btn_hangar_back')` for navigation back, `Key('btn_add_kit')`, and `Key('btn_set_active_${kit.id}')` which calls `kitRepository.setActiveKit(kit.id)`.
   - Explorer 2 (`teamwork_preview_explorer_m3_2/analysis.md`):
     `ShowcaseScreen` (`lib/presentation/screens/showcase_screen.dart`) displays completed kits (`kit.isCompleted == true`), provides `Key('btn_showcase_back')`, and shows empty state `Key('showcase_empty_state')` with verbatim copy `"尚無完工模型，快去討伐堆積吧！"`.

5. **Test Suite Baseline**:
   - `flutter test` was executed and completed with code 0:
     `00:52 +137: All tests passed!`

---

## 2. Logic Chain

1. **Dual-Tier Navigation Architecture (Observation 1 & 3)**:
   - Because existing tests rely on `Key('btn_craft_log')` inside `_buildHeaderHUD` and require background timers to tick during push navigation, we must maintain `Navigator.push(...)` and keep `Key('btn_craft_log')`.
   - We introduce top header quick links (`Key('btn_hangar')`, `Key('btn_showcase')`, `Key('btn_craft_log')`) and a bottom dock (`RetroBottomNavBar` with `Key('btn_nav_battle')`, `Key('btn_nav_hangar')`, `Key('btn_nav_showcase')`, `Key('btn_nav_craft_log')`).
   - Every secondary screen opening helper (`_openHangarScreen`, `_openShowcaseScreen`, `_openCraftLogScreen`) awaits `Navigator.push(...)` and then immediately calls `await _hydrateActiveKit()`.

2. **Feature 22 State Synchronization (Observation 4)**:
   - When the user selects a kit in `HangarScreen` via `Key('btn_set_active_${kit.id}')`, `kitRepository.setActiveKit(kit.id)` persists the selection to `StorageKeys.activeKitId`.
   - Upon popping back to `BattleAtelierScreen`, `_hydrateActiveKit()` executes:
     - Fetches the active `KitItem` via `kitRepository.getActiveKit()`.
     - Updates `_activeKit`, `maxHp = storedKit.totalHp`, `currentHp = storedKit.currentHp`.
     - Boss card immediately displays the updated Title, Grade, and HP Bar.
     - Automatically resets `_selectedPhase` to `Snap-fit` if `Finishing` was active but the new Boss HP > 20%.

3. **Feature 23 Victory Transition & Backward Compatibility (Observation 1, 2 & 4)**:
   - When Boss HP <= 0, `_recordSessionAndSave` automatically sets `status: KitStatus.completed` and `completedAt = DateTime.now()`, persisting it to repository.
   - The redesigned `_showQuestClearDialog()` offers three distinct actions:
     1. `"前往展示櫃觀看"` (`Key('btn_clear_to_showcase')`): Pops dialog, opens `ShowcaseScreen`. The kit remains permanently completed in storage.
     2. `"返回機庫挑選新目標"` (`Key('btn_clear_to_hangar')`): Pops dialog, opens `HangarScreen`. The kit is marked `[已完工]`.
     3. `"收錄至展示櫃 (Showcase)"` (`Key('btn_clear_restart')`): Resets the kit HP to totalHp and restarts. This preserves 100% compatibility with `ui_state_autosave_stress_test.dart` line 241 without breaking M2 challenge assertions.

---

## 3. Caveats

1. **Combat-Active Target Locking**:
   - If a Pomodoro work session is active (`_pomodoroPhase == PomodoroPhase.work`), target switching should either be disabled or guarded in `HangarScreen` (`isCombatActive == true`) to prevent damage attribution to the wrong model.
2. **All Kits Defeated State**:
   - If a player completes all kits in their repository and returns to the Battle Screen without adding a new kit, `kitRepository.getActiveKit()` returns the completed kit with 0 HP. `BattleAtelierScreen` renders an empty/victory banner directing the player to the Hangar to register a new kit.
3. **Screen Size Constraints**:
   - All modal dialogs and bottom navigation docks are wrapped with `SafeArea` and `ConstrainedBox(maxWidth: 540)` to prevent horizontal scaling issues on wide screens.

---

## 4. Conclusion

The architectural investigation, implementation blueprints, and automated test specifications for **Milestone 3 Navigation, Active Kit Link (Feature 22), and Boss Defeat Transition (Feature 23)** are complete:
- **Target Files for Worker**:
  - `lib/presentation/widgets/retro_bottom_nav_bar.dart` (New Retro Arcade Dock widget)
  - `lib/main.dart` (Navigation integration, Header HUD buttons, Quest Clear dialog overhaul, and `_hydrateActiveKit` enhancements)
  - `test/widget/navigation_and_active_kit_test.dart` (Full integration test suite covering navigation, kit switching, finishing skill reset, and victory transitions)
- **Peer Synergy**:
  - Works seamlessly with Explorer 1's `HangarScreen` (`lib/presentation/screens/hangar_screen.dart`) and Explorer 2's `ShowcaseScreen` (`lib/presentation/screens/showcase_screen.dart`).
  - Guarantees 0 errors / 0 warnings in `flutter analyze` and 0 regressions across all 137 baseline tests.

---

## 5. Verification Method

### Test Commands
1. **Run New Milestone 3 Navigation & Active Kit Test Suite**:
   ```powershell
   flutter test test/widget/navigation_and_active_kit_test.dart
   ```
2. **Run Full Regression Test Suite (137+ tests)**:
   ```powershell
   flutter test
   ```
3. **Run Static Analyzer**:
   ```powershell
   flutter analyze
   ```

### Files to Inspect
- `lib/main.dart`
- `lib/presentation/widgets/retro_bottom_nav_bar.dart`
- `test/widget/navigation_and_active_kit_test.dart`
- `.agents/teamwork_preview_explorer_m3_3/analysis.md`

### Invalidation Conditions
- Any failure in `flutter test` or `flutter analyze`.
- Absence of `Key('btn_hangar')`, `Key('btn_showcase')`, or `Key('btn_craft_log')` in Header HUD.
- Failure of Boss Card in BattleScreen to update after setting a new active kit in HangarScreen.
- Overwriting / erasing completion status of a defeated kit when navigating to ShowcaseScreen or HangarScreen.
- Breakdown of background timer ticking when secondary screens are pushed.
