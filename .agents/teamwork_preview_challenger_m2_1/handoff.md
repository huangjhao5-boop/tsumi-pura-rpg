# Adversarial Challenge Handoff Report: Milestone 2 — Storage Stress & Data Integrity

- **Author**: teamwork_preview_challenger (Challenger 1 for Milestone 2)
- **Target Roles**: Orchestrator (parent), teamwork_preview_worker, teamwork_preview_auditor
- **Working Directory**: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_challenger_m2_1
- **Milestone Under Test**: Milestone 2: Local Persistence & CraftLog (Features 13–17)
- **Timestamp**: 2026-09-11T05:43:00Z
- **Verdict**: **REQUEST_CHANGES**

---

## 1. Observation

A dedicated empirical stress harness was created and executed in `test/challenge/storage_stress_challenge_test.dart` (18 adversarial challenge test cases across 5 core categories). All observations below are backed by direct empirical test execution:

### 1.1 Critical Vulnerability: Concurrent Async Writes Cause Silent Data Loss
- **Exact Locations**:
  - `lib/data/repositories/craft_log_repository.dart` (lines 49–57)
  - `lib/data/repositories/kit_repository.dart` (lines 90–102)
- **Observed Behavior**:
  In `test/challenge/storage_stress_challenge_test.dart` (tests 2.1 & 2.2), launching parallel write operations via `Future.wait`:
  ```dart
  final futures = List.generate(5, (i) => logRepo.addLog(...));
  await Future.wait(futures);
  ```
  **Tool Output**:
  ```
  Empirical check: 2 logs survived concurrent write out of 6
  Empirical check: 2 kits in repository after 4 concurrent saves + 1 seed
  ```
  **4 out of 6 logs were permanently lost, and 3 out of 5 kits were permanently lost.**
  The repository implementation performs an un-synchronized read-modify-write:
  ```dart
  final logs = (await getAllLogs()).toList();
  logs.insert(0, log);
  _cachedLogs = logs;
  await _storage.setJsonList(StorageKeys.craftLogs, mapList);
  ```
  Every concurrent call captures the identical pre-write snapshot and overwrites sibling writes.

### 1.2 Logic Defect: `KitStatus.isValid` Normalization Flaw
- **Exact Location**: `lib/domain/models/kit_item.dart` (lines 20–33)
- **Observed Code**:
  ```dart
  static String normalize(String? status) {
    if (status == null) return unstarted;
    final lower = status.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (lower == 'completed') return completed;
    if (lower == 'in_progress' || lower == 'inprogress') return inProgress;
    if (lower == 'backlog' || lower == 'unstarted') return unstarted;
    return unstarted; // <-- Maps ALL unknown strings to unstarted
  }

  static bool isValid(String? status) {
    if (status == null) return false;
    final norm = normalize(status);
    return values.contains(norm); // <-- Always true because normalize returns unstarted!
  }
  ```
- **Observed Behavior**:
  In `test/challenge/storage_stress_challenge_test.dart` (test 1.3):
  ```dart
  KitStatus.isValid('TOTALLY_BOGUS_STATUS_12345') // Returns true!
  ```
  Consequently, `KitItem.validate()` (line 251: `if (!KitStatus.isValid(status)) errors.add(...)`) **can never fail** on any non-null string. A corrupted or injected status value will pass validation unchecked.

### 1.3 Architectural Gap: Decoupled Cascade Deletion Leaves Orphan Logs
- **Exact Locations**:
  - `SPEC.md` §7: `FOREIGN KEY (kitId) REFERENCES KitItem(id) ON DELETE CASCADE`
  - `lib/data/repositories/kit_repository.dart` (lines 105–125)
  - `lib/data/repositories/craft_log_repository.dart` (lines 59–67)
- **Observed Behavior**:
  In `test/challenge/storage_stress_challenge_test.dart` (test 3.2):
  Deleting a kit via `await kitRepo.deleteKit('orphan-test-kit')` removes the kit from `StorageKeys.kits`, but does not invoke deletion on `StorageKeys.craftLogs`.
  `craftLogRepo.getLogsForKit('orphan-test-kit')` still returned 1 log. Orphan craft logs remain indefinitely in local storage and contaminate aggregate metrics when viewing global logs in `CraftLogScreen`.

### 1.4 Inconsistent Default Seed Kit IDs and Metadata
- **Exact Locations**:
  - `lib/domain/models/kit_item.dart` (line 95): `id: 'default-hg-mimic-001'`, `grade: 'HG'`
  - `lib/data/repositories/kit_repository.dart` (line 24): `id: 'default-box-mimic-hg-001'`, `grade: 'HG'`
  - `lib/main.dart` (line 71): `id: 'default_hg_green_mimic'`, `grade: 'HG 1/144'`
