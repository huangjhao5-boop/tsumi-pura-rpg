# Handoff Report: Cascade Deletion Architecture (Milestone 2 Retry)

- **Author**: teamwork_preview_explorer (Explorer 3 for Milestone 2 Retry)
- **Target Roles**: Orchestrator (parent), teamwork_preview_worker, teamwork_preview_auditor, Challenger 2
- **Working Directory**: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m2_retry_3
- **Milestone Under Analysis**: Milestone 2: Local Persistence & CraftLog (Retry Iteration 2)
- **Timestamp**: 2026-09-11T05:54:00Z
- **Type**: Hard (Task complete)

---

## 1. Observation

1. **`SPEC.md` §7 Foreign Key Specification**:
   Lines 161–170 of `SPEC.md`:
   ```sql
   CREATE TABLE CraftLog (
       id TEXT PRIMARY KEY,
       kitId TEXT NOT NULL,
       phase TEXT NOT NULL,
       durationMinutes INTEGER NOT NULL,
       damageDealt INTEGER NOT NULL,
       isCompletedSession INTEGER NOT NULL,
       createdAt TEXT NOT NULL,
       FOREIGN KEY (kitId) REFERENCES KitItem(id) ON DELETE CASCADE
   );
   ```
2. **Current `KitRepository.deleteKit` Implementation**:
   In `lib/data/repositories/kit_repository.dart` (lines 104–125):
   ```dart
   @override
   Future<void> deleteKit(String kitId) async {
     final kits = (await getAllKits()).toList();
     kits.removeWhere((k) => k.id == kitId);
     ...
     _cachedKits = kits;
     await _persistKits(kits);
   }
   ```
   `deleteKit` only modifies `_cachedKits` and `StorageKeys.kits`. It has zero interaction with `StorageKeys.craftLogs` or `CraftLogRepository`.
3. **Existing `CraftLogRepository.deleteLogsForKit` Implementation**:
   In `lib/data/repositories/craft_log_repository.dart` (lines 59–67):
   ```dart
   @override
   Future<void> deleteLogsForKit(String kitId) async {
     final logs = (await getAllLogs()).toList();
     logs.removeWhere((l) => l.kitId == kitId);
     _cachedLogs = logs;

     final mapList = logs.map((l) => l.toMap()).toList();
     await _storage.setJsonList(StorageKeys.craftLogs, mapList);
   }
   ```
   The child deletion logic is already implemented and tested in `CraftLogRepository`, but remains uncalled when deleting a kit.
4. **Empirical Defect Confirmation in Challenger 1 Handoff**:
   In `test/challenge/storage_stress_challenge_test.dart` (lines 446–455):
   ```dart
   await kitRepo.deleteKit('orphan-test-kit');
   ...
   final remainingLogs = await logRepo.getLogsForKit('orphan-test-kit');
   expect(remainingLogs.length, equals(1));
   ```
   Challenger 1 confirmed that deleting a kit leaves orphan logs in storage.
5. **In-Memory Cache Mechanism in `CraftLogRepository`**:
   In `lib/data/repositories/craft_log_repository.dart` (lines 20–24):
   ```dart
   @override
   Future<List<CraftLog>> getAllLogs() async {
     if (_cachedLogs != null) {
       return List.unmodifiable(_cachedLogs!);
     }
     ...
   ```
   If storage is mutated directly without going through the active `CraftLogRepository` instance, `_cachedLogs` retains phantom logs indefinitely.

---

## 2. Logic Chain

1. **Premise 1 (SPEC §7 Mandate)**:
   Per `SPEC.md §7` (Observation 1), `CraftLog` has a foreign key constraint to `KitItem` with `ON DELETE CASCADE`. Removing a parent kit must guarantee that all associated craft logs are removed.
2. **Observation to Deduction 1 (Orphan Accumulation)**:
   Because `KitRepository.deleteKit` (Observation 2) does not delete child logs, deleting a kit leaves orphan logs on disk and in memory (Observation 4). In `CraftLogScreen`, users viewing historical sessions or aggregate time/point statistics will see phantom sessions referencing non-existent kits.
3. **Observation to Deduction 2 (Cache Invalidation Hazard)**:
   Because `CraftLogRepository` caches logs in `_cachedLogs` (Observation 5), directly deleting keys from `_storage` inside `KitRepository` will NOT update `_cachedLogs`. Any UI screen holding a reference to `CraftLogRepository` will continue rendering deleted logs. Therefore, cascade deletion must execute `deleteLogsForKit` on the active `CraftLogRepository` instance.
