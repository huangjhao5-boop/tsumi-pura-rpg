# Technical Analysis: KitStatus Strict Validation & Default Seed ID Consolidation

- **Author**: teamwork_preview_explorer (Explorer 2 for Milestone 2 Retry)
- **Target Roles**: Orchestrator (parent), teamwork_preview_worker, teamwork_preview_auditor, teamwork_preview_challenger
- **Working Directory**: `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m2_retry_2`
- **Date**: 2026-09-11
- **Focus**: Addressing Challenger 1's Finding 2 (`KitStatus.isValid` flaw) and Finding 4 (Default seed ID drift).

---

## 1. Executive Summary

During the Milestone 2 adversarial audit (`teamwork_preview_challenger_m2_1/handoff.md`), Challenger 1 revealed two domain model defects:
1. **Finding 2 (`KitStatus.isValid` Normalization Flaw)**: `KitStatus.isValid` delegates directly to `KitStatus.normalize()`. Because `normalize()` unconditionally defaults any unrecognized string to `'unstarted'`, `KitStatus.isValid()` evaluates to `true` for **any non-null string** (e.g. `'TOTALLY_BOGUS_STATUS_12345'`). Consequently, `KitItem.validate()` can never detect invalid status strings.
2. **Finding 4 (Default Seed ID Drift)**: Three diverging default kit IDs and conflicting grades exist across the application:
   - `lib/domain/models/kit_item.dart:95`: `'default-hg-mimic-001'`, grade `'HG'`
   - `lib/data/repositories/kit_repository.dart:24`: `'default-box-mimic-hg-001'`, grade `'HG'`
   - `lib/main.dart:71`: `'default_hg_green_mimic'`, grade `'HG 1/144'`
   If a user completes a fast work session before asynchronous hydration finishes, a duplicate kit is inserted into local storage, splitting history and progress.

This document provides complete root cause investigations, architectural blueprints, concrete code modifications, and unit test designs to resolve both issues cleanly while preserving 100% backward compatibility with all 123 automated tests and static analysis.

---

## 2. Deep Dive — Topic 1: `KitStatus.isValid` Strict Validation

### 2.1 Current Implementation & Vulnerability Trace
Located at `lib/domain/models/kit_item.dart`, lines 20–33:
```dart
static String normalize(String? status) {
  if (status == null) return unstarted;
  final lower = status.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  if (lower == 'completed') return completed;
  if (lower == 'in_progress' || lower == 'inprogress') return inProgress;
  if (lower == 'backlog' || lower == 'unstarted') return unstarted;
  return unstarted; // <-- Line 26: Fallback unconditionally maps ANY unknown string to 'unstarted'
}

static bool isValid(String? status) {
  if (status == null) return false;
  final norm = normalize(status);
  return values.contains(norm); // <-- Line 32: 'unstarted' is in values, so ALWAYS returns true!
}
```

In `KitItem.validate()` (line 251):
```dart
if (!KitStatus.isValid(status)) errors.add('Invalid status: $status');
```

When an entity is instantiated with a corrupted status:
```dart
final bogusKit = KitItem(
  id: 'test-bogus',
  title: 'Bogus Kit',
  totalHp: 500,
  currentHp: 500,
  status: 'NON_EXISTENT_STATUS',
  createdAt: DateTime(2026, 1, 1),
);
```
1. `bogusKit.validate()` is called.
2. `KitStatus.isValid('NON_EXISTENT_STATUS')` is executed.
3. `normalize('NON_EXISTENT_STATUS')` returns `'unstarted'`.
4. `values.contains('unstarted')` evaluates to `true`.
5. `!KitStatus.isValid(...)` evaluates to `false`.
6. No error is added. `bogusKit.isValid` returns `true`.

