# Architectural Analysis: Cascade Deletion Architecture (SPEC §7 Compliance)

- **Agent**: teamwork_preview_explorer (Explorer 3 for Milestone 2 Retry)
- **Target Roles**: teamwork_preview_worker, Orchestrator, teamwork_preview_auditor, Challenger 2
- **Focus**: Resolving Challenger 1 Finding 1.3 (`SPEC.md §7 ON DELETE CASCADE` gap when deleting a kit)
- **Timestamp**: 2026-09-11T05:52:00Z

---

## 1. Executive Summary

In Milestone 2 (Retry Iteration 2), Challenger 1 identified an architectural defect (`Finding 1.3`): deleting a kit via `IKitRepository.deleteKit(kitId)` removes the kit record from `StorageKeys.kits`, but leaves all associated craft log records permanently stranded in `StorageKeys.craftLogs`. 

This directly violates **`SPEC.md §7`**:
```sql
CREATE TABLE CraftLog (
    id TEXT PRIMARY KEY,
    kitId TEXT NOT NULL,
    ...
    FOREIGN KEY (kitId) REFERENCES KitItem(id) ON DELETE CASCADE
);
```

When orphan craft logs remain in storage:
1. `CraftLogScreen` displays historical sessions referencing non-existent kits when viewing all logs.
2. Global time and score aggregations (total craft minutes, total damage points) become permanently skewed with un-attributable phantom sessions.
3. In Milestone 3 (Hangar CRUD), user deletions of model kits will cause silent database corruption by accumulating orphan records indefinitely.