4. **Observation to Deduction 3 (Concurrency & Deadlock Safety)**:
   Explorer 1 is adding an asynchronous mutex write lock (`Future<void> _writeLock`) to both repositories. The call direction during cascade deletion is strictly `KitRepository` $\to$ `CraftLogRepository`. Because `CraftLogRepository` never calls `KitRepository`, the dependency graph is an acyclic directed graph (DAG). Deadlocks are mathematically impossible, and all log operations remain strictly serialized.
5. **Observation to Deduction 4 (Transactional Ordering)**:
   Deleting child logs before mutating the parent kit ensures that if storage IO fails during child log deletion, the parent kit remains intact and retriable. It prevents partial-failure states where the parent is deleted but children remain as unreferenced orphans.
6. **Deduction 5 (Optimal Architectural Pattern)**:
   Injecting `ICraftLogRepository?` into `KitRepository` with an automatic fallback (`CraftLogRepository(_storage)`) guarantees that:
   - Any call to `IKitRepository.deleteKit` automatically cascades (SPEC §7 invariant enforced).
   - In-memory cache and storage are both kept 100% coherent.
   - The `IKitRepository` interface from `PROJECT.md` remains intact with 0 breaking changes.
   - Existing unit tests that instantiate `KitRepository(storage)` continue to pass and gain storage-level cascade deletion for free.

---

## 3. Caveats

- **No Unexplored Areas**: The interaction between repositories, in-memory caches, mutex write locks, and UI screens has been exhaustively analyzed.
- **Assumptions**: We assume `CraftLogRepository` remains the single authority for managing `StorageKeys.craftLogs`.
- **Alternative Considered & Rejected**: A standalone `KitManagementService` (Option 2) was evaluated and rejected as the primary solution because it leaves `IKitRepository.deleteKit` un-cascaded. Callers in Milestone 3 (Hangar CRUD) could accidentally call `kitRepo.deleteKit` directly, immediately reintroducing orphan logs.

---

## 4. Conclusion

1. **Adopt Repository-Level Cascade with Optional Injection & Automatic Fallback**:
   Update `KitRepository` to accept `ICraftLogRepository? craftLogRepository` in its constructor (plus `bindCraftLogRepository` for late-binding).
2. **Execute Child Deletion Prior to Parent Deletion**:
   In `KitRepository.deleteKit(String kitId)`:
   ```dart
   final logRepo = _craftLogRepository ?? CraftLogRepository(_storage);
   await logRepo.deleteLogsForKit(kitId);
   ```
3. **Wire in `main.dart`**:
   In `BattleAtelierScreenState.initState`:
   ```dart
   _craftLogRepo = widget.craftLogRepository ?? CraftLogRepository();
   _kitRepo = widget.kitRepository ?? KitRepository(null, _craftLogRepo);
   ```
4. **Add `clearCache()`**:
   Add `void clearCache()` to both `CraftLogRepository` and `KitRepository` for testing hygiene.
5. **Update Challenger Test 3.2**:
   Update `test/challenge/storage_stress_challenge_test.dart` Test 3.2 to assert that remaining logs are empty (`expect(remainingLogs, isEmpty)`).

Detailed code blueprints and 4 unit test designs are published in `analysis.md`.

---

## 5. Verification Method

Once Worker applies the blueprints from `analysis.md`:

1. **Verify Unit Tests (including new cascade tests)**:
   ```bash
   flutter test test/unit/storage_test.dart
   ```
2. **Verify Challenge Test Suite**:
   ```bash
   flutter test test/challenge/storage_stress_challenge_test.dart
   ```
3. **Verify Full Project Test Suite**:
   ```bash
   flutter test
   ```
4. **Verify Static Analysis**:
   ```bash
   flutter analyze
   ```
   Expected: 0 issues found.

**Invalidation Condition**:
If calling `kitRepo.deleteKit(kitId)` results in any entries remaining in `storage.getJsonList(StorageKeys.craftLogs)` with `l['kitId'] == kitId`, or if `logRepo.getLogsForKit(kitId)` returns non-empty list on the active repository instance, the implementation is invalid.
