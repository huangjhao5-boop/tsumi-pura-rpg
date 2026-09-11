# Handoff Report — Milestone 1: Battle Engine Numerical Exactness, Edge Cases & Unit Testing Strategy

- **Agent**: Explorer 2 for Milestone 1 (`teamwork_preview_explorer`)
- **Working Directory**: `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m1_2`
- **Date**: 2026-09-11
- **Target Role / Recipient**: Parent Orchestrator (`6fa20b7c-dc2d-40cc-9d90-84e64adeddcf`) & Milestone 1 Worker

---

## 1. Observation

1. **Static Analysis Results**:
   Running `flutter analyze` produced the following verbatim output:
   ```
   Analyzing nifty-heisenberg...

      info - Unnecessary use of multiple underscores - lib\main.dart:298:37 - unnecessary_underscores
      info - Unnecessary use of multiple underscores - lib\main.dart:298:41 - unnecessary_underscores
      info - Unnecessary use of multiple underscores - lib\main.dart:676:39 - unnecessary_underscores
      info - Unnecessary use of multiple underscores - lib\main.dart:676:43 - unnecessary_underscores
      info - Unnecessary use of multiple underscores - lib\main.dart:719:39 - unnecessary_underscores
      info - Unnecessary use of multiple underscores - lib\main.dart:719:43 - unnecessary_underscores

   6 issues found. (ran in 31.7s)
   ```
   The issues are located in three widget builder callbacks in `lib/main.dart`:
   - Line 298: `errorBuilder: (_, __, ___) => const Icon(...)`
   - Line 676: `errorBuilder: (_, __, ___) => const Icon(...)`
   - Line 719: `errorBuilder: (_, __, ___) => const Icon(...)`

2. **Existing Test Status**:
   Running `flutter test` failed with exit code 1 due to `test/widget_test.dart:19:5`:
   ```
   ══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
   The following TestFailure was thrown running a test:
   Expected: exactly one matching candidate
     Actual: _TextWidgetFinder:<Found 0 widgets with text "0": []>
      Which: means none were found but one was expected
   ════════════════════════════════════════════════════════════════════════════════════════════════════
   00:02 +0 -1: Counter increments smoke test [E]
   ```
   This is because `test/widget_test.dart` is still the boilerplate template counter test.

3. **Current In-Widget Battle Logic**:
   `lib/main.dart:184-192` currently implements damage calculation inline:
   ```dart
   double basePoints = 100.0 * elapsedRatio;
   double multiplier = _phaseMultipliers[_selectedPhase] ?? 1.0;
   double totalDamage = basePoints * multiplier;

   if (isInterrupted) {
     totalDamage = totalDamage * 0.5; // Mercy Rule 50%
   }

   int finalDamage = totalDamage.round();
   ```
   - It hardcodes `basePoints = 100.0 * elapsedRatio`, failing to account for 50-minute deep focus mode (220 BP).
   - In `lib/main.dart:118`, the Finishing execution gate is checked before starting the timer:
     ```dart
     if (_selectedPhase == 'Finishing' && (currentHp / maxHp) > 0.2) {
       _showSnackAlert('⚠️ 水貼終結技限定 Boss 殘血 20% 以下發動！');
       return;
     }
     ```
   - No separate unit tests exist for battle formulas or damage math.

4. **Specification Requirements**:
   - `SPEC.md §2.1`: Standard 25m = 100 BP; Deep Focus 50m = 220 BP (+10% bonus); Fast Debug 5s = 100 BP.
   - `SPEC.md §2.2`: Snap-fit 1.0x, Sanding 1.2x, Detailing 1.5x, Airbrush 2.0x, Finishing 2.5x (locked when HP > 20%, unlocked when HP <= 20%).
   - `SPEC.md §2.3`: Mercy Rule formula:
     $$\text{中斷傷害} = \text{基礎點數} \times \left( \frac{\text{已進行秒數}}{\text{總秒數}} \right) \times \text{工序倍率} \times 50\%$$
   - `PROJECT.md:74-87`: Required interface contract:
     ```dart
     abstract class IBattleEngine {
       int calculateDamage({
         required int basePoints,
         required String phase,
         required int elapsedSeconds,
         required int totalSeconds,
         required bool isInterrupted,
         required int currentHp,
         required int maxHp,
       });

       bool canExecuteFinishing({required int currentHp, required int maxHp});
     }
     ```

---

## 2. Logic Chain

1. **Decoupling Rationale**:
   - Observations 3 & 4 show that damage calculation is coupled inside `_BattleAtelierScreenState` in `lib/main.dart` with hardcoded 100 BP and UI dependencies.
   - Decoupling this into pure Dart `lib/domain/battle/battle_engine.dart` and `lib/core/constants/game_constants.dart` fulfills Feature 11, eliminates Flutter test dependencies for math tests, and enables milliseconds-fast unit test execution.

