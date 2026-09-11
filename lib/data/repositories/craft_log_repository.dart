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

  /// Invalidates in-memory cache, forcing the next read to re-hydrate from storage.
  void clearCache() {
    _cachedLogs = null;
  }

  @override
  Future<List<CraftLog>> getAllLogs() async {
    if (_cachedLogs != null) {
      return List.unmodifiable(_cachedLogs!);
    }

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
