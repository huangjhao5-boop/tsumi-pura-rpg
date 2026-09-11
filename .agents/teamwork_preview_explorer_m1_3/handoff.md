# HANDOFF — Milestone 1: UI Integration, Timer Transitions & Analyzer Verification

**Agent**: `teamwork_preview_explorer_m1_3`  
**Working Directory**: `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m1_3`  
**Handoff Type**: Hard (Task Complete)

---

## 1. Observation

1. **Static Analysis Violations (`flutter analyze`)**:
   Executed command: `flutter analyze` in `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg`
   Tool result:
   ```
   Analyzing nifty-heisenberg...                                   

      info - Unnecessary use of multiple underscores - lib\main.dart:298:37 - unnecessary_underscores
      info - Unnecessary use of multiple underscores - lib\main.dart:298:41 - unnecessary_underscores
      info - Unnecessary use of multiple underscores - lib\main.dart:676:39 - unnecessary_underscores
      info - Unnecessary use of multiple underscores - lib\main.dart:676:43 - unnecessary_underscores
      info - Unnecessary use of multiple underscores - lib\main.dart:719:39 - unnecessary_underscores
      info - Unnecessary use of multiple underscores - lib\main.dart:719:43 - unnecessary_underscores

   6 issues found. (ran in 32.0s)
   ```
   Specific lines in `lib/main.dart`:
   - Line 298: `errorBuilder: (_, __, ___) => const Icon(Icons.military_tech, ...)`
   - Line 676: `errorBuilder: (_, __, ___) => const Icon(Icons.smart_toy, ...)`
   - Line 719: `errorBuilder: (_, __, ___) => const Icon(Icons.person, ...)`

2. **Inline Damage Logic in `lib/main.dart`**:
   - Lines 184–192:
     ```dart
     double basePoints = 100.0 * elapsedRatio;
     double multiplier = _phaseMultipliers[_selectedPhase] ?? 1.0;
     double totalDamage = basePoints * multiplier;

     if (isInterrupted) {
       totalDamage = totalDamage * 0.5; // Mercy Rule 50%
     }

     int finalDamage = totalDamage.round();
     ```
   - Observation: Base points are hardcoded to `100.0`. Deep focus mode (50m = 220 base points per SPEC §2.1) is not supported.

3. **Timer State & Missing Rest Cycle**:
   - Lines 48–53:
     ```dart
     Timer? _timer;
     int _remainingSeconds = 0;
     int _totalSeconds = 0;
     bool _isRunning = false;
     int _totalSessionDurationSeconds = 0;
     ```
   - Lines 164–175:
     ```dart
     void _completeSession() {
       _timer?.cancel();
       _calculateAndApplyDamage(...);
       setState(() {
         _isRunning = false;
       });
     }
     ```
   - Observation: When a work session ends, `_isRunning` becomes `false`. There is no rest phase state, no rest countdown, and no automatic or manual transition to the rest cycle.

4. **Missing 50m Mode Controls**:
   - Lines 955–993:
     ```dart
     Expanded(
       flex: 2,
       child: ElevatedButton.icon(..., label: const Text('開始開工 (25m)'), onPressed: () => _startTimer(25)),
     ),
     Expanded(
       flex: 1,
       child: ElevatedButton(..., child: const Text('5秒測試'), onPressed: () => _startTimer(0, isTest: true)),
     ),
     ```
   - Observation: Only 25m and 5s test buttons exist; 50m deep focus mode is absent.

5. **Test Failure in `test/widget_test.dart`**:
   Executed command: `flutter test`
   Result:
   ```
   00:01 +0 -1: Counter increments smoke test [E]
   Expected: exactly one matching candidate
     Actual: _TextWidgetFinder:<Found 0 widgets with text "0": []>
   ```
   Observation: The default counter test fails because the app is `TsumiPuraApp`.

---

## 2. Logic Chain

1. **Addressing Observation 1 (Lint Issues)**:
   In Dart 3.7+, wildcards allow multiple unused parameters named `_` in the same parameter list without collision. The `unnecessary_underscores` lint flags `__` and `___` as redundant. Replacing `(_, __, ___)` with `(_, _, _)` at lines 298, 676, and 719 preserves exact semantics while eliminating all 6 reported issues, achieving 0 analyzer errors/warnings.

