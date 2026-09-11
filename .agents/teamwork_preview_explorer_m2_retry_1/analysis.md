# Technical Analysis: Concurrency Mutex & Atomic Storage

- **Author**: teamwork_preview_explorer (Explorer 1 for Milestone 2 Retry)
- **Target Roles**: Orchestrator (parent), teamwork_preview_worker, teamwork_preview_challenger, teamwork_preview_auditor
- **Working Directory**: `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m2_retry_1`
- **Focus**: Resolving Challenger 1 Finding 1 (Critical: Concurrent async writes cause silent data loss under `Future.wait`)
- **Timestamp**: 2026-09-11T05:49:00Z

---

## 1. Executive Summary & Problem Root Cause

### 1.1 Problem Statement
During Milestone 2 adversarial stress testing, Challenger 1 discovered that parallel asynchronous write operations executed via `Future.wait` resulted in severe data loss:
- **`CraftLogRepository.addLog`**: 4 out of 6 craft logs were permanently lost (only 2 survived).
- **`KitRepository.saveKit`**: 3 out of 5 kits were permanently lost (only 2 survived).

### 1.2 Root Cause Analysis in Dart's Asynchronous Execution Model
Dart operates on an event-driven, single-isolate event loop. While parallel thread preemption does not exist within an isolate, asynchronous race conditions occur across `await` points whenever state is read, modified, and written back across multiple event loop turns.

In the current implementation:

#### Vulnerable Code in `CraftLogRepository.addLog`:
```dart
@override
Future<void> addLog(CraftLog log) async {
  final logs = (await getAllLogs()).toList(); // Yield point 1
  logs.insert(0, log);
  _cachedLogs = logs;

  final mapList = logs.map((l) => l.toMap()).toList();
  await _storage.setJsonList(StorageKeys.craftLogs, mapList); // Yield point 2
}
```

#### Vulnerable Code in `KitRepository.saveKit`:
```dart
@override
Future<void> saveKit(KitItem kit) async {
  final kits = (await getAllKits()).toList(); // Yield point 1
  final index = kits.indexWhere((k) => k.id == kit.id);

  if (index >= 0) {
    kits[index] = kit;
  } else {
    kits.add(kit);
  }

  _cachedKits = kits;
  await _persistKits(kits); // Yield point 2
}
```

### 1.3 Execution Interleaving Trace
When 5 calls to `addLog` are issued in parallel via `Future.wait([addLog(L1), addLog(L2), ...])`:
1. **Turn 0 (Initiation)**: All 5 calls execute up to `await getAllLogs()`. Each yields control to the event loop.
2. **Turn 1 (Snapshot Read)**: All 5 calls resume with the **exact same pre-existing list snapshot** (e.g. containing only `[InitialLog]`).
3. **Turn 2 (In-Memory Mutation)**:
   - Call 1 inserts `L1` into its copy: `[L1, InitialLog]`. Calls `await _storage.setJsonList` and suspends.
   - Call 2 inserts `L2` into its copy: `[L2, InitialLog]`. It overwrites `_cachedLogs = [L2, InitialLog]`, clobbering `L1`! Calls `await _storage.setJsonList` and suspends.
   - Calls 3, 4, 5 do the same in rapid succession.
4. **Turn 3 (Storage Commit)**: Whichever disk write finishes last commits a JSON array containing only its single added log and the initial log. All other concurrent additions are permanently dropped.

---

## 2. Synchronization Architecture Design

### 2.1 Dependency Evaluation: External Package vs. Pure Dart
- **Option A (`package:synchronized`)**: Adds an external dependency to `pubspec.yaml`, requiring `pub get`, risk of dependency conflicts, and build overhead.
- **Option B (Pure Dart `AsyncLock`)**: Implements an asynchronous mutex using standard `dart:async` primitives (`Completer`, `Future`, `Zone`).
  - **Verdict**: **Option B is recommended**. It requires zero external dependencies, introduces zero runtime overhead, compiles instantly on all targets (Web, Windows, Android, iOS), and provides custom control over re-entrancy and error unblocking.

### 2.2 Core Requirements for `AsyncLock`
1. **Mutual Exclusion (Mutex)**: Only one asynchronous critical section runs at any given instant.
2. **FIFO Execution Order**: Operations execute in the exact order they were queued.
3. **Exception Resilience (No Deadlocks on Failure)**: If operation $N$ throws an exception, operation $N+1$ must still execute cleanly. The queue must not stall or abandon subsequent operations.
4. **Clean Idle State**: When all queued operations complete, the lock must reset its internal reference to `null` to avoid retaining completed Future objects in memory.
5. **Zone-Based Re-Entrancy Support**: If a method holding the lock invokes another method guarded by the same lock within the same asynchronous execution context (Zone), the call must execute immediately without deadlocking.