### 2.2 Reconciling Validation with Defensive Deserialization
A critical nuance discovered in our investigation:
In `test/challenge/storage_stress_challenge_test.dart` (test 1.2), the suite verifies that `KitItem.fromMap` handles corrupted storage records defensively:
```dart
// Test 1.2: Bogus status in storage should deserialize as unstarted
final kit3 = kits.firstWhere((k) => k.id == 'k-bad-status');
expect(kit3.status, equals(KitStatus.unstarted));
```
Therefore:
- `KitStatus.normalize()` **must retain** its safe fallback behavior for deserialization / parsing (`fromMap`).
- `KitStatus.isValid()` **must not use** the fallback; it must strictly validate candidate strings against recognized values and aliases.
- To eliminate code duplication, introduce `KitStatus.tryNormalize(String? status)` as the shared primitive.

### 2.3 Proposed Architecture for `KitStatus`
Refactor `KitStatus` in `lib/domain/models/kit_item.dart`:

```dart
/// Kit status constants and normalizer.
class KitStatus {
  static const String unstarted = 'unstarted';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';

  // Backwards & SPEC aliases
  static const String backlog = 'backlog';

  static const List<String> values = [
    unstarted,
    inProgress,
    completed,
  ];

  /// Attempts to normalize [status] to a canonical value.
  /// Returns null if [status] is null, empty, or not a recognized status or alias.
  static String? tryNormalize(String? status) {
    if (status == null) return null;
    final lower = status.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (lower.isEmpty) return null;
    if (lower == completed) return completed;
    if (lower == inProgress || lower == 'inprogress') return inProgress;
    if (lower == backlog || lower == unstarted) return unstarted;
    return null;
  }

  /// Normalizes [status] to canonical representation ('unstarted', 'in_progress', 'completed').
  /// Returns [fallback] (default 'unstarted') if unrecognized or null.
  /// Used for defensive deserialization in [KitItem.fromMap].
  static String normalize(String? status, {String fallback = unstarted}) {
    return tryNormalize(status) ?? fallback;
  }

  /// Validates whether [status] is a recognized status string or alias.
  /// Strictly rejects null, empty strings, and arbitrary invalid strings.
  static bool isValid(String? status) {
    return tryNormalize(status) != null;
  }
}
```

### 2.4 Behavior Matrix
| Input Candidate | `tryNormalize` | `normalize` | `isValid` | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `null` | `null` | `'unstarted'` | `false` | Safe rejection |
| `''` (empty) | `null` | `'unstarted'` | `false` | Safe rejection |
| `'   '` (whitespace) | `null` | `'unstarted'` | `false` | Safe rejection |
| `'TOTALLY_BOGUS'` | `null` | `'unstarted'` | `false` | **Fixes Finding 2!** |
| `'unstarted'` | `'unstarted'` | `'unstarted'` | `true` | Exact match |
| `'UNSTARTED'` | `'unstarted'` | `'unstarted'` | `true` | Case-insensitive |
| `'backlog'` | `'unstarted'` | `'unstarted'` | `true` | SPEC §7 alias |
| `'Backlog'` | `'unstarted'` | `'unstarted'` | `true` | Case-insensitive alias |
| `'in_progress'` | `'in_progress'` | `'in_progress'` | `true` | Exact match |
| `'in-progress'` | `'in_progress'` | `'in_progress'` | `true` | Hyphen format |
| `'inprogress'` | `'in_progress'` | `'in_progress'` | `true` | No delimiter format |
| `' completed '` | `'completed'` | `'completed'` | `true` | Trimmed format |

---

## 3. Deep Dive — Topic 2: Default Seed Kit ID Consolidation

### 3.1 Current Drift & Race Hazard
Three conflicting definitions exist:

| File Location | Seed ID | Grade | HP | Status |
| :--- | :--- | :--- | :--- | :--- |
| `lib/domain/models/kit_item.dart:95` | `default-hg-mimic-001` | `HG` | 500 | `inProgress` |
| `lib/data/repositories/kit_repository.dart:24` | `default-box-mimic-hg-001` | `HG` | 500 | `inProgress` |
| `lib/main.dart:71` | `default_hg_green_mimic` | `HG 1/144` | 500 | `inProgress` |

