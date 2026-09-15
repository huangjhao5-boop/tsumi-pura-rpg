# Handoff Report: E2E Test Coverage Specifications for R1 & R2 (Milestone 5)

## 1. Observation

1. **Feature Scope & Documentation**:
   - `PROJECT.md` lines 23–42 define R1 (Features 1–12) and R2 (Features 13–17).
   - `SPEC.md` lines 39–64 detail the Battle Engine multipliers (Snap-fit 1.0x, Sanding 1.2x, Detailing 1.5x, Airbrush 2.0x, Finishing 2.5x), Mercy Rule floor formula `(elapsed / total) * base * mult * 0.5`, and Finishing Gate `<= 20%`.
   - `SPEC.md` lines 145–171 define SQLite/persistence schemas for `KitItem` and `CraftLog`.

2. **Codebase Implementation Details (`lib/`)**:
   - `lib/main.dart` lines 80–123 define the active kit state, initial seed kit fallback, Pomodoro phase states (`idle`, `work`, `rest`), controllers, and process selection.
   - `lib/main.dart` lines 210–221: Work timer counts down each second; when `_remainingSeconds == 0`, the next tick executes `_completeWorkSession()`.
   - `lib/main.dart` lines 303–311: Pure damage calculation via `_battleEngine.calculateDamage(...)`.
   - `lib/main.dart` lines 313: `final int earnedCoins = (actualElapsedSeconds / 5).round().clamp(2, 50);`. Even at 0s elapsed, clamp yields 2 coins.
   - `lib/main.dart` lines 332–335: Victory dialog delay `Future.delayed(const Duration(milliseconds: 700))` before `_showQuestClearDialog()`.
   - `lib/main.dart` lines 1189–1275: `SegmentedButton<String>` for craft phases (`'Snap-fit'`, `'Sanding'`, `'Detailing'`, `'Airbrush'`, `'Finishing'`). Finishing is disabled with label `'水貼\n🔒20%'` when HP > 20%, and enabled with `'水貼\n2.5x'` when HP <= 20%.
   - `lib/presentation/widgets/retro_bottom_nav_bar.dart` lines 35–56 provide keys: `btn_nav_battle`, `btn_nav_hangar`, `btn_nav_showcase`, `btn_nav_craft_log`.
   - `lib/presentation/screens/craft_log_screen.dart` lines 192: Back button key `btn_craft_log_back`, refresh tooltip `'重新整理'`, filter segment for active kit vs all logs.

3. **Existing Tests Review**:
   - `test/unit/battle_engine_test.dart` & `battle_engine_adversarial_test.dart`: Complete unit tests verifying formula results, half-up rounding (37.5 -> 38, 62.5 -> 63, 82.5 -> 83), clamping, and guards.
   - `test/widget/battle_autosave_test.dart`: Confirms that 5s debug completion saves updated kit and craft log.
   - `test/challenge/pomodoro_challenge_test.dart`: Documents empirical N+1 tick timing for work session completion.
   - `test/challenge/ui_state_autosave_stress_test.dart`: Demonstrates multi-turn combat loops, app re-launch hydration, and background timer preservation across routes.

---

## 2. Logic Chain

1. **Opaque-Box Requirement Derivation (from Observation 1 & 2)**:
   - To achieve genuine E2E opaque-box coverage, tests must interact only with user-facing buttons, segment controls, text inputs, and navigation links.
   - Direct mutation of private state (e.g. `_pomodoroPhase = ...`) is prohibited; all state transitions must be triggered via `tester.tap` on widgets such as `find.text('5秒測試')`, `find.textContaining('開始開工')`, `find.textContaining('中途中斷')`, and `find.textContaining('略過休息')`.

2. **Feature Coverage Granularity (Tier 1 >= 5 per feature)**:
   - For all 17 features (Features 1–17), at least 5 happy-path test cases have been defined in `analysis.md` Section 4.
   - Each test case specifies initial setup, exact user gesture, time advancement, and assertion criteria across UI text, HP bar fraction, combat dialogue, and repository records.

