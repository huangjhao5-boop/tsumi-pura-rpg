# HANDOFF — Explorer 1 (Milestone 3: Hangar Screen & CRUD)

**Author:** Explorer 1 (`teamwork_preview_explorer_m3_1`)  
**Parent:** `6fa20b7c-dc2d-40cc-9d90-84e64adeddcf`  
**Date:** 2026-09-11  
**Target Milestone:** Milestone 3 (Features 18–21)  

---

## 1. Observation
1. **Codebase Status**:
   - `flutter analyze` executed and exited with code `0` (0 errors, 0 warnings).
   - `flutter test` executed across all 11 test suites and passed with 137 tests passing (`All tests passed!`).
2. **Domain & Data Foundations**:
   - `lib/domain/models/kit_item.dart` lines 46–100 implement `KitItem` and `KitStatus` with full validation, normalization, and factory `KitItem.create(title: ..., grade: ..., totalHp: ...)` that auto-fills HP from `GameConstants.gradeHpDefaults`.
   - `lib/data/repositories/kit_repository.dart` lines 15–160 implement `IKitRepository` (`getAllKits`, `getActiveKit`, `saveKit`, `deleteKit`, `setActiveKit`). Line 121 confirms that `deleteKit` already performs cascade deletion of all associated `CraftLog` entries via `logRepo.deleteLogsForKit(kitId)`. Lines 133–140 handle auto-reassigning the next active kit upon active kit deletion, and line 129 re-seeds a default kit if all kits are deleted.
   - `lib/core/constants/game_constants.dart` lines 165–171 define `GameConstants.gradeHpDefaults`:
     ```dart
     static const Map<String, int> gradeHpDefaults = {
       'EG': 300,
       'HG': 500,
       'RG': 800,
       'MG': 1500,
       'PG': 5000,
     };
     ```
3. **UI Patterns**:
   - Inspected `lib/presentation/screens/craft_log_screen.dart` and `lib/main.dart`: established pixel art aesthetic using `#10121A` dark background, `#383A59` borders (3px), `#212234` headers, and arcade color accents (`#FFD54F`, `#8BE9FD`, `#50FA7B`, `#BD93F9`, `#FFB86C`, `#FF5252`).

---

## 2. Logic Chain
1. **Feature 18 (Model Hangar Screen)**:
   - Need a dedicated `HangarScreen` (`lib/presentation/screens/hangar_screen.dart`) that loads kits via `kitRepository.getAllKits()` and active kit via `kitRepository.getActiveKit()`.
   - Each kit card visually displays grade (`[EG]`, `[HG]`, `[RG]`, `[MG]`, `[PG]`), status (`[山積]`, `[施工中]`, `[完工]`), active kit badge (`★ 當前出擊目標`), custom boss tag (`[自訂]`), and an 8-bit dynamic HP bar.
   - Segmented filter controls allow filtering by `all`, `unstarted`, `in_progress`, or `completed`.
2. **Feature 19 (Kit CRUD Management)**:
   - **Create**: Tapping "+ 新增" opens `KitFormDialog` in create mode.
   - **Read**: Live list of kits refreshed after any mutation.
   - **Update**: Tapping "編輯" on any kit card opens `KitFormDialog` in edit mode with existing data pre-populated, permitting title, grade, total HP adjustments, and full-HP reset.
   - **Delete**: Tapping "刪除" triggers `DeleteConfirmDialog` with warning text regarding irreversible cascade log deletion. On confirmation, calls `kitRepository.deleteKit(kit.id)`.
3. **Feature 20 (Grade & HP Defaults)**:
   - Grade choices `['EG', 'HG', 'RG', 'MG', 'PG']` map directly to `GameConstants.gradeHpDefaults`.
   - Selecting a grade chip auto-populates the HP text input with the designated default value when not in custom HP mode.
4. **Feature 21 (Custom HP Input)**:
   - Checkbox / toggle "自訂 HP (Custom HP Override)" unlocks the HP input field for arbitrary positive integer input (`> 0`, `<= 99999`).
   - Marks `isCustomBoss: true` if overridden from default.
   - Full validation rejects empty title, title > 50 chars, empty HP, non-numeric HP, and HP <= 0.

---

## 3. Caveats
- **Navigation Integration**: Explorer 1 is scoped to `HangarScreen` and its internal CRUD dialogs. Wiring `HangarScreen` into the main application navigation header / bottom bar or route stack is owned by Explorer 3 (`teamwork_preview_explorer_m3_3`).
- **Showcase Integration**: Completed kits in the Hangar are displayed with `[完工]` badge; detailed showcase trophy cabinet inspection is handled by Explorer 2 (`teamwork_preview_explorer_m3_2`).
- **Device Orientation & Overflow**: For smaller screens, `HangarScreen` and `KitFormDialog` use `SingleChildScrollView` to prevent keyboard layout overflows.

---

## 4. Conclusion
The architecture and implementation blueprint for Features 18, 19, 20, and 21 are fully designed and documented in `analysis.md`.
The implementation can proceed with zero external dependencies, 100% adherence to existing Clean Architecture conventions, complete test coverage, and pixel-perfect aesthetic alignment with the rest of the game.

---

## 5. Verification Method
1. **Static Analysis**:
   ```powershell
   flutter analyze
   ```
   Must pass with 0 errors and 0 warnings.
2. **Widget Test Execution**:
   Create and execute `test/widget/hangar_screen_test.dart`:
   ```powershell
   flutter test test/widget/hangar_screen_test.dart
   ```
   Must verify:
   - Initial load & kit cards display
   - Active kit indicator styling
   - Status filtering (All / Backlog / In Progress / Completed)
   - "設為目標" setting active kit in repository
   - "+ 新增" with Grade auto-fill (EG: 300, HG: 500, RG: 800, MG: 1500, PG: 5000)
   - Custom HP toggle with validation (> 0, non-empty, <= 99999)
   - Kit editing (modifying title and HP)
   - Kit deletion with cascade confirmation
3. **Full Regression Suite**:
   ```powershell
   flutter test
   ```
   Must pass all existing and new tests.