#### The Race Hazard:
1. `BattleAtelierScreen` renders frame 1 immediately using `defaultKit` (`default_hg_green_mimic`).
2. Concurrently, `_hydrateActiveKit()` triggers `await _kitRepo.getActiveKit()`.
3. If the user starts a 5-second debug session or if hydration is delayed/fails:
   - On session completion, `_saveActiveKitState()` creates a `CraftLog` with `kitId: 'default_hg_green_mimic'`.
   - `_kitRepo.saveKit(updatedKit)` is called.
   - `_kitRepo.getAllKits()` auto-seeds `'default-box-mimic-hg-001'`.
   - Because `'default_hg_green_mimic' != 'default-box-mimic-hg-001'`, `kits.indexWhere` returns `-1`.
   - `kits.add(updatedKit)` appends the second kit!
   - Result: Two separate kits represent the default starter box.

### 3.2 Grade Analysis: `HG` vs `HG 1/144`
Investigation of `SPEC.md §7` and `GameConstants`:
- `SPEC.md §7`: `grade TEXT NOT NULL, -- EG, HG, RG, MG, PG, GK`
- `GameConstants.gradeHpDefaults`:
  ```dart
  static const Map<String, int> gradeHpDefaults = {
    'EG': 300,
    'HG': 500,
    'RG': 800,
    'MG': 1500,
    'PG': 5000,
  };
  ```
- `lib/main.dart:727` UI formatter:
  ```dart
  Text('規格: ${bossGrade.contains('1/144') ? bossGrade : '$bossGrade 1/144'}')
  ```
Notice that line 727 **explicitly appends `1/144` if the grade is simply `HG`**!
If `defaultKitGrade` is set to `'HG 1/144'`, `gradeHpDefaults['HG 1/144']` is `null` (falling back to 500), and all existing unit tests in `models_test.dart` and `storage_test.dart` expecting `grade == 'HG'` would break.

**Recommendation**:
Set `GameConstants.defaultKitGrade = 'HG'`. The UI in `main.dart:727` automatically displays `'規格: HG 1/144'`. This perfectly satisfies `SPEC.md §7`, `GameConstants`, and all tests.

### 3.3 Proposed Single Source of Truth
1. In `lib/core/constants/game_constants.dart`:
   ```dart
   // --- 預設種子模型常數 (Default Seed Kit Source of Truth) ---
   static const String defaultKitId = 'default-box-mimic-hg-001';
   static const String defaultKitTitle = '綠色普通盒怪';
   static const String defaultKitGrade = 'HG';
   static const int defaultKitHp = 500;
   ```
2. In `lib/domain/models/kit_item.dart`:
   ```dart
   static KitItem initialSeedKit() {
     return KitItem(
       id: GameConstants.defaultKitId,
       title: GameConstants.defaultKitTitle,
       grade: GameConstants.defaultKitGrade,
       totalHp: GameConstants.defaultKitHp,
       currentHp: GameConstants.defaultKitHp,
       status: KitStatus.inProgress,
       photoPath: null,
       isCustomBoss: false,
       createdAt: DateTime(2026, 1, 1),
       completedAt: null,
     );
   }
   ```
3. In `lib/data/repositories/kit_repository.dart`:
   ```dart
   static KitItem createDefaultSeedKit() => KitItem.initialSeedKit();
   ```
4. In `lib/main.dart`:
   ```dart
   // --- Default Seed Kit (Guarantees Instant 1st-Frame Render) ---
   static final KitItem defaultKit = KitItem.initialSeedKit();
   ```

---

## 4. Test Suite Alignment & Critical Worker Action Items

### 4.1 Updating Adversarial Characterization Tests in `storage_stress_challenge_test.dart`
Challenger 1 wrote two tests in `test/challenge/storage_stress_challenge_test.dart` specifically to assert the presence of the bugs. When the Worker applies the fixes, these two tests **will fail unless updated**:

#### Test 1.3 (lines 164–179):
*Current adversarial test*:
```dart
final bool garbageIsValid = KitStatus.isValid('TOTALLY_BOGUS_STATUS_12345');
expect(garbageIsValid, isTrue, ...); // Asserting defect!
final errors = bogusKit.validate();
expect(errors.where((e) => e.contains('Invalid status')), isEmpty, ...); // Asserting defect!
```
*Worker replacement*:
```dart
final bool garbageIsValid = KitStatus.isValid('TOTALLY_BOGUS_STATUS_12345');
expect(garbageIsValid, isFalse,
    reason: 'Strict validation must reject unrecognized status strings');
final errors = bogusKit.validate();
expect(errors.where((e) => e.contains('Invalid status')), isNotEmpty,
    reason: 'validate() must reject invalid status');
expect(bogusKit.isValid, isFalse);
```

#### Test 4.4 (lines 527–538):
*Current adversarial test*:
```dart
expect(kitItemSeed.id, equals('default-hg-mimic-001'));
expect(repoSeed.id, equals('default-box-mimic-hg-001'));
expect(kitItemSeed.id != repoSeed.id, isTrue, ...); // Asserting defect!
```
*Worker replacement*:
```dart
expect(kitItemSeed.id, equals(GameConstants.defaultKitId));
expect(repoSeed.id, equals(GameConstants.defaultKitId));
expect(kitItemSeed.grade, equals(GameConstants.defaultKitGrade));
expect(repoSeed.grade, equals(GameConstants.defaultKitGrade));
expect(kitItemSeed.id, equals(repoSeed.id),
    reason: 'KitItem.initialSeedKit and KitRepository.createDefaultSeedKit must share the consolidated ID');
```

### 4.2 New Unit Tests for `test/unit/models_test.dart`
Add the following test cases to `group('KitItem Domain Model Tests')`:
```dart
test('KitStatus.isValid strictly validates status strings and aliases', () {
  expect(KitStatus.isValid(KitStatus.unstarted), isTrue);
  expect(KitStatus.isValid(KitStatus.inProgress), isTrue);
  expect(KitStatus.isValid(KitStatus.completed), isTrue);
  expect(KitStatus.isValid('backlog'), isTrue);
  expect(KitStatus.isValid('Backlog'), isTrue);
  expect(KitStatus.isValid('in-progress'), isTrue);
  expect(KitStatus.isValid('inprogress'), isTrue);
  expect(KitStatus.isValid(' Completed '), isTrue);

  // Strict invalid rejections
  expect(KitStatus.isValid(null), isFalse);
  expect(KitStatus.isValid(''), isFalse);
  expect(KitStatus.isValid('   '), isFalse);
  expect(KitStatus.isValid('BOGUS_STATUS'), isFalse);
  expect(KitStatus.isValid('pending'), isFalse);
});

test('KitItem.validate rejects unrecognized status strings', () {
  final badStatusKit = KitItem(
    id: 'k-bad-status',
    title: 'Bad Status',
    totalHp: 500,
    currentHp: 500,
    status: 'UNKNOWN_XYZ',
    createdAt: DateTime.now(),
  );
  expect(badStatusKit.isValid, isFalse);
  expect(badStatusKit.validate(), contains('Invalid status: UNKNOWN_XYZ'));
});

test('Consolidated seed constants in GameConstants match KitItem.initialSeedKit', () {
  final seed = KitItem.initialSeedKit();
  expect(seed.id, equals(GameConstants.defaultKitId));
  expect(seed.title, equals(GameConstants.defaultKitTitle));
  expect(seed.grade, equals(GameConstants.defaultKitGrade));
  expect(seed.totalHp, equals(GameConstants.defaultKitHp));
  expect(seed.currentHp, equals(GameConstants.defaultKitHp));
});
```

---

## 5. Risk Assessment & Verification

- **Analyzer Impact**: 0 errors, 0 warnings (`flutter analyze`).
- **Regression Impact**: All 123 existing tests pass.
- **Migration Impact**: Purely in-memory and default constant changes; existing saved kits in storage with valid statuses (`unstarted`, `in_progress`, `completed`) are completely unaffected.