2. **Mercy Rule & Rounding Derivation**:
   - Observation 4 defines $\text{Damage} = \text{round}(BP \times (t_{\text{elapsed}} / t_{\text{total}}) \times M \times 0.50)$.
   - Dart's `num.round()` implements half-up rounding away from zero. For example:
     - 25m Detailing interrupted at 50% ($750$s): $100 \times 0.5 \times 1.5 \times 0.5 = 37.5 \rightarrow 38$.
     - 25m Finishing interrupted at 50% ($750$s): $100 \times 0.5 \times 2.5 \times 0.5 = 62.5 \rightarrow 63$.
     - 50m Detailing interrupted at 50% ($1500$s): $220 \times 0.5 \times 1.5 \times 0.5 = 82.5 \rightarrow 83$.
     - 50m Finishing interrupted at 50% ($1500$s): $220 \times 0.5 \times 2.5 \times 0.5 = 137.5 \rightarrow 138$.
   - Any engine implementation must strictly follow `rawDamage.round()` and guarantee non-negative return values (`max(0, finalDamage)`).

3. **Finishing Gate Logic & Safety**:
   - Observation 4 states Finishing is locked when HP > 20% and unlocked when HP <= 20%.
   - In `canExecuteFinishing`: `(currentHp / maxHp) <= 0.2000001` with guard `if (maxHp <= 0) return false;`.
   - In `calculateDamage`: If `phase == 'Finishing'` and `!canExecuteFinishing(currentHp: currentHp, maxHp: maxHp)`, the engine returns `0` damage. This prevents illegitimate damage execution even if the caller bypasses UI restrictions.

4. **Defensive Edge Cases**:
   - If `totalSeconds <= 0`: Division by zero in `elapsedSeconds / totalSeconds` yields `Infinity` or `NaN`. In Dart, calling `.round()` on `NaN`/`Infinity` throws an `UnsupportedError`. Thus, `totalSeconds <= 0` must return `0` immediately.
   - If `elapsedSeconds <= 0`: Aborting with 0 seconds elapsed must return `0` damage to prevent exploitation.
   - If `elapsedSeconds > totalSeconds`: Clamping `elapsedSeconds.clamp(0, totalSeconds)` prevents timer drift from overshooting 100% damage.

5. **Lint Elimination**:
   - Observation 1 identifies 6 `unnecessary_underscores` in `lib/main.dart` at lines 298, 676, 719.
   - Replacing `(_, __, ___)` with `(_, _, _)` in the three `errorBuilder` parameters directly removes all 6 lints without altering any widget behavior.

---

## 3. Caveats

1. **Coin Calculation Location**:
   - In the prototype, plastic coin calculation `(actualElapsedSeconds / 5).round().clamp(2, 50)` was performed in `_calculateAndApplyDamage`. The `IBattleEngine` contract only defines `calculateDamage` and `canExecuteFinishing`. We recommend providing `int calculateCoins(int elapsedSeconds)` as a utility method on `BattleEngine` so the Worker can use it cleanly.
2. **Widget Test Scope**:
   - `test/widget_test.dart` currently fails due to the default counter test. The Worker must replace it with a valid app smoke test (e.g. verifying `TsumiPuraApp` launches and displays the battle title) alongside creating `test/unit/battle_engine_test.dart`.
3. **Talents Extension**:
   - `SPEC.md §2.3` mentions craftsman talents (Lv.1 50%, Lv.5 70%, Lv.10 90%). Milestone 1 specifies standard 50% floor. The engine parameterizes `mercyRuleFactor: 0.50` so future talent scaling can be cleanly passed or modified.

---

## 4. Conclusion

1. Decoupling `BattleEngine` into `lib/domain/battle/battle_engine.dart` and `lib/core/constants/game_constants.dart` provides clean pure-Dart testability and exact mathematical compliance with SPEC §2.1–2.3 and PROJECT Features 1–12.
2. The exact numerical multipliers are: Snap-fit (1.0x), Sanding (1.2x), Detailing (1.5x), Airbrush (2.0x), Finishing (2.5x).
3. The Mercy Rule correctly handles half-up integer rounding (e.g. 37.5 -> 38, 62.5 -> 63) and guards against zero/negative elapsed time and division-by-zero.
4. The Finishing Gate correctly unlocks at <=20% HP (e.g., 100/500 HP is unlocked, 101/500 HP is locked) and returns 0 damage if executed while locked.
5. Replacing `(_, __, ___)` with `(_, _, _)` at lines 298, 676, 719 of `lib/main.dart` completely resolves all 6 static analyzer issues.

---

## 5. Verification Method

To verify these findings and the subsequent Worker implementation:

1. **Static Analysis**:
   Run:
   ```powershell
   flutter analyze
   ```
   **Expected Result**: `No issues found!` (0 errors, 0 warnings).

2. **Unit Test Execution**:
   Run:
   ```powershell
   flutter test test/unit/battle_engine_test.dart
   ```
   **Expected Result**: All tests pass (covering 25m/50m/5s completion damage, Mercy Rule floor, rounding boundaries, finishing gate boundaries, and zero-guard edge cases).

3. **Full Project Test Suite**:
   Run:
   ```powershell
   flutter test
   ```
   **Expected Result**: All test suites pass cleanly with zero failures.

4. **Invalidation Conditions**:
   - If `calculateDamage` throws an exception on `totalSeconds: 0` instead of returning 0.
   - If `canExecuteFinishing` returns true when Boss HP is > 20% (e.g. 101/500).
   - If `flutter analyze` reports any issues after updating `lib/main.dart`.
