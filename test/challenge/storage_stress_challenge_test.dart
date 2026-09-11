import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nifty_heisenberg/core/constants/game_constants.dart';
import 'package:nifty_heisenberg/data/storage/local_storage_service.dart';
import 'package:nifty_heisenberg/data/storage/storage_keys.dart';
import 'package:nifty_heisenberg/data/repositories/kit_repository.dart';
import 'package:nifty_heisenberg/data/repositories/craft_log_repository.dart';
import 'package:nifty_heisenberg/domain/models/kit_item.dart';
import 'package:nifty_heisenberg/domain/models/craft_log.dart';
import 'package:nifty_heisenberg/presentation/screens/craft_log_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenge Task 1: Storage Resilience & Corruption Stress', () {
    test('1.1: LocalStorageService handles various corrupted JSON strings gracefully', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      // Non-JSON garbage string
      await storage.setString('test_key', '!!!NOT_JSON_AT_ALL???');
      final list1 = await storage.getJsonList('test_key');
      expect(list1, isEmpty, reason: 'Invalid JSON should return empty list without throwing');

      // JSON Object instead of JSON List
      await storage.setString('test_key', jsonEncode({'id': 1, 'title': 'Object Not List'}));
      final list2 = await storage.getJsonList('test_key');
      expect(list2, isEmpty, reason: 'JSON object instead of list should return empty list');

      // JSON primitive values (number, boolean, string)
      await storage.setString('test_key', jsonEncode(12345));
      expect(await storage.getJsonList('test_key'), isEmpty);

      await storage.setString('test_key', jsonEncode(true));
      expect(await storage.getJsonList('test_key'), isEmpty);

      await storage.setString('test_key', jsonEncode('plain string'));
      expect(await storage.getJsonList('test_key'), isEmpty);

      // JSON List of primitives and nulls
      await storage.setString('test_key', jsonEncode([1, 'two', null, true]));
      final listPrimitives = await storage.getJsonList('test_key');
      expect(listPrimitives, isEmpty, reason: 'Primitives inside list should be filtered out by whereType<Map>()');

      // Empty string and whitespace string
      await storage.setString('test_key', '   ');
      expect(await storage.getJsonList('test_key'), isEmpty);
    });

    test('1.2: KitRepository resiliently parses corrupted, partial, and mixed-type KitItem maps', () async {
      final corruptedRawJson = jsonEncode([
        // 1. Missing all optional and some required fields
        {'title': 'Bare Minimum Kit'},
        // 2. String numbers for numeric fields
        {
          'id': 'k-str-num',
          'title': 'String Numbers Kit',
          'totalHp': '750',
          'currentHp': '320',
          'grade': 'RG',
          'status': 'in_progress',
          'isCustomBoss': '1',
        },
        // 3. Completely bogus status value
        {
          'id': 'k-bad-status',
          'title': 'Bad Status Kit',
          'totalHp': 600,
          'currentHp': 600,
          'status': 'ABSOLUTELY_UNKNOWN_STATUS_XYZ',
        },
        // 4. Negative and out-of-range HP
        {
          'id': 'k-neg-hp',
          'title': 'Negative HP Kit',
          'totalHp': -200,
          'currentHp': -50,
        },
        // 5. Overflow currentHp (> totalHp)
        {
          'id': 'k-over-hp',
          'title': 'Overflow HP Kit',
          'totalHp': 400,
          'currentHp': 999999,
        },
        // 6. Invalid photoPath type (int instead of String) - skipped defensively
        {
          'id': 'k-bad-photo',
          'title': 'Bad Photo Type Kit',
          'totalHp': 500,
          'currentHp': 500,
          'photoPath': 12345,
        },
        // 7. A fully valid kit
        {
          'id': 'k-valid',
          'title': 'Perfect Valid Kit',
          'grade': 'MG',
          'totalHp': 1500,
          'currentHp': 1000,
          'status': 'in_progress',
          'createdAt': '2026-05-01T12:00:00.000Z',
        }
      ]);

      SharedPreferences.setMockInitialValues({
        StorageKeys.kits: corruptedRawJson,
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final repo = KitRepository(storage);

      final kits = await repo.getAllKits();
      expect(kits, isNotEmpty);

      // Verify Kit 1: default fallbacks
      final kit1 = kits.firstWhere((k) => k.title == 'Bare Minimum Kit');
      expect(kit1.id, isNotEmpty);
      expect(kit1.grade, equals('HG'));
      expect(kit1.totalHp, equals(500));
      expect(kit1.currentHp, equals(500));
      expect(kit1.status, equals(KitStatus.unstarted));

      // Verify Kit 2: string number parsing
      final kit2 = kits.firstWhere((k) => k.id == 'k-str-num');
      expect(kit2.totalHp, equals(750));
      expect(kit2.currentHp, equals(320));
      expect(kit2.isCustomBoss, isTrue);

      // Verify Kit 3: status normalization
      final kit3 = kits.firstWhere((k) => k.id == 'k-bad-status');
      expect(kit3.status, equals(KitStatus.unstarted),
          reason: 'Unknown status should normalize to unstarted');

      // Verify Kit 4: negative HP fallback
      final kit4 = kits.firstWhere((k) => k.id == 'k-neg-hp');
      expect(kit4.totalHp, equals(500), reason: 'Non-positive totalHp falls back to default 500');
      expect(kit4.currentHp, equals(0), reason: 'Negative currentHp clamps to 0');

      // Verify Kit 5: overflow HP clamped
      final kit5 = kits.firstWhere((k) => k.id == 'k-over-hp');
      expect(kit5.currentHp, equals(400), reason: 'currentHp cannot exceed totalHp');

      // Verify Kit 7: valid kit loaded intact
      final kit7 = kits.firstWhere((k) => k.id == 'k-valid');
      expect(kit7.grade, equals('MG'));
      expect(kit7.totalHp, equals(1500));
      expect(kit7.currentHp, equals(1000));
    });

    test('1.3: Empirical verification of KitStatus.isValid logic and validation behavior', () {
      expect(KitStatus.isValid(KitStatus.unstarted), isTrue);
      expect(KitStatus.isValid(KitStatus.inProgress), isTrue);
      expect(KitStatus.isValid(KitStatus.completed), isTrue);
      expect(KitStatus.isValid('backlog'), isTrue);
      expect(KitStatus.isValid(null), isFalse);

      // Strict validation must reject arbitrary unrecognized status strings
      final bool garbageIsValid = KitStatus.isValid('TOTALLY_BOGUS_STATUS_12345');
      expect(garbageIsValid, isFalse,
          reason: 'Strict validation must reject unrecognized status strings');

      final bogusKit = KitItem(
        id: 'test-bogus',
        title: 'Bogus Kit',
        totalHp: 500,
        currentHp: 500,
        status: 'NON_EXISTENT_STATUS',
        createdAt: DateTime(2026, 1, 1),
      );
      final errors = bogusKit.validate();
      expect(errors.where((e) => e.contains('Invalid status')), isNotEmpty,
          reason: 'validate() must reject invalid status');
      expect(bogusKit.isValid, isFalse);
    });

    test('1.4: CraftLogRepository handles corrupted, missing, and malformed log entries', () async {
      final corruptedLogsJson = jsonEncode([
        {'kitId': 'kit-1'},
        {
          'id': 'log-str',
          'kitId': 'kit-1',
          'phase': 'Sanding',
          'durationMinutes': '35',
          'damageDealt': '120',
          'isCompletedSession': 'true',
          'createdAt': '2026-03-01T10:00:00.000Z',
        },
        {
          'id': 'log-bad-date',
          'kitId': 'kit-2',
          'phase': 'Airbrush',
          'durationMinutes': 25,
          'damageDealt': 200,
          'isCompletedSession': 1,
          'timestamp': 'NOT_A_REAL_DATE_AT_ALL',
        },
        'just a string in the array',
        42,
      ]);

      SharedPreferences.setMockInitialValues({
        StorageKeys.craftLogs: corruptedLogsJson,
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);

      final logs = await logRepo.getAllLogs();
      expect(logs.length, equals(3), reason: 'The 3 map entries are recovered and 2 primitives skipped');

      final log1 = logs.firstWhere((l) => l.kitId == 'kit-1' && l.id != 'log-str');
      expect(log1.durationMinutes, equals(0));
      expect(log1.damageDealt, equals(0));
      expect(log1.phase, equals(CraftPhases.snapFit));

      final log2 = logs.firstWhere((l) => l.id == 'log-str');
      expect(log2.durationMinutes, equals(35));
      expect(log2.damageDealt, equals(120));
      expect(log2.isCompletedSession, isTrue);

      final log3 = logs.firstWhere((l) => l.id == 'log-bad-date');
      expect(log3.timestamp, isNotNull, reason: 'Malformed date falls back to DateTime.now()');
    });
  });

  group('Challenge Task 2: Concurrent Updates, Rapid Operations & Boundary Values', () {
    test('2.1: Rapid concurrent writes to CraftLogRepository (Race condition analysis)', () async {
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
      debugPrint('Empirical check: ${allLogs.length} logs survived concurrent write out of 6');
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

    test('2.2: Rapid concurrent writes to KitRepository (Race condition analysis)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);

      await kitRepo.getAllKits();

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
      debugPrint('Empirical check: ${kits.length} kits in repository after 4 concurrent saves + 1 seed');
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

    test('2.3: KitItem HP boundaries: negative HP, zero HP, massive damage, and reset', () {
      final kit = KitItem.create(
        title: 'Boundary Boss',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
      );

      // Massive damage (1,000,000)
      final defeatedKit = kit.applyDamage(1000000);
      expect(defeatedKit.currentHp, equals(0));
      expect(defeatedKit.isCompleted, isTrue);
      expect(defeatedKit.isDefeated, isTrue);
      expect(defeatedKit.completedAt, isNotNull);
      expect(defeatedKit.hpPercentage, equals(0.0));
      expect(defeatedKit.damageTaken, equals(500));

      // Reset after defeat
      final resetKit = defeatedKit.reset();
      expect(resetKit.currentHp, equals(500));
      expect(resetKit.status, equals(KitStatus.unstarted));
      expect(resetKit.completedAt, isNull);
      expect(resetKit.isCompleted, isFalse);
      expect(resetKit.hpPercentage, equals(1.0));

      // Negative damage (healing attempt)
      final healedKit = resetKit.applyDamage(-200);
      expect(healedKit.currentHp, equals(500), reason: 'HP cannot exceed totalHp');

      // Zero damage on unstarted kit
      final zeroDmgKit = kit.applyDamage(0);
      expect(zeroDmgKit.currentHp, equals(500));
      expect(zeroDmgKit.status, equals(KitStatus.inProgress),
          reason: 'Applying damage transitions kit from unstarted to inProgress');
    });

    test('2.4: CraftLog session duration calculation for short and boundary times', () {
      final zeroLog = CraftLog.fromSession(
        kitId: 'k1',
        phase: CraftPhases.snapFit,
        elapsedSeconds: 0,
        damageDealt: 0,
        isCompletedSession: false,
      );
      expect(zeroLog.durationMinutes, equals(0));

      final debugLog = CraftLog.fromSession(
        kitId: 'k1',
        phase: CraftPhases.snapFit,
        elapsedSeconds: 5,
        damageDealt: 100,
        isCompletedSession: true,
      );
      expect(debugLog.durationMinutes, equals(1),
          reason: '5s session must count as at least 1 minute in craft log statistics');

      final subMinuteLog = CraftLog.fromSession(
        kitId: 'k1',
        phase: CraftPhases.snapFit,
        elapsedSeconds: 59,
        damageDealt: 80,
        isCompletedSession: false,
      );
      expect(subMinuteLog.durationMinutes, equals(1));

      final twoMinLog = CraftLog.fromSession(
        kitId: 'k1',
        phase: CraftPhases.snapFit,
        elapsedSeconds: 120,
        damageDealt: 200,
        isCompletedSession: true,
      );
      expect(twoMinLog.durationMinutes, equals(2));
    });
  });

  group('Challenge Task 3: Cascade Deletion Verification', () {
    test('3.1: CraftLogRepository.deleteLogsForKit deletes only target kit logs and preserves other kit logs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);

      for (int i = 0; i < 3; i++) {
        await logRepo.addLog(CraftLog.create(
          id: 'log-A-',
          kitId: 'target-kit-A',
          phase: CraftPhases.snapFit,
          durationMinutes: 25,
          damageDealt: 100,
          isCompletedSession: true,
        ));
      }
      for (int i = 0; i < 2; i++) {
        await logRepo.addLog(CraftLog.create(
          id: 'log-B-',
          kitId: 'other-kit-B',
          phase: CraftPhases.sanding,
          durationMinutes: 15,
          damageDealt: 60,
          isCompletedSession: true,
        ));
      }

      var allLogs = await logRepo.getAllLogs();
      expect(allLogs.length, equals(5));

      await logRepo.deleteLogsForKit('target-kit-A');

      final remainingAll = await logRepo.getAllLogs();
      expect(remainingAll.length, equals(2));
      expect(remainingAll.every((l) => l.kitId == 'other-kit-B'), isTrue);

      final targetLogs = await logRepo.getLogsForKit('target-kit-A');
      expect(targetLogs, isEmpty);

      await logRepo.deleteLogsForKit('non-existent-kit');
      expect((await logRepo.getAllLogs()).length, equals(2));
    });

    test('3.2: KitRepository.deleteKit cascade deletes logs in storage and memory', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

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
  });

  group('Challenge Task 4: Default Kit Re-seeding & ID Discrepancy Stress', () {
    test('4.1: Fresh storage auto-seeds default HG kit and sets active kit ID', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);

      final kits = await kitRepo.getAllKits();
      expect(kits.length, equals(1));
      final defaultKit = kits.first;
      expect(defaultKit.title, equals('綠色普通盒怪'));
      expect(defaultKit.grade, equals('HG'));
      expect(defaultKit.totalHp, equals(500));
      expect(defaultKit.currentHp, equals(500));
      expect(defaultKit.status, equals(KitStatus.inProgress));

      final active = await kitRepo.getActiveKit();
      expect(active, isNotNull);
      expect(active!.id, equals(defaultKit.id));

      final storedActiveId = await storage.getString(StorageKeys.activeKitId);
      expect(storedActiveId, equals(defaultKit.id));
    });

    test('4.2: Deleting the only remaining kit triggers automatic re-seeding of default kit', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);

      final initialKits = await kitRepo.getAllKits();
      expect(initialKits.length, equals(1));
      final initialId = initialKits.first.id;

      await kitRepo.deleteKit(initialId);

      final kitsAfterDelete = await kitRepo.getAllKits();
      expect(kitsAfterDelete.length, equals(1),
          reason: 'Deleting all kits must re-seed a default kit');
      expect(kitsAfterDelete.first.title, equals('綠色普通盒怪'));

      final active = await kitRepo.getActiveKit();
      expect(active, isNotNull);
      expect(active!.title, equals('綠色普通盒怪'));
    });

    test('4.3: In-memory cache behavior when storage is cleared', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);

      final kits = await kitRepo.getAllKits();
      expect(kits.length, equals(1));

      await storage.clear();

      // Because _cachedKits is in memory, calling getAllKits() returns cached kits
      final cachedKits = await kitRepo.getAllKits();
      expect(cachedKits.length, equals(1),
          reason: 'Empirical observation: Repository caches kits in-memory and does not re-read cleared storage on existing instance');

      // Fresh instance re-reads empty storage and re-seeds
      final freshRepo = KitRepository(storage);
      final reSeededKits = await freshRepo.getAllKits();
      expect(reSeededKits.length, equals(1));
      expect(reSeededKits.first.title, equals('綠色普通盒怪'));
    });

    test('4.4: Verification of consolidated default kit ID across KitItem and KitRepository', () {
      final kitItemSeed = KitItem.initialSeedKit();
      final repoSeed = KitRepository.createDefaultSeedKit();

      expect(kitItemSeed.id, equals(GameConstants.defaultKitId));
      expect(repoSeed.id, equals(GameConstants.defaultKitId));
      expect(kitItemSeed.grade, equals(GameConstants.defaultKitGrade));
      expect(repoSeed.grade, equals(GameConstants.defaultKitGrade));

      expect(kitItemSeed.id, equals(repoSeed.id),
          reason: 'KitItem.initialSeedKit and KitRepository.createDefaultSeedKit must share the consolidated ID');
    });

    test('4.5: Active kit deletion behavior when other kits exist', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);

      // First clear or load initial kits
      final initialKits = await kitRepo.getAllKits();
      final seedId = initialKits.first.id;

      final kit1 = KitItem(
        id: 'kit-1-rg',
        title: 'RG 飛翼鋼彈',
        grade: 'RG',
        totalHp: 800,
        currentHp: 800,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      final kit2 = KitItem(
        id: 'kit-2-mg',
        title: 'MG 自由鋼彈',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 1500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );

      await kitRepo.saveKit(kit1);
      await kitRepo.saveKit(kit2);

      // Delete the default seed kit so only kit1 and kit2 remain
      await kitRepo.deleteKit(seedId);

      await kitRepo.setActiveKit('kit-1-rg');
      expect((await kitRepo.getActiveKit())!.id, equals('kit-1-rg'));

      // Delete active kit (kit1) -> fallback should be kit2
      await kitRepo.deleteKit('kit-1-rg');

      final newActive = await kitRepo.getActiveKit();
      expect(newActive, isNotNull);
      expect(newActive!.id, equals('kit-2-mg'),
          reason: 'When active kit is deleted, next active kit smoothly becomes the remaining kit');
    });
  });

  group('Challenge Task 5: CraftLogScreen UI Resilience & Stress', () {
    testWidgets('5.1: CraftLogScreen renders cleanly with 0 logs (Empty State)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);

      await tester.pumpWidget(
        MaterialApp(
          home: CraftLogScreen(
            craftLogRepository: logRepo,
            activeKitId: 'empty-kit',
            activeKitTitle: '空盒怪測試',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('★ CRAFT LOG ★'), findsOneWidget);
      expect(find.textContaining('尚未有施工紀錄'), findsOneWidget);
      expect(find.text('0m'), findsOneWidget);
      expect(find.text('0 pt'), findsOneWidget);
    });

    testWidgets('5.2: CraftLogScreen filter toggling updates metrics and log counts accurately', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);

      // Kit A log
      await logRepo.addLog(CraftLog.create(
        id: 'log-A',
        kitId: 'kit-A',
        phase: CraftPhases.snapFit,
        durationMinutes: 25,
        damageDealt: 100,
        isCompletedSession: true,
      ));

      // Kit B log
      await logRepo.addLog(CraftLog.create(
        id: 'log-B',
        kitId: 'kit-B',
        phase: CraftPhases.airbrush,
        durationMinutes: 50,
        damageDealt: 220,
        isCompletedSession: true,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: CraftLogScreen(
            craftLogRepository: logRepo,
            activeKitId: 'kit-A',
            activeKitTitle: 'Kit A',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // In Kit A view: 25m and 100 pt
      expect(find.text('25m'), findsOneWidget);
      expect(find.text('100 pt'), findsOneWidget);
      expect(find.text('1 次'), findsWidgets);

      // Tap filter toggle button to show all logs
      final allLogsFilterBtn = find.text('全部歷史紀錄');
      expect(allLogsFilterBtn, findsOneWidget);
      await tester.tap(allLogsFilterBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // In all logs view: 25 + 50 = 75m (displayed as 1h 15m), 100 + 220 = 320 pt
      expect(find.text('1h 15m'), findsOneWidget);
      expect(find.text('320 pt'), findsOneWidget);
    });

    testWidgets('5.3: CraftLogScreen handles high volume of logs (500 logs stress test)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);

      final phases = [
        CraftPhases.snapFit,
        CraftPhases.sanding,
        CraftPhases.detailing,
        CraftPhases.airbrush,
        CraftPhases.finishing,
      ];

      final rawLogs = List.generate(500, (i) {
        return {
          'id': 'stress-log-',
          'kitId': 'stress-kit',
          'phase': phases[i % phases.length],
          'durationMinutes': (i % 25) + 1,
          'damageDealt': (i % 50) + 10,
          'isCompletedSession': i % 3 != 0,
          'timestamp': DateTime(2026, 1, 1).add(Duration(minutes: i * 30)).toIso8601String(),
        };
      });

      await storage.setJsonList(StorageKeys.craftLogs, rawLogs);

      await tester.pumpWidget(
        MaterialApp(
          home: CraftLogScreen(
            craftLogRepository: logRepo,
            activeKitId: 'stress-kit',
            activeKitTitle: '巨量日誌盒怪',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('★ CRAFT LOG ★'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'High-volume logs should render without exceptions');
    });
  });
}
