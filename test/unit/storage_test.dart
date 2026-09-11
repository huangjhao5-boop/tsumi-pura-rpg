import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nifty_heisenberg/data/storage/local_storage_service.dart';
import 'package:nifty_heisenberg/data/storage/storage_keys.dart';
import 'package:nifty_heisenberg/data/repositories/kit_repository.dart';
import 'package:nifty_heisenberg/data/repositories/craft_log_repository.dart';
import 'package:nifty_heisenberg/core/constants/game_constants.dart';
import 'package:nifty_heisenberg/domain/models/kit_item.dart';
import 'package:nifty_heisenberg/domain/models/craft_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ILocalStorageService storage;
  late IKitRepository kitRepo;
  late ICraftLogRepository logRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    kitRepo = KitRepository(storage);
    logRepo = CraftLogRepository(storage);
  });

  group('KitRepository Tests', () {
    test('Empty storage auto-seeds default HG kit', () async {
      final kits = await kitRepo.getAllKits();
      expect(kits.length, equals(1));
      expect(kits.first.title, equals('綠色普通盒怪'));
      expect(kits.first.grade, equals('HG'));
      expect(kits.first.totalHp, equals(500));
      expect(kits.first.currentHp, equals(500));
      expect(kits.first.isInProgress, isTrue);

      final active = await kitRepo.getActiveKit();
      expect(active, isNotNull);
      expect(active!.id, equals(kits.first.id));
    });

    test('Loads pre-existing kits from storage without re-seeding', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.kits: jsonEncode([
          {
            'id': 'test-mg-001',
            'title': 'MG 獵魔鋼彈',
            'grade': 'MG',
            'totalHp': 1500,
            'currentHp': 1200,
            'status': 'in_progress',
            'photoPath': null,
            'isCustomBoss': 0,
            'createdAt': DateTime(2026, 1, 1).toIso8601String(),
            'completedAt': null,
          }
        ]),
        StorageKeys.activeKitId: 'test-mg-001',
      });

      final prefs = await SharedPreferences.getInstance();
      final customStorage = LocalStorageService(prefs);
      final customRepo = KitRepository(customStorage);

      final kits = await customRepo.getAllKits();
      expect(kits.length, equals(1));
      expect(kits.first.id, equals('test-mg-001'));
      expect(kits.first.title, equals('MG 獵魔鋼彈'));

      final active = await customRepo.getActiveKit();
      expect(active!.id, equals('test-mg-001'));
    });

    test('Save kit updates existing and appends new', () async {
      final kits = await kitRepo.getAllKits();
      final defaultKit = kits.first;

      // 1. Update existing kit HP
      final damagedKit = defaultKit.copyWith(currentHp: 400);
      await kitRepo.saveKit(damagedKit);

      var updatedKits = await kitRepo.getAllKits();
      expect(updatedKits.length, equals(1));
      expect(updatedKits.first.currentHp, equals(400));

      // 2. Add new kit
      final newKit = KitItem(
        id: 'new-rg-002',
        title: 'RG 牛鋼彈',
        grade: 'RG',
        totalHp: 800,
        currentHp: 800,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(newKit);

      updatedKits = await kitRepo.getAllKits();
      expect(updatedKits.length, equals(2));
      expect(updatedKits.any((k) => k.id == 'new-rg-002'), isTrue);
    });

    test('Delete kit removes it and re-adjusts active kit', () async {
      final seedKits = await kitRepo.getAllKits();
      final seedId = seedKits.first.id;

      final extraKit = KitItem(
        id: 'extra-001',
        title: 'HG 異端',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(extraKit);
      await kitRepo.setActiveKit(extraKit.id);

      // Delete active kit
      await kitRepo.deleteKit(extraKit.id);
      final remaining = await kitRepo.getAllKits();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals(seedId));

      final active = await kitRepo.getActiveKit();
      expect(active!.id, equals(seedId));
    });

    test('Switching active kit persists correctly', () async {
      final secondKit = KitItem(
        id: 'kit-2',
        title: 'EG 初鋼',
        grade: 'EG',
        totalHp: 300,
        currentHp: 300,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(secondKit);
      await kitRepo.setActiveKit('kit-2');

      final active = await kitRepo.getActiveKit();
      expect(active!.id, equals('kit-2'));
    });
  });

  group('CraftLogRepository Tests', () {
    test('Add log and query by kitId and all', () async {
      final log1 = CraftLog(
        id: 'log-1',
        kitId: 'kit-A',
        phase: 'Snap-fit',
        durationMinutes: 25,
        damageDealt: 100,
        isCompletedSession: true,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      );

      final log2 = CraftLog(
        id: 'log-2',
        kitId: 'kit-B',
        phase: 'Sanding',
        durationMinutes: 12,
        damageDealt: 30,
        isCompletedSession: false,
        timestamp: DateTime.now(),
      );

      await logRepo.addLog(log1);
      await logRepo.addLog(log2);

      final allLogs = await logRepo.getAllLogs();
      expect(allLogs.length, equals(2));

      final kitALogs = await logRepo.getLogsForKit('kit-A');
      expect(kitALogs.length, equals(1));
      expect(kitALogs.first.id, equals('log-1'));

      final kitBLogs = await logRepo.getLogsForKit('kit-B');
      expect(kitBLogs.length, equals(1));
      expect(kitBLogs.first.id, equals('log-2'));
    });

    test('Cascade delete logs for kit', () async {
      final logA = CraftLog(
        id: 'l-a',
        kitId: 'target-kit',
        phase: 'Airbrush',
        durationMinutes: 25,
        damageDealt: 200,
        isCompletedSession: true,
        timestamp: DateTime.now(),
      );
      final logB = CraftLog(
        id: 'l-b',
        kitId: 'other-kit',
        phase: 'Detailing',
        durationMinutes: 25,
        damageDealt: 150,
        isCompletedSession: true,
        timestamp: DateTime.now(),
      );

      await logRepo.addLog(logA);
      await logRepo.addLog(logB);

      await logRepo.deleteLogsForKit('target-kit');

      final remaining = await logRepo.getAllLogs();
      expect(remaining.length, equals(1));
      expect(remaining.first.kitId, equals('other-kit'));
    });
  });

  group('Corruption & Edge Case Resilience', () {
    test('Malformed JSON in storage recovers gracefully without crash', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.kits: '{this is not valid json!}',
      });

      final prefs = await SharedPreferences.getInstance();
      final corruptedStorage = LocalStorageService(prefs);
      final repo = KitRepository(corruptedStorage);

      // Should recover gracefully and re-seed default kit
      final kits = await repo.getAllKits();
      expect(kits.length, equals(1));
      expect(kits.first.title, equals('綠色普通盒怪'));
    });
  });

  group('Cascade Deletion Tests (SPEC §7 Compliance)', () {
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

      // Act: Delete kit A via kitRepo (bound to logRepo)
      if (kitRepo is KitRepository) {
        (kitRepo as KitRepository).bindCraftLogRepository(logRepo);
      }
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
      expect((await kitRepo.getAllKits()).isNotEmpty, isTrue);
    });
  });

  group('Concurrent Write Atomicity Tests', () {
    test('Concurrent addLog operations all succeed without data loss', () async {
      final futures = List.generate(10, (i) {
        return logRepo.addLog(CraftLog.create(
          id: 'concurrent-unit-log-$i',
          kitId: 'kit-concurrent',
          phase: CraftPhases.snapFit,
          durationMinutes: 10 + i,
          damageDealt: 20 + i,
          isCompletedSession: true,
        ));
      });

      await Future.wait(futures);

      final logs = await logRepo.getAllLogs();
      expect(logs.length, equals(10));
      for (int i = 0; i < 10; i++) {
        expect(logs.any((l) => l.id == 'concurrent-unit-log-$i'), isTrue);
      }
    });

    test('Concurrent saveKit operations all succeed without data loss', () async {
      await kitRepo.getAllKits(); // Hydrate seed

      final futures = List.generate(5, (i) {
        return kitRepo.saveKit(KitItem(
          id: 'concurrent-unit-kit-$i',
          title: 'Concurrent Unit Kit $i',
          grade: 'HG',
          totalHp: 500,
          currentHp: 500,
          status: KitStatus.unstarted,
          createdAt: DateTime.now(),
        ));
      });

      await Future.wait(futures);

      final kits = await kitRepo.getAllKits();
      // 5 concurrent kits + 1 default seed kit = 6 kits
      expect(kits.length, equals(6));
      for (int i = 0; i < 5; i++) {
        expect(kits.any((k) => k.id == 'concurrent-unit-kit-$i'), isTrue);
      }
    });
  });
}