This report evaluates four architectural patterns for implementing cascade deletion, investigates critical runtime interactions (specifically **in-memory cache invalidation** and **Explorer 1's concurrency mutex lock**), and delivers production-ready code blueprints and unit test designs for the Worker.

---

## 2. Root Cause & Technical Mechanics

### 2.1 The Current Implementation Gap
In `lib/data/repositories/kit_repository.dart`:
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
`KitRepository` operates with zero awareness of child entities. While `CraftLogRepository` already contains a robust, working `deleteLogsForKit(String kitId)` method (`lib/data/repositories/craft_log_repository.dart` line 59), `deleteKit` never invokes it.

### 2.2 The In-Memory Cache Trap (Crucial Discovery)
Both `KitRepository` and `CraftLogRepository` utilize in-memory cached lists (`_cachedKits` and `_cachedLogs`):
```dart
class CraftLogRepository implements ICraftLogRepository {
  List<CraftLog>? _cachedLogs;

  @override
  Future<List<CraftLog>> getAllLogs() async {
    if (_cachedLogs != null) {
      return List.unmodifiable(_cachedLogs!);
    }
    // Only reads from _storage if _cachedLogs is null
  }
}
```
If `KitRepository` were to purge craft logs by directly manipulating `_storage.setJsonList(StorageKeys.craftLogs, ...)`, any existing `CraftLogRepository` instance holding a non-null `_cachedLogs` will **NOT** be notified. The in-memory cache remains stale, and calls to `getLogsForKit(kitId)` or `getAllLogs()` will continue serving deleted logs from memory until the instance is destroyed.

Therefore, **cascade deletion MUST invoke `CraftLogRepository.deleteLogsForKit(kitId)` on the active repository instance** so that both `_cachedLogs` and `_storage` are updated atomically.

---

## 3. Evaluation of Candidate Architectural Patterns

We evaluated 4 candidate options across 6 key software engineering dimensions:

### Option 1: Repository-Level Cascade via Injected Repository (Recommended)
`KitRepository` accepts an optional `ICraftLogRepository?` dependency in its constructor (with smart fallback to `CraftLogRepository(_storage)` if omitted) and an optional `bindCraftLogRepository` method for late-binding.

```dart
class KitRepository implements IKitRepository {
  final ILocalStorageService _storage;
  ICraftLogRepository? _craftLogRepository;

  KitRepository([
    ILocalStorageService? storage,
    ICraftLogRepository? craftLogRepository,
  ])  : _storage = storage ?? LocalStorageService(),
        _craftLogRepository = craftLogRepository;

  void bindCraftLogRepository(ICraftLogRepository repository) {
    _craftLogRepository = repository;
  }
  
  @override
  Future<void> deleteKit(String kitId) async {
    // 1. Cascade delete child logs first
    final logRepo = _craftLogRepository ?? CraftLogRepository(_storage);
    await logRepo.deleteLogsForKit(kitId);

    // 2. Delete parent kit
    ...
  }
}
```

### Option 1B: Callback / Observer Hook (`onKitDeleted`)
`KitRepository` accepts a callback `final Future<void> Function(String kitId)? onKitDeleted`.
- **Pros**: Complete decoupling between repository classes.
- **Cons**: Requires caller boilerplate (`onKitDeleted: (id) => logRepo.deleteLogsForKit(id)`). If caller forgets to pass the callback, cascade deletion fails silently unless a fallback is also implemented.

### Option 2: Orchestrating Domain Service (`KitManagementService.deleteKitWithLogs`)
Introduce a domain/application service that holds both repositories and coordinates deletion:
```dart
class KitService {
  final IKitRepository _kitRepo;
  final ICraftLogRepository _logRepo;
  ...
  Future<void> deleteKitWithLogs(String kitId) async {
    await _logRepo.deleteLogsForKit(kitId);
    await _kitRepo.deleteKit(kitId);
  }
}
```
- **Pros**: Pure separation of concerns; repositories don't reference each other.
- **Cons**: 
  - **Leaky Invariant**: `IKitRepository.deleteKit(kitId)` remains exposed in the public interface contract (`PROJECT.md` line 95). Any caller or screen that directly calls `kitRepo.deleteKit(kitId)` bypasses the service and recreates the orphan log bug.
  - In Milestone 3 (Hangar CRUD), screens will naturally consume `IKitRepository` per `PROJECT.md`. Adding a separate service layer just for a 2-line cascade call adds unnecessary indirection without fixing the underlying repository vulnerability.

### Option 3: Direct Storage Key Deletion in `KitRepository` (Anti-pattern)
`KitRepository` reads `StorageKeys.craftLogs` directly from `_storage` and rewrites it.
- **Critical Flaws**:
  1. **Cache Stale Hazard**: Bypasses `CraftLogRepository._cachedLogs`, leaving in-memory cache desynchronized.
  2. **Mutex Bypass Hazard**: Bypasses Explorer 1's mutex write lock on `CraftLogRepository`, creating a concurrency race condition if another thread is executing `addLog()`.
  3. **High Coupling to Data Schema**: Couples `KitRepository` to the JSON schema and storage keys of a foreign entity.

---

## 4. Trade-Off Comparison Matrix

| Evaluation Criteria | Option 1: Injected Repo + Fallback (Recommended) | Option 1B: Callback Hook | Option 2: Domain Service | Option 3: Direct Storage Mutation |
| :--- | :--- | :--- | :--- | :--- |
| **SPEC §7 Invariant Enforcement** | **Guaranteed**: Calling `deleteKit` always cascades | Conditional on caller wiring callback | Fragile: Bypassed if caller invokes `kitRepo.deleteKit` directly | Partial (disk only; memory stale) |
| **In-Memory Cache Coherence** | **100%**: Updates `_cachedLogs` of active instance | **100%**: When callback calls `deleteLogsForKit` | **100%**: Service calls `deleteLogsForKit` | **0%**: Bypasses `_cachedLogs` |
| **Concurrency Mutex Safety (Exp 1)** | **100%**: Executes inside `deleteLogsForKit` write lock | **100%**: Executes inside `deleteLogsForKit` write lock | **100%**: Executes inside `deleteLogsForKit` write lock | **0%**: Mutex collision on `StorageKeys.craftLogs` |
| **`PROJECT.md` Interface Compliance** | **100%**: `IKitRepository.deleteKit` signature preserved | **100%**: Preserved | Requires adding `IKitService` or leaving `deleteKit` unsafe | **100%**: Preserved |
| **Test Ergonomics & Backward Compat** | **High**: Optional param; default fallback allows existing `KitRepository(storage)` to pass | Medium: Requires wiring closure in tests | Low: Requires instantiating service in all tests | High: No signature change |
| **Architecture Cleanliness** | Relies on `ICraftLogRepository` interface | Fully decoupled signature | Clean DDD separation, but creates dual deletion paths | Violates single responsibility & information hiding |

---

## 5. Architectural Deep Dives

### 5.1 Transactional Ordering: Delete Children Before Parent
In database theory (`FOREIGN KEY ... ON DELETE CASCADE`), dependent child records MUST be deleted before or simultaneously with the parent record.
In our Dart implementation:
1. `await logRepo.deleteLogsForKit(kitId);` (Step 1)
2. `await _persistKits(kits);` (Step 2)

**Failure Mode Analysis**:
- If Step 1 throws an error (e.g. storage IO failure): The error propagates immediately. Step 2 never executes. The parent kit remains intact. The system remains in a valid, retriable state without orphan records.
- If Step 2 were executed first and threw an error: The parent kit would be deleted, but the child logs would still exist, creating corrupt orphan records permanently.
- **Rule**: Always delete child logs before mutating the parent kit collection.

### 5.2 Concurrency & Mutex Coordination (Explorer 1 Alignment)
Explorer 1 is introducing an asynchronous write lock (`Future<void> _writeLock`) to serialize concurrent calls:
```dart
Future<T> _synchronized<T>(Future<T> Function() action) { ... }
```
When `KitRepository.deleteKit(kitId)` runs:
```
[kitRepo._synchronized] ──► acquires kitRepo lock
     │
     └──► [logRepo.deleteLogsForKit] ──► acquires logRepo lock
               │
               ├──► reads logs, filters, writes StorageKeys.craftLogs
               └──► releases logRepo lock
     │
     ├──► reads kits, filters, updates activeKitId, writes StorageKeys.kits
     └──► releases kitRepo lock
```
- **Deadlock Analysis**:
  Does `CraftLogRepository` ever call `KitRepository`? **No.**
  The call hierarchy is strictly: `KitRepository` $\to$ `CraftLogRepository`.
  Since the dependency graph is an acyclic directed graph (DAG), deadlocks are mathematically impossible.
- Furthermore, because `deleteLogsForKit` acquires `logRepo`'s lock, any concurrent `addLog` call will cleanly wait in queue and execute either entirely before or entirely after the cascade deletion.

### 5.3 Cache Invalidation Defense
In addition to repository injection, `CraftLogRepository` should expose a public `void clearCache()` method (and `KitRepository` should expose `void clearCache()`). This allows test fixtures and state management resets to force cache invalidation without restarting the runtime.

---

## 6. Concrete Code Blueprints for Worker

### 6.1 Blueprint 1: `lib/data/repositories/kit_repository.dart`

```dart
import '../../domain/models/kit_item.dart';
import '../storage/local_storage_service.dart';
import '../storage/storage_keys.dart';
import 'craft_log_repository.dart';

abstract class IKitRepository {
  Future<List<KitItem>> getAllKits();
  Future<KitItem?> getActiveKit();
  Future<void> saveKit(KitItem kit);
  Future<void> deleteKit(String kitId);
  Future<void> setActiveKit(String kitId);
}

class KitRepository implements IKitRepository {
  final ILocalStorageService _storage;
  ICraftLogRepository? _craftLogRepository;
  List<KitItem>? _cachedKits;
  String? _cachedActiveKitId;

  // Explorer 1 mutex write queue
  Future<void> _writeLock = Future.value();

  KitRepository([
    ILocalStorageService? storage,
    ICraftLogRepository? craftLogRepository,
  ])  : _storage = storage ?? LocalStorageService(),
        _craftLogRepository = craftLogRepository;

  /// Allows late-binding of the CraftLogRepository if created out of order.
  void bindCraftLogRepository(ICraftLogRepository repository) {
    _craftLogRepository = repository;
  }

  /// Invalidates in-memory cache, forcing next read to re-hydrate from storage.
  void clearCache() {
    _cachedKits = null;
    _cachedActiveKitId = null;
  }

  /// Sequential execution queue for write operations
  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeLock = _writeLock.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  ...

  @override
  Future<void> deleteKit(String kitId) => _synchronized(() async {
    // 1. Cascade delete associated craft logs per SPEC §7 ON DELETE CASCADE
    final logRepo = _craftLogRepository ?? CraftLogRepository(_storage);
    await logRepo.deleteLogsForKit(kitId);

    // 2. Load existing kits and remove target
    final kits = (await getAllKits()).toList();
    kits.removeWhere((k) => k.id == kitId);

    // 3. Handle active kit fallback and auto-seeding if empty
    if (kits.isEmpty) {
      final seed = createDefaultSeedKit();
      kits.add(seed);
      _cachedActiveKitId = seed.id;
      await _storage.setString(StorageKeys.activeKitId, seed.id);
    } else if (_cachedActiveKitId == kitId) {
      final nextActive = kits.firstWhere(
        (k) => !k.isCompleted,
        orElse: () => kits.first,
      );
      _cachedActiveKitId = nextActive.id;
      await _storage.setString(StorageKeys.activeKitId, nextActive.id);
    }

    _cachedKits = kits;
    await _persistKits(kits);
  });
```

### 6.2 Blueprint 2: `lib/data/repositories/craft_log_repository.dart`

Add `clearCache()` for testing and defensive cache coherence:
```dart
class CraftLogRepository implements ICraftLogRepository {
  final ILocalStorageService _storage;
  List<CraftLog>? _cachedLogs;

  CraftLogRepository([ILocalStorageService? storage])
      : _storage = storage ?? LocalStorageService();

  /// Invalidates in-memory cache
  void clearCache() {
    _cachedLogs = null;
  }
  ...
```

### 6.3 Blueprint 3: Wiring in `lib/main.dart`

In `lib/main.dart` (`_BattleAtelierScreenState.initState`):
```dart
  @override
  void initState() {
    super.initState();
    _craftLogRepo = widget.craftLogRepository ?? CraftLogRepository();
    // Pass _craftLogRepo to KitRepository so both share the same instance and cache!
    _kitRepo = widget.kitRepository ?? KitRepository(null, _craftLogRepo);
```
If `widget.kitRepository` is provided from an external caller as a `KitRepository` instance, also bind `_craftLogRepo`:
```dart
  if (_kitRepo is KitRepository) {
    (_kitRepo as KitRepository).bindCraftLogRepository(_craftLogRepo);
  }
```

---

## 7. Unit Test Suite Design for Worker

The Worker should add the following dedicated cascade deletion tests to `test/unit/storage_test.dart`:

```dart
group('Cascade Deletion Tests (SPEC §7 Compliance)', () {
  late ILocalStorageService storage;
  late ICraftLogRepository logRepo;
  late KitRepository kitRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    logRepo = CraftLogRepository(storage);
    kitRepo = KitRepository(storage, logRepo);
  });

  test('Deleting a kit cascade deletes all its logs and preserves logs of other kits', () async {
    final kitA = KitItem(
      id: 'kit-A',
      title: 'Kit A',
      grade: 'HG',
      totalHp: 500,
      currentHp: 500,
      status: KitStatus.inProgress,
      createdAt: DateTime.now(),
    );
    final kitB = KitItem(
      id: 'kit-B',
      title: 'Kit B',
      grade: 'RG',
      totalHp: 800,
      currentHp: 800,
      status: KitStatus.unstarted,
      createdAt: DateTime.now(),
    );
    await kitRepo.saveKit(kitA);
    await kitRepo.saveKit(kitB);

    // 3 logs for kitA, 2 logs for kitB
    for (int i = 0; i < 3; i++) {
      await logRepo.addLog(CraftLog.create(
        id: 'log-A-$i',
        kitId: 'kit-A',
        phase: CraftPhases.snapFit,
        durationMinutes: 25,
        damageDealt: 100,
        isCompletedSession: true,
      ));
    }
    for (int i = 0; i < 2; i++) {
      await logRepo.addLog(CraftLog.create(
        id: 'log-B-$i',
        kitId: 'kit-B',
        phase: CraftPhases.sanding,
        durationMinutes: 15,
        damageDealt: 60,
        isCompletedSession: true,
      ));
    }

    expect((await logRepo.getAllLogs()).length, equals(5));

    // Act: Delete kit A
    await kitRepo.deleteKit('kit-A');

    // Assert: kit A is gone
    final kits = await kitRepo.getAllKits();
    expect(kits.any((k) => k.id == 'kit-A'), isFalse);
    expect(kits.any((k) => k.id == 'kit-B'), isTrue);

    // Assert: kit A logs are purged from memory cache
    final remainingKitALogs = await logRepo.getLogsForKit('kit-A');
    expect(remainingKitALogs, isEmpty);

    // Assert: kit B logs are preserved
    final remainingKitBLogs = await logRepo.getLogsForKit('kit-B');
    expect(remainingKitBLogs.length, equals(2));

    // Assert: storage has 0 orphan logs
    final rawLogsInStorage = await storage.getJsonList(StorageKeys.craftLogs);
    expect(rawLogsInStorage.length, equals(2));
    expect(rawLogsInStorage.every((l) => l['kitId'] == 'kit-B'), isTrue);
  });

  test('KitRepository without injected logRepo falls back to auto-cleaning storage', () async {
    // Un-injected repository instance
    final standaloneKitRepo = KitRepository(storage);

    final kit = KitItem(
      id: 'standalone-kit',
      title: 'Standalone Kit',
      grade: 'HG',
      totalHp: 500,
      currentHp: 500,
      status: KitStatus.inProgress,
      createdAt: DateTime.now(),
    );
    await standaloneKitRepo.saveKit(kit);

    // Add log via raw storage to simulate pre-existing data
    await storage.setJsonList(StorageKeys.craftLogs, [
      {
        'id': 'raw-log-1',
        'kitId': 'standalone-kit',
        'phase': 'Snap-fit',
        'durationMinutes': 25,
        'damageDealt': 100,
        'isCompletedSession': 1,
        'createdAt': DateTime.now().toIso8601String(),
      }
    ]);

    expect((await storage.getJsonList(StorageKeys.craftLogs)).length, equals(1));

    // Act: Delete kit
    await standaloneKitRepo.deleteKit('standalone-kit');

    // Assert: Storage logs were purged via fallback
    final storedLogs = await storage.getJsonList(StorageKeys.craftLogs);
    expect(storedLogs, isEmpty);
  });

  test('Late-binding via bindCraftLogRepository correctly wires cascade deletion', () async {
    final lateKitRepo = KitRepository(storage);
    lateKitRepo.bindCraftLogRepository(logRepo);

    final kit = KitItem(
      id: 'late-kit',
      title: 'Late Kit',
      grade: 'HG',
      totalHp: 500,
      currentHp: 500,
      status: KitStatus.inProgress,
      createdAt: DateTime.now(),
    );
    await lateKitRepo.saveKit(kit);
    await logRepo.addLog(CraftLog.create(
      id: 'late-log-1',
      kitId: 'late-kit',
      phase: CraftPhases.snapFit,
      durationMinutes: 25,
      damageDealt: 100,
      isCompletedSession: true,
    ));

    await lateKitRepo.deleteKit('late-kit');

    expect(await logRepo.getLogsForKit('late-kit'), isEmpty);
    expect(await storage.getJsonList(StorageKeys.craftLogs), isEmpty);
  });

  test('Deleting a non-existent kit completes safely without side effects', () async {
    await kitRepo.deleteKit('totally-non-existent-kit-id');
    // Storage should retain default seed kit and no error thrown
    expect((await kitRepo.getAllKits()).isNotEmpty, isTrue);
  });
});
```

### 6.4 Updating Challenger Test 3.2 in `test/challenge/storage_stress_challenge_test.dart`

In Milestone 2 Retry, Challenger Test 3.2 should be updated from asserting a failure (`expect(remainingLogs.length, equals(1))`) to asserting that cascade deletion **successfully purges the orphan logs**:

```dart
    test('3.2: KitRepository.deleteKit cascade deletes logs in storage and memory', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo); // Injected repository

      final kit = KitItem(
        id: 'orphan-test-kit',
        title: 'Orphan Test Kit',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit);
      await logRepo.addLog(CraftLog.create(
        id: 'orphan-log-1',
        kitId: 'orphan-test-kit',
        phase: CraftPhases.snapFit,
        durationMinutes: 25,
        damageDealt: 100,
        isCompletedSession: true,
      ));

      expect((await kitRepo.getAllKits()).any((k) => k.id == 'orphan-test-kit'), isTrue);
      expect((await logRepo.getLogsForKit('orphan-test-kit')).length, equals(1));

      // Now delete kit via KitRepository
      await kitRepo.deleteKit('orphan-test-kit');

      expect((await kitRepo.getAllKits()).any((k) => k.id == 'orphan-test-kit'), isFalse);

      // Check CraftLogRepository: Both in-memory and disk logs are cleanly purged!
      final remainingLogs = await logRepo.getLogsForKit('orphan-test-kit');
      expect(remainingLogs, isEmpty,
          reason: 'SPEC §7 ON DELETE CASCADE: Deleting a kit must delete all associated craft logs');

      final rawStorageLogs = await storage.getJsonList(StorageKeys.craftLogs);
      expect(rawStorageLogs.any((l) => l['kitId'] == 'orphan-test-kit'), isFalse);
    });
```
