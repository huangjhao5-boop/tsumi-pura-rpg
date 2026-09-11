# Handoff Report — Explorer 2 for Milestone 3: Showcase Gallery Screen

## 1. Observation

Direct observations from codebase inspection and local environment:
- **Kit Completion State**:
  In `lib/domain/models/kit_item.dart` lines 122–124:
  ```dart
  bool get isCompleted =>
      KitStatus.normalize(status) == KitStatus.completed || currentHp <= 0;
  ```
  `completedAt` is recorded at line 57 as `final DateTime? completedAt;`.
- **Craft Log Phases & Constants**:
  In `lib/core/constants/game_constants.dart` lines 13–19 & 148–154:
  ```dart
  static const List<String> all = [
    snapFit,
    sanding,
    detailing,
    airbrush,
    finishing,
  ];
  static const Map<String, String> phaseSkillNames = {
    CraftPhases.snapFit: '剪鉗連擊',
    CraftPhases.sanding: '破甲打磨',
    CraftPhases.detailing: '弱點刻線',
    CraftPhases.airbrush: '噴筆重砲',
    CraftPhases.finishing: '處決水貼',
  };
  ```
- **Repositories**:
  - `IKitRepository.getAllKits()` in `lib/data/repositories/kit_repository.dart:43`.
  - `ICraftLogRepository.getAllLogs()` in `lib/data/repositories/craft_log_repository.dart:27`.
  - `ICraftLogRepository.getLogsForKit(String kitId)` in `lib/data/repositories/craft_log_repository.dart:56`.
- **Mandated Empty State Copy**:
  Specified in `DISPATCH.md` line 13 and `ORIGINAL_REQUEST.md`:
  ```
  尚無完工模型，快去討伐堆積吧！
  ```
- **Existing Test Suite Baseline**:
  `flutter test` executed successfully with code 0:
  ```
  00:55 +137: All tests passed!
  ```

---

## 2. Logic Chain

1. **Kit Filtering (`getAllKits()`)**:
   - Observation: `KitItem.isCompleted` returns true whenever `status == 'completed'` or `currentHp <= 0`.
   - Logic: `ShowcaseScreen` loads all kits via `kitRepository.getAllKits()`, and applies `.where((k) => k.isCompleted).toList()`. Any unstarted or in-progress kits are strictly excluded from the Showcase.
2. **Shelf Chronological Ordering**:
   - Observation: `completedAt` records the timestamp when HP reached 0.
   - Logic: Completed kits are sorted descending by `k.completedAt ?? k.createdAt` so the player's most recent triumph sits at the top-left spotlight position.
3. **Empty State Handling**:
   - Observation: When the user starts a fresh save or has not completed any kits, `completedKits.isEmpty` is true.
   - Logic: The screen renders a centered retro 8-bit cabinet placeholder displaying `Key('showcase_empty_state')`, the verbatim copy `"尚無完工模型，快去討伐堆積吧！"`, explanatory subtitle, and a return action button.
4. **Single-Batch High-Performance Metric Aggregation**:
   - Observation: Querying `getLogsForKit()` individually inside item builders creates an asynchronous N+1 query pattern.
   - Logic: `_loadShowcaseData()` queries `craftLogRepository.getAllLogs()` once, then buckets them in memory:
     `Map<String, List<CraftLog>> logsByKit = {}`.
5. **KPI Metrics Formulation (Feature 25)**:
   - Observation: `durationMinutes` and `damageDealt` are stored on each `CraftLog`.
   - Logic:
     - Total craft time: `totalMinutes = logs.fold(0, (sum, l) => sum + l.durationMinutes)`. Formatted as `${hours}h ${mins}m` (or `${mins}m` if `< 60`).
     - Session count: `logs.length` with completed vs interrupted breakdown.
     - Completion date formatted as `YYYY-MM-DD` (e.g. `2026-09-11`).
6. **5-Phase Breakdown Modal (SPEC §5.1)**:
   - Observation: SPEC §5.1 requires an identity plaque and phase breakdown chart.
   - Logic: Tapping a card launches a retro dialog (`Key('showcase_detail_dialog')`) detailing the 5 canonical phases (Snap-fit, Sanding, Detailing, Airbrush, Finishing) with duration, damage, percentage, and colored progress bars (`#4CAF50`, `#FFB300`, `#8BE9FD`, `#BD93F9`, `#FF5252`).
7. **Cross-Screen Link to CraftLog**:
   - Observation: Users inspecting a completed model often wish to inspect individual session entries.
   - Logic: The detail modal contains an action button (`Key('btn_showcase_view_logs_${kit.id}')`) that pushes `CraftLogScreen` initialized with `activeKitId: kit.id` and `activeKitTitle: kit.title`.

---

## 3. Caveats

1. **Nullable `completedAt`**:
   - Legacy or seeded kits may have a null `completedAt`.
   - Handled defensively by falling back to `kit.createdAt`, ensuring no null pointer exceptions or empty date displays.
2. **Zero-Minute / Zero-Damage Sessions**:
   - If a user completes a kit in rapid debug mode (e.g., 5-second sessions resulting in 0 or 1 minute logs), percentages `(mins / totalMins)` must guard against division by zero via `totalMins > 0 ? (mins / totalMins) : 0.0`.
3. **Platform Image Rendering**:
   - Kit images use `assets/images/boss_green_box.jpg` with an `errorBuilder` fallback rendering `Icon(Icons.military_tech, color: Color(0xFFFFD54F))`, guaranteeing fault-tolerant rendering across Web and Desktop without broken asset crashes.

---

## 4. Conclusion

The specification, UI blueprint, and test architecture for **Milestone 3 Showcase Gallery Screen** (Features 24 & 25) are complete:
- **Target File**: `lib/presentation/screens/showcase_screen.dart`
  - Fully implements `ShowcaseScreen` with trophy cards, empty state, date formatting (`YYYY-MM-DD`), aggregated craft duration (`Xh Ym`), session count, and 5-phase breakdown modal.
  - Complete drop-in code blueprint is provided in `analysis.md` section 5.
- **Target Test File**: `test/widget/showcase_screen_test.dart`
  - Provides comprehensive automated widget test coverage for all empty state conditions, metrics computations, phase breakdowns, and navigation routes.

---

## 5. Verification Method

### Test Commands
1. **Run ShowcaseScreen widget test**:
   ```powershell
   flutter test test/widget/showcase_screen_test.dart
   ```
2. **Run full project test suite**:
   ```powershell
   flutter test
   ```
3. **Static analysis check**:
   ```powershell
   flutter analyze
   ```

### Files to Inspect
- `lib/presentation/screens/showcase_screen.dart`
- `test/widget/showcase_screen_test.dart`
- `.agents/teamwork_preview_explorer_m3_2/analysis.md`

### Invalidation Conditions
- Any `flutter test` failure or timeout.
- Any warning or lint failure from `flutter analyze`.
- Absence of verbatim empty state string: `"尚無完工模型，快去討伐堆積吧！"`.
- Non-completed kits appearing in Showcase.
- Division by zero during phase percentage calculations when total duration is 0.
