# Milestone 3 Review & Adversarial Challenge Report — Hangar Screen & CRUD

**Role**: teamwork_preview_reviewer (Reviewer 1 / Adversarial Critic)
**Verdict**: **APPROVE**
**Integrity Assessment**: **PASS** (Zero integrity violations, zero facades, zero hardcoded test outputs)

---

## 1. Observation

1. **Independent Static Analysis**:
   Executed command:
   ```powershell
   flutter analyze
   ```
   Verbatim output:
   ```
   Analyzing nifty-heisenberg...
   No issues found! (ran in 8.8s)
   ```
   Exit code: `0` (0 errors, 0 warnings, 0 lints).

2. **Independent Automated Test Suite**:
   Executed commands:
   ```powershell
   flutter test
   ```
   Verbatim output:
   ```
   00:51 +152: All tests passed!
   ```
   Executed dedicated hangar test suite:
   ```powershell
   flutter test test/widget/hangar_screen_test.dart
   ```
   Verbatim output:
   ```
   00:14 +7: All tests passed!
   ```
   Executed navigation and battle link test suite:
   ```powershell
   flutter test test/widget/showcase_screen_test.dart test/widget/navigation_and_active_kit_test.dart
   ```
   Verbatim output:
   ```
   00:10 +8: All tests passed!
   ```

3. **Codebase Inspection of `lib/presentation/screens/hangar_screen.dart`**:
   - **Backlog kit listing & Badges** (lines 367–613):
     - Renders kit card with grade badge (EG, HG, RG, MG, PG with dedicated colors), custom tag (`自訂` if `kit.isCustomBoss`), title with overflow ellipsis, status badge (`山積` / `施工中` / `完工`), HP ratio bar with dynamic colors (>50% green, >20% amber, <=20% red), and active indicator (`★ 當前出擊目標 (ACTIVE BOSS)` with star icon and gold glow).
     - Filter bar (lines 271–320): Chips for `全部`, `山積`, `施工中`, `完工` with real-time kit counts and filtering.
     - Empty state (lines 322–364): Displays `▶ 機庫空空如也` and `Key('btn_add_kit_empty')`.
   - **Add & Edit Kit Dialogs (`KitFormDialog`)** (lines 615–922):
     - Title input (`Key('input_kit_title')`): `maxLength: 50`, validated for non-empty (`請輸入模型名稱`) and max 50 chars (`名稱不可超過 50 字元`).
     - Grade presets: ChoiceChips (`Key('chip_grade_$g')`) for `EG (300)`, `HG (500)`, `RG (800)`, `MG (1500)`, `PG (5000)`. Selecting automatically populates HP when custom HP is disabled.
     - Custom HP toggle (`Key('checkbox_custom_hp')`): Unlocks numeric input (`Key('input_kit_hp')`), formatted with `digitsOnly`, validated for `> 0` integer (`HP 必須為大於 0 之整數`) and `<= 99999` (`HP 不可超過 99,999`).
     - Add option: `Key('checkbox_set_active')` immediately sets newly created kit as active target (default: true).
     - Edit option: `Key('checkbox_reset_hp')` ("重設當前血量為滿血"). If total HP is reduced below current HP, current HP safely clamps to the new total HP (line 707).
   - **Delete Confirmation Dialog (`DeleteConfirmDialog`)** (lines 924–1017):
     - Danger header `⚠️ 解體除籍確認 ⚠️`.
     - Cascade warning: `"※ 此操作將一併永久清除該模型的全部施工紀錄 (Craft Logs)，且無法復原！"`.
     - Active target reallocation notice: `"※ 此模型為當前出擊目標，刪除後將自動切換為下一盒模型。"`.
     - Confirm button (`Key('btn_confirm_delete')`) and Cancel button (`Key('btn_cancel_delete')`).
   - **Set Active Kit Action & Persistence Integration** (lines 72–95):
     - Calls `widget.kitRepository.setActiveKit(kit.id)` and shows SnackBar `已將【${kit.title}】設為當前討伐目標！`.
     - Calls `widget.onKitSelected?.call(kit)`.
     - In `main.dart` (lines 133–158), returning from Hangar triggers `_hydrateActiveKit(notifyTargetChange: true)`, synchronizing boss health, updating combat dialogues, and enforcing the Finishing execution gate: if HP > 20% on the newly activated kit, resets phase to Snap-fit.

4. **Codebase Inspection of `lib/data/repositories/kit_repository.dart`**:
   - Lines 120–123: Cascade deletion of associated craft logs is implemented via `await logRepo.deleteLogsForKit(kitId)`.
   - Lines 128–144: Active target reallocation when active kit is deleted: falls back to next non-completed kit or first kit, or automatically generates `createDefaultSeedKit()` if collection becomes empty.
   - Concurrency protection: `AsyncLock _lock` synchronizes write operations to prevent race conditions.

---

## 2. Logic Chain