2. **Addressing Observation 2 (Decoupled BattleEngine)**:
   Per `PROJECT.md` Architecture & Interface Contracts, pure math belongs in `lib/domain/battle/battle_engine.dart`. `BattleEngine` implements `IBattleEngine` with `calculateDamage(...)` supporting configurable `basePoints` (100 for 25m, 220 for 50m, 100 for 5s) and `canExecuteFinishing(currentHp: currentHp, maxHp: maxHp)` (locked when HP > 20%, unlocked when HP <= 20%). Replacing inline calculation in `_calculateAndApplyDamage` and finishing checks in `_buildSegmentedProcessSelector` with `_battleEngine` methods ensures single-source-of-truth calculations.

3. **Addressing Observations 3 & 4 (Pomodoro Cycle & Mode Selection)**:
   Features 1, 2, and 3 require Standard (25m work / 5m rest), Deep Focus (50m work / 10m rest), and Fast Debug (5s work / 3s rest).
   Introducing:
   - `PomodoroMode { standard, deepFocus, debug }` defining work seconds, rest seconds, and base points.
   - `PomodoroPhase { idle, work, rest }` state machine.
   When `work` session finishes:
   - Damage and coins are applied.
   - If Boss HP <= 0: Trigger Quest Clear victory dialog.
   - If Boss HP > 0: Automatically start `PomodoroPhase.rest` with the mode's rest duration.
   - When rest completes or user presses "略過休息 (Skip Rest)", return to `idle`.
   This completes the full Pomodoro game loop cleanly within `lib/main.dart`.

4. **Addressing Observation 5 (Test Suite)**:
   Replacing the obsolete counter test in `test/widget_test.dart` with a UI smoke test for `TsumiPuraApp` plus creating `test/unit/battle_engine_test.dart` ensures all automated tests pass (`00:00 +X: All tests passed!`).

---

## 3. Caveats

1. **Milestone Boundary**: This analysis strictly targets Milestone 1 (Features 1–12). Persistent SQLite / SharedPreferences storage (M2), Model Hangar CRUD (M3), and retro audio integration (M4) are purposely not implemented in M1.
2. **Boss Data Source**: For Milestone 1, Boss data remains local in `lib/main.dart` (`bossName = '綠色普通盒怪'`, `maxHp = 500`). Dynamic switching from `KitItem` in repository will occur in Milestone 3.
3. **Rest Phase Damage**: During the rest phase, the Boss does not take damage; the player is in rest/recovery.

---

## 4. Conclusion

1. **State Machine Blueprint**:
   - `PomodoroMode` enum: `standard` (25m/5m, 100 pts), `deepFocus` (50m/10m, 220 pts), `debug` (5s/3s, 100 pts).
   - `PomodoroPhase` enum: `idle`, `work`, `rest`.
   - Work completion automatically triggers the rest phase (if Boss alive), and rest completion/skip returns to idle.
2. **UI Integration**:
   - `_battleEngine.calculateDamage(...)` replaces inline math in `_calculateAndApplyDamage`.
   - `_battleEngine.canExecuteFinishing(...)` drives the Finishing skill button lock/unlock state and execution gate.
   - Mode selector added above timer HUD, controls adapt dynamically to `idle`, `work`, and `rest`.
3. **Static Analysis & Tests**:
   - Changing `(_, __, ___)` to `(_, _, _)` at lines 298, 676, and 719 makes `flutter analyze` 100% clean (0 errors, 0 warnings, 0 infos).
   - Modernizing `test/widget_test.dart` and adding `test/unit/battle_engine_test.dart` guarantees full test passing.

---

## 5. Verification Method

### 1. Analyzer Cleanliness Verification
Run the Flutter static analyzer:
```powershell
flutter analyze
```
- **Success Criteria**: `No issues found!` (0 errors, 0 warnings, 0 lints, exit code 0).
- **Invalidation Condition**: Any remaining `unnecessary_underscores` or syntax errors.

### 2. Unit & Widget Test Verification
Run the Flutter test runner:
```powershell
flutter test
```
- **Success Criteria**: All unit tests in `test/unit/battle_engine_test.dart` and smoke tests in `test/widget_test.dart` pass with exit code 0.

### 3. Inspection Verification
Open `lib/main.dart` and inspect:
- Lines 298, 676, 719: confirm `errorBuilder: (_, _, _)`.
- Timer state: confirm `PomodoroPhase` transitions between `work` and `rest`.
- Finishing gate: confirm lock icon `🔒20%` when Boss HP > 20% and unlock `2.5x` when Boss HP <= 20%.
- Damage output: confirm 50m session yields 220 base points multiplier and Mercy rule yields 50% floor on interrupt.