### 2.3 Mechanism Specification
```
[Operation 1] ---> acquires lock ---> executes computation ---> whenComplete: unblocks Op 2
                                                                   |
[Operation 2] ---> waits on Op 1 completer ------------------------+---> executes computation
```

If `Zone.current[#lockKey] == true`, the execution context is already within the lock's critical section, so `computation()` is executed immediately via `Future.sync(computation)`.

---

## 3. Concrete Code Blueprints for Worker

### 3.1 Blueprint 1: `lib/core/utils/async_lock.dart`
Create a new file at `lib/core/utils/async_lock.dart`:

```dart
import 'dart:async';

/// An asynchronous mutual exclusion lock (mutex).
///
/// Guarantees that asynchronous critical sections execute sequentially in FIFO order.
/// Supports re-entrancy within the same async Zone context to prevent deadlocks
/// when nested methods acquire the same lock.
class AsyncLock {
  Future<void>? _lastOperation;
  final Object _zoneKey = Object();

  /// Returns true if the lock is currently held by an ongoing operation.
  bool get isLocked => _lastOperation != null;

  /// Executes [computation] exclusively within the lock.
  ///
  /// - If the current asynchronous context already holds this lock (re-entrant call),
  ///   [computation] is executed immediately to prevent deadlock.
  /// - If an earlier queued operation throws an exception, subsequent operations
  ///   will still execute without being blocked or cancelled.
  Future<T> synchronized<T>(FutureOr<T> Function() computation) {
    // Re-entrancy check: if already executing inside this lock's zone, run immediately.
    if (Zone.current[_zoneKey] == true) {
      return Future.sync(computation);
    }

    final prev = _lastOperation;
    final completer = Completer<void>();
    _lastOperation = completer.future;

    Future<void> waitForPrev() {
      if (prev == null) return Future.value();
      return prev.catchError((_) {
        // Suppress previous errors so that a failed operation does not
        // deadlock or break subsequent operations in the queue.
      });
    }

    return waitForPrev().then((_) {
      return runZoned(
        () => Future.sync(computation),
        zoneValues: {_zoneKey: true},
      );
    }).whenComplete(() {
      if (identical(_lastOperation, completer.future)) {
        _lastOperation = null;
      }
      completer.complete();
    });
  }
}
```

---

### 3.2 Blueprint 2: `lib/data/repositories/craft_log_repository.dart`
Update `lib/data/repositories/craft_log_repository.dart` to protect all mutations and cold hydration using `AsyncLock`:

```dart
import '../../core/utils/async_lock.dart';
import '../../domain/models/craft_log.dart';
import '../storage/local_storage_service.dart';
import '../storage/storage_keys.dart';

abstract class ICraftLogRepository {
  Future<List<CraftLog>> getLogsForKit(String kitId);
  Future<List<CraftLog>> getAllLogs();
  Future<void> addLog(CraftLog log);
  Future<void> deleteLogsForKit(String kitId);
}

class CraftLogRepository implements ICraftLogRepository {
  final ILocalStorageService _storage;
  final AsyncLock _lock = AsyncLock();
  List<CraftLog>? _cachedLogs;

  CraftLogRepository([ILocalStorageService? storage])
      : _storage = storage ?? LocalStorageService();

  @override
  Future<List<CraftLog>> getAllLogs() async {
    // Fast path: synchronous cache hit
    if (_cachedLogs != null) {
      return List.unmodifiable(_cachedLogs!);
    }

    // Synchronized cold hydration
    return _lock.synchronized(() async {
      if (_cachedLogs != null) {
        return List.unmodifiable(_cachedLogs!);
      }

      final rawList = await _storage.getJsonList(StorageKeys.craftLogs);
      final logs = <CraftLog>[];

      for (final map in rawList) {
        try {
          logs.add(CraftLog.fromMap(map));
        } catch (_) {
          // Skip corrupted logs defensively
        }
      }

      // Sort newest first
      logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _cachedLogs = logs;
      return List.unmodifiable(logs);
    });
  }

  @override
  Future<List<CraftLog>> getLogsForKit(String kitId) async {
    final all = await getAllLogs();
    return all.where((log) => log.kitId == kitId).toList();
  }

  @override
  Future<void> addLog(CraftLog log) {
    return _lock.synchronized(() async {
      final logs = (await getAllLogs()).toList();
      logs.insert(0, log); // Insert newest first

      final mapList = logs.map((l) => l.toMap()).toList();
      await _storage.setJsonList(StorageKeys.craftLogs, mapList);
      _cachedLogs = logs;
    });
  }

  @override
  Future<void> deleteLogsForKit(String kitId) {
    return _lock.synchronized(() async {
      final logs = (await getAllLogs()).toList();
      logs.removeWhere((l) => l.kitId == kitId);

      final mapList = logs.map((l) => l.toMap()).toList();
      await _storage.setJsonList(StorageKeys.craftLogs, mapList);
      _cachedLogs = logs;
    });
  }
}
```