1. **Requirement Verification**:
   - **Requirement 1 (Listing, Badges & Active Indicator)**: Directly observed in `hangar_screen.dart` lines 367–613 and verified by tests `Renders kit cards with grade, title, status, and active badge` and `Filter bar filters by status`. KitStatus normalization in `KitItem` correctly handles unstarted, in_progress, and completed states.
   - **Requirement 2 (Add & Edit Dialogs)**: Directly observed in `hangar_screen.dart` lines 615–922 and verified by tests `Add Kit dialog: Grade preset auto-fills HP, custom HP override, and validation` and `Edit Kit dialog updates title, grade, and HP`. Grade presets map 1:1 to `GameConstants.gradeHpDefaults` (EG: 300, HG: 500, RG: 800, MG: 1500, PG: 5000), custom HP validation strictly enforces positive integers <= 99,999, and title validation enforces 1–50 characters.
   - **Requirement 3 (Delete Confirmation & Reallocation)**: Directly observed in `hangar_screen.dart` lines 924–1017, `kit_repository.dart` lines 120–144, and verified by test `Delete Kit opens confirmation dialog with warning and deletes kit`. Cascade delete warning is prominent and actual log cascade deletion is executed in `KitRepository`. Active kit deletion safely reallocates to remaining kits or auto-seeds default kit.
   - **Requirement 4 (Set Active Kit & Persistence Integration)**: Directly observed in `hangar_screen.dart` lines 72–95, `main.dart` lines 133–158, and verified by `test/widget/navigation_and_active_kit_test.dart`. Active kit selection updates storage, syncs HUD, and guards against Finishing phase exploit.
   - **Requirement 5 (Zero Monetary Cost & Architecture Compliance)**: Storage relies purely on local `SharedPreferences` / JSON serialization. No paid APIs, no external cloud dependencies, fully offline-ready.

2. **Integrity Violation Analysis**:
   - Checked for dummy mocks, static bypasses, or hardcoded return values in `hangar_screen.dart` and `kit_repository.dart`. None exist.
   - Tests instantiate real repository implementations using mock SharedPreferences and verify persistent state changes across method calls.
   - The implementation is completely genuine and conforms to Clean Architecture.

---

## 3. Adversarial Challenges & Stress Tests

### Challenge 1: Finishing Phase Gate Bypass via Kit Switching
- **Assumption Challenged**: Player activates Finishing phase on a low HP Boss (<= 20%), then navigates to Hangar and switches to a fresh 100% HP Boss without resetting the selected phase.
- **Verification**: In `main.dart` `_hydrateActiveKit()` (lines 150–156):
  ```dart
  if (_selectedPhase == CraftPhases.finishing &&
      !_battleEngine.canExecuteFinishing(
        currentHp: currentHp,
        maxHp: maxHp,
      )) {
    _selectedPhase = CraftPhases.snapFit;
  }
  ```
  Verified by `navigation_and_active_kit_test.dart` line 168.
- **Result**: **PASS**. Exploit is completely mitigated; phase resets to Snap-fit automatically.

### Challenge 2: Total Deletion Empty Hangar State
- **Assumption Challenged**: User deletes all model kits in the hangar, causing `getAllKits()` or `getActiveKit()` to throw or leave the Battle screen in a null state.
- **Verification**: In `kit_repository.dart` lines 64–73 and lines 128–132: if kits collection becomes empty, `createDefaultSeedKit()` is immediately generated and persisted with active ID set.
- **Result**: **PASS**. App cannot be broken into an empty boss state.

### Challenge 3: Negative or Corrupted Custom HP Input
- **Assumption Challenged**: User enters `0`, `-50`, non-numeric characters, or extremely large values in custom HP input.
- **Verification**: `inputFormatters: [FilteringTextInputFormatter.digitsOnly]` prevents non-digit entry. Form validator explicitly rejects `parsed == null || parsed <= 0` and `parsed > 99999`.
- **Result**: **PASS**. Invalid inputs cannot be submitted.

---

## 4. Caveats

- **No caveats.** All 8 features under Milestone 3 (Features 18–25) and all 5 specific review requirements have been verified without discrepancy or degradation.

---

## 5. Conclusion

The implementation of `HangarScreen` (`lib/presentation/screens/hangar_screen.dart`), its integration in `lib/main.dart` and `lib/data/repositories/kit_repository.dart`, and the test coverage in `test/widget/hangar_screen_test.dart` and `test/widget/navigation_and_active_kit_test.dart` are **fully verified, correct, architecturally clean, and zero-cost**.

**Final Verdict**: **APPROVE**.

---

## 6. Verification Method

To reproduce and independently confirm:
1. Run static analysis:
   ```powershell
   flutter analyze
   ```
   Output: `No issues found! (ran in X.Xs)`
2. Run test suites:
   ```powershell
   flutter test test/widget/hangar_screen_test.dart
   flutter test
   ```
   Output: All 152 tests passed.
3. Inspect `lib/presentation/screens/hangar_screen.dart` and `test/widget/hangar_screen_test.dart`.