- **Observed Behavior**:
  Three different IDs and conflicting grade strings are defined across the app. If a work session concludes or auto-saves before asynchronous hydration completes, a second default kit with ID `default_hg_green_mimic` is persisted into storage alongside `default-box-mimic-hg-001`.

### 1.5 Positive Empirical Observations
- **Storage Corruption Resilience**: `LocalStorageService` safely catches `FormatException` on corrupted JSON strings and non-list JSON types, returning `<Map<String, dynamic>>[]` without throwing or crashing.
- **Defensive Model Parsing**: `KitItem.fromMap` and `CraftLog.fromMap` handle missing fields, string-encoded numbers, and invalid date formats gracefully.
- **Duration Floor**: Short debug sessions (e.g. 5s) correctly record `1` minute in craft log statistics per Feature 3 requirements.
- **UI Stress**: `CraftLogScreen` renders smoothly with 0 logs (empty state) and 500 logs without layout overflow or memory exceptions.
- **Analyzer & Suite Cleanliness**: `flutter analyze` reports 0 errors and 0 warnings; all 123 automated tests pass.

---

## 2. Logic Chain

1. **Premise 1 (Data Integrity Requirement)**:
   Per `ORIGINAL_REQUEST.md §R2` and `SPEC.md §7`, the local persistence layer must safeguard player progress and session history across reloads.
2. **Observation to Deduction 1 (Concurrent Update Hazard)**:
   In Dart's asynchronous model, any function performing `await read()` followed by `await write()` yields execution back to the event loop. When concurrent calls are triggered without an asynchronous queue or mutex, each call operates on stale state, directly causing 66% data loss in our empirical test (`test 2.1` & `test 2.2`). This is a critical data loss bug for a persistence engine.
3. **Observation to Deduction 2 (Validation Bypass)**:
   Because `KitStatus.isValid` routes through `normalize()`, which unconditionally returns `'unstarted'` for any unrecognized string, `isValid()` evaluates to `true` for all non-null strings. Domain invariants cannot be enforced.
4. **Observation to Deduction 3 (Cascade Deletion Contract)**:
   `SPEC.md §7` explicitly mandates `ON DELETE CASCADE`. Because `KitRepository` operates without awareness of `CraftLogRepository`, deleting a kit leaves orphan logs in `StorageKeys.craftLogs`. In Milestone 3 (Hangar CRUD), deleting kits will pollute the user's CraftLog statistics with phantom data.
5. **Observation to Deduction 4 (Seed ID Drift)**:
   Having three distinct IDs for the default kit creates split-brain state between the first-frame UI fallback and the persisted database seed.

---

## 3. Caveats

- **No Caveats**: All 5 tasks outlined in `DISPATCH.md` were empirically tested using reproducible automated test code in `test/challenge/storage_stress_challenge_test.dart`.
- In standard single-user sequential GUI usage, concurrent writes are rare, but can occur during rapid Pomodoro stop/start cycles, background timer expiration, or multi-screen navigation.

---

## 4. Conclusion & Required Changes

**Verdict**: **REQUEST_CHANGES**

Before Milestone 2 is approved and Milestone 3 begins, the following 4 actionable fixes must be addressed:

1. **[Critical] Synchronize Repository Writes**:
   Introduce a mutex lock or sequential future queue (e.g. `Future<void> _writeLock`) in `KitRepository.saveKit` / `deleteKit` and `CraftLogRepository.addLog` / `deleteLogsForKit` to guarantee atomic read-modify-write execution and prevent data loss under concurrent calls.
2. **[Medium] Fix `KitStatus.isValid` Validation**:
   Rewrite `KitStatus.isValid(String? status)` to verify whether `status` (case-insensitive and trimmed) directly matches known valid values (`unstarted`, `in_progress`, `completed`, `backlog`), without falling back to `unstarted`.
3. **[Medium] Wire Cascade Deletion on Kit Delete**:
   Ensure that deleting a kit removes all associated logs in `StorageKeys.craftLogs` (either by having `KitRepository.deleteKit` clear them from storage or through an orchestrating service) to satisfy `SPEC.md §7 ON DELETE CASCADE`.
4. **[Low] Consolidate Default Seed Kit ID**:
   Establish a single source of truth for the default kit ID (e.g. `GameConstants.defaultKitId` or `KitItem.initialSeedKit()`) and use it consistently across `KitItem`, `KitRepository`, and `BattleAtelierScreen`.

---

## 5. Verification Method

To independently reproduce and verify all challenge findings:

```bash
# 1. Run the storage stress challenge test suite (displays empirical concurrent write metrics)
flutter test test/challenge/storage_stress_challenge_test.dart

# 2. Run the full project test suite (123 tests passing)
flutter test

# 3. Verify static analysis has 0 issues
flutter analyze
```