---

### 3.3 Blueprint 3: `lib/data/repositories/kit_repository.dart`
Update `lib/data/repositories/kit_repository.dart` to protect all mutations and cold hydration using `AsyncLock`, with optional cascade deletion integration:

```dart
import '../../core/utils/async_lock.dart';
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
  final ICraftLogRepository? _craftLogRepository;
  final AsyncLock _lock = AsyncLock();
  List<KitItem>? _cachedKits;
  String? _cachedActiveKitId;

  KitRepository([
    ILocalStorageService? storage,
    ICraftLogRepository? craftLogRepository,
  ])  : _storage = storage ?? LocalStorageService(),
        _craftLogRepository = craftLogRepository;

  /// Default initial seed kit when storage is empty.
  static KitItem createDefaultSeedKit() {
    return KitItem(
      id: 'default-box-mimic-hg-001',
      title: '綠色普通盒怪',
      grade: 'HG',
      totalHp: 500,
      currentHp: 500,
      status: KitStatus.inProgress,
      photoPath: null,
      isCustomBoss: false,
      createdAt: DateTime(2026, 1, 1),
      completedAt: null,
    );
  }

  @override
  Future<List<KitItem>> getAllKits() async {
    // Fast path: synchronous cache hit
    if (_cachedKits != null) {
      return List.unmodifiable(_cachedKits!);
    }

    // Synchronized cold hydration
    return _lock.synchronized(() async {
      if (_cachedKits != null) {
        return List.unmodifiable(_cachedKits!);
      }

      final rawList = await _storage.getJsonList(StorageKeys.kits);
      final kits = <KitItem>[];

      for (final map in rawList) {
        try {
          kits.add(KitItem.fromMap(map));
        } catch (_) {
          // Skip corrupted entries defensively
        }
      }

      // Auto-seed default kit if storage is empty
      if (kits.isEmpty) {
        final seed = createDefaultSeedKit();
        kits.add(seed);
        _cachedActiveKitId = seed.id;
        await _persistKits(kits);
        await _storage.setString(StorageKeys.activeKitId, seed.id);
        _cachedKits = kits;
        return List.unmodifiable(kits);
      }

      _cachedKits = kits;
      return List.unmodifiable(kits);
    });
  }

  @override
  Future<KitItem?> getActiveKit() async {
    final kits = await getAllKits();
    _cachedActiveKitId ??= await _storage.getString(StorageKeys.activeKitId);

    if (_cachedActiveKitId != null) {
      try {
        return kits.firstWhere((k) => k.id == _cachedActiveKitId);
      } catch (_) {}
    }

    // Fallback to first non-completed or first kit
    final fallback = kits.firstWhere(
      (k) => !k.isCompleted,
      orElse: () => kits.first,
    );
    await setActiveKit(fallback.id);
    return fallback;
  }

  @override
  Future<void> saveKit(KitItem kit) {
    return _lock.synchronized(() async {
      final kits = (await getAllKits()).toList();
      final index = kits.indexWhere((k) => k.id == kit.id);

      if (index >= 0) {
        kits[index] = kit;
      } else {
        kits.add(kit);
      }

      await _persistKits(kits);
      _cachedKits = kits;
    });
  }

  @override
  Future<void> deleteKit(String kitId) {
    return _lock.synchronized(() async {
      final kits = (await getAllKits()).toList();
      kits.removeWhere((k) => k.id == kitId);

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

      await _persistKits(kits);
      _cachedKits = kits;

      // Cascade delete logs for this kit (SPEC §7 ON DELETE CASCADE)
      if (_craftLogRepository != null) {
        await _craftLogRepository.deleteLogsForKit(kitId);
      } else {
        final rawLogs = await _storage.getJsonList(StorageKeys.craftLogs);
        final filteredLogs = rawLogs.where((l) => l['kitId'] != kitId).toList();
        await _storage.setJsonList(StorageKeys.craftLogs, filteredLogs);
      }
    });
  }

  @override
  Future<void> setActiveKit(String kitId) {
    return _lock.synchronized(() async {
      _cachedActiveKitId = kitId;
      await _storage.setString(StorageKeys.activeKitId, kitId);
    });
  }

  Future<void> _persistKits(List<KitItem> kits) async {
    final mapList = kits.map((k) => k.toMap()).toList();
    await _storage.setJsonList(StorageKeys.kits, mapList);
  }
}
```