3. **Boundary & Corner Case Coverage (Tier 2 >= 5 per feature)**:
   - For all 17 features, at least 5 boundary/corner cases have been defined in `analysis.md` Section 5.
   - Key boundaries include:
     - 0s and 1s interruptions (testing the 1 damage floor and 2 coin clamp).
     - 50% and 99% progress interruptions (testing half-up rounding accuracy).
     - Strict 20.0% vs 20.2% HP threshold for Finishing Gate (`100/500` vs `101/500`).
     - Auto-reset of Finishing when switching active kit in Hangar to a >20% HP kit.
     - Empty CraftLog state, corrupted JSON recovery in LocalStorageService, and viewport scaling (320x480 to 1440x2560).

4. **Test Writer Implementation Structure**:
   - The test specifications directly map into two files:
     - `test/e2e/e2e_tier1_r1_r2_test.dart`: Tier 1 Feature Coverage (Happy Paths, Features 1–17).
     - `test/e2e/e2e_tier2_r1_r2_test.dart`: Tier 2 Boundary & Corner Cases (Features 1–17).
   - Test suites share a clean setup helper with `SharedPreferences.setMockInitialValues({})`, `Size(1080, 1920)` viewport, and a 200ms pump for zero-flicker hydration.

---

## 3. Caveats

1. **Timer Tick Advance Rule**:
   - In Flutter widget tests running `Timer.periodic`, advancing the exact duration (e.g. 5 seconds) reaches `_remainingSeconds == 0`, but the callback executing `_completeWorkSession()` occurs on the subsequent periodic tick (tick 6). Test authors must pump `N + 1` ticks (e.g. `pump(Duration(seconds: 1))` 6 times or `pump(Duration(seconds: 5))` followed by `pump(Duration(seconds: 1))`).
2. **Quest Clear Dialog Delay**:
   - When lethal damage drops currentHp to 0, `_showQuestClearDialog()` is dispatched via `Future.delayed(const Duration(milliseconds: 700))`. Tests asserting on victory dialog widgets must `pump(const Duration(milliseconds: 800))` before finding `★ QUEST CLEAR ★`.
3. **Coin Floor on 0s Interruption**:
   - `lib/main.dart` clamps coin rewards to `clamp(2, 50)`. Even with 0 elapsed seconds, 2 coins are awarded. Assertions on coin amounts must anticipate this behavior.
4. **No Implementation Changes Made**:
   - In adherence to read-only Explorer constraints, no application or test implementation files were created in `test/e2e/` or modified in `lib/`. Full implementation is handed off to the Test Writer agent.

---

## 4. Conclusion

The E2E test coverage blueprint for R1 (Features 1–12) and R2 (Features 13–17) is fully analyzed, formulated, and validated against the codebase.
- Detailed specifications for **85 Tier 1 test cases** and **85 Tier 2 test cases** (170 total test cases) are documented in `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m5_1\analysis.md`.
- All widget keys, UI finder strategies, timing rules, and expected assertions are fully prepared for the Test Writer to implement in:
  1. `test/e2e/e2e_tier1_r1_r2_test.dart`
  2. `test/e2e/e2e_tier2_r1_r2_test.dart`

---

## 5. Verification Method

To independently verify the investigation and subsequent test execution:

1. **Inspect Analysis and Specification Artifacts**:
   - `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m5_1\analysis.md`
   - `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m5_1\handoff.md`

2. **Test Execution Command for Test Writer**:
   Once implemented in `test/e2e/`:
   ```bash
   flutter test test/e2e/e2e_tier1_r1_r2_test.dart
   flutter test test/e2e/e2e_tier2_r1_r2_test.dart
   flutter test
   flutter analyze
   ```

3. **Invalidation Conditions**:
   - Any test case failing due to unhandled async timers or layout overflows.
   - Any test attempting to access private state variables rather than user-facing widgets or public repository contracts.
   - Missing coverage for any of Features 1–17 with fewer than 5 test cases per tier.
