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
  ICraftLogRepository? _craftLogRepository;
  final AsyncLock _lock = AsyncLock();
  List<KitItem>? _cachedKits;
  String? _cachedActiveKitId;

  KitRepository([
    ILocalStorageService? storage,
    ICraftLogRepository? craftLogRepository,
  ])  : _storage = storage ?? LocalStorageService(),
        _craftLogRepository = craftLogRepository;

  /// Allows late-binding of the CraftLogRepository if created out of order.
  void bindCraftLogRepository(ICraftLogRepository repository) {
    _craftLogRepository = repository;
  }

  /// Invalidates in-memory cache, forcing the next read to re-hydrate from storage.
  void clearCache() {
    _cachedKits = null;
    _cachedActiveKitId = null;
  }

  /// Default initial seed kit when storage is empty.
  static KitItem createDefaultSeedKit() => KitItem.initialSeedKit();

  @override
  Future<List<KitItem>> getAllKits() async {
    if (_cachedKits != null) {
      return List.unmodifiable(_cachedKits!);
    }

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
        _cachedKits = kits;
        _cachedActiveKitId = seed.id;
        await _persistKits(kits);
        await _storage.setString(StorageKeys.activeKitId, seed.id);
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

      _cachedKits = kits;
      await _persistKits(kits);
    });
  }

  @override
  Future<void> deleteKit(String kitId) {
    return _lock.synchronized(() async {
      // 1. Cascade delete associated craft logs per SPEC §7 ON DELETE CASCADE
      final logRepo = _craftLogRepository ?? CraftLogRepository(_storage);
      await logRepo.deleteLogsForKit(kitId);

      // 2. Remove kit from kit collection
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

      _cachedKits = kits;
      await _persistKits(kits);
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