---

## 4. Concrete Unit Test Designs

### 4.1 New Unit Test Suite: `test/unit/async_lock_test.dart`
Create a dedicated unit test suite for `AsyncLock` at `test/unit/async_lock_test.dart`:

```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nifty_heisenberg/core/utils/async_lock.dart';

void main() {
  group('AsyncLock Unit Tests', () {
    test('Sequential execution: operations run strictly one after another in FIFO order', () async {
      final lock = AsyncLock();
      final executionOrder = <int>[];

      final f1 = lock.synchronized(() async {
        await Future.delayed(const Duration(milliseconds: 30));
        executionOrder.add(1);
        return 'first';
      });

      final f2 = lock.synchronized(() async {
        await Future.delayed(const Duration(milliseconds: 10));
        executionOrder.add(2);
        return 'second';
      });

      final f3 = lock.synchronized(() async {
        executionOrder.add(3);
        return 'third';
      });

      final results = await Future.wait([f1, f2, f3]);

      expect(executionOrder, equals([1, 2, 3]));
      expect(results, equals(['first', 'second', 'third']));
      expect(lock.isLocked, isFalse);
    });

    test('Error resilience: an exception in an earlier operation does NOT block subsequent operations', () async {
      final lock = AsyncLock();
      final executed = <int>[];

      final f1 = lock.synchronized(() async {
        await Future.delayed(const Duration(milliseconds: 20));
        executed.add(1);
        throw Exception('Operation 1 simulated failure');
      });

      final f2 = lock.synchronized(() async {
        executed.add(2);
        return 'op2_ok';
      });

      expect(f1, throwsA(isA<Exception>()));
      final result2 = await f2;

      expect(executed, equals([1, 2]));
      expect(result2, equals('op2_ok'));
      expect(lock.isLocked, isFalse);
    });

    test('Re-entrancy: nested synchronized calls in the same Zone execute without deadlocking', () async {
      final lock = AsyncLock();

      final result = await lock.synchronized(() async {
        final inner1 = await lock.synchronized(() async {
          final inner2 = await lock.synchronized(() async {
            return 'deeply_nested_success';
          });
          return 'level1_$inner2';
        });
        return 'root_$inner1';
      });

      expect(result, equals('root_level1_deeply_nested_success'));
      expect(lock.isLocked, isFalse);
    });

    test('High-concurrency stress: 50 concurrent async tasks execute without dropping or corruption', () async {
      final lock = AsyncLock();
      final list = <int>[];
      const taskCount = 50;

      final futures = List.generate(taskCount, (i) {
        return lock.synchronized(() async {
          await Future.delayed(const Duration(milliseconds: 1));
          list.add(i);
        });
      });

      await Future.wait(futures);

      expect(list.length, equals(taskCount));
      expect(list, equals(List.generate(taskCount, (i) => i)));
      expect(lock.isLocked, isFalse);
    });

    test('Synchronous computation support and immediate return', () async {
      final lock = AsyncLock();

      final val = await lock.synchronized(() => 42);
      expect(val, equals(42));
      expect(lock.isLocked, isFalse);
    });
  });
}
```

---

### 4.2 Updated Assertions for `test/challenge/storage_stress_challenge_test.dart`
Update the challenge tests (lines 232–295) to enforce 100% data survival:

#### In Test 2.1 (`CraftLogRepository` concurrent writes):
```dart
test('2.1: Rapid concurrent writes to CraftLogRepository (Race condition eliminated)', () async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);
  final logRepo = CraftLogRepository(storage);

  final initialLog = CraftLog.create(
    id: 'init-000',
    kitId: 'kit-shared',
    phase: CraftPhases.snapFit,
    durationMinutes: 10,
    damageDealt: 50,
    isCompletedSession: true,
  );
  await logRepo.addLog(initialLog);

  final futures = List.generate(5, (i) {
    final id = 'concurrent-log-$i';
    return logRepo.addLog(CraftLog.create(
      id: id,
      kitId: 'kit-shared',
      phase: CraftPhases.sanding,
      durationMinutes: 5 * (i + 1),
      damageDealt: 20 * (i + 1),
      isCompletedSession: true,
    ));
  });

  await Future.wait(futures);

  final allLogs = await logRepo.getAllLogs();
  
  // Enforce 100% survival: all 6 logs must survive without data loss
  expect(allLogs.length, equals(6),
      reason: 'All 6 logs must survive concurrent writes without data loss');
  expect(allLogs.any((l) => l.id == 'init-000'), isTrue);
  for (int i = 0; i < 5; i++) {
    expect(allLogs.any((l) => l.id == 'concurrent-log-$i'), isTrue);
  }

  // Reload verification from disk: fresh repository instance sees all 6 logs
  final freshRepo = CraftLogRepository(storage);
  final diskLogs = await freshRepo.getAllLogs();
  expect(diskLogs.length, equals(6),
      reason: 'Disk persistence must reflect all 6 concurrent writes');
});
```

#### In Test 2.2 (`KitRepository` concurrent writes):
```dart
test('2.2: Rapid concurrent writes to KitRepository (Race condition eliminated)', () async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);
  final kitRepo = KitRepository(storage);

  await kitRepo.getAllKits(); // Hydrate seed kit

  final futures = List.generate(4, (i) {
    final id = 'concurrent-kit-$i';
    final title = 'Concurrent Kit $i';
    return kitRepo.saveKit(KitItem(
      id: id,
      title: title,
      grade: 'HG',
      totalHp: 500,
      currentHp: 500,
      status: KitStatus.unstarted,
      createdAt: DateTime.now(),
    ));
  });

  await Future.wait(futures);

  final kits = await kitRepo.getAllKits();

  // Enforce 100% survival: 4 saved kits + 1 seed kit = 5 kits
  expect(kits.length, equals(5),
      reason: 'All 4 concurrent kits plus 1 default seed kit must survive');
  for (int i = 0; i < 4; i++) {
    expect(kits.any((k) => k.id == 'concurrent-kit-$i'), isTrue);
  }

  // Reload verification from disk: fresh repository instance sees all 5 kits
  final freshRepo = KitRepository(storage);
  final diskKits = await freshRepo.getAllKits();
  expect(diskKits.length, equals(5),
      reason: 'Disk persistence must reflect all 5 kits');
});
```

---

## 5. Deadlock Prevention & Concurrency Verification Matrix

| Potential Risk | Scenario | Mitigation Implemented |
|---|---|---|
| **Re-entrancy Deadlock** | Method A in repository holds lock and calls Method B in same repository which also requests lock | `Zone.current[_zoneKey] == true` detects existing lock ownership and executes computation immediately without queueing. |
| **Pipeline Stall** | An I/O write throws `FormatException` or disk error | `waitForPrev()` uses `.catchError((_) {})` and `.whenComplete()` ensures `completer.complete()` is always called, allowing subsequent tasks to proceed unhindered. |
| **State Clobbering** | Multiple callers invoke `getAllKits()` during cold startup | Double-checked locking in `getAllKits()`: enters `_lock.synchronized` and checks `_cachedKits != null` again before triggering storage read or seed write. |
| **Memory Leak** | Continuous queue chaining builds unbounded future references | When the active queue is empty (`identical(_lastOperation, completer.future)`), `_lastOperation` resets to `null`. |
| **Cascade Lock Inversion** | `KitRepository.deleteKit` deletes logs via `CraftLogRepository` | Lock graph is strictly hierarchical: `KitRepository` lock $\to$ `CraftLogRepository` lock. `CraftLogRepository` never accesses `KitRepository`. |

---

## 6. Implementation Action Plan for Worker

1. **Step 1**: Create `lib/core/utils/async_lock.dart` matching Blueprint 3.1.
2. **Step 2**: Add unit tests at `test/unit/async_lock_test.dart` matching Blueprint 4.1. Run `flutter test test/unit/async_lock_test.dart` to confirm mutex behavior.
3. **Step 3**: Update `lib/data/repositories/craft_log_repository.dart` matching Blueprint 3.2.
4. **Step 4**: Update `lib/data/repositories/kit_repository.dart` matching Blueprint 3.3.
5. **Step 5**: Update `test/challenge/storage_stress_challenge_test.dart` assertions in tests 2.1 & 2.2 matching Blueprint 4.2.
6. **Step 6**: Run verification suite:
   ```bash
   flutter test test/unit/async_lock_test.dart
   flutter test test/challenge/storage_stress_challenge_test.dart
   flutter test
   flutter analyze
   ```
